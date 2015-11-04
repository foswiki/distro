# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UserMapping

This is a virtual base class (a.k.a an interface) for all user mappers. It is
*not* useable as a mapping in Foswiki - use the BaseUserMapping for default
behaviour.

User mapping is the process by which Foswiki maps from a username (a login name)
to a display name and back. It is also where groups are maintained.

See Foswiki::Users::BaseUserMapping and Foswiki::Users::TopicUserMapping for
the default implementations of this interface.

If you want to write a user mapper, you will need to implement the methods
described in this class.

User mappings work by mapping both login names and display names to a
_canonical user id_. This user id is composed from a prefix that defines
the mapper in use (something like 'BaseUserMapping_' or 'LdapUserMapping_')
and a unique user id that the mapper uses to identify the user.

The null prefix is reserver for the TopicUserMapping for compatibility
with old Foswiki releases.

__Note:__ in all the following documentation, =$cUID= refers to a
*canonical user id*.

=cut

package Foswiki::UserMapping;

use strict;
use warnings;
use Assert;
use Error ();
use Foswiki::Func;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ PROTECTED ClassMethod new ($session, $mapping_id)

Construct a user mapping object, using the given mapping id.

=cut

sub new {
    my ( $class, $session, $mid ) = @_;
    my $this = bless(
        {
            mapping_id => $mid || '',
            session => $session,
        },
        $class
    );
    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

sub finish {
    my $this = shift;
    undef $this->{mapping_id};
    undef $this->{session};
}

=begin TML

---++ ObjectMethod loginTemplateName () -> $templateFile

Allows UserMappings to come with customised login screens - that should
preferably only over-ride the UI function

Default is "login"

=cut

sub loginTemplateName {
    return 'login';
}

=begin TML

---++ ObjectMethod supportsRegistration() -> $boolean

Return true if the UserMapper supports registration (ie can create new users)

Default is *false*

=cut

sub supportsRegistration {
    return 0;    # NO, we don't
}

=begin TML

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the Foswiki::Users object to determine which loaded mapping
to use for a given user (must be fast).

The user can be identified by any of $cUID, $login or $wikiname. Any of
these parameters may be undef, and they should be tested in order; cUID
first, then login, then wikiname.

=cut

sub handlesUser {
    return 0;
}

=begin TML

---++ ObjectMethod login2cUID($login, $dontcheck) -> cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must map 1:1 to the login name.
(undef on failure)

(if $dontcheck is true, return a cUID for a nonexistant user too.
This is used for registration)

Subclasses *must* implement this method.

Note: This method was previously (in TWiki 4.2.0) known as getCanonicalUserID.
The name was changed to avoid confusion with Foswiki::Users::getCanonicalUserID,
which has a more generic function. However to support older user mappers,
getCanonicalUserID will still be called if login2cUID is not defined.

=cut

sub login2cUID {
    ASSERT( 0, 'Must be implemented' );
}

=begin TML

---++ ObjectMethod getLoginName ($cUID) -> login

Converts an internal cUID to that user's login
(undef on failure)

Subclasses *must* implement this method.

=cut

sub getLoginName {
    ASSERT(0);
}

=begin TML

---++ ObjectMethod addUser ($login, $wikiname, $password, $emails) -> $cUID

Add a user to the persistent mapping that maps from usernames to wikinames
and vice-versa.

$login and $wikiname must be acceptable to $Foswiki::cfg{NameFilter}.
$login must *always* be specified. $wikiname may be undef, in which case
the user mapper should make one up.

This function must return a canonical user id that it uses to uniquely
identify the user. This can be the login name, or the wikiname if they
are all guaranteed unigue, or some other string consisting only of 7-bit
alphanumerics and underscores.

If you fail to create a new user (for eg your Mapper has read only access),
<pre>
    throw Error::Simple('Failed to add user: '.$error);
</pre>
where $error is a descriptive string.

Throws an Error::Simple if user adding is not supported (the default).

=cut

sub addUser {
    throw Error::Simple('Failed to add user: adding users is not supported');
}

=begin TML

---++ ObjectMethod removeUser( $cUID ) -> $boolean

Delete the users entry from this mapper. Throws an Error::Simple if
user removal is not supported (the default).

=cut

sub removeUser {
    throw Error::Simple('Failed to remove user: user removal is not supported');
}

=begin TML

---++ ObjectMethod getWikiName ($cUID) -> $wikiname

Map a canonical user name to a wikiname.

Returns the $cUID by default.

=cut

sub getWikiName {
    my ( $this, $cUID ) = @_;
    return $cUID;
}

=begin TML

---++ ObjectMethod userExists($cUID) -> $boolean

Determine if the user already exists or not. Whether a user exists
or not is determined by the password manager.

Subclasses *must* implement this method.

=cut

sub userExists {
    ASSERT(0);
}

=begin TML

---++ ObjectMethod eachUser () -> $iterator

Get an iterator over the list of all cUIDs of the registered
users *not* including groups.

Subclasses *must* implement this method.

=cut

sub eachUser {
    ASSERT(0);
}

=begin TML

---++ ObjectMethod eachGroupMember ($group, $expand) -> $iterator

Return a iterator over the canonical user ids of users that are members
of this group. Should only be called on groups.

Note that groups may be defined recursively, so a group may contain other
groups. Unless $expand is set to false, this method should *only* return
users i.e.  all contained groups should be fully expanded.

Subclasses *must* implement this method.

=cut

sub eachGroupMember {
    ASSERT(0);
}

=begin TML

---++ ObjectMethod isGroup ($name) -> boolean

Establish if a user refers to a group or not. If $name is not
a group name it will probably be a canonical user id, though that
should not be assumed.

Subclasses *must* implement this method.

=cut

sub isGroup {
    ASSERT(0);
}

=begin TML

---++ ObjectMethod eachGroup () -> $iterator

Get an iterator over the list of all the group names.

Subclasses *must* implement this method.

=cut

sub eachGroup {
    ASSERT(0);
}

=begin TML

---++ ObjectMethod eachMembership($cUID) -> $iterator

Return an iterator over the names of groups that $cUID is a member of.

Subclasses *must* implement this method.

=cut

sub eachMembership {
    ASSERT(0);
}

=begin TML

---++ ObjectMethod groupAllowsView($group) -> boolean

returns 1 if the group is able to be viewed by the current logged in user

=cut

sub groupAllowsView {
    return 1;
}

=begin TML

---++ ObjectMethod groupAllowsChange($group) -> boolean

returns 1 if the group is able to be modified by the current logged in user

=cut

sub groupAllowsChange {
    return 0;
}

=begin TML

---++ ObjectMethod addToGroup( $cuid, $group, $create ) -> $boolean
adds the user specified by the cuid to the group.

Mapper should throws Error::Simple if errors are encountered.  For example,
if the group does not exist, and the create flag is not supplied:
<pre>
    throw Error::Simple( $this->{session}
        ->i18n->maketext('Group does not exist and create not permitted')
    ) unless ($create);
</pre>

=cut

sub addUserToGroup {
    return 0;
}

=begin TML

---++ ObjectMethod removeFromGroup( $cuid, $group ) -> $boolean

Mapper should throws Error::Simple if errors are encountered.  For example,
if the user does not exist in the group:
<pre>
   throw Error::Simple(
      $this->{session}->i18n->maketext(
         'User [_1] not in group, cannot be removed', $cuid
      )
   );
</pre>

=cut

sub removeUserFromGroup {
    return 0;
}

=begin TML

---++ ObjectMethod isAdmin( $cUID ) -> $boolean

True if the user is an administrator.

=cut

sub isAdmin {
    return 0;
}

=begin TML

---++ ObjectMethod isInGroup ($cUID, $group, $options ) -> $bool


Test if the user identified by $cUID is in the given group. The default
implementation iterates over all the members of $group, which is rather
inefficient.  $options is a hash array of options effecting the search.
Available options are:

   * =expand => 1=  0/1 - should nested groups be expanded when searching for the cUID?   Default is 1 - expand nested groups

=cut

my %scanning;

sub isInGroup {
    my ( $this, $cUID, $group, $options ) = @_;
    ASSERT($cUID) if DEBUG;

    my $expand = $options->{expand};
    $expand = 1 unless ( defined $expand );

    # If not recursively, clear the scanning hash
    if ( ( caller(1) )[3] ne ( caller(0) )[3] ) {
        %scanning = ();
    }

    #use Carp;
    #Carp::cluck "Scanning for JoeUser\n" if $cUID eq 'JoeUser';
    #die "Scanning for JoeUser\n" if $cUID eq 'JoeUser';

    my @users;
    my $it = $this->eachGroupMember( $group, { expand => $expand } );
    while ( $it->hasNext() ) {
        my $u = $it->next();
        next if $scanning{$u};
        $scanning{$u} = 1;

        return 1 if $u eq $cUID;
    }
    return 0;
}

=begin TML

---++ ObjectMethod findUserByEmail( $email ) -> \@users
   * =$email= - email address to look up
Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

=cut

sub findUserByEmail {
    return [];
}

=begin TML

---++ ObjectMethod getEmails($name) -> @emailAddress

If $name is a cUID, return that user's email addresses. If it is a group,
return the addresses of everyone in the group.

Duplicates should be removed from the list.

=cut

sub getEmails {
    return ();
}

=begin TML

---++ ObjectMethod setEmails($cUID, @emails)

Set the email address(es) for the given user.

=cut

sub setEmails {
}

=begin TML

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname
   * =$wikiname= - wikiname to look up
Return a list of canonical user names for the users that have this wikiname.
Since a single wikiname might be used by multiple login ids, we need a list.

Note that if $wikiname is the name of a group, the group will *not* be
expanded.

Subclasses *must* implement this method.

=cut

sub findUserByWikiName {
    ASSERT(0);
}

=begin TML

---++ ObjectMethod checkPassword( $login, $passwordU ) -> $boolean

Finds if the password is valid for the given login. This is called using
a login name rather than a cUID because the user may not have been mapped
at the time it is called.

Returns 1 on success, undef on failure.

Default behaviour is to return 1.

=cut

sub checkPassword {
    return 1;
}

=begin TML

---++ ObjectMethod setPassword( $cUID, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

Default behaviour is to fail.

=cut

sub setPassword {
    return;
}

=begin TML

---++ ObjectMethod passwordError( ) -> $string

Returns a string indicating the error that happened in the password handlers
TODO: these delayed errors should be replaced with Exceptions.

returns undef if no error (the default)

=cut

sub passwordError {
    return;
}

=begin TML

---++ ObjectMethod validateRegistrationField($field, $value ) -> $string

Returns a string containing the sanitized registration field, or can throw an oops
if the field contains illegal data to block the registration.

returns the string unchanged if no issue found.

=cut

sub validateRegistrationField {

    #my ($this, $field, $value) = @_;

    # Filter username per the login validation rules.
    #    Note:  loginname excluded as it's validated directly in the mapper

    return $_[2] if ( lc( $_[1] ) eq 'loginname' );

    if ( lc( $_[1] ) eq 'username' ) {
        if ( length( $_[2] )
            && !( $_[2] =~ m/$Foswiki::cfg{LoginNameFilterIn}/ ) )
        {
            throw Error::Simple( Foswiki::entityEncode("Invalid $_[1]") );
        }
        else {
            return $_[2];
        }
    }

    # Don't check contents of password - it's never displayed.
    return $_[2] if ( lc( $_[1] ) eq 'password' || lc( $_[1] ) eq 'confirm' );

# Registration fails without valid email, wikiname and name are validated elsewhere
    unless ( $_[1] =~ m/^(?:email|wikiname|name|)$/i ) {
        $_[2] = Foswiki::entityEncode( $_[2] );
    }

    return $_[2];
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
