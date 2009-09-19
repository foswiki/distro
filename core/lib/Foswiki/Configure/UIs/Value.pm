# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::Value;

use strict;
use base 'Foswiki::Configure::UI';

# Generates the appropriate HTML for getting a value to configure the
# entry. The actual input field is decided by the type.
sub open_html {
    my ( $this, $value, $valuer, $expert ) = @_;

    my $type = $value->getType();
    return '' if $value->{hidden};

    my $info     = '';
    my $isExpert = 0;    # true if this is an EXPERT setting
    if ( $value->isExpertsOnly() ) {
        $isExpert = 1;
        $info     = CGI::h6('EXPERT') . $info;
    }
    $info .= $value->{desc};
    my $keys = $value->getKeys();

    my $checker  = Foswiki::Configure::UI::loadChecker( $keys, $value );
    my $isUnused = 0;
    my $isBroken = 0;
    if ($checker) {
        my $check = $checker->check($value);
        if ($check) {

            # something wrong
            $info .= $check;
            $isBroken = 1;
        }
        if ( $check && $check eq 'NOT USED IN THIS CONFIGURATION' ) {
            $isUnused = 1;
        }
    }

    # Hide rows if this is an EXPERT setting in non-experts mode, or
    # this is a hidden or unused value
    my $hiddenClass = '';
    if ( $isUnused
        || !$isBroken && ( $isExpert && !$expert || $value->{hidden} ) )
    {
        $hiddenClass = 'foswikiHidden';
    }

    # Generate the documentation row
    my $hiddenTypeOf = $this->hidden( 'TYPEOF:' . $keys, $value->{typename} );
    my $row1 = $hiddenTypeOf . $info;

    # Generate col1 of the prompter row
    my $row2col1 = $keys;
    $row2col1 = CGI::span( { class => 'mandatory' }, $row2col1 )
      if $value->{mandatory};
    if ( $value->needsSaving($valuer) ) {
        my $defaultValue = $valuer->defaultValue($value) || '';

        # special case of Perl data structures
        # in order to edit this in the browser, it must get translated
        # to a string
        if ( $value->{typename} eq 'PERL' || $value->{typename} eq 'HASH' ) {
            use Data::Dumper;
            $Data::Dumper::Terse = 1;
            $defaultValue        = Dumper($defaultValue);

            # create stubs for special characters, put them back
            # with javascript
            $defaultValue =~ s/'/#26;/go;
            $defaultValue =~ s/"/#22;/go;
            $defaultValue =~ s/\n/#13;/go;
        }

        $row2col1 .= CGI::span(
            {
                title => $defaultValue,
                class => $value->{typename} . ' delta foswikiAlert'
            },
            ' &delta;'
        );

        # prepare javascript call
        ( my $safeKeys = $keys ) =~ s/'/#26;/go;
        my @onClickParams = (
            'this',          "\'$value->{typename}\'",
            "\'$safeKeys\'", "\'$defaultValue\'"
        );
        my $onClickParamsString = join( ", ", @onClickParams );

        # first link CSS class name must be type
        # a bit of a hack but we need to pass the type of the field the link
        # will be changing

        $row2col1 .= ' '
          . CGI::a(
            {
                title => $defaultValue,
                class => $value->{typename} . ' defaultValueLink foswikiSmall',
                href  => '#',
                onclick => 'resetToDefaultValue('
                  . $onClickParamsString
                  . '); return false;',
            },
            ''
          );
    }

    # Generate col2 of the prompter row
    my $row2col2;
    if ( !$isUnused && ( $isBroken || !$isExpert || $expert ) ) {

        # Generate a prompter for the value.
        my $class = $value->{typename};
        $class .= ' mandatory' if ( $value->{mandatory} );
        $row2col2 = CGI::span(
            { class => $class },
            $type->prompt(
                $keys, $value->{opts}, $valuer->currentValue($value)
            )
        );
    }
    else {

        # Non-expert - just pass the value through a hidden
        $row2col2 = $type->hiddenInput( $keys, $valuer->currentValue($value) );
    }

    return CGI::Tr(
        { class => $hiddenClass },
        CGI::td( { class => 'firstCol' }, $row2col1 ) . "\n"
          . CGI::td( { class => 'secondCol' }, $row2col2 )
      )
      . "\n"
      . CGI::Tr( { class => $hiddenClass },
        CGI::td( { colspan => "2", class => 'docdata info' }, $row1 ) )
      . "\n";
}

sub close_html {
    my $this = shift;
    return '';
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# UI generating package for simple values
#
