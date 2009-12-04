# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Contrib::MailerContrib

Package of support for extended Web<nop>Notify notification, supporting per-topic notification and notification of changes to children.

Also supported is a simple API that can be used to change the Web<nop>Notify topic from other code.

=cut

package Foswiki::Contrib::MailerContrib;

use strict;

use URI ();
use CGI qw(-any);

use Foswiki                                    ();
use Foswiki::Plugins                           ();
use Foswiki::Time                              ();
use Foswiki::Func                              ();
use Foswiki::Contrib::MailerContrib::WebNotify ();
use Foswiki::Contrib::MailerContrib::Change    ();
use Foswiki::Contrib::MailerContrib::UpData    ();

our $VERSION = '$Rev$';
our $RELEASE = '4 Dec 2009';
our $SHORTDESCRIPTION = 'Supports e-mail notification of changes';

our $verbose = 0;
our $nonews = 0;
our $nochanges = 0;

# PROTECTED STATIC ensure the contrib is initernally initialised
sub initContrib {
    $Foswiki::cfg{MailerContrib}{EmailFilterIn} ||=
      $Foswiki::regex{emailAddrRegex};
}

=pod

---++ StaticMethod mailNotify($webs, $session, $verbose, $exwebs, $nonewsmode, $nochangesmode)
   * =$webs= - filter list of names webs to process. Wildcards (*) may be used.
   * =$session= - optional session object. If not given, will use a local object.
   * =$verbose= - true to get verbose (debug) output.
   * =$exwebs = - filter list of webs to exclude.
   * =$nonewsmode = the notify script was called with the -nonews option so we skip news mode
   * =$nochangesmode = the notify script was called with the -nochanges option

Main entry point.

Process the Web<nop>Notify topics in each web and generate and issue
notification mails. Designed to be invoked from the command line; should
only be called by =mailnotify= scripts.

=cut

sub mailNotify {
    my ( $webs, $twiki, $noisy, $exwebs, $nonewsmode, $nochangesmode ) = @_;

    $verbose = $noisy;
    $nonews = $nonewsmode || 0;
    $nochanges = $nochangesmode || 0;

    my $webstr;
    if ( defined($webs) ) {
        $webstr = join( '|', @$webs );
    }
    $webstr = '*' unless ($webstr);
    $webstr =~ s/\*/\.\*/g;

    my $exwebstr = '';
    if ( defined($exwebs) ) {
        $exwebstr = join( '|', @$exwebs );
    }
    $exwebstr =~ s/\*/\.\*/g;

    if ( !defined $twiki ) {
        $twiki = new Foswiki();
    }

    $Foswiki::Plugins::SESSION = $twiki;

    my $context = Foswiki::Func::getContext();

    $context->{command_line} = 1;

    # absolute URL context for email generation
    $context->{absolute_urls} = 1;

    initContrib();

    my $report = '';
    foreach my $web ( Foswiki::Func::getListOfWebs('user ') ) {
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
    my ( $defaultWeb, $who, $topicList, $unsubscribe ) = @_;

#we can get away with a normalise on a list of topics, so long as the list starts with a topic
    my ( $web, $t ) =
      Foswiki::Func::normalizeWebTopicName( $defaultWeb, $topicList );

    #TODO: this limits us to subscribing to one web.
    my $wn = new Foswiki::Contrib::MailerContrib::WebNotify(
        $Foswiki::Plugins::SESSION, $web, $Foswiki::cfg{NotifyTopicName}, 1 );
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
    my ( $defaultWeb, $who, $topicList ) = @_;

    my $subscribed = {
        currentWeb => $defaultWeb,
        topicSub   => \&_isSubscribedToTopic
    };

    my $ret = parsePageList( $subscribed, $who, $topicList );

    return ( !defined( $subscribed->{not_subscribed} )
          || ( 0 == scalar( $subscribed->{not_subscribed} ) ) );
}

sub _isSubscribedToTopic {
    my ( $subscribed, $who, $unsubscribe, $topic, $options, $childDepth ) = @_;

    require Foswiki::Contrib::MailerContrib::WebNotify;
    my ( $sweb, $stopic ) =
      Foswiki::Func::normalizeWebTopicName( $subscribed->{currentWeb}, $topic );

    #TODO: extract this code so we only create $wn objects for each web once..
    my $wn = new Foswiki::Contrib::MailerContrib::WebNotify(
        $Foswiki::Plugins::SESSION, $sweb, $Foswiki::cfg{NotifyTopicName} );
    my $subscriber = $wn->getSubscriber($who);

    my $db =
      new Foswiki::Contrib::MailerContrib::UpData( $Foswiki::Plugins::SESSION,
        $sweb );

    #TODO: need to check $childDepth topics too (somehow)
    if ( $subscriber->isSubscribedTo( $stopic, $db )
        && ( !$subscriber->isUnsubscribedFrom( $stopic, $db ) ) )
    {
        push( @{ $subscribed->{subscribed} }, $stopic );
    }
    else {
        push( @{ $subscribed->{not_subscribed} }, $stopic );
    }
}

=pod

---+++ sub parsePageList ( $object, $who, $spec, $unsubscribe ) => unprocessable remainder of $spec line
Calls the $object->{topicSub} once per identified topic entry.
   * $object (a hashref) may be a hashref that has the field, =topicSub=,
     which _may_ be a sub ref as follows:
     =&topicSub($object, $who, $unsubscribe, $webTopic, $options, $childDepth)=
   * =$unsubscribe= can be set to '-' to force an unsubscription
     (used by SubscribePlugin)

=cut

sub parsePageList {
    my ( $object, $who, $spec, $unsubscribe ) = @_;

    #ASSERT(defined($object->{topicSub}));

    return $spec if ( !$object || !defined( $object->{topicSub} ) );

    $spec =~ s/,/ /g;

    # $1: + or -, optional
    # $2: the wildcarded topic specifier (may be quoted)
    # TODO: refine the $2 regex to be proper web.topic/topic/* style..
    # $3: options
    # $4: child depth
    while ( $spec =~
              s/^\s*([+-])?\s*([*\w.]+|'.*?'|".*?")([!?]?)\s*(?:\((\d+)\))?//) {
        my ( $us, $webTopic, $options, $childDepth ) = (
            $unsubscribe||$1||'+', $2, $3, $4||0 );
        $webTopic =~ s/^(['"])(.*)\1$/$2/; # remove quotes
        &{$object->{topicSub}}(
            $object, $who, $us, $webTopic, $options, $childDepth);
        #go
    }
    return $spec;
}

# PRIVATE: Read the webnotify, and notify changes
sub _processWeb {
    my ( $twiki, $web, $nonews, $nochanges ) = @_;

    if ( !Foswiki::Func::webExists($web) ) {

        # print STDERR "**** ERROR mailnotifier cannot find web $web\n";
        return '';
    }

    print "Processing $web\n" if $verbose;

    my $report = '';

    # Read the webnotify and load subscriptions
    my $wn =
      new Foswiki::Contrib::MailerContrib::WebNotify( $twiki, $web,
        $Foswiki::cfg{NotifyTopicName} );
    if ( $wn->isEmpty() ) {
        print "\t$web has no subscribers\n" if $verbose;
    }
    else {

        # create a DB object for parent pointers
        print $wn->stringify(1) if $verbose;
        my $db = new Foswiki::Contrib::MailerContrib::UpData( $twiki, $web );
        $report .= _processSubscriptions( $twiki, $web, $wn, $db );
    }

    return $report;
}

# Process subscriptions in $notify
sub _processSubscriptions {
    my ( $twiki, $web, $notify, $db ) = @_;

    my $metadir = Foswiki::Func::getWorkArea('MailerContrib');
    my $notmeta = $web;
    $notmeta =~ s#/#.#g;
    $notmeta = "$metadir/$notmeta";

    my $timeOfLastNotify = 0;
    if ( open( F, '<', $notmeta ) ) {
        local $/ = undef;
        $timeOfLastNotify = <F>;
        close(F);
    }

    if ($verbose) {
        print "\tLast notification was at "
          . Foswiki::Time::formatTime( $timeOfLastNotify, 'iso' ) . "\n";
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

    if ( !defined(&Foswiki::Func::eachChangeSince) ) {
        require Foswiki::Contrib::MailerContrib::CompatibilityHacks;
    }

    # + 1 because the 'since' check is >=
    my $it = Foswiki::Func::eachChangeSince( $web, $timeOfLastNotify + 1 );
    while ( $it->hasNext() ) {
        my $change = $it->next();
        next if $change->{more} && $change->{more} =~ /minor$/;

        next unless Foswiki::Func::topicExists( $web, $change->{topic} );

        $timeOfLastChange = $change->{time} unless ($timeOfLastChange);

        print "\tChange to $change->{topic} at "
          . Foswiki::Time::formatTime( $change->{time}, 'iso' )
          . ". New revision is $change->{revision}\n"
          if ($verbose);

        # Formulate a change record, irrespective of
        # whether any subscriber is interested
        $change =
          new Foswiki::Contrib::MailerContrib::Change( $twiki, $web,
            $change->{topic}, $change->{user}, $change->{time},
            $change->{revision} );

        # Now, find subscribers to this change and extend the change set
        $notify->processChange( $change, $db, \%changeset, \%seenset,
            \%allSet );
    }

    # For each topic, see if there's a compulsory subscription independent
    # of the time since last notify
    foreach my $topic ( Foswiki::Func::getTopicList($web) ) {
        $notify->processCompulsory( $topic, $db, \%allSet );
    }

    # Now generate emails for each recipient
    my $report = '';
    
    if ( !$nochanges ) {
        $report .= _sendChangesMails( $twiki, $web, \%changeset,
          Foswiki::Time::formatTime($timeOfLastNotify) );
    }

    if ( !$nonews ) {
        $report .= _sendNewsletterMails( $twiki, $web, \%allSet );
    }
    
    if ( $timeOfLastChange != 0 ) {
        if ( open( F, '>', $notmeta ) ) {
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

    # We read the mailnotify template in the context (skin and web) or the
    # WebNotify topic we are currently processing
    Foswiki::Func::pushTopicContext( $web, $Foswiki::cfg{NotifyTopicName} );
    my $skin = Foswiki::Func::getSkin();
    my $template = Foswiki::Func::readTemplate( 'mailnotify', $skin );
    Foswiki::Func::popTopicContext();

    my $homeTopic = $Foswiki::cfg{HomeTopicName};

    my $before_html = Foswiki::Func::expandTemplate('HTML:before');
    my $middle_html = Foswiki::Func::expandTemplate('HTML:middle');
    my $after_html  = Foswiki::Func::expandTemplate('HTML:after');

    my $before_plain = Foswiki::Func::expandTemplate('PLAIN:before');
    my $middle_plain = Foswiki::Func::expandTemplate('PLAIN:middle');
    my $after_plain  = Foswiki::Func::expandTemplate('PLAIN:after');

    my $mailtmpl = Foswiki::Func::expandTemplate('MailNotifyBody');
    $mailtmpl =
      Foswiki::Func::expandCommonVariables( $mailtmpl, $homeTopic, $web );
    if ( $Foswiki::cfg{RemoveImgInMailnotify} ) {

        # change images to [alt] text if there, else remove image
        $mailtmpl =~ s/<img\s[^>]*\balt=\"([^\"]+)[^>]*>/[$1]/goi;
        $mailtmpl =~ s/<img src=.*?[^>]>//goi;
    }

    my $sentMails = 0;

    foreach my $email ( keys %{$changeset} ) {
        my $html  = '';
        my $plain = '';
        foreach my $change ( sort { $a->{TIME} cmp $b->{TIME} }
            @{ $changeset->{$email} } )
        {

            $html  .= $change->expandHTML($middle_html);
            $plain .= $change->expandPlain($middle_plain);
        }

        $plain =~ s/\($Foswiki::cfg{UsersWebName}\./\(/go;

        my $mail = $mailtmpl;

        $mail =~ s/%EMAILTO%/$email/go;
        $mail =~ s/%HTML_TEXT%/$before_html$html$after_html/go;
        $mail =~ s/%PLAIN_TEXT%/$before_plain$plain$after_plain/go;
        $mail =~ s/%LASTDATE%/$lastTime/geo;
        $mail = Foswiki::Func::expandCommonVariables( $mail, $homeTopic, $web );

        my $base = $Foswiki::cfg{DefaultUrlHost} . $Foswiki::cfg{ScriptUrlPath};
        $mail =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/goei;
        $mail =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/goei;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        my $error = Foswiki::Func::sendEmail( $mail, 5 );

        if ($error) {
            print STDERR "Error sending mail forf $web: $error\n";
            $report .= $error . "\n";
        }
        else {
            print "Notified $email of changes in $web\n" if $verbose;
            $sentMails++;
        }
    }
    $report .= "\t$sentMails change notifications from $web\n";

    return $report;
}

sub relativeURL {
    my ( $base, $link ) = @_;
    return URI->new_abs( $link, URI->new($base) )->as_string;
}

sub _sendNewsletterMails {
    my ( $twiki, $web, $allSet ) = @_;

    my $report = '';
    foreach my $topic ( keys %$allSet ) {
        $report .=
          _sendNewsletterMail( $twiki, $web, $topic, $allSet->{$topic} );
    }
    return $report;
}

sub _sendNewsletterMail {
    my ( $twiki, $web, $topic, $emails ) = @_;
    my $wikiName = Foswiki::Func::getWikiName();

    # SMELL: this code is almost identical to PublishContrib

    # Read topic data.
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    if ( !defined(&Foswiki::Func::pushTopicContext) ) {
        require Foswiki::Contrib::MailerContrib::TopicContext;
    }

    # SMELL: Have to hack into the core to set internal preferences :-(
    my %old = map { $_ => undef } qw(BASEWEB BASETOPIC INCLUDINGWEB INCLUDINGTOPIC);
    if (defined $Foswiki::Plugins::SESSION->{SESSION_TAGS}) {

        # In 1.0.6 and earlier, have to handle some session tags ourselves
        # because pushTopicContext doesn't do it. **
        foreach my $macro (keys %old) {
            $old{$macro} = Foswiki::Func::getPreferencesValue($macro);
        }
    }
    Foswiki::Func::pushTopicContext( $web, $topic );

    # See ** above
    if (defined $Foswiki::Plugins::SESSION->{SESSION_TAGS}) {
        my $stags = $Foswiki::Plugins::SESSION->{SESSION_TAGS};
        $stags->{BASEWEB} = $web;
        $stags->{BASETOPIC} = $topic;
        $stags->{INCLUDINGWEB} = $web;
        $stags->{INCLUDINGTOPIC} = $topic;
    }

    $twiki->enterContext( 'can_render_meta', $meta );

    # Get the skin for this topic
    my $skin = Foswiki::Func::getSkin();
    Foswiki::Func::readTemplate( 'newsletter', $skin );
    my $header = Foswiki::Func::expandTemplate('NEWS:header');
    my $body   = Foswiki::Func::expandTemplate('NEWS:body');
    my $footer = Foswiki::Func::expandTemplate('NEWS:footer');

    my ( $revdate, $revuser, $maxrev );
    ( $revdate, $revuser, $maxrev ) = $meta->getRevisionInfo();

    # Handle standard formatting.
    $body =~ s/%TEXT%/$text/g;

    # Don't render the header, it is preformatted
    $header = Foswiki::Func::expandCommonVariables( $header, $topic, $web );
    my $tmpl = "$body\n$footer";
    $tmpl = Foswiki::Func::expandCommonVariables( $tmpl, $topic, $web );
    $tmpl = Foswiki::Func::renderText( $tmpl, "", $meta );

    # REFACTOR OPPORTUNITY: stop factor me into getTWikiRendering()
    # SMELL: this code is identical to PublishContrib!

    # New tags
    my $newTmpl = '';
    my $tagSeen = 0;
    my $publish = 1;
    foreach my $s ( split( /(%STARTPUBLISH%|%STOPPUBLISH%)/, $tmpl ) ) {
        if ( $s eq '%STARTPUBLISH%' ) {
            $publish = 1;
            $newTmpl = '' unless ($tagSeen);
            $tagSeen = 1;
        }
        elsif ( $s eq '%STOPPUBLISH%' ) {
            $publish = 0;
            $tagSeen = 1;
        }
        elsif ($publish) {
            $newTmpl .= $s;
        }
    }
    $tmpl = $header . $newTmpl;
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
    my $base = $Foswiki::cfg{DefaultUrlHost} . $Foswiki::cfg{ScriptUrlPath};
    $tmpl =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/goei;
    $tmpl =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/goei;

    my $report    = '';
    my $sentMails = 0;

    my %targets = map { $_ => 1 } @$emails;

    foreach my $email ( keys %targets ) {
        my $mail = $tmpl;

        $mail =~ s/%EMAILTO%/$email/go;

        my $base = $Foswiki::cfg{DefaultUrlHost} . $Foswiki::cfg{ScriptUrlPath};
        $mail =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/goei;
        $mail =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/goei;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

        my $error = Foswiki::Func::sendEmail( $mail, 5 );

        if ($error) {
            print STDERR "Error sending mail for $web: $error\n";
            $report .= $error . "\n";
        }
        else {
            print "Sent newletter for $web to $email\n" if $verbose;
            $sentMails++;
        }
    }
    $report .= "\t$sentMails newsletters from $web\n";

    Foswiki::Func::popTopicContext();

    # SMELL: See ** above
    if (defined $Foswiki::Plugins::SESSION->{SESSION_TAGS}) {

	    # In 1.0.6 and earlier, have to handle some session tags ourselves
	    # because pushTopicContext doesn't do it. **
        foreach my $macro (keys %old) {
            $Foswiki::Plugins::SESSION->{SESSION_TAGS}{$macro} =
            $old{$macro};
        }
    }

    return $report;
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
# Copyright (C) 2004 Wind River Systems Inc.
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
