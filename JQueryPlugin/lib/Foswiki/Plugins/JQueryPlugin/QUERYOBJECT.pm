# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2006-2010 Blair Mitchelmore 
#   (blair DOT mitchelmore AT gmail DOT com) 
#   Licensed under the WTFPL (http://sam.zoy.org/wtfpl/).
#
# Packaged for Foswiki by Paul.W.Harvey@csiro.au - www.taxonomy.org.au

package Foswiki::Plugins::JQueryPlugin::QUERYOBJECT;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::QUERYOBJECT

This is the perl stub for the jquery.queryobject plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless($class->SUPER::new( 
    $session,
    name => 'QueryObject',
    version => '2.1.7',
    author => 'Blair Mitchelmore',
    homepage => 'http://plugins.jquery.com/project/query-object',
    javascript => ['jquery.queryobject.js']
  ), $class);

  return $this;
}

1;
