# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2009 Michael Daum, http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQueryPlugin::Plugin;
use Foswiki::Plugins::JQueryPlugin ();

use strict;

# static class properties
our @iconSearchPath;
our %iconCache;
our %plugins; # all singletons

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::Plugin

abstract class for a jQuery plugin

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

   * =$class=: Plugin class
   * =$session= : Foswiki object, defaults to =$Foswiki::Plugins::SESSION=
   * =...=: additional properties to be added to the object. i.e. 
      * =name => 'pluginName'= (default unknown)
      * =author => 'pluginAuthor'= (default unknown)
      * =version => 'pluginVersion'= (default unknown)
      * =summary => 'pluginSummary'= (default unknown)
      * =homepage => 'pluginHomepage'= (default unknown)
      * =debug => 0 or 1= (default =$Foswiki::cfg{JQueryPlugin}{Debug}=)

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless({
    session => $session,
    debug => $Foswiki::cfg{JQueryPlugin}{Debug} || 0,
    name => $class,
    author => 'unknown',
    version => 'unknown',
    summary => 'unknown',
    homepage => 'unknown',
    tags => '',
    @_
  }, $class);

  return $this;
}

=begin TML

---++ ClassMethod init()

add jQuery plugin to web and make sure all its dependencies 
are fulfilled

=cut

sub init {
  my $this = shift;

  return 0 if $this->{isActive};
  $this->{isActive} = 1;
  return 1;
}

=begin TML

---++ ClassMethod createPlugin( $this, $pluginName ) -> $plugin 

Helper method to establish plugin dependencies. See =load()=.

=cut

sub createPlugin {
  my $plugin = load(@_);
  $plugin->init() if $plugin;
  return $plugin;
}

=begin TML

---++ ClassMethod load ( $this, $pluginName ) -> $plugin

Loads a plugin and runs its initializer. 

parameters
   * =$pluginName=: name of plugin

returns
   * =$plugin=: returns the plugin object or false if instantiating
     the plugin failed

=cut

sub load {
  my ($this, $pluginName) = @_;

  # normalize plugin name
  my $normalizedName = $pluginName;
  $normalizedName = ucfirst(lc($normalizedName));

  return undef unless  
    $Foswiki::cfg{JQueryPlugin}{Plugins}{$normalizedName}{Enabled} ||
    $Foswiki::cfg{JQueryPlugin}{Plugins}{$pluginName}{Enabled};

  my $module = uc($pluginName);

  unless (defined $plugins{$module}) {
    my $packageName = 'Foswiki::Plugins::JQueryPlugin::'.$module;
    eval "use $packageName;";
    if ($@) {
      print STDERR "ERROR: can't load jQuery plugin $pluginName: $@\n";
      $plugins{$module} = 0;
    } else {
      $plugins{$module} = $packageName->new();
    }
  }

  return $plugins{$module};
}


=begin TML

---++ ClassMethod expandVariables( $format, %params) -> $string

Helper function to expand standard escape sequences =$percnt=, =$nop=,
=$n= and =$dollar=. 

   * =$format=: format string to be expaneded
   * =%params=: optional hash array containing further key-value pairs to be
     expanded as well, that is all occurences of =$key= will 
     be replaced by its =value= as defined in %params
   * =$string=: returns the resulting text 

=cut


sub expandVariables {
  my ($this, $format, %params) = @_;

  return '' unless $format;
  
  foreach my $key (keys %params) {
    my $val = $params{$key} || '';
    $format =~ s/\$$key\b/$val/g;
  }
  $format =~ s/\$percnt/\%/go;
  $format =~ s/\$nop//g;
  $format =~ s/\$n/\n/go;
  $format =~ s/\$dollar/\$/go;

  return $format;
}


=begin TML

---++ ClassMethod getIconUrlPath ( $iconName ) -> $pubUrlPath

Returns the path to the named icon searching along a given icon search path.
This path can be in =$Foswiki::cfg{JQueryPlugin}{IconSearchPath}= or will fall
back to =FamFamFamSilkIcons=, =FamFamFamSilkCompanion1Icons=,
=FamFamFamFlagIcons=, =FamFamFamMiniIcons=, =FamFamFamMintIcons= As you see
installing Foswiki:Extensions/FamFamFamContrib would be nice to have.

   = =$iconName=: name of icon; you will have to know the icon name by heart as listed in your
     favorite icon set, meaning there's no mapping between something like "semantic" and "physical" icons
   = =$pubUrlPath=: the path to the icon as it is attached somewhere in your wiki or the empty
     string if the icon was not found

=cut

sub getIconUrlPath {
  my ($this, $iconName) = @_;

  return '' unless $iconName;

  unless (@iconSearchPath) {
    my $iconSearchPath = 
      $Foswiki::cfg{JQueryPlugin}{IconSearchPath}
      || 'FamFamFamSilkIcons, FamFamFamSilkCompanion1Icons, FamFamFamFlagIcons, FamFamFamMiniIcons, FamFamFamMintIcons';
    @iconSearchPath = split(/\s*,\s*/, $iconSearchPath);
  }

  $iconName =~ s/^.*\.(.*?)$/$1/; # strip file extension

  my $iconPath = $iconCache{$iconName};

  unless ($iconPath) {
    my $iconWeb = $Foswiki::cfg{SystemWebName};
    my $pubSystemDir = $Foswiki::cfg{PubDir}.'/'.$Foswiki::cfg{SystemWebName};

    foreach my $item (@iconSearchPath) {
      my ($web, $topic) = 
        Foswiki::Func::normalizeWebTopicName($Foswiki::cfg{SystemWebName}, $item);

      # SMELL: store violation assumes the we have got file-level access
      # better use store api
      my $iconDir = $Foswiki::cfg{PubDir}.'/'.$web.'/'.$topic.'/'.$iconName.'.png';
      if (-f $iconDir) {
        $iconPath = Foswiki::Func::getPubUrlPath().'/'.$web.'/'.$topic.'/'.$iconName.'.png';
        last; # first come first serve
      }
    }
   
    $iconPath ||= '';
    $iconCache{$iconName} = $iconPath;
  }

  return $iconPath;
}

=begin TML

---++ ClassMethod getPlugins () -> @plugins

returns a list of all known plugins

=cut

sub getPlugins {
  my $this = shift;

  my @plugins = ();
  foreach my $pluginName (sort keys %{$Foswiki::cfg{JQueryPlugin}{Plugins}}) {
    my $plugin = $this->load($pluginName);
    push @plugins, $plugin if $plugin;
  }

  return @plugins;
}

1;
