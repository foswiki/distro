# See bottom of file for license and copyright information
package Foswiki::Form::Color;
use Foswiki::Form::FieldDefinition;
our @ISA = qw( Foswiki::Form::FieldDefinition );

use Foswiki::Plugins::JQueryPlugin ();

use strict;
use warnings;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    Foswiki::Plugins::JQueryPlugin::createPlugin("farbtastic");
    return $this;
}

sub renderForEdit {
    my ( $this, $param1, $param2, $param3 ) = @_;

    my $value;
    my $web;
    my $topic;
    my $topicObject;
    if ( ref($param1) ) {    # Foswiki > 1.1
        $topicObject = $param1;
        $value       = $param2;
    }
    else {
        $web   = $param1;
        $topic = $param2;
        $value = $param3;
    }
    $value ||= '#000';

    my $field = CGI::textfield(
        -class    => $this->cssClasses('foswikiInputField jqFarbtastic'),
        -name     => $this->{name},
        -size     => 11,
        -override => 1,
        -value    => $value,
        -id       => $this->{name},
    );

    return ( '', $field );
}

sub renderForDisplay {
    my ( $this, $format, $value, $attrs ) = @_;

    Foswiki::Plugins::JQueryPlugin::createPlugin("farbtastic");

    my $displayValue =
"<span class='jqFarbtasticFG' style='background-color:$value;width:$this->{size}em'>$value</span>";
    $format =~ s/\$value\(display\)/$displayValue/g;
    $format =~ s/\$value/$value/g;

    return $this->SUPER::renderForDisplay( $format, $value, $attrs );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
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
