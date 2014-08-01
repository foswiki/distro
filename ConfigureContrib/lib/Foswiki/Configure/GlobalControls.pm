# See bottom of file for license and copyright information

# The global controls framework for the configure page (tabs)
package Foswiki::Configure::GlobalControls;

use strict;
use warnings;

sub new {
    my ( $class, $groupid ) = @_;

    my $this = bless(
        {
            tabs    => [],
            tips    => [],
            groupid => $groupid,
        },
        $class
    );
    return $this;
}

sub openTab {
    my ( $this, $id, $depth, $model, $text, $errors, $warnings ) = @_;

    push(
        @{ $this->{tabs} },
        {
            id       => $id,
            text     => $text,
            errors   => $errors,
            warnings => $warnings
        }
    );
}

sub sectionId {
    my ( $this, $id ) = @_;

    my $sectionId = $id;
    $sectionId .= "\$$this->{groupid}"
      if $this->{groupid} ne '';    # syntax: sub$main
    return $sectionId;
}

sub _nbsp {
    my $text = shift;
    $text =~ s/\s/&nbsp;/g;
    return $text;
}

sub generateTabs {
    my ( $this, $depth ) = @_;

    return '' if !scalar @{ $this->{tabs} };
    my $tabs = '';

    my $controllerType = $depth > 1 ? 'div' : 'body';
    my @tabLi =
      map { "$controllerType.$_->{id} li.tabId_$_->{id} a" } @{ $this->{tabs} };

    my $ulClass = $depth > 1 ? 'configureSubTab' : 'configureRootTab';
    $tabs .= "<ul class='$ulClass'>";
    foreach my $tab ( @{ $this->{tabs} } ) {
        my $href = $depth > 1 ? "#$tab->{id}\$$this->{groupid}" : "#$tab->{id}";
        my $expertClass = '';

# $expertClass = ($tab->{EXPERT} ? ' configureExpert' : ''); # uncomment to hide menu items if they are expert
        my $alertClass = '';
        if ( $tab->{errorcount} && $tab->{warningcount} ) {
            $alertClass = 'configureWarnAndError';
        }
        elsif ( $tab->{errorcount} ) {
            $alertClass = 'configureError';
        }
        elsif ( $tab->{warnings} ) {
            $alertClass = 'configureWarn';
        }
        $alertClass = "class='$alertClass'" if $alertClass;
        $tabs .=
            "<li class='tabli$expertClass'>"
          . "<a $alertClass href='$href'>"
          . _nbsp( $tab->{text} )
          . "</a></li>"
          ;    # do not append a newline because IE makes this a whitespace
    }
    $tabs .= "</ul><div class='foswikiClear'></div>";

    return $tabs;
}

sub addTooltip {
    my ( $this, $tip ) = @_;
    push( @{ $this->{tips} }, $tip );
    return $#{ $this->{tips} };
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
