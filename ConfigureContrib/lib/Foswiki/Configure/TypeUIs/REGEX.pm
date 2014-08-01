# See bottom of file for license and copyright information
package Foswiki::Configure::TypeUIs::REGEX;

use strict;
use warnings;

use Foswiki::Configure::TypeUIs::STRING ();
our @ISA = ('Foswiki::Configure::TypeUIs::STRING');

# Default options prior to prompt (and check)
#
sub defaultOptions {
    my ( $this, $value ) = @_;
    $value->set( opts => 'FEEDBACK=AUTO' ) unless $value->{FEEDBACK};
}

# SMELL:  Regex cleanup is also done in Foswiki/Configure/Valuer.pm sub _getValue
# If regex is growing due to perl stringification changes, this needs to be
# updated as well as here in string2value and equals.
# Note:  Perl 5.10 has use re qw(regexp_pattern); to decompile a pattern
#        my $pattern = regexp_pattern($val);

sub prompt {
    my ( $this, $model, $value, $class ) = @_;

    $value = '' unless defined($value);
    $value = "$value";

# disabling these lines because the value appears changed on the authorise screen
# while ( $value =~ s/^\(\?-xism:(.*)\)$/$1/ ) { }
# while ( $value =~ s/^\(\?\^:(.*)\)/$1/ ) { }
# $value =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;

    my $size = $Foswiki::DEFAULT_FIELD_WIDTH_NO_CSS;

    # percentage size should be set in CSS

    return CGI::textfield(
        -name     => $model->{keys},
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
    my $re = eval "qr/\$value/";
    return $value if ($@);    # Return input if invalid
    return $re;
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

### Retained for documentation ###

=begin TML
---++ ClassMethod makeChecker( $item, $keys )

Instantiates a default (Foswiki::Configure::Checkers::REGEX) checker for this type
and binds it to this item.

Invoked when an item has no item-specific checker.

$item is the UI configuration item being processed
$keys are the %Foswiki::cfg hash keys (E.g. '{Module}{FooRegex}') for this item.

This is left as an example of how one can write a makeChecker method.  It is not required,
since it implements the (new) default behavior of the UI, which also handles inheritance.

makeChecker is still invoked if present, for compatibility and to allow for non-default mappings
of typename to checkername.

=cut

sub makeChecker {
    my $type = shift;

    my $class = ref( $type );
    $class =~ s/^Foswiki::Configure::TypeUIs::/Foswiki::Configure::Checkers::/ or die "Can't makeChecker for $class\n";

    eval "require $class;";
    die "Unable to makeChecker for ${class}:$@\n" if( $@ );
    return $class->new(@_);
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
