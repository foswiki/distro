# See bottom of file for license and copyright information
package Foswiki::Form::Rating;

use strict;
use warnings;

use Foswiki::Form::ListFieldDefinition ();
use Foswiki::Plugins::JQueryPlugin     ();
use Foswiki::Func                      ();
our @ISA = ('Foswiki::Form::ListFieldDefinition');

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    $this->{size} ||= 0;
    $this->{size} =~ s/\D//g;
    $this->{size} ||= 0;
    $this->{size} = 4 if ( $this->{size} < 1 );

    return $this;
}

sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{valueMap};
}

sub getOptions {
    my $this = shift;

    my $options = $this->{_options};
    return $options if $options;
    $options = $this->SUPER::getOptions();

    unless (@$options) {
        for ( my $i = 1 ; $i <= $this->{size} ; $i++ ) {
            push @$options, $i;
        }
        $this->{_options} = $options;
        return $options;
    }

    if ( $this->{type} =~ /\+values/ ) {
        $this->{valueMap} = ();
        $this->{_options} = ();
        my $str;
        foreach my $val (@$options) {
            if ( $val =~ /^(.*?[^\\])=(.*)$/ ) {
                $str = $1;
                $val = $2;
                $str =~ s/\\=/=/g;
            }
            else {
                $str = $val;
            }
            $this->{valueMap}{$val} = Foswiki::urlDecode($str);
            push @{ $this->{_options} }, $val;
        }
        $options = $this->{_options};
    }

    return $options;
}

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

    Foswiki::Plugins::JQueryPlugin::createPlugin("stars");

    my @vals    = ();
    my $options = $this->getOptions();
    foreach my $val (@$options) {
        if ( $this->{type} =~ /\+values/ && defined( $this->{valueMap}{$val} ) )
        {
            push @vals, '{"' . $val . '":"' . $this->{valueMap}{$val} . '"}';
        }
        else {
            push @vals, '"' . $val . '"';
        }
    }
    my $dataVals = '';
    $dataVals = join( ", ", @vals ) if @vals;

    my $result =
"<input type='hidden' autocomplete='off' name='$this->{name}' value='$value' class='jqStars {$this->{attributes}}' "
      . $dataVals . ">";

    return ( '', $result );
}

sub renderForDisplay {
    my ( $this, $format, $value, $attrs ) = @_;

    $format =~ s/\$value\(display\)/$this->renderDisplayValue($value)/ge;
    $format =~ s/\$value/$value/g;

    return $this->SUPER::renderForDisplay( $format, $value, $attrs );
}

sub renderDisplayValue {
    my ( $this, $value ) = @_;

    Foswiki::Plugins::JQueryPlugin::createPlugin("stars");

    my @htmlAttrs = ();

#    if (defined $this->{valueMap}) {
#      push @htmlAttrs, "data-values='[\"".join('", "', @{$this->getOptions()})."\"]";
#    }

    return
"<input type='hidden' disabled autocomplete='off' name='$this->{name}' value='$value' class='jqStars {$this->{attributes}}' "
      . join( " ", @htmlAttrs ) . ">";
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
