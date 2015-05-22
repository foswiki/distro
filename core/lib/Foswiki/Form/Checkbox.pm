# See bottom of file for license and copyright information
package Foswiki::Form::Checkbox;

use strict;
use warnings;
use Assert;

use Foswiki::Form::ListFieldDefinition ();
our @ISA = ('Foswiki::Form::ListFieldDefinition');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my ( $class, @args ) = @_;
    my $this = $class->SUPER::new(@args);
    $this->{size} ||= 0;
    $this->{size} =~ s/\D//g;
    $this->{size} ||= 0;
    $this->{size} = 4 if ( $this->{size} < 1 );
    $this->{validModifiers} = ['+values'];    #comma separated list?

    return $this;
}

sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{valueMap};
}

=begin TML

---++ getDefaultValue() -> $value
The default for a select is always the empty string, as there is no way in
Foswiki form definitions to indicate selected values. This defers the decision
on a value to the browser.

=cut

sub getDefaultValue {
    my $this = shift;
    return ( exists( $this->{default} ) ? $this->{default} : '' );
}

# Checkbox store multiple values
sub isMultiValued { return 1; }

sub getDisplayValue {
    my ( $this, $value ) = @_;

    return $value unless $this->isValueMapped();

    $this->getOptions();
    my @vals = ();
    foreach my $val ( split( /\s*,\s*/, $value ) ) {
        if ( defined( $this->{valueMap}{$val} ) ) {
            push @vals, $this->{valueMap}{$val};
        }
        else {
            push @vals, $val;
        }
    }
    return join( ", ", @vals );
}

sub renderForEdit {
    my ( $this, $topicObject, $value ) = @_;

    my $session = $this->{session};
    my $extra   = '';
    if ( $this->{type} =~ m/\+buttons/ ) {
        $extra = "<div class='foswikiButtonBox'>";
        $extra .= CGI::button(
            -class   => 'foswikiButton',
            -value   => $session->i18n->maketext('Set all'),
            -onClick => 'jQuery(this).parents("form").find("input[name='
              . $this->{name}
              . ']").prop("checked", true);',
        );
        $extra .= CGI::button(
            -class   => 'foswikiButton',
            -value   => $session->i18n->maketext('Clear all'),
            -onClick => 'jQuery(this).parents("form").find("input[name='
              . $this->{name}
              . ']").prop("checked", false);',
        );
        $extra .= "</div>";
    }

    $value = '' unless defined($value) && length($value);

    my %isSelected = map { $_ => 1 } split( /\s*,\s*/, $value );
    my %attrs;
    my @defaults;

    foreach my $item ( @{ $this->getOptions } ) {

        my $title = $item;
        $title = $this->{_descriptions}{$item}
          if $this->{_descriptions}{$item};

        # NOTE: Does not expand $item in title
        $attrs{$item} = {
            class => $this->cssClasses('foswikiCheckbox'),
            title => $topicObject->expandMacros($title),
        };

        if ( $isSelected{$item} ) {

            # One or the other; not both, or CGI generates two checked="checked"
            if ( $this->isValueMapped() ) {
                $attrs{$item}{checked} = 'checked';
            }
            else {
                push( @defaults, $item );
            }
        }
    }

    my %params = (
        -name       => $this->{name},
        -override   => 1,
        -values     => $this->getOptions(),
        -defaults   => \@defaults,
        -columns    => $this->{size},
        -attributes => \%attrs,
    );
    if ( defined $this->{valueMap} ) {
        $params{-labels} = $this->{valueMap};
    }
    $value = CGI::checkbox_group(%params);

    # Item2410: We need a dummy control to detect the case where
    #           all checkboxes have been deliberately unchecked
    # Item3061:
    # Don't use CGI, it will insert the sticky value from the query
    # once again and we need an empty field here.
    $value .= '<input type="hidden" name="' . $this->{name} . '" value="" />';
    return ( $extra, $value );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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
