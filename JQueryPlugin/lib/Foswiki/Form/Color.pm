# See bottom of file for license and copyright details
package Foswiki::Form::Color;
use base 'Foswiki::Form::FieldDefinition';

use Foswiki::Plugins::JQueryPlugin ();

use strict;

sub new {
  my $class = shift;
  my $this  = $class->SUPER::new(@_);
  Foswiki::Plugins::JQueryPlugin::createPlugin("farbtastic");
  return $this;
}

sub renderForEdit {
  my ($this, $param1, $param2, $param3) = @_;

  my $value;
  my $web;
  my $topic;
  my $topicObject;
  if (ref($param1)) { # Foswiki > 1.1
    $topicObject = $param1;
    $value = $param2;
  } else {
    $web = $param1;
    $topic = $param2;
    $value = $param3;
  }

  my $field = CGI::textfield(
    -class => $this->cssClasses('foswikiInputField jqFarbtastic'),
    -name  => $this->{name},
    -size  => 11,
    -value => $value,
    -id  => $this->{name},
  );

  return ('',$field);
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
# Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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

