# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::UI

Coordinator of execution flow and service functions used by the UI packages

=cut

package Foswiki::UI;

use Try::Tiny;
use Assert;
use CGI  ();
use JSON ();

use Foswiki                         ();
use Foswiki::Request                ();
use Foswiki::Response               ();
use Foswiki::Infix::Error           ();
use Foswiki::OopsException          ();
use Foswiki::EngineException        ();
use Foswiki::ValidationException    ();
use Foswiki::AccessControlException ();
use Foswiki::Validation             ();
use Foswiki::Exception              ();
use Foswiki::Request::Cache         ();

use Foswiki::Class qw<app>;
extends qw<Foswiki::Object>;

# Used to lazily load UI handler modules
#has isInitialized => ( is => 'rw', lazy => 1, default => sub { {} }, );

use constant TRACE_REQUEST => 0;

=begin TML

---++ METHODS

=cut

=begin TML

---+++ StaticMethod logon($app)

Handler for "logon" action.
   * =$app= is a Foswiki session object

=cut

sub logon {
    my $this = shift;
    my $app  = $this->app;
    my $req  = $app->request;

    if ( defined $app->cfg->data->{LoginManager}
        && $app->cfg->data->{LoginManager} eq 'none' )
    {
        throw Foswiki::OopsException(
            app      => $app,
            template => 'attention',
            status   => 500,
            def      => 'login_disabled',
        );
    }

    my $action = $req->param('foswikiloginaction');
    $req->delete('foswikiloginaction');

    if ( defined $action && $action eq 'validate' ) {
        Foswiki::Validation::validate($app);
    }
    else {
        $app->users->loginManager->login;
    }
}

=begin TML

---+++ ObjectMethod checkWebExists( $web [, $op] )

Check if the web exists. If it doesn't, will throw an oops exception.

 $op is the user operation being performed. $app->request->action is used if $op
 is undef.

=cut

sub checkWebExists {
    my $this = shift;
    my ( $webName, $op ) = @_;

    my $app = $this->app;
    $op //= $app->request->action;

    if ( $app->request->invalidWeb ) {
        throw Foswiki::OopsException(
            app      => $app,
            template => 'accessdenied',
            status   => 404,
            def      => 'bad_web_name',
            web      => $webName,
            topic    => $app->cfg->data->{WebPrefsTopicName},
            params   => [ $op, $app->request->invalidWeb ]
        );
    }
    unless ($webName) {
        throw Foswiki::OopsException(
            app      => $app,
            template => 'accessdenied',
            status   => 404,
            def      => 'bad_web_name',
            web      => $webName,
            topic    => $app->cfg->data->{WebPrefsTopicName},
            params   => [$op]
        );
    }

    unless ( $app->store->webExists($webName) ) {
        throw Foswiki::OopsException(
            app      => $app,
            template => 'accessdenied',
            status   => 404,
            def      => 'no_such_web',
            web      => $webName,
            topic    => $app->cfg->data->{WebPrefsTopicName},
            params   => [$op]
        );
    }
}

=begin TML

---+++ ObjectMethod topicExists( $web, $topic [, $op] ) => boolean

Check if the given topic exists, throwing an OopsException if it doesn't. $op is
the user operation being performed. $app->request->action is used if $op is
undef.

=cut

sub checkTopicExists {
    my $this = shift;
    my ( $web, $topic, $op ) = @_;

    my $app = $this->app;
    $op //= $app->request->action;

    if ( $app->request->invalidTopic ) {
        throw Foswiki::OopsException(
            app      => $app,
            template => 'accessdenied',
            status   => 404,
            def      => 'invalid_topic_name',
            web      => $web,
            topic    => $topic,
            params   => [ $op, $app->request->invalidTopic ]
        );
    }

    unless ( $app->store->topicExists( $web, $topic ) ) {
        throw Foswiki::OopsException(
            app      => $app,
            template => 'accessdenied',
            status   => 404,
            def      => 'no_such_topic',
            web      => $web,
            topic    => $topic,
            params   => [$op]
        );
    }
}

=begin TML

---+++ ObjectMethod checkAccess( $mode, $topicObject )

Check if the given mode of access by the given user to the given
web.topic is permissible, throwing a Foswiki::AccessControlException if not.

=cut

sub checkAccess {
    my $this = shift;
    my ( $mode, $topicObject ) = @_;

    my $app = $this->app;

    unless ( $topicObject->haveAccess($mode) ) {
        throw Foswiki::AccessControlException(
            mode   => $mode,
            user   => $app->user,
            web    => $topicObject->web,
            topic  => $topicObject->topic,
            reason => $Foswiki::Meta::reason
        );
    }
}

=begin TML

---+++ ObjectMethod checkValidationKey

Check the validation key for the given action. Throws an exception
if the validation key isn't valid (handled in _execute(), above)
   * =$app= - the current session object

See Foswiki::Validation for more information.

=cut

sub checkValidationKey {
    my $this = shift;

    my $app     = $this->app;
    my $req     = $app->request;
    my $users   = $app->users;
    my $cfgData = $app->cfg->data;

    # If validation is disabled, do nothing
    return if ( $cfgData->{Validation}{Method} eq 'none' );

    # No point in command-line mode
    return if $app->inContext('command_line');

    # Check the nonce before we do anything else
    my $nonce = $req->param('validation_key');
    $req->delete('validation_key');
    if (   !defined($nonce)
        || !Foswiki::Validation::isValidNonce( $users->getCGISession, $nonce ) )
    {
        throw Foswiki::ValidationException( action => $req->action );
    }
    if ( defined($nonce) && !$req->param('preserve_vk') ) {

        # Expire the nonce. If the user tries to use it again, they will
        # be prompted. Note that if preserve_vk is provided we don't
        # expire the nonce - this is to support browsers that don't
        # implement FormData in javascript (such as IE8)
        Foswiki::Validation::expireValidationKeys( $users->getCGISession(),
            $cfgData->{Validation}{ExpireKeyOnUse} ? $nonce : undef );

        # Write a new validation code into the response
        my $context = $req->url( -full => 1, -path => 1, -query => 1 ) . time();
        my $cgis = $users->getCGISession();
        if ($cgis) {
            my $nonce =
              Foswiki::Validation::generateValidationKey( $cgis, $context, 1 );
            $app->response->pushHeader( 'X-Foswiki-Validation' => $nonce );
        }
    }
    $req->delete('preserve_vk');
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Copyright (C) 2005 Martin at Cleaver.org
Copyright (C) 2005-2007 TWiki Contributors

and also based/inspired on Catalyst framework, whose Author is
Sebastian Riedel. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
for more credit and liscence details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
