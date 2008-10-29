#!/usr/bin/perl

# cruise back up the tree until we find lib and data subdirs
require Cwd;

my @cwd = split(/[\/\\]/, Cwd::getcwd());
my $root;

while (scalar(@cwd) > 1) {
    $root = join('/', @cwd);
    if (-d "$root/lib" && -d "$root/data") {
        last;
    }
    pop(@cwd);
}

die "Can't find root" unless (-d "$root/lib" && -d "$root/data");

@skip = qw(twikiplugins tools test working logs);
print <<END;
Run this script from anywhere (either in core root or in a subdir
of twikiplugins).

The script will find and scan MANIFEST and compare the contents with
what is checked in under subversion. Any differences are reported.

END
print "The ",join(',', @skip)," directories are *not* scanned.\n";

my $manifest = 'lib/MANIFEST';
unless (-f $manifest) {
    $manifest = `find $root/lib/TWiki -name 'MANIFEST' -print`;
    chomp $manifest;
}
die "No such MANIFEST $manifest" unless -e $manifest;

my %man;

map{ s/ .*//; $man{$_} = 1; }
  grep { !/^!include/  }
  split(/\n/, `cat $manifest` );

my @lost;
my $sk = join('|', @skip);
foreach my $dir( grep { -d "$root/$_" }
                   split(/\n/, `svn ls $root`) ) {
    next if $dir =~ /^($sk)\/$/;
    print "Examining $root/$dir\n";
    push( @lost,
          grep { !$man{$_} && !/\/TestCases\// && ! -d "$root/$_" }
            map{ "$dir$_" }
              split(/\n/, `svn ls -R $root/$dir`));
}
print "The following files were found in subversion, but are not in MANIFEST\n";
print join("\n", @lost ),"\n";
