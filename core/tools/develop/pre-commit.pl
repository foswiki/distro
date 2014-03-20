#!/usr/bin/perl
use strict;
use warnings;

# Pick up BuildContrib version of Perl::Tidy
use lib '/home/trunk.foswiki.org/BuildContrib/lib';
use lib '/home/trunk.foswiki.org/core/lib';
use Perl::Tidy;
use Text::Diff;
use File::Spec;
use Foswiki::Attrs;

# PRE-COMMIT HOOK for Foswiki Subversion
#
# The pre-commit hook tests that the item(s) listed in the checkin
# exist(s) in Tasks web, and is(are) in a state to receive checkins.
#
# STDERR ends up on the users' terminal

# Defaults are test settings - pass test as the first parameter to
# test a specific checkin. Works off-server as well, e.g.
# perl pre-commit.pl test -m "Item12806: eat lead sucker" pre-commit.pl
# so long as PERL5LIB contains BuildContrib/lib and core/lib

my $REPOS   = '';
my $logmsg  = '';
my $dataDir = '../../data';
my $rev     = '';
my $SVNLOOK = 'svn';
my $changed = 'status';
my @status  = ();
my $testing = 1;

if ( $ARGV[0] eq 'test' ) {
    shift @ARGV;
    while ( my $a = shift @ARGV ) {
        if ( $a eq '-m' ) {
            $logmsg = shift @ARGV;
        }
        else {
            eval 'require Cwd';
            $a = Cwd::abs_path($a);
            push( @status, "M $a\n" );
        }
    }
}
else {
    $REPOS = $ARGV[0];
    my $TXN = $ARGV[1];
    $dataDir = "/home/foswiki.org/public_html/data";
    $rev     = "-t $TXN";
    $SVNLOOK = '/usr/local/bin/svnlook';
    $logmsg  = `$SVNLOOK log $rev $REPOS`;
    $changed = 'changed';
    @status  = `$SVNLOOK $changed $rev $REPOS`;
    $testing = 0;
}

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
Rules - files being checked in must:
1. Have a comment...
2. ...with relevant ItemNNN task topics in the first line, e.g.

Item12345: Item12346: fixed foo, updated release notes

3. Refer to ItemNNN task topics which are open at the time of
   checkin, i.e. *not* one of: Closed, Waiting For Release,
   No Action or Proposal Required

4. .pl and .pm files must be "tidied" if the TIDY control file
   in the root of the extension calls for it, see:
   http://foswiki.org/Development/TIDY

5. .txt files in web directories must have META:TOPICINFO with
   the author "ProjectContributor", a version of 1 and a date
   within three days of the checkin.

Getting rejected commits with perltidy? We are checking using
version $Perl::Tidy::VERSION
See http://foswiki.org/Development/PerlTidy#Versions
--------------------------------------------------------------
EOF
    exit 1;
}

# Get a being-checked-in file. For testing, we look at the dir. For
# real checkin, we look at SVN.
sub getFile {
    my ( $file, $rev ) = @_;
    my @f;

    if ($testing) {
        fail("Could not open $file") unless open( F, '<', $file );
        local $/ = undef;
        @f = map { "$_\n" } split( /\n/, <F> );
        close(F);
    }
    else {
        @f = `$SVNLOOK cat $rev $REPOS $file 2>/dev/null`;
    }
    return @f;
}

# Verify that code is cleanly formatted, but only for files which were not
# removed, and end in .pm or .pl, and are not CPAN libraries
my %tidyOption;

# Returns undef when file should be skipped,
# otherwise returns perltidy options to be used (can be empty for defaults)
sub getTidyOptions {
    my $file = shift;

    # .pm, .pl and .txt files
    if ( $file =~ /\.p[ml]$/ ) {

        # Not CPAN modules
        return undef if $file =~ m#/lib/CPAN/lib/#;
    }
    elsif ( $file !~ m#/data/.*\.txt$# ) {

        # Not .txt in a web
        return undef;
    }
    return $tidyOption{$file} if exists $tidyOption{$file};

    # Defaults to skip
    my $tidyOptions = undef;
    my ( $volume, $directory ) = File::Spec->splitpath($file);
    my @pathList;    # Save examined hierarchy to update cache
    my @path = File::Spec->splitdir($directory);
    while ( defined pop @path ) {
        my $path = File::Spec->catdir(@path);
        $tidyOptions = $tidyOption{$path} and last if exists $tidyOption{$path};
        push @pathList, $path;    # To update cache hierachy
        my $tidyFile = File::Spec->catpath( $volume, $path, 'TIDY' );
        my @tidyOptions = `$SVNLOOK cat $rev $REPOS $file 2>/dev/null`;
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

# Return error message if TOPICINFO is bad per the rules.
sub checkTOPICINFO {
    my $ti = shift;
    return 'no TOPICINFO' unless ( $ti =~ /^%META:TOPICINFO{(.*)}%$/ );
    my $attrs = new Foswiki::Attrs($1);
    my $auth = $attrs->{author} || 'unknown user';
    return "wrong author '$auth', must be 'ProjectContributor'"
      unless ( $auth eq 'ProjectContributor' );
    my $date = $attrs->{date} || 0;
    my $t = time;
    return "bad date $date, must be within 3 days of $t"
      unless $date =~ /^\d+$/
      && abs( $t - $date ) < 3 * 24 * 60 * 60;
    my $ver = $attrs->{version} || 0;
    return "bad version $ver, must be 1" unless $attrs->{version} eq '1';
    return undef;
}

sub check {
    my $file = shift;

    my @input = getFile($file);
    fail "$?: $SVNLOOK cat $rev $REPOS $file;\n" . join( "\n", @input )
      if $?;

    # Function should get it from the cache anyway
    my $tidyOptions = getTidyOptions($file);
    my @tidyed;
    my $err;
    if ( $file =~ /\.txt$/ ) {
        my $err = checkTOPICINFO( $input[0] );
        fail("$file TOPICINFO is inconsistent; cannot check in: $err")
          if $err;
    }
    else {
        perltidy(
            source      => \@input,
            destination => \@tidyed,
            argv        => $tidyOptions,
        );
        my $diff = diff( \@input, \@tidyed );
        fail("$file is not tidy; cannot check in:\n$diff") if $diff;
    }
}

fail("No Task Item in log message") unless ( $logmsg =~ /\bItem\d+\s*:/ );

my @items;
$logmsg =~ s/\b(Item\d+)\s*:/push(@items, $1); '';/gem;
foreach my $item (@items) {
    fail "Task $item does not exist"
      unless ( -f "$dataDir/Tasks/$item.txt" );
    open( my $file, '<', "$dataDir/Tasks/$item.txt" )
      || die "Cannot open $item";
    my $text = do { local $/; <$file> };
    my $state = "Closed";
    if ( $text =~ /^%META:FIELD{name="CurrentState".*value="(.*?)"/m ) {
        $state = $1;
    }
    close($file);
    if ( $state =~
        /^(Waiting for Release|Closed|No Action Required|Proposal Required)$/ )
    {
        fail("$item is in $state state; cannot check in");
    }
}

my @files =
  map { $_->[1] }
  grep { $_->[0] !~ /^D/ && defined getTidyOptions( $_->[1] ) }
  map { chomp; [ split( /\s+/, $_, 2 ) ] } @status;

foreach my $file (@files) {
    check($file);
}

exit 0;
