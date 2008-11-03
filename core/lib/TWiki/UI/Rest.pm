# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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

---+ package TWiki::UI::Rest

UI delegate for REST interface

=cut

package TWiki::UI::Rest;

use strict;
use TWiki;
use Error qw( :try );

sub rest {
    my ( $twiki, %initialContext ) = @_;

    my $query = $twiki->{request};
    my $login = $query->param('username');
    my $pass  = $query->param('password');

    # Must define topic param in the query to avoid plugins being
    # passed the path_info when the are initialised. We can't affect
    # the path_info, but we *can* persuade TWiki to ignore it.
    my $topic = $query->param('topic');
    if ($topic) {
        unless ( $topic =~ /((?:.*[\.\/])+)(.*)/ ) {
            my $res = $twiki->{response};
            $res->header(
                -type   => 'text/html',
                -status => '400'
            );
            $res->body( "ERROR: (400) Invalid REST invocation"
                  . " - Invalid topic - no web specified\n" );
            throw TWiki::EngineException( 400,
                'ERROR: (400) Invalid REST invocation', $res );
        }
    }
    else {

        # Point it somewhere innocent
        $twiki->{webName}   = $TWiki::cfg{UsersWebName};
        $twiki->{topicName} = $TWiki::cfg{HomeTopicName};
    }

    if ($login) {
        my $validation = $twiki->{users}->checkPassword( $login, $pass );
        unless ($validation) {
            my $res = $twiki->{response};
            $res->header(
                -type   => 'text/html',
                -status => '401'
            );
            $res->body("ERROR: (401) Can't login as $login");
            throw TWiki::EngineException( 401,
                "ERROR: (401) Can't login as $login", $res );
        }

        my $cUID     = $twiki->{users}->getCanonicalUserID($login);
        my $WikiName = $twiki->{users}->getWikiName($cUID);
        $twiki->{users}->{loginManager}->userLoggedIn( $login, $WikiName );

#TODO: its a bit odd that $twiki->{user} has to be manually set (expected userLoggedIn would do it)
        $twiki->{user} = $cUID;
    }

    try {
        $twiki->{users}->{loginManager}->checkAccess();
    }
    catch Error with {
        my $e   = shift;
        my $res = $twiki->{response};
        $res->header(
            -type   => 'text/html',
            -status => '401'
        );
        $res->body("ERROR: (401) $e");
        throw TWiki::EngineException( 401, "ERROR: (401) $e", $res );
    };

    my $pathInfo = $query->path_info();

    unless ( $pathInfo =~ /\/(.*?)[\.\/](.*?)([\.\/].*?)*$/ ) {

        #TWiki rest invocations are defined as having a subject (pluginName)
        # and verb (restHandler in that plugin)
        my $res = $twiki->{response};
        $res->header(
            -type   => 'text/html',
            -status => '400'
        );
        $res->body("ERROR: (400) Invalid REST invocation");
        throw TWiki::EngineException( 401,
            "ERROR: (400) Invalid REST invocation", $res );
    }
    my ( $subject, $verb ) = ( $1, $2 );

    unless ( TWiki::isValidWikiWord($subject) ) {
        my $res = $twiki->{response};
        $res->header(
            -type   => 'text/html',
            -status => '404'
        );
        $res->body("ERROR: (404) Invalid REST invocation ($subject)");
        throw TWiki::EngineException( 401,
            "ERROR: (400) Invalid REST invocation ($subject)", $res );
    }

    my $function = $TWiki::restDispatch{$subject}{$verb};
    unless ($function) {
        my $res = $twiki->{response};
        $res->header(
            -type   => 'text/html',
            -status => '404'
        );
        $res->body("ERROR: (404) Invalid REST invocation ($verb on $subject)");
        throw TWiki::EngineException( 401,
            "ERROR: (400) Invalid REST invocation ($verb on $subject)", $res );
    }

    no strict 'refs';
    my $result = &$function( $twiki, $subject, $verb, $twiki->{response} );
    use strict 'refs';
    my $endPoint = $query->param('endPoint');
    if ( defined($endPoint) ) {
        $twiki->redirect( $twiki->getScriptUrl( 1, 'view', '', $endPoint ) );
    }
    else {
        $twiki->writeCompletePage($result) if $result;
    }
}

1;
