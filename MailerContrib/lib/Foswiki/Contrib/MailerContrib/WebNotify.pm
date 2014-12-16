# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::MailerContrib::WebNotify
Object that represents the contents of a %NOTIFYTOPIC% topic in a Foswiki web.

Note that =$Foswiki::Plugins::SESSION= is used to find the Foswiki session, and
must be set up before this class is used.

=cut

package Foswiki::Contrib::MailerContrib::WebNotify;

use strict;
use warnings;

use Assert;

use Foswiki::Func                                 ();
use Foswiki::Contrib::MailerContrib               ();
use Foswiki::Contrib::MailerContrib::Subscriber   ();
use Foswiki::Contrib::MailerContrib::Subscription ();

use constant TRACE => 0;

=begin TML

---++ ClassMethod new($web, $topic)
   * =$web= - web name
   * =$topic= - topic name
   * =$noexpandgroups= - True will prevent expansion of group subscriptions
     (False is best for checking subscriptions, but True is best for
     writing results back to $topic)
     
Create a new object by parsing the content of the given topic in the
given web. This is the normal way to load a %NOTIFYTOPIC% topic. If the
topic does not exist, it will create an empty object.

=cut

sub new {
    my ( $class, $web, $topic, $noexpandgroups ) = @_;

    my $this = bless( {}, $class );

    # Ensure the contrib is initialised
    Foswiki::Contrib::MailerContrib::initContrib();

    $this->{web}      = $web;
    $this->{topic}    = $topic || $Foswiki::cfg{NotifyTopicName} || 'WebNotify';
    $this->{pretext}  = '';
    $this->{posttext} = '';
    $this->{noexpandgroups} = $noexpandgroups;

    if ( Foswiki::Func::topicExists( $web, $topic ) ) {
        $this->_load();
    }

    return $this;
}

=begin TML

---++ ObjectMethod writeWebNotify()
Write the object to the %NOTIFYTOPIC% topic it was read from.
If there is a problem writing the topic (e.g. it is locked), or the
current user is not authorised to write it, then the method will
throw an exception.

=cut

sub writeWebNotify {
    my $this = shift;

    # First remove overlaps
    $this->_optimise();

    # Then chuck it out
    Foswiki::Func::saveTopic( $this->{web}, $this->{topic}, undef,
        $this->stringify(), { minor => 1 } );
}

=begin TML

---++ ObjectMethod getSubscriber($name, $noAdd)
   * =$name= - Name of subscriber (wikiname with no web or email address)
   * =$noAdd= - If false or undef, a new subscriber will be created for this name
Get a subscriber from the list of subscribers, and return a reference
to the Subscriber object. If $noAdd is true, and the subscriber is not
found, undef will be returned. Otherwise a new Subscriber object will
be added if necessary.

=cut

sub getSubscriber {
    my ( $this, $name, $noAdd ) = @_;

    my $subscriber = $this->{subscribers}{$name};
    unless ( $noAdd || defined($subscriber) ) {
        $subscriber = new Foswiki::Contrib::MailerContrib::Subscriber($name);
        $this->{subscribers}{$name} = $subscriber;
    }
    return $subscriber;
}

# Optimise the webnotify to remove overlaps in subscription lists
sub _optimise {
    my $this = shift;
    foreach my $subscriber ( values %{ $this->{subscribers} } ) {
        $subscriber->optimise();
    }
}

=begin TML

---++ ObjectMethod getSubscribers()
Get a list of all subscriber names (unsorted)

=cut

sub getSubscribers {
    my ($this) = @_;

    return keys %{ $this->{subscribers} };
}

=begin TML

---++ ObjectMethod subscribe($name, $topics, $depth, $options)
   * =$name= - Name of subscriber (wikiname with no web or email address)
   * =$topics= - wildcard expression giving topics to subscribe to
   * =$depth= - Child depth to scan (default 0)
   * =$options= - Bitmap of Mailer::Const options
Add a subscription, adding the subscriber if necessary.

=cut

sub subscribe {
    my ( $this, $name, $topics, $depth, $opts ) = @_;

    $opts ||= 0;

    my @names = ($name);
    unless ( $this->{noexpandgroups} ) {
        my $it = Foswiki::Func::eachGroupMember($name);
        if ($it) {
            @names = ();
            while ( $it->hasNext() ) {
                my $member = $it->next();
                push( @names, $member );
            }
        }
    }

    foreach my $n (@names) {
        my $subscriber = $this->getSubscriber($n);
        my $sub =
          new Foswiki::Contrib::MailerContrib::Subscription( $topics, $depth,
            $opts );
        $subscriber->subscribe($sub);
    }
}

=begin TML

---++ ObjectMethod unsubscribe($name, $topics, $depth)
   * =$name= - Name of subscriber (wikiname with no web or email address)
   * =$topics= - wildcard expression giving topics to subscribe to
   * =$depth= - Child depth to scan (default 0)
Add an unsubscription, adding the subscriber if necessary. An unsubscription
is a specific request to ignore notifications for a topic for this
particular subscriber.

=cut

sub unsubscribe {
    my ( $this, $name, $topics, $depth ) = @_;

    my @names = ($name);
    unless ( $this->{noexpandgroups} ) {
        my $it = Foswiki::Func::eachGroupMember($name);
        if ($it) {
            @names = ();
            while ( $it->hasNext() ) {
                my $member = $it->next();
                push( @names, $member );
            }
        }
    }

    foreach my $n (@names) {
        my $subscriber = $this->getSubscriber($n);
        my $sub =
          new Foswiki::Contrib::MailerContrib::Subscription( $topics, $depth,
            0 );
        $subscriber->unsubscribe($sub);
    }
}

=begin TML

---++ ObjectMethod stringify([$subscribersOnly]) -> string
Return a string representation of this object, in %NOTIFYTOPIC% format.

Optional =$subscribersOnly= parameter to only print the parsed subscription list.
Used when running a mailnotify, where printing out the entire WebNotify topic is confusing,
as it's different from the actual topic contents, but doesn't inform the user why.

=cut

sub stringify {
    my ( $this, $subscribersOnly ) = @_;

    my $page = '';

    $page .= $this->{pretext} if ( !$subscribersOnly );
    $page .= "---\n" if TRACE && $page !~ /---\n*$/;
    foreach my $name ( sort keys %{ $this->{subscribers} } ) {
        my $subscriber = $this->{subscribers}{$name};
        $page .= $subscriber->stringify() . "\n";
    }
    $page .= "---\n" if TRACE && $this->{posttext} !~ /^\n*---/;
    $page .= $this->{posttext} if ( !$subscribersOnly );

    return $page;
}

=begin TML

---++ ObjectMethod processChange($change, $db, $changeSet, $seenSet, $allSet)
   * =$change= - ref of a Foswiki::Contrib::Mailer::Change
   * =$db= - Foswiki::Contrib::MailerContrib::UpData database of parent references
   * =$changeSet= - ref of a hash mapping name&emails to sets of changes
   * =$seenSet= - ref of a hash recording indices of topics already seen for
                  each name&email addressee
   * =$allSet= - ref of a hash that maps topics to name&email ids for news subscriptions
Find all subscribers that are interested in the given change. Only the most
recent change to each topic listed in the .changes file is retained. This
method does _not_ change this object.

=cut

sub processChange {
    my ( $this, $change, $db, $changeSet, $seenSet, $allSet ) = @_;

    my $topic   = $change->{TOPIC};
    my $web     = $change->{WEB};
    my %authors = map { $_ => 1 } @{
        Foswiki::Contrib::MailerContrib::Subscriber::getEmailAddressesForUser(
            $change->{author}
        )
    };
    print STDERR "Process change to $web.$topic\n" if TRACE;

    foreach my $name ( keys %{ $this->{subscribers} } ) {
        my $subscriber = $this->{subscribers}{$name};
        my $subs = $subscriber->isSubscribedTo( $topic, $db );
        if ( $subs && !$subscriber->isUnsubscribedFrom( $topic, $db ) ) {

            # Check access to the old rev
            my $cuid = Foswiki::Func::getCanonicalUserID($name);

            # Check access is allowed to the most recent revision
            my $to =
              Foswiki::Meta->load( $Foswiki::Plugins::SESSION, $web, $topic,
                $change->{CURR_REV} );
            unless ( $to->haveAccess( 'VIEW', $cuid ) ) {
                print STDERR
"$name has no permission to view r$change->{CURR_REV} of $web.$topic\n"
                  if TRACE;
                next;
            }

            $to =
              Foswiki::Meta->load( $Foswiki::Plugins::SESSION, $web, $topic,
                $change->{BASE_REV} );
            unless ( $to->haveAccess( 'VIEW', $cuid ) ) {
                print STDERR
"$name has no permission to view r$change->{BASE_REV} of $web.$topic\n"
                  if TRACE;
                next;
            }

            print "$name will be notified of changes to $topic\n" if TRACE;
            my $emails = $subscriber->getEmailAddresses();
            if ( $emails && scalar(@$emails) ) {
                foreach my $email (@$emails) {
                    my $id = "$name&$email";

                    # Skip this change if the subscriber is the author
                    # of the change, and we are not always sending
                    next
                      if (
                        !(
                            $subs->{options} &
                            Foswiki::Contrib::MailerContrib::Subscription::ALWAYS
                        )
                        && $authors{$email}
                      );
                    print STDERR "\tusing email $email for $name\n" if TRACE;
                    if ( $subs->{options} &
                        Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC
                      )
                    {

                        #print "Add $id to allSet for $topic\n";
                        push( @{ $allSet->{$topic} }, $id );
                    }
                    else {
                        my $at = $seenSet->{$id}{$topic};
                        if ($at) {

                            #print "Merge $id to changeset for $topic\n";
                            $changeSet->{$id}[ $at - 1 ]->merge($change);
                        }
                        else {

                            #print "Add $id to changeset for $topic\n";
                            $seenSet->{$id}{$topic} =
                              push( @{ $changeSet->{$id} }, $change );
                        }
                    }
                }
            }
            else {
                $this->_emailWarn( $subscriber, $name, $web );
            }
        }
    }
}

=begin TML

---++ ObjectMethod processCompulsory($topic, $db, \%allSet)
   * =$topic= - topic name
   * =$db= - Foswiki::Contrib::MailerContrib::UpData database
     of parent references
   * =\%allSet= - ref of a hash that maps topics to name&email addresses
     for news subscriptions

=cut

sub processCompulsory {
    my ( $this, $topic, $db, $allSet ) = @_;

    foreach my $name ( keys %{ $this->{subscribers} } ) {
        my $subscriber = $this->{subscribers}{$name};
        my $subs = $subscriber->isSubscribedTo( $topic, $db );
        next unless $subs;
        next
          unless ( $subs->{options} &
            Foswiki::Contrib::MailerContrib::Subscription::ALWAYS );
        unless ( $subscriber->isUnsubscribedFrom( $topic, $db ) ) {
            my $emails = $subscriber->getEmailAddresses();
            if ($emails) {
                foreach my $address (@$emails) {
                    push( @{ $allSet->{$topic} }, "$name&$address" );
                }
            }
        }
    }
}

=begin TML

---++ ObjectMethod isEmpty() -> boolean
Return true if there are no subscribers

=cut

sub isEmpty {
    my $this = shift;
    return ( scalar( keys %{ $this->{subscribers} } ) == 0 );
}

# PRIVATE parse a webnotify topic extracting formatted lines
sub _load {
    my $this = shift;

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{web}, $this->{topic} );
    my $in_pre = 1;
    $this->{pretext}  = '';
    $this->{posttext} = '';
    $this->{meta}     = $meta;

    # join \ terminated lines
    $text =~ s/\\\r?\n//gs;
    my $webRE    = qr/(?:$Foswiki::cfg{UsersWebName}\.)?/;
    my $legacyRE = qr{
                    ^\s+\*\s$webRE
                    ($Foswiki::regex{wikiWordRegex})
                    \s+-\s+
                    ($Foswiki::cfg{MailerContrib}{EmailFilterIn}+)
                    \s*$
                   }x;
    my $stdRE = qr{^\s+\*\s$webRE
                       (
                           $Foswiki::regex{wikiWordRegex}
                           | '.*?'
                           | ".*?"
                           | $Foswiki::cfg{MailerContrib}{EmailFilterIn}
                       )
                       \s*(:.*)?$
                  }x;
    foreach my $baseline ( split( /\r?\n/, $text ) ) {
        my $line =
          Foswiki::Func::expandCommonVariables( $baseline, $this->{topic},
            $this->{web}, $meta );
        if (   $line =~ /$legacyRE/
            && $1 ne $Foswiki::cfg{DefaultUserWikiName} )
        {

            # Main.WikiName - email@domain (legacy format)
            $this->subscribe( $2, '*', 0, 0 );
            $in_pre = 0;
        }
        elsif ($line =~ /$stdRE/
            && $1 ne $Foswiki::cfg{DefaultUserWikiName} )
        {
            my $subscriber = $1;

            # Get the topic list from the last bracket matched. Have to do it
            # this awkward way because the email filter may contain braces
            my $topics = $+;

            # email addresses can't start with :
            $topics = undef unless ( $topics =~ s/^:// );
            $subscriber =~ s/^(['"])(.*)\1$/$2/;    # remove quotes

            # CDot: I don't understand how this can ever be tainted, but the
            # unit tests fail without this untaint. The subscriber is
            # validated, and should be untainted, by the conditional regex.
            $subscriber = Foswiki::Sandbox::untaintUnchecked($subscriber);

            if ( defined $topics ) {
                $this->parsePageSubscriptions( $subscriber, $topics );
            }
            else {
                $this->subscribe( $subscriber, '*', 0, 0 );
            }
            $in_pre = 0;
        }
        else {
            if ($in_pre) {
                $this->{pretext} .= "$baseline\n";
            }
            else {
                $this->{posttext} .= "$baseline\n";
            }
        }
    }
    print STDERR "LOADED " . $this->stringify() if TRACE;
}

=begin TML

---++ ObjectMethod parsePageSubscriptions($who, $spec, $unsubscribe)

Parse a pages list for a single user (corresponding to one line in
WebNotify), adding subscriptions for user $who as appropriate
If $unsubscribe is set to '-' by SubscribePlugin to force a '-' operation

=cut

# If we see a simple topic specification with no unusual options, and
# at childDepth 0, we can collect it into a group subscription for
# efficiency.
our @simple_subscriptions;

sub parsePageSubscriptions {
    my ( $this, $who, $spec, $unsubscribe ) = @_;

    $this->{topicSub} = \&_subscribeTopic;

    local @simple_subscriptions = ();
    my $ret =
      Foswiki::Contrib::MailerContrib::parsePageList( $this, $who, $spec,
        $unsubscribe );
    if ( $ret =~ m/\S/ ) {
        Foswiki::Func::writeWarning("Badly formatted page list at $who: $spec");
        return -1;
    }

    if ( scalar(@simple_subscriptions) ) {

        $this->subscribe( $who, join( ' ', @simple_subscriptions ), 0, 0 );
    }
    return;
}

# helper for parsePageSubscriptions
sub _subscribeTopic {
    my ( $this, $who, $unsubscribe, $webTopic, $options, $childDepth ) = @_;

    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( $this->{web}, $webTopic );

    my $opts = 0;
    my $kids = $childDepth || 0;
    if ($options) {
        $opts |= Foswiki::Contrib::MailerContrib::Subscription::FULL_TOPIC;
        if ( $options =~ /!/ ) {
            $opts |= Foswiki::Contrib::MailerContrib::Subscription::ALWAYS;
        }
    }
    if ( $unsubscribe && $unsubscribe eq '-' ) {
        $this->unsubscribe( $who, $topic, $kids );
    }
    elsif ( !$opts && !$childDepth ) {

        push( @simple_subscriptions, $topic );
    }
    else {

        # Otherwise we have to add a separate subscription record
        $this->subscribe( $who, $topic, $kids, $opts );
    }

    #TODO: howto find & report errors?
    return '';
}

# PRIVATE emailWarn to warn when an email address cannot be found
# for a subscriber.
sub _emailWarn {
    my ( $this, $subscriber, $name, $web ) = @_;

    # Make sure we only warn once. Don't want to see this for every
    # Topic we are notifying on.
    unless ( defined $this->{nomail}{$name} ) {
        $this->{nomail}{$name} = 1;
        Foswiki::Func::writeWarning( "Failed to find permitted email for '"
              . $subscriber->stringify()
              . "' when processing web '$web'" );
    }
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. All Rights Reserved.
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
