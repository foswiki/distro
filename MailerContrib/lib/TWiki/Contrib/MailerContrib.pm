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

=pod

---+ package TWiki::Contrib::MailerContrib

Package of support for extended Web<nop>Notify notification, supporting per-topic notification and notification of changes to children.

Also supported is a simple API that can be used to change the Web<nop>Notify topic from other code.

=cut

package TWiki::Contrib::MailerContrib;

use strict;

use URI;
use CGI qw(-any);

require TWiki;
require TWiki::Plugins;
require TWiki::Time;
require TWiki::Func;
require TWiki::Contrib::MailerContrib::WebNotify;
require TWiki::Contrib::MailerContrib::Change;
require TWiki::Contrib::MailerContrib::UpData;

use vars qw ( $VERSION $RELEASE $verbose );

$VERSION = '$Rev: 16130 $';
$RELEASE = '15 Oct 2008';

# PROTECTED STATIC ensure the contrib is initernally initialised
sub initContrib {
    $TWiki::cfg{MailerContrib}{EmailFilterIn} ||=
      $TWiki::regex{emailAddrRegex};
}

=pod

---++ StaticMethod mailNotify($webs, $session, $verbose, $exwebs)
   * =$webs= - filter list of names webs to process. Wildcards (*) may be used.
   * =$session= - optional session object. If not given, will use a local object.
   * =$verbose= - true to get verbose (debug) output.
   * =$exwebs = - filter list of webs to exclude.

Main entry point.

Process the Web<nop>Notify topics in each web and generate and issue
notification mails. Designed to be invoked from the command line; should
only be called by =mailnotify= scripts.

=cut

sub mailNotify {
    my( $webs, $twiki, $noisy, $exwebs ) = @_;

    $verbose = $noisy;

    my $webstr;
    if ( defined( $webs )) {
        $webstr = join( '|', @$webs );
    }
    $webstr = '*' unless ( $webstr );
    $webstr =~ s/\*/\.\*/g;

    my $exwebstr = '';
    if ( defined( $exwebs )) {
        $exwebstr = join( '|', @$exwebs );
    }
    $exwebstr =~ s/\*/\.\*/g;

    if (!defined $twiki) {
        $twiki = new TWiki();
    }

    $TWiki::Plugins::SESSION = $twiki;

    my $context = TWiki::Func::getContext();

    $context->{command_line} = 1;

    # absolute URL context for email generation
    $context->{absolute_urls} = 1;

    initContrib();

    my $report = '';
    foreach my $web ( TWiki::Func::getListOfWebs( 'user ') ) {
       if ( $web =~ /^($webstr)$/ && $web !~ /^($exwebstr)$/ ) {
          $report .= _processWeb( $twiki, $web );
       }
    }

    $context->{absolute_urls} = 0;

    return $report;
}

=pod

=cut

sub changeSubscription {
    my ($defaultWeb, $who, $topicList, $unsubscribe) = @_;

    #we can get away with a normalise on a list of topics, so long as the list starts with a topic
    my ($web, $t) = TWiki::Func::normalizeWebTopicName($defaultWeb, $topicList);
    #TODO: this limits us to subscribing to one web.
    my $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $web, $TWiki::cfg{NotifyTopicName}, 1 );
    $wn->parsePageSubscriptions( $who, $topicList, $unsubscribe );
    $wn->writeWebNotify();
    return;
}


=pod
---+++ isSubscribedTo ($web, $who, $topicList) -> boolean
returns true if all topics mentioned in the $topicList are subscribed to by $who.

is able to ignore all valid special characters that can be used on the WebNotify topic
such as NewsTopic! , TopicAndChildren (2)

=cut

sub isSubscribedTo {
    my ($defaultWeb, $who, $topicList) = @_;
    
    my $subscribed = {
                        currentWeb=>$defaultWeb,
                        topicSub=>\&_isSubscribedToTopic
                    };

    my $ret = TWiki::Contrib::MailerContrib::parsePageList($subscribed, $who, $topicList);
    
    return (!defined($subscribed->{not_subscribed}) ||
                (0 == scalar($subscribed->{not_subscribed})) );
}
sub _isSubscribedToTopic {
    my ( $subscribed, $who, $unsubscribe, $topic, $options, $childDepth ) = @_;
    
    require TWiki::Contrib::MailerContrib::WebNotify;
    my ($sweb, $stopic) = TWiki::Func::normalizeWebTopicName($subscribed->{currentWeb}, $topic);

    #TODO: extract this code so we only create $wn objects for each web once..    
    my $wn = new TWiki::Contrib::MailerContrib::WebNotify( $TWiki::Plugins::SESSION, $sweb, $TWiki::cfg{NotifyTopicName} );
    my $subscriber = $wn->getSubscriber($who);
    
    my $db = new TWiki::Contrib::MailerContrib::UpData( $TWiki::Plugins::SESSION, $sweb );
    #TODO: need to check $childDepth topics too (somehow)
    if ( $subscriber->isSubscribedTo($stopic, $db) &&
         (!$subscriber->isUnsubscribedFrom($stopic, $db))) {
      	push(@{$subscribed->{subscribed}}, $stopic);
    } else {
      	push(@{$subscribed->{not_subscribed}}, $stopic);
    }
    return '';
}

=pod
---+++ sub parsePageList ( $object, $who, $spec, $unsubscribe ) => unprocessable remainder of $spec line
calls the $topicSub (ref to sub) once per identified topic entry.
   * $object (is a hashref) can be used to set status' and its definition is dependent on $topicSub
   * $object->{topicSub} _must_ be a sub ref and _must_ return an empty string
   * $unsubscribe can be set to '-' to force an unsubscription (used by SubscribePlugin)
   
   $object is a functor.

=cut

sub parsePageList {
    my ( $object, $who, $spec, $unsubscribe ) = @_;
    #ASSERT(defined($object->{topicSub}));
    
    return $spec if (!defined($object->{topicSub}));
    
    $spec =~ s/,/ /g;
    #TODO: refine the $2 regex to be proper web.topic/topic/* style..
    while ($spec =~ s/^\s*([+-])?\s*([\w.\*]+)([!?]?)\s*(?:\((\d+)\))?/&{$object->{topicSub}}($object, $who, $unsubscribe||$1, $2, $3, $4)/e) {
	#go
    }
    return $spec;
}


# PRIVATE: Read the webnotify, and notify changes
sub _processWeb {
    my( $twiki, $web) = @_;

    if( ! TWiki::Func::webExists( $web ) ) {
#        print STDERR "**** ERROR mailnotifier cannot find web $web\n";
        return '';
    }

    print "Processing $web\n" if $verbose;

    my $report = '';

    # Read the webnotify and load subscriptions
    my $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $twiki, $web, $TWiki::cfg{NotifyTopicName} );
    if ( $wn->isEmpty() ) {
        print "\t$web has no subscribers\n" if $verbose;
    } else {
        # create a DB object for parent pointers
        print $wn->stringify(1) if $verbose;
        my $db = new TWiki::Contrib::MailerContrib::UpData( $twiki, $web );
        $report .= _processSubscriptions( $twiki, $web, $wn, $db );
    }

    return $report;
}

# Process subscriptions in $notify
sub _processSubscriptions {
    my ( $twiki, $web, $notify, $db ) = @_;

    my $metadir = TWiki::Func::getWorkArea('MailerContrib');
    my $notmeta = $web;
    $notmeta =~ s#/#.#g;
    $notmeta = "$metadir/$notmeta";

    my $timeOfLastNotify = 0;
    if( open(F, "<$notmeta")) {
        local $/ = undef;
        $timeOfLastNotify = <F>;
        close(F);
    }

    if ( $verbose ) {
        print "\tLast notification was at " .
          TWiki::Time::formatTime( $timeOfLastNotify, 'iso' ). "\n";
    }

    my $timeOfLastChange = 0;

    # Hash indexed on email address, each entry contains a hash
    # of topics already processed in the change set for this email.
    # Each subhash maps the topic name to the index of the change
    # record for this topic in the array of Change objects for this
    # email in %changeset.
    my %seenset;

    # Hash indexed on email address, each entry contains an array
    # indexed by the index stored in %seenSet. Each entry in the array
    # is a ref to a Change object.
    my %changeset;

    # Hash indexed on topic name, mapping to email address, used to
    # record simple newsletter subscriptions.
    my %allSet;

    if( !defined( &TWiki::Func::eachChangeSince )) {
        require TWiki::Contrib::MailerContrib::CompatibilityHacks;
    }

    # + 1 because the 'since' check is >=
    my $it = TWiki::Func::eachChangeSince( $web, $timeOfLastNotify + 1 );
    while( $it->hasNext() ) {
        my $change = $it->next();
        next if $change->{more} && $change->{more} =~ /minor$/;

        next unless TWiki::Func::topicExists( $web, $change->{topic} );

        $timeOfLastChange = $change->{time} unless( $timeOfLastChange );

        print "\tChange to $change->{topic} at ".
          TWiki::Time::formatTime( $change->{time}, 'iso' ).
              ". New revision is $change->{revision}\n" if ( $verbose );

        # Formulate a change record, irrespective of
        # whether any subscriber is interested
        $change = new TWiki::Contrib::MailerContrib::Change(
            $twiki, $web, $change->{topic}, $change->{user},
            $change->{time}, $change->{revision} );

        # Now, find subscribers to this change and extend the change set
        $notify->processChange(
            $change, $db, \%changeset, \%seenset, \%allSet );
    }
    # For each topic, see if there's a compulsory subscription independent
    # of the time since last notify
    foreach my $topic (TWiki::Func::getTopicList($web)) {
        $notify->processCompulsory( $topic, $db, \%allSet );
    }

    # Now generate emails for each recipient
    my $report = _sendChangesMails(
        $twiki, $web, \%changeset,
        TWiki::Time::formatTime($timeOfLastNotify) );

    $report .= _sendNewsletterMails( $twiki, $web, \%allSet);

    if ($timeOfLastChange != 0) {
        if( open(F, ">$notmeta" )) {
            print F $timeOfLastChange;
            close(F);
        }
    }

    return $report;
}

# PRIVATE generate and send an email for each user
sub _sendChangesMails {
    my ( $twiki, $web, $changeset, $lastTime ) = @_;
    my $report = '';

    my $skin = TWiki::Func::getSkin();
    my $template = TWiki::Func::readTemplate( 'mailnotify', $skin );

    my $homeTopic = $TWiki::cfg{HomeTopicName};

    my $before_html = TWiki::Func::expandTemplate( 'HTML:before' );
    my $middle_html = TWiki::Func::expandTemplate( 'HTML:middle' );
    my $after_html = TWiki::Func::expandTemplate( 'HTML:after' );

    my $before_plain = TWiki::Func::expandTemplate( 'PLAIN:before' );
    my $middle_plain = TWiki::Func::expandTemplate( 'PLAIN:middle' );
    my $after_plain = TWiki::Func::expandTemplate( 'PLAIN:after' );

    my $mailtmpl = TWiki::Func::expandTemplate( 'MailNotifyBody' );
    $mailtmpl = TWiki::Func::expandCommonVariables(
        $mailtmpl, $homeTopic, $web );
    if( $TWiki::cfg{RemoveImgInMailnotify} ) {
        # change images to [alt] text if there, else remove image
        $mailtmpl =~ s/<img\s[^>]*\balt=\"([^\"]+)[^>]*>/[$1]/goi;
        $mailtmpl =~ s/<img src=.*?[^>]>//goi;
    }

    my $sentMails = 0;

    foreach my $email ( keys %{$changeset} ) {
        my $html = '';
        my $plain = '';
        foreach my $change (sort { $a->{TIME} cmp $b->{TIME} }
                            @{$changeset->{$email}} ) {

            $html .= $change->expandHTML( $middle_html );
            $plain .= $change->expandPlain( $middle_plain );
        }

        $plain =~ s/\($TWiki::cfg{UsersWebName}\./\(/go;

        my $mail = $mailtmpl;

        $mail =~ s/%EMAILTO%/$email/go;
        $mail =~ s/%HTML_TEXT%/$before_html$html$after_html/go;
        $mail =~ s/%PLAIN_TEXT%/$before_plain$plain$after_plain/go;
        $mail =~ s/%LASTDATE%/$lastTime/geo;
        $mail = TWiki::Func::expandCommonVariables( $mail, $homeTopic, $web );

        my $base = $TWiki::cfg{DefaultUrlHost} . $TWiki::cfg{ScriptUrlPath};
        $mail =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/goei;
        $mail =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/goei;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        my $error = TWiki::Func::sendEmail( $mail, 5 );

        if ($error) {
            print STDERR "Error sending mail forf $web: $error\n";
            $report .= $error."\n";
        } else {
            print "Notified $email of changes in $web\n" if $verbose;
            $sentMails++;
        }
    }
    $report .= "\t$sentMails change notifications from $web\n";

    return $report;
}

sub relativeURL {
    my( $base, $link ) = @_;
    return URI->new_abs( $link, URI->new($base) )->as_string;
}

sub _sendNewsletterMails {
    my ($twiki, $web, $allSet) = @_;

    my $report = '';
    foreach my $topic (keys %$allSet) {
        $report .= _sendNewsletterMail(
            $twiki, $web, $topic, $allSet->{$topic});
    }
    return $report;
}

sub _sendNewsletterMail {
    my ($twiki, $web, $topic, $emails) = @_;
    my $wikiName = TWiki::Func::getWikiName();

    # SMELL: this code is almost identical to PublishContrib

    # Read topic data.
    my ($meta, $text) = TWiki::Func::readTopic( $web, $topic );

    if (!defined( &TWiki::Func::pushTopicContext )) {
        require TWiki::Contrib::MailerContrib::TopicContext;
    }
    TWiki::Func::pushTopicContext( $web, $topic );

    $twiki->enterContext( 'can_render_meta', $meta );

    # Get the skin for this topic
    my $skin = TWiki::Func::getSkin();
    TWiki::Func::readTemplate( 'newsletter', $skin );
    my $header = TWiki::Func::expandTemplate( 'NEWS:header' );
    my $body = TWiki::Func::expandTemplate( 'NEWS:body' );
    my $footer = TWiki::Func::expandTemplate( 'NEWS:footer' );

    my ($revdate, $revuser, $maxrev);
    ($revdate, $revuser, $maxrev) = $meta->getRevisionInfo();

    # Handle standard formatting.
    $body =~ s/%TEXT%/$text/g;
    # Don't render the header, it is preformatted
    $header = TWiki::Func::expandCommonVariables($header, $topic, $web);
    my $tmpl = "$body\n$footer";
    $tmpl = TWiki::Func::expandCommonVariables($tmpl, $topic, $web);
    $tmpl = TWiki::Func::renderText($tmpl, "", $meta);
    $tmpl = "$header$tmpl";

    # REFACTOR OPPORTUNITY: stop factor me into getTWikiRendering()
    # SMELL: this code is identical to PublishContrib!

    # New tags
    my $newTmpl = '';
    my $tagSeen = 0;
    my $publish = 1;
    foreach my $s ( split( /(%STARTPUBLISH%|%STOPPUBLISH%)/, $tmpl )) {
        if( $s eq '%STARTPUBLISH%' ) {
            $publish = 1;
            $newTmpl = '' unless( $tagSeen );
            $tagSeen = 1;
        } elsif( $s eq '%STOPPUBLISH%' ) {
            $publish = 0;
            $tagSeen = 1;
        } elsif( $publish ) {
            $newTmpl .= $s;
        }
    }
    $tmpl = $newTmpl;
    $tmpl =~ s/.*?<\/nopublish>//gs;
    $tmpl =~ s/%MAXREV%/$maxrev/g;
    $tmpl =~ s/%CURRREV%/$maxrev/g;
    $tmpl =~ s/%REVTITLE%//g;
    $tmpl =~ s|( ?) *</*nop/*>\n?|$1|gois;

    # Remove <base.../> tag
    $tmpl =~ s/<base[^>]+\/>//;
    # Remove <base...>...</base> tag
    $tmpl =~ s/<base[^>]+>.*?<\/base>//;

    # Rewrite absolute URLs
    my $base = $TWiki::cfg{DefaultUrlHost} . $TWiki::cfg{ScriptUrlPath};
    $tmpl =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/goei;
    $tmpl =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/goei;

    my $report = '';
    my $sentMails = 0;

    my %targets = map { $_ => 1 } @$emails;

    foreach my $email ( keys %targets ) {
        my $mail = $tmpl;

        $mail =~ s/%EMAILTO%/$email/go;

        my $base = $TWiki::cfg{DefaultUrlHost} . $TWiki::cfg{ScriptUrlPath};
        $mail =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/goei;
        $mail =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/goei;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        my $error = TWiki::Func::sendEmail( $mail, 5 );

        if ($error) {
            print STDERR "Error sending mail for $web: $error\n";
            $report .= $error."\n";
        } else {
            print "Sent newletter for $web to $email\n" if $verbose;
            $sentMails++;
        }
    }
    $report .= "\t$sentMails newsletters from $web\n";

    TWiki::Func::popTopicContext();

    return $report;
}

1;
