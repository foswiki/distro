package PatchFoswikiContribTests;

use strict;
use warnings;

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Error       ();
use File::Temp  ();
use FindBin     ();
use File::Path  ();
use Digest::MD5 ();

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
    File::Path::rmtree( $this->{tempdir} )
      if ( -e $this->{tempdir} );    # Cleanup any old tests
    File::Path::mkpath( $this->{tempdir} );
    $this->{scriptdir}       = $this->{tempdir} . '/bin';
    $Foswiki::cfg{ScriptDir} = $this->{scriptdir};
    $this->{toolsdir}        = $this->{tempdir} . '/tools';
    $Foswiki::cfg{ToolsDir}  = $this->{toolsdir};
    $this->{logdir}          = $this->{tempdir} . '/logs';
    $Foswiki::cfg{Log}{Dir}  = $this->{logdir};

    $Foswiki::cfg{TrashWebName}   = $this->{trash_web};
    $Foswiki::cfg{SandboxWebName} = $this->{sandbox_web};

    $Foswiki::RELEASE = 'Foobar-1';
    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, $this->{test_web} );
    $this->removeWebFixture( $this->{session}, $this->{trash_web} );
    $this->removeWebFixture( $this->{session}, $this->{sandbox_web} );
    File::Path::rmtree( $this->{tempdir} );    # Cleanup any old tests
    $this->SUPER::tear_down();

    return;
}

sub removeWeb {
    my ( $this, $web ) = @_;
    $this->removeWebFixture( $this->{session}, $web );

    return;
}

# Test applying and removing a patch
sub test_PatchFile_parse_backup {
    my $this = shift;

    _makefile( "$this->{tempdir}", "Item0000.patch", <<'DONE');
commit 5e6b4d1f9540bb7b75705faf80e412fc0c66fe84
Author: GeorgeClark <GeorgeClark@0b4bb1d4-4e5a-0410-9cc4-b2b747904278>
Date:   Mon Nov 5 05:07:25 2012 +0000

    Item11267: Don't use "HEAD" to detect pseudo install.

~~~PATCH 829239dd10279df7a8851299e5beeeb2:630427bf41c01c9428d1e8d0ad298690  lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm (Foobar-1)
--- lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm	2012-12-24 16:48:56.663587164 -0500
+++ lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.new	2012-12-24 16:50:22.478548551 -0500
@@ -14,9 +14,9 @@
 # Always use strict to enforce variable scoping
 use strict;
 use warnings;
+use Data::Dumper

DONE

    _makefile( "$this->{tempdir}", "Item0001.patch", <<'DONE');
commit 5e6b4d1f9540bb7b75705faf80e412fc0c66fe84
Author: GeorgeClark <GeorgeClark@0b4bb1d4-4e5a-0410-9cc4-b2b747904278>
Date:   Mon Nov 5 05:07:25 2012 +0000

    Item11267: Don't use "HEAD" to detect pseudo install.


~~~PATCH 630427bf41c01c9428d1e8d0ad298690:829239dd10279df7a8851299e5beeeb2  lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm (Foobar-1)  
--- lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm	2012-12-24 16:48:56.663587164 -0500
+++ lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.new	2012-12-24 16:50:22.478548551 -0500
@@ -14,9 +14,9 @@
 # Always use strict to enforce variable scoping
 use strict;
 use warnings;
+use Data::Dumper
 
DONE

    _makefile( "$this->{tempdir}", "Item0002.patch", <<'DONE');
commit 5e6b4d1f9540bb7b75705faf80e412fc0c66fe84
Author: GeorgeClark <GeorgeClark@0b4bb1d4-4e5a-0410-9cc4-b2b747904278>
Date:   Mon Nov 5 05:07:25 2012 +0000

    Item11267: Don't use "HEAD" to detect pseudo install.

 
~~~PATCH 123427bf41c01c9428d1e8d0ad298690:123239dd10279df7a8851299e5beeeb2  lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm (Foobar-1) 
--- lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm	2012-12-24 16:48:56.663587164 -0500
+++ lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.new	2012-12-24 16:50:22.478548551 -0500
@@ -14,9 +14,9 @@
 # Always use strict to enforce variable scoping


DONE

    my %result = Foswiki::Configure::PatchFile::parsePatch(
        $this->{tempdir} . '/Item0000.patch' );

    $Foswiki::RELEASE = 'Foobar-3';
    my $msgs =
      Foswiki::Configure::PatchFile::backupTargets( undef, \%result, 0 );

    # N/A Release - patch should not be backed up
    $this->assert_matches( qr/\| N\/A Release \|/ms,   $msgs );
    $this->assert_matches( qr/\| Foobar-1 \|/ms,       $msgs );
    $this->assert_matches( qr/^No files backed up./ms, $msgs );

    $Foswiki::RELEASE = 'Foobar-1';
    $msgs = Foswiki::Configure::PatchFile::backupTargets( undef, \%result, 0 );

    # NOT APPLIED patch should be backed up
    $this->assert_matches( qr/\| NOT APPLIED \|/ms, $msgs );
    $this->assert_matches( qr/\| Foobar-1 \|/ms,    $msgs );
    $this->assert_matches( qr/^Backed up target: .*PatchTestTarget.pm/ms,
        $msgs );
    $this->assert_matches( qr/^Backup Archived.*configure\/backup\/Item000/ms,
        $msgs );
    $this->assert_matches( qr/^1 file backed up./ms, $msgs );

    %result = Foswiki::Configure::PatchFile::parsePatch(
        $this->{tempdir} . '/Item0001.patch' );

    $msgs = Foswiki::Configure::PatchFile::backupTargets( undef, \%result, 0 );

    # Already PATCHED should not be backed up
    $this->assert_matches( qr/\| PATCHED \|/ms,        $msgs );
    $this->assert_matches( qr/^No files backed up./ms, $msgs );

    %result = Foswiki::Configure::PatchFile::parsePatch(
        $this->{tempdir} . '/Item0002.patch' );

    $msgs = Foswiki::Configure::PatchFile::backupTargets( undef, \%result, 0 );

    # Not applicable should not be backed up
    $this->assert_matches( qr/\| N\/A \|/ms,           $msgs );
    $this->assert_matches( qr/^No files backed up./ms, $msgs );

    $msgs = Foswiki::Configure::PatchFile::backupTargets( undef, \%result, 1 );

    # Reversing an unapplied patch - also not applicable should not be backed up
    $this->assert_matches( qr/\| N\/A \|/ms,           $msgs );
    $this->assert_matches( qr/^No files backed up./ms, $msgs );

    %result = Foswiki::Configure::PatchFile::parsePatch(
        $this->{tempdir} . '/Item0001.patch' );

    $msgs = Foswiki::Configure::PatchFile::backupTargets( undef, \%result, 1 );

    # Reversing a patch - should be backed up
    $this->assert_matches( qr/\| PATCHED \|/ms, $msgs );
    $this->assert_matches( qr/^Backed up target: .*PatchTestTarget.pm/ms,
        $msgs );
    $this->assert_matches( qr/^Backup Archived.*configure\/backup\/Item000/ms,
        $msgs );
    $this->assert_matches( qr/^1 file backed up./ms, $msgs );

    %result = Foswiki::Configure::PatchFile::parsePatch(
        $this->{tempdir} . '/Item0002.patch' );

    $msgs = Foswiki::Configure::PatchFile::backupTargets( undef, \%result, 1 );

    # Reversing a N/A patch - should not be backed up
    $this->assert_matches( qr/\| N\/A \|/ms,           $msgs );
    $this->assert_matches( qr/^No files backed up./ms, $msgs );

}

# Test applying and removing a patch
sub test_PatchFile_parse_patch_remove {
    my $this = shift;

    _makefile( "$this->{tempdir}", "TestFile.patch", <<'DONE');
commit 5e6b4d1f9540bb7b75705faf80e412fc0c66fe84
Author: GeorgeClark <GeorgeClark@0b4bb1d4-4e5a-0410-9cc4-b2b747904278>
Date:   Mon Nov 5 05:07:25 2012 +0000

    Item11267: Don't use "HEAD" to detect pseudo install.
    


~~~PATCH 829239dd10279df7a8851299e5beeeb2:630427bf41c01c9428d1e8d0ad298690  lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm (Foobar-1)
--- lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm	2012-12-24 16:48:56.663587164 -0500
+++ lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.new	2012-12-24 16:50:22.478548551 -0500
@@ -14,9 +14,9 @@
 # Always use strict to enforce variable scoping
 use strict;
 use warnings;
+use Data::Dumper
 
 # $VERSION is referred to by Foswiki, and is the only global variable that
-# *must* exist in this package. This should always be in the format
 # $Rev$ so that Foswiki can determine the checked-in status of the
 # extension.
 our $VERSION = '1.4';
@@ -27,13 +27,17 @@
 # tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
 #           usually refer to major.minor.patch release or similar. You can
 #           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
+#           usually refer to major.minor.patch release or similar. You can
+#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
+#           usually refer to major.minor.patch release or similar. You can
+#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
 # isodate - a date in ISO8601 format e.g. 2009-08-07
 # date    - a date in 1 Jun 2009 format. Three letter English month names only.
 # Note: it's important that this string is exactly the same in the extension
 # topic - if you use %$RELEASE% with BuildContrib this is done automatically.
 our $RELEASE = '1.4';
 
-our $SHORTDESCRIPTION = 'Apply critical patches to Foswiki.';
+our $SHORTDESCRIPTION = 'Apply any  patches to Foswiki.';
 
 1;
 
@@ -54,6 +58,6 @@
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
-MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 
 As per the GPL, removal of this notice is prohibited.
+blah

DONE

    my %result = Foswiki::Configure::PatchFile::parsePatch(
        $this->{tempdir} . '/TestFile.patch' );

    my $msgs = Foswiki::Configure::PatchFile::checkPatch( undef, \%result );

    $this->assert_equals(
"| lib/Foswiki/Contrib/PatchFoswikiContrib/PatchTestTarget.pm | 829239dd10279df7a8851299e5beeeb2 | NOT APPLIED | Foobar-1 |\n\n",
        $msgs
    );

    foreach my $key ( keys %result ) {
        next if ( $key eq 'summary' );
        foreach my $md5 ( keys %{ $result{$key} } ) {

            $this->assert_str_equals( $result{$key}{$md5}{status},
                'NOT APPLIED' );

            my $origFile =
              Foswiki::Configure::PatchFile::mapTarget( '/tmp', $key );

            # Override lib path so the patch won't apply to the live system
            my $savepath = $Foswiki::foswikiLibPath;
            $Foswiki::foswikiLibPath = '/tmp/lib';
            File::Path::mkpath($Foswiki::foswikiLibPath);
            my $file = Foswiki::Configure::PatchFile::mapTarget( '/tmp', $key );
            $Foswiki::foswikiLibPath = $savepath;

            my ( $fv, $fp, $fn ) = File::Spec->splitpath( $file, 0 );
            File::Path::mkpath($fp);
            File::Copy::copy( $origFile, $file );
            my $origMD5 = _getMD5($origFile);
            $this->assert( ( $origMD5 eq $md5 ), "$file $md5 ne $origMD5" );

            my $msg =
              Foswiki::Configure::PatchFile::updateFile( $file,
                $result{$key}{$md5}{patch} );

            $this->assert_matches( qr/Update successful/,
                $msg,, "Failed with $msg\n" );

            my $newMD5 = _getMD5($file);
            $this->assert( ( $newMD5 eq $result{$key}{$md5}{patched} ),
                "$file  ne $newMD5" );

            $msg =
              Foswiki::Configure::PatchFile::updateFile( $file,
                $result{$key}{$md5}{patch}, 1 );

            $this->assert_matches( qr/Update reversed/,
                $msg, "Failed with $msg\n" );

            $newMD5 = _getMD5($file);
            $this->assert( ( $newMD5 eq $md5 ), "$md5  ne $newMD5" );

        }

    }

}

sub _getMD5 {

    my $filename = shift;
    open( my $fh, '<', $filename ) or die "Can't open '$filename': $!";
    binmode($fh);
    my $digest = Digest::MD5->new->addfile($fh)->hexdigest;
    close $fh;
    return $digest;
}

sub _makefile {
    my $path    = shift;
    my $file    = shift;
    my $content = shift;

    $content = "datadata/n" unless ($content);

    File::Path::mkpath($path);
    open( my $fh, '>', "$path/$file" )
      or die "Unable to open $path/$file for writing: $!\n";
    print $fh $content;
    close($fh) or die "Couldn't close $path/$file: $!\n";

    return;
}

sub disable_test_Package_makeBackup {
    my $this = shift;

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;

    my $result = '';
    my $err    = '';

    my $tempdir = $this->{tempdir} . '/test_util_installFiles';
    File::Path::rmtree($tempdir);    # Clean up old files if left behind
    File::Path::mkpath($tempdir);

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
