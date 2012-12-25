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

use Foswiki::Configure::CGI;

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

    my $keys     = $value->getKeys();
    my $feedback = $value->feedback();

    # Check with the type for any default options; these might add CHECK or
    # FEEDBACK data, default to EXPERT - etc.

    if ( $type->can('defaultOptions') ) {
        my $opts = my $prev = $value->{opts} || '';
        my $updated = $type->defaultOptions(
            $keys, $opts,
            $value->feedback && 1,
            $value->getCheckerOptions && 1
        );
        if ( $updated ne $prev ) {
            $value->set( undef, opts => $updated );
            return '' if ( $value->{hidden} );
            $feedback = $value->feedback;
        }
    }

    my $isExpert  = $value->isExpertsOnly();
    my $displayIf = $value->displayIf();
    my $enableIf  = $value->enableIf();
    my $info      = $value->{desc};
    my $isUnused  = 0;
    my $isBroken  = 0;
    my $check     = '';

    my $checker = Foswiki::Configure::UI::loadChecker( $keys, $value );
    if ($checker) {
        my $output;
        eval { $output = $checker->check($value); };
        if ($@) {
            $output =
              $this->ERROR( "Checker ("
                  . ref($checker)
                  . ") for $keys failed: check for .spec errors:  <pre>$@</pre>"
              );
        }
        $output = '' unless ( defined $output );

        # Remove any feedback command blocks - they don't apply to the static
        # presentation created here.  This could be done in-place, but this
        # is the same logic used in Feedback to reduce the risk of divergence.
        while (1) {
            my ($len);
            if ( $output !~ s/\A\001// ) {

               # Unencoded text (from NOTE, WARN, ERROR - or bare text)
               # Length runs to next encoded block, or end of string & may be 0.
                $len = index( $output, "\001" );
                if ( $len == -1 ) {
                    $check .= $output;
                    last;
                }
                $check .= substr( $output, 0, $len, '' );
                next if ( length $output );
                last;
            }

            # Pre-encoded commands from FB_xxx
            # Length, is used to find end of each command, and removed
            die "Bad command string\n" unless ( $output =~ s/\A(\d+),\{/{/ );
            $len = $1;
            die "Bad command length\n"
              unless ( $len && $len <= length $output );
            substr( $output, 0, $len, '' );
            next if ( length $output );
            last;
        }
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

    my $index = '';
    my $haslabel;    # label replaces {key}{s}
    if ( defined( my $label = $value->label ) ) {
        $index .= $label;
        $haslabel = 1;
    }
    else {
        $index .= $keys;
    }
    $index .= " <span class='configureMandatory'>required</span>"
      if $value->{mandatory};

    if ( defined $feedback ) {
        my $buttons = "";
        my $bn      = 0;
        my $col     = 0;
        my $ac      = 0;
        my ( $tbl, %bn );
        $tbl ||= exists $_->{col} foreach (@$feedback);
        $buttons =
          ( $haslabel ? '' : '<br />' )
          . '<table class="configureFeedbackArray"><tbody>'
          if ($tbl);
        foreach my $fb (@$feedback) {
            $bn++;
            my $n = $fb->{button} || $bn;
            if ( $bn{$n} || $bn < 0 ) {
                $check .= $this->ERROR(
".spec duplicates feedback button $n for $keys; duplicate skipped"
                );
                next;
            }
            $bn{$n} = 1;
            my $invisible = '';
            my $pinfo     = '';
            my $fbl       = $fb->{'.label'};
            if ( $fb->{pinfo} ) {
                $pinfo = qq{, '$fb->{pinfo}'};
            }
            if ( $fbl eq '~' ) {
                $invisible = qq{ style="display:none;"};
                $ac        = 1;
            }
            else {
                if ($tbl) {
                    my $fbc = $fb->{col} || $col + 1;
                    if ( $col == 0 || $fbc < $col ) {
                        $buttons .= '<tr>';
                        $col = 0;
                    }
                    $buttons .= '<td>' while ( $col++ < ( $fbc - 1 ) );
                    $fbc = $fb->{span};
                    $buttons .= '<td' . ( $fbc ? " colspan='$fbc'>" : '>' );
                }
                else {
                    $buttons .=
                      ( !$haslabel && $col % 3 == 0 ) ? "<br />" : ' ';
                }
                $col++;
            }
            $fbl =~
              s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge
              unless ( $fb->{html} );
            my $fbc = $fb->{class};
            $fbc = ( defined $fbc ? ' $fbc' : '' );
            my $val = $fb->{value} || $fbl;
            my $title = $fb->{title};
            if ( defined $title ) {
                $title =~
s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;
                $title = qq{ title="$title"};
            }
            else {
                $title = '';
            }
            $buttons .=
qq{<button type="button" id="${keys}feedreq$n" value="$val" class="configureFeedbackButton$n $fbc" onclick="return doFeedback(this$pinfo);"$invisible$title>$fbl</button>};
            $buttons .=
qq{<span style='display:none' id="${keys}feedmsg$n"><span class="configureFeedbackWaitText">$fb->{wait}</span></span>}
              if ( $fb->{wait} );
        }
        $buttons .= '</tbody></table>' if ($tbl);
        $feedback = qq{<span class="foswikiJSRequired">$buttons</span>};
        $index .=
qq{<span class="configureCheckOnChange"><img src="${Foswiki::resourceURI}autocheck.png" title="This field will be automatically verified when you change it" alt="Autochecked field"></span>}
          if ($ac);
    }
    else {
        $feedback = '';
    }
    my ( $itemErrors, $itemWarnings ) =
      ( ( $value->{errors} || 0 ), ( $value->{warnings} || 0 ) );
    $index .= Foswiki::Configure::UI::hidden(
        "${keys}errors",
        "$itemErrors $itemWarnings",
        !( $itemErrors + $itemWarnings )
    );
    push @cssClasses, 'configureDisplayForced'
      if ( $itemErrors || $itemWarnings );

    my $resetToDefaultLinkText = '';

    # if ( $value->needsSaving( $root->{valuer} ) ) {
    {
        # Since Feedback allows values to change without a screen
        # refresh, we always generate a ResetToDefault link.
        # This can result in "stored" and "default" values
        # being the same, but I don't think it matters...
        my $valueString;
        {

            package Foswiki::Configure::Value;
            our $VALUE_TYPE;

            $valueString =
              $value->asString( $root->{valuer},
                $Foswiki::Configure::Value::VALUE_TYPE->{DEFAULT} );
        }

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
<a href='#' name="${keys}deflink" title='$defaultDisplayValue' class='$value->{typename} configureDefaultValueLink' onclick="return resetToDefaultValue(this,'$value->{typename}','$safeKeys','$valueString')"><span class="configureDefaultValueLinkLabel">&nbsp;</span><span class='configureDefaultValueLinkValue'>$defaultDisplayValue</span></a>
HERE

        $resetToDefaultLinkText =~ s/^[[:space:]]+//s;    # trim at start
        $resetToDefaultLinkText =~ s/[[:space:]]+$//s;    # trim at end
    }

    my $control      = '';
    my $enable       = '&nbsp;';
    my $currentValue = $root->{valuer}->currentValue($value);
    unless ( defined $currentValue ) {

        # Could be a corrupt spec file, or an item materialized
        # without a spec entry.  Assume the latter know what
        # they are doing.  (They won't have a symbol entry).
        # If a materialized item should be checked, see FoswikiCfg
        # for the format of an _defined entry.

        if ( exists $value->{_defined} ) {
            $control = $this->WARN(
"Undefined or missing value should not occur in .spec or .cfg file.  Check for corruption."
            );
            $currentValue = '';
        }
    }
    if ( $isUnused && !$isBroken ) {

        # Unused and not broken - just pass the value through a hidden
        $control .= Foswiki::Configure::UI::hidden( $keys, $currentValue );
    }
    else {

        # Generate a prompter for the value.
        my $promptclass = $value->{typename} || '';
        $promptclass .= ' configureMandatory' if ( $value->{mandatory} );
        if ( $value->{opts} =~ /\bE\b/ ) {
            my $name = $keys;
            $name =~ s/\}$/_\}/;
            $hiddenTypeOf .=
              Foswiki::Configure::UI::hidden( 'TYPEOF:' . $name, 'BOOLEAN' );
            $enable =
qq{<input type="checkbox" name="$name" value="1" class="BOOLEAN configureItemEnable" };
            $enable .= qq{checked="checked"}
              if ( defined $currentValue );
            $enable .= qq{ onchange="return enableChanged(this,'$keys');">};
        }

        eval {
            $control .=
              $type->prompt( $keys, $value->{opts}, $currentValue,
                $promptclass );
        };
        if ($@) {
            $control .= $this->ERROR(
                ref($type)
                  . " failed to generate input field; check for .spec errors: $@"
            );
        }
    }

    my $helpTextLink = '';
    my $helpText     = '';
    if ($info) {
        my $tip        = $root->{controls}->addTooltip($info);
        my $scriptName = Foswiki::Configure::CGI::getScriptName();
        my $image =
"<img src='${Foswiki::resourceURI}icon_info.png' alt='Show info' title='Show info' />";
        $helpTextLink =
"<span class='foswikiMakeVisible'><a href='#' onclick='return toggleInfo($tip);'>$image</a></span>";
        $helpText =
"<div id='info_$tip' class='configureInfoText foswikiMakeHidden'>$info</div>";
    }

    my %props = ( 'data-keys' => $keys );
    $props{class} = join( ' ', @cssClasses ) if ( scalar @cssClasses );
    $props{'data-displayif'} = $displayIf if $displayIf;
    $props{'data-enableif'}  = $enableIf  if $enableIf;
    my $changeAction = $value->{changeAction} || '';
    if ( $value->{opts} =~ /\bE\b/ ) {
        $changeAction = << 'ENABLEJS' . $changeAction;
if( ele.value.length ) {
    $('[name="' + configure.utils.quoteName(ele.name.replace(/\}$/,'_}')) + '"]').each(function() {
        if( !this.checked ) {
            this.checked = true;
        }
        return true;
    });
}
ENABLEJS
    }
    $props{'data-change'} = $changeAction if $changeAction;

    my $expander = '';
    $expander .= ' ' if ($helpTextLink);
    $expander .=
qq{<span id="${keys}expander" class="configureFeedbackExpander foswikiJSRequired">};
    $expander .=
qq{<a href='#' onclick="return feedback.toggleXpndr(this,'${keys}status');" ><img src="${Foswiki::resourceURI}toggleopen.png" alt="Expand/condense feedback" title="Expand/condense feedback" /></a></span>};
    $helpTextLink .= $expander;

    $check =
qq{<div id="${keys}status" class="configureFeedback configureFeedbackExpanded" >$check</div>};
    $output .= CGI::Tr( \%props,
            CGI::th("$index$feedback$hiddenTypeOf")
          . CGI::td( { class => 'configureItemEnable' }, $enable )
          . CGI::td("$helpText$control&nbsp;$resetToDefaultLinkText$check")
          . CGI::td( { class => "configureHelp" }, $helpTextLink ) )
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
