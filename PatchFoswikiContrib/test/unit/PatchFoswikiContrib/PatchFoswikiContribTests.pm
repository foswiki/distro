package PatchFoswikiContribTests;

use strict;
use warnings;

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Error qw( :try );
use File::Temp();
use FindBin;
use File::Path qw(mkpath rmtree);
use Digest::MD5;

use Foswiki::Configure::Util      ();
use Foswiki::Configure::PatchFile ();
use File::Copy qw( copy );

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;
    $root =~ s|\\|/|g;

    $this->{rootdir} = $root;
    $this->{user}    = $Foswiki::cfg{AdminUserLogin};
    $this->createNewFoswikiSession( $this->{user} );
    $this->{test_web} = 'Testsystemweb1234';
    my $webObject = $this->populateNewWeb( $this->{test_web} );
    $webObject->finish();
    $this->{trash_web} = 'Testtrashweb1234';
    $webObject = $this->populateNewWeb( $this->{trash_web} );
    $webObject->finish();
    $this->{sandbox_web} = 'Testsandboxweb1234';
    $webObject = $this->populateNewWeb( $this->{sandbox_web} );
    $webObject->finish();
    $this->{sandbox_subweb} = 'Testsandboxweb1234/Subweb';
    $webObject = $this->populateNewWeb( $this->{sandbox_subweb} );
    $webObject->finish();
    $this->{tempdir} = $Foswiki::cfg{TempfileDir} . '/test_ConfigureTests';
    rmtree( $this->{tempdir} )
      if ( -e $this->{tempdir} );    # Cleanup any old tests
    mkpath( $this->{tempdir} );
    $this->{scriptdir}       = $this->{tempdir} . '/bin';
    $Foswiki::cfg{ScriptDir} = $this->{scriptdir};
    $this->{toolsdir}        = $this->{tempdir} . '/tools';
    $Foswiki::cfg{ToolsDir}  = $this->{toolsdir};
    $this->{logdir}          = $this->{tempdir} . '/logs';
    $Foswiki::cfg{Log}{Dir}  = $this->{logdir};

    $Foswiki::cfg{TrashWebName}   = $this->{trash_web};
    $Foswiki::cfg{SandboxWebName} = $this->{sandbox_web};

    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $this->{test_web} );
    $this->removeWebFixture( $this->{session}, $this->{trash_web} );
    $this->removeWebFixture( $this->{session}, $this->{sandbox_web} );
    rmtree( $this->{tempdir} );    # Cleanup any old tests
    $this->SUPER::tear_down();

    return;
}

sub removeWeb {
    my ( $this, $web ) = @_;
    $this->removeWebFixture( $this->{session}, $web );

    return;
}

sub test_PatchFile_parsePatch {
    my $this = shift;

    _makefile( "$this->{tempdir}", "TestFile.patch", <<'DONE');
commit 5e6b4d1f9540bb7b75705faf80e412fc0c66fe84
Author: GeorgeClark <GeorgeClark@0b4bb1d4-4e5a-0410-9cc4-b2b747904278>
Date:   Mon Nov 5 05:07:25 2012 +0000

    Item11267: Don't use "HEAD" to detect pseudo install.
    
    A real, non-pseudo-installed extension will crash configure if a perl
    version object is compared to an alpha string.
    
    9999.99_999 will be used to indicate a pseudo-installed release.
    
    git-svn-id: http://svn.foswiki.org/trunk@15909 0b4bb1d4-4e5a-0410-9cc4-b2b747904278

##PATCH fdeeb7f236608b7792ad0845bf2279f9  lib/Foswiki/Configure/Dependency.pm
--- a/core/lib/Foswiki/Configure/Dependency.pm
+++ b/core/lib/Foswiki/Configure/Dependency.pm
@@ -220,7 +220,7 @@ sub studyInstallation {
             if ( -l "$dir/$path" ) {
 
                 # Assume pseudo-installed
-                $this->{installedVersion} = '9999.99_999';
+                $this->{installedVersion} = 'HEAD';
             }
             last;
         }
##PATCH 76e28354522a6d6cccc76c66f99d2424  lib/Foswiki/Configure/UIs/EXTENSIONS.pm
--- a/core/lib/Foswiki/Configure/UIs/EXTENSIONS.pm
+++ b/core/lib/Foswiki/Configure/UIs/EXTENSIONS.pm
@@ -339,7 +339,7 @@ sub _rawExtensionRows {
         if ( $ext->{installedRelease} ) {
 
             # The module is installed; check the version
-            if ( $ext->{installedVersion} eq '9999.99_999' ) {
+            if ( $ext->{installedVersion} eq 'HEAD' ) {
 
                 # pseudo-installed
                 $install = 'pseudo-installed';
DONE

    my %result = Foswiki::Configure::PatchFile::parsePatch(
        $this->{tempdir} . '/TestFile.patch' );

    foreach my $key ( keys %result ) {
        print STDERR "KEY $key  \n";
        next if ( $key eq 'summary' );
        foreach my $md5 ( keys %{ $result{$key} } ) {
            print "MD5 $md5\n patch $result{$key}{$md5} \n";

            my $origFile = Foswiki::Configure::Util::mapTarget( '/tmp', $key );

            my $savepath = $Foswiki::foswikiLibPath;
            $Foswiki::foswikiLibPath = '/tmp/lib';
            mkpath($Foswiki::foswikiLibPath);

            my $file = Foswiki::Configure::Util::mapTarget( '/tmp', $key );
            $Foswiki::foswikiLibPath = $savepath;

            my ( $fv, $fp, $fn ) = File::Spec->splitpath( $file, 0 );
            mkpath($fp);
            copy( $origFile, $file );
            my $origMD5 = _getMD5($origFile);
            $this->assert( ( $origMD5 eq $md5 ), "$file $md5 ne $origMD5" );

            print STDERR
              "$key mapped to $file\n - Vol $fv, path $fp, name $fn \n";

            my $rc =
              Foswiki::Configure::PatchFile::updateFile( $file,
                $result{$key}{$md5} );

            $this->assert( !$rc, "Failed with $rc\n" );
        }

    }

}

sub _getMD5 {

    my $filename = shift;
    open( my $fh, '<', $filename ) or die "Can't open '$filename': $!";
    binmode($fh);
    return Digest::MD5->new->addfile($fh)->hexdigest;
}

sub _makefile {
    my $path    = shift;
    my $file    = shift;
    my $content = shift;

    $content = "datadata/n" unless ($content);

    mkpath($path);
    open( my $fh, '>', "$path/$file" )
      or die "Unable to open $path/$file for writing: $!\n";
    print $fh $content;
    close($fh) or die "Couldn't close $path/$file: $!\n";

    return;
}

sub test_Package_makeBackup {
    my $this = shift;

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;

    my $result = '';
    my $err    = '';

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    rmtree($tempdir);    # Clean up old files if left behind
    mkpath($tempdir);

    my $extension = "MyPlugin";
    _makePackage( $tempdir, $extension );

    use Foswiki::Configure::Package;
    my $pkg =
      Foswiki::Configure::Package->new( $root, "$extension", $this->{session} );

    ( $result, $err ) =
      $pkg->loadInstaller( { DIR => $tempdir, USELOCAL => 1 } );
    $this->assert( !$err );

    ( $result, $err ) = $pkg->_install( { DIR => $tempdir, EXPANDED => 1 } );

    $this->assert( !$err );

    my $msg = $pkg->createBackup();
    $this->assert_matches( qr/Backup saved into/, $msg );
    $result = $pkg->uninstall();
    my @expFiles = (
        'Testsandboxweb1234/Subweb/TestTopic43.txt',
        'Testsandboxweb1234/TestTopic1.txt',
        'Testsandboxweb1234/TestTopic43.txt',
        'Testsandboxweb1234/Subweb/TestTopic43/file3.att',
        'Testsandboxweb1234/Subweb/TestTopic43/subdir-1.2.3/file4.att',
        'Testsandboxweb1234/TestTopic1/file.att',
        'Testsandboxweb1234/TestTopic43/file.att',
        'Testsandboxweb1234/TestTopic43/file2.att',
        'configure/pkgdata/MyPlugin_installer'
    );

    push @expFiles, "$this->{scriptdir}/shbtest1";
    push @expFiles, "$this->{toolsdir}/shbtest2";

    foreach my $expFile (@expFiles) {

        #print STDERR "Checkkng $expFile\n";
        $this->assert_matches( qr/$expFile/, $result, "Missing file $expFile" );
    }

    $pkg->finish();

    return;
}

my $INSTALL_HEAD = <<'HERE';
#!blah
bleh

sub preuninstall {

    return "Pre-uninstall entered";
}

sub postuninstall {

    # # No POSTUNINSTALL script;

    return;
}

sub preinstall {

    return "Pre-install entered";
}

sub postinstall {

    my $this = shift;   # Get the object instance passed to the routine
    if ($this) {        # Verify that you are running in the new environment
HERE

my $INSTALL_FOOT = <<'HERE';
        return "Removed $file" if unlink $file;
    }

    return;
}

Foswiki::Extender::install( $PACKAGES_URL, 'CommentPlugin', 'CommentPlugin', @DATA );

1;
our $VERSION = '2.1';
# MANIFEST and DEPENDENCIES are done this way
# to make it easy to extract them from this script.

__DATA__
<<<< MANIFEST >>>>
bin/shbtest1,0755,1a9a1da563535b2dad241d8571acd170,
data/Sandbox/TestTopic1.txt,0644,1a9a1da563535b2dad241d8571acd170,Documentation (noci)
data/Sandbox/TestTopic43.txt,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
data/Sandbox/Subweb/TestTopic43.txt,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
pub/Sandbox/TestTopic1/file.att,0664,ede33d5e092a0cb2fa00d9146eed5f9a, (noci)
pub/Sandbox/TestTopic43/file.att,0664,1a9a1da563535b2dad241d8571acd170,
pub/Sandbox/TestTopic43/file2.att,0664,ede33d5e092a0cb2fa00d9146eed5f9a,
pub/Sandbox/Subweb/TestTopic43/file3.att,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3/file4.att,0644,4dcabc1c8044e816f3c3d1a071ba1bc5,Documentation
tools/shbtest2,0755,1a9a1da563535b2dad241d8571acd170,

<<<< DEPENDENCIES >>>>
.\@#$%}{Filtrx::Invalid::Blah,>=0.68,1,CPAN,Required. install from CPAN
Time::ParseDate,>=2003.0211,1,cpan,Required. Available from the CPAN:Time::ParseDate archive.
Foswiki::Plugins::RequiredTriggeredModule,>=0.1,( $Foswiki::Plugins::VERSION < 3.2 ),perl,Required
Foswiki::Plugins::UnneededTriggeredModule,>=0.1,( $Foswiki::Plugins::VERSION < 2.1 ),perl,Required
Foswiki::Contrib::OptionalDependency,>=14754,1,perl,optional module
Foswiki::Contrib::UnitTestContrib::MultiDottedVersion,>=14754,1,perl,Required
File::Spec, >0,1,cpan,This module is shipped as part of standard perl
Cwd, >55,1,cpan,This module is shipped as part of standard perl
htmldoc, >24.3,1,c,Required for generating PDF

HERE

#
# Utility subroutine to build the files for an installable package
#
sub _makePackage {
    my ( $tempdir, $plugin ) = @_;

    open( my $fh, '>',
        "$tempdir/${plugin}_installer$Foswiki::cfg{ScriptSuffix}" )
      || die "Unable to open \n $! \n\n ";
    print $fh $INSTALL_HEAD;
    print $fh "        my \$file = \"$tempdir/obsolete.pl\";\n";
    print $fh $INSTALL_FOOT;
    close($fh) or die "Couldn't close: $!\n";
    _makefile( "$tempdir/data/Sandbox", "TestTopic1.txt", <<'DONE');
%META:TOPICINFO{author="BaseUserMapping_333" comment="reprev" date="1267729185" format="1.1" reprev="1.1" version="1.1"}%
Test rev 132412341234
==qr/[\s\*?~^\$@%`"'&;|&lt;&gt;\[\]\x00-\x1f]/;==

-- Main.AdminUser - 04 Mar 2010
DONE
    _makefile( "$tempdir/data/Sandbox", "TestTopic43.txt", <<'DONE');
%META:TOPICINFO{author="BaseUserMapping_333" comment="reprev" date="1267729185" format="1.1" reprev="1.1" version="1.1"}%
Test rev 132412341234
==qr/[\s\*?~^\$@%`"'&;|&lt;&gt;\[\]\x00-\x1f]/;==

-- Main.AdminUser - 04 Mar 2010
DONE
    _makefile( "$tempdir/pub/Sandbox/TestTopic1", "file.att", <<'DONE');
#! /usr/bin/perl
Test file data
DONE
    _makefile( "$tempdir/pub/Sandbox/TestTopic43", "file.att", <<'DONE');
Test file data
DONE
    _makefile( "$tempdir/pub/Sandbox/TestTopic43", "file2.att", <<'DONE');
Test file data
DONE
    _makefile( "$tempdir/bin", "shbtest1", <<'DONE');
#! /usr/bin/perl
Test file data
DONE
    _makefile( "$tempdir/tools", "shbtest2", <<'DONE');
#! /usr/bin/perl
Test file data
DONE
    _makefile( "$tempdir/data/Sandbox/Subweb", "TestTopic43.txt", <<'DONE');
#! /usr/bin/perl
Test file data
DONE
    _makefile( "$tempdir/pub/Sandbox/Subweb/TestTopic43", "file3.att",
        <<'DONE');
Test file data
DONE
    _makefile( "$tempdir/pub/Sandbox/Subweb/TestTopic43/subdir-1.2.3",
        "file4.att", <<'DONE');
Test file data
DONE

    return;
}

1;
