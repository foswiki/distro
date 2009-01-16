#!/usr/bin/perl
# Count "real code" lines in TWiki core perl modules
# $where must be set to the root of your twiki installation

use FindBin;
my $where = $ARGV[0] || "$FindBin::Bin/../..";

my $pms = `find $where/lib -name '*.pm' -print | grep -v '/test/' | grep -v '/Plugins/' | grep -v 'Upgrade' | grep -v '/Contrib/' | grep -v /Algorithm/ | grep -v Error.pm`;

foreach my $script qw( attach changes configure edit geturl login logon manage oops passwd preview rdiff register rename resetpasswd rest save search statistics upload view viewfile ) {
    $pms .= " $where/bin/$script";
}

foreach $i (split( /\s+/, $pms)) {
    open($in, $i) or next;

    $collect = 'code';
    $module{code} = 0;
    $module{comment} = 0;
    while (<$in>) {
        my $thisline = 1;
        if (/^=(begin|pod)/) {
            $collect = 'comment';
            next;
        } elsif (/^=cut/) {
            $collect = 'code';
            next;
        } elsif (/^\s*#/) {
            $module{comment}++;
            next;
        } elsif (/^\s*[{}];?\s*$/) {
            next;
        } elsif (/^\s*$/) {
            next;
        }
        $module{comment}++ if( $collect ne 'comment' && $thisline =~ /#/ );
        $module{$collect}++;
    }
    close($in);
    #print "$i $module\n";
    $lines += $module{code};
    $comments += $module{comment};
}
print "code $lines pod $comments\n";
