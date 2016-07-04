
=pod

---+ package Foswiki::Plugins::HomePagePlugin

=cut

package Foswiki::Plugins::HomePagePlugin;

use strict;
use warnings;

use Foswiki::Func    ();
use Foswiki::Plugins ();

our $VERSION           = '1.23';
our $RELEASE           = '1.23';
our $SHORTDESCRIPTION  = 'Allow User specified home pages - on login';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {

    #my ( $topic, $web, $user, $installWeb ) = @_;
    return 1;
}

sub initializeUserHandler {
    my ( $loginName, $url, $pathInfo ) = @_;

    my $app = $Foswiki::app;
    my $req = $app->request;
    my $cfg = $app->cfg;

    return
      unless ( $app->inContext('view')
        || $app->inContext('login') );

    return
      if ( $app->inContext('command_line') );

    # Don't override web/topic if specified by url param.
    return
      if ( $app->request->param('defaultweb')
        || $app->request->param('topic') );

    my $gotoOnLogin =
      (       $cfg->data->{HomePagePlugin}{GotoHomePageOnLogin}
          and $app->inContext('login') );
    if ($gotoOnLogin) {
        my $test = $app->request->param('username');
        $loginName = $test if defined($test);

        # pre-load the origurl with the 'login' url which forces
        # templatelogin to use the requested web&topic
        $app->request->param(
            -name  => 'origurl',
            -value => $app->request->url()
        );
    }

    # we don't know the user at this point so can only set up the
    # site wide default
    my $path_info = Foswiki::urlDecode( $app->request->pathInfo );

    return
      unless ( ( $path_info eq '' or $path_info eq '/' )
        or ($gotoOnLogin) );

    my $siteDefault = $cfg->data->{HomePagePlugin}{SiteDefaultTopic};

    #$cfg->data->{HomePagePlugin}{HostnameMapping}
    my $hostName = lc( Foswiki::Func::getUrlHost() );
    if ( defined( $cfg->data->{HomePagePlugin}{HostnameMapping}->{$hostName} ) )
    {
        $siteDefault =
          $cfg->data->{HomePagePlugin}{HostnameMapping}->{$hostName};
    }

    my $wikiName = Foswiki::Func::getWikiName($loginName);
    if ( ( defined $wikiName )
        and
        Foswiki::Func::topicExists( $cfg->data->{UsersWebName}, $wikiName ) )
    {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $cfg->data->{UsersWebName}, $wikiName );

        # TODO: make fieldname a setting.
        my $field = $meta->get( 'FIELD', 'HomePage' );
        my $userHomePage;
        $userHomePage = $field->{value} if ( defined($field) );
        $siteDefault = $userHomePage
          if ( $userHomePage and ( $userHomePage ne '' ) );
    }

    if ( Foswiki::Func::webExists($siteDefault) ) {

        # if they only set a webname, dwim
        $siteDefault .= '.' . $cfg->data->{HomeTopicName};
    }

    return unless defined $siteDefault;

    my ( $web, $topic ) = $req->normalizeWebTopicName( '', $siteDefault );

    if (   Foswiki::Func::isValidWebName($web)
        && Foswiki::Func::isValidTopicName( $topic, 1 ) )
    {
        $req->web($web);
        $req->topic($topic);
    }

    return;
}

1;
__END__
Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (c) 2009-2011 Sven Dowideit, SvenDowideit@fosiki.com
Copyright (c) 2012-2015 Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

