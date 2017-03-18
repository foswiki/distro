# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Contrib::MailerContrib

Package of support for extended Web<nop>Notify notification, supporting per-topic notification and notification of changes to children.

Also supported is a simple API that can be used to change the Web<nop>Notify topic from other code.

=cut

package Foswiki::Contrib::MailerContrib;

use strict;
use warnings;

use URI ();
use CGI ();

use Assert;

use Foswiki                                    ();
use Foswiki::Plugins                           ();
use Foswiki::Time                              ();
use Foswiki::Func                              ();
use Foswiki::Contrib::MailerContrib::WebNotify ();
use Foswiki::Contrib::MailerContrib::Change    ();
use Foswiki::Contrib::MailerContrib::UpData    ();

# Also change Version/Release in Plugins/MailerContrib.pm
our $VERSION          = '2.84';
our $RELEASE          = '2.84';
our $SHORTDESCRIPTION = 'Supports email notification of changes';

# PROTECTED STATIC ensure the contrib is internally initialised
sub initContrib {
    $Foswiki::cfg{MailerContrib}{EmailFilterIn} ||=
      $Foswiki::regex{emailAddrRegex};
    $Foswiki::cfg{MailerContrib}{RespectUserPrefs} ||= 'LANGUAGE';
}

=begin TML

---++ StaticMethod mailNotify($webs, $exwebs)
   * =$webs= - filter list of names webs to process. Wildcards (*) may be used.
   * =$exwebs= - filter list of webs to exclude.
   * =%options%
      * =verbose= - true to get verbose (debug) output.
      * =news= - true to process news
      * =changes= - true to process changes
      * =reset= - true to reset the clock after processing
      * =mail= - true to send emails from this run 
Main entry point.

Process the Web<nop>Notify topics in each web and generate and issue
notification mails. Designed to be invoked from the command line; should
only be called by =mailnotify= scripts.

=cut

sub mailNotify {
    my ( $webs, $exwebs, %options ) = @_;

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

    my $context = Foswiki::Func::getContext();

    $context->{command_line} = 1;

    # absolute URL context for email generation
    $context->{absolute_urls} = 1;

    initContrib();

    foreach my $web ( Foswiki::Func::getListOfWebs('user ') ) {
        if ( $web =~ m/^($webstr)$/ && $web !~ /^($exwebstr)$/ ) {
            _processWeb( $web, \%options );
        }
    }

    $context->{absolute_urls} = 0;
}

=begin TML

---++ StaticMethod changeSubscription($web, $who, $topicList, $unsubscribe)

Modify a user's subscription in =WebNotify= for a web.
   * =$web= - web to edit the WebNotify for
   * =$who= - the user's wikiname
   * =$topicList= - list of topics to (un)subscribe to(from)
   * =$unsubscribe= - false to subscribe, true to unsubscribe

The current user must be able to modify WebNotify, or an access control
violation will be thrown.

=cut

sub changeSubscription {
    my ( $defaultWeb, $who, $topicList, $unsubscribe ) = @_;

    # we can get away with a normalise on a list of topics, so long as
    # the list starts with a topic
    my ( $web, $t ) =
      Foswiki::Func::normalizeWebTopicName( $defaultWeb, $topicList );

    #TODO: this limits us to subscribing to one web.
    my $wn =
      Foswiki::Contrib::MailerContrib::WebNotify->new( $web,
        $Foswiki::cfg{NotifyTopicName}, 1 );
    $wn->parsePageSubscriptions( $who, $topicList, $unsubscribe );
    $wn->writeWebNotify();
    return;
}

=begin TML

---++ isSubscribedTo ($web, $who, $topicList) -> boolean

Returns true if all topics mentioned in the =$topicList= are subscribed to by =$who=.

Can ignore all valid special characters that can be used on the WebNotify topic
such as NewsTopic! , TopicAndChildren (2)

=cut

sub isSubscribedTo {
    my ( $defaultWeb, $who, $topicList ) = @_;

    my $subscribed = {
        currentWeb => $defaultWeb,
        topicSub   => \&_isSubscribedToTopic,
        webs       => {}
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

    $subscribed->{webs}->{$sweb} ||=
      Foswiki::Contrib::MailerContrib::WebNotify->new( $sweb,
        $Foswiki::cfg{NotifyTopicName}, 0 );

    my $wn         = $subscribed->{webs}->{$sweb};
    my $subscriber = $wn->getSubscriber($who);
    my $db         = Foswiki::Contrib::MailerContrib::UpData->new($sweb);

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

=begin TML

---++ parsePageList ( $object, $who, $spec, $unsubscribe ) -> unprocessable remainder of =$spec= line
Calls =$object->{topicSub}= once per identified topic entry.
   * =$object= (a hashref) may be a hashref that has the field =topicSub=,
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
s/^\s*([-+])?\s*((?:[[:alnum:]]|[*.])+|'.*?'|".*?")([!?]?)\s*(?:\((\d+)\))?//
      )
    {
        my ( $us, $webTopic, $options, $childDepth ) =
          ( $unsubscribe || $1 || '+', $2, $3, $4 || 0 );
        $webTopic =~ s/^(['"])(.*)\1$/$2/;    # remove quotes
        &{ $object->{topicSub} }
          ( $object, $who, $us, $webTopic, $options, $childDepth );
    }
    return $spec;
}

# PRIVATE: Read the webnotify, and notify changes
sub _processWeb {
    my ( $web, $options ) = @_;

    if ( !Foswiki::Func::webExists($web) ) {

        # print STDERR "**** ERROR mailnotifier cannot find web $web\n";
        return '';
    }

    _UTF8print("Processing $web\n") if $options->{verbose};

    # Read the webnotify and load subscriptions
    my $wn =
      Foswiki::Contrib::MailerContrib::WebNotify->new( $web,
        $Foswiki::cfg{NotifyTopicName}, 0 );
    if ( $wn->isEmpty() ) {
        _UTF8print("\t$web has no subscribers\n") if $options->{verbose};
    }
    else {

        # create a DB object for parent pointers
        _UTF8print( $wn->stringify(1) ) if $options->{verbose};
        my $db = Foswiki::Contrib::MailerContrib::UpData->new($web);
        _processSubscriptions( $web, $wn, $db, $options );
    }
}

# Process subscriptions in $notify
sub _processSubscriptions {
    my ( $web, $notify, $db, $options ) = @_;

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

    if ( $options->{verbose} ) {
        _UTF8print( "\tLast notification was at "
              . Foswiki::Time::formatTime( $timeOfLastNotify, 'iso' )
              . "\n" );
    }

    my $timeOfLastChange = 0;

    # Hash indexed on name&email address, each entry contains a hash
    # of topics already processed in the change set for this name&email.
    # Each subhash maps the topic name to the index of the change
    # record for this topic in the array of Change objects for this
    # name&email in %changeset.
    my %seenset;

    # Hash indexed on name&email address, each entry contains an array
    # indexed by the index stored in %seenSet. Each entry in the array
    # is a ref to a Change object.
    my %changeset;

    # Hash indexed on topic name, mapping to name&email address, used to
    # record simple newsletter subscriptions.
    my %allSet;

    # + 1 because the 'since' check is >=
    my $it = Foswiki::Func::eachChangeSince( $web, $timeOfLastNotify + 1 );
    while ( $it->hasNext() ) {
        my $change = $it->next();
        next if $change->{minor};
        next if $change->{more} && $change->{more} =~ m/minor/;

        next unless Foswiki::Func::topicExists( $web, $change->{topic} );

        $timeOfLastChange = $change->{time} unless ($timeOfLastChange);

        _UTF8print( "\tChange to $change->{topic} at "
              . Foswiki::Time::formatTime( $change->{time}, 'iso' )
              . ". New revision is $change->{revision}\n" )
          if ( $options->{verbose} );

        # Formulate a change record, irrespective of
        # whether any subscriber is interested
        $change =
          Foswiki::Contrib::MailerContrib::Change->new( $web, $change->{topic},
            $change->{user}, $change->{time}, $change->{revision} );

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
    my %email2meta;
    if ( $options->{changes} && scalar( keys %changeset ) ) {
        _sendChangesMails( $web, \%changeset,
            Foswiki::Time::formatTime($timeOfLastNotify),
            \%email2meta, $options );
    }

    if ( $options->{news} ) {
        _sendNewsletterMails( $web, \%allSet, \%email2meta, $options );
    }

    if ( $options->{reset} && $timeOfLastChange != 0 ) {
        if ( open( F, '>', $notmeta ) ) {
            print F $timeOfLastChange;
            close(F);
        }
    }
}

# i18N doesn't change when we change LANGUAGE, so we have to stomp it.
sub _stompI18N {
    if ( $Foswiki::Plugins::SESSION->can('reset_i18n') ) {
        $Foswiki::Plugins::SESSION->reset_i18n();
    }
    elsif ( $Foswiki::Plugins::SESSION->{i18n} ) {

        # Muddy boots.
        $Foswiki::Plugins::SESSION->i18n->finish();
        undef $Foswiki::Plugins::SESSION->{i18n};
    }
}

sub _loadUserPreferences {
    my ( $name, $email, $email2meta, $oldPrefs ) = @_;

    my $meta = $email2meta->{$email};
    unless ( defined $meta ) {
        my @wn = Foswiki::Func::emailToWikiNames($email);

        # If the email maps to a single user, we can use their
        # preferences.
        # First check sanity of mappings.
        if ( scalar(@wn) == 1 ) {
            if ( $wn[0] ne $name ) {
                my $mess = 'MailerContrib Warning: surprising mapping'
                  . " $email => $wn[0] != $name";
                Foswiki::Func::writeDebug($mess);
            }
            $name = $wn[0];
        }
        elsif ( !grep { /^$name$/ } @wn ) {
            my $mess =
                'MailerContrib Warning: missing mapping'
              . " $email => ("
              . join( ',', @wn )
              . ") != $name";
            Foswiki::Func::writeDebug($mess);
        }
        my ( $uw, $ut ) =
          Foswiki::Func::normalizeWebTopicName( $Foswiki::cfg{UsersWebName},
            $name );
        $meta = Foswiki::Meta->new( $Foswiki::Plugins::SESSION, $uw, $ut );
        $email2meta->{$email} = $meta;
    }
    if ($meta) {
        foreach my $k (
            split( /[ ,]+/, $Foswiki::cfg{MailerContrib}{RespectUserPrefs} ) )
        {

            my $ov = Foswiki::Func::getPreferencesValue($k);
            my $nv = $meta->getPreference($k);
            if ( ( $nv || '' ) ne ( $ov || '' ) ) {
                $oldPrefs->{$k} = $ov;
                Foswiki::Func::setPreferencesValue( $k, $nv );
                _stompI18N() if ( $k eq 'LANGUAGE' );
            }
        }
    }
}

sub _restorePreferences {
    my ($oldPrefs) = @_;

    while ( my ( $k, $v ) = each %$oldPrefs ) {

        # Really we'd like to clear the session pref, but there's
        # no API to do that :-(
        Foswiki::Func::setPreferencesValue( $k, $v );
        _stompI18N() if ( $k eq 'LANGUAGE' );
    }
}

# PRIVATE generate and send an email for each user
sub _sendChangesMails {
    my ( $web, $changeset, $lastTime, $email2meta, $options ) = @_;

    # We read the mailnotify template in the context (skin and web) of the
    # WebNotify topic we are currently processing
    Foswiki::Func::pushTopicContext( $web, $Foswiki::cfg{NotifyTopicName} );
    my $skin = Foswiki::Func::getSkin();
    my $template = Foswiki::Func::readTemplate( 'mailnotify', $skin );
    Foswiki::Func::popTopicContext();

    my $sentMails = 0;

    foreach my $name_email ( keys %{$changeset} ) {
        my ( $name, $email ) = split( '&', $name_email, 2 );

        my %oldPrefs;
        _loadUserPreferences( $name, $email, $email2meta, \%oldPrefs );

        my $mail =
          Foswiki::Func::expandCommonVariables(
            Foswiki::Func::expandTemplate('MailNotifyBody'),
            $Foswiki::cfg{HomeTopicName}, $web );

        if ( $Foswiki::cfg{MailerContrib}{RemoveImgInMailnotify} ) {

            # change images to [alt] text if there, else remove image
            $mail =~ s/<img\s[^>]*\balt=\"([^\"]+)[^>]*>/[$1]/gi;
            $mail =~ s/<img\s[^>]*\bsrc=.*?[^>]>//gi;
        }

        $mail =~ s/%EMAILTO%/$email/g;
        $mail =~ s/%(HTML|PLAIN)_TEXT%/
             _generateChangeDetail($name_email, $changeset, $1, $web)/ge;
        $mail =~ s/%LASTDATE%/$lastTime/ge;

        my $base = $Foswiki::cfg{DefaultUrlHost} . $Foswiki::cfg{ScriptUrlPath};
        $mail =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/gei;
        $mail =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/gei;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gis;

        _restorePreferences( \%oldPrefs );

        my $error;
        if ( $options->{mail} ) {
            $error = Foswiki::Func::sendEmail( $mail, 5 );
        }
        else {
            _UTF8print($mail) if $options->{verbose};
        }

        if ($error) {
            print STDERR "Error sending mail for $web: $error\n";
            _UTF8print("$error\n");
        }
        else {
            _UTF8print("Notified $email of changes in $web\n")
              if $options->{verbose};
            $sentMails++;
        }
    }
    _UTF8print("\t$sentMails change notifications from $web\n")
      if $options->{verbose};
}

sub _generateChangeDetail {
    my ( $name_email, $changeset, $style, $web ) = @_;

    my @ep = ( $Foswiki::cfg{HomeTopicName}, $web );

    my $template = Foswiki::Func::expandTemplate( $style . ':middle' );
    my $diff_tmpl;
    my $text = '';
    my ( $name, $email ) = split( '&', $name_email, 2 );
    foreach my $change ( sort { $a->{TIME} cmp $b->{TIME} }
        @{ $changeset->{$name_email} } )
    {
        if ( $style eq 'HTML' ) {
            $text .= Foswiki::Func::expandCommonVariables(
                $change->expandHTML( $template, $name ), @ep );
        }
        elsif ( $style eq 'PLAIN' ) {
            $text .= Foswiki::Func::expandCommonVariables(
                $change->expandPlain( $template, $name ), @ep );
        }

        if ( $text =~ m/%DIFF_TEXT%/ ) {
            $diff_tmpl ||= Foswiki::Func::expandTemplate( $style . ':diff' );

            # Note: no macro expansion; this is a verbatim format
            $text =~ s/%DIFF_TEXT%/$change->expandDiff($diff_tmpl)/ge;
        }
    }
    return Foswiki::Func::expandCommonVariables(
        Foswiki::Func::expandTemplate( $style . ':before' ), @ep )
      . $text
      . Foswiki::Func::expandCommonVariables(
        Foswiki::Func::expandTemplate( $style . ':after' ), @ep );
}

sub relativeURL {
    my ( $base, $link ) = @_;
    if ( $link =~ "^#" ) {
        return $link;
    }
    else {
        return URI->new_abs( $link, URI->new($base) )->as_string;
    }
}

sub _sendNewsletterMails {
    my ( $web, $allSet, $email2meta, $options ) = @_;

    foreach my $topic ( keys %$allSet ) {
        _sendNewsletterMail( $web, $topic, $allSet->{$topic}, $email2meta,
            $options );
    }
}

sub _sendNewsletterMail {
    my ( $web, $topic, $name_emails, $email2meta, $options ) = @_;
    my $wikiName = Foswiki::Func::getWikiName();

    # SMELL: this code is almost identical to PublishContrib

    # Read topic data.
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    # SMELL: Have to hack into the core to set internal preferences :-(
    my %old =
      map { $_ => undef } qw(BASEWEB BASETOPIC INCLUDINGWEB INCLUDINGTOPIC);
    if ( defined $Foswiki::Plugins::SESSION->{SESSION_TAGS} ) {

        # In 1.0.6 and earlier, have to handle some session tags ourselves
        # because pushTopicContext doesn't do it. **
        foreach my $macro ( keys %old ) {
            $old{$macro} = Foswiki::Func::getPreferencesValue($macro);
        }
    }
    Foswiki::Func::pushTopicContext( $web, $topic );

    # See ** above
    if ( defined $Foswiki::Plugins::SESSION->{SESSION_TAGS} ) {
        my $stags = $Foswiki::Plugins::SESSION->{SESSION_TAGS};
        $stags->{BASEWEB}        = $web;
        $stags->{BASETOPIC}      = $topic;
        $stags->{INCLUDINGWEB}   = $web;
        $stags->{INCLUDINGTOPIC} = $topic;
    }

    # Only required pre-1.1
    Foswiki::Func::getContext()->{can_render_meta} = $meta;

    # Get the skin for this topic
    my $skin = Foswiki::Func::getSkin();
    Foswiki::Func::readTemplate( 'newsletter', $skin );
    my $h_tmpl = Foswiki::Func::expandTemplate('NEWS:header');
    my $body   = Foswiki::Func::expandTemplate('NEWS:body');
    my $footer = Foswiki::Func::expandTemplate('NEWS:footer');

    my ( $revdate, $revuser, $maxrev );
    ( $revdate, $revuser, $maxrev ) = $meta->getRevisionInfo();

    # Handle standard formatting.
    $body =~ s/%TEXT%/$text/g;

    my $sentMails = 0;

    foreach my $name_email (@$name_emails) {

        my ( $name, $email ) = split( '&', $name_email, 2 );

        # Set up user prefs
        my %oldPrefs;
        _loadUserPreferences( $name, $email, $email2meta, \%oldPrefs );

        # Don't render the header, it is preformatted
        my $header =
          Foswiki::Func::expandCommonVariables( $h_tmpl, $topic, $web );
        my $mail = "$body\n$footer";
        $mail = Foswiki::Func::expandCommonVariables( $mail, $topic, $web );
        $mail = Foswiki::Func::renderText( $mail, "", $meta );

        # REFACTOR OPPORTUNITY: stop factor me into getTWikiRendering()
        # SMELL: this code is identical to PublishContrib!

        # New tags
        my $newTmpl = '';
        my $tagSeen = 0;
        my $publish = 1;
        foreach my $s ( split( /(%STARTPUBLISH%|%STOPPUBLISH%)/, $mail ) ) {
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
        $mail = $header . $newTmpl;
        $mail =~ s/.*?<\/nopublish>//gs;
        $mail =~ s/%MAXREV%/$maxrev/g;
        $mail =~ s/%CURRREV%/$maxrev/g;
        $mail =~ s/%REVTITLE%//g;
        $mail =~ s|( ?) *</*nop/*>\n?|$1|gis;

        # Remove <base.../> tag
        $mail =~ s/<base[^>]+\/>//;

        # Remove <base...>...</base> tag
        $mail =~ s/<base[^>]+>.*?<\/base>//;

        # Rewrite absolute URLs
        my $base =
            $Foswiki::cfg{DefaultUrlHost}
          . $Foswiki::cfg{ScriptUrlPath}
          . "/view/"
          . $web . "/"
          . $topic;
        $mail =~ s/(href=\")([^"]+)/$1.relativeURL($base,$2)/gei;
        $mail =~ s/(action=\")([^"]+)/$1.relativeURL($base,$2)/gei;
        $mail =~ s/%EMAILTO%/$email/g;

        # remove <nop> and <noautolink> tags
        $mail =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gis;

        _restorePreferences( \%oldPrefs );

        my $error;
        if ( $options->{mail} ) {
            $error = Foswiki::Func::sendEmail( $mail, 5 );
        }
        else {
            _UTF8print($mail) if $options->{verbose};
        }

        if ($error) {
            print STDERR "Error sending mail for $web: $error\n";
            _UTF8print("$error\n");
        }
        else {
            _UTF8print("Sent newsletter $web.$topic to $email\n")
              if $options->{verbose};
            $sentMails++;
        }
    }
    _UTF8print("\t$sentMails newsletters from $web\n");

    Foswiki::Func::popTopicContext();

    # SMELL: See ** above
    if ( defined $Foswiki::Plugins::SESSION->{SESSION_TAGS} ) {

        # In 1.0.6 and earlier, have to handle some session tags ourselves
        # because pushTopicContext doesn't do it. **
        foreach my $macro ( keys %old ) {
            $Foswiki::Plugins::SESSION->{SESSION_TAGS}{$macro} = $old{$macro};
        }
    }
}

sub _UTF8print {
    if ($Foswiki::UNICODE) {
        print Foswiki::encode_utf8( $_[0] );
    }
    else {
        print $_[0];
    }
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. All Rights Reserved.
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
