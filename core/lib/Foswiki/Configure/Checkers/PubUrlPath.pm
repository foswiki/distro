# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PubUrlPath;

use strict;
use warnings;

require Foswiki::Configure::Checkers::URLPATH;
our @ISA = ('Foswiki::Configure::Checkers::URLPATH');

use Foswiki::Configure qw/:cgi/;

sub check {
    my $this = shift;

    unless ( $Foswiki::cfg{PubUrlPath}
        && $Foswiki::cfg{PubUrlPath} ne 'NOT SET' )
    {
        my $guess = $this->getItemCurrentValue('ScriptUrlPath');
        $guess =~ s/\/[^\/]*?bin$/\/pub/;
        $guess .= '/pub' unless ( $guess =~ m/pub$/ );
        $this->{GuessedValue} = $guess;
        $this->setItemValue($guess);
        return $this->SUPER::check(@_);
    }
    my $d    = $this->getCfg;
    my $mess = $this->SUPER::check(@_);
    my $t    = "/System/ProjectLogos/foswiki-logo.png";

    $mess .= $this->NOTE("Please wait while the path is tested")
      . qq{<div class='configureSetting' onload='\$("[name=\\"\\{PubUrlPath\\}Error\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Ok\\"]").hide();'>
<img name="{PubUrlPath}TestImage" src="$d$t" testImg="$t" style="height:20px;"
 onload='\$("[name=\\"\\{PubUrlPath\\}Error\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Ok\\"]").show();'
 onerror='\$("[name=\\"\\{PubUrlPath\\}Ok\\"]").hide();\$("[name=\\"\\{PubUrlPath\\}Error\\"]").show();'>
<span name="{PubUrlPath}Ok">This setting is correct.</span>
<span name="{PubUrlPath}Error"><img src="${resourceURI}icon_error.png" style="margin-right:5px;">Path is not correct.</span></div>};

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
