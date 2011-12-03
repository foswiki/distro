# See bottom of file for license and copyright information
package Foswiki::Form::Rating;

use strict;
use warnings;

use Foswiki::Form::ListFieldDefinition ();
use Foswiki::Plugins::JQueryPlugin     ();
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
    my $this = shift;

    # get args in a backwards compatible manor:
    my $metaOrWeb = shift;

    my $meta;
    my $web;
    my $topic;

    if ( ref($metaOrWeb) ) {

        # new: $this, $meta, $value
        $meta  = $metaOrWeb;
        $web   = $meta->web;
        $topic = $meta->topic;
    }
    else {

        # old: $this, $web, $topic, $value
        $web   = $metaOrWeb;
        $topic = shift;
        ( $meta, undef ) = Foswiki::Func::readTopic( $web, $topic );
    }

    my $value = shift;

    Foswiki::Plugins::JQueryPlugin::createPlugin("rating");

    my $result = "<div class='jqRating {$this->{attributes}}'>\n";
    my $found  = 0;

    foreach my $item ( @{ $this->getOptions() } ) {

        $result .=
            '<input type="radio" autocomplete="off" name="'
          . $this->{name} . '" '
          . ' value="'
          . $item . '" ';

        $result .= 'title="' . $this->{valueMap}{$item} . '" '
          if defined $this->{valueMap}{$item};

        my $isNumeric = ( $value =~ /[^\-\+\.\d]|^$/ ) ? 0 : 1;

        # value was found if it is well defined and > 0 and item >= value; a
        # zero values is not marked as a star; instead it is stored in the
        # hidden input field at the end; as a consequence any empty string
        # value is normalized to a zero rating on save; note also, that values
        # not matching the raster of allowed rating values are rounded up to
        # the next matching value
        if (
               !$found
            && defined($value)
            && $value ne "\0"
            && (   ( $isNumeric && $value > 0 && $item >= $value )
                || ( !$isNumeric && $item eq $value ) )
          )
        {
            $result .= 'checked="checked" ';
            $found = 1;
        }

        $result .= "/>\n";
    }
    $result .= '<input type="hidden" name="' . $this->{name} . '" value="0" />';
    $result .= "</div>\n";

    return ( '', $result );
}

sub renderForDisplay {
    my ( $this, $format, $value, $attrs ) = @_;

    Foswiki::Plugins::JQueryPlugin::createPlugin("rating");

    my $result = "<div class='jqRating {$this->{attributes}}'>\n";
    my $found  = 0;

    # add a random suffix in case we have multiple formfields of the same type
    # on the same page
    my $name = $this->{name} . int( rand(10000) );
    foreach my $item ( @{ $this->getOptions() } ) {

        $result .=
            '<input type="radio" autocomplete="off" name="' 
          . $name . '" '
          . ' value="'
          . $item . '" ';

        $result .= 'title="' . $this->{valueMap}{$item} . '" '
          if $this->{valueMap}{$item};

        $result .= 'disabled="disabled" ';

        my $isNumeric = ( $value =~ /[^\-\+\.\d]|^$/ ) ? 0 : 1;

        if (
               !$found
            && defined($value)
            && $value ne "\0"
            && (   ( $isNumeric && $value > 0 && $item >= $value )
                || ( !$isNumeric && $item eq $value ) )
          )
        {
            $result .= 'checked="checked" ';
            $found = 1;
        }
        $result .= "/>\n";
    }
    $result .= "</div>\n";

    $format =~ s/\$value/$result/g;
    return $this->SUPER::renderForDisplay( $format, $value, $attrs );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
