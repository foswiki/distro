# See bottom of file for license and copyright information

package Foswiki::Extension::Empty;

use Foswiki::Class qw(extension);
extends qw(Foswiki::Extension);

use version 0.77; our $VERSION = version->declare(0.0.1);
our $API_VERSION = version->declare("2.99.0");

#extAfter qw(Sample);

#extBefore qw(Test1 Foswiki::Extension::Test2);

plugAfter 'Foswiki::Config::plugMethod' => sub {
    my $this = shift;
    my ($params) = @_;

    $this->_traceMsg(
        "This is plugMethod after processing. ",
        "The return value is ",
        (
            exists $params->{rc}
            ? ( defined $params->{rc} ? $params->{rc} : '*undef*' )
            : '*missing*'
        )
    );
    if ( defined $params->{rc} && ref( $params->{rc} ) eq 'ARRAY' ) {
        push @{ $params->{rc} }, 'Additional from ', __PACKAGE__;
    }
};

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
