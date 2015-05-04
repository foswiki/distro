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

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $Foswiki::cfg{Validation}{Method} = 'none';
    $UI_FN ||= $this->getUIFn('rest');
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

    $subscribe =~ s/data-validation-key=".*" //g;
    $this->assert_html_equals( <<HTML, $subscribe );
<a href="#" class="subscribe_link" data-topic="TemporarySubscribePluginTestsTestWebSubscribePluginTests.TestTopicSubscribePluginTests" data-subscriber="ScumBag" data-remove="0">Subscribe</a>
HTML
}

sub test_SUBSCRIBE_2 {
    my $this = shift;

    # Unsubscribe
    my $subscribe = Foswiki::Func::expandCommonVariables(
'%SUBSCRIBE{who="TobermoryCat" topic="Kitties.Tobermory" unsubscribe="on"}%',
        $this->{test_topic}, $this->{test_web}
    );

    $subscribe =~ s/data-validation-key=".*" //g;

    $this->assert_html_equals( <<HTML, $subscribe );
<a href="#" class="subscribe_link" data-topic="Kitties.Tobermory" data-subscriber="TobermoryCat" data-remove="1" >Unsubscribe</a>
HTML
}

sub test_SUBSCRIBE_format {
    my $this = shift;

    # format=
    my $subscribe = Foswiki::Func::expandCommonVariables(
"%SUBSCRIBE{format=\"\$topic \$wikiname \$action\" who=\"$this->{test_user_wikiname}\"}%",
        $this->{test_topic}, $this->{test_web}
    );
    $this->assert_html_equals( <<HTML, $subscribe );
$this->{test_web}.$this->{test_topic} $this->{test_user_wikiname} Subscribe
HTML
}

sub test_SUBSCRIBE_formatunsubscribe {
    my $this = shift;

    # fomatunsubscribe=
    my $subscribe = Foswiki::Func::expandCommonVariables(
"%SUBSCRIBE{formatunsubscribe=\"\$topic \$wikiname \$action\" unsubscribe=\"yes\" who=\"$this->{test_user_wikiname}\"}%",
        $this->{test_topic}, $this->{test_web}
    );
    $this->assert_html_equals( <<HTML, $subscribe );
$this->{test_web}.$this->{test_topic} $this->{test_user_wikiname} Unsubscribe
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
    my $query = Unit::Request->new( { action => ['rest'] } );
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
    $query->param( topic      => "Bog.FootRot" );
    $query->param( subscriber => "Colostomy.BagCollector" );
    $query->param( topic      => "$this->{test_web}.$this->{test_topic}" );
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
    $query->param( subscriber => "Colostomy.BagCollector" );
    $query->param( topic      => "$this->{test_web}.$this->{test_topic}" );
    $query->param( remove     => "yes" );
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
    $query->param( subscriber => $this->{test_user_wikiname} );
    $query->param( topic      => "$this->{test_web}.*" );
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
    $query->param( subscriber => $this->{test_user_wikiname} );
    $query->param( topic      => "$this->{test_web}/SubWeb.*" );
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
