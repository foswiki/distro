#! /usr/bin/env perl

use strict;
use warnings;

use Cwd;
use File::Spec;
use File::Find;
use Data::Dumper;
use LWP::Simple;
use JSON;

my $extension = shift;
my %items;    # Hash to cache item # & descriptions.

# Tasks that are typically left open and not documented in release notes,  eg. Documentation, Translation, etc.
my @omit = (qw(Item13883 Item13884 Item13504));

my $start = `git describe --tags --abbrev=0`;
unless ($start) {
    help();
    die "Unable to locate starting tag.";
}
chomp $start;
print "checking for changes since $start\n";

my @changed;

# Prints some "helpful" messages
sub help {
    print <<"END";
Run this script from the top of a foswiki git checkout. The list of "default"
extensions is retrieved from "lib/MANIFEST".  Each extension will checked for:
   * The VERSION recorded in the .pm file should be > than the prior releases version.
   * (SMELL: Does not account for interim releases of the extensioni)
   * Commit Item* numbers are extracted from the git commit log and compared to the change log un the data/System/Extension.txt file.
   * The check_manifest.pl script is run against the extension

END
}

my $root = findPathToDir('core/lib');
die
"Could not find core/lib and MANIFEST.  Are you running from the root of a checkout?"
  unless ( -d "$root/core/lib" && -f "$root/core/lib/MANIFEST" );
my $manifest = "$root/core/lib/MANIFEST";

# process MANIFEST file:
#!include ../core/lib/Foswiki/Contrib/core
#!include ../AutoViewTemplatePlugin/lib/Foswiki/Plugins/AutoViewTemplatePlugin
#!include ../CompareRevisionsAddOn/lib/Foswiki/Contrib/CompareRevisionsAddOn
#
my @extensions;
if ($extension) {
    push @extensions, $extension;
}
else {
    open my $man, '<', $manifest or die "Can't open $manifest for reading: $!";
    print "Processing manifest $manifest\n";
    while (<$man>) {
        next unless /^!include \.\.\/([^\/]+)/;
        next if ( $1 eq 'core' );
        push @extensions, $1;
    }
    close $man;
}

if ( $extensions[0] =~ m/^Release/ ) {
    my $release = $extensions[0];
    my @itemlist;
    my $gitlog = `git log --oneline $start..HEAD .`;
    next
      unless
      $gitlog;    # Comment this to get verbose report of unmodified extensions.
    print "\n========== $release ============\n";
    if ($gitlog) {
        @itemlist = $gitlog =~ m/(Item\d+):/g;
        my $topicText = get_rel_notes($release);
        my $last      = '';
        foreach my $item ( sort @itemlist ) {
            next if $item eq $last;

#SMELL: SmartMatch is experimental.  But had to give it a try.  Will  be changed in upcoming perl.
            next if $item ~~ @omit;
            $last = $item;
            my $taskinfo = get_task_info($item);
            print "WARNING: Wrong state: $taskinfo\n"
              unless $taskinfo =~ m/Waiting for Release/;
            next if $topicText =~ m/$item\b/;
            print "MISSING: from change log: $taskinfo\n";

        }
    }

}
else {

    foreach my $ext ( sort @extensions ) {
        chomp $ext;
        chdir "$root/$ext";
        my @itemlist;
        my $gitlog = `git log --oneline $start..HEAD .`;
        next
          unless $gitlog
          ;    # Comment this to get verbose report of unmodified extensions.
        print "\n========== $ext ============\n";
        if ($gitlog) {
            push @changed, $ext;
            @itemlist = $gitlog =~ m/(Item\d+):/g;
            my $topicText = get_ext_topic($ext);
            my $last      = '';
            foreach my $item ( sort @itemlist ) {
                next if $item eq $last;

#SMELL: SmartMatch is experimental.  But had to give it a try.  Will  be changed in upcoming perl.
                next if $item ~~ @omit;
                $last = $item;
                my $taskinfo = get_task_info($item);
                print "WARNING: Wrong state: $taskinfo\n"
                  unless $taskinfo =~ m/Waiting for Release/;
                next if $topicText =~ m/$item\b/;
                print "MISSING: from change log: $taskinfo\n";

            }
        }

        else {
            print "No changes since last release\n";
        }

        my $class = ( $ext =~ m/Plugin/ ) ? 'Plugins' : 'Contrib';
        my $origsrc = `git show $start:$ext/lib/Foswiki/$class/$ext.pm`;

        my $mancheck = `../core/tools/check_manifest.pl`;
        chomp $mancheck;
        $mancheck =~ s/^Processing manifest .*\/MANIFEST$//g;
        print "\n\n$mancheck" if ($mancheck);

        my $ov = extractModuleVersion( "lib/Foswiki/$class/$ext", $origsrc );
        my $lv = extractModuleVersion("lib/Foswiki/$class/$ext");
        my $exthash = get_ext_info($ext);

        print "\n\n";
        print
"$ext - Last release: $ov, Uploaded $exthash->{version}, Module: $lv\n";

        if ( ( $ov eq $lv || $exthash->{version} eq $lv ) && $gitlog ) {
            print
"ERROR: $ext: Identical versions, but commits logged since last release\n";
        }
    }

    print "\n\nChanged extensions: " . join( ', ', @changed ) . "\n";

}

#chdir $root;

# Search the current working directory and its parents
# for a directory called like the first parameter
sub findPathToDir {
    my $lookForDir = shift;

    my @dirlist = File::Spec->splitdir( Cwd::getcwd() );
    do {
        my $dir = File::Spec->catdir( @dirlist, $lookForDir );
        return File::Spec->catdir(@dirlist) if -d $dir;
    } while ( pop @dirlist );
    return;
}

=begin TML

---++ StaticMethod extractModuleVersion ($moduleName, $magic) -> ($moduleFound, $moduleVersion, $modulePath)

Locates a module in @INC and parses it to determine its version.  If the second parameter is
true, it magically handles Foswiki.pm's version construction.

Returns:
  $moduleFound - True if the module was found (and could be opended for read)
  $moduleVersion - The module version that was extracted, or undef if none was found.
  $modulePath - The full path to the module.

Require was used previously, but it doesn't scale and can have side-effects such a
loading many unused dependencies, even LocalSite.cfg if it's a Foswiki module.

Since $VERSION is usually declared early in a module, we can also avoid reading
most of (most) files.

This parser was inspired by Module::Extract::VERSION, though this is simplified and
has special magic for the Foswiki build.

=cut

sub extractModuleVersion {
    my $module = shift;
    my $src    = shift;

    my $file = $module;
    $file =~ s,::,/,g;
    $file .= '.pm';

    # If module is available but no version, don't return undefined
    my $mod_version = '0';

    if ( length $src ) {
        my @srclines = split( /\n/, $src );

        my $pod;
        foreach (@srclines) {
            chomp;
            if (/^=cut/) {
                $pod = 0;
                next;
            }
            if (/^=/) {
                $pod = 1;
                next;
            }
            next if ($pod);
            next if m/eval/; # Some modules issue $VERSION = eval $VERSION ... bypass that line
            s/\s*#.*$//;
            next unless (/^\s*(?:our\s+)?\$(?:\w*::)*VERSION\s*=\s*(.*?);/);
            eval("\$mod_version = $1;");

    # die "Failed to eval $1 from $_ in $file at line $. $@\n" if( $@ ); # DEBUG
            last;
        }
    }
    else {
        open( my $mf, '<', "$file" ) or die "Unable to open $file";
        local $/ = "\n";
        local $_;
        my $pod;
        while (<$mf>) {
            chomp;
            if (/^=cut/) {
                $pod = 0;
                next;
            }
            if (/^=/) {
                $pod = 1;
                next;
            }
            next if ($pod);
            next
              if m/eval/
              ; # Some modules issue $VERSION = eval $VERSION ... bypass that line
            s/\s*#.*$//;
            next unless (/^\s*(?:our\s+)?\$(?:\w*::)*VERSION\s*=\s*(.*?);/);
            eval("\$mod_version = $1;");

    # die "Failed to eval $1 from $_ in $file at line $. $@\n" if( $@ ); # DEBUG
            last;
        }
        close $mf;
    }
    return $mod_version;
}

sub get_ext_topic {
    my $ext  = shift;
    my $file = "data/System/$ext.txt";

    open( my $mf, '<', "$file" ) or die "Unable to open $file";
    local $/;
    my $topicText = <$mf>;
    close $mf;
    return $topicText;
}

sub get_rel_notes {
    my $release = shift;
    $release =~ s/^Release/ReleaseNotes/;
    my $file = "core/data/System/$release.txt";

    open( my $mf, '<', "$file" ) or die "Unable to open $file";
    local $/;
    my $topicText = <$mf>;
    close $mf;
    return $topicText;
}

sub get_ext_info {
    my $ext = shift;

    my $url =
"https://foswiki.org/Extensions/JsonReport?contenttype=application/json;skin=text;name=^$ext\$";
    my $jsondata = get $url;

    unless ( defined $jsondata ) {
        die
"ERROR: GET on Tasks.ItemStatusQuery failed.  Check https://foswiki.org/Tasks/ItemStatusQuery\n";
    }
    my $jsonarray = decode_json($jsondata);
    my $json      = shift @{$jsonarray};
    return $json;
}

sub get_task_info {
    my $it = shift;

    return $items{$it} if $items{$it};
    my $url = "http://foswiki.org/Tasks/ItemSummaryQuery?item=$it;skin=text";
    my $description = get $url;
    $description =~ s#<b>.*</b>\n##;
    $items{$it} = $description;
    return $description;
}

