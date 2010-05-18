# See bottom of file for license and copyright information
#
# A UI for a collection object.
# The layout of a configuration page is depth-sensitive, so we have slightly
# different behaviours for each of level 0 (the root), level 1 (tab
# sections) and level > 1 (subsection).
package Foswiki::Configure::UIs::Section;

use strict;
use Foswiki::Configure::UIs::Value ();
use Foswiki::Configure::UI         ();
our @ISA = ('Foswiki::Configure::UI');

# Sections are of two types; "plain" and "tabbed". A plain section formats
# all its subsections inline, in a table. A tabbed section formats all its
# subsections as tabs.
#
# =$contents= are table rows
#
sub renderHtml {
    my ( $this, $section, $root, $contents ) = @_;

    $contents ||= '';
    my $depth = $section->getDepth();
    my $class = $section->isExpertsOnly() ? 'configureExpert' : '';
    my $id    = $this->makeID( $section->{headline} )
      || ( 'randomId' . int( rand(1000) ) );

    my $headline    = $section->{headline};
    my $navigation  = '';
    my $description = $section->{desc} || '';

    my $fullId    = $id;
    my $bodyClass = '';
    $bodyClass = 'configureRootSection' if $depth == 2;
    $bodyClass = 'configureSubSection'  if $depth > 2;

    # render values within this section
    # note that has to happen before creating tab sections
    # because field checks are done while rendering
    # these may update the WARN and ERROR messages
    my $values = $this->renderValues( $section, $root );
    if ($values) {
        $contents = $this->renderValueBlock($values) . $contents;
    }

    my $sectionErrors   = 0;
    my $sectionWarnings = 0;

    if ( $section->{parent} ) {
        if ( $section->{parent}->{opts} =~ /TABS/ ) {

            # this is a tab within a tabbed page

            # See what errors and warnings exist in the tab
            ( $sectionErrors, $sectionWarnings ) =
              $this->collectMessages($section);

            $section->{parent}->{controls} ||=
              new Foswiki::Configure::GlobalControls(
                $this->makeID( $section->{parent}->{headline} || '' ) );

            $section->{parent}->{controls}
              ->openTab( $id, $depth, $section->{opts}, $section->{headline},
                $sectionErrors, $sectionWarnings );

            $id = $section->{parent}->{controls}->sectionId($id);

            $bodyClass .= ' configureToggleSection';
        }
    }

    if ( $section->{opts} =~ /TABS/ ) {
        $navigation = $section->{controls}->generateTabs($depth);
    }

    my $outText = '';
    if ( $depth == 1 ) {
        my $totalWarningsText;
        if ($Foswiki::Configure::UI::totwarnings) {
            $totalWarningsText =
              $Foswiki::Configure::UI::totwarnings . ' '
              . ( $Foswiki::Configure::UI::totwarnings == 1
                ? 'warning'
                : 'warnings' );
        }
        my $totalErrorsText;
        if ($Foswiki::Configure::UI::toterrors) {
            $totalErrorsText =
              $Foswiki::Configure::UI::toterrors . ' '
              . (
                $Foswiki::Configure::UI::toterrors == 1 ? 'error' : 'errors' );
        }
        my $isFirstTime = $Foswiki::Configure::UI::firsttime || 0;

        $outText = Foswiki::Configure::UI::getTemplateParser()->readTemplate('main');
        Foswiki::Configure::UI::getTemplateParser()->parse(
            $outText,
            {
                'navigation'    => $navigation,
                'contents'      => $contents,
                'totalWarnings' => $totalWarningsText,
                'totalErrors'   => $totalErrorsText,
                'firstTime'     => $isFirstTime,
            }
        );
    }
    else {
        my $errorText;
        $errorText =
          ( $sectionErrors == 1 ) ? '1 error' : "$sectionErrors errors"
          if $sectionErrors > 0;
        my $warningText;
        $warningText =
          ( $sectionWarnings == 1 ) ? '1 warning' : "$sectionWarnings warnings"
          if $sectionWarnings;

        $outText = Foswiki::Configure::UI::getTemplateParser()->readTemplate('section');
        Foswiki::Configure::UI::getTemplateParser()->parse(
            $outText,
            {
                'id'          => $id,
                'bodyClass'   => $bodyClass,
                'depth'       => $depth,
                'headline'    => $headline,
                'errors'      => $errorText,
                'warnings'    => $warningText,
                'navigation'  => $navigation,
                'description' => $description,
                'contents'    => $contents,
            }
        );
    }
    return $outText;
}

sub renderValues {
    my ( $this, $section, $root ) = @_;

    my $out         = '';
    my $expertCount = 0;
    my $infoCount   = 0;
    foreach my Foswiki::Configure::Value $item ( @{ $section->{values} } ) {
        my $class = ref($item);
        $class =~ s/.*:://;
        my $ui = Foswiki::Configure::UI::loadUI( $class, $item );
        die "Fatal Error - Could not load UI for $class - $@" unless $ui;

        my ( $rowHtml, $properties ) = $ui->renderHtml( $item, $root );
        $out .= $rowHtml;
        $expertCount++ if $properties->{expert};
        $infoCount++   if $properties->{info};
    }

    if ( $expertCount > 0 || $infoCount > 0 ) {
        my @placeholders = ();
        push( @placeholders, 'CONFIGURE_EXPERT_LINK' ) if $expertCount > 0;
        push( @placeholders, 'CONFIGURE_INFO_LINK' )   if $infoCount > 0;

        my $expertTitle = '';

# title unfinished:
# - should be in template
# - should be left-aligned
# - language should cater for 1 option or multiple
#		$expertTitle = "<span class='configureTableExpertTitle'>$expertCount expert options</span>" if $expertCount > 0;

        $out .= Foswiki::Configure::UIs::Value::getOutsideRowHtml(
            'configureTableOutside', $expertTitle, join( ' ', @placeholders ) );
    }

    return $out;
}

sub renderValueBlock {
    my ( $this, $values ) = @_;

    return "<table class='configureSectionValues'>$values</table>";
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
