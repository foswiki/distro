# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PubUrlPath;

use strict;
use warnings;

require Foswiki::Configure::Checkers::URLPATH;
our @ISA = ('Foswiki::Configure::Checkers::URLPATH');

use Foswiki::Configure qw/:cgi/;

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
    my $ok   = $this->NOTE("Successfully accessed content under $value");
    my $fail = $this->ERROR("Failed to acccess content under $value");
    $valobj->{errors}--;

    $mess .= $this->NOTE(
qq{<span name="{PubUrlPath}Wait">Please wait while the setting is tested.  Disregard any message that appears only briefly.</span>}
          . qq{<span onload='\$("[name=\\"\\{PubUrlPath\\}Error\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Ok\\"]").hide();'>
<img name="{PubUrlPath}TestImage" src="$value$t" testImg="$t" style="height:1px;float:right;opacity:0"
 onload='\$("[name=\\"\\{PubUrlPath\\}Error\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Wait\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Ok\\"]").show();'
 onerror='\$("[name=\\"\\{PubUrlPath\\}Ok\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Wait\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Error\\"]").show();'>
<span name="{PubUrlPath}Ok">$ok</span>
<span name="{PubUrlPath}Error">$fail</span></span>}
    );

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
