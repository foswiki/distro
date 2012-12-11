# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PubUrlPath;

use strict;
use warnings;

require Foswiki::Configure::Checkers::URLPATH;
our @ISA = ('Foswiki::Configure::Checkers::URLPATH');

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $value = $this->getCfg;
    unless ( $value && $value ne 'NOT SET' ) {
        my $guess = $this->getItemCurrentValue('{ScriptUrlPath}');
        $guess =~ s,/[^/]*?bin$,/pub,;
        $guess .= '/pub' unless ( $guess =~ m/pub$/ );
        $this->{GuessedValue} = $guess;
        $this->setItemValue($guess);
        $value = $guess;
    }
    my $mess = $this->SUPER::check(@_);
    return $mess if ( $mess =~ /Error:/ );

    my $t    = "/System/ProjectLogos/foswiki-logo.png";
    my $ok   = $this->NOTE("Content under $value is accessible.");
    my $fail = $this->ERROR(
"Content under $value is inaccessible.  Check the setting and webserver configuration."
    );
    $valobj->{errors}--;

    $mess .= $this->NOTE(
        qq{<span class="foswikiJSRequired">
<span name="{PubUrlPath}Wait">Please wait while the setting is tested.  Disregard any message that appears only briefly.</span>
<span name="{PubUrlPath}Ok">$ok</span>
<span name="{PubUrlPath}Error">$fail</span></span>
<span class="foswikiNonJS">Content under $value is accessible if the Foswiki logo appears to the right of this text.
<img name="{PubUrlPath}TestImage" src="$value$t" testImg="$t" style="margin-left:10px;height:15px;"
 onload='\$("[name=\\"\\{PubUrlPath\\}Error\\"],[name=\\"\\{PubUrlPath\\}Wait\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Ok\\"]").show();'
 onerror='\$("[name=\\"\\{PubUrlPath\\}Ok\\"],[name=\\"\\{PubUrlPath\\}Wait\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Error\\"]").show();'><br >If it does not appear, check the setting and webserver configuration.</span>}
    );
    $this->{JSContent} = 1;

    return $mess;
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
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
