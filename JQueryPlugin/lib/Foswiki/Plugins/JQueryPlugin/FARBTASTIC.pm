# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::FARBTASTIC;
use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::FARBTASTIC

This is the perl stub for the jquery.farbtastic plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name     => 'Farbtastic',
            version  => '1.2',
            author   => 'Steven Wittens',
            homepage => 'http://acko.net/dev/farbtastic',
            css      => ['jquery.farbtastic.css'],
            javascript =>
              [ 'jquery.farbtastic.js', 'jquery.farbtastic.init.js' ],
            dependencies => [ 'ui', 'metadata', 'livequery' ],
        ),
        $class
    );

    return $this;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
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
