# See bottom of file for license and copyright information

package Foswiki::Plugins::EmptyJQueryPlugin::YOUR;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

use Foswiki::Plugins::EmptyJQueryPlugin (); # for version information

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

    my $this = bless(
        $class->SUPER::new(
            $session,
            name          => 'your',
	    # Use the version number from the Foswiki plugin; this keeps the
	    # version number in lock-step between the JQuery plugin and
	    # the Foswiki plugin.
            version       => $Foswiki::Plugins::EmptyJQueryPlugin::VERSION,
            author        => $Foswiki::Plugins::EmptyJQueryPlugin::AUTHOR,
            homepage      => 'JQuery module\'s URL',
            documentation => "$Foswiki::cfg{SystemWebName}.JQueryYour",
            puburl        => '%PUBURLPATH%/%SYSTEMWEB%/EmptyJQueryPlugin/your',
            javascript    => ['jquery.your.js']

              #    ,css => ['jquery.your.css']
        ),
        $class
    );

    return $this;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
