package Foswiki::Contrib::JEditableAddOn::JEDITABLE;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Contrib::JEditableAddOn ();

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;
	
    my $this = $class->SUPER::new( 
	$session,
	name          => 'JEditable',
	version       => $Foswiki::Contrib::JEditableAddOn::RELEASE,
	author        => 'Mika Tuupola',
	homepage      => 'http://www.appelsiini.net/projects/jeditable',
	puburl        => '%PUBURLPATH%/%SYSTEMWEB%/JEditableAddOn',
	documentation => "$Foswiki::cfg{SystemWebName}.JEditableAddOn",
	summary       => $Foswiki::Contrib::JEditableAddOn::SHORTDESCRIPTION,
	javascript    => [ "jquery.jeditable.js" ]);
    
    return $this;
}

1;
