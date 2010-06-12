#! perl -w
# See bottom of file for license and copyright information
use strict;
use warnings;

print <<'END';
Change the "shebang" lines of all perl scripts found in the current
directory.

"shebang" lines tell the shell what interpreter to use for running
scripts. By default the Foswiki bin scripts are set to user the
"/usr/bin/perl" interpreter, which is where perl lives on most
UNIX-like platforms. On some platforms you will need to change this line
to run a different interpreter e.g. "D:\indigoperl\bin\perl"
or "/usr/bin/speedy"

This script will change the "shebang" lines of all scripts found in
the directory where the script is run from.

Note: the path to the interpreter *must not* contain any spaces.
END

my $new = $^X;
$/ = "\n";

while (1) {
    print "Enter path to interpreter [hit enter to choose '$new']: ";
    my $n = <>;
    chomp $n;
    last if( !$n );
    $new = $n;
};

unless( -x $new ) {
    print "Warning: I could not find an executable at $new
Are you sure you want to use this path (y/n)? ";
    my $n = <>;
    die "Aborted" unless $n =~ /^y/i;
}

my $changed = 0;
my $scanned = 0;
opendir(D, ".") || die $!;
foreach my $file (grep { -f && /^\w+$/ } readdir D) {
    $scanned++;
    $/ = undef;
    open(F, '<', $file) || die $!;
    my $contents = <F>;
    close F;

    if( $contents =~ s/^#!\s*\S+/#!$new/s ) {
        my $mode = (stat($file))[2];
        chmod( oct(600), "$file");
        open(F, '>', $file) || die $!;
        print F $contents;
        close F;
        chmod( $mode, "$file");
        print "$file modified\n";
        $changed++;
    } else {
        print "$file modified\n";
    }
}
closedir(D);
print "$changed of $scanned files changed\n";
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
