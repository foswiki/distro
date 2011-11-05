#!/usr/bin/perl
# POST-COMMIT HOOK
#
#   [1] REPOS-PATH   (the path to this repository)
#   [2] REV          (the number of the revision just committed)
#   [3] TEST         (disable write,  and enables verbose)
#
# Must be chdired to the tools subdirectory when this is run
#
use strict;
use warnings;

my $REPOS   = $ARGV[0];
my $BUGS    = '/home/foswiki.org/public_html/data/Tasks';
my $SUPPORT = '/home/svn';

our $verbose = 0;    # 1 to debug

my $last = $ARGV[1] || `/usr/local/bin/svnlook youngest $REPOS`;
chomp($last);
print STDERR "LAST $last from $ARGV[1]\n" if $verbose;

#my $BRANCH = $ARGV[2]; # Not used

my $test = $ARGV[2] || 0;
if ($test) {
    $verbose = 1;
    print "Running as TEST - No updates\n";
}

my $first = 0;
if ( open( F, '<', "$SUPPORT/lastupdate" ) ) {
    local $/ = "\n";
    $first = <F>;
    chomp($first);
    close(F);
}

#die "NOT A TEST" unless $test;

die unless $last;

#die unless $BRANCH; ] Not used

if ( $first >= $last ) {
    $first = $last - 1;
}

print "F:$first L:$last\n" if $verbose;
my @changes;
for ( my $i = $first + 1 ; $i <= $last ; $i++ ) {
    push(
        @changes,

        # No filter since change to /trunk/
        #          map { s/^.*?$BRANCH\///; $_ }
        #           grep { /branches\/$BRANCH/ }
        split( /\n/, `/usr/local/bin/svnlook changed -r $i $REPOS` )
    );
}
print scalar(@changes), " changes\n" if $verbose;
exit 0 unless scalar(@changes);

sub _add {
    my ( $cur, $rev, $changed, $commits ) = @_;
    print STDERR "_add called with cur $cur rev $rev\n" if $verbose;
    my %curr = map { $_ => 1 } grep { /^\d+$/ }
      map { s/^(TWikirev|Nextwikirev|Foswikirev|Rev)://i; $_ }
      split( /\s+/, $cur );
    $curr{$rev} = 1;
    @$commits = sort { $a <=> $b } keys %curr;    # numeric sort
    my $new = join( " ", map { "Foswikirev:$_" } @$commits );
    $$changed = 1 if $cur ne $new;
    print STDERR "cur $cur,\n new $new\n" if $verbose;
    return $new;
}

# _addBr - add a branch for the current checkin into the list of branches with checkins
sub _addBr {
    my ( $cur, $br, $changed, $brCkRef ) = @_;
    print STDERR "_addBr called with cur $cur,  Br $br\n" if $verbose;

    # Split the current branches with checkins into a hash
    my %curr = map { $_ => 1 }
      split( /\s+/, $cur );

    # And set the current item branch into the hash
    $curr{$br} = 1;
    $brCkRef->{$br} = (1);

    # Sort into a list of branches and collapse
    my @list = sort keys %curr;
    my $new = join( " ", @list );

    if ( $cur ne $new ) {
        $$changed = 1;
    }
    print STDERR "cur $cur,\n  new $new\n" if $verbose;
    return $new;
}

# _getBr - organize the checkins list into a hash, keyed by branch.
sub _getBr {
    my ( $commits, $currRef ) = @_;
    foreach my $commit (@$commits) {
        push( @{ $currRef->{ _readBr($commit) } }, $commit );
    }
    my $new = join( " ", sort keys %$currRef );
    print STDERR "BANCHES branches $new\n" if $verbose;
    return $new;
}

# _readBr - read the branch for a checkin
sub _readBr {
    my $commit = shift;
    my $branch = 'unknown';
    my $dirs   = `/usr/local/bin/svnlook dirs-changed -r $commit $REPOS`;
    if ( $dirs =~ m/^trunk/ ) {
        $branch = 'trunk';
    }
    else {
        if ( $dirs =~ m#^branches/(.*?)/# ) {
            $branch = $1;
        }
    }
    print "Returning $branch for $commit\n" if $verbose;
    return $branch;
}

# Don't know where STDERR goes, so send it somewhere we can read it
unless ($test) {
    open( STDERR, '>>', "$SUPPORT/logs/post-commit.log" ) || die $!;
}
print STDERR "Post-Commit $first..$last in $REPOS\n" if $verbose;
$/ = undef;

for my $rev ( ( $first + 1 ) .. $last ) {

    # Update the list of checkins for referenced bugs
    my $logmsg    = `/usr/local/bin/svnlook log -r $rev $REPOS`;
    my $committer = `/usr/local/bin/svnlook author -r $rev $REPOS`;

    #SMELL: Can't use chomp - $/ is undef
    $committer =~ s/\n$//;

    my $branch = _readBr($rev);
    print STDERR "BRANCH $branch\n" if $verbose;

    my @list;
    while ( $logmsg =~ s/\b(Item\d+)\s*:// ) {
        push( @list, $1 );
    }

    foreach my $item (@list) {
        my $fi      = "$BUGS/$item.txt";
        my $changed = 0;

        # Extract the last revision of the item
        my $lastrev = 1;
        if ( -e "$BUGS/$item.txt,v" ) {
            my $rlog = `rlog -h $BUGS/$item.txt`;
            ($lastrev) = $rlog =~ m/^head: 1\.(\d+).*?$/ms;
            print STDERR "LAST REVISION $lastrev of $item \n" if $verbose;
        }
        $lastrev++;

        open( F, '<', $fi ) || next;
        my $text = <F>;
        close(F);

        my @commits = ();
        print STDERR "Updating Checkins for $rev\n" if $verbose;
        unless ( $text =~
s/^(%META:FIELD.*name="Checkins".*value=")(.*?)(".*%)$/$1._add($2, $rev, \$changed, \@commits).$3/gem
          )
        {
            $text .= "\n" unless $text =~ /\n$/s;
            $text .=
"%META:FIELD{name=\"Checkins\" attributes=\"\" title=\"Checkins\" value=\"Foswikirev:$rev\"}%\n";
            $changed = 1;
        }

        my %brCommits;
        print STDERR "Updating CheckinsOnBranches for $branch\n" if $verbose;
        unless ( $text =~
s/^(%META:FIELD.*name="CheckinsOnBranches".*value=")(.*?)(".*%)$/$1._addBr($2, $branch, \$changed, \%brCommits ).$3/gem
          )
        {

# The CheckinsOnBranches doesn't exist.  Need to recover the list of branches by processing all
# prior commits.  This code builds a hash array.  Key is the branch, and the value is the list of commits
# For the branch.  it will be used to populate the <branch>Checkins metadata.

            $text .= "\n" unless $text =~ /\n$/s;
            print STDERR "Writing new CheckinsOnBranches for $branch\n"
              if $verbose;
            $text .=
"%META:FIELD{name=\"CheckinsOnBranches\" attributes=\"\" title=\"CheckinsOnBranches\" value=\""
              . _getBr( \@commits, \%brCommits )
              . "\"}%\n";
            $changed = 1;

            # Build the <branch>Checkins
            foreach my $key ( sort keys %brCommits ) {
                my $new =
                  join( " ", map { "Foswikirev:$_" } @{ $brCommits{$key} } );

                $text .= "\n" unless $text =~ /\n$/s;
                print STDERR "Writing new ${key} Checkins for $new\n"
                  if $verbose;
                unless ( $text =~
s/^(%META:FIELD.*?name="${key}Checkins".*value=")(.*?)(".*%)$/$1.$new.$3/gem
                  )
                {
                    $text .=
"%META:FIELD{name=\"${key}Checkins\" attributes=\"\" title=\"${key}Checkins\" value=\""
                      . $new
                      . "\"}%\n";
                }
            }
        }
        else {

# The CheckinsOnBranches exists,  so only have to add the current commit and branch to the metadata
            print STDERR "Updating (${branch})Checkins for $rev\n" if $verbose;
            unless ( $text =~
s/^(%META:FIELD.*?name="${branch}Checkins".*value=")(.*?)(".*}%)$/$1._add($2, $rev, \$changed, \@commits ).$3/gem
              )
            {

                # First commit to a new branch
                print STDERR "Writing new  ${branch}Checkins for $rev\n"
                  if $verbose;
                $text .=
"%META:FIELD{name=\"${branch}Checkins\" attributes=\"\" title=\"${branch}Checkins\" value=\"Foswikirev:$rev\"}%\n";
                $changed = 1;
            }
        }

        next unless $changed;

        # Update the TOPICINFO
        $text =~
          s/^(%META:TOPICINFO{.*?author=")(?:[^"]*)(".*?}%)$/$1$committer$2/m;
        $text =~
          s/^(%META:TOPICINFO{.*?version=")(?:[^"]*)(".*?}%)$/$1$lastrev$2/m;
        $text =~
          s/^(%META:TOPICINFO{.*?comment=")(?:[^"]*)(".*?}%)$/$1svn commit$2/m;
        my $timestamp = time();
        $text =~
          s/^(%META:TOPICINFO{.*?date=")(?:[^"]*)(".*?}%)$/$1$timestamp$2/m;
        print STDERR
"CHANGED: Updated TOPICINFO with author $committer rev $lastrev timestamp $timestamp\n"
          if $verbose;

        unless ($test) {
            print STDERR `co -l -f $fi`;
            die $! if $?;
            open( F, '>', $fi ) || die "Failed to write $fi: $!";
            print F $text;
            close(F);
            print STDERR `ci -mauto -u $fi`;
            die $! if $?;

            # 777 in case subversion user is not Apache user
            chmod( 0777, $fi );
        }
        else {
            print STDERR "\n>>>\n$text\n>>>\n";
        }

        print STDERR "Updated $item with $rev\n";
    }
}

unless ($test) {

    # Create the flag that tells the cron job to update from the repository
    open( F, '>>', "$SUPPORT/svncommit" )
      || die "Failed to write $SUPPORT/svncommit: $!";
    print F join( " ", @changes );
    close(F);

    # Create the flag for this script
    open( F, '>', "$SUPPORT/lastupdate" ) || die $!;
    print F "$last\n";
    close(F);
}

close(STDERR);
