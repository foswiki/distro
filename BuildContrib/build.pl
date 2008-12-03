#!/usr/bin/perl
unless ( scalar(@ARGV) ) {
    print <<DOC;
Build an extension

When run from the 'trunk' directory of a Foswiki trunk checkout
this script will build the BuildContrib-enabled extension named in the
first parameter. The second parameter is the build target for the extension.

Examples:
$ perl build.pl ActionTrackerPlugin
$ perl build.pl SubscribePlugin upload
$ for f in FirstPlugin SecondPlugin; do perl build.pl $f release; done
DOC
    exit 1;
}

my $arg = '';
my $extension = shift(@ARGV);
if ($extension eq '-v') {
    $arg = $extension;
    $extension = shift(@ARGV);
}
$extension =~ s./+$..;
my $target = shift(@ARGV) || '';

my $extdir = "Contrib";
if ( $extension =~ /Plugin$/ ) {
    $extdir = "Plugins";
}

my $scriptDir = "$extension/lib/Foswiki/$extdir/$extension";
unless ( -e "$scriptDir/build.pl" ) {
    $scriptDir = "$extension/lib/TWiki/$extdir/$extension";
    unless ( -e "$scriptDir/build.pl" ) {
        die "build.pl not found";
    }
}

my $call = './build.pl '.$arg.' '.$target;
print "calling build.pl in $scriptDir\n" if ($arg eq '-v');

use Cwd;
chdir($scriptDir);
print `$call`;


