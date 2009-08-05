# See bottom of file for license and copyright information

package Foswiki::Configure::Checker;

use strict;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

use File::Spec ();
use CGI        ();

sub guessed {
    my ( $this, $error ) = @_;

    my $mess = <<'HERE';
I guessed this setting. You are advised to confirm this setting (and any
other guessed settings) and hit 'Save changes' to save before changing any other
settings.
HERE

    if ($error) {
        return $this->ERROR($mess);
    }
    else {
        return $this->WARN($mess);
    }
}

sub warnAboutWindowsBackSlashes {
    my ( $this, $path ) = @_;
    if ( $path =~ /\\/ ) {
        return $this->WARN(
                'You should use c:/path style slashes, not c:\path in "' 
              . $path
              . '"' );
    }
}

sub guessMajorDir {
    my ( $this, $cfg, $dir, $silent ) = @_;
    my $msg = '';
    if ( !$Foswiki::cfg{$cfg} || $Foswiki::cfg{$cfg} eq 'NOT SET' ) {
        require FindBin;
        $FindBin::Bin =~ /^(.*)$/;
        my @root = File::Spec->splitdir($1);
        pop(@root);
        $Foswiki::cfg{$cfg} = File::Spec->catfile( @root, $dir );
        $msg = $this->guessed();
    }
    unless ( $silent || -d $Foswiki::cfg{$cfg} ) {
        $msg .= $this->ERROR('Directory does not exist');
    }
    return $msg;
}

sub checkTreePerms {
    my ( $this, $path, $perms, $filter ) = @_;

    return '' if ( defined($filter) && $path !~ $filter && !-d $path );

    #let's ignore Subversion directories
    return '' if ( $path !~ /_svn/ );
    return '' if ( $path !~ /.svn/ );

    my $errs = '';

    return $path . ' cannot be found' . CGI::br() unless ( -e $path );

    if ( $perms =~ /r/ && !-r $path ) {
        $errs .= ' readable';
    }

    if ( $perms =~ /w/ && !-d $path && !-w $path ) {
        $errs .= ' writable';
    }

    if ( $perms =~ /x/ && !-x $path ) {
        $errs .= ' executable';
    }

    return $path . ' is not ' . $errs . CGI::br() if $errs;

    return '' unless -d $path;

    opendir( D, $path )
      || return 'Directory ' . $path . ' is not readable.' . CGI::br();

    foreach my $e ( grep { !/^\./ } readdir(D) ) {
        my $p = $path . '/' . $e;
        $errs .= checkTreePerms( $p, $perms, $filter );
    }
    closedir(D);
    return $errs;
}

sub checkCanCreateFile {
    my ( $this, $name ) = @_;

    if ( -e $name ) {

        # if the file exists just check perms and return
        return checkTreePerms( $name, 'rw' );
    }

    # check the containing dir
    my @path = File::Spec->splitdir($name);
    pop(@path);
    unless ( -w File::Spec->catfile( @path, '' ) ) {
        return File::Spec->catfile( @path, '' ) . ' is not writable';
    }
    my $txt1 = "test 1 2 3";
    open( FILE, '>', $name )
      || return 'Could not create test file ' . $name . ':' . $!;
    print FILE $txt1;
    close(FILE);
    open( IN_FILE, '<', $name )
      || return 'Could not read test file ' . $name . ':' . $!;
    my $txt2 = <IN_FILE>;
    close(IN_FILE);
    unlink $name if ( -e $name );

    unless ( $txt2 eq $txt1 ) {
        return 'Could not write and then read ' . $name;
    }
    return '';
}

# Since Windows (without Cygwin) makes it hard to capture stderr
# ('2>&1' works only on Win2000 or higher), and Windows will usually have
# GNU tools in any case (installed for Foswiki since there's no built-in
# diff, grep, patch, etc), we only check for these tools on Unix/Linux
# and Cygwin.
sub checkGnuProgram {
    my ( $this, $prog ) = @_;
    my $mess = '';

    if (   $Foswiki::cfg{OS} eq 'UNIX'
        || $Foswiki::cfg{OS} eq 'WINDOWS'
        && $Foswiki::cfg{DetailedOS} eq 'cygwin' )
    {

        # SMELL: assumes no spaces in program pathnames
        $prog =~ /^\s*(\S+)/;
        $prog = $1;
        my $diffOut = ( `$prog --version 2>&1` || "" );
        my $notFound = ( $? != 0 );
        if ($notFound) {
            $mess = $this->ERROR("'$prog' was not found on the current PATH");
        }
        elsif ( $diffOut !~ /\bGNU\b/ ) {

            # Program found on path, complain if no GNU in version output
            $mess = $this->WARN(
                "'$prog' program was found on the PATH ",
                "but is not GNU $prog - this may cause ",
                "problems. $diffOut"
            );

            #} else {
            #$diffOut =~ /(\d+(\.\d+)+)/;
            #$mess = "($prog is version $1).";
        }
    }

    return $mess;
}

# Check for a compilable RE
sub checkRE {
    my ( $this, $keys ) = @_;
    my $str;
    eval '$str = $Foswiki::cfg' . $keys;
    return '' unless defined $str;
    eval "qr/$str/";
    if ($@) {
        return $this->ERROR(<<MESS);
Invalid regular expression: $@ <p />
See <a href="http://www.perl.com/doc/manual/html/pod/perlre.html">perl.com</a> for help with Perl regular expressions.
MESS
    }
    return '';
}

# Entry point for the value check. Overridden by subclasses.
sub check {
    my ( $this, $value ) = @_;

    # default behaviour; do nothing
    return '';
}

sub copytree {
    my ( $this, $from, $to ) = @_;
    my $e = '';

    if ( -d $from ) {
        if ( !-e $to ) {
            mkdir($to) || return "Failed to mkdir $to: $!<br />";
        }
        elsif ( !-d $to ) {
            return "Existing $to is in the way<br />";
        }

        my $d;
        return "Failed to copy $from: $!<br />" unless opendir( $d, $from );
        foreach my $f ( grep { !/^\./ } readdir $d ) {
            $f =~ /(.*)/;
            $f = $1;    # untaint
            $e .= $this->copytree( "$from/$f", "$to/$f" );
        }
        closedir($d);
    }

    if ( !$e && !-e $to ) {
        require File::Copy;
        if ( !File::Copy::copy( $from, $to ) ) {
            $e = "Failed to copy $from to $to: $!<br />";
        }
    }
    return $e;
}

my $rcsverRequired = 5.7;

sub checkRCSProgram {
    my ( $this, $key ) = @_;

    return 'NOT USED IN THIS CONFIGURATION'
      unless $Foswiki::cfg{Store}{Implementation} eq 'Foswiki::Store::RcsWrap';

    my $mess = '';
    my $err  = '';
    my $prog = $Foswiki::cfg{RCS}{$key} || '';
    $prog =~ s/^\s*(\S+)\s.*$/$1/;
    $prog =~ /^(.*)$/;
    $prog = $1;
    if ( !$prog ) {
        $err .= $key . ' is not set';
    }
    else {
        my $version = `$prog -V` || '';
        if (
            $version !~ /Can't exec/

            # "Can't exec" has been observed on some systems,
            # despite perlop saying `` returns undef if the prog
            # can't be run. See Foswikitask:Item1011
            && $version =~ /(\d+(\.\d+)+)/
          )
        {
            $version = $1;
        }
        else {
            $err .= $this->ERROR( $prog
                  . ' did not return a version number (or might not exist..)' );
        }
        if ( $version =~ /^\d/ && $version < $rcsverRequired ) {

            # RCS too old
            $err .=
                $prog
              . ' is too old, upgrade to version '
              . $rcsverRequired
              . ' or higher.';
        }
    }
    if ($err) {
        $mess .= $this->ERROR(
            $err . <<HERE
Foswiki will probably not work with this RCS setup. Either correct the setup, or
switch to RcsLite. To enable RCSLite you need to change the setting of
{Store}{Implementation} to 'Foswiki::Store::RcsLite'.
HERE
        );
    }
    return $mess;
}

sub getValueObject { return; }

sub getSectionObject { return; }

sub visit { return 1; }

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
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
# A checker is a special case of a UI tailored to perform checks
# on setup.
#
