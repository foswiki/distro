# This script Copyright (c) 2009 Impressive.media  ( www.impressive-media.de )
# and distributed under the GPL (see below)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# Author: Eugen Mayer

package Foswiki::Plugins::TwistyPlugin::Accordion;

use strict;
use warnings;

sub _accordionStart {
   my ( $session, $params, $theTopic, $theWeb ) = @_;
   my $id = $params->{'id'};
   $id =~ s/\///go;
   
   my $settings = "{ fillSpace: false, autoHeight: false, header:'p.accordionSection' }";
   my $output = '<script type="text/javascript">;(function($j) { $j(function() { $j("#'.$id.'").accordion('.$settings.'); }); })(jQuery);</script>';
   $output .= "<div id='$id'>";
   return $output;
}

sub _accordionEnd {    
    return '</div>';   
}

sub _accordionItemStart{
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $label = $params->{_DEFAULT};
    return "<p class='accordionSection'><a href=\"#\">$label</a></p><div>";
}

sub _accordionItemEnd{
    return '</div>';
}
1;