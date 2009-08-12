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
  my $impl = $Foswiki::cfg{CacheManager} || 'Foswiki::Cache';
  if ($impl eq 'Foswiki::Cache' || $impl eq 'none' || !$Foswiki::cfg{Cache}{Enabled}) {
    $impl = 'Foswiki::Cache'; # dummy
    $Foswiki::cfg{Cache}{Enabled} = 0;
  }

  # try to get a shared instance of this class
  eval "use $impl";
  die $@ if $@;

  my $this = {
    session => $session,

    # store holding the main workload
    handler => $impl->new($session),
    
  };

  # store metadata in a separate store, i.e. one without size constraints
  my $metaImpl = $Foswiki::cfg{MetaCacheManager} || 'Foswiki::Cache::DB_File';
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
  $variationKey = '';
  foreach my $key ($request->param()) {
    # filter out some params that are not relevant
    # SMELL: needs docu
    next if $key =~ /^(_.*|refresh|foswiki_redirect_cache|logout|style.*|switch.*|topic)$/;
    $variationKey .= ':'.$key.'='.$request->param($key);
    #writeDebug("adding urlparam key=$key");
  }

  # add language tag
  my $language = $this->{session}->i18n->language();
  $variationKey .= ":language=$language" if $language;

  # get information from the session object 
  my $sessionValues  = $session->getLoginManager()->getSessionValues();
  foreach my $key (keys %$sessionValues) {
    # SMELL: docu this
    next if $key =~ /^(_.*|VALIDATION|REMEMBER|FOSWIKISTRIKEONE.*|VALID_ACTIONS.*|BREADCRUMB_TRAIL)$/o;
    #writeDebug("adding session key=$key");

    $sessionValues->{$key} = 'undef' unless defined $sessionValues->{$key};
    $variationKey .= ":$key=$sessionValues->{$key}";
  }

  #writeDebug("variation key = '$variationKey'");

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
  return 0 unless $Foswiki::cfg{Cache}{Enabled};

  my ($this, $contentType, $text) = @_;
  my $session = $this->{session};
  my $web = $session->{webName};
  my $topic = $session->{topicName};

  $web =~ s/\//./go;

  #writeDebug("cachePage($web, $topic)");

  # delete page and all variations if we ask for a refresh copy
  my $refresh = $session->{request}->param('refresh') || '';
  my $webTopic = $web.'.'.$topic;
  my $variationKey = $this->genVariationKey();

  if ($refresh =~ /^(all|on|cache)$/o) {
    $this->_deletePage($webTopic);
  } else {
    # remove old dependencies
    # SMELL: deletes _all_ dependencies, even if other variations establish more 
    # that we will do next
    $this->_deleteDependency($webTopic);
  }

  # assert autotetected dependencies
  $this->_setDependencies($webTopic);

  # store page
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


  my $variation = {
    contentType=>$contentType,
    lastModified=>$lastModified,
    text=>$text,
    etag=>$etag,
    isDirty=>$isDirty,
  };

  # store variation of this topic
  $this->{handler}->set(PAGECACHE_PAGE_KEY.$webTopic.'::'.$variationKey, $variation);

  # remember this topic's variation key
  my $variations = $this->{handler}->get(PAGECACHE_VARS_KEY.$webTopic);
  my %variations = ();
  %variations = map {$_ => 1} split(/,/, $variations) if $variations;
  $variations{$variationKey} = 1;
  $variations = join(',', keys %variations);
  $this->{handler}->set(PAGECACHE_VARS_KEY.$webTopic, $variations);

  return $variation;
}


=pod 

retrieve a html page for the current session from cache

=cut

sub getPage {

  return undef unless $Foswiki::cfg{Cache}{Enabled};
  my ($this, $web, $topic) = @_;
  $web =~ s/\//./go;

  # check url param
  my $session = $this->{session};
  my $refresh = $session->{request}->param('refresh') || '';
  if ($refresh eq 'all') {
    $this->{handler}->clear; # SMELL: restrict this to admins
    return undef;
  }
  if ($refresh =~ /on|cache/) {
    return undef;
  }

  # check cacheability
  return undef unless $this->isCacheable($web, $topic);

  #writeDebug("getPage($web.$topic)");

  # check availability
  my $variationKey = $this->genVariationKey();
  my $webTopic = $web.'.'.$topic;

  return $this->{handler}->get(PAGECACHE_PAGE_KEY.$webTopic.'::'.$variationKey);
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

=cut

sub _deletePage {
  my ($this, $webTopic) = @_;

  return 0 unless $Foswiki::cfg{Cache}{Enabled};

  #writeDebug("DELETE page $webTopic");

  # get variation keys
  my $variations = $this->{handler}->get(PAGECACHE_VARS_KEY.$webTopic);
  return 0 unless $variations;

  # delete all variations
  foreach my $variationKey (split(/,/, $variations)) {
    $this->{handler}->delete(PAGECACHE_PAGE_KEY.$webTopic.'::'.$variationKey);
  }

  # delete variation keys themselves
  $this->{handler}->delete(PAGECACHE_VARS_KEY.$webTopic);

  # delete all dependency records
  $this->_deleteDependency($webTopic);
}

=pod 

check if the current page is cacheable

1. check refresh url param
2. check CACHEABLE pref value
3. ask plugins what they think (e.g. the blacklist plugin may want
   to prevent the blacklist message from being cached)

=cut

sub isCacheable {
  my ($this, $web, $topic) = @_;

  return 0 unless $Foswiki::cfg{Cache}{Enabled};

  #writeDebug("isCacheable($web, $topic)");

  $web =~ s/\//./go;
  my $webTopic = $web.'.'.$topic;
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
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  my $deps = $this->_getDependencies($web.'.'.$topic);

  my @result = ();
  @result = split(/,/, $deps) if $deps;

  return \@result;
}

=pod

private implementation of getDependencies

=cut

sub _getDependencies {
  return $_[0]->{metaHandler}->get(PAGECACHE_DEPS_KEY.$_[1]);
}


=pod 

set the dependencies for the given web.topic topic

=cut

sub setDependencies {
  my $this = shift;
  my $web = shift;
  my $topic = shift;

  $web =~ s/\//./go;
  return $this->_setDependencies($web.'.'.$topic, @_);
}

=pod

private implementation of getDependencies

=cut

sub _setDependencies {
  my ($this, $webTopic, @topicDeps) = @_;

  @topicDeps = keys %{$this->{deps}} unless @topicDeps;
  #writeDebug("setting ".scalar(@topicDeps)." dependencies $webTopic");
  #writeDebug(join("\n", @topicDeps));

  $this->{metaHandler}->set(PAGECACHE_DEPS_KEY.$webTopic, join(',', @topicDeps));

  # assert autodetected dependencies in reverse logic
  foreach my $depWebTopic (@topicDeps) {
    next if $depWebTopic eq $webTopic;

    my $revTopicDeps = $this->{metaHandler}->get(PAGECACHE_REVDEPS_KEY.$depWebTopic);
    my %revTopicDeps;
    if ($revTopicDeps) {
      %revTopicDeps = map {$_ => 1} split(/,/, $revTopicDeps);
      next if $revTopicDeps{$webTopic};
    }

    $revTopicDeps{$webTopic} = 1;

    #writeDebug("adding rev dependency $webTopic <- $depWebTopic") unless $depWebTopic =~ /(Preferences|Plugin)$/;
    $revTopicDeps = join(',', keys %revTopicDeps);
    $this->{metaHandler}->set(PAGECACHE_REVDEPS_KEY.$depWebTopic, $revTopicDeps);
  }
}

=pod 

remove a web.topic dependency, i.e. the reverse ones

=cut

sub deleteDependencies {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  return $this->_deleteDependency($web.'.'.$topic);
}

=pod 

private implementation of deleteDependencies

=cut

sub _deleteDependency {
  my ($this, $webTopic) = @_;
  
  my $topicDeps = $this->{metaHandler}->get(PAGECACHE_DEPS_KEY.$webTopic);
  return unless $topicDeps;

  foreach my $depWebTopic (split(/,/, $topicDeps)) {
    $this->{metaHandler}->delete(PAGECACHE_REVDEPS_KEY.$depWebTopic);
  }

  $this->{metaHandler}->delete(PAGECACHE_DEPS_KEY.$webTopic);
}



=pod 

return reverse dependencies for a given web.topic

=cut

sub getRevDependencies {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  my $revDeps = $this->_getRevDependencies($web.'.'.$topic);

  my @result = ();
  @result = split(/,/, $revDeps) if $revDeps;

  return \@result;
}


=pod

private implementation of getRevDependencies

=cut

sub _getRevDependencies {
  return $_[0]->{metaHandler}->get(PAGECACHE_REVDEPS_KEY.$_[1]);
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

fire a dependency invalidating the related cache entries

=cut

sub fireDependency {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  my $webTopic = $web . '.' . $topic;

  #writeDebug("FIRING $webTopic");

  # delete pages in WEBDEPENDENCIES
  foreach my $dep (@{ $this->getWebDependencies($web) }) {
    $this->_deletePage($dep);
  }

  # delete this page
  $this->_deletePage($webTopic);

  # delete all pages we are an ingredient of
  my $revDeps = $this->_getRevDependencies($webTopic);
  foreach my $dep (split(/,/, $revDeps)) {
    $this->_deletePage($dep);
  }
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
