# See bottom of file for license and copyright information
package Foswiki::Form::Textboxlist;

use Foswiki::Form::ListFieldDefinition;
our @ISA = qw( Foswiki::Form::ListFieldDefinition );
use Foswiki::Plugins::JQueryPlugin ();

use strict;
use warnings;

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);

    Foswiki::Plugins::JQueryPlugin::createPlugin("textboxlist");
    return $this;
}

sub isMultiValued { return 1; }

sub getDefaultValue { undef }

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

    my @values   = @{ $this->SUPER::getOptions() };
    my $metadata = '';
    if (@values) {
        if ( scalar(@values) == 1 && $values[0] =~ m/^https?:/ ) {
            $metadata = "{autocomplete: '$values[0]'}";
        }
        else {
            $metadata =
                "{autocomplete: ['"
              . join( "', '", map { $_ =~ s/(["'])/\\$1/g; $_ } @values )
              . "']}";
        }
    }

    my $field = CGI::textfield(
        -class =>
          $this->cssClasses("foswikiInputField jqTextboxList $metadata"),
        -name     => $this->{name},
        -size     => $this->{size},
        -override => 1,
        -value    => $value,
        -id       => $this->{name},
    );

    return ( '', $field );
}

sub getOptions {
    my $this = shift;

    my $query = Foswiki::Func::getCgiQuery();

    # trick this in
    my @values          = ();
    my @valuesFromQuery = $query->multi_param( $this->{name} );
    foreach my $item (@valuesFromQuery) {

        # Item10889: Coming from an "Warning! Confirmation required", often
        # there's an undef item (the, last, empty, one, <-- here)
        if ( defined $item ) {
            $item =~ s/^\s+|\s+$//g;
            foreach my $value ( split( /\s*,\s*/, $item ) ) {
                push @values, $value if defined $value;
            }
        }
    }

    return \@values;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
