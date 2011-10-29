#!/usr/bin/perl
# POST-COMMIT HOOK
#
#   [1] REPOS-PATH   (the path to this repository)
#   [2] REV          (the number of the revision just committed)
#
# Must be chdired to the tools subdirectory when this is run
#
use strict;
use warnings;

my $REPOS   = $ARGV[0];
my $BUGS    = '/home/foswiki.org/public_html/data/Tasks';
my $SUPPORT = '/home/svn';

my $verbose = 1;    # 1 to debug

my $first = 1;
if ( open( F, '<', "$SUPPORT/lastupdate" ) ) {
    local $/ = "\n";
    $first = <F>;
    chomp($first);
    close(F);
}
my $last = $ARGV[1] || `/usr/local/bin/svnlook youngest $REPOS`;
chomp($last);

#my $BRANCH = $ARGV[2]; # Not used

die unless $last;

#die unless $BRANCH; ] Not used

$first ||= ( $last - 1 );

#print "F:$first L:$last\n" if $verbose;
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
#print scalar(@changes), " changes\n" if $verbose;
exit 0 unless scalar(@changes);

sub _add {
    my ( $cur, $rev, $changed ) = @_;
    my %curr = map { $_ => 1 } grep { /^\d+$/ }
      map { s/^(TWikirev|Nextwikirev|Foswikirev|Rev)://i; $_ }
      split( /\s+/, $cur );
    $curr{$rev} = 1;
    my @list = sort { $a <=> $b } keys %curr;    # numeric sort
    my $new = join( " ", map { "Foswikirev:$_" } @list );
    $$changed = 1 if $cur ne $new;
    print STDERR "cur $cur,  new $new\n" if $verbose;
    return $new;
}

# Don't know where STDERR goes, so send it somewhere we can read it
open( STDERR, '>>', "$SUPPORT/logs/post-commit.log" ) || die $!;
print STDERR "Post-Commit $first..$last in $REPOS\n";
$/ = undef;

for my $rev ( $first .. $last ) {

    # Update the list of checkins for referenced bugs
    my $logmsg    = `/usr/local/bin/svnlook log -r $rev $REPOS`;
    my $committer = `/usr/local/bin/svnlook author -r $rev $REPOS`;

    #SMELL: Can't use chomp - $/ is undef
    $committer =~ s/\n$//;

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
            print STDERR "LAST REVISION $lastrev of Item$item \n" if $verbose;
        }
        $lastrev++;

        open( F, '<', $fi ) || next;
        my $text = <F>;
        close(F);

        # Update the TOPICINFO
        $text =~ s/^(%META:TOPICINFO{.*?author=")(?:[^"]*)(".*?}%)$/$1$committer$2/m;
        $text =~ s/^(%META:TOPICINFO{.*?version=")(?:[^"]*)(".*?}%)$/$1$lastrev$2/m;
        $text =~ s/^(%META:TOPICINFO{.*?comment=")(?:[^"]*)(".*?}%)$/$1svn commit$2/m;
        my $timestamp = time();
        $text =~ s/^(%META:TOPICINFO{.*?date=")(?:[^"]*)(".*?}%)$/$1$timestamp$2/m;
        print STDERR "Updated TOPICINFO with author $committer rev $lastrev timestamp $timestamp\n" if $verbose;

        unless ( $text =~
s/^(%META:FIELD.*name="Checkins".*value=")(.*?)(".*%)$/$1._add($2, $rev, \$changed).$3/gem
          )
        {
            $text .= "\n" unless $text =~ /\n$/s;
            $text .=
"%META:FIELD{name=\"Checkins\" attributes=\"\" title=\"Checkins\" value=\"Foswikirev:$rev\"}%\n";
            $changed = 1;
        }

        next unless $changed;

        print STDERR `co -l -f $fi`;
        die $! if $?;
        open( F, '>', $fi ) || die "Failed to write $fi: $!";
        print F $text;
        close(F);
        print STDERR `ci -mauto -u $fi`;
        die $! if $?;

        # 777 in case subversion user is not Apache user
        chmod( 0777, $fi );

        print STDERR "Updated $item with $rev\n";
    }
}

# Create the flag that tells the cron job to update from the repository
open( F, '>>', "$SUPPORT/svncommit" )
  || die "Failed to write $SUPPORT/svncommit: $!";
print F join( " ", @changes );
close(F);

# Create the flag for this script
open( F, '>', "$SUPPORT/lastupdate" ) || die $!;
print F "$last\n";
close(F);

close(STDERR);
