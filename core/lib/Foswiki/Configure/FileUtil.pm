# See bottom of file for license and copyright information

package Foswiki::Configure::FileUtil;

=begin TML

---+ package Foswiki::Configure::FileUtil

Basic file utilities used by Configure and admin scripts

=cut

use strict;
use warnings;
use utf8;

use Assert;

use Encode;
use Foswiki::Configure::Reporter ();
use File::Spec;
use Unicode::Normalize;

=begin TML

---++ readdir utility

Returns NFC normalized unicode characters

=cut

sub _readdir {
    map { NFC( Encode::decode_utf8($_) ) } readdir( $_[0] );
}

=begin TML

---++ StaticMethod findFileOnTree($dir, $pattern, $reject) ->> $fullpath
Recursive search for a file matching the specified pattern, searching $dir
and all subdirectories of $dir,  Anything matching $reject is not
considered, to avoid searching the ,pfv subdirectories..

This is used by checkers and bootstrap to see if there are any ",v" rcs
files in the Store.

Example:

  findFileOnTree( $Foswiki::cfg{DataDir}, qr/,v$/, qr/,pfv$/ );

SMELL:  We could use File::Find as a CPAN solution, however in this case
really only need to find the first occurance, we have no need for the full
list,  just whether or not any exist.  File::Find returns the complete list
of matching files.

=cut

sub findFileOnTree {

    #my ( $dir, $match, $reject ) = @_;

    if ( opendir( my $dh, $_[0] ) ) {
        foreach ( grep !/^\./, readdir($dh) ) {
            next if $_ =~ $_[2];
            my $dentry = File::Spec->catdir( $_[0], $_ );
            return $dentry if $dentry =~ $_[1];
            if ( -d $dentry ) {
                my $hit = findFileOnTree( $dentry, $_[1], $_[2] );
                return $hit if ($hit);
            }
        }
        closedir $dh;
    }
    else {
        return
          "Search failed: Directory open of $_[0] failed. Check permissions.\n";
    }
    return 0;
}

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

    foreach my $incdir (@INC) {

        my ( $volume, $directories, $filename ) =
          File::Spec->splitpath("$incdir/$file");
        next unless ( -d $volume . $directories );
        opendir( my $df, $volume . $directories ) || next;
        my @files = grep { $_ eq $filename } _readdir($df);
        closedir($df);

        if ( scalar @files ) {
            return "$incdir/$file";
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

    my @NFCINC = map { NFC( decode_utf8($_) ) } @INC;
    my $places = \@NFCINC;
    my $dir;

    while ( scalar(@path) > 1 && @$places ) {
        my $pathel = shift(@path);
        eval("\$pathel = qr/^($pathel)\$/");    # () to untaint
        my @newplaces;

        foreach my $place (@$places) {
            if ( opendir( $dir, $place ) ) {

                #next if ($place =~ m/^\..*/);
                foreach my $subplace ( _readdir $dir ) {
                    next unless $subplace =~ $pathel;

                    #next if ($subplace =~ m/^\..*/);
                    push( @newplaces, $place . '/' . $1 );
                }
                closedir $dir;
            }
        }
        $places = \@newplaces;
    }

    my @list;
    my $leaf = pop(@path);
    eval("\$leaf = qr/$leaf\\.pm\$/");
    ASSERT( !$@, $@ ) if DEBUG;

    my %known;
    foreach my $place (@$places) {
        if ( opendir( $dir, $place ) ) {
            foreach my $file ( _readdir $dir ) {
                next unless $file =~ $leaf;
                next if ( $file =~ m/^\..*/ );
                next unless $file =~ m/^(.*)\.pm$/;
                my $module = "$place/$1";
                $module =~ s./.::.g;
                if ( $module =~ m/($pattern)$/ ) {
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

    use filetest 'access';

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

    unless ( defined $txt2 && $txt2 eq $txt1 ) {
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
   * n - Verify normalization of the directory location

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
        dirErrors   => 0,
        missingFile => 0,
        excessPerms => 0,
        messages    => []
    );

    return \%report
      if ( defined( $options{filter} )
        && $path =~ m/$options{filter}/
        && !-d $path );

    # Let's ignore Subversion and git directories
    return \%report if ( $path eq '_svn' );
    return \%report if ( $path eq '.svn' );
    return \%report if ( $path eq '.git' );

    $options{maxFileErrors}  = 10 unless defined $options{maxFileErrors};
    $options{maxDirErrors}   = 10 unless defined $options{maxDirErrors};
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

    if ( $perms =~ m/d/ && -d $path ) {
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
"   * $path - directory permission $omode differs from requested $operm - check directory for possible excess permissions"
                    );
                }
            }
            if ( ( $mode & $Foswiki::cfg{Store}{dirPermission} ) !=
                $Foswiki::cfg{Store}{dirPermission} )
            {
                if ( $report{fileErrors}++ < $options{maxFileErrors} ) {
                    push(
                        @{ $report{messages} },
"   * $path - directory permission $omode differs from requested $operm - check directory for possible insufficient permissions"
                    );
                }
            }
        }
    }

    if ( $perms =~ m/f/ && -f $path ) {
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
"   * $path - file permission $omode differs from requested $operm - check file for possible excess permissions."
                    );
                }
            }
            if ( ( $mode & $Foswiki::cfg{Store}{filePermission} ) !=
                $Foswiki::cfg{Store}{filePermission} )
            {
                if ( $report{fileErrors}++ < $options{maxFileErrors} ) {
                    push(
                        @{ $report{messages} },
"   * $path - file permission $omode differs from requested $operm - check file for possible insufficient permissions."
                    );
                }
            }
        }
    }

    if (   $perms =~ m/p/
        && $path =~ m/\Q$Foswiki::cfg{DataDir}\E\/(.+)$/
        && -d $path
        && $path !~ m#,pfv# )
    {
        unless ( -e "$path/$Foswiki::cfg{WebPrefsTopicName}.txt" ) {
            unless ( $report{missingFile}++ > $options{maxMissingFile} ) {
                push(
                    @{ $report{messages} },
                    "   * $path missing $Foswiki::cfg{WebPrefsTopicName} topic."
                );
            }
        }
    }

    if ( $rwxString && $report{fileErrors}++ < $options{maxFileErrors} ) {
        push( @{ $report{messages} }, "=$path= $rwxString" );
    }

    return \%report unless -d $path;

    # Stop at this directory, if it doesn't have -x - readdir permission
    if ( -d $path && !-x $path ) {
        unshift( @{ $report{messages} }, "   * $path missing -x permission" );
        $report{dirErrors}++;
        return \%report;
    }

    # The NFC check requires readdir permission.
    if (   $perms =~ m/n/
        && !$Foswiki::cfg{NFCNormalizeFilenames}
        && -d $path
        && ( substr( $path, -4 ) ne ',pfv' ) )
    {
        my $nfcok = Foswiki::Configure::FileUtil::canNfcFilenames($path);
        if ( !$nfcok && $report{dirErrors}++ < $options{maxDirErrors} ) {
            push(
                @{ $report{messages} },
"   * =$path= NFD File System detected, Normalization should be enabled"
            );
        }
    }

    opendir( my $Dfh, $path )
      or return "Directory $path is not readable.";

    foreach my $e ( grep { !/^\.\.?$/ } _readdir($Dfh) ) {
        my $p = $path . '/' . $e;
        my $subreport = checkTreePerms( $p, $perms, %options );
        while ( my ( $k, $v ) = each %report ) {
            if ( ref($v) eq 'ARRAY' ) {
                push( @{ $report{$k} }, @{ $subreport->{$k} } );
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

    use filetest 'access';

    if ( $perms =~ m/r/ && !-r $path ) {
        $message .= ' not readable';
    }

    if ( $perms =~ m/w/ && !-d $path && !-w $path ) {
        $message .= ' not writable';
    }

    if ( $perms =~ m/x/ && !-x $path ) {
        $message .= ' not executable';
    }

    return $message;
}

=begin TML

---++ StaticMethod checkGNUProgram($prog, $reporter, $reqVersion )

Check for the availability of a GNU program.

If $reqVersion is provided, (Simple decimmal number) then a warning is
issued if older version is detected.

Since Windows (without Cygwin) makes it hard to capture stderr
('2>&1' works only on Win2000 or higher), and Windows will usually have
GNU tools in any case (installed for Foswiki since there's no built-in
diff, grep, patch, etc), we only check for these tools on Unix/Linux
and Cygwin.

Errors are reported by calling ERROR and/or WARN on $reporter
=cut

sub checkGNUProgram {
    my ( $prog, $reporter, $reqVersion ) = @_;

    # SMELL: assumes no spaces in program pathnames
    $prog =~ s/^\s*(\S+)\s.*$/$1/;    # Extract out program name and untaint
    $prog =~ m/^(.*)$/;
    $prog = $1;

    my $err;
    my $msg;
    my $version;
    my $fullversion;

    if (   $Foswiki::cfg{OS} eq 'UNIX'
        || $Foswiki::cfg{OS} eq 'WINDOWS'
        && $Foswiki::cfg{DetailedOS} eq 'cygwin' )
    {

        foreach my $cmd ( "$prog --version", "$prog -V" ) {

            # Don't let failures get trapped.
            {
                local $SIG{'__WARN__'};
                local $SIG{'__DIE__'};
                $msg = `$cmd 2>&1` || "";
            }

            #print STDERR "$cmd returned $?, " . ( $msg || 'undef' ) . "\n";

            if ( $? < 0 ) {
                $err =
"Command $prog failed, may not be installed, or found on path. ";
                last;
            }
            elsif ( $? > 0 ) {

                # Probably a syntax error eg.  --version not supported
                next;
            }
            elsif ( defined $msg
                && $msg =~ m/^.*?([0-9]+\.[0-9]+)(\.[0-9]+)?$/m )
            {
                $version = $1 if defined($1);
                $fullversion = $1 . ( $2 || '' ) if defined($1);
                last unless DEBUG;
            }

        }

        if ($err) {
            $reporter->ERROR($err);
        }
        else {

            $reporter->NOTE("$prog version $fullversion detected.")
              if defined $fullversion;

            if ( $msg !~ /\bGNU\b/ ) {

                # Program found on path, complain if no GNU in version output
                $reporter->WARN(
                    "'$prog' program was found on the PATH ",
                    "but is not GNU $prog - this may cause ",
                    "problems. $msg"
                );
            }
        }

        if ( defined $reqVersion ) {
            if ( !defined $version ) {
                $reporter->WARN(
"Unable to determine version of $prog, Version $reqVersion required."
                );
            }
            elsif ( $version < $reqVersion ) {

                $reporter->WARN( $prog
                      . ' is too old, upgrade to version '
                      . $reqVersion
                      . ' or higher. ' );
            }
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
            $f =~ m/(.*)/;
            $f = $1;    # untaint
            push( @e, copytree( "$from/$f", "$to/$f" ) );
        }
        closedir($d);
        return @e if scalar(@e);
    }

    unless ( -e $to ) {
        require File::Copy;
        if ( !File::Copy::copy( $from, $to ) ) {
            return ("Failed to copy $from to $to: $!");
        }
    }
}

=begin TML

---++ StaticMethod listDir($dir, [$dflag], [$path] )
Recursively list the files in directory $dir. Optional $dflag can be set to 1
to cause the list to exclude the directory names from the list. 

If $path is used internally for the recursive directory list. It is
appended to the Directory.  The list of files in @names is relative to the
$dir directory.   Subroutine called recursively for each subdirectory
encountered.

=cut

# Recursively list a directory
sub listDir {
    my ( $dir, $dflag, $path ) = @_;
    $path  ||= '';
    $dflag ||= '';
    $dir .= '/' unless $dir =~ m/\/$/;
    my $d;
    my @names = ();
    if ( opendir( $d, "$dir$path" ) ) {
        foreach my $f ( grep { !/^\.*$/ } readdir $d ) {

            # Someone might upload a package that contains
            # a filename which, when passed to File::Copy, does something
            # evil. Check and untaint the filenames here.
            # SMELL: potential problem with unicode chars in file names? (yes)
            if ( $f =~ m/^([-\w.,]+)$/ ) {
                $f = $1;
                if ( -d "$dir$path/$f" ) {
                    push( @names, "$path$f/" ) unless ($dflag);
                    push( @names, listDir( $dir, $dflag, "$path$f/" ) );
                }
                else {
                    push( @names, "$path$f" );
                }
            }
            else {
                print
"WARNING: skipping possibly unsafe file (not able to show it for the same reason :( )<br />\n";
            }
        }
        closedir($d);
    }
    return @names;
}

sub _getTarFamily {
    my ($tarCmd) = @_;
    `$tarCmd --version` =~ /(bsd|gnu)/i;
    return lc $1;
}

sub _getTar {
    my $tarCmd    = 'tar';
    my $tarFamily = _getTarFamily($tarCmd);

    if ( $tarFamily eq 'bsd' ) {

        # Trying to find gnutar in order to keep as much compatibility with
        # linux as we can.
        my $gnutar;
      TAR_UTIL:
        foreach my $utilname (qw(gtar gnutar)) {
            $gnutar = `which $utilname`;
            if ( $? == 0 && $gnutar ) {
                chomp $gnutar;
                if ( _getTarFamily($gnutar) eq 'gnu' ) {
                    $tarCmd    = $gnutar;
                    $tarFamily = 'gnu';
                    last TAR_UTIL;
                }

            }
        }

    }

    return ( $tarCmd, $tarFamily );
}

=begin TML

---++ StaticMethod createArchive($name, $dir, $delete )
Create an archive of the passed directory. 
   * $name is the directory to be backed up _and_ the filename of the archive to be created.  $name will be given a suffix of the backup type - depends on what type of backup tools are installed.
   * $dir is the root directory of the backups - typically the working/configure/backup directory
   * $delete - set if the directory being backed up should be deleted after archive is created.

=cut

sub createArchive {
    my ( $name, $dir, $delete, $test ) = @_;
    eval('use File::Path qw(rmtree)');
    ASSERT( !$@, $@ );

    my $file    = undef;
    my $results = '';
    my $warn    = '';

    my $here = Cwd::getcwd();
    $here =~ m/(.*)/;
    $here = $1;    # untaint current dir name

    return ( undef, "Directory $dir/$name does not exist \n" )
      unless ( -e "$dir/$name" && -d "$dir/$name" );

    chdir("$dir/$name");

    if ( !defined $test || ( defined $test && $test eq 'tar' ) ) {
        my ( $tarCmd, $tarFamily ) = _getTar();
        my $redirect = '';
        if ( $tarFamily eq 'bsd' ) {

            # BSD tar sends listing to STDERR while create an archive.
            $redirect = '2>&1';
        }

        $results = `$tarCmd -czvf "../$name.tgz" . $redirect`;

        if ( $? != 0 ) {
            $results = '';
        }
        else {
            $file = "$dir/$name.tgz";
        }
    }

    unless ($results) {
        $warn .= "tar command failed $!, trying zip \n";

        if ( !defined $test || ( defined $test && $test eq 'zip' ) ) {
            $results .= `zip -r "../$name.zip" .`;

            if ( $results && !$? ) {
                $file = "$dir/$name.zip";
            }
        }

        unless ($results) {
            $warn .= "zip failed $!, trying perl routines \n";

            if ( !defined $test || ( defined $test && $test eq 'Ptar' ) ) {
                my @flist = listDir( '.', 1 );
                $results = _tar( "../$name.tgz", \@flist );

                if ($results) {
                    $file = "$dir/$name.tgz";
                }
            }

            unless ($results) {
                $warn .= "Perl Archive::Tar failed - trying zip \n";

                if ( !defined $test || ( defined $test && $test eq 'Pzip' ) ) {
                    my @flist = listDir( '.', 1 );
                    $results = _zip( "../$name.zip", \@flist );

                    if ($results) {
                        $file = "$dir/$name.zip";
                    }
                    else {
                        $warn .=
"Perl Archive::Zip failed - Backup directory remains \n";
                    }
                }
            }
        }
    }

    chdir($here);

    return ( undef, $warn ) unless ($results);

    rmtree("$dir/$name") if ($delete);
    return ( $file, $results );

}

sub _zip {
    my $archive = shift;
    my $files   = shift;
    my $err;

    eval('use Archive::Zip ( )');
    unless ($@) {
        my $zip = Archive::Zip->new();
        unless ($zip) {
            return 0;
        }

        # Note:  Archive::Zip addTree fails with taint errors.
        # Workaround was to add each file individually
        foreach my $f (@$files) {
            $zip->addFile($f);
        }
        $err = $zip->writeToFileNamed("$archive");
        return join( "\n", $zip->memberNames() ) unless ($err);
    }

    return 0;
}

sub _tar {
    my $archive = shift;
    my $files   = shift;

    eval('use Archive::Tar ()');
    unless ($@) {
        my $tgz = Archive::Tar->new();
        return 0 unless ($tgz);
        $tgz->add_files(@$files);
        $tgz->write( "$archive", 7 );
        return join( "\n", $tgz->list_files() );
    }
    return 0;
}

=begin TML

---++ StaticMethod unpackArchive($archive [,$dir] ) -> ( $dir, $err )
Unpack an archive. The unpacking method is determined from the file
extension e.g. .zip, .tgz. .tar, etc. If $dir is not given, unpack
to a temporary directory, the name of which is returned.

Errors are reported by returnng a non-null $err

=cut

sub unpackArchive {
    my ( $name, $dir ) = @_;

    $dir ||= File::Temp::tempdir( CLEANUP => 1 );
    my $here = Cwd::getcwd();
    $here =~ m/(.*)/;
    $here = $1;    # untaint current dir name
    chdir($dir);

    my $error;
    if ( $name =~ m/\.zip$/i ) {
        $error = _unzip($name);
        $error = "Failed to unpack archive $name: $error" if $error;
    }
    else {
        if ( $name =~ m/(\.tar\.gz|\.tgz|\.tar)$/i ) {
            $error = _untar($name);
            $error = "Failed to unpack archive $name: $error" if $error;
        }
    }
    chdir($here);

    return ( $dir, $error );
}

sub _unzip {
    my $archive = shift;

    my $testzip = ( `unzip -hh 2>&1` || "" );
    my $noUnzip = ( $? != 0 );

    if ($noUnzip) {
        eval('require Archive::Zip');
        unless ($@) {
            my $zip;
            eval { $zip = Archive::Zip->new($archive); };
            return Foswiki::Configure::Reporter::stripStacktrace($@) if $@;
            return "Failed to open zip file $archive" unless $zip;

            my @members = $zip->members();
            foreach my $member (@members) {
                my $file = $member->fileName();
                $file =~ m/^(.*)$/;
                $file = $1;    #yes, we must untaint
                my $target = $file;
                my $dest   = Cwd::getcwd();
                ($dest) = $dest =~ m/^(.*)$/;

            #SMELL:  Archive::Zip->extractMember( $file)  would be better to use
            # but it has taint issues on Perl 5.12.
                my $contents = $zip->contents($file);
                if ($contents) {
                    my ( $vol, $dir, $fn ) = File::Spec->splitpath($file);
                    File::Path::mkpath("$dest/$dir");
                    open( my $fh, '>', "$dest/$file" )
                      || die "Unable to open $dest/$file \n $! \n\n ";
                    binmode $fh;
                    print $fh $contents;
                    close($fh);
                }
            }
        }
    }
    else {
        `unzip -n $archive`;
        return "$? - $!" if ($?);
    }
    return undef;
}

sub _untar {
    my $archive = shift;

    my $compressed = ( $archive =~ m/z$/i ) ? 'z' : '';

    my $testtar = ( `tar --version 2>&1` || "" );
    my $noTar = ( $? != 0 );

    if ($noTar) {

        eval('require Archive::Tar');
        unless ($@) {
            my $tar;
            eval { $tar = Archive::Tar->new( $archive, $compressed ); };
            return Foswiki::Configure::Reporter::stripStacktrace($@) if $@;
            return "Could not open tar file $archive" unless $tar;

            my @members = $tar->list_files();
            foreach my $file (@members) {

                #SMELL: Some tarfiles return a trigger for long filenames
                next if ( $file eq '././@LongLink' );
                my $err = $tar->extract($file);
                unless ($err) {
                    return 'Failed to extract ', $file, ' from tar file ',
                      $tar, ". Archive may be corrupt.\n";
                }
            }
        }
    }
    else {
        `tar xvf$compressed $archive`;
        return "$? - $!" if ($?);
    }
    return undef;
}

=begin TML

---++ StaticMethod getPerlLocation( )
This routine will read in the first line of the bin/configure 
script and recover the location of the perl interpreter. 

Optional parameter is file used to retrieve the shebang.  If not 
specified, defaults to the configure script

=cut

sub getPerlLocation {

    my $file = shift
      || "$Foswiki::cfg{ScriptDir}/configure$Foswiki::cfg{ScriptSuffix}";

    local $/ = "\n";
    open( my $fh, '<', "$file" )
      || return "";
    my $Shebang = <$fh>;
    chomp $Shebang;
    ($Shebang) = $Shebang =~ m/^#\!\s*(.*?perl.*?)\s?(?:\s-.*?)?$/;
    $Shebang =~ s/\s+$//;
    close($fh);
    return $Shebang;

}

=begin TML

---++ StaticMethod rewriteShebang($file, $newShebang, $taint )

Rewrite the #! (shebang) line of the target script
with the specified script name. Clear any taint flag
by default, or set it if $taint is true.

This is used in 2 places:
 - The Package installer - used when installing extensions
 - In tools/rewriteshebang.pl

=cut

sub rewriteShebang {
    my $file       = shift;
    my $newShebang = shift;
    my $taint      = shift;

    return 'Not a file' unless ( -f $file );
    return 'Missing Shebang' unless $newShebang;

    local $/ = undef;
    open( my $fh, '<', $file ) || return "Rewrite shebang failed:  $!";
    my $contents = <$fh>;
    close $fh;

    # Pull out the first line,  parse it into the script (match)  and arguments
    my $firstline = substr( $contents, 0, index( $contents, "\n" ) );
    my ( $match, $args ) =
      $firstline =~ m/^#\!\s*(.*?perl[^\s]*)(\s?-w?T?w?)?.*?$/ms;
    $match ||= '';
    $args  ||= '';
    my $newargs = $args;

    return "Not a perl script" unless ($match);

    if ( $newShebang =~ m/env perl/ ) {
        $newargs = '';    # No arguments possible when using env perl
    }
    elsif ( defined $taint ) {
        if ($args) {
            if ($taint) {
                $newargs .= 'T' unless ( $args =~ m/T/ );
            }
            else {
                $newargs =~ s/T//;
                $newargs = '' if ( $newargs eq ' -' );
            }
        }
    }

    # Find position of existing args, and replace with new arguments
    my $argsIdx = index( $contents, $args );
    if ($argsIdx) {
        substr( $contents, $argsIdx, length($args) ) = "$newargs";
    }
    elsif ( defined $taint ) {
        $newShebang .= ' -T' if ($taint);
    }

    # Note: space inserted after #! - needed on some flavors of Unix
    my $perlIdx = index( $contents, $match );
    substr( $contents, $perlIdx, length($match) ) =
      ( substr( $contents, $perlIdx - 1, 1 ) eq ' ' ? '' : ' ' )
      . "$newShebang";

    return "No change required"
      if ( $match eq $newShebang
        && $args eq $newargs
        && substr( $contents, $perlIdx - 1, 1 ) eq ' ' );

    my $mode = ( stat($file) )[2];
    $file =~ m/(.*)/;
    $file = $1;
    chmod( oct(600), "$file" );
    open( $fh, '>', $file ) || return "Rewrite shebang failed:  $!";
    print $fh $contents;
    close $fh;
    $mode =~ m/(.*)/;
    $mode = $1;
    chmod( $mode, "$file" );

    return '';
}

=begin TML

---++ StaticMethod canNfcFilenames($testdir)
Determine if the file system is NFC or NFD.
Write a UTF8 filename to the data directory, and then read the directory.
If the filename is returned in NFD format, then the NFCNormalizeFilename flag is enabled.

returns:
   * 1 if NFC filenames are accepted by the filesystem
   * 0 if the NFC is converted to NFD
   * undef in any other case (errors)

=cut

sub canNfcFilenames {
    my $testdir = shift;

    ASSERT( $testdir, "missing argument to canNfcFilenames" );

#die as BUG if the testdir contains non-ascii characters and it isn't unicode string
    ASSERT( !( $testdir =~ /\P{ASCII}/ && !utf8::is_utf8($testdir) ),
        "CORE bug, got a [$testdir] as bytes" );

    my $ext      = '.CfgNfcTmpFile';
    my $testname = '_ÁčňÖüß' . $ext;
    my $fullpath =
      NFC( File::Spec->catfile( $testdir, $testname ) );   #ensure full NFC path
    my $fsnorm;

    unlink $fullpath;
    if ( open my $fd, '>', $fullpath ) {
        close $fd;
        opendir my $dh, $testdir or return;                #or die?
        my @list = grep { /$ext/ } map { decode_utf8($_) } readdir $dh;
        closedir $dh;
        return unless ( scalar @list == 1 );
        $fsnorm =
            ( $list[0] eq $testname )      ? 1
          : ( $list[0] eq NFD($testname) ) ? 0
          :                                  undef;
        unlink $fullpath;
    }
    return $fsnorm;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
