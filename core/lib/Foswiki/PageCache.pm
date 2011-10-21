# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::PageCache

Interface to the caching infrastructure.

=cut

package Foswiki::PageCache;

use strict;
use warnings;
use Foswiki::Cache;
use Foswiki::Time;
use Foswiki::Attrs;
use Error qw( :try );
use CGI::Util ();

use constant PAGECACHE_PAGE_KEY    => 'Foswiki::PageCache::';
use constant PAGECACHE_VARS_KEY    => 'Foswiki::PageCache::Vars::';
use constant PAGECACHE_DEPS_KEY    => 'Foswiki::PageCache::Deps::';
use constant PAGECACHE_REVDEPS_KEY => 'Foswiki::PageCache::RevDeps::';
use constant PAGECACHE_KEYSEP      => "\0";

# Enable output of messages to the foswiki debug log. All writeDebug()
# calls are written as writeDebug(...) if (TRACE)
use constant TRACE => 0;

# Protected, for use of subclasses (and companion classes) only.
sub writeDebug {
    $Foswiki::Plugins::SESSION->logger->log( 'debug', @_ );
}

=begin TML

---++ ClassMethod new( $session ) -> $object

Construct a new page cache and a delegator.

=cut

sub new {
    my ( $class, $session ) = @_;

    writeDebug("new PageCache using $Foswiki::cfg{CacheManager}")
      if (TRACE);

    # try to get a shared instance of this class
    eval "require $Foswiki::cfg{CacheManager}";
    die $@ if $@;

    my $this = {
        session => $session,
        handler => $Foswiki::cfg{CacheManager}->new($session),
    };

    # store metadata in a separate store, i.e. one without size constraints
    if ( $Foswiki::cfg{MetaCacheManager} ne $Foswiki::cfg{CacheManager} ) {
        eval "use $Foswiki::cfg{MetaCacheManager}";
        die $@ if $@;
        $this->{metaHandler} = $Foswiki::cfg{MetaCacheManager}->new($session);
    }
    else {
        $this->{metaHandler} = $this->{handler};
    }

    return bless( $this, $class );
}

=begin TML 

---++ ObjectMethod genVariationKey() -> $key

Generate a key for the current webtopic being produced; this reads
information from the current session and url params, as follows:
    *  The server serving the request (HTTP_HOST)
    * The port number of the server serving the request (HTTP_PORT)
    * The language of the current session, if any
    * All session parameters EXCEPT:
          o Those starting with an underscore
          o VALIDATION
          o REMEMBER
          o FOSWIKISTRIKEONE.*
          o VALID_ACTIONS.*
          o BREADCRUMB_TRAIL
    * All HTTP request parameters EXCEPT:
          o All those starting with an underscore
          o refresh
          o foswiki_redirect_cache
          o logout
          o style.*
          o switch.*
          o topic

=cut

sub genVariationKey {
    my $this = shift;

    my $variationKey = $this->{variationKey};
    return $variationKey if defined $variationKey;

    my $session    = $this->{session};
    my $request    = $session->{request};
    my $serverName = $request->server_name || $Foswiki::cfg{DefaultUrlHost};
    my $serverPort = $request->server_port || 80;
    $variationKey = '::' . $serverName . '::' . $serverPort;

    # add language tag
    if ( $Foswiki::cfg{UserInterfaceInternationalisation} ) {
        my $language = $this->{session}->i18n->language();
        $variationKey .= "::language=$language" if $language;
    }

    # get information from the session object
    my $sessionValues = $session->getLoginManager()->getSessionValues();
    foreach my $key ( keys %$sessionValues ) {

        next
          if $key =~
/^(_.*|VALIDATION|REMEMBER|FOSWIKISTRIKEONE.*|VALID_ACTIONS.*|BREADCRUMB_TRAIL)$/o;

        writeDebug("adding session key=$key") if (TRACE);

        $sessionValues->{$key} = 'undef' unless defined $sessionValues->{$key};
        $variationKey .= "::$key=$sessionValues->{$key}";
    }

    foreach my $key ( $request->param() ) {

        # filter out some params that are not relevant
        next
          if $key =~
/^(_.*|refresh|foswiki_redirect_cache|logout|style.*|switch.*|topic)$/;
        my $val = $request->param($key);
        next unless $val;

        #$val =~ s/PAGECACHE_KEYSEP//g;
        $variationKey .= '::' . $key . '=' . $val;

        writeDebug("adding urlparam key=$key") if (TRACE);
    }

    writeDebug("variation key = '$variationKey'") if (TRACE);

    # cache it
    $this->{variationKey} = $variationKey;
    return $variationKey;
}

=begin TML

---++ ObjectMethod cachePage($contentType, $text) -> $boolean

Cache a html page. every page is stored in a page bucket
that contains all variations (stored for other users or other session
parameters) of this page, as well as dependency and expiration information

Note that the dependencies are fired in reverse order as the depending pages
have to notify this page if they changed. 

=cut

sub cachePage {

    my ( $this, $contentType, $text ) = @_;
    my $session = $this->{session};
    my $web     = $session->{webName};
    my $topic   = $session->{topicName};
    $web =~ s/\//./go;
    my $webTopic = $web . '.' . $topic;

    # delete page and all variations if we ask for a refresh copy
    my $refresh = $session->{request}->param('refresh') || '';
    my $variationKey = $this->genVariationKey();

    writeDebug("cachePage($web, $topic), variationKey='$variationKey'")
      if (TRACE);

    # remove old dependencies
    if ( $refresh =~ /^(all|on|cache)$/o ) {
        $this->_deletePage($webTopic);    # removes all variations
    }
    else {
        $this->_deleteDependency( $webTopic, $variationKey );
    }

    # assert newly autotetected dependencies
    $this->_setDependencies( $webTopic, $variationKey );

    # prepair page variation
    my $isDirty      = ( $text =~ /<dirtyarea[^>]*?>/ ) ? 1 : 0;
    my $etag         = '';
    my $lastModified = '';
    my $time         = time();

    unless ($isDirty) {
        $text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;

        if ( $Foswiki::cfg{HttpCompress} ) {
            require Compress::Zlib;
            $text = Compress::Zlib::memGzip($text);
        }
        $etag = $time;
        $lastModified = Foswiki::Time::formatTime( $time, '$http', 'gmtime' );
    }


    my $headers   = $session->{response}->headers();
    my $status    = $headers->{Status} || 200;
    my $variation = {
        contentType  => $contentType,
        lastModified => $lastModified,
        text         => $text,
        etag         => $etag,
        isDirty      => $isDirty,
        status       => $status,
    };
    $variation->{location} = $headers->{Location} if $status == 302;

    # get cache-expiry preferences and add it to the bucket if available
    my $expire = $this->{session}->{prefs}->getPreference('CACHEEXPIRE');
    $variation->{expire} = CGI::Util::expire_calc($expire)
      if defined $expire;

    # store page variation
    $this->{handler}
      ->set( PAGECACHE_PAGE_KEY . $webTopic . $variationKey, $variation );

    # remember this topic's variation key
    my $variations = $this->{handler}->get( PAGECACHE_VARS_KEY . $webTopic );
    my %variations = ();
    %variations = map { $_ => 1 } split( PAGECACHE_KEYSEP, $variations )
      if $variations;
    $variations{$variationKey} = 1;
    $variations = join( PAGECACHE_KEYSEP, keys %variations );
    $this->{handler}->set( PAGECACHE_VARS_KEY . $webTopic, $variations );

    return $variation;
}

=begin TML 

---++ ObjectMethod getPage($web, $topic)

Retrieve a html page for the given web.topic from cache, using a variation
key based on the current session.

=cut

sub getPage {
    my ( $this, $web, $topic ) = @_;

    $web =~ s/\//./go;
    my $webTopic = $web . '.' . $topic;

    # check url param
    my $session = $this->{session};
    my $refresh = $session->{request}->param('refresh') || '';
    if ( $refresh eq 'all' ) {

        # SMELL: restrict this to admins; put this somewhere else
        $this->{handler}->clear;
        return undef;
    }
    if ( $refresh =~ /on|cache|all/ ) {
        return undef;
    }

    # check cacheability
    return undef unless $this->_isCacheable($webTopic);

    writeDebug("getPage($web.$topic)") if (TRACE);

    # check availability
    my $variationKey = $this->genVariationKey();

    my $variation =
      $this->{handler}->get( PAGECACHE_PAGE_KEY . $webTopic . $variationKey );

    # check expiry date of this entry; return undef if it did expire, not deleted
    # from cache as it will be recomputed during a normal view cycle
    return undef
      if defined($variation)
          && defined( $variation->{expire} )
          && $variation->{expire} < time();

    return $variation;
}

# check if the current page is cacheable
#
# 1. check refresh url param
# 2. check CACHEABLE pref value
# 3. ask plugins what they think (e.g. the blacklist plugin may want
#    to prevent the blacklist message from being cached)
sub _isCacheable {
    my ( $this, $webTopic ) = @_;

    writeDebug("isCacheable($webTopic)") if (TRACE);

    my $isCacheable = $this->{isCacheable}{$webTopic};
    return $isCacheable if defined $isCacheable;

    writeDebug("... checking") if (TRACE);

    # by default we try to cache as much as possible
    $isCacheable = 1;

    # check prefs value
    my $flag = $this->{session}->{prefs}->getPreference('CACHEABLE');
    $isCacheable = 0 if defined $flag && !Foswiki::isTrue($flag);

    # TODO: give plugins a chance - create a callback

    writeDebug("isCacheable=$isCacheable") if (TRACE);
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
    return if $this->{session}->inContext('dirtyarea');

    $depWeb =~ s/\//\./go;
    my $depWebTopic = $depWeb . '.' . $depTopic;

    # exclude unwanted dependencies
    if ($depWebTopic =~ /^($Foswiki::cfg{Cache}{DependencyFilter})$/o) {
      writeDebug("dependency on $depWebTopic ignored by filter $Foswiki::cfg{Cache}{DependencyFilter}")
        if (TRACE);
      return;
    } else {
      writeDebug("addDependency($depWeb.$depTopic)") if (TRACE);
    }
  
    # collect them; defer writing them to the database til we cache this page
    $this->{deps}{$depWebTopic} = 1;
}

=begin TML 

---++ ObjectMethod getDependencies($web, $topic, $variationKey) -> \@deps

Return dependencies for a given web.topic

=cut

sub getDependencies {
    my ( $this, $web, $topic, $variationKey ) = @_;

    my @result = ();

    $web =~ s/\//./go;
    my $webTopic = $web . '.' . $topic;

    if ( defined $variationKey ) {

        # get only these

        my $deps = $this->_getDependencies( $webTopic, $variationKey );

        @result = split( PAGECACHE_KEYSEP, $deps ) if $deps;

    }
    else {

        # get them all

        my $variations =
          $this->{handler}->get( PAGECACHE_VARS_KEY . $webTopic );
        my %result = ();
        foreach my $variationKey ( split( PAGECACHE_KEYSEP, $variations ) ) {
            my $deps = $this->_getDependencies( $webTopic, $variationKey );
            foreach my $dep ( split( PAGECACHE_KEYSEP, $deps ) ) {
                $result{$dep} = 1;
            }
        }
        @result = keys %result;
    }

    return \@result;
}

# private implementation of getDependencies
sub _getDependencies {
    my ( $this, $webTopic, $variationKey ) = @_;

    return $this->{metaHandler}
      ->get( PAGECACHE_DEPS_KEY . $webTopic . $variationKey );
}

=begin TML 

---++ ObjectMethod getRevDependencies($web, $topic) -> \@deps

Return reverse dependencies for a given web.topic (those topics that
depend on this topic)

=cut

sub getRevDependencies {
    my ( $this, $web, $topic ) = @_;

    $web =~ s/\//./go;
    my $webTopic = $web . '.' . $topic;

    # get only these
    my $revDeps = $this->_getRevDependencies($webTopic);

    my @result = ();
    @result = split( PAGECACHE_KEYSEP, $revDeps ) if $revDeps;

    return \@result;
}

# private implementation of getRevDependencies
sub _getRevDependencies {
    my ( $this, $webTopic, ) = @_;

    return $this->{metaHandler}->get( PAGECACHE_REVDEPS_KEY . $webTopic );
}

=begin TML 

---++ ObjectMethod getWebDependencies($web) -> \@deps

Returns dependencies that hold for all topics in a web. 

=cut

sub getWebDependencies {
    my ( $this, $web ) = @_;

    unless ( defined $this->{webDeps} ) {
        my $webDeps =
             $this->{session}->{prefs}->getPreference( 'WEBDEPENDENCIES', $web )
          || $Foswiki::cfg{Cache}{WebDependencies}
          || '';

        $this->{webDeps} = ();

        # normalize topics
        foreach my $dep ( split( /\s*,\s*/, $webDeps ) ) {
            my ( $depWeb, $depTopic ) =
              $this->{session}->normalizeWebTopicName( $web, $dep );

            writeDebug("found webdep $depWeb.$depTopic") if (TRACE);
            $this->{webDeps}{ $depWeb . '.' . $depTopic } = 1;
        }
    }
    my @result = keys %{ $this->{webDeps} };
    return \@result;
}

# set the dependencies for the given web.topic topic
sub _setDependencies {
    my ( $this, $webTopic, $variationKey, @topicDeps ) = @_;

    @topicDeps = keys %{ $this->{deps} } unless @topicDeps;

    writeDebug( "setting "
          . scalar(@topicDeps)
          . " dependencies $webTopic\n"
          . join( "\n", @topicDeps ) )
      if (TRACE);

    $this->{metaHandler}->set(
        PAGECACHE_DEPS_KEY . $webTopic . $variationKey,
        join( PAGECACHE_KEYSEP, @topicDeps )
    );

    # assert autodetected dependencies in reverse logic
    foreach my $depWebTopic (@topicDeps) {
        next if $depWebTopic eq $webTopic;

        # merge
        my $revTopicDeps =
          $this->{metaHandler}->get( PAGECACHE_REVDEPS_KEY . $depWebTopic );
        my %revTopicDeps;
        if ($revTopicDeps) {
            %revTopicDeps =
              map { $_ => 1 } split( PAGECACHE_KEYSEP, $revTopicDeps );
            next if $revTopicDeps{ $webTopic . $variationKey };
        }
        $revTopicDeps{ $webTopic . $variationKey } = 1;
        $revTopicDeps = join( PAGECACHE_KEYSEP, keys %revTopicDeps );

        $this->{metaHandler}
          ->set( PAGECACHE_REVDEPS_KEY . $depWebTopic, $revTopicDeps );
    }
}

# remove all dependencies of a web.topic/variation
sub _deleteDependency {
    my ( $this, $webTopic, $variationKey ) = @_;

    my $topicDeps =
      $this->{metaHandler}
      ->get( PAGECACHE_DEPS_KEY . $webTopic . $variationKey );
    return unless $topicDeps;

    foreach my $depWebTopic ( split( PAGECACHE_KEYSEP, $topicDeps ) ) {
        my $revTopicDeps =
          $this->{metaHandler}->get( PAGECACHE_REVDEPS_KEY . $depWebTopic );
        next unless $revTopicDeps;

        # unmerge
        my %revTopicDeps =
          map { $_ => 1 } split( PAGECACHE_KEYSEP, $revTopicDeps );
        delete $revTopicDeps{$webTopic};
        $revTopicDeps = join( PAGECACHE_KEYSEP, keys %revTopicDeps );

        $this->{metaHandler}
          ->set( PAGECACHE_REVDEPS_KEY . $depWebTopic, $revTopicDeps );
    }

    $this->{metaHandler}
      ->delete( PAGECACHE_DEPS_KEY . $webTopic . $variationKey );
}

=begin TML 

---++ ObjectMethod deletePage($web, $topic)

Remove a page from the cache; this removes all of the information
that we have about this page 

=cut

sub deletePage {
    my ( $this, $web, $topic ) = @_;

    $web =~ s/\//./go;
    return $this->_deletePage( $web . '.' . $topic );
}

# internal implementation of deletePage()
# deletes all page variations and dependencies
sub _deletePage {
    my ( $this, $webTopic ) = @_;

    writeDebug("DELETE page $webTopic") if (TRACE);

    # get variation keys
    my $variations = $this->{handler}->get( PAGECACHE_VARS_KEY . $webTopic );
    return 0 unless $variations;

    # delete all variations
    foreach my $variationKey ( split( PAGECACHE_KEYSEP, $variations ) ) {
        $this->_deletePageVariation( $webTopic, $variationKey );
    }

    # delete registration entry for all variation keys
    $this->{handler}->delete( PAGECACHE_VARS_KEY . $webTopic );
}

# delete a dedicated page variation
sub _deletePageVariation {
    my ( $this, $webTopic, $variationKey ) = @_;

    writeDebug("deleting $webTopic variation '$variationKey'") if (TRACE);

    $this->{handler}->delete( PAGECACHE_PAGE_KEY . $webTopic . $variationKey );
    $this->_deleteDependency( $webTopic, $variationKey );
}

=begin TML 

---++ ObjectMethod fireDependency($web, $topic)

Fire a dependency invalidating the related cache entries.

=cut

sub fireDependency {
    my ( $this, $web, $topic ) = @_;

    $web =~ s/\//./go;
    my $webTopic = $web . '.' . $topic;

    writeDebug("FIRING $webTopic") if (TRACE);

    # delete all page variations the reverse dependencies point to
    my $revDeps = $this->_getRevDependencies($webTopic);
    if ($revDeps) {
        foreach my $revDep ( split( PAGECACHE_KEYSEP, $revDeps ) ) {
            if ( $revDep =~ /^(.*?)(::.*)$/ ) {
                $this->_deletePageVariation( $1, $2 );
            }
            else {

                #die "illegal format revDep=$revDep of $webTopic";
            }
        }
    }
    else {

        writeDebug("no rev deps found") if (TRACE);
    }

    # delete pages in WEBDEPENDENCIES
    foreach my $dep ( @{ $this->getWebDependencies($web) } ) {
        $this->_deletePage($dep);
    }

    # delete this page
    $this->_deletePage($webTopic);
}

=begin TML

---++ ObjectMethod renderDirtyAreas($text)

Extract dirty areas and render them; this happens after storing a 
page including the un-rendered dirty areas into the cache and after
retrieving it again.

=cut

sub renderDirtyAreas {
    my ( $this, $text ) = @_;

    writeDebug("renderDirtyAreas called text=$$text") if (TRACE);

    $this->{session}->enterContext('dirtyarea');

    # remember the current page length to recompute the content length below
    my $found    = 0;
    my $topicObj = new Foswiki::Meta(
        $this->{session},
        $this->{session}{webName},
        $this->{session}{topicName}
    );

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

    $this->{session}->leaveContext('dirtyarea');

    writeDebug("done renderDirtyAreas") if (TRACE);
}

# called by renderDirtyAreas() to process each dirty area in isolation
sub _handleDirtyArea {
    my ( $this, $args, $text, $topicObj ) = @_;

    writeDebug("_handleDirtyArea($args) called in text='$text'")
      if (TRACE);

    # add dirtyarea params
    my $params = new Foswiki::Attrs($args);
    my $prefs  = $this->{session}->{prefs};

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

    writeDebug("out text='$text'") if (TRACE);
    return $text;
}

=begin TML 

---++ ObjectMethod finish()

Break cyclic dependencies during destruction.

=cut

sub finish {
    my $this = shift;

    $this->{metaHandler}->finish(@_)
      if $this->{metaHandler};

    $this->{handler}->finish(@_)
      if $this->{handler};

    undef $this->{metaHandler};
    undef $this->{handler};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
