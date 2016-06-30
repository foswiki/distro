package Foswiki::Contrib::JEditableContrib::JEDITABLE;

use v5.14;

use Assert;

use Foswiki::Contrib::JEditableContrib ();

use Moo;
extends qw( Foswiki::Plugins::JQueryPlugin::Plugin );

our %pluginParams = (
    name          => 'JEditable',
    version       => $Foswiki::Contrib::JEditableContrib::RELEASE,
    author        => 'Mika Tuupola',
    homepage      => 'http://www.appelsiini.net/projects/jeditable',
    puburl        => '%PUBURLPATH%/%SYSTEMWEB%/JEditableContrib',
    documentation => "$Foswiki::cfg{SystemWebName}.JEditableContrib",
    summary       => $Foswiki::Contrib::JEditableContrib::SHORTDESCRIPTION,
    javascript    => [ "jquery.jeditable" . ( DEBUG ? "_src" : "" ) . ".js" ]
);

1;
