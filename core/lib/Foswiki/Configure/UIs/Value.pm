# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::Value;

use strict;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

=pod

renderHtml($value, $root) -> ($html, \%properties)

Generates the appropriate HTML for getting a value to configure the
entry. The actual input field is decided by the type.

=cut

sub renderHtml {
    my ( $this, $value, $root ) = @_;

    my $output = '';

    my $type = $value->getType();

    return '' if $value->{hidden};

    my $isExpert = $value->isExpertsOnly();
    my $info     = '';

    $info .= $value->{desc};
    my $keys = $value->getKeys();

    my $checker  = Foswiki::Configure::UI::loadChecker( $keys, $value );
    my $isUnused = 0;
    my $isBroken = 0;
    my $check    = '';
    if ($checker) {
        $check = $checker->check($value) || '';
        if ($check) {

            # something wrong
            $isBroken = 1;
        }
        if ( $check eq 'NOT USED IN THIS CONFIGURATION' ) {
            $isUnused = 1;
        }
    }

    # Hide rows if this is an EXPERT setting in non-experts mode, or
    # this is a hidden or unused value
    my @cssClasses = ();
    push @cssClasses, 'configureExpert' if $isExpert;
    if ( $isUnused || !$isBroken && $value->{hidden} ) {
        push @cssClasses, 'foswikiHidden';
    }

    # Hidden type information used when passing to 'save'
    my $hiddenTypeOf = Foswiki::Configure::UI::hidden(
        'TYPEOF:' . $keys, $value->{typename} );

    my $index = $keys;
    $index = "$index <span class='configureMandatory'>required</span>"
      if $value->{mandatory};

    my $resetToDefaultLinkText = '';
    if ( $value->needsSaving( $root->{valuer} ) ) {

        my $valueString =
          $value->asString( $root->{valuer},
            $Foswiki::Configure::Value::VALUE_TYPE->{DEFAULT} );

        # encode special characters
        $valueString =~ s/(['"\n])/'#'.ord($1)/ge;

        my $safeKeys = $keys;
        $safeKeys =~ s/(['"\n])/'#'.ord($1)/ge;
        my $defaultDisplayValue = $valueString;

        if (   $value->{typename} eq 'BOOLEAN'
            || $value->{typename} eq 'NUMBER'
            || $value->{typename} eq 'OCTAL' )
        {
            $defaultDisplayValue ||= '0';
        }
        $valueString =~ s/\'/\\'/go;
        $valueString =~ s/\"/&quot;/go;
        $resetToDefaultLinkText .= <<HERE;
<a href='#' title='$defaultDisplayValue' class='$value->{typename} configureDefaultValueLink' onclick="return resetToDefaultValue(this,'$value->{typename}','$safeKeys','$valueString')"><span class="configureDefaultValueLinkLabel">&nbsp;</span><span class='configureDefaultValueLinkValue'>$defaultDisplayValue</span></a>
HERE

        $resetToDefaultLinkText =~ s/^[[:space:]]+//s;    # trim at start
        $resetToDefaultLinkText =~ s/[[:space:]]+$//s;    # trim at end
    }

    my $control;
    if ( $isUnused && !$isBroken ) {

        # Unused and not broken - just pass the value through a hidden
        $control = Foswiki::Configure::UI::hidden(
            $keys, $root->{valuer}->currentValue($value) );
    }
    else {

        # Generate a prompter for the value.
        my $promptclass = $value->{typename} || '';
        $promptclass .= ' configureMandatory' if ( $value->{mandatory} );
        $control =
          $type->prompt( $keys, $value->{opts},
            $root->{valuer}->currentValue($value), $promptclass );
    }

    my $helpTextLink = '';
    my $helpText     = '';
    if ($info) {
        my $tip        = $root->{controls}->addTooltip($info);
        my $scriptName = Foswiki::Configure::Util::getScriptName();
        my $image =
"<img src='$scriptName?action=resource;resource=icon_info.gif' alt='Show info' title='Show info' />";
        $helpTextLink =
"<span class='foswikiMakeVisible'><a href='#' onclick='return toggleInfo($tip);'>$image</a></span>";
        $helpText =
"<div id='info_$tip' class='configureInfoText foswikiMakeHidden'>$info</div>";
    }

    my $class = join( ' ', @cssClasses );

    $output .=
      getRowHtml( $class, "$index$hiddenTypeOf", $helpTextLink,
        "$control&nbsp;$resetToDefaultLinkText$check$helpText" )
      . "\n";

    return (
        $output,
        {
            expert => $isExpert,
            info   => ( $info ne '' ),
            broken => $isBroken,
            unused => $isUnused,
            hidden => $value->{hidden}
        }
    );
}

sub getRowHtml {
    my ( $class, $header, $info, $data ) = @_;

    my $classProp = $class ? { class => $class } : undef;
    return CGI::Tr( $classProp,
            CGI::th( $classProp, $header )
          . CGI::td($data)
          . CGI::td( { class => "$class configureHelp" }, $info ) );
}

sub getOutsideRowHtml {
    my ( $class, $title, $data ) = @_;

    return CGI::Tr(
        CGI::td( { class => $class, colspan => "3" }, "$title $data" ) );
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
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
