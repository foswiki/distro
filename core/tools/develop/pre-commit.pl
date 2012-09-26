#!/usr/bin/perl
use strict;
use warnings;
use Perl::Tidy;
use Text::Diff;
use File::Spec;

# PRE-COMMIT HOOK for Foswiki Subversion
#
# The pre-commit hook tests that the item(s) listed in the checkin
# exist(s) in Tasks web, and is(are) in a state to receive checkins.
#
# STDERR ends up on the users' terminal

my $REPOS   = $ARGV[0];
my $TXN     = $ARGV[1];
my $dataDir = "/home/foswiki.org/public_html/data";
my $rev     = "-t $TXN";

my $SVNLOOK = '/usr/local/bin/svnlook';
my $logmsg  = `$SVNLOOK log $rev $REPOS`;

# PLEASE keep this message in sync with
# http://foswiki.org/Development/SvnRepository#RulesForCheckins
sub fail {
    my $message = shift;
    print STDERR <<"EOF";
--------------------------------------------------------------
Illegal checkin to $REPOS:
$logmsg
$message
http://foswiki.org/Development/SvnRepository#RulesForCheckins
Rules - checkins must:
1. Have a comment...
2. ...with relevant ItemNNN topics in the first line, example:

Item12345: Item12346: fixed foo, updated release notes

3. Use ItemNNN topics which are open at the time of checkin,
   I.E. *not* one of: Closed, Waiting For Release, No Action
4. Have "tidied" source code if the TIDY control file in the
   root of the extension calls for it, see:
   http://foswiki.org/Development/TIDY

NB Getting rejected commits with perltidy older than v20120714?
   See http://foswiki.org/Development/PerlTidy#Versions
--------------------------------------------------------------
EOF
    exit 1;
}

fail("No Bug item in log message") unless ( $logmsg =~ /\bItem\d+\s*:/ );

my @items;
$logmsg =~ s/\b(Item\d+)\s*:/push(@items, $1); '';/gem;
foreach my $item (@items) {
    fail "Bug item $item does not exist"
      unless ( -f "$dataDir/Tasks/$item.txt" );
    open( my $file, '<', "$dataDir/Tasks/$item.txt" )
      || die "Cannot open $item";
    my $text = do { local $/; <$file> };
    my $state = "Closed";
    if ( $text =~ /^%META:FIELD{name="CurrentState".*value="(.*?)"/m ) {
        $state = $1;
    }
    close($file);
    if ( $state =~ /^(Waiting for Release|Closed|No Action Required)$/ ) {
        fail("$item is in $state state; cannot check in");
    }
}

# Verify that code is cleanly formatted, but only for files which were not
# removed, and end in .pm or .pl, and are not CPAN libraries
my %tidyOption;

# Returns undef when file should be skipped,
# otherwise returns perltidy options to be used (can be empty for defaults)
sub getTidyOptions {
    my $file = shift;
    return undef unless $file =~ /\.p[ml]$/;    # Only perl files
    return undef if $file =~ m#/lib/CPAN/lib/#; # Not CPAN modules
    return $tidyOption{$file} if exists $tidyOption{$file};

    my $tidyOptions = undef;                    # Defaults to skip
    my ( $volume, $directory ) = File::Spec->splitpath($file);
    my @pathList;    # Save examined hierarchy to update cache
    my @path = File::Spec->splitdir($directory);
    while ( defined pop @path ) {
        my $path = File::Spec->catdir(@path);
        $tidyOptions = $tidyOption{$path} and last if exists $tidyOption{$path};
        push @pathList, $path;    # To update cache hierachy
        my $tidyFile = File::Spec->catpath( $volume, $path, 'TIDY' );
        my @tidyOptions = `$SVNLOOK cat $rev $REPOS $tidyFile 2>/dev/null`;
        if ( $? == 0 ) {          # Found a TIDY file, check its content
            $tidyOptions = '';    # Defaults to check
            for (@tidyOptions) {
                if (/^(?:perl\s+)OFF$/) {
                    $tidyOptions = undef;
                    last;
                }
                if (/^perl\s*(.*)$/) {
                    $tidyOptions = $1;
                    last;
                }
            }
            last;
        }
    }

    # Update cache for the entire paths
    for my $path (@pathList) {
        $tidyOption{$path} = $tidyOptions;
    }

    return $tidyOption{$file} = $tidyOptions;
}

my @files =
  map { $_->[1] }
  grep { $_->[0] !~ /^D/ && defined getTidyOptions( $_->[1] ) }
  map { chomp; [ split( /\s+/, $_, 2 ) ] } `$SVNLOOK changed $rev $REPOS`;

foreach my $file (@files) {
    check_perltidy($file);
}

sub check_perltidy {
    my $file = shift;

    my @input = `$SVNLOOK cat $rev $REPOS $file`;
    fail "$?: $SVNLOOK cat $rev $REPOS $file;\n" . join( "\n", @input )
      if $?;

    # Function should get it from the cache anyway
    my $tidyOptions = getTidyOptions($file);
    my @tidyed;
    perltidy(
        source      => \@input,
        destination => \@tidyed,
        argv        => $tidyOptions,
    );
    my $diff = diff( \@input, \@tidyed );
    fail("$file is not tidy; cannot check in:\n$diff") if $diff;
}

exit 0;
