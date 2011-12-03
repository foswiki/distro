# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::MailerContrib::Subscription
Object that represents a single subscription of a user to
notification on a page. A subscription is expressed as a page
spec (which may contain wildcards) and a depth of children of
matching pages that the user is subscribed to.

=cut

package Foswiki::Contrib::MailerContrib::Subscription;

use strict;
use warnings;
use Assert;

# Always mail out this subscription, even if there have been no changes
use constant ALWAYS => 1;

# Always mail out the full topic, not just the changes
use constant FULL_TOPIC => 2;

# ? = FULL_TOPIC
# ! = FULL_TOPIC | ALWAYS

=begin TML

---++ new($pages, $childDepth, $options)
   * =$pages= - Wildcarded expression matching subscribed pages
   * =$childDepth= - Depth of children of $topic to notify changes
     for. Defaults to 0
   * =$options= - bitmask of Foswiki::Contrib::MailerContrib::Subscription options
Create a new subscription.

=cut

sub new {
    my ( $class, $topics, $depth, $opts ) = @_;

    ASSERT( defined($opts) && $opts =~ /^\d*$/ ) if DEBUG;

    my $this = bless( {}, $class );

    $this->{topics}  = $topics || '';
    $this->{depth}   = $depth  || 0;
    $this->{options} = $opts   || 0;

    $topics =~ s/[^\w\*]//g;
    $topics =~ s/\*/\.\*\?/g;
    $this->{topicsRE} = qr/^$topics$/;

    return $this;
}

=begin TML

---++ stringify() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub stringify {
    my $this   = shift;
    my $record = $this->{topics};

    # Protect non-alphanumerics in topic name
    if ( $record =~ /[^*\w.]/ ) {
        if ( $record =~ /'/ ) {
            $record = "\"$record\"";
        }
        else {
            $record = "'$record'";
        }
    }
    $record .= $this->getMode();
    $record .= " ($this->{depth})" if ( $this->{depth} );
    return $record;
}

=begin TML

---++ matches($topic, $db, $depth) -> boolean
   * =$topic= - Topic object we are checking
   * =$db= - Foswiki::Contrib::MailerContrib::UpData database of parent names
   * =$depth= - If non-zero, check if the parent of the given topic matches as well. undef = 0.
Check if we match this topic. Recurses up the parenthood tree seeing if
this is a child of a parent that matches within the depth range.

TODO: '*' should match alot of things..

=cut

sub matches {
    my ( $this, $topic, $db, $depth ) = @_;
    return 0 unless ($topic);

    return 1 if ( $topic =~ $this->{topicsRE} );

    $depth = $this->{depth} unless defined($depth);
    $depth ||= 0;

    if ( $depth && $db ) {
        my $parent = $db->getParent($topic);
        $parent =~ s/^.*\.//;
        return $this->matches( $parent, $db, $depth - 1 ) if ($parent);
    }

    return 0;
}

=begin TML

---++ covers($other, $db) -> $boolean
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
    return 1 if ( $this->{topics} eq '*' );

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

---++ getMode() -> $mode
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

=begin TML

---++ equals($other) -> $boolean
Compare two subscriptions.

=cut

sub equals {
    my ( $this, $tother ) = @_;
    return 0 unless ( $this->{options} eq $tother->{options} );
    return 0 unless ( $this->{depth} == $tother->{depth} );
    return 0 unless ( $this->{topics} eq $tother->{topics} );
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
