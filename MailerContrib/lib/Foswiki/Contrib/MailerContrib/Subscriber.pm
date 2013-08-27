# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::MailerContrib::Subscriber
Object that represents a subscriber to notification. A subscriber is
a name (which may be a wikiName or an email address) and a list of
subscriptions which describe the topis subscribed to, and
unsubscriptions representing topics they are specifically not
interested in. The subscriber
name may also be a group, so it may expand to many email addresses.

=cut

package Foswiki::Contrib::MailerContrib::Subscriber;

use strict;
use warnings;
use Assert;

use Foswiki                                    ();
use Foswiki::Plugins                           ();
use Foswiki::Contrib::MailerContrib::WebNotify ();

=begin TML

---++ ClassMethod new($name)
   * =$name= - Wikiname, with no web, or email address, of user targeted for notification
Create a new user.

=cut

sub new {
    my ( $class, $name ) = @_;
    my $this = bless(
        {
            name => $name,

            # emails => [],
            # subscriptions => [],
            # unsubscriptions => [],
        },
        $class
    );
    return $this;
}

=begin TML

---++ ObjectMethod getEmailAddresses() -> \@list
Get a list of email addresses for the user(s) represented by this
subscription

=cut

sub getEmailAddresses {
    my $this = shift;

    unless ( defined( $this->{emails} ) ) {
        $this->{emails} = getEmailAddressesForUser( $this->{name} );
    }
    return $this->{emails};
}

=begin TML

---++ STATIC getEmailAddressesForUser() -> \@list
Get a list of email addresses for the user(s) represented by this
subscription. Static method provided for use by other modules.

=cut

sub getEmailAddressesForUser {
    my $name   = shift;
    my $emails = [];

    return $emails unless $name;

    if ( $name =~ /^$Foswiki::cfg{MailerContrib}{EmailFilterIn}$/ ) {
        push( @{$emails}, $name );
    }
    else {
        my $users = $Foswiki::Plugins::SESSION->{users};
        if ( $users->can('findUserByWikiName') ) {

            # User is represented by a wikiname. Map to a canonical
            # userid.
            my $list = $users->findUserByWikiName($name);
            foreach my $user (@$list) {

                # Automatically expands groups
                push( @{$emails}, $users->getEmails($user) );
            }
        }
        else {

            # Old code; use the user object
            my $user = $users->findUser( $name, undef, 1 );
            if ($user) {
                push( @{$emails}, $user->emails() );
            }
            else {
                $user = $users->findUser( $name, $name, 1 );
                if ($user) {
                    push( @{$emails}, $user->emails() );
                }
                else {

                    # unknown - can't find an email
                    $emails = [];
                }
            }
        }
    }
    return $emails;
}

=begin TML

---++ ObjectMethod optimise()
Optimise the lists of subscriptions and unsubscriptions by finding
overlaps and eliminating them. Intended to be used before writing
a new WebNotify.

=cut

# O(N^2)
# Call before writing.
sub optimise {
    my $this = shift;

    foreach my $set ( 'subscriptions', 'unsubscriptions' ) {
        my @new_set = ();

      NEW:
        foreach my $new ( @{ $this->{$set} } ) {

            # Don't add already covered duplicates
            my $i = 0;
            my @remove;
            foreach my $known (@new_set) {
                next NEW if $known->covers($new);
                if ( $new->covers($known) ) {

                    # remove anything covered by the new subscription
                    unshift( @remove, $i );
                }
                $i++;
            }
            foreach $i (@remove) {
                splice( @new_set, $i, 1 );
            }
            push( @new_set, $new );
        }

        # TODO: should look at removing redundant exclusions e.g.
        # -SubScribe (2) when there is no positive subscription
        # if there are no subscriptions, there is no point lugging
        # around the unsubs
        $this->{$set} = \@new_set;
    }
}

# Subtract a subscription from an internal list. If the removal expression
# removes one or more existing expressions by exact matching, then return
# true otherwise return false. Thus:
#   * removing 'This*' from 'This* ThisThat' will remove 'This*' and
#     'ThisThat' and return true.
#   * removing '*That' will remove 'ThisThat' and return false.
#   * removing 'T*' will remove 'This*' and 'ThisThat' and return false.
sub _subtract {
    my ( $this, $set, $dead ) = @_;

    my $i = 0;
    my @remove;
    my $removed;

    #print "Subtract ".$dead->stringify()." from ".$this->stringify()."\n";
    foreach my $known ( @{ $this->{$set} } ) {
        $removed = $known->filterExact( $dead->{topics} );
        if ( $dead->covers($known) ) {

          #print "DEAD ".$dead->stringify()." COVERS ".$known->stringify()."\n";
          # remove anything covered by the dead subscription
            unshift( @remove, $i );
        }
        $i++;
    }
    foreach $i (@remove) {
        splice( @{ $this->{$set} }, $i, 1 );
    }
    return $removed;
}

=begin TML

---++ ObjectMethod subscribe($subs)
   * =$subs= - Subscription object
Add a new subscription to this subscriber object. no optimisation is performed; if
the subscription is already there, or is covered by another subscription, then it
will still be added.

=cut

sub subscribe {
    my ( $this, $subs ) = @_;

    push( @{ $this->{subscriptions} }, $subs );

 #$this->_subtract( 'unsubscriptions', $subs ); disabled for performance reasons
}

=begin TML

---++ ObjectMethod unsubscribe($subs)
   * =$subs= - Subscription object
Add a new unsubscription to this subscriber object.
The unsubscription will always be added, even if there is
a wildcard overlap with an existing subscription or unsubscription.

An unsubscription is a statement of the subscribers desire _not_
to be notified of changes to this topic.

=cut

sub unsubscribe {
    my ( $this, $subs ) = @_;

    # If there was no exact match in the removal, then push a -
    if (
        !$this->_subtract( 'subscriptions', $subs )

        # - * causes evaluation problems.
        && !$subs->matches('*')
      )
    {
        push( @{ $this->{unsubscriptions} }, $subs );
    }
}

=begin TML

---++ isSubscribedTo($topic, $db) -> $subscription
   * =$topic= - Topic object we are checking
   * =$db= - Foswiki::Contrib::MailerContrib::UpData database of parents
Check if we have a subscription to the given topic. Return the subscription
that matches if we do, undef otherwise.

=cut

sub isSubscribedTo {
    my ( $this, $topic, $db ) = @_;

    foreach my $subscription ( @{ $this->{subscriptions} } ) {
        if ( $subscription->matches( $topic, $db ) ) {
            return $subscription;
        }
    }

    return;
}

=begin TML

---++ ObjectMethod isUnsubscribedFrom($topic) -> $subscription
   * =$topic= - Topic object we are checking
   * =$db= - Foswiki::Contrib::MailerContrib::UpData database of parents
Check if we have an unsubscription from the given topic. Return the subscription that matches if we do, undef otherwise.

=cut

sub isUnsubscribedFrom {
    my ( $this, $topic, $db ) = @_;

    foreach my $subscription ( @{ $this->{unsubscriptions} } ) {
        if ( $subscription->matches( $topic, $db ) ) {
            return $subscription;
        }
    }

    return;
}

=begin TML

---++ ObjectMethod stringify() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub stringify {
    my $this = shift;
    my $subs =
      join( ' ', map { $_->stringify(); } @{ $this->{subscriptions} } );
    my $unsubs =
      join( " - ", map { $_->stringify(); } @{ $this->{unsubscriptions} } );
    $unsubs = " - $unsubs" if $unsubs;

    my $name = $this->{name};
    if ( $name =~ /^$Foswiki::regex{wikiWordRegex}$/ ) {
        $name = '%USERSWEB%.' . $name;
    }
    elsif ( $name !~ /^$Foswiki::cfg{MailerContrib}{EmailFilterIn}$/ ) {
        $name = $name =~ /'/ ? '"' . $name . '"' : "'$name'";
    }
    return "   * " . $name . ": " . $subs . $unsubs;
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
