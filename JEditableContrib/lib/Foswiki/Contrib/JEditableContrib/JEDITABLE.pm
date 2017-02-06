# See bottom of file for license and copyright information
package Foswiki::Contrib::JEditableContrib::JEDITABLE;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Contrib::JEditableContrib     ();

=begin TML

---+ package Foswiki::Contrib::JEditableContrib::JEDITABLE

This is the perl stub for the jeditable plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = $class->SUPER::new(
        $session,
        name          => 'JEditable',
        version       => $Foswiki::Contrib::JEditableContrib::RELEASE,
        author        => 'Mika Tuupola',
        homepage      => 'http://www.appelsiini.net/projects/jeditable',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/JEditableContrib',
        documentation => "$Foswiki::cfg{SystemWebName}.JEditableContrib",
        summary       => $Foswiki::Contrib::JEditableContrib::SHORTDESCRIPTION,
        javascript    => ["jquery.jeditable.js"]
    );

    return $this;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2017 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
