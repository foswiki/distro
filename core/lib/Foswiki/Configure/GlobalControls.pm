# See bottom of file for license and copyright information

# The global controls framework for the configure page (tabs)
package Foswiki::Configure::GlobalControls;

use strict;

sub new {
    my $class = shift;

    my $this = bless( {
        tabs => [],
        tips => [],
    }, $class );
    return $this;
}

sub openTab {
    my ($this, $id, $text, $alert) = @_;
    push(@{$this->{tabs}}, { id => $id, text => $text, alert => $alert });
    return "<div id='${id}_body' class='configureTabBodyHidden'><a name='${id}'></a>\n";
}

sub closeTab {
    my ($this, $id) = @_;
    return "</div><!--/$id tab-->\n";
}

sub _nbsp {
    my $text = shift;
    $text =~ s/\s/&nbsp;/g;
    return $text;
}

sub generateTabs {
    my $this = shift;
    # Load the CSS from resources, embedding the expansion of the tabs
    my @tabLi = map { "body.$_->{id} li.$_->{id}" } @{$this->{tabs}};
    my $css = "<style type='text/css'>".Foswiki::getResource(
        'tabs.css',
        TABLI  => join(',', @tabLi),
        TABLIA => join(',', map { "$_ a" } @tabLi))
      .'</style>';
    my $tabs = "<ul class='configureTab'>\n";
    foreach my $tab ( @{$this->{tabs}} ) {
        my $alertClass = $tab->{alert} ? " class='configureWarn'" : '';
        $tabs .= "<li class='$tab->{id}'>"
          . "<a$alertClass onclick='tab(\"$tab->{id}\")'>"
            . _nbsp($tab->{text}) . "</a></li>\n";
    }
    $tabs .= "</ul>\n";
    return $css.$tabs;
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
