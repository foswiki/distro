# See bottom of file for license and copyright information

package Foswiki::Plugins::JQueryPlugin::VIEW;
use strict;
use warnings;

use Foswiki                                ();
use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = bless(
        $class->SUPER::new(
            $session,
            name         => 'View',
            version      => '1.0.7',
            author       => 'Boris Moore',
            homepage     => 'http://www.jsviews.com',
            dependencies => ['render'],
            javascript   => [
                'jquery.observable.uncompressed.js',
                'jquery.views.uncompressed.js'
            ],
        ),
        $class
    );

    return $this;
}

1;

__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2020 Foswiki Contributors. Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
