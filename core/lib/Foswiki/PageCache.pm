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
use Foswiki::Cache::DB_File;

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
    
    # store metadata in a separate store, i.e. one without size constraints
    metaHandler => new Foswiki::Cache::DB_File($session), 
  };

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
  $variationKey = $session->{request}->query_string() || '';
  
  # filter out some params that are not relevant
  $variationKey =~ s/(refresh|foswiki_redirect_cache|logout|style.*|switch.*|keywords)=[^&]*$//go;
  $variationKey =~ s/;$//o;

  # add server name and port by which the user has accessed the site
  $variationKey .= $ENV{SERVER_NAME}.':'.$ENV{SERVER_PORT};

  # add language tag
  my $language = $this->{session}->i18n->language();
  $variationKey .= ":language=$language" if $language;

  # get information from the session object 
  my $sessionValues  = $session->{users}->{loginManager}->getSessionValues();
  foreach my $key (keys %$sessionValues) {
    next if $key =~ /^BREADCRUMB_TRAIL$/o; # SMELL: this is a list of stuff that gets stored
    next if $key =~ /^VALIDATION$/o;       # in the session object that shall not distinguish
    next if $key =~ /^_SESSION_/o;         # pages in cache ... we need a standardized way to
    next if $key =~ /^REMEMBER$/o;         # filter that out
    next if $key =~ /^FOSWIKISTRIKEONE/o;  # secret key
    next if $key =~ /^VALID_ACTIONS/o;     # whatdat

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
  if ($refresh =~ /^(all|on|cache)$/o) {
    $this->_deletePage($webTopic);
  }

  # remove old reverse dependencies
  $this->_deleteDependency($webTopic);

  # assert autotetected dependencies
  $this->{metaHandler}->set('Foswiki::PageCache::Deps'.$webTopic, $this->{deps});

  # assert autodetected dependencies in reverse logic
  foreach my $depWebTopic (keys %{$this->{deps}}) {
    next if $depWebTopic eq $webTopic;
    my $topicDeps = $this->{metaHandler}->get('Foswiki::PageCache::RevDeps'.$depWebTopic);
    $topicDeps->{$webTopic} = 1;
    #writeDebug("adding rev dependency $webTopic <- $depWebTopic") unless $depWebTopic =~ /(Preferences|Plugin)$/;
    $this->{metaHandler}->set('Foswiki::PageCache::RevDeps'.$depWebTopic, $topicDeps);
  }

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
  my $variationKey = $this->genVariationKey();
  $this->{handler}->set('Foswiki::PageCache::'.$webTopic.'::'.$variationKey, $variation);

  # remember this topic's variation key
  my $variations = $this->{handler}->get('Foswiki::PageCache::'.$webTopic);
  $variations->{$variationKey} = 1;
  $this->{handler}->set('Foswiki::PageCache::'.$webTopic, $variations);

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
  if ($refresh eq 'on') {
    return undef;
  }

  # check cacheability
  return undef unless $this->isCacheable($web, $topic);

  #writeDebug("getPage($web.$topic)");

  # check availability
  my $variationKey = $this->genVariationKey();
  my $webTopic = $web.'.'.$topic;
  my $cachedPage = $this->{handler}->get('Foswiki::PageCache::'.$webTopic.'::'.$variationKey);
  return undef unless $cachedPage;
}

=pod 

remove a page from the cache; this removes all of the information
that we have about this page stored in its bucket

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

  # delete all variations
  my $variations = $this->{handler}->get('Foswiki::PageCache::'.$webTopic);
  return 0 unless $variations;

  foreach my $variationKey (keys %{$variations}) {
    $this->{handler}->delete('Foswiki::PageCache::'.$webTopic.'::'.$variationKey);
  }

  $this->{handler}->delete('Foswiki::PageCache::'.$webTopic);
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

TODO: don't use a separate web and topic argument, use a topicObject instead

=cut

sub addDependency {
  my ($this, $depWeb, $depTopic) = @_;

  return if $this->{session}->inContext('dirtyarea');

  $depWeb =~ s/\//\./go;
  my $depWebTopic = $depWeb.'.'.$depTopic;
  return if $this->{deps}{$depWebTopic}; # cosmetic

  #writeDebug("addDependency($depWebTopic)") unless $depWebTopic =~ /(Preferences|Plugin)$/;

  # collect them; defer writing them to the database til we cache this page
  $this->{deps}{$depWebTopic} = 1;
}

=pod 

return dependencies for a given web.topic

=cut

sub getDependencies {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  return $this->_getDependencies($web.'.'.$topic);
}

=pod

private implementation of getDependencies

=cut

sub _getDependencies {
  my ($this, $webTopic) = @_;

  #writeDebug("_getDependencies($webTopic)");

  my $topicDeps = $this->{metaHandler}->get('Foswiki::PageCache::Deps'.$webTopic);
  my @result = ();
  @result = keys %{$topicDeps} if $topicDeps;

  #writeDebug("topicDeps=".join(',',@result));

  return \@result;
}

=pod 

remove a web.topic dependency, i.e. the reverse ones

=cut

sub deleteDependencies {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  return $this->_deleteDependencies($web.'.'.$topic);
}

=pod 

private implementation of deleteDependencies

=cut

sub _deleteDependency {
  my ($this, $webTopic) = @_;
  
  my $topicDeps = $this->{metaHandler}->get('Foswiki::PageCache::Deps'.$webTopic);
  return unless $topicDeps;

  foreach my $depWebTopic (keys %$topicDeps) {
    #writeDebug("deleting dependency $depWebTopic") unless $depWebTopic =~ /(Preferences|Plugin)$/;
    $this->{metaHandler}->delete('Foswiki::PageCache::RevDeps'.$depWebTopic);
  }

  $this->{metaHandler}->delete('Foswiki::PageCache::Deps'.$webTopic);
}



=pod 

return reverse dependencies for a given web.topic

=cut

sub getRevDependencies {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  return $this->_getRevDependencies($web.'.'.$topic);
}


=pod

private implementation of getRevDependencies

=cut

sub _getRevDependencies {
  my ($this, $webTopic) = @_;

  #writeDebug("_getRevDependencies($webTopic)");

  my $topicDeps = $this->{metaHandler}->get('Foswiki::PageCache::RevDeps'.$webTopic);
  my @result = ();
  @result = keys %{$topicDeps} if $topicDeps;

  #writeDebug("topicDeps=".join(',',@result));

  return \@result;
}

=pod 

returns dependencies that hold for all topics in a web. 

=cut

sub getWebDependencies {
  my $this = shift;

  unless (defined $this->{webDeps}) {
    my $webDeps = $this->{session}->{prefs}->getPreference(
      'WEBDEPENDENCIES', $this->{session}->{webName}) || '';

    $this->{webDeps} = ();

    # normalize topics
    foreach my $dep (split(/\s*,\s*/, $webDeps)) {
      my ($depWeb, $depTopic) = 
        $this->{session}->normalizeWebTopicName($this->{session}->{webName}, $dep);
      #writeDebug("found webdep $depWeb.$depTopic");
      $this->{webDeps}{$depWeb.'.'.$depTopic} = 1;
    }
    
  }
  my @result = keys %{$this->{webDeps}};
  return \@result;
}

=pod 

fire a dependency invalidating the related cache entries

=cut

sub fireDependency {
  my ($this, $web, $topic) = @_;

  $web =~ s/\//./go;
  my $webTopic = $web.'.'.$topic;

  writeDebug("FIRING $webTopic");

  # delete pages in WEBDEPENDENCIES
  foreach my $dep (@{$this->getWebDependencies()}) {
    $this->_deletePage($dep);
  }

  # delete this page
  $this->_deletePage($webTopic);

  # delete all pages we are an ingredient of
  my $deps = $this->_getRevDependencies($webTopic);
  foreach my $dep (@$deps) {
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
  $this->{metaHandler}->finish(@_);
  $this->{handler}->finish(@_);
}

1;
