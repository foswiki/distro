# See bottom of file for license and copyright information

# The global controls framework for the configure page (tabs)
package Foswiki::Configure::GlobalControls;

use strict;

sub new {
    my ($class, $groupid) = @_;

    my $this = bless( {
        tabs => [],
        tips => [],
        groupid => $groupid,
    }, $class );
    return $this;
}

sub openTab {
    my ($this, $id, $depth, $opts, $text, $alert) = @_;
    my $bodyClass =
      $depth > 2 ? 'configureSubSection' : 'configureRootSection';
    push(@{$this->{tabs}}, {
        id => $id, opts => $opts || '', text => $text, alert => $alert });
    return "<div id='${id}_body' class='foswikiMakeHidden $bodyClass'><a name='${id}'><!--//--></a>\n";
}

sub closeTab {
    my ($this, $id) = @_;
    return "</div><!--/#${id}_body-->\n";
}

sub _nbsp {
    my $text = shift;
    $text =~ s/\s/&nbsp;/g;
    return $text;
}

sub generateTabs {
    my ($this, $depth) = @_;

    my $controllerType = $depth > 1 ? 'div' : 'body';
    my @tabLi = map { "$controllerType.$_->{id} li.tabId_$_->{id} a" } @{$this->{tabs}};
    
    my $ulClass = $depth > 1 ? 'configureSubTab' : 'configureRootTab';
    my $tabs = "<ul class='$ulClass'>\n";
    foreach my $tab ( @{$this->{tabs}} ) {
        my $href = $depth > 1 ? "#$this->{groupid}" : "#$tab->{id}";
        my $expertClass = '';
        # $expertClass = ($tab->{opts} =~ /EXPERT/ ? ' configureExpert' : ''); # uncomment to hide menu items if they are expert
        my $alertClass = $tab->{alert} ? " class='configureWarn'" : '';
        $tabs .= "<li class='tabli tabGroup_$this->{groupid} tabId_$tab->{id}$expertClass'>"
          . "<a$alertClass href='$href'>"
            . _nbsp($tab->{text}) . "</a></li>\n";
    }
    $tabs .= "</ul>\n";
    $tabs .= "<br class='foswikiClear' />\n" if $depth > 1;

    return $tabs;
}

sub addTooltip {
    my ($this, $tip) = @_;
    push(@{$this->{tips}}, $tip);
    return $#{$this->{tips}};
}

sub generateTooltips {
    my $this = shift;
    my $tips = '';
    my $n = 0;
    foreach my $tip (@{$this->{tips}}) {
        $tips .= "<div id='tt$n' style='display:none'>$tip</div>";
        $n++;
    }
    return $tips;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
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
