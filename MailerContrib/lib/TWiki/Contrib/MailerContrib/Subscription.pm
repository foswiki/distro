# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 1999-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
#
# As per the GPL, removal of this notice is prohibited.

use strict;

=pod

---+ package TWiki::Contrib::MailerContrib::Subscription
Object that represents a single subscription of a user to
notification on a page. A subscription is expressed as a page
spec (which may contain wildcards) and a depth of children of
matching pages that the user is subscribed to.

=cut

package TWiki::Contrib::MailerContrib::Subscription;

use Assert;

use TWiki::Contrib::MailerContrib::Constants;

=pod

---++ new($pages, $childDepth, $options)
   * =$pages= - Wildcarded expression matching subscribed pages
   * =$childDepth= - Depth of children of $topic to notify changes
     for. Defaults to 0
   * =$options= - bitmask of MailerConst options
Create a new subscription.

=cut

sub new {
    my ( $class, $topics, $depth, $opts ) = @_;

    ASSERT(defined($opts) && $opts =~ /^\d*$/) if DEBUG;

    my $this = bless( {}, $class );

    $this->{topics} = $topics || '';
    $this->{depth} = $depth || 0;
    $this->{options} = $opts || 0;

    $topics =~ s/[^\w\*]//g;
    $topics =~ s/\*/\.\*\?/g;
    $this->{topicsRE} = qr/^$topics$/;

    return $this;
}

=pod

---++ stringify() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub stringify {
    my $this = shift;
    my $record = $this->{topics};
    # convert RE back to wildcard
    $record =~ s/\.\*\?/\*/;
    $record .= $this->getMode();
    $record .= " ($this->{depth})" if ( $this->{depth} );
    return $record;
}

=pod

---++ matches($topic, $db, $depth) -> boolean
   * =$topic= - Topic object we are checking
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parent names
   * =$depth= - If non-zero, check if the parent of the given topic matches as well. undef = 0.
Check if we match this topic. Recurses up the parenthood tree seeing if
this is a child of a parent that matches within the depth range.

TODO: '*' should match alot of things..

=cut

sub matches {
    my ( $this, $topic, $db, $depth ) = @_;
    return 0 unless ($topic);

    return 1 if ( $topic =~ $this->{topicsRE} );

    $depth = $this->{depth} unless defined( $depth );
    $depth ||= 0;

    if ( $depth && $db) {
        my $parent = $db->getParent( $topic );
        $parent =~ s/^.*\.//;
        return $this->matches( $parent, $db, $depth - 1 ) if ( $parent );
    }

    return 0;
}

=pod

---++ covers($other, $db) -> $boolean
   * =$other= - Other subscription object we are checking
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parent names
Return true if this subscription already covers all the topics
specified by another subscription. Thus:
   * A&#2A;B _covers_ AB, AxB
   * A&#2A; _covers_ A&#2A;B
   * &#2A;B _does not cover_ A&#2A;

=cut

sub covers {
    my( $this, $tother, $db ) = @_;
    
    #* should win always.
    return 1 if ($this->{topics} eq '*');

    # Does the mode cover the other subscription?
    return 0 unless
      (($this->{options} & $tother->{options}) == $tother->{options});

    # do they match without taking into account the depth?
    return 0 unless( $this->matches($tother->{topics}, undef, 0) );

    # if we have a depth and they don't, that's already catered for
    # by the matches test above

    # if we don't have a depth and they do, then we might be covered
    # by them, but that's irrelevant

    # if we have a depth and they have a depth, then there is coverage
    # if our depth is >= their depth
    return 0 unless( $this->{depth} >= $tother->{depth} );

    return 1;
}

=pod

---++ getMode() -> $mode
Get the newsletter mode of this subscription ('', '?' or '!') as
specified in WebNotify.

=cut

sub getMode {
    my $this = shift;

    if ($this->{options} & $MailerConst::FULL_TOPIC) {
        return '!' if ($this->{options} & $MailerConst::ALWAYS);
        return '?';
    }
    return '';
}

=pod

---++ equals($other) -> $boolean
Compare two subscriptions.

=cut

sub equals {
    my( $this, $tother ) = @_;
    return 0 unless ($this->{options} eq $tother->{options});
    return 0 unless ($this->{depth} == $tother->{depth});
    return 0 unless ($this->{topics} eq $tother->{topics});
}

1;
