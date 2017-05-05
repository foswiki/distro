# Copyright (C) 2007-2017 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatEditPlugin;

use strict;
use warnings;

use Foswiki::Func       ();
use Foswiki::Plugins    ();
use Foswiki::Validation ();
use Foswiki::Request    ();
use Foswiki::Sandbox    ();

BEGIN {
    # Backwards compatibility for Foswiki 1.1.x
    unless ( Foswiki::Request->can('multi_param') ) {
        no warnings 'redefine';
        *Foswiki::Request::multi_param = \&Foswiki::Request::param;
        use warnings 'redefine';
    }
}

our $VERSION           = '9.09';
our $RELEASE           = '04 May 2017';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION  = 'A Wikiwyg Editor';
our $baseWeb;
our $baseTopic;
our $doneNonce;

use constant TRACE => 0;    # toggle me

###############################################################################
sub writeDebug {
    return unless TRACE;
    print STDERR "- NatEditPlugin - " . $_[0] . "\n";

    #Foswiki::Func::writeDebug("- NatEditPlugin - $_[0]");
}

###############################################################################
sub initPlugin {
    ( $baseTopic, $baseWeb ) = @_;

    Foswiki::Func::registerTagHandler(
        'NATFORMBUTTON',
        sub {
            require Foswiki::Plugins::NatEditPlugin::FormButton;
            return Foswiki::Plugins::NatEditPlugin::FormButton::handle(@_);
        }
    );
    Foswiki::Func::registerTagHandler(
        'NATFORMLIST',
        sub {
            require Foswiki::Plugins::NatEditPlugin::FormList;
            return Foswiki::Plugins::NatEditPlugin::FormList::handle(@_);
        }
    );

    # SMELL: wrapper around normal save not being able to handle
    # utf8->sitecharset conversion.
    Foswiki::Func::registerRESTHandler(
        'save',
        sub {
            require Foswiki::Plugins::NatEditPlugin::RestSave;
            return Foswiki::Plugins::NatEditPlugin::RestSave::handle(@_);
        },
        authenticate => 1,         # save always requires authentication
        validate     => 1,         # and validation
        http_allow   => 'POST',    # updates: restrict to POST.
        description => 'Save or preview results of an edit.'
    );

    Foswiki::Func::registerRESTHandler(
        "attachments",
        sub {
            require Foswiki::Plugins::NatEditPlugin::RestAttachments;
            return Foswiki::Plugins::NatEditPlugin::RestAttachments::handle(@_);
        },
        authenticate => 0,             # handler checks it's own security.
        validate     => 0,             # doesn't update.
        http_allow   => 'GET,POST',    # doesn't update.
        description => 'Expand the list of attachments.'
    );

    $doneNonce = 0;

    return 1;
}

###############################################################################
# This function will store the TopicTitle in a preference variable if it isn't
# part of the DataForm of this topic. In a way, we do the reverse of
# WebDB::onReload() where the TopicTitle is extracted and put into the cache.
sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    writeDebug("called beforeSaveHandler($web, $topic)");

    # find out if we received a TopicTitle
    my $request = Foswiki::Func::getCgiQuery();

    my $newTopic = $request->param('newtopic');
    $newTopic = Foswiki::Sandbox::untaint( $newTopic,
        \&Foswiki::Sandbox::validateTopicName );

    my $topicTitle = $request->param('TopicTitle');
    $topicTitle = Foswiki::Sandbox::untaintUnchecked($topicTitle);

# the "newtopic" urlparam either holds a new topic name in case of a rename action,
# or a boolean flag indicating that the topic being created is a new topic
    if (   defined($newTopic)
        && $newTopic ne ''
        && $newTopic ne '1'
        && $newTopic ne $topic )
    {
        writeDebug("not saving the topic being rename ... no action");
        return;
    }

    unless ( defined $topicTitle ) {
        writeDebug("didn't get a TopicTitle, nothing do here");
        return;
    }

    if ( $topicTitle =~ m/X{10}|AUTOINC\d/ ) {
        writeDebug("ignoring topic being auto-generated");
        return;
    }

    my $fieldTopicTitle = $meta->get( 'FIELD', 'TopicTitle' );
    writeDebug("topic=$web.$topic, topicTitle=$topicTitle");

    if ( $topicTitle eq $topic ) {
        writeDebug("same as topic name ... nulling");
        $request->param( "TopicTitle", "" );
        $topicTitle = '';
        if ( defined $fieldTopicTitle ) {
            $fieldTopicTitle->{value} = "";
        }
    }

    # find out if this topic can store the TopicTitle in its metadata
    if ( defined $fieldTopicTitle ) {
        writeDebug("storing it into the formfield");

        # however, check if we've got a TOPICTITLE preference setting
        # if so remove it. this happens if we stored a topic title but
        # then added a form that now takes the topic title instead
        if ( defined $meta->get( 'PREFERENCE', 'TOPICTITLE' ) ) {
            writeDebug("removing redundant TopicTitles in preferences");
            $meta->remove( 'PREFERENCE', 'TOPICTITLE' );
        }

        $fieldTopicTitle->{value} = $topicTitle;
        return;
    }

    writeDebug("we need to store the TopicTitle in the preferences");

    # if it is a topic setting, override it.
    my $topicTitleHash = $meta->get( 'PREFERENCE', 'TOPICTITLE' );
    if ( defined $topicTitleHash ) {
        writeDebug(
"found old TopicTitle in preference settings: $topicTitleHash->{value}"
        );
        if ($topicTitle) {

            # set the new value
            $topicTitleHash->{value} = $topicTitle;
        }
        else {

            # remove the value if the new TopicTitle is an empty string
            $meta->remove( 'PREFERENCE', 'TOPICTITLE' );
        }
        return;
    }

    writeDebug("no TopicTitle in preference settings");

    # if it is a bullet setting, replace it.
    if ( $text =~
s/((?:^|[\n\r])(?:\t|   )+\*\s+(?:Set|Local)\s+TOPICTITLE\s*=\s*)(.*)((?:$|[\r\n]))/$1$topicTitle$3/
      )
    {
        writeDebug("found old TopicTitle defined as a bullet setting: $2");
        $_[0] = $text;
        return;
    }

    writeDebug(
        "no TopicTitle stored anywhere. creating a new preference setting");

    if ($topicTitle) {    # but only if we don't set it to the empty string
        $meta->putKeyed(
            'PREFERENCE',
            {
                name  => 'TOPICTITLE',
                title => 'TOPICTITLE',
                type  => 'Local',
                value => $topicTitle
            }
        );
    }
}

###############################################################################
# make sure there's a new nonce for consecutive save+continues
sub beforeEditHandler {
    my ( $text, $topic, $web, $error, $meta ) = @_;

    return if $doneNonce;
    $doneNonce = 1;

    my $session = $Foswiki::Plugins::SESSION;
    my $cgis    = $session->getCGISession();
    return unless $cgis;

    my $response = $session->{response};
    my $request  = $session->{request};

    my $context = $request->url( -full => 1, -path => 1, -query => 1 ) . time();
    my $useStrikeOne = ( $Foswiki::cfg{Validation}{Method} eq 'strikeone' );
    my $nonce;

    if ( Foswiki::Validation->can('generateValidationKey') ) {

        # newer foswikis have a proper api for things like this
        $nonce = Foswiki::Validation::generateValidationKey( $cgis, $context,
            $useStrikeOne );
    }
    else {

        # older ones get a quick and dirty approach
        my $result = Foswiki::Validation::addValidationKey( $cgis, $context,
            $useStrikeOne );
        if ( $result =~ m/value='(.*)'/ ) {
            $nonce = $1;
        }
    }

    #print STDERR "nonce=$nonce\n";

    $response->pushHeader( 'X-Foswiki-Validation', $nonce ) if defined $nonce;
}

1;
