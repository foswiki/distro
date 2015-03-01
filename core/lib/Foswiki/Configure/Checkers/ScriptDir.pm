# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ScriptDir;

use strict;
use warnings;

use Foswiki::Configure::Checkers::PATH ();
our @ISA = ('Foswiki::Configure::Checkers::PATH');

# Wizard method
sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $dir = $this->{item}->getExpandedValue();

    my $ext = $Foswiki::cfg{ScriptSuffix} || '';
    my $errs = '';
    unless ( opendir( D, $dir ) ) {
        $reporter->ERROR(<<HERE);
Cannot open '$dir' for read ($!) - check it exists, and that permissions are correct.
HERE
        return;
    }
    foreach my $script ( grep { -f "$dir/$_" && /^\w+(\.\w+)?$/ } readdir D ) {
        my $err = '';

        #  If a script suffix is set, make sure all scripts have one
        if (   $ext
            && $script !~ /$ext$/
            && $script !~ /\.cfg$/ )
        {
            $err .= "   * is missing the configured script suffix ($ext).\n";
        }
        if (  !$ext
            && $script =~ m/(\..*)$/
            && $script !~ /\.cfg$/
            && $script !~ /\.fcgi$/ )
        {
            $err .=
              "   * has a suffix ($1), but no script suffix is configured.\n";
        }

        #  Verify that scripts are executable
        if (   $^O ne 'MSWin32'
            && $script !~ /\.cfg$/
            && !-x "$dir/$script" )
        {
            $err .=
"   * permissions do not include eXecute.  It might not be an executable script.\n";
        }
        if ($err) {
            $reporter->WARN("$script:\n$err");
        }
    }
    closedir(D);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
