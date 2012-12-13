# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ScriptUrlPaths;

use strict;
use warnings;

require Foswiki::Configure::Checkers::URLPATH;
our @ISA = ('Foswiki::Configure::Checkers::URLPATH');

# Type checker for entries in the {ScriptUrlPaths} hash

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $keys = ref($valobj) ? $valobj->getKeys : $valobj;

    die "$keys not supported by " . __PACKAGE__ . "\n"
      unless ( $keys =~ /^\{ScriptUrlPaths\}\{(.*)\}$/ );

    # non-existent keys are treated differently from
    # null keys.  Just accept non-existent/undefined ones.

    return '' unless ( defined $Foswiki::cfg{ScriptUrlPaths}{$1} );

    my $script = $1;

    # Should be path to script

    my $e = '';

    $e = $this->SUPER::check($valobj);

    return $e if ( $e =~ /Error:/ );

    my $value = $this->getCfg;

    # Very old config; undefined implies no alias

    $value =
        $this->getCfg('{ScriptUrlPath}')
      . "/$script"
      . ( $this->getCfg('{ScriptSuffix}') || '' )
      unless ( defined $value );

    # Blank implies '/'; Display '/' rather than ''
    my $dval = ( $value || '/' );

    # Attempt access

    my $t    = "/Web/Topic/Img/$script?configurationTest=yes";
    my $ok   = $this->NOTE("Content under $dval is accessible.");
    my $fail = $this->ERROR(
"Content under $dval is inaccessible.  Check the setting and webserver configuration."
    );
    $valobj->{errors}--;

    my $qkeys = $keys;
    $qkeys =~ s/([{}])/\\\\$1/g;

    $e .= $this->NOTE(
        qq{<span class="foswikiJSRequired">
<span name="${keys}Wait">Please wait while the setting is tested.  Disregard any message that appears only briefly.</span>
<span name="${keys}Ok">$ok</span>
<span name="${keys}Error">$fail</span></span>
<span class="foswikiNonJS">Content under $dval is accessible if a green check appears to the right of this text.
<img name="${keys}TestImage" src="$value$t" testImg="$t" style="margin-left:10px;height:15px;"
 onload='\$("[name=\\"${qkeys}Error\\"],[name=\\"${qkeys}Wait\\"]").hide();\$("[name=\\"${qkeys}Ok\\"]").show();'
 onerror='\$("[name=\\"${qkeys}Ok\\"],[name=\\"${qkeys}Wait\\"]").hide();\$("[name=\\"${qkeys}Error\\"]").show();'><br >If it does not appear, check the setting and webserver configuration.</span>}
    );
    $this->{JSContent} = 1;

    return $e;
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
