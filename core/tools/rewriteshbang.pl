#!/usr/bin/perl -w
# See bottom of file for license and copyright information
use strict;
use warnings;
use Cwd;

print "\nRunning Perl $]\n";

print <<'END';

Change the "shebang" lines of all perl scripts found either in the current
directory or as configured in @directories. Default is to change:
../tools and ../bin directories. You will be asked to confirm accordingly.

"shebang" lines tell the shell what interpreter to use for running scripts.
By default the Foswiki bin scripts are set to use the "/usr/bin/perl"
interpreter, which is where perl lives on most UNIX-like platforms. On some
platforms you will need to change this line to run a different interpreter
e.g. "D:\indigoperl\bin\perl" or "/usr/bin/speedy"

This script will change the "shebang" lines of all scripts found in the
confirmed directories except for itself.

Note: the path to the interpreter *must not* contain any spaces.
END

my $new_path     = $^X;
my @directories  = ( '../tools', '../bin', );
my $not_just_cwd = '';
my $os = $^O;
$/ = "\n";

while (1) {
    print "Enter path to interpreter [hit enter to choose '$new_path']: ";
    my $n = <>;
    chomp $n;
    last if ( !$n );    # exit if $n undefined or 0
    $new_path = $n;
}

unless ( -x "$new_path" ) {
    print "Warning: I could not find an executable at \"$new_path\"
Are you sure you want to use this path (y/n)?: ";
    my $n = <>;
    die "Aborted" unless $n =~ /^y/i;
}

while (1) {
    print
"\n\"No\" will only change \"shebang\" lines of scripts found in the directory
where the script is run from. Are you sure you want to change scripts
in the ";
    print scalar(@directories);
    print " directories:\n";
    foreach (@directories) {
        print "$_\n";
    }
    print "(y/n)?: ";
    $not_just_cwd = <>;
    chomp $not_just_cwd;
    last if ( $not_just_cwd =~ /^[yn]/i );
}

if ( $not_just_cwd =~ /^y/i ) {
    foreach (@directories) {
        chdir "$_" || die "Can't change to: $!";
        opendir( D, "." ) || die "Can't open: $!";
        &change_files;
    }
}
else {
    opendir( D, "." ) || die "Can't open: $!";
    &change_files;
}

print "\n";

#############
# Subroutines

sub change_files {

    my $cwd     = getcwd;
    my $scanned = 0;
    my $changed = 0;

    # Grep relevant files to process while only including .pl, .cgi or .?cgi
    # Keep .bak and this script excluded.
    # ^\w+$ matches only alphanumeric characters between beginning and end
    # ^\w+\.pl$ alphanumeric, a dot and pl between beginning and end
    # ^\w+\..?cgi$ alphanumeric, a dot, 0 or 1 single char. and cgi between...

    my @files =
      grep ( -f && /(^\w+$|^(?!rewriteshbang)\w+\.pl$|^\w+\..?cgi$)/,
        readdir(D) );
    closedir(D);

    print "\nModified files:\n";

    foreach my $file (@files) {
        $scanned++;
        $/ = undef;
        open( F, "<$file" ) || die $!;
        my $contents = <F>;
        close F;

        if ( $contents =~ s/^#!\s*\S+/#!$new_path/s ) {
            my $mode = ( stat("$file") )[2];
            chmod( oct(600), "$file" );
            open( F, ">$file" ) || die $!;
            print F $contents;
            close F;
            chmod( $mode, "$file" );
            print "$cwd/$file\n";
            $changed++;
        }
        else {
            print "$cwd/$file\n";
        }
    }
    print "$changed of $scanned files changed\n";
}

if ( $os =~ /^MSWin/ ) {
    print "\nFinished, closing in 10 seconds, so Windows users may not have
the window closed immediately.\n";
    sleep(10);
}
exit 0
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
