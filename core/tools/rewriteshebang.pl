#!/usr/bin/perl -w
# See bottom of file for license and copyright information
# On Unix the -T switch can be used but was removed because it caused trouble
# on Windows.

use strict;
use warnings;
use Cwd;
use Getopt::Long;
use Pod::Usage;
use File::Spec;

use strict;

# Assume we are in the tools dir, and we can find bin and lib from there
use FindBin ();
use lib "$FindBin::Bin/../bin";

require 'setlib.cfg';
require Foswiki::Configure::FileUtil;

# SMELL: setlib does "require CGI" which sets STDIN to binmode.
binmode( STDIN, ':crlf' );

my $new_path     = '';
my @default_dir  = ( '../tools', '../bin', );
my $expect_perlv = 5.008008;
my $ask          = 1;
my $taint        = 0;                           # Default is no taint checking
my $not_just_cwd = '';
my $os           = $^O;
my $new_perlv;
my @directories;
my @args;
$/ = "\n";

# Parse options and print usage if there is a syntax error,
# or if usage was explicitly requested.
# Also consider perldoc availability.
my $help    = 0;
my $man     = 0;
my $perldoc = qx| perldoc 2>&1 1>/dev/null |;
GetOptions(
    'help|?'        => \$help,
    man             => \$man,
    'path|p=s'      => \$new_path,
    'taint!'        => \$taint,
    'directory|d=s' => \@directories,
    'ask!'          => \$ask
) or pod2usage(2);
pod2usage(1) if $help;
if ( $perldoc =~ /^Usage: perldoc.*/ ) {
    pod2usage( -verbose => 2 ) if $man;
}
else {
    pod2usage( -verbose => 2, -noperldoc => 1 ) if $man;
}

unless ($new_path) {
    $new_path = $^X;
}

unless (@directories) {
    @directories = @default_dir;
}

# Here we guide the user and ask for confirmations

if ( $ask == 1 ) {

    print "
Description
-----------
Use option -m or --man to read the manual page and to become aware about
limitations regarding the automatically suggested path.

Taint option set to $taint

Environment
-----------
Running Perl $^V ($]) using absolute path:
$^X

Select Path
-----------
Note: the path to the interpreter *must not* contain any spaces.\n";

    while (1) {
        print "Enter path to interpreter [hit enter to choose '$new_path']: ";
        my $n = <>;
        chomp $n;
        last if ( !$n );    # exit if $n undefined or 0
        $new_path = $n;
    }

    unless ( $new_path =~ m#^/usr/bin/env perl# || -x "$new_path" ) {
        while (1) {
            print "\nWarning: I could not find an executable at \"$new_path\"
Are you sure you want to use this path (y/n)?: ";
            my $n = <>;
            chomp $n;
            die "Aborted\n" unless $n =~ /^y|^$/i;
            last if $n =~ /^y/i;
        }
    }

    # Here we go and check the new interpreter version
    # Parts of this code are duplicated further below but are due to context
    # a bit less secure here.

    # Using $new_path to execute it on the system which is an
    # *insecure dependency* in taint mode but in this context the script is
    # expected to run directly from a shell.
    # Now untainting it by checking additional things which doesn't necessarily
    # make it save! Please approve/double check it to remain careful.

    $ENV{"PATH"} = ""; # untainted environment for system call
                       # Unix and Windows path matching without spaces to untain
    if ( $new_path =~ m/(.*?\/env perl\b)/ ) {

        # probably /usr/bin/env perl.  No parameters supported.
        $new_path = "$1";            # untaint
        @args     = ("$new_path");
    }
    elsif ( $new_path =~
        /(^(\.)?(\/[^\/]+)+(\.exe)?$|^[[:alpha:]]:(\\[^\\]+)+(\.exe)?$|^perl$)/i
      )
    {
        $new_path = "$1";            # untainted variable
        @args      = ( "$new_path", "-Mstrict", "-w", '-e "print $];"' );
        $new_perlv = qx|@args|;
        if ( $new_perlv < $expect_perlv ) {
            while (1) {
                print
"\nThe new Perl interpreter uses version \"$new_perlv\". If your path was just
\"perl\" this number might be wrong as in web server context you may use a
different environment. The verified version is not recommended for a current
Foswiki installation.
Are you still sure you want to use this path (y/n): ";
                my $n = <>;
                chomp $n;
                die "Aborted\n" unless $n =~ /^y|^$/i;
                last if $n =~ /^y/i;
            }
        }
        print "\nNew Perl interpreter uses version $new_perlv\n";
    }
    else {
        print
          "\nERROR: Regex verfication of given path failed. Going to exit.\n";
        &keep_open_on_windows;
        exit 1;
    }

    while (1) {
        print
          "\n\"No\" will only change \"shebang\" lines of scripts found in ";
        print getcwd() . "\n";
        print "Are you sure you want to change scripts in the ";
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
}

# Here we do not ask anything to make live easy for anyone who knows
# or to allow calling this program from a web interface.
else {

    # If additional arguments than just the path itself exist in $new_path
    # then it "usually" dies here already.
    unless ( -x "$new_path" ) {
        die "Path to Perl interpreter is not executable.\n$!";
    }
    else {

        # Using $new_path to execute it on the system
        # which is an *insecure dependency* in taint mode!
        # Now untainting it by checking additional things
        # which doesn't necessarily make it save!
        # Please approve/double check it to remain careful.

        $ENV{"PATH"} = "";    # untainted environment for system call
           # Unix and Windows path matching on Perl executables to get untainted
        if ( $new_path =~
/(^(\/[^\/]+)+\/perl(\.exe)?$|^[[:alpha:]]:(\\[^\\]+)+\\perl(\.exe)?$|^perl$)/
          )
        {
            $new_path = "$1";    # untainted variable
            @args      = ( "$new_path", "-Mstrict", "-w", '-e "print $];"' );
            $new_perlv = qx|@args|;
            $new_perlv > $expect_perlv
              || die
"The new Perl interpreter uses version \"$new_perlv\". This is not recommended for a current Foswiki installation. If you still want to use this path then please run the script manually using option --ask to confirm.\n$!";
            print "\nNew Perl interpreter uses version $new_perlv\n";
        }
    }
    $not_just_cwd = 'y';
}

if ( $not_just_cwd =~ /^y/i ) {
    foreach (@directories) {
        print "\nProcessing directory: $_\n";
        chdir "$_" || die "Can't change to directory. $!";
        opendir( D, "." ) || die "Can't open current directory. $!";
        &change_files;
    }
}
else {
    opendir( D, "." ) || die "Can't open current directory. $!";
    &change_files;
}

print "\n";
&keep_open_on_windows;

#############
# Subroutines

sub change_files {

    my $cwd     = getcwd;
    my $scanned = 0;
    my $changed = 0;

    my $tflag = ( $cwd =~ m/bin$/ ) ? $taint : undef;

    # Grep relevant files to process while only including .pl, .cgi or .?cgi
    # Keep .bak and this script excluded.
    # ^\w+$ matches only alphanumeric characters between beginning and end
    # ^\w+\.pl$ alphanumeric, a dot and pl between beginning and end
    # ^\w+\..?cgi$ alphanumeric, a dot, 0 or 1 single char. and cgi between...

    my @files =
      grep ( -f && /(^\w+$|^(?!rewriteshebang)\w+\.pl$|^\w+\..?cgi$)/,
        readdir(D) );
    closedir(D);

    print "\nProcessed files:\n";

    @files = sort(@files);

    foreach my $file (@files) {
        $scanned++;

        my $rewriteErr =
          Foswiki::Configure::FileUtil::rewriteShebang( $file, $new_path,
            $tflag );

        if ($rewriteErr) {
            print "$cwd/$file - $rewriteErr \n";
        }
        else {
            print "$cwd/$file\n";
            $changed++;
        }
    }
    print "$changed of $scanned files changed\n";
}

sub keep_open_on_windows {
    if ( $os =~ /^MSWin/ ) {
        print "\nClosing in 8 seconds, so Windows users may not have
the window closed immediately.\n";
        sleep(8);
    }
}

exit 0
__END__

=head1 NAME

rewriteshebang.pl - Changing the shebang line of most scripts to the given path
in the specified directories

=head1 SYNOPSIS

rewriteshebang.pl [-a|--ask] [-d|--directory <directory>] [--noask] [-p|--path <path to Perl interpreter>] [-h|?|--help] [-m|--man]  [-t|taint]

Options:

B<-a> or B<--ask> enables confirmations (default)

B<-d> or B<--directory> directory to process, repeat to add more than one directory

B<--noask> disable confirmations

B<-p> or B<--path> path to Perl interpreter

B<-h> or B<-?> or B<--help> brief help message

B<-m> or B<--man> full documentation

B<--taint> / B<-t> or B<--notaint> / B<-not>  Set (--taint)  or clear (--notaint) the -T taint flags from the shebang. Note that this option is ONLY applied to the bin directory.

=head1 OPTIONS

=over 8

=item B<-a|--ask>

Enable questions to confirm chosen values before proceeding. Passing this option is not required because it is enabled by default.

=item B<-d|--directory> <path to directory>

Provide a directory path for processing. Use this option multiple times to specify multiple directories. Using it replaces all values of any pre-configured default directories.

=item B<--noask>

Disable confirming questions. Run the script without asking for any approving confirmation!

=item B<-p|--path> <path to Perl interpreter>

Provide the absolute pathname to the Perl interpreter and use it to rewrite shebang lines of most if not all scripts in the specified directories.

=item B<-h|--help>

Prints a brief help message and exits.

=item B<-m|--man>

Prints the manual page and exits.

=item B<-t|--taint>

Enables the -T (Taint checking) flag in the Perl command line.  By default any -T flag in the script shebang lines will be removed.  It is recommended that developers enable this option to have perl check for unvalidated parameters. 
Note that taint checking is not compatible with use of Locales,  and has an approximate 10% performance penalty.

=back

=head1 DESCRIPTION

B<This program> will change the shebang lines of all Perl scripts found either in the current directory, as configured in @default_dirs or as specified by option -d or --directory. Default is to change ../tools and ../bin directories. You will be asked to confirm accordingly unless you are using option --noask.

Shebang lines tell the shell what interpreter to use for running scripts. By default the Foswiki bin scripts are set to use the "/usr/bin/perl" interpreter, which is where perl lives on most UNIX-like platforms. On some platforms you will need to change this line to run a different interpreter e.g. "D:\indigoperl\bin\perl" or "/usr/bin/speedy".

This script will change the shebang lines of most if not all scripts found in the given directories except for itself. It processes all files without suffix and files with suffixes .pl, .cgi or .?cgi e.g. .fcgi etc.

B<Note:> The path to the Perl interpreter must not contain any spaces.

The given path will be verified slightly different if running with --noask. In this mode the path must end with the word "perl" or "perl.exe" or only use the single word "perl". However, if the path is not executable the script will die. If you want to use something more uncommon, then please run the script manually using --ask and confirm your requirements explicitly.

When the script is executed without parameters from the command line, it shows the Perl version used and offers the path to this Perl as default selection using the special Perl variable B<$^X>. This results in a static path not using symlinks (on Unix). Probably you want a default path like "/usr/bin/perl" or a path following symlinks to be save in case of a Perl upgrade. However, this path is presented as default suggestion and you have been warned about its limitations.

This program also aims at Windows users who are probably most commonly in need to change the default shebang line.

=cut

------------------------------------------------------------
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
