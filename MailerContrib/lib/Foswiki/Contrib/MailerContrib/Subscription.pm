# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::MailerContrib::Subscription
Object that represents a subscription to notification on a set of pages.
A subscription is expressed as a set of page specs (each of which may
contain wildcards) and a depth of children of matching pages that the
user is subscribed to.

=cut

package Foswiki::Contrib::MailerContrib::Subscription;

use strict;
use warnings;
use Assert;

# Always mail out this subscription, even if there have been no changes
use constant ALWAYS => 1;

# Always mail out the full topic, not just the changes
use constant FULL_TOPIC => 2;

# in the page spec these correspond as follows:
# ? = FULL_TOPIC
# ! = FULL_TOPIC | ALWAYS

=begin TML

---++ ClassMethod new($pages, $childDepth, $options)
   * =$pages= - Wildcarded expression matching subscribed pages.
   * =$childDepth= - Depth of children of $topic to notify changes
     for. Defaults to 0
   * =$options= - bitmask of Foswiki::Contrib::MailerContrib::Subscription options
Create a new subscription.

=cut

sub new {
    my ( $class, $topics, $depth, $opts ) = @_;

    ASSERT( defined($opts) && $opts =~ /^\d*$/ ) if DEBUG;

    my $tre = $topics;
    $tre =~ s/ +/|/g;         # space means alternate
    $tre =~ s/\*/\.\*\?/g;    # convert wildcards to perl RE syntax
    my $this = bless(
        {
            topics => [ split( /\s+/, $topics ) ],
            depth   => $depth || 0,
            options => $opts  || 0,
            topicsRE => qr/^(?:$tre)$/
        },
        $class
    );
    return $this;
}

=begin TML

---++ stringify() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub stringify {
    my $this   = shift;
    my $record = join(
        ' ',
        map {

            # Protect single and double quotes in topic names
            ( $_ =~ /'/ ) ? "\"$_\"" : ( ( $_ =~ /"/ ) ? "'$_'" : $_ );
        } @{ $this->{topics} }
    );
    $record .= $this->getMode();
    $record .= " ($this->{depth})" if ( $this->{depth} );
    return $record;
}

=begin TML

---++ ObjectMethod matches($topic, $db, $depth) -> boolean
   * =$topic= - Topic names we are checking (may be an array ref)
   * =$db= - Foswiki::Contrib::MailerContrib::UpData database of parent names
   * =$depth= - If non-zero, check if the parent of the given topic matches as well. undef = 0.
Check if we match this topic. Recurses up the parenthood tree seeing if
this is a child of a parent that matches within the depth range.

TODO: '*' should match alot of things..

=cut

sub matches {
    my ( $this, $topics, $db, $depth ) = @_;

    return 0 unless ($topics);

    unless ( ref $topics ) {
        $topics = [$topics];
    }

    foreach my $topic (@$topics) {
        return 1 if ( $topic =~ $this->{topicsRE} );

        $depth = $this->{depth} unless defined($depth);
        $depth ||= 0;

        if ( $depth && $db ) {
            my $parent = $db->getParent($topic);
            $parent =~ s/^.*\.//;
            return $this->matches( $parent, $db, $depth - 1 ) if ($parent);
        }
    }

    return 0;
}

=begin TML

---++ ObjectMethod covers($other, $db) -> $boolean
   * =$other= - Other subscription object we are checking
   * =$db= - Foswiki::Contrib::MailerContrib::UpData database of parent names
Return true if this subscription already covers all the topics
specified by another subscription. Thus:
   * A&#2A;B _covers_ AB, AxB
   * A&#2A; _covers_ A&#2A;B
   * &#2A;B _does not cover_ A&#2A;

=cut

sub covers {
    my ( $this, $tother, $db ) = @_;

    # Does the mode cover the other subscription?
    # ALWAYS covers (ALWAYS and not ALWAYS).
    # FULL_TOPIC covers (FULL_TOPIC and not FULL_TOPIC)
    return 0
      unless ( $this->{options} & $tother->{options} ) == $tother->{options};

    # A * always covers if the options match
    foreach my $t ( @{ $this->{topics} } ) {
        return 1 if ( $t eq '*' );
    }

    # do they match without taking into account the depth?
    return 0 unless ( $this->matches( $tother->{topics}, undef, 0 ) );

    # if we have a depth and they don't, that's already catered for
    # by the matches test above

    # if we don't have a depth and they do, then we might be covered
    # by them, but that's irrelevant

    # if we have a depth and they have a depth, then there is coverage
    # if our depth is >= their depth
    return 0 unless ( $this->{depth} >= $tother->{depth} );

    return 1;
}

=begin TML

---++ ObjectMethod filterExact( \@pages ) -> $boolean
If this subscription has an exact (string) match to any of the page expressions passed,
remove it and return true.
    * \@pages - list of page expressions to filter

=cut

sub filterExact {
    my ( $this, $pages ) = @_;
    my $removed = 0;
  KNOWN:
    for ( my $i = $#{ $this->{topics} } ; $i >= 0 ; $i-- ) {
        foreach my $j ( @{$pages} ) {
            if ( $j eq $this->{topics}[$i] ) {
                splice( @{ $this->{topics} }, $i, 1 );
                $removed = 1;
                next KNOWN;
            }
        }
    }
    return $removed;
}

=begin TML

---++ ObjectMethod getMode() -> $mode
Get the newsletter mode of this subscription ('', '?' or '!') as
specified in WebNotify.

=cut

sub getMode {
    my $this = shift;

    if ( $this->{options} & FULL_TOPIC ) {
        return '!'
          if ( $this->{options} & ALWAYS );
        return '?';
    }
    return '';
}

sub _sameTopics {
    my ( $a, $b ) = @_;
    my @aa = sort @$a;
    my @bb = sort @$b;
    my $i  = scalar(@aa);
    return 0 unless scalar(@bb) == $i;
    while ($i) {
        $i--;
        return 0 unless $aa[$i] eq $bb[$i];
    }
    return 1;
}

=begin TML

---++ ObjectMethod equals($other) -> $boolean
Compare two subscriptions.

=cut

sub equals {
    my ( $this, $tother ) = @_;
    return 0 unless ( $this->{options} eq $tother->{options} );
    return 0 unless ( $this->{depth} == $tother->{depth} );
    return 0 unless ( _sameTopics( $this->{topics}, $tother->{topics} ) );
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2006 TWiki Contributors.
Copyright (C) 2004 Wind River Systems Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
