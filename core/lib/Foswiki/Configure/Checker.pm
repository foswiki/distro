# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Checker;

Base class of all checkers. Checkers give checking and guessing support
for configuration values. Most of the methods of this class are intended
to be protected i.e. only available to subclasses.

=cut

package Foswiki::Configure::Checker;

use strict;
use warnings;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

use File::Spec               ();
use CGI                      ();
use Foswiki::Configure::Load ();

=begin TML

---++ ObjectMethod check($value) -> $html
   * $value - Value object for the thing being checked

Entry point for the value check. Overridden by subclasses.

Returns html formatted by $this->ERROR(), WARN(), NOTE(), or
hand made _OR_ an empty string. The output of a checker will normally
be included in an HTML table, so don't get too carried away.

=cut

sub check {
    my ( $this, $value ) = @_;

    # default behaviour; see no evil, hear no evil, speak no evil
    return $this->showExpandedValue($value);
}

=begin TML

---++ PROTECTED ObjectMethod guessed($status) -> $html

A checker can either check the sanity of the previously saved value,
or guess a one if none exists. If the checker guesses, it should call
=$this->guessed(0)= (passing 1 if the guess was an error).

=cut

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

=begin TML

---++ ObjectMethod getCfg($name) -> $expanded_val
Get the value of the named configuration var. The name is in the form 
getCfg("{Validation}{ExpireKeyOnUse}")

Any embedded references to other Foswiki::cfg vars will be expanded.

=cut

sub getCfg {
    my ( $this, $name ) = @_;
    my $item = '$Foswiki::cfg' . $name;
    Foswiki::Configure::Load::expandValue($item);
    return $item;
}

=begin TML

---++ PROTECTED ObjectMethod warnAboutWindowsBackSlashes($path) -> $html

Generate a warning if the supplied pathname includes windows-style
path separators.

=cut

sub warnAboutWindowsBackSlashes {
    my ( $this, $path ) = @_;
    if ( $path =~ /\\/ ) {
        return $this->WARN(
                'You should use c:/path style slashes, not c:\path in "' 
              . $path
              . '"' );
    }
}

=begin TML

---++ PROTECTED ObjectMethod guessMajorDir($cfg, $dir, $silent) -> $html

Try and guess the path of one of the major directories, by looking relative
to the absolute pathname of the dir where configure is being run.

=cut

sub guessMajorDir {
    my ( $this, $cfg, $dir, $silent ) = @_;
    my $msg = '';
    my $val = $this->getCfg("{$cfg}");
    if ( !$val || $val eq 'NOT SET' || $val eq 'undef' ) {
        require FindBin;
        $FindBin::Bin =~ /^(.*)$/;
        my $scriptDir = $1;
        my @root      = File::Spec->splitdir($scriptDir);
        pop(@root);
        $Foswiki::cfg{$cfg} =
          ( $cfg eq 'ScriptDir' )
          ? $scriptDir
          : File::Spec->catfile( @root, $dir );
        $Foswiki::cfg{$cfg} =~ s|\\|/|g;
        $msg = $this->guessed();
    }
    unless ( $silent || -d $Foswiki::cfg{$cfg} ) {
        $msg .= $this->ERROR("Directory '$Foswiki::cfg{$cfg}'  does not exist");
    }
    return $msg;
}

=begin TML

---++ PROTECTED ObjectMethod showExpandedValue -> $html

Return the expanded value of a parameter as a note for display.

=cut

sub showExpandedValue {
    my ( $this, $field ) = @_;
    my $msg = '';

    if ( $field =~ m/\$Foswiki::cfg/ ) {
        Foswiki::Configure::Load::expandValue($field);
        $msg = $this->NOTE( '<b>Note:</b> Expands to: ' . $field );
    }
    return $msg;
}

=begin TML

---++ PROTECTED ObjectMethod checkTreePerms($path, $perms, $filter) -> $html

Perform a recursive check of the specified path.  The recursive check 
is limited to the configured "PathCheckLimit".  This prevents excessive
delay on installations with large data or pub directories.  The
count of files checked is available in the class method $this->{fileCount}

$perms is a string of permissions to check:

Basic checks:
   * r - File or directory is readable 
   * w - File or directory is writable
   * x - File is executable.

All failures of the basic checks are reported back to the caller.

Enhanced checks:
   * d - Directory permission matches the permissions in {RCS}{dirPermission}
   * f - File permission matches the permission in {RCS}{filePermission}  (FUTURE)
   * p - Verify that a WebPreferences exists for each web

If > 20 enhanced errors are encountered, reporting is stopped to avoid excessive
errors to the administrator.   The count of enhanced errors is reported back 
to the caller by the object variable:  $this->{fileErrors}

In addition to the basic and enhanced checks specified in the $perms string, 
Directories are always checked to determine if they have the 'x' permission.

$filter is a regular expression.  Files matching the supplied regex if present
will not be checked.  This is used to skip rcs,v  or .txt files because they
have different permission requirements.

Note that the enhanced checks are important especially on hosted sites. In some
environments, the Foswiki perl scripts run under a different user/group than 
the web server.  Basic checks will pass, but the server may still be unable
to access the file.  The enhanced checks will detect this condition.

Callers of this checker should reset $this->{fileCount} and $this->{fileErrors} 
to zero before calling this routine.

=cut

sub checkTreePerms {
    my ( $this, $path, $perms, $filter ) = @_;

    return '' if ( defined($filter) && $path =~ $filter && !-d $path );

    $this->{fileErrors}  = 0 unless ( defined $this->{fileErrors} );
    $this->{missingFile} = 0 unless ( defined $this->{missingFile} );
    $this->{excessPerms} = 0 unless ( defined $this->{excessPerms} );

    #let's ignore Subversion directories
    return '' if ( $path eq '_svn' );
    return '' if ( $path eq '.svn' );

    # Okay to increment count once filtered files are ignored.
    $this->{filecount}++;

    my $errs      = '';
    my $permErrs  = '';
    my $rwxString = buildRWXMessageString( $perms, $path );

    return $path . ' cannot be found' . CGI::br()
      unless ( -e $path || -l $path );

    if ( $perms =~ /d/ && -d $path ) {
        my $mode = ( stat($path) )[2] & oct(7777);
        if ( $mode != $Foswiki::cfg{RCS}{dirPermission} ) {
            my $omode = sprintf( '%04o', $mode );
            my $operm = sprintf( '%04o', $Foswiki::cfg{RCS}{dirPermission} );
            if (
                (
                    ( $mode | $Foswiki::cfg{RCS}{dirPermission} )
                    ^ $Foswiki::cfg{RCS}{dirPermission}
                )
              )
            {
                $permErrs .= $this->getEmptyStringUnlessUnderLimit(
                    'excessPerms',
"$path - directory permission $omode differs from requested $operm - check directory for possible excess permissions"
                );
            }
            if ( ( $mode & $Foswiki::cfg{RCS}{dirPermission} ) !=
                $Foswiki::cfg{RCS}{dirPermission} )
            {
                $permErrs .= $this->getEmptyStringUnlessUnderLimit(
                    'fileErrors',
"$path - directory permission $omode differs from requested $operm - check directory for possible insufficient permissions"
                );
            }
        }
    }

    if ( $perms =~ /f/ && -f $path ) {
        my $mode = ( stat($path) )[2] & oct(7777);
        if ( $mode != $Foswiki::cfg{RCS}{filePermission} ) {
            my $omode = sprintf( '%04o', $mode );
            my $operm = sprintf( '%04o', $Foswiki::cfg{RCS}{filePermission} );
            if (
                (
                    ( $mode | $Foswiki::cfg{RCS}{filePermission} )
                    ^ $Foswiki::cfg{RCS}{filePermission}
                )
              )
            {
                $permErrs .= $this->getEmptyStringUnlessUnderLimit(
                    'excessPerms',
"$path - file permission $omode differs from requested $operm - check file for possible excess permissions"
                );
            }
            if ( ( $mode & $Foswiki::cfg{RCS}{filePermission} ) !=
                $Foswiki::cfg{RCS}{filePermission} )
            {
                $permErrs .= $this->getEmptyStringUnlessUnderLimit(
                    'fileErrors',
"$path - file permission $omode differs from requested $operm - check file for possible insufficient permissions"
                );
            }
        }
    }

    if (   $perms =~ /p/
        && $path =~ /\Q$Foswiki::cfg{DataDir}\E\/(.+)$/
        && -d $path )
    {
        unless ( -e "$path/$Foswiki::cfg{WebPrefsTopicName}.txt" ) {
            $permErrs .= " $path missing $Foswiki::cfg{WebPrefsTopicName} Topic"
              . CGI::br();
            $this->{missingFile}++;
        }
    }

    if ($rwxString) {
        $errs .=
          $this->getEmptyStringUnlessUnderLimit( 'fileErrors', $rwxString );
    }

    return $permErrs . $path . $errs . CGI::br() if $errs;

    return $permErrs unless -d $path;

    return
        $permErrs 
      . $path
      . ' directory is missing \'x\' permission - not readable'
      . CGI::br()
      if ( -d $path && !-x $path );

    opendir( my $Dfh, $path )
      or return 'Directory ' . $path . ' is not readable.' . CGI::br();

    foreach my $e ( grep { !/^\./ } readdir($Dfh) ) {
        my $p = $path . '/' . $e;
        $errs .= checkTreePerms( $this, $p, $perms, $filter );
        last if ( $this->{filecount} >= $Foswiki::cfg{PathCheckLimit} );

    }
    closedir($Dfh);

    return $permErrs . $errs;
}

sub getEmptyStringUnlessUnderLimit {
    my ( $this, $type, $message ) = @_;
    my $errs = '';

    $this->{$type}++;
    if ( $this->{$type} < 10 ) {
        if ($message) {
            $errs = $message . CGI::br();
        }
    }

    return $errs;
}

sub buildRWXMessageString {
    my ( $perms, $path ) = @_;
    my $message = '';

    if ( $perms =~ /r/ && !-r $path ) {
        $message .= ' not readable';
    }

    if ( $perms =~ /w/ && !-d $path && !-w $path ) {
        $message .= ' not writable';
    }

    if ( $perms =~ /x/ && !-x $path ) {
        $message .= ' not executable';
    }

    return $message;
}

=begin TML

---++ PROTECTED ObjectMethod checkCanCreateFile($path) -> $html

Check that the given path can be created (or, if it already exists,
can be written). If the existing path is a directory, recursively
check for rw permissions using =checkTreePerms=.

Returns a message or the empty string if the check passed.

=cut

sub checkCanCreateFile {
    my ( $this, $name ) = @_;

    if ( -e $name ) {

        # if the file exists just check perms and return
        return $this->checkTreePerms( $name, 'rw' );
    }

    # check the containing dir
    my @path = File::Spec->splitdir($name);
    pop(@path);
    unless ( -w File::Spec->catfile( @path, '' ) ) {
        return File::Spec->catfile( @path, '' ) . ' is not writable';
    }
    my $txt1 = "test 1 2 3";
    open my $fh, '>', $name
      || return 'Could not create test file ' . $name . ':' . $!;
    print $fh $txt1;
    close($fh);
    open my $in_file, '<', $name
      || return 'Could not read test file ' . $name . ':' . $!;
    my $txt2 = <$in_file>;
    close($in_file);
    unlink $name if ( -e $name );

    unless ( $txt2 eq $txt1 ) {
        return 'Could not write and then read ' . $name;
    }
    return '';
}

=begin TML

---++ PROTECTED ObjectMethod checkGnuProgram($prog) -> $html

Check for the availability of a GNU program.

Since Windows (without Cygwin) makes it hard to capture stderr
('2>&1' works only on Win2000 or higher), and Windows will usually have
GNU tools in any case (installed for Foswiki since there's no built-in
diff, grep, patch, etc), we only check for these tools on Unix/Linux
and Cygwin.

=cut

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
    elsif ( $Foswiki::cfg{OS} eq 'WINDOWS' ) {

        #real windows - using GnuWin32 tools
    }

    return $mess;
}

=begin TML

---++ PROTECTED ObjectMethod checkRE($keys) -> $html
Check that the configuration item identified by the given keys represents
a compilable perl regular expression.

=cut

sub checkRE {
    my ( $this, $keys ) = @_;
    my $str;
    eval { $str = $Foswiki::cfg . $keys; };
    return '' unless defined $str;
    eval { qr/$str/ };
    if ($@) {
        return $this->ERROR(<<"MESS");
Invalid regular expression: $@ <p />
See <a href="http://www.perl.com/doc/manual/html/pod/perlre.html">perl.com</a> for help with Perl regular expressions.
MESS
    }
    return '';
}

my $rcsverRequired = 5.7;

=begin TML

---++ PROTECTED ObjectMethod checkRCSProgram($prog) -> $html
Specific to RCS, this method checks that the given program is available.
Check is only activated when the selected store implementation is RcsWrap.

=cut

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
            $err . <<'HERE'
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
