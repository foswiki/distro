# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 1999-2007 TWiki Contributors.
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

=pod

---+ package TWiki::Contrib::MailerContrib::WebNotify
Object that represents the contents of a %NOTIFYTOPIC% topic in a TWiki web.

Note that =$TWiki::Plugins::SESSION= is used to find the TWiki session, and
must be set up before this class is used.

=cut

package TWiki::Contrib::MailerContrib::WebNotify;

use strict;
use locale; # required for matching \w with international characters

use Assert;

require TWiki::Func;
require TWiki::Contrib::MailerContrib;
require TWiki::Contrib::MailerContrib::Subscriber;
require TWiki::Contrib::MailerContrib::Subscription;

=pod

---++ new($session, $web, $topic)
   * =$session= - TWiki object
   * =$web= - web name
   * =$topic= - topic name
   * =$noexpandgroups= - True will prevent expansion of  group subscriptions
          (False is best for checking subscriptions, but True is best for
	  writing results back to $topic)
Create a new object by parsing the content of the given topic in the
given web. This is the normal way to load a %NOTIFYTOPIC% topic. If the
topic does not exist, it will create an empty object.

=cut

sub new {
    my ( $class, $session, $web, $topic, $noexpandgroups ) = @_;

    my $this = bless( {}, $class );

    # Ensure the contrib is initialised
    TWiki::Contrib::MailerContrib::initContrib();

    $this->{web} = $web;
    $this->{topic} = $topic || $TWiki::cfg{NotifyTopicName} || 'WebNotify';
    $this->{pretext} = '';
    $this->{posttext} = '';
    $this->{session} = $session;
    $this->{noexpandgroups} = $noexpandgroups;

    if( TWiki::Func::topicExists( $web, $topic )) {
        $this->_load();
    }

    return $this;
}

=pod

---++ writeWebNotify()
Write the object to the %NOTIFYTOPIC% topic it was read from.
If there is a problem writing the topic (e.g. it is locked),
the method will throw an exception.

=cut

sub writeWebNotify {
    my $this = shift;
    TWiki::Func::saveTopicText(
        $this->{web},
        $this->{topic},
        $this->stringify(),
        1, 1);
}

=pod

---++ getSubscriber($name, $noAdd)
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
    unless ( $noAdd || defined( $subscriber )) {
        $subscriber =
          new TWiki::Contrib::MailerContrib::Subscriber( $name );
        $this->{subscribers}{$name} = $subscriber;
    }
    return $subscriber;
}

=pod

---++ getSubscribers()
Get a list of all subscriber names (unsorted)

=cut

sub getSubscribers {
    my ( $this ) = @_;

    return keys %{$this->{subscribers}};
}

=pod

---++ subscribe($name, $topics, $depth, $options)
   * =$name= - Name of subscriber (wikiname with no web or email address)
   * =$topics= - wildcard expression giving topics to subscribe to
   * =$depth= - Child depth to scan (default 0)
   * =$options= - Bitmap of Mailer::Const options
Add a subscription, adding the subscriber if necessary.

=cut

sub subscribe {
    my ( $this, $name, $topics, $depth, $opts ) = @_;

    ASSERT(defined($opts) && $opts =~ /^\d*$/) if DEBUG;

    my @names = ($name);
    unless ($this->{noexpandgroups}) {
        if (defined &TWiki::Func::eachGroupMember) {
            my $it = TWiki::Func::eachGroupMember( $name );
            if( $it ) {
                @names = ();
                while( $it->hasNext() ) {
                    my $member = $it->next();
                    push( @names, $member );
                }
            }
        } else {
            my $user = TWiki::User->new($this->{session}, '', $name);
            if ($user->isGroup) {
                @names = map {$_->wikiName} @{$user->groupMembers};
            }
        }
    }

    foreach my $n (@names) {
        my $subscriber = $this->getSubscriber( $n );
        my $sub = new TWiki::Contrib::MailerContrib::Subscription(
            $topics, $depth, $opts );
        $subscriber->subscribe( $sub );
    }
}

=pod

---++ unsubscribe($name, $topics, $depth)
   * =$name= - Name of subscriber (wikiname with no web or email address)
   * =$topics= - wildcard expression giving topics to subscribe to
   * =$depth= - Child depth to scan (default 0)
Add an unsubscription, adding the subscriber if necessary. An unsubscription
is a specific request to ignore notifications for a topic for this
particular subscriber.

=cut

sub unsubscribe {
    my ( $this, $name, $topics, $depth ) = @_;

    my @names = ( $name );
    unless ($this->{noexpandgroups}) {
        if (defined &TWiki::Func::eachGroupMember) {
            my $it = TWiki::Func::eachGroupMember( $name );
            if( $it ) {
                @names = ();
                while( $it->hasNext() ) {
                    my $member = $it->next();
                    push( @names, $member );
                }
            }
        } else {
            my $user = TWiki::User->new($this->{session}, '', $name);
            if ($user->isGroup) {
                @names = map {$_->wikiName} @{$user->groupMembers};
            }
        }
    }

    foreach my $n (@names) {
        my $subscriber = $this->getSubscriber( $n );
        my $sub = new TWiki::Contrib::MailerContrib::Subscription(
            $topics, $depth, 0 );
        $subscriber->unsubscribe( $sub );
    }
}

=pod

---++ stringify() -> string
Return a string representation of this object, in %NOTIFYTOPIC% format.

Optional $subscribersOnly parameter to only print the parsed subscription list.
Used when running a mailnotify, where printing out the entire WebNotify topic is confusing,
as its different from the actual topic contents, but doesn't inform the user why.

=cut

sub stringify {
    my $this = shift;
    my $subscribersOnly = shift || 0;

    my $page = $this->{pretext} if (!$subscribersOnly);

    foreach my $name ( sort keys %{$this->{subscribers}} ) {
        my $subscriber = $this->{subscribers}{$name};
        $page .= $subscriber->stringify() . "\n";
    }
    $page .= $this->{posttext} if (!$subscribersOnly);

    return $page;
}

=pod

---++ processChange($change, $db, $changeSet, $seenSet, $allSet)
   * =$change= - ref of a TWiki::Contrib::Mailer::Change
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parent references
   * =$changeSet= - ref of a hash mapping emails to sets of changes
   * =$seenSet= - ref of a hash recording indices of topics already seen
   * =$allSet= - ref of a hash that maps topics to email addresses for news subscriptions
Find all subscribers that are interested in the given change. Only the most
recent change to each topic listed in the .changes file is retained. This
method does _not_ change this object.

=cut

sub processChange {
    my ( $this, $change, $db, $changeSet, $seenSet, $allSet ) = @_;

    my $topic = $change->{TOPIC};
    my $web = $change->{WEB};
    my %authors = map { $_ => 1 }
      @{TWiki::Contrib::MailerContrib::Subscriber::getEmailAddressesForUser(
          $change->{author})};

    foreach my $name ( keys %{$this->{subscribers}} ) {
        my $subscriber = $this->{subscribers}{$name};
        my $subs = $subscriber->isSubscribedTo( $topic, $db );
        if ($subs && !$subscriber->isUnsubscribedFrom( $topic, $db )) {

            next unless TWiki::Func::checkAccessPermission(
                'VIEW', $name, undef, $topic, $this->{web}, undef );

            my $emails = $subscriber->getEmailAddresses();
            if( $emails && scalar( @$emails )) {
                foreach my $email ( @$emails ) {
                    # Skip this change if the subscriber is the author
                    # of the change, and we are not always sending
                    next if (!($subs->{options} & $MailerConst::ALWAYS)
                               && $authors{$email});

                    if ($subs->{options} & $MailerConst::FULL_TOPIC) {
                        push( @{$allSet->{$topic}}, $email );
                    } else {
                        my $at = $seenSet->{$email}{$topic};
                        if ( $at ) {
                            $changeSet->{$email}[$at - 1]->merge( $change );
                        } else {
                            $seenSet->{$email}{$topic} =
                              push( @{$changeSet->{$email}}, $change );
                        }
                    }
                }
            } else {
                $this->_emailWarn($subscriber,$name,$web);
            }
        }
    }
}

=pod

---++ processCompulsory($topic, $db, \%allSet)
   * =$topic= - topic name
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parent references
   * =\%allSet= - ref of a hash that maps topics to email addresses for news subscriptions

=cut

sub processCompulsory {
    my ($this, $topic, $db, $allSet) = @_;

    foreach my $name ( keys %{$this->{subscribers}} ) {
        my $subscriber = $this->{subscribers}{$name};
        my $subs = $subscriber->isSubscribedTo( $topic, $db );
        next unless $subs;
        next unless ($subs->{options} & $MailerConst::ALWAYS);
        unless( $subscriber->isUnsubscribedFrom( $topic, $db )) {
            my $emails = $subscriber->getEmailAddresses();
            if( $emails ) {
                foreach my $address (@$emails) {
                    push( @{$allSet->{$topic}}, $address );
                }
            }
        }
    }
}

=pod

---++ isEmpty() -> boolean
Return true if there are no subscribers

=cut

sub isEmpty {
    my $this = shift;
    return ( scalar( keys %{$this->{subscribers}} ) == 0 );
}

# PRIVATE parse a topic extracting formatted lines
sub _load {
    my $this = shift;

    my ( $meta, $text ) = TWiki::Func::readTopic(
        $this->{web}, $this->{topic} );
    my $in_pre = 1;
    $this->{pretext} = '';
    $this->{posttext} = '';
    $this->{meta} = $meta;
    # join \ terminated lines
    $text =~ s/\\\r?\n//gs;
    my $webRE = qr/(?:$TWiki::cfg{UsersWebName}\.)?/o;
    foreach my $baseline ( split ( /\r?\n/, $text )) {
        my $line = TWiki::Func::expandCommonVariables(
            $baseline, $this->{topic}, $this->{web}, $meta);
        if( $line =~ /^\s+\*\s$webRE($TWiki::regex{wikiWordRegex})\s+\-\s+($TWiki::cfg{MailerContrib}{EmailFilterIn}+)\s*$/o
              && $1 ne $TWiki::cfg{DefaultUserWikiName}) {
            # Main.WikiName - email@domain (legacy format)
            $this->subscribe( $2, '*', 0, 0 );
            $in_pre = 0;
        }
        elsif ( $line =~ /^\s+\*\s$webRE($TWiki::regex{wikiWordRegex}|'.*?'|".*?"|$TWiki::cfg{MailerContrib}{EmailFilterIn})\s*(:.*)?$/o
                  && $1 ne $TWiki::cfg{DefaultUserWikiName}) {
            my $subscriber = $1;
            # Get the topic list from the last bracket matched. Have to do it
            # this awkward way because the email filter may contain braces
            my $topics = $+;
            # email addresses can't start with :
            $topics = undef unless ($topics =~ s/^://);
            $subscriber =~ s/^(['"])(.*)\1$/$2/; # remove quotes
            if ($topics) {
                $this->parsePageSubscriptions( $subscriber, $topics );
            } else {
                $this->subscribe($subscriber, '*', 0, 0 );
            }
            $in_pre = 0;
        }
        else {
            if( $in_pre ) {
                $this->{pretext} .= "$baseline\n";
            } else {
                $this->{posttext} .=  "$baseline\n";
            }
        }
    }
}

# parse a pages list, adding subscriptions as appropriate
# $unsubscribe is set to '-' by SubscribePlugin to force a '-' operation
sub parsePageSubscriptions {
    my ( $this, $who, $spec, $unsubscribe ) = @_;
    
    $this->{topicSub} = \&_subscribeTopic;
    
    my $ret = TWiki::Contrib::MailerContrib::parsePageList($this, $who, $spec, $unsubscribe);
    if ( $ret =~ m/\S/ ) {
        TWiki::Func::writeWarning(
            "Badly formatted page list at $who: $spec");
	return -1;
    }
    return;
}

sub _subscribeTopic {
    my ( $this, $who, $unsubscribe, $webTopic, $options, $childDepth ) = @_;
    
    my ($web, $topic) = TWiki::Func::normalizeWebTopicName($this->{web}, $webTopic);
    $this->_alert('warning: ignoring web prefix on '.$webTopic) if ($web ne $this->{web});
    
#print STDERR "_subscribeTopic($topic)\n";
    my $opts = 0;
    if ($options) {
	$opts |= $MailerConst::FULL_TOPIC;
	if ($options =~ /!/) {
	    $opts |= $MailerConst::ALWAYS;
	}
    }
    my $kids = $childDepth or 0;
    if ( $unsubscribe && $unsubscribe eq '-') {
	$this->unsubscribe( $who, $topic, $kids );
    } else {
	$this->subscribe( $who, $topic, $kids, $opts );
    }
    #TODO: howto find & report errors?
    return '';
}

# PRIVATE emailWarn to warn when an email address cannot be found
# for a subscriber.
sub _emailWarn {
    my ($this, $subscriber, $name, $web) = @_;

    # Make sure we only warn once. Don't want to see this for every
    # Topic we are notifying on.
    unless (defined $this->{nomail}{$name}) {
        $this->{nomail}{$name} = 1;
        TWiki::Func::writeWarning(
            "Failed to find permitted email for '".
              $subscriber->stringify()."' when processing web '$web'");
    }
}

1;
