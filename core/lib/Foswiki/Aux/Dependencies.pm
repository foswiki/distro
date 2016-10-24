# See bottom of file for license and copyright information

package Foswiki::Aux::Dependencies::MuteOut;
use v5.14;
use strict;
use warnings;
use Config;

sub new {
    my $class  = shift;
    my %params = @_;

    $class = ref($class) || $class;

    my ( $oldOut, $oldErr, $rc );

    my $outFile = $params{outFile} // File::Spec->devnull;
    my $errFile = $params{errFile} // File::Spec->devnull;

    unless ( open $oldOut, ">&", STDOUT ) {
        Foswiki::Aux::Dependencies::_msg( "Cannot dup STDOUT: " . $! );
        return undef;
    }
    unless ( open $oldErr, ">&", STDERR ) {
        Foswiki::Aux::Dependencies::_msg( "Cannot dup STDERR: " . $! );
        return undef;
    }
    unless ( open STDOUT, ">", $outFile ) {
        Foswiki::Aux::Dependencies::_msg( "Failed to redirect STDOUT: " . $! );
    }
    unless ( open STDERR, ">", $errFile ) {
        Foswiki::Aux::Dependencies::_msg( "Failed to redirect STDERR: " . $! );
    }

    my $obj = bless {
        oldOut  => $oldOut,
        oldErr  => $oldErr,
        outFile => $outFile,
        errFile => $errFile,
    }, $class;

    return $obj;
}

sub exec {
    my $this = shift;
    my ($sub) = shift;

    my @rc;
    my $wantarray = wantarray;
    if ($wantarray) {
        @rc = $sub->(@_);
    }
    elsif ( defined $wantarray ) {
        $rc[0] = $sub->(@_);
    }
    else {
        $sub->(@_);
    }

    return $wantarray ? @rc : $rc[0];
}

sub DESTROY {
    my $this = shift;

    unless ( open STDOUT, ">&", $this->{oldOut} ) {
        Foswiki::Aux::Dependencies::_msg( "Failed to restore STDOUT: " . $! );
    }
    unless ( open STDERR, ">&", $this->{oldErr} ) {
        Foswiki::Aux::Dependencies::_msg( "Failed to restore STDERR: " . $! );
    }
}

package Foswiki::Aux::Dependencies;
use v5.14;
use strict;
use warnings;
use Config;

=begin TML
---+ package Foswiki::Aux::Dependencies;

Fetch and install dependencies.

---++ SYNOPSIS

<verbatim>
use Foswiki::Aux::Dependencies rootDir => $ENV{FOSWIKI_HOME};

if (Foswiki::Aux::Dependencies::isFirstRun) {
    Foswiki::Aux::Dependencies::checkDependencies(
        doUpgrade      => 0,
        withExtensions => 1,
        inlineExec     => 1,
    );
}
</verbatim>

#ModParams
---++ Module import parameters.

| *Key* | *Default* | *Description* |
| =rootDir= | _undef_ | Foswiki root dir as defined in FOSWIKI_HOME shell environment variable |
| =firstRunCheck = | _FALSE_ | Boolean, check if it's the first run of the application on this server; in other words, check if there is no .checksum file in =$FOSWIKI_HOME/perl5=. |

=cut

use File::Spec ();
use File::Path qw(make_path);

our ( $rootDir, @messages, $OK );

sub import {
    my $target = shift;
    my (%profile) = @_;

    $rootDir = $profile{rootDir} // $ENV{FOSWIKI_HOME};

    if ( !$rootDir ) {

        # Try to guess root dir location depending on where this module is
        # located by presuming that $FOSWIKI_HOME/lib/<this module path> is the
        # location.
        my @modNames = split /::/, __PACKAGE__;
        my $modFile =
          File::Spec->rel2abs( $INC{ File::Spec->catfile(@modNames) . ".pm" } );
        my @path = File::Spec->splitdir($modFile);
        my $vol  = shift @path;

        # @path would containt all path elements including module file name.
        # Cut off the trailing scalar(@modNames) elements to remove this module
        # path and name elements and then one more to remove 'lib'. What remains
        # we expect to be the root dir.
        my $rootPath =
          File::Spec->catdir( File::Spec->rootdir,
            @path[ 0 .. $#path - @modNames - 1 ] );
        $rootDir = File::Spec->catpath( $vol, $rootPath, '' );
    }

    $OK = 1;

    if ( $profile{firstRunCheck} ) {
        if ( Foswiki::Aux::Dependencies::isFirstRun() ) {
            my $noPerlBin = 1
              ; # Must be dynamically checked later for, say, mod_perl environment.
            $OK = Foswiki::Aux::Dependencies::checkDependencies(
                rootDir        => $rootDir,
                doUpgrade      => 0,
                withExtensions => 0,
                inlineExec     => $noPerlBin,
            );
        }
    }

    if ($OK) {
        my %inc = map { $_ => 1 } @INC;
        _presets( \%profile );
        my $localLib = File::Spec->catdir( $profile{libDir}, "lib", "perl5" );

        # Isert lib path to the beginning prefer locally installed modules over
        # system ones.
        unshift @INC, $localLib unless $inc{$localLib};
    }
    else {
        say STDERR
          join( "\n", "---MESSAGES BEGIN---", @messages, "---MESSAGES END---" );
    }

}

sub _msg {
    push @messages, @_;
}

sub _say {
    my $profile = shift;
    if ( $profile->{verbose} ) {
        return say STDERR @_;
    }
    return 0;
}

=begin TML

---++ StaticMethod checkDependencies(%params) -> bool

=%params= keys:

| *Key* | *Default* | *Description* |
| =rootDir= | $Foswiki::Aux::Dependencies::rootDir | See [[#ModParams][module import parameters]] |
| =depFile= | _undef_ | Full path to DEPENDENCIES file to be checked. |
| =withExtensions= | _FALSE_ | Scan for extensions DEPENDECIES files too |
| =doUpgrade= | _FALSE_ | Recheck all dependencies for possible upgrades. |
| =inlineExec= | _FALSE_ | Don't use system() call for running any Perl code but execute it as inline. May have unexpected side effects and should be avoided whenever possible! |
| =depFileList= | _empty_ | Manually define DEPENDENCIES files to be processed. If =withExtensions= is true then added to this list. |
| =retries= | 5 | Number of times to retry a failed installation. Reasonable if cause of failure is a network issue. |
| =retryPause= | 1 | Number of seconds to wait between retries |

=cut

sub checkDependencies {
    my %profile = @_;

    return 0 unless _presets( \%profile );

    $ENV{PERL_CPANM_HOME} = $profile{cpanmHomeDir};

    # Read dependencies before validating DEPENDENCIES checksum
    return 0 unless readDependencies( \%profile );

    foreach my $depFile ( keys %{ $profile{depFiles} } ) {
        my $sumValid = validChecksum( \%profile, $depFile );

        # If checksums cannot be validated we cannot proceed.
        return 0 unless defined $sumValid;

        unless ($sumValid) {
            push @{ $profile{dependencies} },
              @{ $profile{depFiles}{$depFile}{dependencies} };
        }
    }

    # Dependencies must be rechecked.
    return 0 unless installDependencies( \%profile );
    writeChecksums( \%profile );
    return 1;
}

sub isFirstRun {
    my $profile;

    if ( @_ == 1 ) {
        $profile = shift;
    }
    else {
        $profile = {@_};
        return 0 unless _presets($profile);
    }

    return !( -f $profile->{checksumFile} );
}

sub _presets {
    my $profile = shift;

    $profile->{rootDir}        //= $rootDir;
    $profile->{doUpgrade}      //= 0;
    $profile->{withExtensions} //= 0;
    $profile->{retries}        //= 5;
    $profile->{retryPause}     //= 1;

    unless ( defined $profile->{rootDir} ) {
        _msg("No directory to look for DEPENDENCIES is defined.");
        return 0;
    }

    @{$profile}{qw(libDir toolsDir)} = (
        File::Spec->catdir( $profile->{rootDir}, "perl5" ),
        File::Spec->catdir( $profile->{rootDir}, "tools" ),
    );

    $profile->{cpanmBin} = File::Spec->catfile( $profile->{toolsDir}, "cpanm" );
    $profile->{cpanmHomeDir} =
      File::Spec->catdir( $profile->{libDir}, ".cpanm" );
    $profile->{contribDir} //=
      File::Spec->catdir( $profile->{rootDir}, "lib", "Foswiki", "Contrib",
        "core" );

    $profile->{checksumFile} =
      File::Spec->catfile( $profile->{libDir}, ".checksum" );

    my $mainDepFile = $profile->{depFile}
      || File::Spec->catfile( $profile->{contribDir}, "DEPENDENCIES" );
    $profile->{depFiles}{$mainDepFile} = {};

    return 1;
}

sub _decodeFileName {
    my ($name) = @_;

    $name =~ s/\\(.)/$1/g;
    return $name;
}

sub _encodeFileName {
    my ($name) = @_;

    $name =~ s/([\\:])/\\$1/g;
    return $name;
}

sub _readOldSums {
    my $profile = shift;

    my $checkSums = _slurpFile( $profile->{checksumFile} );
    return 0 unless $checkSums;

    foreach my $line ( split /\n/s, $checkSums ) {
        chomp $line;
        my ( $file, $sum ) = split /(?<!\\):\s*/, $line;
        $file = _decodeFileName($file);
        $profile->{checkSums}{$file} = $sum;
    }

    return 1;
}

sub _fileChkSum {
    my $profile = shift;
    my ($file) = @_;

    my $sha1 = Digest::SHA->new;

    my ( $fh, $chkSum );

    if ( open $fh, "<", $file ) {
        local $/;
        $chkSum = Digest::SHA::sha1_hex(<$fh>);
        close $fh;
    }
    else {
        _msg( "Cannot open $file: " . $! );
        return undef;
    }

    $profile->{newCheckSums}{$file} = $chkSum;

    return $chkSum;
}

sub validChecksum {
    my ( $profile, $depFile ) = @_;

    my $digestModule = 'Digest::SHA';
    my $digestVersion = $profile->{modules}{$digestModule} // '>0';
    unless ( defined _verifyModule( $profile, $digestModule, $digestVersion ) )
    {
        _msg(
"!!! Module $digestModule is required but not found and cannot be installed."
        );
        return undef;
    }

    my $rc = eval "require Digest::SHA";

    if ( !$rc || $@ ) {
        _msg($@);
        return 0;
    }

    my $newSum = _fileChkSum( $profile, $depFile );

    return 0 unless defined $newSum;

    return 0 if isFirstRun($profile);

    unless ( -d $profile->{libDir} ) {
        _msg("Directory not found: $profile->{libDir}");
        return 0;
    }
    unless ( -f $profile->{checksumFile} ) {
        _msg("File doesn't exists: $profile->{checksumFile}");
        return 0;
    }
    unless ( -r $profile->{checksumFile} ) {
        _msg("File not readable: $profile->{checksumFile}");
        return 0;
    }

    return 0 unless _readOldSums($profile);

    return $newSum eq $profile->{checkSums}{$depFile};
}

sub _scanDirs {
    my $profile = shift;
    my ( $dir, $params ) = @_;

    $params->{inExtDir} ||= $dir =~
      /(?:\Q$profile->{_pluginsSubDir}\E|\Q$profile->{_contribSubDir}\E)/;

    my @found;

    my $dh;
    unless ( opendir $dh, $dir ) {
        _msg( "Cannot open dir '$dir': " . $! );
        return ();
    }

    while ( my $entry = readdir($dh) ) {
        next if $entry eq File::Spec->updir or $entry eq File::Spec->curdir;

        my $fullDir = File::Spec->catdir( $dir, $entry );
        if ( -d $fullDir ) {
            push @found, _scanDirs( $profile, $fullDir, $params );
        }
        elsif ( $params->{inExtDir} && $entry eq 'DEPENDENCIES' ) {
            push @found, File::Spec->catfile( $dir, $entry );
        }
    }

    closedir $dh;
    return @found;
}

sub _findExtDependecies {
    my $profile = shift;

    my $rootDir = $profile->{rootDir};
    $profile->{_pluginsSubDir} = File::Spec->catdir( 'Foswiki', 'Plugins' );
    $profile->{_contribSubDir} = File::Spec->catdir( 'Foswiki', 'Contrib' );

    my @depFileList = _scanDirs( $profile, $rootDir );
    $profile->{depFiles}{$_} = { fromExt => 1, } foreach @depFileList;
}

sub readDependencies {
    my $profile = shift;

    my $dep_fh;

    if ( $profile->{depFileList} ) {
        $profile->{depFiles}{$_} = {} foreach @{ $profile->{depFileList} };
    }

    if ( $profile->{withExtensions} ) {
        _findExtDependecies($profile);
    }

    foreach my $depFile ( keys %{ $profile->{depFiles} } ) {
        unless ( open $dep_fh, "<", $depFile ) {
            _msg( "Failed to open $depFile:" . $! );
            return 0;
        }

        $profile->{depFiles}{$depFile}{dependencies} = [];
        my $fromExt = $profile->{depFiles}{$depFile}{fromExt} // 0;
        while ( my $line = <$dep_fh> ) {
            chomp $line;
            my %depEntry;

            my @splitLine = split /,/, $line, 4;
            next if @splitLine < 4;  # Ignore some special format lines for now.
            @depEntry{qw(module version type description source fromExt)} =
              ( @splitLine, $depFile, $fromExt );

            next unless lc( $depEntry{type} ) eq 'cpan';

            $profile->{modules}{ $depEntry{module} } = \%depEntry;
            push @{ $profile->{depFiles}{$depFile}{dependencies} }, \%depEntry;
        }
        close $dep_fh;

    }

    return 1;
}

sub writeChecksums {
    my ($profile) = @_;

    foreach my $depFile ( keys %{ $profile->{newCheckSums} } ) {
        $profile->{checkSums}{$depFile} = $profile->{newCheckSums}{$depFile};
    }

    my $fh;
    unless ( open $fh, ">", $profile->{checksumFile} ) {
        _msg( "Cannot open '$profile->{checksumFile}' for write: " . $! );
        return 0;
    }

    foreach my $depFile ( keys %{ $profile->{checkSums} } ) {
        my $file = _encodeFileName($depFile);
        print $fh $file, ":", $profile->{checkSums}{$depFile}, "\n";
    }

    close $fh;

    return 1;
}

sub _signalName {
    my ($sigNum) = @_;
    my $sigName = ( split ' ', $Config{sig_name} )[$sigNum] // $sigNum;
    return $sigName;
}

sub _slurpFile {
    my ($file) = @_;

    my $fh;
    unless ( open $fh, "<", $file ) {
        _msg( "Cannot open '$file': " . $! );
        return undef;
    }

    local $/;
    my $data = <$fh>;
    _msg( "Read from '$file' failed: " . $! ) unless defined $data;
    close $fh;
    return $data;
}

sub _inlineCpanmExec {
    my $profile = shift;

    # Shell-like return.
    my $rc = 0;

    state $codeLoaded = 0;

    unless ($codeLoaded) {
        my $code = _slurpFile( $profile->{cpanmBin} );

        if ($code) {
            $code =~ s/^(.+)\h*#\h+END\h+OF\h+FATPACK\h+CODE.+$/$1/s;
            $code .= "\n1;";
            my $compiled = eval $code;
            if ( !$compiled ) {
                _msg( "Load of cpanm code failed: " . $@ );
                $rc = 1;
            }
            else {
                $codeLoaded = 1;
            }
        }
        else {
            $rc = 1;
        }
    }

    if ( $rc == 0 ) {
        require App::cpanminus::script;
        my $cpanmApp = App::cpanminus::script->new;
        $cpanmApp->parse_options(@_);
        $rc = $cpanmApp->doit;
    }

    # Simulate system()
    return $rc << 8;
}

sub _cpanmExec {
    my $profile = shift;

    # For no good reason an attempt to install mod_perl on macOS causes either
    # cpanm or the mod_perl installation scripts to raise TERM signal to the
    # parent – i.e. to us. We shall ignore it.
    my $cmdLine = "$^X $profile->{cpanmBin} " . join( " ", @_ );
    local $SIG{TERM} = sub { say STDERR "Got $_[0] signal for `$cmdLine`"; };

    if ( $profile->{inlineExec} ) {
        return _inlineCpanmExec( $profile, @_ );
    }
    return system $^X, $profile->{cpanmBin}, @_;
}

sub _perlExec {
    return system $^X, @_;
}

sub _muteExec {
    my $profile = shift;
    my $sub     = shift;

    my $rc;
    my $outFile = File::Spec->catfile( $profile->{libDir}, ".stdout" );
    my $errFile = File::Spec->catfile( $profile->{libDir}, ".stderr" );

    {
        my $muter = Foswiki::Aux::Dependencies::MuteOut->new(
            outFile => $outFile,
            errFile => $errFile,
        );

        $rc = $muter->exec( $sub, @_ );
    }

    my $out = _slurpFile($outFile);
    my $err = _slurpFile($errFile);

    unlink $outFile;
    unlink $errFile;

    return wantarray ? ( $rc, $out, $err ) : $rc;
}

sub _testModule {
    my $profile = shift;
    my ( $module, $modParams ) = @_;

    if ( $profile->{inlineExec} ) {
        eval "use $module $modParams;";
        return !$@;
    }
    else {
      # Use libDir because it's the only location we know for sure where nothing
      # would be broken.
        my $scriptFile = File::Spec->catfile( $profile->{libDir}, ".test.pl" );

        my $fh;

        if ( open $fh, ">", $scriptFile ) {
            print $fh <<SCRIPT;
use $module $modParams;
print "OK";
exit 0;
SCRIPT
            close $fh;
            my $rc = _muteExec( $profile, \&_perlExec, $scriptFile );
            my $success;
            if ( $rc != 0 ) {
                if ( $rc & 0x7f ) {
                    _msg( "'perl $scriptFile' died by signal "
                          . _signalName( $rc & 0x7f ) );
                    undef $success;
                }
                else {
                    $success = 0;
                }
            }
            else {
                $success = 1;
            }
            unlink $scriptFile;
            return $success;
        }
    }

    # Cannot create test script file.
    return undef;
}

sub _verifyModule {
    my ( $profile, $module, $version, @modParams ) = @_;

    my $modParams = @modParams ? join( " ", @modParams ) : '()';

    my $moduleExists = _testModule( $profile, $module, $modParams );

    # If test for module existance failed then verify fail too.
    return 0 unless defined $moduleExists;

    if ( !$moduleExists || $profile->{doUpgrade} ) {
        _say( $profile, "Processing module $module" );
        my $verSuffix = '';
        $version =~ s/^\s*(.+)\s*$/$1/;
        if ($version) {
            if ( $version =~ /[><]/ ) {
                $verSuffix = "~$version";
            }
            else {
                # Remove = version prefix.
                $version =~ s/^=//;
                $verSuffix = '@' . $version;
            }
        }
        my @cpanmArgs = ( qw(--pureperl -q --local-lib), $profile->{libDir} );
        push @cpanmArgs, "$module$verSuffix";
        my ( $rc, $stdout, $stderr ) =
          _muteExec( $profile, \&_cpanmExec, $profile, @cpanmArgs );
        my $exitCode = $rc >> 8;
        if ( $exitCode != 0 ) {
            if ( $rc == -1 ) {
                _msg( "Failed to execute `$profile->{cpanmBin}`: " . $! );
            }
            elsif ( my $sig = $rc & 0x7f ) {
                _msg( "$profile->{cpanmBin} died by signal "
                      . _signalName($sig) );
            }
            else {
                _msg(   $profile->{cpanmBin}
                      . " exited with code "
                      . $exitCode
                      . ";\n>>>STDOUT BEGIN<<<\n"
                      . $stdout
                      . ">>>STDOUT END<<<\n"
                      . ">>>STDERR BEGIN<<<\n"
                      . $stderr
                      . ">>>STDERR END<<<" );
            }
            return 0;
        }
    }
    return 1;
}

sub installDependencies {
    my $profile = shift;

    unless ( -d $profile->{libDir} ) {
        my $errStr;
        unless (
            make_path(
                $profile->{libDir}, { mode => 0700, error => \$errStr }
            )
          )
        {
            _msg(@$errStr);
            return 0;
        }
    }

    # Take special care of local::lib
    my $llibMod = 'local::lib';
    my $version = $profile->{modules}{$llibMod}{version} || '>=2.00000';
    return 0
      unless _verifyModule( $profile, $llibMod, $version,
        "'$profile->{libDir}'" );

    foreach my $depEntry ( @{ $profile->{dependencies} } ) {
        my $version = $depEntry->{version};
        $version ||= 0;
        my $optional = $depEntry->{fromExt}
          || $depEntry->{description} !~ /^required/i;

        # NOTE Only dependencies of the core or those defined by depFileList
        # profile key are considered really required. If a dependency was picked
        # from an extension then it could ignored if failed verification.
        my ( $succeed, $attempt ) = ( 0, 0 );

        while ( !$succeed && $attempt < $profile->{retries} ) {
            $attempt++;
            $succeed = _verifyModule( $profile, $depEntry->{module}, $version );
            if ( !$succeed ) {
                _msg(   "Verification of "
                      . ( $optional ? "" : "REQUIRED" )
                      . " module "
                      . $depEntry->{module}
                      . ", attempt #"
                      . $attempt
                      . " FAILED" );
                sleep $profile->{retryPause} if $profile->{retryPause} > 0;
            }
        }

        return 0 unless $succeed || $optional;
    }

    return 1;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
