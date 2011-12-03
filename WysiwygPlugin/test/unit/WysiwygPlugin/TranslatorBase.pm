# See bottom of file for license and copyright information

package TranslatorBase;

# This is a base class for translator tests,
# intended as a mixin with FoswikiTestCase or a class derived from it

use strict;
use warnings;

# Bits for test type
# Fields in test records:
our $TML2HTML      = 1 << 0;    # test tml => html
our $HTML2TML      = 1 << 1;    # test html => finaltml (default tml)
our $ROUNDTRIP     = 1 << 2;    # test tml => => finaltml
our $CANNOTWYSIWYG = 1 << 3;    # test that notWysiwygEditable returns true
                                #   and make the ROUNDTRIP test expect failure

# Note: ROUNDTRIP is *not* the same as the combination of
# HTML2TML and TML2HTML. The HTML and TML comparisons are both
# somewhat "flexible". This is necessary because, for example,
# the nature of whitespace in the TML may change.
# ROUNDTRIP tests are intended to isolate gradual degradation
# of the TML, where TML -> HTML -> not quite TML -> HTML
# -> even worse TML, ad nauseum
#
# CANNOTWYSIWYG should normally be used in conjunction with ROUNDTRIP
# to ensure that notWysiwygEditable is consistent with this plugin's
# ROUNDTRIP capabilities.
#
# CANNOTWYSIWYG and ROUNDTRIP used together document the failure cases,
# i.e. they indicate TML that WysiwygPlugin cannot properly translate
# to HTML and back. When WysiwygPlugin is modified to support these
# cases, CANNOTWYSIWYG should be removed from each corresponding
# test case and nonWysiwygEditable should be updated so that the TML
# is "WysiwygEditable".
#
# Use CANNOTWYSIWYG without ROUNDTRIP *only* with an appropriate
# explanation. For example:
#   Can't ROUNDTRIP this TML because perl on the SMURF platform
#   automagically replaces all instances of 'blue' with 'beautiful'.

# Bit mask for selected test types
my $mask = $TML2HTML | $HTML2TML | $ROUNDTRIP | $CANNOTWYSIWYG;

our $protecton  = '<span class="WYSIWYG_PROTECTED">';
our $linkon     = '<span class="WYSIWYG_LINK">';
our $protectoff = '</span>';
our $linkoff    = '</span>';
our $nop        = "$protecton<nop>$protectoff";

sub gen_compare_tests {
    my $class  = shift;
    my $method = shift;
    my $data   = shift;
    my %picked = map { $_ => 1 } @_;
    for ( my $i = 0 ; $i < scalar(@$data) ; $i++ ) {
        my $datum = $data->[$i];
        if ( scalar(@_) ) {
            next unless ( $picked{ $datum->{name} } );
        }
        if ( ( $mask & $datum->{exec} ) & $TML2HTML ) {
            my $fn = $class . '::' . $method . 'TML2HTML_' . $datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareTML_HTML($datum) };
            use strict 'refs';
        }
        if ( ( $mask & $datum->{exec} ) & $HTML2TML ) {
            my $fn = $class . '::' . $method . 'HTML2TML_' . $datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareHTML_TML($datum) };
            use strict 'refs';
        }
        if ( ( $mask & $datum->{exec} ) & $ROUNDTRIP ) {
            my $fn = $class . '::' . $method . 'ROUNDTRIP_' . $datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareRoundTrip($datum) };
            use strict 'refs';
        }
        if ( ( $mask & $datum->{exec} ) & $CANNOTWYSIWYG ) {
            my $fn =
              $class . '::' . $method . 'CANNOTWYSIWYG_' . $datum->{name};
            no strict 'refs';
            *$fn =
              sub { my $this = shift; $this->compareNotWysiwygEditable($datum) };
            use strict 'refs';
        }
    }
}

sub compareTML_HTML {
    my ( $this, $args ) = @_;
    $this->assert( 0, ref($this) . " must override compareTML_HTML" );
}

sub compareNotWysiwygEditable {
    my ( $this, $args ) = @_;
    $this->assert( 0, ref($this) . " must override compareNotWysiwygEditable" );
}

sub compareRoundTrip {
    my ( $this, $args ) = @_;
    $this->assert( 0, ref($this) . " must override compareRoundTrip" );
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;
    $this->assert( 0, ref($this) . " must override compareHTML_TML" );
}

sub encode {
    my $s = shift;

    # used for debugging odd chars
    #    $s =~ s/([\000-\037])/'#'.ord($1)/ge;
    return $s;
}

sub assert_tml_equals {
    my ( $this, $expected, $actual, $name ) = @_;
    $expected ||= '';
    $actual   ||= '';
    $actual   =~ s/\n$//s;
    $expected =~ s/\n$//s;
    if ( $expected eq $actual ) {
        $this->assert(1);
    }
    else {
        my $expl =
            "==$name== Expected TML:\n"
          . encode($expected)
          . "\n==$name== Actual TML:\n"
          . encode($actual)
          . "\n==$name==\n";
        my $i = 0;
        while ( $i < length($expected) && $i < length($actual) ) {
            my $e = substr( $expected, $i, 1 );
            my $a = substr( $actual,   $i, 1 );
            if ( $a ne $e ) {
                $expl .= "<<==== HERE actual ";
                $expl .= ord($a) . " != expected " . ord($e) . "\n";
                last;
            }
            $expl .= $a;
            $i++;
        }
        $this->assert( 0, $expl . "\n" );
    }
}

sub assert_tml_not_equals {
    my ( $this, $expected, $actual, $name ) = @_;
    $expected ||= '';
    $actual   ||= '';
    $actual   =~ s/\n$//s;
    $expected =~ s/\n$//s;
    if ( $expected eq $actual ) {
        my $expl =
"==$name== Actual TML unexpectedly correct, remove \$CANNOTWYSIWYG flag:\n"
          . encode($actual)
          . "\n==$name==\n";
        $this->assert( 0, $expl . "\n" );
    }
    else {
        $this->assert(1);
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005 ILOG http://www.ilog.fr

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
