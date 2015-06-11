# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Users::BaseUserMapping

User mapping is the process by which Foswiki maps from a username
(a login name)
to a display name and back. It is also where groups are maintained.

The BaseMapper provides support for a small number of predefined users.
No registration - this is a read only usermapper. It uses the mapper
prefix 'BaseUserMapping_'.

---++ Users
   * $Foswiki::cfg{AdminUserLogin} - uses the password that
     was set in Configure (IF its not null)
   * $Foswiki::cfg{DefaultUserLogin} - WikiGuest
   * UnknownUser
   * ProjectContributor
   * $Foswiki::cfg{Register}{RegistrationAgentWikiName}

---+++ Groups
   * $Foswiki::cfg{SuperAdminGroup}
   * BaseGroup

=cut

package Foswiki::Users::BaseUserMapping;
use strict;
use warnings;

use Foswiki::UserMapping ();
our @ISA = ('Foswiki::UserMapping');

use Assert;
use Encode;
use Error ();
use Digest::MD5 qw(md5_hex);
use Crypt::PasswdMD5 qw(apache_md5_crypt);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our $DEFAULT_USER_CUID = 'BaseUserMapping_666';
our $UNKNOWN_USER_CUID = 'BaseUserMapping_999';
our %BASE_USERS;
our %BASE_GROUPS;

=begin TML

---++ ClassMethod new ($session)

Construct the BaseUserMapping object

=cut

# Constructs a new user mapping handler of this type, referring to $session
# for any required Foswiki services.
sub new {
    my ( $class, $session ) = @_;

    # $DEFAULT_USER_CUID , $UNKNOWN_USER_CUID, %BASE_USERS and %BASE_GROUPS
    # could be initialised statically, but tests have been written that rely
    # on being able to override the $Foswiki::cfg settings that are part of
    # them. Since it's a low cost op to re-initialise them each time this
    # singleton is built, we will contiue to do so (at least until those
    # tests have been revisited)
    $DEFAULT_USER_CUID = 'BaseUserMapping_666';
    $UNKNOWN_USER_CUID = 'BaseUserMapping_999';
    %BASE_USERS        = (
        BaseUserMapping_111 => {
            login    => 'ProjectContributor',
            wikiname => 'ProjectContributor',
        },
        BaseUserMapping_222 => {
            login => $Foswiki::cfg{Register}{RegistrationAgentWikiName}
              || 'RegistrationAgent',
            wikiname => $Foswiki::cfg{Register}{RegistrationAgentWikiName}
              || 'RegistrationAgent',
        },
        BaseUserMapping_333 => {
            login    => $Foswiki::cfg{AdminUserLogin}    || 'admin',
            wikiname => $Foswiki::cfg{AdminUserWikiName} || 'AdminUser',
            email    => $Foswiki::cfg{WebMasterEmail}    || 'email not set',
            password => $Foswiki::cfg{Password},
        },
        $DEFAULT_USER_CUID => {
            login    => $Foswiki::cfg{DefaultUserLogin}    || 'guest',
            wikiname => $Foswiki::cfg{DefaultUserWikiName} || 'WikiGuest',
        },
        $UNKNOWN_USER_CUID => {
            login    => 'unknown',
            wikiname => 'UnknownUser',
        }
    );
    %BASE_GROUPS = (
        $Foswiki::cfg{SuperAdminGroup} => [
            'BaseUserMapping_333',

# Registration agent was here so registration can still take
# place on an otherwise locked down USERSWEB.
# Jan2010: Sven removed it, otherwise anyone registering can add themselves as admin.
#'BaseUserMapping_222'
        ],
        BaseGroup => [
            'BaseUserMapping_333', $DEFAULT_USER_CUID,
            $UNKNOWN_USER_CUID,    'BaseUserMapping_111',
            'BaseUserMapping_222',
        ],

        #         RegistrationGroup => ['BaseUserMapping_222']
    );

    my $this = $class->SUPER::new( $session, 'BaseUserMapping_' );
    $Foswiki::cfg{Register}{RegistrationAgentWikiName} ||= 'RegistrationAgent';

    # set up our users
    $this->{L2U} = {};    # login 2 cUID
    $this->{U2L} = {};    # cUID 2 login
    $this->{W2U} = {};    # wikiname 2 cUID
    $this->{U2W} = {};    # cUID 2 wikiname
    $this->{U2E} = {};    # cUID 2 email
    $this->{L2P} = {};    # login 2 password

    while ( my ( $k, $v ) = each %BASE_USERS ) {
        $this->{U2L}->{$k} = $v->{login};
        $this->{U2W}->{$k} = $v->{wikiname};
        $this->{U2E}->{$k} = $v->{email} if defined $v->{email};

        $this->{L2U}->{ $v->{login} } = $k;
        $this->{L2P}->{ $v->{login} } = $v->{password}
          if defined $v->{password};

        $this->{W2U}->{ $v->{wikiname} } = $k;
    }

    %{ $this->{GROUPS} } = %BASE_GROUPS;

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{U2L};
    undef $this->{U2W};
    undef $this->{L2P};
    undef $this->{U2E};
    undef $this->{L2U};
    undef $this->{W2U};
    undef $this->{GROUPS};
    $this->SUPER::finish();
}

=begin TML

---++ ObjectMethod loginTemplateName () -> templateFile

allows UserMappings to come with customised login screens - that should preffereably only over-ride the UI function

=cut

sub loginTemplateName {
    return 'login.sudo';
}

=begin TML

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

See baseclass for documentation.

In the BaseUserMapping case, we know all
the details of the users we specialise in.

=cut

sub handlesUser {
    my ( $this, $cUID, $login, $wikiname ) = @_;

    return 1 if ( defined($cUID)     && defined( $this->{U2L}{$cUID} ) );
    return 1 if ( defined($login)    && defined( $this->{L2U}{$login} ) );
    return 1 if ( defined($wikiname) && defined( $this->{W2U}{$wikiname} ) );

    return 0;
}

=begin TML

---++ ObjectMethod login2cUID ($login) -> $cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

=cut

sub login2cUID {
    my ( $this, $login ) = @_;

    return $this->{L2U}{$login};

    #alternative impl - slower, but more re-useable
    #my @list = findUserByWikiName($this, $login);
    #return shift @list;
}

=begin TML

---++ ObjectMethod getLoginName ($cUID) -> login

converts an internal cUID to that user's login
(undef on failure)

=cut

sub getLoginName {
    my ( $this, $user ) = @_;
    return $this->{U2L}{$user};
}

=begin TML

---++ ObjectMethod getWikiName ($cUID) -> wikiname

Map a canonical user name to a wikiname

=cut

sub getWikiName {
    my ( $this, $cUID ) = @_;
    return $this->{U2W}->{$cUID} || getLoginName( $this, $cUID );
}

=begin TML

---++ ObjectMethod userExists( $user ) -> $boolean

Determine if the user already exists or not.

=cut

sub userExists {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;
    return 0 unless defined $cUID;
    return $this->{U2L}{$cUID};
}

=begin TML

---++ ObjectMethod eachUser () -> listIterator of cUIDs

See baseclass for documentation.

=cut

sub eachUser {
    my ($this) = @_;

    my @list = keys( %{ $this->{U2W} } );
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

=begin TML

---++ ObjectMethod eachGroupMember ($group) ->  listIterator of cUIDs

See baseclass for documentation.

The basemapper implementation assumes that there are no nested groups in the
basemapper.

=cut

sub eachGroupMember {
    my $this  = shift;
    my $group = shift;

    my $members = $this->{GROUPS}{$group};

    #print STDERR "eachGroupMember($group): ".join(',', @{$members});

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator($members);
}

=begin TML

---++ ObjectMethod isGroup ($name) -> boolean

See baseclass for documentation.

=cut

sub isGroup {
    my ( $this, $name ) = @_;
    $name ||= "";

    #TODO: what happens to the code if we implement this using an iterator too?
    return ( $this->{GROUPS}->{$name} );
}

=begin TML

---++ ObjectMethod eachGroup () -> ListIterator of groupnames

See baseclass for documentation.

=cut

sub eachGroup {
    my ($this) = @_;
    my @groups = keys( %{ $this->{GROUPS} } );

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@groups );
}

=begin TML

---++ ObjectMethod eachMembership ($cUID) -> ListIterator of groups this user is in

See baseclass for documentation.

=cut

sub eachMembership {
    my ( $this, $cUID ) = @_;

    my $it = $this->eachGroup();
    $it->{filter} = sub {
        $this->isInGroup( $cUID, $_[0] );
    };
    return $it;
}

=begin TML

---++ ObjectMethod groupAllowsChange($group) -> boolean

returns 0 if the group is 'owned by the BaseMapper and it wants to veto adding to that group

=cut

sub groupAllowsChange {
    my $this  = shift;
    my $group = shift;
    ASSERT( defined $group ) if DEBUG;

    return 0
      if ( ( $group eq 'BaseGroup' )
        or ( $group eq 'RegistrationGroup' ) );
    return 1;
}

=begin TML

---++ ObjectMethod isAdmin( $cUID ) -> $boolean

True if the user is an admin
   * is a member of the $Foswiki::cfg{SuperAdminGroup}

=cut

sub isAdmin {
    my ( $this, $cUID ) = @_;
    return $this->isInGroup( $cUID, $Foswiki::cfg{SuperAdminGroup} );
}

=begin TML

---++ ObjectMethod getEmails($name) -> @emailAddress

If $name is a cUID, return their email addresses. If it is a group,
return the addresses of everyone in the group.

=cut

sub getEmails {
    my ( $this, $user ) = @_;

    return $this->{U2E}{$user} || ();
}

=begin TML

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

See baseclass for documentation.

=cut

sub findUserByWikiName {
    my ( $this, $wn ) = @_;
    my @users = ();

    if ( $this->isGroup($wn) ) {
        push( @users, $wn );
    }
    else {

        # Add additional mappings defined in WikiUsers
        if ( $this->{W2U}->{$wn} ) {
            push( @users, $this->{W2U}->{$wn} );
        }
        elsif ( $this->{L2U}->{$wn} ) {

           # The wikiname is also a login name for the purposes of this
           # mapping. We have to do this because Foswiki defines access controls
           # in terms of mapped users, and if a wikiname is *missing* from the
           # mapping there is "no such user".
            push( @users, $this->{L2U}->{$wn} );
        }
    }
    return \@users;
}

=begin TML

---++ ObjectMethod checkPassword( $login, $passwordU ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my ( $this, $login, $pass ) = @_;

    my $hash = $this->{L2P}->{$login};

    # All of the digest / hash routines require bytes
    $pass = Encode::encode_utf8($pass);

    if ($hash) {
        if ( length($hash) == 13 ) {
            return 1 if ( crypt( $pass, $hash ) eq $hash );
        }
        elsif ( length($hash) == 42 ) {
            my $salt = substr( $hash, 0, 10 );
            return 1
              if ( $salt . Digest::MD5::md5_hex( $salt . $pass ) eq $hash );
        }
        else {
            my $salt = substr( $hash, 0, 14 );
            return 1
              if (
                Crypt::PasswdMD5::apache_md5_crypt( $pass, $salt ) eq $hash );
        }
    }

    # be a little more helpful to the admin
    if ( $login eq $Foswiki::cfg{AdminUserLogin} && !$hash ) {
        $this->{error} =
          'To login as ' . $login . ', you must set {Password} in configure.';
    }
    return 0;
}

=begin TML

---++ ObjectMethod setPassword( $cUID, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
    my ( $this, $cUID, $newPassU, $oldPassU ) = @_;
    throw Error::Simple(
        'cannot change user passwords using Foswiki::BaseUserMapping');
}

=begin TML

---++ ObjectMethod passwordError( ) -> $string

returns a string indicating the error that happened in the password handlers
TODO: these delayed error's should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my $this = shift;

    return $this->{error};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this file:

Copyright (C) 2007 Sven Dowideit, SvenDowideit@distributedINFORMATION.com
and TWiki Contributors. All Rights Reserved. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
