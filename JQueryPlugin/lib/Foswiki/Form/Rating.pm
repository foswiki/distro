# See bottom of file for license and copyright information
package Foswiki::Form::Rating;

use strict;
use warnings;

use Foswiki::Form::ListFieldDefinition ();
use Foswiki::Plugins::JQueryPlugin     ();
use Foswiki::Func                      ();
use JSON                               ();

our @ISA = ('Foswiki::Form::ListFieldDefinition');

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    my $options = $this->getOptions();
    if ( $options && @$options ) {
        $this->{size} = scalar(@$options);
    }
    else {
        $this->{size} ||= 0;
        $this->{size} =~ s/\D//g;
        $this->{size} ||= 0;
        $this->{size} = 5 if ( $this->{size} < 1 );
    }

    return $this;
}

sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{valueMap};
    undef $this->{json};
}

sub json {
    my $this = shift;

    unless ( $this->{json} ) {
        $this->{json} = JSON->new->allow_nonref;
    }

    return $this->{json};
}

sub getOptions {
    my $this = shift;

    my $options = $this->{_options};
    return $options if $options;
    $options = $this->SUPER::getOptions();

    unless ( $this->{valueMap} ) {

        # 2.0 does the value map for you in the superclass.
        if ( $this->{type} =~ m/\+values/ ) {
            $this->{valueMap} = ();
            $this->{_options} = ();
            my $str;
            foreach my $val (@$options) {
                if ( $val =~ m/^(.*?[^\\])=(.*)$/ ) {
                    $str = $1;
                    $val = $2;
                    $str =~ s/\\=/=/g;
                }
                else {
                    $str = $val;
                }
                $str =~ s/%([\da-f]{2})/chr(hex($1))/gei;
                $this->{valueMap}{$val} = $str;
                push @{ $this->{_options} }, $val;
            }
            $options = $this->{_options};
        }
    }

    return $options;
}

sub getDataValues {
    my $this = shift;

    my $options = $this->getOptions();
    my @vals    = ();

    foreach my $val (@$options) {
        if ( $this->{type} =~ m/\+values/
            && defined( $this->{valueMap}{$val} ) )
        {
            push @vals, { $this->{valueMap}{$val} => $val };
        }
        else {
            push @vals, $val;
        }
    }

    return '' unless @vals;
    return "data-values='" . $this->json->encode( \@vals ) . "'";
}

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

    Foswiki::Plugins::JQueryPlugin::createPlugin("stars");

    my $result =
"<input type='hidden' autocomplete='off' name='$this->{name}' value='$value' class='jqStars {$this->{attributes}}' "
      . "data-num-stars='"
      . $this->{size} . "' "
      . $this->getDataValues() . ">";

    return ( '', $result );
}

sub renderForDisplay {
    my ( $this, $format, $value, $attrs ) = @_;

    $format =~ s/\$value\(display\)/$this->getDisplayValue($value)/ge;
    $format =~ s/\$value/$value/g;

    return $this->SUPER::renderForDisplay( $format, $value, $attrs );
}

sub getDisplayValue {
    my ( $this, $value ) = @_;

    Foswiki::Plugins::JQueryPlugin::createPlugin("stars");

    my @htmlAttrs = ();

    $value = '' unless defined $value;

    return
"<input type='hidden' disabled autocomplete='off' name='$this->{name}' value='"
      . $value
      . "' class='jqStars {$this->{attributes}}' "
      . "data-num-stars='"
      . $this->{size} . "' "
      . $this->getDataValues() . ">";
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
