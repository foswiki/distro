# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Merge

Support for merging strings

=cut

package Foswiki::Merge;

use strict;
use warnings;
use Assert;

use CGI ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod merge2( $arev, $a, $brev, $b, $sep, $session, $info )

   * =$arev= - rev for $a (string)
   * =$a= - first ('original') string
   * =$brev= - rev for $b (string)
   * =$b= - second ('new') string
   * =$sep= = separator, string RE e.g. '.*?\n' for lines
   * =$session= - Foswiki object
   * =$info= - data block passed to plugins merge handler. Conventionally this will identify the source of the text being merged (the source form field, or undef for the body text)

Perform a merge of two versions of the same text, using
HTML tags to mark conflicts.

The granularity of the merge depends on the setting of $sep.
For example, if it is ="\\n"=, a line-by-line merge will be done.

Where conflicts exist, they are marked using HTML &lt;del> and
&lt;ins> tags. &lt;del> marks content from $a while &lt;ins>
marks content from $b.

Non-conflicting content (insertions from either set) are not
marked.

The plugins =mergeHandler= is called for each merge.

Call it like this:
<verbatim>
$newText = Foswiki::Merge::merge2(
   $oldrev, $old, $newrev, $new, '.*?\n', $session, $info );
</verbatim>

=cut

sub merge2 {
    my ( $va, $ia, $vb, $ib, $sep, $session, $info ) = @_;

    my @a = split( /($sep)/, $ia );
    my @b = split( /($sep)/, $ib );

    ASSERT( $session && $session->isa('Foswiki') ) if DEBUG;

    my @out;
    require Algorithm::Diff;
    Algorithm::Diff::traverse_balanced(
        \@a,
        \@b,
        {
            MATCH     => \&_acceptA,
            DISCARD_A => \&_acceptA,
            DISCARD_B => \&_acceptB,
            CHANGE    => \&_change
        },
        undef,
        \@out,
        \@a,
        \@b,
        $session, $info
    );
    return join( '', @out );
}

sub _acceptA {
    my ( $a, $b, $out, $ai, $bi, $session, $info ) = @_;

    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    #print STDERR "From A: '$ai->[$a]'\n";
    # accept text from the old version without asking for resolution
    my $merged =
      $session->{plugins}
      ->dispatch( 'mergeHandler', ' ', $ai->[$a], undef, $info );
    if ( defined $merged ) {
        push( @$out, $merged );
    }
    else {
        push( @$out, $ai->[$a] );
    }
}

sub _acceptB {
    my ( $a, $b, $out, $ai, $bi, $session, $info ) = @_;

    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    #print STDERR "From B: '$bi->[$b]'\n";
    my $merged =
      $session->{plugins}
      ->dispatch( 'mergeHandler', ' ', $bi->[$b], undef, $info );
    if ( defined $merged ) {
        push( @$out, $merged );
    }
    else {
        push( @$out, $bi->[$b] );
    }
}

sub _change {
    my ( $a, $b, $out, $ai, $bi, $session, $info ) = @_;
    my $merged;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    # Diff isn't terribly smart sometimes; it will generate changes
    # with a or b empty, which I would have thought should have
    # been accepts.
    if ( $ai->[$a] =~ m/\S/ ) {

        # there is some non-white text to delete
        if ( $bi->[$b] =~ m/\S/ ) {

            # this insert is replacing something with something
            $merged =
              $session->{plugins}
              ->dispatch( 'mergeHandler', 'c', $ai->[$a], $bi->[$b], $info );
            if ( defined $merged ) {
                push( @$out, $merged );
            }
            else {
                push( @$out, CGI::del( {}, $ai->[$a] ) );
                push( @$out, CGI::ins( {}, $bi->[$b] ) );
            }
        }
        else {
            $merged =
              $session->{plugins}
              ->dispatch( 'mergeHandler', '-', $ai->[$a], $bi->[$b], $info );
            if ( defined $merged ) {
                push( @$out, $merged );
            }
            else {
                push( @$out, CGI::del( {}, $ai->[$a] ) );
            }
        }
    }
    elsif ( $bi->[$b] =~ m/\S/ ) {

        # inserting new
        $merged =
          $session->{plugins}
          ->dispatch( 'mergeHandler', '+', $ai->[$a], $bi->[$b], $info );

        #print STDERR "From B: '$bi->[$b]'\n";
        if ( defined $merged ) {
            push( @$out, $merged );
        }
        else {
            push( @$out, $bi->[$b] );
        }
    }
    else {

        # otherwise this insert is not replacing anything
        #print STDERR "From B: '$bi->[$b]'\n";
        $merged =
          $session->{plugins}
          ->dispatch( 'mergeHandler', ' ', $ai->[$a], $bi->[$b], $info );
        if ( defined $merged ) {
            push( @$out, $merged );
        }
        else {
            push( @$out, $bi->[$b] );
        }
    }
}

=begin TML

---++ StaticMethod simpleMerge( $a, $b, $sep ) -> \@arr

Perform a merge of two versions of the same text, returning
an array of strings representing the blocks in the merged context
where each string starts with one of "+", "-" or " " depending on
whether it is an insertion, a deletion, or just text. Insertions
and deletions alway happen in pairs, as text taken in from either
version that does not replace text in the other version will simply
be accepted.

The granularity of the merge depends on the setting of $sep.
For example, if it is ="\\n"=, a line-by-line merge will be done.
$sep characters are retained in the outout.

=cut

sub simpleMerge {
    my ( $ia, $ib, $sep ) = @_;

    my @a = split( /($sep)/, $ia );
    my @b = split( /($sep)/, $ib );

    #print "\n====\nMerge DUMP A \n";
    #foreach my $l ( @a ) {
    #    print "$l";
    #    }
    #print "\n====\nMerge DUMP B \n";
    #foreach my $l ( @b ) {
    #    print "$l";
    #    }

    my $out = [];
    require Algorithm::Diff;
    Algorithm::Diff::traverse_balanced(
        \@a,
        \@b,
        {
            MATCH     => \&_sAcceptA,
            DISCARD_A => \&_sDiscardA,
            DISCARD_B => \&_sDiscardB,
            CHANGE    => \&_sChange
        },
        undef, $out,
        \@a,
        \@b
    );
    return $out;
}

sub _sAcceptA {
    my ( $a, $b, $out, $ai, $bi ) = @_;

    #print "DIFF AcceptA ($ai->[$a]) ($bi->[$b]) \n";
    push( @$out, ' ' . $ai->[$a] );
}

sub _sDiscardA {
    my ( $a, $b, $out, $ai, $bi ) = @_;

    #print "DIFF DiscardA ($ai->[$a]) ($bi->[$b]) \n";
    push( @$out, '-' . $ai->[$a] );
}

sub _sDiscardB {
    my ( $a, $b, $out, $ai, $bi ) = @_;

    #print "DIFF DiscardB ($ai->[$a]) ($bi->[$b]) \n";
    push( @$out, '+' . $bi->[$b] ) unless $bi->[$b] eq "\n";
}

sub _sChange {
    my ( $a, $b, $out, $ai, $bi ) = @_;
    my $simpleInsert = 0;

    #print "DIFF Change ($ai->[$a]) ($bi->[$b]) \n";
    if ( $ai->[$a] =~ m/\S/ ) {

        # there is some non-white text to delete
        push( @$out, '-' . $ai->[$a] );
    }
    else {

        # otherwise this insert is not replacing anything
        $simpleInsert = 1;
    }

    if ( !$simpleInsert && $bi->[$b] =~ m/\S/ ) {

        # this insert is replacing something with something
        push( @$out, '+' . $bi->[$b] );
    }
    else {

        # otherwise it is replacing nothing, or is whitespace or null
        push( @$out, ' ' . $bi->[$b] );
    }
}

sub _equal {
    my ( $a, $b ) = @_;
    return 1 if ( !defined($a) && !defined($b) );
    return 0 if ( !defined($a) || !defined($b) );
    return $a eq $b;
}

=begin TML

---++ StaticMethod merge3( $arev, $a, $brev, $b, $crev, $c, $sep,
                          $session, $info )

   * =$arev= - rev for common ancestor (id e.g. ver no)
   * =$a= - common ancestor
   * =$brev= - rev no for first derivative string (id)
   * =$b= - first derivative string
   * =$crev= - rev no for second derivative string (id)
   * =$c= - second derivative string
   * =$sep= = separator, string RE e.g. '.*?\n' for lines
   * =$session= - Foswiki object
   * =$info= - data block passed to plugins merge handler. Conventionally this will identify the source of the text being merged (the source form field, or undef for the body text)

Perform a merge of two versions (b and c) of the same text, using
HTML &lt;div> tags to mark conflicts. a is the common ancestor.

The granularity of the merge depends on the setting of $sep.
For example, if it is =".*?\\n"=, a line-by-line merge will be done.

Where conflicts exist, they are labeled using the provided revision
numbers.

The plugins =mergeHandler= is called for each merge.

Here's a little picture of a 3-way merge:

      a   <- ancestor
     / \
    b   c <- revisions
     \ /
      d   <- merged result, returned.

call it like this:
<verbatim>
    my ( $ancestorMeta, $ancestorText ) =
        $store->readTopic( undef, $webName, $topic, $originalrev );
    $newText = Foswiki::Merge::merge3(
        $ancestorText, $prevText, $newText,
        $originalrev, $rev, "new",
        '.*?\n' );
</verbatim>

=cut

sub merge3 {
    my ( $arev, $ia, $brev, $ib, $crev, $ic, $sep, $session, $info ) = @_;

    $sep = "\r?\n" if ( !defined($sep) );

    my @a = split( /(.+?$sep)/, $ia );
    my @b = split( /(.+?$sep)/, $ib );
    my @c = split( /(.+?$sep)/, $ic );
    require Algorithm::Diff;
    my @bdiffs = Algorithm::Diff::sdiff( \@a, \@b );
    my @cdiffs = Algorithm::Diff::sdiff( \@a, \@c );

    my $ai   = 0;                 # index into a
    my $bdi  = 0;                 # index into bdiffs
    my $cdi  = 0;                 # index into bdiffs
    my $na   = scalar(@a);
    my $nbd  = scalar(@bdiffs);
    my $ncd  = scalar(@cdiffs);
    my $done = 0;
    my ( @achunk, @bchunk, @cchunk );
    my @diffs;                    # (a, b, c)

    # diffs are of the form [ [ modifier, b_elem, c_elem ] ... ]
    # where modifiers is one of:
    #   '+': element (b or c) added
    #   '-': element (from a) removed
    #   'u': element unmodified
    #   'c': element changed (a to b/c)

    # first, collate the diffs.

    while ( !$done ) {
        my $bop = ( $bdi < $nbd ) ? $bdiffs[$bdi][0] : 'x';
        if ( $bop eq '+' ) {
            push @bchunk, $bdiffs[ $bdi++ ][2];
            next;
        }
        my $cop = ( $cdi < $ncd ) ? $cdiffs[$cdi][0] : 'x';
        if ( $cop eq '+' ) {
            push @cchunk, $cdiffs[ $cdi++ ][2];
            next;
        }
        while ( scalar(@bchunk) || scalar(@cchunk) ) {
            push @diffs, [ shift @achunk, shift @bchunk, shift @cchunk ];
        }
        if ( scalar(@achunk) ) {
            @achunk = ();
        }
        last if ( $bop eq 'x' || $cop eq 'x' );

        # now that we've dealt with '+' and 'x', the only remaining
        # operations are '-', 'u', and 'c', which all consume an
        # element of a, so we should increment them together.
        my $aline = $bdiffs[$bdi][1];
        my $bline = $bdiffs[$bdi][2];
        my $cline = $cdiffs[$cdi][2];
        push @diffs, [ $aline, $bline, $cline ];
        $bdi++;
        $cdi++;
    }

    # at this point, both lists should be consumed, unless theres a bug in
    # Algorithm::Diff. We'll consume whatevers left if necessary though.

    while ( $bdi < $nbd ) {
        push @diffs, [ $bdiffs[$bdi][1], undef, $bdiffs[$bdi][2] ];
        $bdi++;
    }
    while ( $cdi < $ncd ) {
        push @diffs, [ $cdiffs[$cdi][1], undef, $cdiffs[$cdi][2] ];
        $cdi++;
    }

    my ( @aconf, @bconf, @cconf, @merged );
    my $conflict = 0;
    my @out;
    my ( $aline, $bline, $cline );

    for my $diff (@diffs) {
        ( $aline, $bline, $cline ) = @$diff;
        my $ab = _equal( $aline, $bline );
        my $ac = _equal( $aline, $cline );
        my $bc = _equal( $bline, $cline );
        my $dline = undef;

        if ($bc) {

            # same change (or no change) in b and c
            $dline = $bline;
        }
        elsif ($ab) {

            # line did not change in b
            $dline = $cline;
        }
        elsif ($ac) {

            # line did not change in c
            $dline = $bline;
        }
        else {

            # line changed in both b and c
            $conflict = 1;
        }

        if ($conflict) {

            # store up conflicting lines until we get a non-conflicting
            push @aconf, $aline;
            push @bconf, $bline;
            push @cconf, $cline;
        }

        if ( defined($dline) ) {

            # we have a non-conflicting line
            if ($conflict) {

                # flush any pending conflict if there is enough
                # context (at least 3 lines)
                push( @merged, $dline );
                if ( @merged > 3 ) {
                    for my $i ( 0 .. $#merged ) {
                        pop @aconf;
                        pop @bconf;
                        pop @cconf;
                    }
                    _handleConflict(
                        \@out, \@aconf, \@bconf, \@cconf,  $arev,
                        $brev, $crev,   $sep,    $session, $info
                    );
                    $conflict = 0;
                    push @out, @merged;
                    @merged = ();
                }
            }
            else {

                # the line is non-conflicting
                my $merged =
                  $session->{plugins}
                  ->dispatch( 'mergeHandler', ' ', $dline, $dline, $info );
                if ( defined $merged ) {
                    push( @out, $merged );
                }
                else {
                    push( @out, $dline );
                }
            }
        }
        elsif (@merged) {
            @merged = ();
        }
    }

    if ($conflict) {
        for my $i ( 0 .. $#merged ) {
            pop @aconf;
            pop @bconf;
            pop @cconf;
        }

        _handleConflict(
            \@out, \@aconf, \@bconf, \@cconf,  $arev,
            $brev, $crev,   $sep,    $session, $info
        );
    }
    push @out, @merged;
    @merged = ();

    #foreach ( @out ) { print STDERR (defined($_) ? $_ : "undefined") . "\n"; }

    return join( '', @out );
}

my $conflictAttrs = { class => 'foswikiConflict' };

# SMELL: internationalisation?
my $conflictB = CGI::b( {}, 'CONFLICT' );

sub _handleConflict {
    my (
        $out,  $aconf, $bconf, $cconf,   $arev,
        $brev, $crev,  $sep,   $session, $info
    ) = @_;
    my ( @a, @b, @c );

    @a = grep( $_, @$aconf );
    @b = grep( $_, @$bconf );
    @c = grep( $_, @$cconf );
    my $merged =
      $session->{plugins}
      ->dispatch( 'mergeHandler', 'c', join( '', @b ), join( '', @c ), $info );
    if ( defined $merged ) {
        push( @$out, $merged );
    }
    else {
        if (@a) {
            push( @$out,
                CGI::div( $conflictAttrs, "$conflictB original $arev:" )
                  . "\n" );
            push( @$out, @a );
        }
        if (@b) {
            push( @$out,
                CGI::div( $conflictAttrs,, "$conflictB version $brev:" )
                  . "\n" );
            push( @$out, @b );
        }
        if (@c) {
            push( @$out,
                CGI::div( $conflictAttrs,, "$conflictB version $crev:" )
                  . "\n" );
            push( @$out, @c );
        }
        push( @$out, CGI::div( $conflictAttrs,, "$conflictB end" ) . "\n" );
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2004-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
