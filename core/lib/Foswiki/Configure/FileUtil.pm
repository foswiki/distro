# See bottom of file for license and copyright information

package Foswiki::Configure::FileUtil;

=begin TML

---+ package Foswiki::Configure::FileUtil

Basic file utilities

=cut

use strict;
use warnings;

use Assert;

=begin TML

---++ StaticMethod findFileOnPath($filename) ->> $fullpath
Find a file on the @INC path, or undef if not found.

$filename may be a simple file name e.g. Example.pm
or may be a /-separated path e.g. Net/Util
or a class path e.g. Net::Util

Note that a terminating .pm is required to find a
perl module.

=cut

sub findFileOnPath {
    my $file = shift;

    $file =~ s(::)(/)g;

    foreach my $dir (@INC) {
        if ( -e "$dir/$file" ) {
            return "$dir/$file";
        }
    }
    return undef;
}

=begin TML

---++ StaticMethod lscFileName() -> $localsite_cfg_path

Determine the pathname of LocalSite.cfg. This file must be
on the path, but may not exist yet; it it doesn't, then
Foswiki.spec must be and LocalSite.cfg will be placed in the
same directory.

=cut

sub lscFileName {
    my $lsc = findFileOnPath('LocalSite.cfg');

    return $lsc if ($lsc);

    # If not found on the path, park it beside Foswiki.spec
    $lsc = findFileOnPath('Foswiki.spec');
    if ($lsc) {
        $lsc =~ s/Foswiki\.spec/LocalSite.cfg/;
        return $lsc;
    }

    # No existing file we can use
    return undef;
}

=begin TML

---++ StaticMethod findPackages( $pattern ) -> @list

Finds all packages that match the pattern in @INC

   * =$pattern= is a wildcard expression that matches classes e.g.
     Foswiki::Plugins::*Plugin. * is the only wildcard supported.

Return a list of package names.

=cut

sub findPackages {
    my ($pattern) = @_;

    $pattern =~ s/\*/.*/g;
    my @path = split( /::/, $pattern );

    my $places = \@INC;
    my $dir;

    while ( scalar(@path) > 1 && @$places ) {
        my $pathel = shift(@path);
        eval "\$pathel = qr/^($pathel)\$/";    # () to untaint
        my @newplaces;

        foreach my $place (@$places) {
            if ( opendir( $dir, $place ) ) {

                #next if ($place =~ /^\..*/);
                foreach my $subplace ( readdir $dir ) {
                    next unless $subplace =~ $pathel;

                    #next if ($subplace =~ /^\..*/);
                    push( @newplaces, $place . '/' . $1 );
                }
                closedir $dir;
            }
        }
        $places = \@newplaces;
    }

    my @list;
    my $leaf = pop(@path);
    eval "\$leaf = qr/$leaf\\.pm\$/";
    ASSERT( !$@, $@ ) if DEBUG;

    my %known;
    foreach my $place (@$places) {
        if ( opendir( $dir, $place ) ) {
            foreach my $file ( readdir $dir ) {
                next unless $file =~ $leaf;
                next if ( $file =~ /^\..*/ );
                next unless $file =~ /^(.*)\.pm$/;
                my $module = "$place/$1";
                $module =~ s./.::.g;
                if ( $module =~ /($pattern)$/ ) {
                    push( @list, $1 ) unless $known{$1};
                    $known{$1} = 1;
                }
            }
            closedir $dir;
        }
    }
    return @list;
}

=begin TML

---++ StaticMethod checkCanCreateFile($path) -> $report

Check that the given path can be created (or, if it already exists,
can be written). If the existing path is a directory, recursively
check for rw permissions using =checkTreePerms=.

Returns a message if the check fails or undef if the check passed.

=cut

sub checkCanCreateFile {
    my ($name) = @_;

    if ( -e $name ) {

        # if the file exists just check perms and return
        my $report = checkTreePerms( $name, 'rw' );
        if ( @{ $report->{messages} } ) {
            return join( "\n", @{ $report->{messages} } );
        }
        return undef;
    }

    # check the containing dir
    my @path = File::Spec->splitdir($name);
    pop(@path);
    unless ( -w File::Spec->catfile( @path, '' ) ) {
        return File::Spec->catfile( @path, '' ) . ' is not writable';
    }
    my $txt1 = "test 1 2 3";
    open( my $fh, '>', $name )
      or return 'Could not create test file ' . $name . ':' . $!;
    print $fh $txt1;
    close($fh);
    open( my $in_file, '<', $name )
      or return 'Could not read test file ' . $name . ':' . $!;
    my $txt2 = <$in_file>;
    close($in_file);
    unlink $name if ( -e $name );

    unless ( $txt2 eq $txt1 ) {
        return 'Could not write and then read ' . $name;
    }
    return '';
}

=begin TML

---++ StaticMethod checkTreePerms($path, $perms, %options) -> \%report

Perform a recursive check of the specified path.
No failures will return undef, otherwise a string report is generated.

$perms is a string of permissions to check:

Basic checks:
   * r - File or directory is readable 
   * w - File or directory is writable
   * x - File is executable.

Enhanced checks:
   * d - Directory permission matches the permissions
         in {Store}{dirPermission}
   * f - File permission matches the permission in
         {Store}{filePermission}  (FUTURE)
   * p - Verify that a WebPreferences exists for each web

%options may include the following:
   * =filter= is a regular expression.  Files matching the regex
     if present will not be checked. This is used to skip hidden files
     and those with different permission requirements.
   * =maxFileCount= - limit on number of files checked
   * =maxFileErrors= - limit on number of fileError messages generated
     Default is 10
   * =maxExcessPerms= - limit on number of excessPerms messages generated
     Default is 10
   * =maxMissingFile= - limit on number of missing file messages generated
     Default is 10

The returned \%report contains the following fields:
   * fileCount - number of files checked
   * fileErrors - number of file errors errors encountered
   * excessPerms - number of excess permissions encountered
   * missingFile - number of missing files encountered
   * messages - ref of an array containing individual file messages,
     limited as per the options.

In addition to the basic and enhanced checks specified in the $perms string, 
directories are always checked to determine if they have the 'x' permission.

Note that the enhanced checks are important especially on hosted sites. In some
environments, the Foswiki perl scripts run under a different user/group than 
the web server.  Basic checks will pass, but the server may still be unable
to access the file.  The enhanced checks will detect this condition.

=cut

sub checkTreePerms {
    my ( $path, $perms, %options ) = @_;

    my %report = (
        fileCount   => 0,
        fileErrors  => 0,
        missingFile => 0,
        excessPerms => 0,
        messages    => []
    );

    return \%report
      if ( defined( $options{filter} )
        && $path =~ /$options{filter}/
        && !-d $path );

    # Let's ignore Subversion directories
    return \%report if ( $path eq '_svn' );
    return \%report if ( $path eq '.svn' );

    $options{maxFileErrors}  = 10 unless defined $options{maxFileErrors};
    $options{maxExcessPerms} = 10 unless defined $options{maxExcessPerms};
    $options{maxMissingFile} = 10 unless defined $options{maxMissingFile};

    # Okay to increment count once filtered files are ignored.
    $report{fileCount}++;

    my $errs      = '';
    my $permErrs  = '';
    my $rwxString = _buildRWXMessageString( $perms, $path );

    unless ( -e $path || -l $path ) {
        push( @{ $report{messages} }, $path . ' cannot be found' );
        return \%report;
    }

    if ( $perms =~ /d/ && -d $path ) {
        my $mode = ( stat($path) )[2] & oct(7777);
        if ( $mode != $Foswiki::cfg{Store}{dirPermission} ) {
            my $omode = sprintf( '%04o', $mode );
            my $operm = sprintf( '%04o', $Foswiki::cfg{Store}{dirPermission} );
            if (
                (
                    ( $mode | $Foswiki::cfg{Store}{dirPermission} )
                    ^ $Foswiki::cfg{Store}{dirPermission}
                )
              )
            {
                if ( $report{excessPerms}++ < $options{maxExcessPerms} ) {
                    push(
                        @{ $report{messages} },
"$path - directory permission $omode differs from requested $operm - check directory for possible excess permissions\n"
                    );
                }
            }
            if ( ( $mode & $Foswiki::cfg{Store}{dirPermission} ) !=
                $Foswiki::cfg{Store}{dirPermission} )
            {
                if ( $report{fileErrors}++ < $options{maxFileErrors} ) {
                    push(
                        @{ $report{messages} },
"$path - directory permission $omode differs from requested $operm - check directory for possible insufficient permissions\n"
                    );
                }
            }
        }
    }

    if ( $perms =~ /f/ && -f $path ) {
        my $mode = ( stat($path) )[2] & oct(7777);
        if ( $mode != $Foswiki::cfg{Store}{filePermission} ) {
            my $omode = sprintf( '%04o', $mode );
            my $operm = sprintf( '%04o', $Foswiki::cfg{Store}{filePermission} );
            if (
                (
                    ( $mode | $Foswiki::cfg{Store}{filePermission} )
                    ^ $Foswiki::cfg{Store}{filePermission}
                )
              )
            {
                if ( $report{excessPerms}++ < $options{maxExcessPerms} ) {
                    push(
                        @{ $report{messages} },
"$path - file permission $omode differs from requested $operm - check file for possible excess permissions\n"
                    );
                }
            }
            if ( ( $mode & $Foswiki::cfg{Store}{filePermission} ) !=
                $Foswiki::cfg{Store}{filePermission} )
            {
                if ( $report{fileErrors}++ < $options{maxFileErrors} ) {
                    push(
                        @{ $report{messages} },
"$path - file permission $omode differs from requested $operm - check file for possible insufficient permissions"
                    );
                }
            }
        }
    }

    if (   $perms =~ /p/
        && $path =~ /\Q$Foswiki::cfg{DataDir}\E\/(.+)$/
        && -d $path )
    {
        unless ( -e "$path/$Foswiki::cfg{WebPrefsTopicName}.txt" ) {
            unless ( $report{missingFile}++ > $options{maxMissingFile} ) {
                push(
                    @{ $report{messages} },
                    "$path missing $Foswiki::cfg{WebPrefsTopicName} topic"
                );
            }
        }
    }

    if ( $rwxString && $report{fileErrors}++ < $options{maxFileErrors} ) {
        push( @{ $report{messages} }, "=$path= $rwxString" );
    }

    return \%report if scalar( @{ $report{messages} } );

    return \%report unless -d $path;

    if ( -d $path && !-x $path ) {
        unshift( @{ $report{messages} }, "$path missing -x permission" );
        return \%report;
    }

    opendir( my $Dfh, $path )
      or return "Directory $path is not readable.";

    foreach my $e ( grep { !/^\./ } readdir($Dfh) ) {
        my $p = $path . '/' . $e;
        my $subreport = checkTreePerms( $p, $perms, %options );
        while ( my ( $k, $v ) = each %report ) {
            if ( ref($v) eq 'ARRAY' ) {
                push( @$v, @{ $subreport->{$k} } );
            }
            else {
                $report{$k} += $subreport->{$k};
            }
        }
        last
          if ( defined $options{maxFileCount}
            && $report{fileCount} >= $options{maxFileCount} );
    }
    closedir($Dfh);

    return \%report;
}

sub _buildRWXMessageString {
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

---++ StaticMethod checkGNUProgram($prog, $reporter)

Check for the availability of a GNU program.

Since Windows (without Cygwin) makes it hard to capture stderr
('2>&1' works only on Win2000 or higher), and Windows will usually have
GNU tools in any case (installed for Foswiki since there's no built-in
diff, grep, patch, etc), we only check for these tools on Unix/Linux
and Cygwin.

Errors are reproted by calling ERROR and/or WARN on $reporter
=cut

sub checkGNUProgram {
    my ( $prog, $reporter ) = @_;

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
            $reporter->ERROR("'$prog' was not found on the current PATH");
        }
        elsif ( $diffOut !~ /\bGNU\b/ ) {

            # Program found on path, complain if no GNU in version output
            $reporter->WARN(
                "'$prog' program was found on the PATH ",
                "but is not GNU $prog - this may cause ",
                "problems. $diffOut"
            );
        }
    }
    elsif ( $Foswiki::cfg{OS} eq 'WINDOWS' ) {

        #real windows - using GnuWin32 tools
    }

}

=begin TML

---++ StaticMethod copytree($from, $to) => @errors

Copy a directory tree from one place to another.
Errors are reported in @errors, empty if it succeeds.
A partial copy may happen if the copy fails mid-way.

=cut

sub copytree {
    my ( $from, $to ) = @_;

    if ( -d $from ) {
        if ( !-e $to ) {
            mkdir($to) || return ("Failed to mkdir $to: $!");
        }
        elsif ( !-d $to ) {
            return ("Existing $to is in the way");
        }

        my $d;
        return ("Failed to copy $from: $!") unless opendir( $d, $from );
        my @e;
        foreach my $f ( grep { !/^\./ } readdir $d ) {
            $f =~ /(.*)/;
            $f = $1;    # untaint
            push( @e, copytree( "$from/$f", "$to/$f" ) );
        }
        closedir($d);
        return @e if scalar @e;
    }

    unless ( -e $to ) {
        require File::Copy;
        if ( !File::Copy::copy( $from, $to ) ) {
            return ("Failed to copy $from to $to: $!");
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
