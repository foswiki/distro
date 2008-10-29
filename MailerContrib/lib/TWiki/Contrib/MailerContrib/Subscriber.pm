# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 1999-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

use strict;

=pod

---+ package TWiki::Contrib::MailerContrib::Subscriber
Object that represents a subscriber to notification. A subscriber is
a name (which may be a wikiName or an email address) and a list of
subscriptions which describe the topis subscribed to, and
unsubscriptions representing topics they are specifically not
interested in. The subscriber
name may also be a group, so it may expand to many email addresses.

=cut

package TWiki::Contrib::MailerContrib::Subscriber;

use TWiki;
use TWiki::Plugins;
use Assert;

require TWiki::Contrib::MailerContrib::WebNotify;

=pod

---++ new($name)
   * =$name= - Wikiname, with no web, or email address, of user targeted for notification
Create a new user.

=cut

sub new {
    my ( $class, $name ) = @_;
    my $this = bless( { name => $name }, $class );

    return $this;
}

=pod

---++ getEmailAddresses() -> \@list
Get a list of email addresses for the user(s) represented by this
subscription

=cut

sub getEmailAddresses {
    my $this = shift;

    unless ( defined( $this->{emails} )) {
        $this->{emails} = getEmailAddressesForUser( $this->{name});
    }
    return $this->{emails};
}

=pod

---++ STATIC getEmailAddressesForUser() -> \@list
Get a list of email addresses for the user(s) represented by this
subscription. Static method provided for use by other modules.

=cut

sub getEmailAddressesForUser {
    my $name = shift;
    my $emails = [];

    return $emails unless $name;

    if ( $name =~ /^$TWiki::cfg{MailerContrib}{EmailFilterIn}$/ ) {
        push( @{$emails}, $name );
    } else {
        my $users = $TWiki::Plugins::SESSION->{users};
        if ($users->can('findUserByWikiName')) {
            # User is represented by a wikiname. Map to a canonical
            # userid.
            my $list = $users->findUserByWikiName($name);
            foreach my $user (@$list) {
                # Automatically expands groups
                push( @{$emails}, $users->getEmails($user) );
            }
        } else {
            # Old code; use the user object
            my $user = $users->findUser( $name, undef, 1 );
            if( $user ) {
                push( @{$emails}, $user->emails() );
            } else {
                $user = $users->findUser(
                    $name, $name, 1 );
                if( $user ) {
                    push( @{$emails}, $user->emails() );
                } else {
                    # unknown - can't find an email
                    $emails = [];
                }
            }
        }
    }
    return $emails;
}

# Add a subscription to an internal list, optimising the list so that
# the fewest subscriptions are kept that are needed to cover all
# topics.
sub _addAndOptimise {
    my( $this, $set, $new ) = @_;

    # Don't add already covered duplicates
    my $i = 0;
    my @remove;
    foreach my $known (@{$this->{$set}}) {
        return if $known->covers($new);
        if( $new->covers( $known )) {
            # remove anything covered by the new subscription
            unshift(@remove, $i);
        }
        $i++;
    }
    foreach $i (@remove) {
        splice(@{$this->{$set}}, $i, 1);
    }
    push( @{$this->{$set}}, $new );
}

# Subtract a subscription from an internal list. Do the best job
# you can in the face of wildcards.
sub _subtract {
    my( $this, $set, $new ) = @_;

    my $i = 0;
    my @remove;
    foreach my $known (@{$this->{$set}}) {
        if( $new->covers( $known )) {
            # remove anything covered by the new subscription
            unshift(@remove, $i);
        }
        $i++;
    }
    foreach $i (@remove) {
        splice(@{$this->{$set}}, $i, 1);
    }
}

=pod

---++ subscribe($subs)
   * =$subs= - Subscription object
Add a new subscription to this subscriber object.

=cut

sub subscribe {
    my ( $this, $subs ) = @_;

    $this->_addAndOptimise( 'subscriptions', $subs );
    $this->_subtract( 'unsubscriptions', $subs );
}

=pod

---++ unsubscribe($subs)
   * =$subs= - Subscription object
Add a new unsubscription to this subscriber object.
The unsubscription will always be added, even if there is
a wildcard overlap with an existing subscription or unsubscription.

An unsubscription is a statement of the subscribers desire _not_
to be notified of changes to this topic.

=cut

sub unsubscribe {
    my ( $this, $subs ) = @_;

    $this->_addAndOptimise( 'unsubscriptions', $subs );
    if ($subs->matches('*')) {
        # -* makes no sense and causes evaluation problems.
        $this->_subtract( 'unsubscriptions', $subs );
    }
    $this->_subtract( 'subscriptions', $subs );
    #TODO: should look at removing redundant exclusions ie a - SubScribe (2) when there is no positive subscription
    
    #if there are no subscriptions, there is no point luging around the unsubs
    if (scalar(@{$this->{'subscriptions'}}) == 0) {
        undef @{$this->{'unsubscriptions'}};
    }
}

=pod

---++ isSubscribedTo($topic, $db) -> $subscription
   * =$topic= - Topic object we are checking
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parents
Check if we have a subscription to the given topic. Return the subscription
that matches if we do, undef otherwise.

=cut

sub isSubscribedTo {
   my ( $this, $topic, $db ) = @_;

   foreach my $subscription ( @{$this->{subscriptions}} ) {
       if ( $subscription->matches( $topic, $db )) {
           return $subscription;
       }
   }

   return undef;
}

=pod

---++ isUnsubscribedFrom($topic) -> $subscription
   * =$topic= - Topic object we are checking
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parents
Check if we have an unsubscription from the given topic. Return the subscription that matches if we do, undef otherwise.

=cut

sub isUnsubscribedFrom {
   my ( $this, $topic, $db ) = @_;

   foreach my $subscription ( @{$this->{unsubscriptions}} ) {
       if ( $subscription->matches( $topic, $db )) {
           return $subscription;
       }
   }

   return undef;
}

=pod

---++ stringify() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub stringify {
    my $this = shift;
    my $subs = join( ' ',
                     map { $_->stringify(); }
                     @{$this->{subscriptions}} );
    my $unsubs = join( " - ",
                       map { $_->stringify(); }
                       @{$this->{unsubscriptions}} );
    $unsubs = " - $unsubs" if $unsubs;

    my $name = $this->{name};
    if ($name !~ /^($TWiki::regex{wikiWordRegex}|$TWiki::cfg{MailerContrib}{EmailFilterIn})$/) {
        $name = $name =~ /'/ ? '"'.$name.'"' : "'$name'";
    }
    return "   * " . $name . ": " .
      $subs . $unsubs;
}

1;
