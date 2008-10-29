#!/usr/bin/perl
# POST-COMMIT HOOK
#
#   [1] REPOS-PATH   (the path to this repository)
#   [2] REV          (the number of the revision just committed)
#
# Must be chdired to the tools subdirectory when this is run
#
use strict;

my $REPOS = $ARGV[0];
my $first = `cat $ENV{HOME}/lastupdate`;
chomp($first);
my $last = $ARGV[1] || `/usr/bin/svnlook youngest $REPOS`;
chomp($last);
#my $BRANCH = $ARGV[2]; # Not used

die unless $last;
#die unless $BRANCH; ] Not used

$first ||= ($last-1);

my @changes;
for (my $i = $first + 1; $i <= $last; $i++) {
    push( @changes,
# No filter since change to /trunk/
#          map { s/^.*?$BRANCH\///; $_ }
#           grep { /twiki\/branches\/$BRANCH/ }
            split(/\n/, `/usr/bin/svnlook changed -r $i $REPOS` ));
}
exit 0 unless scalar( @changes );

sub _add {
    my( $cur, $rev, $changed ) = @_;
    my %curr = map { $_ => 1 } grep { /^\d+$/ }
      map { s/^(TWikirev:|Rev:)//i; $_ } split(/\s+/, $cur);
    $curr{$rev} = 1;
    my @list = sort { $a <=> $b } keys %curr; # numeric sort
    my $new = join(" ", map { "TWikirev:$_" } @list);
    $$changed = 1 if $cur ne $new;
    return $new;
}

# Don't know where STDERR goes, so send it somewhere we can read it
open(STDERR, ">>$ENV{HOME}/logs/post-commit.log") || die $!;
print STDERR "Post-Commit $first..$last in $REPOS\n";
$/ = undef;

for my $rev ($first..$last) {
    # Update the list of checkins for referenced bugs
    my $logmsg = `/usr/bin/svnlook log -r $rev $REPOS`;

    my @list;
    while( $logmsg =~ s/\b(Item\d+):// ) {
        push(@list, $1);
    }

    foreach my $item (@list) {
        my $fi = "data/Bugs/$item.txt";
        my $changed = 0;

        open(F, "<$fi") || next;
        my $text = <F>;
        close(F);

        unless( $text =~ s/^(%META:FIELD.*name="Checkins".*value=")(.*?)(".*%)$/$1._add($2, $rev, \$changed).$3/gem ) {
            $text .= "\n" unless $text =~ /\n$/s;
            $text .= "%META:FIELD{name=\"Checkins\" attributes=\"\" title=\"Checkins\" value=\"TWikirev:$rev\"}%\n";
            $changed = 1;
        }

        next unless $changed;

        print STDERR `co -l -f $fi`;
        die $! if $?;
        open(F, ">$fi") || die "Failed to write $fi: $!";
        print F $text;
        close(F);
        print STDERR `ci -mauto -u $fi`;
        die $! if $?;

        # 777 in case subversion user is not Apache user
        chmod(0777, $fi);

        print STDERR "Updated $item with $rev\n";
    }
}

# Create the flag that tells the cron job to update from the repository
open(F, ">>$ENV{HOME}/svncommit") || die "Failed to write $ENV{HOME}/svncommit: $!";
print F join(" ", @changes);
close(F);

# Create the flag for this script
open(F, ">$ENV{HOME}/lastupdate") || die $!;
print F "$last\n";
close(F);

close(STDERR);
