# See bottom of file for license and copyright information

#
# Data type for an perl constant rvalue. This is used for capturing values
# of collection types.
# The value must observe the following grammar:
# value :: array | hash | string ;
# array :: '[' value ( ',' value )* ']' ;
# hash  :: '{' keydef ( ',' keydef )* ']';
# keydef :: string '=>' value ;
# string ::= single quoted string, use \' to escape a quote, or \w+

package Foswiki::Configure::TypeUIs::PERL;

use strict;
use warnings;

use Foswiki::Configure qw/:cgi/;

require Foswiki::Configure::TypeUI;
our @ISA = ('Foswiki::Configure::TypeUI');

# Default options prior to prompt (and check)
#
sub defaultOptions {
    my ( $this, $value ) = @_;

    # Force textarea.  Default no spellcheck, autocheck
    my $size = $value->{SIZE} || $Foswiki::DEFAULT_FIELD_WIDTH_NO_CSS;

    if ( !defined $value->{SIZE} || $value->{SIZE} =~ /^\d+$/ ) {
        $value->{SIZE} = "${size}x10";
    }
    $value->set( opts => 'NOSPELLCHECK' )  unless $value->{SPELLCHECK};
    $value->set( opts => 'FEEDBACK=AUTO' ) unless $value->{FEEDBACK};
}

sub prompt {
    my ( $this, $model, $value, $class ) = @_;

    require Data::Dumper;

    my $d = Data::Dumper->new( [$value], ['x'] );
    $d->Sortkeys(1);
    my $v = $d->Dump;
    $v =~ s/^\$x = (.*);\s*$/$1/s;
    $v =~ s/^     //gm;

    return $this->SUPER::prompt( $model, $v, $class );
}

# verify that the string is a legal rvalue according to the grammar
sub _rvalue {
    my ( $s, $term ) = @_;
    while ( length($s) > 0 && ( !$term || $s !~ s/^\s*$term// ) ) {
        if ( $s =~ s/^\s*'//s ) {
            my $escaped = 0;
            while ( length($s) > 0 && $s =~ s/^(.)//s ) {
                last if ( $1 eq "'" && !$escaped );
                $escaped = ( $escaped ? 0 : $1 eq '\\' );
            }
        }
        elsif ( $s =~ s/^\s*(\w+)//s ) {
        }
        elsif ( $s =~ s/^\s*\[//s ) {
            $s = _rvalue( $s, ']' );
        }
        elsif ( $s =~ s/^\s*{//s ) {
            $s = _rvalue( $s, '}' );
        }
        elsif ( $s =~ s/^\s*(,|=>)//s ) {
        }
        else {
            last;
        }
    }
    return $s;
}

sub string2value {
    my ( $this, $val ) = @_;

    $val =~ s/^[[:space:]]+(.*?)$/$1/s;    # strip at start
    $val =~ s/^(.*?)[[:space:]]+$/$1/s;    # strip at end

    my $s;
    if ( $s = _rvalue($val) ) {

        # Unable to parse.  If configure is running
        # allow checker to handle diagnostic.
        return if ($Foswiki::configureRunning);

        # Parse failed, LSC is corrupt. Only way to report is die.
        $val = 'undef' unless ( defined $val );
        die "Types::PERL: Could not parse text to a data structure."
          . substr( $val, 0, length($val) - length($s) )
          . "<<<==== HERE" . "\n$s";
    }
    $val =~ /(.*)/s;    # parsed, so safe to untaint
    $val = eval $1;
    return $val if ( defined $val );
    return if ($Foswiki::configureRunning);
    die "Types::PERL: Parsed but invalid data: $@";
}

sub deep_equals {
    my ( $a, $b ) = @_;

    if ( !defined($a) && !defined($b) ) {
        return 1;
    }
    if ( !defined($a) || !defined($b) ) {
        return 0;
    }
    if ( ref($a) eq 'ARRAY' && ref($b) eq 'ARRAY' ) {
        return 0 unless scalar(@$a) == scalar(@$b);
        for ( 0 .. $#$a ) {
            return 0 unless deep_equals( $a->[$_], $b->[$_] );
        }
        return 1;
    }

    if ( ref($a) eq 'HASH' && ref($b) eq 'HASH' ) {
        return 0 unless scalar( keys %$a ) == scalar( keys %$b );
        for ( keys %$a ) {
            return 0 unless deep_equals( $a->{$_}, $b->{$_} );
        }
        return 1;
    }
    return $a eq $b;
}

sub equals {
    my ( $this, $val, $def ) = @_;

    return deep_equals( $val, $def );
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
