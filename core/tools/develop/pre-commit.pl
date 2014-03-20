#!/usr/bin/perl
use strict;
use warnings;

use Text::Diff;
use File::Spec;

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

my $WINDOW_DAYS = 3;                             # window for date in %META
my $WINDOW      = $WINDOW_DAYS * 24 * 60 * 60;
my $REPOS       = '';
my $logmsg      = '';
my $dataDir;
my $rev     = '';
my $SVNLOOK = 'svn';
my $changed = 'status';
my @status  = ();
my $testing = 1;

if ( $ARGV[0] eq 'test' ) {
    eval 'use Cwd';
    die $@ if $@;
    my @lib = File::Spec->splitdir( Cwd::abs_path($0) );
    pop(@lib);
    pop(@lib);
    pop(@lib);
    eval "use lib '" . join( '/', @lib, 'lib' ) . "'";
    $dataDir = join( '/', @lib, 'data' );
    shift @ARGV;

    while ( $a = shift @ARGV ) {
        if ( $a eq '-m' ) {
            $logmsg = shift @ARGV;
        }
        else {
            $a = Cwd::abs_path($a);
            push( @status, "M $a\n" );
        }
    }
}
else {
    eval "use lib '/home/trunk.foswiki.org/BuildContrib/lib'";
    eval "use lib '/home/trunk.foswiki.org/core/lib'";
    $dataDir = "/home/foswiki.org/public_html/data";
    $SVNLOOK = '/usr/local/bin/svnlook';

    $REPOS = $ARGV[0];
    my $TXN = $ARGV[1];
    $rev     = "-t $TXN";
    $logmsg  = `$SVNLOOK log $rev $REPOS`;
    $changed = 'changed';
    @status  = `$SVNLOOK $changed $rev $REPOS`;
    $testing = 0;
}

# Pick up BuildContrib version of Perl::Tidy
eval 'use Perl::Tidy';
die $@ if $@;
eval 'use Foswiki::Attrs';
die $@ if $@;

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
   within $WINDOW_DAYS days of the checkin. Any FILEATTACHMENTs must
   has the "ProjectContributor" author, a version of 1 and a date
   with $WINDOW_DAYS days of the checkin.

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
    my ( $ti, $err ) = @_;
    unless ( $ti =~ /^%META:TOPICINFO{(.*)}%$/ ) {
        push( @$err, 'No TOPICINFO' );
        return;
    }
    my $attrs = new Foswiki::Attrs($1);
    my $auth = $attrs->{author} || 'unknown user';
    push( @$err,
        "TOPICINFO: wrong author '$auth', must be 'ProjectContributor'" )
      unless ( $auth eq 'ProjectContributor' );
    my $date = $attrs->{date} || 0;
    my $t = time;
    push( @$err, "TOPICINFO: date must be within $WINDOW seconds of $t" )
      unless $date =~ /^\d+$/
      && abs( $t - $date ) < $WINDOW;
    my $ver = $attrs->{version} || 0;
    push( @$err, "TOPICINFO: version must be 1" )
      unless $attrs->{version} eq '1';
}

sub checkFILEATTACHMENT {
    my ( $lines, $err ) = @_;
    foreach my $meta (@$lines) {
        if ( $meta =~ /^%META:FILEATTACHMENT{(.*)}%/ ) {
            my $attrs = new Foswiki::Attrs($1);
            my $name = $attrs->{name} || '';
            if ($name) {
                $name = " '$name'";
            }
            else {
                push( @$err, "FILEATTACHMENT has no name" );
            }
            my $auth = $attrs->{user} || 'unknown user';
            push( @$err,
"FILEATTACHMENT$name wrong user '$auth', must be 'ProjectContributor'"
            ) unless ( $auth eq 'ProjectContributor' );
            my $date = $attrs->{date} || 0;
            my $t = time;
            push( @$err, "date must be within $WINDOW seconds of $t" )
              unless $date =~ /^\d+$/
              && abs( $t - $date ) < $WINDOW;
            my $ver = $attrs->{version} || 0;
            push( @$err, "version must be 1" )
              unless $attrs->{version} eq '1';
        }
    }
    return $err;
}

sub check {
    my ( $file, $rev ) = @_;

    my @input = getFile( $file, $rev );
    fail "$?: $SVNLOOK cat $rev $REPOS $file;\n" . join( "\n", @input )
      if $?;

    # Function should get it from the cache anyway
    my $tidyOptions = getTidyOptions($file);
    my @tidyed;
    my $err;
    if ( $file =~ /\.txt$/ ) {
        my @err;
        checkTOPICINFO( $input[0], \@err ),
          checkFILEATTACHMENT( \@input, \@err );
        fail(   "$file meta-data is incorrect; cannot check in:\n"
              . join( "\n", @err )
              . "\n" )
          if scalar(@err);
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
    check( $file, $rev );
}

exit 0;
