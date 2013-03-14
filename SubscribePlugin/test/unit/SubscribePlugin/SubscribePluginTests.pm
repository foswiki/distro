# See bottom of file for license and copyright information
use strict;
use warnings;

package SubscribePluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use Foswiki;
use CGI;
use Foswiki::Plugins::SubscribePlugin;
use Foswiki::Contrib::MailerContrib;

our $UI_FN;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

our $restURL;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('rest');
    $restURL =
      Foswiki::Func::getScriptUrlPath( 'SubscribePlugin', 'subscribe', 'rest' );
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_SUBSCRIBE_0 {
    my $this = shift;

    my $subscribe =
      Foswiki::Func::expandCommonVariables( '%SUBSCRIBE%', $this->{test_topic},
        $this->{test_web} );
    $this->assert_str_equals( '', $subscribe );
}

sub test_SUBSCRIBE_1 {
    my $this      = shift;
    my $subscribe = Foswiki::Func::expandCommonVariables(
        "%SUBSCRIBE{who=\"$this->{test_user_wikiname}\"}%",
        $this->{test_topic}, $this->{test_web} );
    $this->assert_html_equals( <<HTML, $subscribe );
<form class="subscribe_form" action="$restURL" method="POST">
<div class="subscribe_changing foswikiHidden">Changing...</div>
<input type="hidden" name="subscribe_topic" value="$this->{test_web}.$this->{test_topic}" />
<input type="hidden" name="subscribe_subscriber" value="$this->{test_user_wikiname}" />
<input type="hidden" name="subscribe_remove" value="0" />
<a class="subscribe_button">Subscribe</a>
</form>
HTML
}

sub test_SUBSCRIBE_2 {
    my $this = shift;

    # Unsubscribe
    my $subscribe = Foswiki::Func::expandCommonVariables(
'%SUBSCRIBE{who="TobermoryCat" topic="Kitties.Tobermory" unsubscribe="on"}%',
        $this->{test_topic}, $this->{test_web}
    );
    $this->assert_html_equals( <<HTML, $subscribe );
<form class="subscribe_form" action="$restURL" method="POST">
<div class="subscribe_changing foswikiHidden">Changing...</div>
<input type="hidden" name="subscribe_topic" value="Kitties.Tobermory" />
<input type="hidden" name="subscribe_subscriber" value="TobermoryCat" />
<input type="hidden" name="subscribe_remove" value="1"/>
<a class="subscribe_button">Unsubscribe</a>
</form>
HTML
}

sub test_SUBSCRIBE_format {
    my $this = shift;

    # format=
    my $url = Foswiki::Func::getScriptUrl(
        'SubscribePlugin', 'subscribe', 'rest',
        subscribe_topic      => "$this->{test_web}.$this->{test_topic}",
        subscribe_subscriber => $this->{test_user_wikiname},
        subscribe_remove     => 0
    );
    my $subscribe = Foswiki::Func::expandCommonVariables(
"%SUBSCRIBE{format=\"\$topics \$url \$wikiname \$action\" who=\"$this->{test_user_wikiname}\"}%",
        $this->{test_topic}, $this->{test_web}
    );
    $this->assert_html_equals( <<HTML, $subscribe );
$this->{test_topic} $url $this->{test_user_wikiname} Subscribe
HTML
}

sub test_SUBSCRIBE_formatunsubscribe {
    my $this = shift;

    # fomatunsubscribe=
    my $url = Foswiki::Func::getScriptUrl(
        'SubscribePlugin', 'subscribe', 'rest',
        subscribe_topic      => "$this->{test_web}.$this->{test_topic}",
        subscribe_subscriber => $this->{test_user_wikiname},
        subscribe_remove     => 1
    );
    my $subscribe = Foswiki::Func::expandCommonVariables(
"%SUBSCRIBE{formatunsubscribe=\"\$topics \$url \$wikiname \$action\" unsubscribe=\"yes\" who=\"$this->{test_user_wikiname}\"}%",
        $this->{test_topic}, $this->{test_web}
    );
    $this->assert_html_equals( <<HTML, $subscribe );
$this->{test_topic} $url $this->{test_user_wikiname} Unsubscribe
HTML
}

sub request {
    my $this = shift;
    my ( $response, $s, $so, $se ) = $this->capture( $UI_FN, $this->{session} );
    my ( $h, $b ) = split( /\n\n/, $response, 2 );
    my %headers =
      map { /(.*?):\s*(.*?)\s*$/, ( lc($1), $2 ) } split( /\n/, $h );
    return ( \%headers, $b );
}

sub checkWebNotify {
    my ( $this, $who, $what, $un ) = @_;
    ( my $web, $what ) =
      Foswiki::Func::normalizeWebTopicName( $this->{test_web}, $what );

    #print `cat $Foswiki::cfg{DataDir}/$web/WebNotify.txt`;
    my $is =
      Foswiki::Contrib::MailerContrib::isSubscribedTo( $web, $who, $what );
    $un ||= 0;
    $this->assert( ( $un && !$is ) || ( !$un && $is ), "$who $is $what ($un)" );
}

sub test_rest_subscribe {

    # Minimalist subscribe request
    my $this = shift;
    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info('/SubscribePlugin/subscribe');
    $query->method('post');
    $query->param( topic => "$this->{test_web}.$this->{test_topic}" );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $headers, $text ) = $this->request();
    $this->assert_equals( 200, $headers->{status} );
    $this->checkWebNotify( $this->{test_user_wikiname}, $this->{test_topic} );
}

sub test_rest_subscribe_2 {

    # make sure subscribe_topic overrides topic
    my $this = shift;
    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info('/SubscribePlugin/subscribe');
    $query->method('post');
    $query->param( topic                => "Bog.FootRot" );
    $query->param( subscribe_subscriber => "Colostomy.BagCollector" );
    $query->param( subscribe_topic => "$this->{test_web}.$this->{test_topic}" );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $headers, $text ) = $this->request();
    $this->assert_equals( 200, $headers->{status} );
    $this->checkWebNotify( 'Colostomy.BagCollector', $this->{test_topic} );
    $this->checkWebNotify( 'Colostomy.BagCollector', 'FootRot', 1 );
}

sub test_rest_subscribe_remove {

    # make sure subscribe_topic overrides topic
    my $this = shift;
    $this->test_rest_subscribe_2();    # to get the subscription set up
    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info('/SubscribePlugin/subscribe');
    $query->method('post');
    $query->param( subscribe_subscriber => "Colostomy.BagCollector" );
    $query->param( subscribe_topic => "$this->{test_web}.$this->{test_topic}" );
    $query->param( subscribe_remove => "yes" );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $headers, $text ) = $this->request();
    $this->assert_equals( 200, $headers->{status} );

    # Check it's removed
    $this->checkWebNotify( "$this->{test_web}.$this->{test_topic}",
        $this->{test_topic}, 1 );
}

sub test_rest_subscribe_bad {
    my $this = shift;
    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info('/SubscribePlugin/subscribe');
    $query->method('post');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $headers, $text ) = $this->request();
    $this->assert_equals( 400, $headers->{status} );
}

sub test_subscribe_all {
    my $this = shift;
    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info('/SubscribePlugin/subscribe');
    $query->method('post');
    $query->param( subscribe_subscriber => $this->{test_user_wikiname} );
    $query->param( subscribe_topic      => "$this->{test_web}.*" );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $headers, $text ) = $this->request();
    $this->assert_equals( 200, $headers->{status}, $text );
    $this->checkWebNotify( $this->{test_user_wikiname},
        "$this->{test_web}/WebNotify" );
}

sub test_subscribe_subweb {
    my $this = shift;
    $this->populateNewWeb("$this->{test_web}/SubWeb");
    my $query = Unit::Request->new( { action => ['rest'], } );
    $query->path_info('/SubscribePlugin/subscribe');
    $query->method('post');
    $query->param( subscribe_subscriber => $this->{test_user_wikiname} );
    $query->param( subscribe_topic      => "$this->{test_web}/SubWeb.*" );
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ( $headers, $text ) = $this->request();
    $this->assert_equals( 200, $headers->{status}, $text );
    $this->checkWebNotify( $this->{test_user_wikiname},
        "$this->{test_web}/SubWeb/WebNotify" );
    $this->checkWebNotify( $this->{test_user_wikiname},
        "$this->{test_web}/SubWeb/WebPreferences" );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: CrawfordCurrie

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
