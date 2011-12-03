# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::Value
This is the UI object for a single configuration item. It must not be
confused with Foswiki::Configure::Value, which is the value object that
models a configuration item. There will be one corresponding
Foswiki::Configure::Value for each object of this class.

=cut

package Foswiki::Configure::UIs::Value;

use strict;
use warnings;

use Foswiki::Configure::UIs::Item ();
our @ISA = ('Foswiki::Configure::UIs::Item');

=begin TML

---++ ObjectMethod renderHtml($value, $root, ...) -> ($html, \%properties)
   * =$value= - Foswiki::Configure::Value object in the model
   * =$root= - Foswiki::Configure::UIs::Root

Implements Foswiki::Configure::UIs::Item

Generates the appropriate HTML for getting a presenting the configure the
entry.

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
    my $hiddenTypeOf =
      Foswiki::Configure::UI::hidden( 'TYPEOF:' . $keys, $value->{typename} );

    my $index = $keys;
    $index = "$index <span class='configureMandatory'>required</span>"
      if $value->{mandatory};

    my $resetToDefaultLinkText = '';
    if ( $value->needsSaving( $root->{valuer} ) ) {

        my $valueString =
          $value->asString( $root->{valuer},
            $Foswiki::Configure::Value::VALUE_TYPE->{DEFAULT} );

        # URL encode parameter name and value
        my $safeKeys = $this->urlEncode($keys);

        my $defaultDisplayValue = $this->urlEncode($valueString);

        if (   $value->{typename} eq 'BOOLEAN'
            || $value->{typename} eq 'NUMBER'
            || $value->{typename} eq 'OCTAL' )
        {
            $defaultDisplayValue ||= '0';
        }

        #$valueString =~ s/\'/\\'/go;
        #$valueString =~ s/\n/\\n/go;
        $valueString = $this->urlEncode($valueString);
        $resetToDefaultLinkText .= <<HERE;
<a href='#' title='$defaultDisplayValue' class='$value->{typename} configureDefaultValueLink' onclick="return resetToDefaultValue(this,'$value->{typename}','$safeKeys','$valueString')"><span class="configureDefaultValueLinkLabel">&nbsp;</span><span class='configureDefaultValueLinkValue'>$defaultDisplayValue</span></a>
HERE

        $resetToDefaultLinkText =~ s/^[[:space:]]+//s;    # trim at start
        $resetToDefaultLinkText =~ s/[[:space:]]+$//s;    # trim at end
    }

    my $control;
    if ( $isUnused && !$isBroken ) {

        # Unused and not broken - just pass the value through a hidden
        $control =
          Foswiki::Configure::UI::hidden( $keys,
            $root->{valuer}->currentValue($value) );
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
      _getRowHtml( $class, "$index$hiddenTypeOf", $helpTextLink,
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

sub _getRowHtml {
    my ( $class, $header, $info, $data ) = @_;

    my $classProp = $class ? { class => $class } : undef;
    return CGI::Tr( $classProp,
            CGI::th( $classProp, $header )
          . CGI::td( {}, $data )
          . CGI::td( { class => "$class configureHelp" }, $info ) );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
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
