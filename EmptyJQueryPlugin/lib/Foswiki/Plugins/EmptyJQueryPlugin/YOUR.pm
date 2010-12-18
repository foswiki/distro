# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# copyright for plugin and for jquery code
# license..

package Foswiki::Plugins::EmptyJQueryPlugin::YOUR;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::EmptyJQueryPlugin::YOUR

This is the perl stub for the jquery.your plugin.

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
    name => 'your',
    version => '0.0.1',
    author => 'The Author of the JQuery plugin',
    homepage => 'jq module\'s URL',
    documentation => "$Foswiki::cfg{SystemWebName}.JQueryYour",
    puburl => '%PUBURLPATH%/%SYSTEMWEB%/EmptyJQueryPlugin/your',
    javascript => ['jquery.your.js']
  ), $class);

  return $this;
}

1;
