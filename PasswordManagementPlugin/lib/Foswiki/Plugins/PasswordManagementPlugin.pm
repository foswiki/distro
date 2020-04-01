# See bottom of file for default license and copyright information

# Note that POD in this module is included in the documentation topic
# by BuildContrib

=pod

---++ REST Call (RPC) interface

This plugin implements the REST handler used for:
   * Password Change
   * Password Reset
   * Email Change

=cut

package Foswiki::Plugins::PasswordManagementPlugin;

use strict;
use warnings;

our $VERSION = '1.01';
our $RELEASE = '02 Oct 2017';
our $SHORTDESCRIPTION =
  '=REST= interface for managing User passwords and Emails.';
our $NO_PREFS_IN_TOPIC = 1;

use Assert;

use Foswiki::Contrib::JsonRpcContrib ();
use Foswiki::Configure::Auth         ();
use Foswiki::Configure::LoadSpec     ();
use Foswiki::Configure::Load         ();
use Foswiki::Configure::Root         ();
use Foswiki::Configure::Reporter     ();
use Foswiki::Configure::Checker      ();
use Foswiki::Configure::Wizard       ();
use Foswiki::Configure::Query        ();

use constant TRACE => 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerRESTHandler(
        'resetPassword', \&_RESTresetPassword,
        validate => $Foswiki::cfg{Validation}{Method} eq 'none' ? 0 : 1,
        authenticate => 0,
        http_allow   => 'POST',
        description  => 'Generate a Passord reset token and email to the user.',
    );

    Foswiki::Func::registerRESTHandler(
        'bulkResetPassword', \&_RESTbulkResetPassword,
        validate => $Foswiki::cfg{Validation}{Method} eq 'none' ? 0 : 1,
        authenticate => 1,
        http_allow   => 'POST',
        description  => 'Generate and send a Passord reset token for multiple users.',
    );

    Foswiki::Func::registerRESTHandler(
        'changePassword', \&_RESTchangePassword,
        authenticate => 1,
        validate     => $Foswiki::cfg{Validation}{Method} eq 'none' ? 0 : 1,
        http_allow   => 'POST',
        description  => 'Change the user\'s password to a new password.',
    );

    Foswiki::Func::registerRESTHandler(
        'changeEmail', \&_RESTchangeEmail,
        authenticate => 1,
        validate     => $Foswiki::cfg{Validation}{Method} eq 'none' ? 0 : 1,
        http_allow   => 'POST',
        description  => 'Change the user\'s email address.',
    );

    return 1;

}

=begin TML

---++ =sub _RESTresetPassword=

Generate a reset for a user's passord

   * generates a crypographic token that will allow login to Foswiki
   * Email the token to the user.

=cut

sub _RESTresetPassword {
    require Foswiki::Plugins::PasswordManagementPlugin::Core;
    return
      Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(@_);
}

=begin TML

---++ =sub _RESTbulkResetPassword=

Generate a reset for a user's passord

   * generates a crypographic token that will allow login to Foswiki
   * Email the token to the user.

=cut

sub _RESTbulkResetPassword {
    require Foswiki::Plugins::PasswordManagementPlugin::Core;
    return
      Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTbulkResetPassword(@_);
}

=begin TML

---++ =sub _RESTchangePassword=

Generate a reset for a user's passord

   * generates a crypographic token that will allow login to Foswiki
   * Email the token to the user.

=cut

sub _RESTchangePassword {
    require Foswiki::Plugins::PasswordManagementPlugin::Core;
    return
      Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTchangePassword(@_);
}

=begin TML

---++ =sub _RESTchangeEmail=

Generate a reset for a user's passord

   * generates a crypographic token that will allow login to Foswiki
   * Email the token to the user.

=cut

sub _RESTchangeEmail {
    require Foswiki::Plugins::PasswordManagementPlugin::Core;
    return Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTchangeEmail(
        @_);
}

=pod

---++ Invocation examples

Call using a URL of the format:

=%SCRIPTURL{"jsonrpc"}%/configure=

while POSTing a request encoded according to the JSON-RPC 2.0 specification:

<verbatim>
{
  jsonrpc: "2.0", 
  method: "getspec", 
  params: {
     get : { keys: "{DataDir}" },
     depth : 0
  }, 
  id: "caller's id"
}
</verbatim>

---++ .spec format
The format of .spec files is documented in detail in
There are two node types in the .spec tree:

SECTIONs have:
   * =headline= (default =UNKNOWN=, the root is usually '')
   * =typename= (always =SECTION=)
   * =children= - array of child nodes (sections and keys)
 
Key entries (such as ={DataDir}=) have:
   * =keys= e.g. ={Store}{Cupboard}=
   * =typename= (from the .spec)
   * Other keys from the .spec e.g. =SIZE=, =FEEDBACK=, =CHECK=

=cut

1;

__END__

Author: George Clark 

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2017 Foswiki Contributors. Foswiki Contributors
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
