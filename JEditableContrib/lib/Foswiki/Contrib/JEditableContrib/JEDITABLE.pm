package Foswiki::Contrib::JEditableContrib::JEDITABLE;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Contrib::JEditableContrib     ();

sub new {
    my $class   = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;
    my $src     = (DEBUG) ? '_src' : '';

    my $this = $class->SUPER::new(
        $session,
        name          => 'JEditable',
        version       => $Foswiki::Contrib::JEditableContrib::RELEASE,
        author        => 'Mika Tuupola',
        homepage      => 'http://www.appelsiini.net/projects/jeditable',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/JEditableContrib',
        documentation => "$Foswiki::cfg{SystemWebName}.JEditableContrib",
        summary       => $Foswiki::Contrib::JEditableContrib::SHORTDESCRIPTION,
        javascript    => ["jquery.jeditable${src}.js"]
    );

    return $this;
}

1;
