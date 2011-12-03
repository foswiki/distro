# See bottom of file for license and copyright information
package Foswiki::Configure::Types::REGEX;

use strict;
use warnings;

use Foswiki::Configure::Types::STRING ();
our @ISA = ('Foswiki::Configure::Types::STRING');

# SMELL:  Regex cleanup is also done in Foswiki/Configure/Valuer.pm sub _getValue
# If regex is growing due to perl stringification changes, this needs to be
# updated as well as here in string2value and equals.
# Note:  Perl 5.10 has use re qw(regexp_pattern); to decompile a pattern
#        my $pattern = regexp_pattern($val);

sub prompt {
    my ( $this, $id, $opts, $value, $class ) = @_;

    $value = '' unless defined($value);
    $value = "$value";

# disabling these lines because the value appears changed on the authorise screen
# while ( $value =~ s/^\(\?-xism:(.*)\)$/$1/ ) { }
# while ( $value =~ s/^\(\?\^:(.*)\)/$1/ ) { }
# $value =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;

    my $size = $Foswiki::DEFAULT_FIELD_WIDTH_NO_CSS;

    # percentage size should be set in CSS

    return CGI::textfield(
        -name     => $id,
        -size     => $size,
        -default  => $value,
        -onchange => 'valueChanged(this)',
        -class    => "foswikiInputField $class",
    );
}

sub string2value {
    my ( $this, $value ) = @_;
    while ( $value =~ s/^\(\?-xism:(.*)\)$/$1/ ) { }
    while ( $value =~ s/^\(\?\^:(.*)\)/$1/ )     { }
    return qr/$value/;
}

sub equals {
    my ( $this, $val, $def ) = @_;
    if ( !defined $val ) {
        return 0 if defined $def;
        return 1;
    }
    elsif ( !defined $def ) {
        return 0;
    }

    while ( $val =~ s/^\(\?-xism:(.*)\)$/$1/ ) { }
    while ( $def =~ s/^\(\?-xism:(.*)\)$/$1/ ) { }

    while ( $val =~ s/^\(\?\^:(.*)\)/$1/ ) { }
    while ( $def =~ s/^\(\?\^:(.*)\)/$1/ ) { }

    return $val eq $def;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
