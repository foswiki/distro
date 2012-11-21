# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::PageCache

This class is a purely virtual base class that implements the
basic infrastructure required to cache pages as produced by
the rendering engine. Once a page was computed, it will be 
cached for subsequent calls for the same output. In addition
a Foswiki::PageCache has to ensure cache correctness, that is
all content stored in the cache is up-to-date. It must not
return any content being rendered on the base of  data that has already
changed in the meantine by actions performed by the Foswiki::Store. 

The Foswiki::Store informs the cache whenever any content has changed
by calling Foswiki::PageCache::fireDependency($web, $topic). This
will in turn delete any cache entries that used this $web.$topic as an
ingredience to render the cached page. That's why there is a dependency
graph part of the page cache.

The dependency graph records all topics that have been touched while
the current page is being computed. It also records the session and url
parameters that were in use, part of which is the user name as well.

An edge in the dependency graph consists of:

   * from: the topic being rendered
   * variation: an opaque key encoding the context in which the page was rendered
   * to: the topic that has been used to render the "from" topic

For every cached page there's a record of meta data describing it:

   * topic: the web.topic being cached
   * variation: the context which this page was rendered within
   * md5: fingerprint of the data stored; this is used to get access to the stored
     blob related to this page
   * contenttype: to be used in the http header
   * lastmodified: time when this page was cached in http-date format
   * etag: tag used for browser-side caching 
   * status: http response status 
   * location: url in case the status is a 302 redirect
   * expire: time when this cache entry is outdated
   * isdirty: boolean flag indicating whether the cached page has got "dirtyareas"
     and thus needs post-processing

Whenever the Foswiki::Store informs the cache by firing a dependency for
a given web.topic, the cache will remove those cache entries that have a dependency
to the given web.topic. It thereby guarentees that whenever a page has been
successfully retrieved from the cache, there is no "fresher" content available
in the Foswiki::Store, and that this cache entry can be used instead without
rendering the related yet again.

=cut

package Foswiki::PageCache;

use strict;
use warnings;
use Foswiki::Time    ();
use Foswiki::Attrs   ();
use Foswiki::Plugins ();
use Error qw( :try );
use CGI::Util ();

# Enable output
use constant TRACE => 0;

sub writeDebug {
    print STDERR "$_[0]\n" if TRACE;
}

=begin TML

---++ ClassMethod new( ) -> $object

Construct a new page cache 

=cut

sub new {
    my ($class) = @_;

    return bless( {}, $class );
}

=begin TML 

---++ ObjectMethod genVariationKey() -> $key

Generate a key for the current webtopic being produced; this reads
information from the current session and url params, as follows:
    * the server serving the request (HTTP_HOST)
    * the port number of the server serving the request (HTTP_PORT)
    * the language of the current session, if any
    * all session parameters EXCEPT:
          o Those starting with an underscore
          o VALIDATION
          o REMEMBER
          o FOSWIKISTRIKEONE.*
          o VALID_ACTIONS.*
          o BREADCRUMB_TRAIL
          o DGP_hash
    * all HTTP request parameters EXCEPT:
          o All those starting with an underscore
          o refresh
          o foswiki_redirect_cache
          o logout
          o topic
          o cache_ignore
          o cache_expire

=cut

sub genVariationKey {
    my $this = shift;

    my $variationKey = $this->{variationKey};
    return $variationKey if defined $variationKey;

    my $session    = $Foswiki::Plugins::SESSION;
    my $request    = $session->{request};
    my $serverName = $request->server_name || $Foswiki::cfg{DefaultUrlHost};
    my $serverPort = $request->server_port || 80;
    $variationKey = '::' . $serverName . '::' . $serverPort;

    # add a flag to distinguish compressed from uncompressed cache entries
    $variationKey .= '::'
      . (
        ( $Foswiki::cfg{HttpCompress} && $session->inContext('command_line') )
        ? 1
        : 0
      );

    # add language tag
    if ( $Foswiki::cfg{UserInterfaceInternationalisation} ) {
        my $language = $session->i18n->language();
        $variationKey .= "::language=$language" if $language;
    }

    # get information from the session object
    my $sessionValues = $session->getLoginManager()->getSessionValues();
    foreach my $key ( sort keys %$sessionValues ) {

      # SMELL: add a setting to make exclusion of session variables configurable
        next
          if $key =~
/^(_.*|VALIDATION|REMEMBER|FOSWIKISTRIKEONE.*|VALID_ACTIONS.*|BREADCRUMB_TRAIL|DGP_hash|release_lock)$/o;

        #writeDebug("adding session key=$key");

        my $val = $sessionValues->{$key};
        next unless defined $val;

        $variationKey .= '::' . $key . '=' . $val;
    }

    # get cache_ignore pattern
    my @ignoreParams = $request->param("cache_ignore");
    push @ignoreParams,
      (
        "cache_expire",           "cache_ignore",
        "_.*",                    "refresh",
        "foswiki_redirect_cache", "logout",
        "topic"
      );
    my $ignoreParams = join( "|", @ignoreParams );

    foreach my $key ( sort $request->param() ) {

        # filter out some params that are not relevant
        next if $key =~ /^($ignoreParams)$/;
        my @vals = $request->param($key);
        foreach my $val (@vals) {
            next unless defined $val;    # wtf?
            $variationKey .= '::' . $key . '=' . $val;
            writeDebug("adding urlparam key=$key val=$val");
        }
    }

    $variationKey =~ s/'/\\'/g;

    writeDebug("variation key = '$variationKey'");

    # cache it
    $this->{variationKey} = $variationKey;
    return $variationKey;
}

=begin TML

---++ ObjectMethod cachePage($contentType, $data) -> $boolean

Cache a page. Every page is stored in a page bucket that contains all
variations (stored for other users or other session parameters) of this page,
as well as dependency and expiration information

=cut

sub cachePage {
    my ( $this, $contentType, $data ) = @_;

    my $session = $Foswiki::Plugins::SESSION;
    my $request = $session->{request};
    my $web     = $session->{webName};
    my $topic   = $session->{topicName};
    $web =~ s/\//./go;

    writeDebug("called cachePage($web, $topic)");

    return undef unless $this->isCacheable( $web, $topic );

    # delete page and all variations if we ask for a refresh copy
    my $refresh = $request->param('refresh') || '';
    my $variationKey = $this->genVariationKey();

    # remove old entries
    if ( $refresh =~ /^(on|cache|all)$/o ) {
        $this->deletePage( $web, $topic );    # removes all variations
    }
    else {
        $this->deletePage( $web, $topic, $variationKey );
    }

    # prepair page variation
    my $isDirty =
      ( $data =~ /<dirtyarea[^>]*?>/ )
      ? 1
      : 0;    # SMELL: only for textual content type
    my $etag         = '';
    my $lastModified = '';
    my $time         = time();

    unless ($isDirty) {
        $data =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;

        if ( $Foswiki::cfg{HttpCompress}
            && !$session->inContext('command_line') )
        {
            require Compress::Zlib;
            $data = Compress::Zlib::memGzip($data);
        }
        $etag = $time;
        $lastModified = Foswiki::Time::formatTime( $time, '$http', 'gmtime' );
    }

    my $headers   = $session->{response}->headers();
    my $status    = $headers->{Status} || 200;
    my $variation = {
        contenttype  => $contentType,
        lastmodified => $lastModified,
        data         => $data,
        etag         => $etag,
        isdirty      => $isDirty,
        status       => $status,
    };
    $variation->{location} = $headers->{Location} if $status == 302;

    # get cache-expiry preferences and add it to the bucket if available
    my $expire = $request->param("cache_expire");
    $expire = $session->{prefs}->getPreference('CACHEEXPIRE')
      unless defined $expire;
    $variation->{expire} = CGI::Util::expire_calc($expire)
      if defined $expire;

    # store page variation
    $this->setPageVariation( $web, $topic, $variationKey, $variation );

    # assert newly autotetected dependencies
    $this->setDependencies( $web, $topic, $variationKey );

    return $variation;
}

=begin TML 

---++ ObjectMethod getPage($web, $topic)

Retrieve a cached page for the given web.topic, using a variation
key based on the current session.

=cut

sub getPage {
    my ( $this, $web, $topic ) = @_;

    $web =~ s/\//./go;

    writeDebug("getPage($web.$topic)");

    # check url param
    my $session = $Foswiki::Plugins::SESSION;
    my $refresh = $session->{request}->param('refresh') || '';
    if ( $refresh eq 'all' ) {

        # SMELL: restrict this to admins; put this somewhere else
        $this->deleteAll();
    }

    if ( $refresh eq 'fire' ) {    # simulates a "save" of the current topic
        $this->fireDependency( $web, $topic );
    }
    return undef if $refresh =~ /^(on|cache|all|fire)$/;

    # check cacheability
    return undef unless $this->isCacheable( $web, $topic );

    # check availability
    my $variationKey = $this->genVariationKey();

    my $variation = $this->getPageVariation( $web, $topic, $variationKey );

   # check expiry date of this entry; return undef if it did expire, not deleted
   # from cache as it will be recomputed during a normal view cycle
    return undef
      if defined($variation)
      && defined( $variation->{expire} )
      && $variation->{expire} < time();

    return $variation;
}

=begin TML 

---++ ObjectMethod setPageVariation($web, $topici, $variationKey, $variation)

stores a rendered page

=cut

sub setPageVariation {
    my ( $this, $web, $topic, $variationKey, $variation ) = @_;

    die("virtual method");
}

=begin TML 

---++ ObjectMethod getPageVariation($web, $topic, $variationKey)

retrievs a cache entry; returns undef if there is none.

=cut

sub getPageVariation {
    die("virtual method");
}

=begin TML

Checks whether the current page is cacheable. It first
checks the "refresh" url parameter and then looks out
for the "CACHEABLE" preference variable.

=cut

sub isCacheable {
    my ( $this, $web, $topic ) = @_;

    my $webTopic = $web . '.' . $topic;

    writeDebug("isCacheable($webTopic)");

    my $isCacheable = $this->{isCacheable}{$webTopic};
    return $isCacheable if defined $isCacheable;

    writeDebug("... checking");

    # by default we try to cache as much as possible
    $isCacheable = 1;

    my $session = $Foswiki::Plugins::SESSION;

    # POSTs aren't cacheable
    my $request = $session->{request};
    $isCacheable = 0 if $request->method eq 'POST';

    if ($isCacheable) {

        # check prefs value
        my $flag = $session->{prefs}->getPreference('CACHEABLE');
        $isCacheable = 0 if defined $flag && !Foswiki::isTrue($flag);
    }

    # don't cache 401 Not authorized responses
    my $headers = $session->{response}->headers();
    my $status  = $headers->{Status};
    $isCacheable = 0 if $status && $status eq 401;

    # TODO: give plugins a chance - create a callback to intercept cacheability

    writeDebug("isCacheable=$isCacheable");
    $this->{isCacheable}{$webTopic} = $isCacheable;
    return $isCacheable;
}

=begin TML

---++ ObjectMethod addDependency($web, $topic)

Add a web.topic to the dependencies of the current page

=cut

sub addDependency {
    my ( $this, $depWeb, $depTopic ) = @_;

    # exclude invalid topic names
    return unless $depTopic =~ /^[$Foswiki::regex{upperAlpha}]/o;

    # omit dependencies triggered from inside a dirtyarea
    my $session = $Foswiki::Plugins::SESSION;
    return if $session->inContext('dirtyarea');

    $depWeb =~ s/\//\./go;
    my $depWebTopic = $depWeb . '.' . $depTopic;

    # exclude unwanted dependencies
    if ( $depWebTopic =~ /^($Foswiki::cfg{Cache}{DependencyFilter})$/o ) {

#writeDebug( "dependency on $depWebTopic ignored by filter $Foswiki::cfg{Cache}{DependencyFilter}");
        return;
    }
    else {

        #writeDebug("addDependency($depWeb.$depTopic)");
    }

    # collect them; defer writing them to the database til we cache this page
    $this->{deps}{$depWebTopic} = 1;
}

=begin TML 

---++ ObjectMethod getDependencies($web, $topic, $variationKey) -> \@deps

Return dependencies for a given web.topic. if $variationKey is specified, only
dependencies of this page variation will be returned.

=cut

sub getDependencies {
    my ( $this, $web, $topic, $variationKey ) = @_;

    die("virtual method");

}

=begin TML 

---++ ObjectMethod getWebDependencies($web) -> \@deps

Returns dependencies that hold for all topics in a web. 

=cut

sub getWebDependencies {
    my ( $this, $web ) = @_;

    unless ( defined $this->{webDeps} ) {
        my $session = $Foswiki::Plugins::SESSION;
        my $webDeps =
             $session->{prefs}->getPreference( 'WEBDEPENDENCIES', $web )
          || $Foswiki::cfg{Cache}{WebDependencies}
          || '';

        $this->{webDeps} = ();

        # normalize topics
        foreach my $dep ( split( /\s*,\s*/, $webDeps ) ) {
            my ( $depWeb, $depTopic ) =
              $session->normalizeWebTopicName( $web, $dep );

            writeDebug("found webdep $depWeb.$depTopic");
            $this->{webDeps}{ $depWeb . '.' . $depTopic } = 1;
        }
    }
    my @result = keys %{ $this->{webDeps} };
    return \@result;
}

=begin TML 

---++ ObjectMethod setDependencies($web, $topic, $variation, @topics)

Stores the dependencies for the given web.topic topic. Setting the dependencies
happens at the very end of a rendering process of a page while it is about
to be cached.

When the optional @topics parameter isn't provided, then all dependencies
collected in the Foswiki::PageCache object will be used. These dependencies
are collected during the rendering process. 

=cut

sub setDependencies {
    my ( $this, $web, $topic, $variationKey, @topicDeps ) = @_;

    @topicDeps = keys %{ $this->{deps} } unless @topicDeps;

    die("virtual method");
}

=begin TML 

---++ ObjectMethod deleteDependencies($web, $topic, $variation, $force)

Remove a dependency from the graph. This operation is normally performed
as part of a call to Foswiki::PageCache::deletePage().

=cut

sub deleteDependencies {
    die("virtual method");
}

=begin TML 

---++ ObjectMethod deletePage($web, $topic, $variation, $force)

Remove a page from the cache; this removes all of the information
that we have about this page, including any dependencies that have
been established while this page was created.

If $variation is specified, only this variation of $web.$topic will
be removed. When $variation is not specified, all page variations of $web.$topic
will be removed.

When $force is true, the deletion will take place immediately. Otherwise all
delete requests might be delayed and committed as part of
Foswiki::PageCache::finish().

=cut

sub deletePage {
    die("virtual method");
}

=begin TML 

---++ ObjectMethod deleteAll()

purges all of the cache

=cut

sub deleteAll {
    die("virtual method");
}

=begin TML 

---++ ObjectMethod fireDependency($web, $topic)

This method is called to remove all other cache entries that 
used the given $web.$topic as an ingredience to produce the page.

A dependency is a directed edge starting from a page variation being rendered
towards a depending page that has been used to produce it.

While dependency edges are stored as they are collected during the rendering
process, these edges are traversed in reverse order when a dependency is
fired. 

In addition all manually asserted dependencies of topics in a web are deleted,
as well as the given topic itself.

=cut

sub fireDependency {
    die("virtual method");
}

=begin TML

---++ ObjectMethod renderDirtyAreas($text)

Extract dirty areas and render them; this happens after storing a 
page including the un-rendered dirty areas into the cache and after
retrieving it again.

=cut

sub renderDirtyAreas {
    my ( $this, $text ) = @_;

    writeDebug("renderDirtyAreas called text=$$text");

    my $session = $Foswiki::Plugins::SESSION;
    $session->enterContext('dirtyarea');

    # remember the current page length to recompute the content length below
    my $found = 0;
    my $topicObj =
      new Foswiki::Meta( $session, $session->{webName}, $session->{topicName} );

    # expand dirt
    while ( $$text =~
s/<dirtyarea([^>]*?)>(?!.*<dirtyarea)(.*?)<\/dirtyarea>/$this->_handleDirtyArea($1, $2, $topicObj)/geos
      )
    {
        $found = 1;
    }

    $$text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis if $found;

    # remove any dirtyarea leftovers
    $$text =~ s/<\/?dirtyarea>//go;

    $session->leaveContext('dirtyarea');

    writeDebug("done renderDirtyAreas");
}

# called by renderDirtyAreas() to process each dirty area in isolation
sub _handleDirtyArea {
    my ( $this, $args, $text, $topicObj ) = @_;

    writeDebug("_handleDirtyArea($args) called in text='$text'");

    # add dirtyarea params
    my $params  = new Foswiki::Attrs($args);
    my $session = $Foswiki::Plugins::SESSION;
    my $prefs   = $session->{prefs};

    $prefs->pushTopicContext( $topicObj->web, $topicObj->topic );
    $params->remove('_RAW');
    $prefs->setSessionPreferences(%$params);
    try {
        $text = $topicObj->expandMacros($text);
        $text = $topicObj->renderTML($text);
    };
    finally {
        $prefs->popTopicContext();
    };

    writeDebug("out text='$text'");
    return $text;
}

=begin TML 

---++ ObjectMethod finish()

clean up finally

=cut

sub finish {
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Copyright (C) 2006-2010 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
