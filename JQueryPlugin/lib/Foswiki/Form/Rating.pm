# See bottom of file for license and copyright details
package Foswiki::Form::Rating;

use strict;

use Foswiki::Form::ListFieldDefinition ();
use Foswiki::Plugins::JQueryPlugin ();
our @ISA = ('Foswiki::Form::ListFieldDefinition');

sub new {
  my $class = shift;
  my $this = $class->SUPER::new(@_);
  $this->{size} ||= 0;
  $this->{size} =~ s/\D//g;
  $this->{size} ||= 0;
  $this->{size} = 4 if ($this->{size} < 1);

  return $this;
}

sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{valueMap};
}


sub getOptions {
  my $this = shift;

  my $options = $this->SUPER::getOptions();

  unless (@$options) {
    for (my $i = 1; $i <= $this->{size}; $i++) {
      push @$options, $i;
    }
    $this->{_options} = $options;
    return $options;
  }

  if ($this->{type} =~ /\+values/) {
    $this->{valueMap} = ();
    $this->{_options} = ();
    my $str;
    foreach my $val (@$options) {
      if ($val =~ /^(.*?[^\\])=(.*)$/) {
        $str = $1;
        $val = $2;
        $str =~ s/\\=/=/g;
      } else {
        $str = $val;
      }
      $this->{valueMap}{$val} = Foswiki::urlDecode($str);
      push @{$this->{_options}}, $val;
    }
    $options = $this->{_options};
  }

  return $options;
}

sub renderForEdit {
  my ($this, $topicObject, $value) = @_;

  Foswiki::Plugins::JQueryPlugin::createPlugin("rating");

  my $result = "<div class='jqRating {$this->{attributes}}'>\n";
  my $found = 0;
  my $intVal = ($value)?$value:0;
  foreach my $item (@{ $this->getOptions() }) {
    $result .= '<input type="radio" name="' . $this->{name} . '" ' . ' value="' . $item . '" ';
    $result .= 'title="'.$this->{valueMap}{$item}.'" ' if $this->{valueMap}{$item};
    if ($item == $intVal || ($item > $intVal && !$found)) {
      $found = 1;
      $result .= 'checked="checked" ';
    }
    $result .= "/>\n";
  }
  $result .= '<input type="hidden" name="'.$this->{name}.'" value="" />';
  $result .= "</div>\n";

  return ('', $result);
}

sub renderForDisplay {
  my ($this, $format, $value, $attrs) = @_;

  Foswiki::Plugins::JQueryPlugin::createPlugin("rating");

  my $result = "<div class='jqRating {$this->{attributes}}'>\n";
  my $found = 0;
  my $intVal = ($value)?$value:0;
  foreach my $item (@{ $this->getOptions() }) {
    $result .= '<input type="radio" name="' . $this->{name} . '" ' . ' value="' . $item . '" ';
    $result .= 'title="'.$this->{valueMap}{$item}.'" ' if $this->{valueMap}{$item};
    $result .= 'disabled="disabled" ';
    if ($item == $intVal || ($item > $intVal && !$found)) {
      $found = 1;
      $result .= 'checked="checked" ';
    }
    $result .= "/>\n";
  }
  $result .= "</div>\n";

  $format =~ s/\$value/$result/g;
  return $this->SUPER::renderForDisplay($format, $value, $attrs);
}

1;
__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

