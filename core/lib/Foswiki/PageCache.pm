# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
#
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod
---+ package Foswiki::PageCache

Foswiki::PageCache interface

=cut

package Foswiki::PageCache;

use strict;
use Foswiki::Cache;
use Foswiki::Time;
use Foswiki::Attrs;
use Error qw( :try );

use constant PAGECACHE_PAGE_KEY => 'Foswiki::PageCache::';
use constant PAGECACHE_VARS_KEY => 'Foswiki::PageCache::Vars::';
use constant PAGECACHE_DEPS_KEY => 'Foswiki::PageCache::Deps::';
use constant PAGECACHE_REVDEPS_KEY => 'Foswiki::PageCache::RevDeps::';
use constant PAGECACHE_KEYSEP => "\0";

# static poor man's debugging tools
sub writeDebug {
  print STDERR "Foswiki::PageCache - $_[0]\n" if $Foswiki::cfg{Cache}{Debug};
}

=pod 

---++ ClassMethod new( $session ) -> $object

Construct a new page cache and a delegator.

=cut

sub new {
  my ($class, $session) = @_;

  #writeDebug("new PageCache");
  my $impl = $Foswiki::cfg{CacheManager} || 'Foswiki::Cache::BDB';

  # try to get a shared instance of this class
  eval "use $impl";
  die $@ if $@;

  my $this = {
    session => $session,
    handler => $impl->new($session),
  };

  # store metadata in a separate store, i.e. one without size constraints
  my $metaImpl = $Foswiki::cfg{MetaCacheManager} || 'Foswiki::Cache::BDB';

  if ($metaImpl ne $impl) {
    eval "use $metaImpl";
    die $@ if $@;
    $this->{metaHandler} = $metaImpl->new($session), 
  } else {
    $this->{metaHandler} = $this->{handler};
  }

  return bless($this, $class);
}

=pod 

---++ ObjectMethod genVariationKey() -> $key

method to generate a key for the current webtopic being produced; this reads
information from the current session and url params

=cut

sub genVariationKey {
  my $this = shift;

  my $variationKey = $this->{variationKey};
  return $variationKey if defined $variationKey;

  my $session = $this->{session};
  my $request = $session->{request};
  my $serverName = $request->server_name || $Foswiki::cfg{DefaultUrlHost};
  my $serverPort = $request->server_port || 80;
  $variationKey = '::'.$serverName.'::'.$serverPort;

  # add language tag
  my $language = $this->{session}->i18n->language();
  $variationKey .= "::language=$language" if $language;

  # get information from the session object 
  my $sessionValues  = $session->getLoginManager()->getSessionValues();
  foreach my $key (keys %$sessionValues) {
    # SMELL: docu this
    next if $key =~ /^(_.*|VALIDATION|REMEMBER|FOSWIKISTRIKEONE.*|VALID_ACTIONS.*|BREADCRUMB_TRAIL)$/o;
    #writeDebug("adding session key=$key");

    $sessionValues->{$key} = 'undef' unless defined $sessionValues->{$key};
    $variationKey .= "::$key=$sessionValues->{$key}";
  }

  foreach my $key ($request->param()) {
    # filter out some params that are not relevant
    # SMELL: needs docu
    next if $key =~ /^(_.*|refresh|foswiki_redirect_cache|logout|style.*|switch.*|topic)$/;
    my $val = $request->param($key);
    next unless $val;
    #$val =~ s/PAGECACHE_KEYSEP//g;
    $variationKey .= '::'.$key.'='.$val;
    #writeDebug("adding urlparam key=$key");
  }

  #writeDebug("variation key = '$variationKey'");

  # cache it
  $this->{variationKey} = $variationKey;
  return $variationKey;
}

=pod

---++ ObjectMethod cachePage($contentType, $text) -> $boolean

Cache a html page. every page is stored in a page bucket
that contains all variations (stored for other users or other session parameters)
of this page, as well as dependency and expiration information

Note, that the dependencies are fired in reverse logic as the depending pages
have to notify this page if they changed. 

=cut

sub cachePage {

  my ($this, $contentType, $text) = @_;
  my $session = $this->{session};
  my $web = $session->{webName};
  my $topic = $session->{topicName};
  $web =~ s/\//./go;
  my $webTopic = $web.'.'.$topic;

  # delete page and all variations if we ask for a refresh copy
  my $refresh = $session->{request}->param('refresh') || '';
  my $variationKey = $this->genVariationKey();
  
  writeDebug("cachePage($web, $topic), variationKey='$variationKey'");

  # remove old dependencies
  if ($refresh =~ /^(all|on|cache)$/o) {
    $this->_deletePage($webTopic); # removes all variations 
  } else {
    $this->_deleteDependency($webTopic, $variationKey);
  }

  # assert newly autotetected dependencies
  $this->_setDependencies($webTopic, $variationKey);

  # prepair page variation
  my $isDirty = ($text =~ /<dirtyarea[^>]*?>/)?1:0;
  my $etag = '';
  my $lastModified = '';
  my $time = time();

  unless ($isDirty) {
    $text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;
    if ($Foswiki::cfg{Cache}{Compress}) {
      require Compress::Zlib;
      $text = Compress::Zlib::memGzip($text) 
    }
    $etag = $time;
    $lastModified = Foswiki::Time::formatTime($time, 'http', 'gmtime');
  }

  my $headers = $session->{response}->headers();
  my $status = $headers->{Status} || 200;
  my $variation = {
    contentType=>$contentType,
    lastModified=>$lastModified,
    text=>$text,
    etag=>$etag,
    isDirty=>$isDirty,
    status=>$status,
  };
  $variation->{location} = $headers->{Location} if $status == 302;

  # store page variation 
  $this->{handler}->set(PAGECACHE_PAGE_KEY.$webTopic.$variationKey, $variation);

  # remember this topic's variation key
  my $variations = $this->{handler}->get(PAGECACHE_VARS_KEY.$webTopic);
  my %variations = ();
  %variations = map {$_ => 1} split(PAGECACHE_KEYSEP, $variations) if $variations;
  $variations{$variationKey} = 1;
  $variations = join(PAGECACHE_KEYSEP, keys %variations);
  $this->{handler}->set(PAGECACHE_VARS_KEY.$webTopic, $variations);

  return $variation;
}


=pod 

retrieve a html page for the current session from cache

=cut

sub getPage {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  my $webTopic = $web.'.'.$topic;

  # check url param
  my $session = $this->{session};
  my $refresh = $session->{request}->param('refresh') || '';
  if ($refresh eq 'all') {
    $this->{handler}->clear; # SMELL: restrict this to admins; put this somewhere else
    return undef;
  }
  if ($refresh =~ /on|cache|all/) {
    return undef;
  }

  # check cacheability
  return undef unless $this->_isCacheable($webTopic);

  #writeDebug("getPage($web.$topic)");

  # check availability
  my $variationKey = $this->genVariationKey();

  return $this->{handler}->get(PAGECACHE_PAGE_KEY.$webTopic.$variationKey);
}

=pod 

check if the current page is cacheable

1. check refresh url param
2. check CACHEABLE pref value
3. ask plugins what they think (e.g. the blacklist plugin may want
   to prevent the blacklist message from being cached)

=cut

sub _isCacheable {
  my ($this, $webTopic) = @_;

  #writeDebug("isCacheable($webTopic)");

  my $isCacheable = $this->{isCacheable}{$webTopic};
  return $isCacheable if defined $isCacheable;

  #writeDebug("... checking");

  # by default we try to cache as much as possible
  $isCacheable = 1;

  # check prefs value
  my $flag = $this->{session}->{prefs}->getPreference('CACHEABLE');
  $isCacheable = 0 if defined $flag && !Foswiki::isTrue($flag);

  # TODO: give plugins a chance - create a callback

  #writeDebug("isCacheable=$isCacheable");
  $this->{isCacheable}{$webTopic} = $isCacheable;
  return $isCacheable;
}

=pod

add a web.topic to the dependencies of the current page

=cut

sub addDependency {
  my ($this, $depWeb, $depTopic) = @_;

  # exclude invalid topic names
  return unless $depTopic =~ /^[$Foswiki::regex{upperAlpha}]/o;

  # omit dependencies triggered from inside a dirtyarea
  return if $this->{session}->inContext('dirtyarea');

  $depWeb =~ s/\//\./go;
  my $depWebTopic = $depWeb.'.'.$depTopic;

  # exclude unwanted dependencies
  return if $depWebTopic =~ /^($Foswiki::cfg{Cache}{DependencyFilter})$/o;

  # collect them; defer writing them to the database til we cache this page
  $this->{deps}{$depWebTopic} = 1;
}

=pod 

return dependencies for a given web.topic

=cut

sub getDependencies {
  my ($this, $web, $topic, $variationKey) = @_;

  my @result = ();

  $web =~ s/\//./go;
  my $webTopic = $web.'.'.$topic;

  if (defined $variationKey) {
    # get only these

    my $deps = $this->_getDependencies($webTopic, $variationKey);

    @result = split(PAGECACHE_KEYSEP, $deps) if $deps;

  } else  {
    # get them all

    my $variations = $this->{handler}->get(PAGECACHE_VARS_KEY.$webTopic);
    my %result = ();
    foreach my $variationKey (split(PAGECACHE_KEYSEP, $variations)) {
      my $deps = $this->_getDependencies($webTopic, $variationKey);
      foreach my $dep (split(PAGECACHE_KEYSEP, $deps)) {
        $result{$dep} = 1;
      }
    }
    @result = keys %result;
  }

  return \@result;
}

=pod

private implementation of getDependencies

=cut

sub _getDependencies {
  my ($this, $webTopic, $variationKey) = @_;

  return $this->{metaHandler}->get(PAGECACHE_DEPS_KEY.$webTopic.$variationKey);
}

=pod 

return reverse dependencies for a given web.topic

=cut

sub getRevDependencies {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  my $webTopic = $web.'.'.$topic;

  # get only these
  my $revDeps = $this->_getRevDependencies($webTopic);

  my @result = ();
  @result = split(PAGECACHE_KEYSEP, $revDeps) if $revDeps;

  return \@result;
}


=pod

private implementation of getRevDependencies

=cut

sub _getRevDependencies {
  my ($this, $webTopic, ) = @_;

  return $this->{metaHandler}->get(PAGECACHE_REVDEPS_KEY.$webTopic);
}

=pod 

returns dependencies that hold for all topics in a web. 

=cut

sub getWebDependencies {
  my ($this, $web) = @_;

  unless (defined $this->{webDeps}) {
    my $webDeps = $this->{session}->{prefs}->getPreference('WEBDEPENDENCIES', $web)
      || $Foswiki::cfg{Cache}{WebDependencies}
      || '';

    $this->{webDeps} = ();

    # normalize topics
    foreach my $dep (split(/\s*,\s*/, $webDeps)) {
      my ($depWeb, $depTopic) = $this->{session}->normalizeWebTopicName($web, $dep);

      #writeDebug("found webdep $depWeb.$depTopic");
      $this->{webDeps}{ $depWeb . '.' . $depTopic } = 1;
    }
  }
  my @result = keys %{ $this->{webDeps} };
  return \@result;
}



=pod

set the dependencies for the given web.topic topic

=cut

sub _setDependencies {
  my ($this, $webTopic, $variationKey, @topicDeps) = @_;

  @topicDeps = keys %{$this->{deps}} unless @topicDeps;
  #writeDebug("setting ".scalar(@topicDeps)." dependencies $webTopic");
  #writeDebug(join("\n", @topicDeps));

  $this->{metaHandler}->set(PAGECACHE_DEPS_KEY.$webTopic.$variationKey, join(PAGECACHE_KEYSEP, @topicDeps));

  # assert autodetected dependencies in reverse logic
  foreach my $depWebTopic (@topicDeps) {
    next if $depWebTopic eq $webTopic;

    # merge 
    my $revTopicDeps = $this->{metaHandler}->get(PAGECACHE_REVDEPS_KEY.$depWebTopic);
    my %revTopicDeps;
    if ($revTopicDeps) {
      %revTopicDeps = map {$_ => 1} split(PAGECACHE_KEYSEP, $revTopicDeps);
      next if $revTopicDeps{$webTopic.$variationKey};
    }
    $revTopicDeps{$webTopic.$variationKey} = 1;
    $revTopicDeps = join(PAGECACHE_KEYSEP, keys %revTopicDeps);

    $this->{metaHandler}->set(PAGECACHE_REVDEPS_KEY.$depWebTopic, $revTopicDeps);
  }
}

=pod 

remove all dependencies of a web.topic/variation 

=cut

sub _deleteDependency {
  my ($this, $webTopic, $variationKey) = @_;

  my $topicDeps = $this->{metaHandler}->get(PAGECACHE_DEPS_KEY.$webTopic.$variationKey);
  return unless $topicDeps;

  foreach my $depWebTopic (split(PAGECACHE_KEYSEP, $topicDeps)) {
    my $revTopicDeps = $this->{metaHandler}->get(PAGECACHE_REVDEPS_KEY.$depWebTopic);
    next unless $revTopicDeps;

    # unmerge
    my %revTopicDeps= map {$_ => 1} split(PAGECACHE_KEYSEP, $revTopicDeps);
    delete $revTopicDeps{$webTopic};
    $revTopicDeps = join(PAGECACHE_KEYSEP, keys %revTopicDeps);

    $this->{metaHandler}->set(PAGECACHE_REVDEPS_KEY.$depWebTopic, $revTopicDeps);
  }

  $this->{metaHandler}->delete(PAGECACHE_DEPS_KEY.$webTopic.$variationKey);
}

=pod 

remove a page from the cache; this removes all of the information
that we have about this page 

=cut

sub deletePage {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  return $this->_deletePage($web.'.'.$topic);
}

=pod

internal implementation of deletePage()

deletes all page variations and dependencies

=cut

sub _deletePage {
  my ($this, $webTopic) = @_;

  writeDebug("DELETE page $webTopic");

  # get variation keys
  my $variations = $this->{handler}->get(PAGECACHE_VARS_KEY.$webTopic);
  return 0 unless $variations;

  # delete all variations
  foreach my $variationKey (split(PAGECACHE_KEYSEP, $variations)) {
    $this->_deletePageVariation($webTopic, $variationKey);
  }

  # delete registration entry for all variation keys 
  $this->{handler}->delete(PAGECACHE_VARS_KEY.$webTopic);
}

=pod

delete a dedicated page variation

=cut

sub _deletePageVariation {
  my ($this, $webTopic, $variationKey) = @_;

  writeDebug("deleting $webTopic variation '$variationKey'");

  $this->{handler}->delete(PAGECACHE_PAGE_KEY.$webTopic.$variationKey);
  $this->_deleteDependency($webTopic, $variationKey);
}

=pod 

fire a dependency invalidating the related cache entries

=cut

sub fireDependency {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  my $webTopic = $web . '.' . $topic;

  writeDebug("FIRING $webTopic");

  # delete all page variations the reverse dependencies point to
  my $revDeps = $this->_getRevDependencies($webTopic);
  if ($revDeps) {
    foreach my $revDep (split(PAGECACHE_KEYSEP, $revDeps)) {
      if ($revDep =~ /^(.*?)(::.*)$/) {
        $this->_deletePageVariation($1, $2);
      } else {
        #die "illegal format revDep=$revDep of $webTopic";
      }
    }
  } else {
    #writeDebug("no rev deps found");
  }

  # delete pages in WEBDEPENDENCIES
  foreach my $dep (@{ $this->getWebDependencies($web) }) {
    $this->_deletePage($dep);
  }

  # delete this page
  $this->_deletePage($webTopic);
}

=pod

extract dirty areas and render them; this happens after storing a 
page including the un-rendered dirty areas into the cache and after
retrieving it again

=cut

sub renderDirtyAreas {
  my ($this, $text) = @_;

  #writeDebug("renderDirtyAreas called");
  #writeDebug("text=$$text");
  $this->{session}->enterContext('dirtyarea');

  # remember the current page length to recompute the content length below
  my $found = 0;
  my $topicObj = new Foswiki::Meta($this->{session}, $this->{session}{webName}, $this->{session}{topicName});

  # expand dirt
  while ($$text =~ s/<dirtyarea([^>]*?)>(?!.*<dirtyarea)(.*?)<\/dirtyarea>/$this->_handleDirtyArea($1, $2, $topicObj)/geos) {
    $found = 1;
  }

  $$text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis if $found;

  # remove any dirtyarea leftovers
  $$text =~ s/<\/?dirtyarea>//go;

  $this->{session}->leaveContext('dirtyarea');

  #writeDebug("done renderDirtyAreas");
}

=pod

called by renderDirtyAreas() to process each dirty area in isolation

=cut

sub _handleDirtyArea {
  my ($this, $args, $text, $topicObj) = @_;

  #writeDebug("_handleDirtyArea($web, $topic, $args) called");
  #writeDebug("in text='$text'");

  # add dirtyarea params
  my $params = new Foswiki::Attrs($args);
  my $prefs = $this->{session}->{prefs};

  $prefs->pushTopicContext($topicObj->web, $topicObj->topic);
  $params->remove('_RAW');
  $prefs->setSessionPreferences(%$params);
  try {
    $text = $topicObj->expandMacros($text);
    $text = $topicObj->renderTML($text);
  };
  finally {
    $prefs->popTopicContext();
  };
  
  #writeDebug("out text='$text'");
  return $text;
}

=pod 

finish the cache impl

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
