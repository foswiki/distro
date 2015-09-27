# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Users
This package provides services for the lookup and manipulation of login and
wiki names of users, and their authentication.

It is a Facade that presents a common interface to the User Mapping
and Password modules. The rest of the core should *only* use the methods
of this package, and should *never* call the mapping or password managers
directly.

Foswiki uses the concept of a _login name_ which is used to authenticate a
user. A login name maps to a _wiki name_ that is used to identify the user
for display. Each login name is unique to a single user, though several
login names may map to the same wiki name.

Using this module (and the associated plug-in user mapper) Foswiki supports
the concept of _groups_. Groups are sets of login names that are treated
equally for the purposes of access control. Group names do not have to be
wiki names, though it is helpful for display if they are.

Internally in the code Foswiki uses something referred to as a _canonical user
id_ or just _user id_. The user id is also used externally to uniquely identify
the user when (for example) recording topic histories. The user id is *usually*
just the login name, but it doesn't need to be. It just has to be a unique
7-bit alphanumeric and underscore string that can be mapped to/from login
and wiki names by the user mapper.

The canonical user id should *never* be seen by a user. On the other hand,
core code should never use anything *but* a canonical user id to refer
to a user.

*Terminology*
   * A *login name* is the name used to log in to Foswiki. Each login name is
     assumed to be unique to a human. The Password module is responsible for
     authenticating and manipulating login names.
   * A *canonical user id* is an internal Foswiki representation of a user. Each
     canonical user id maps 1:1 to a login name.
   * A *wikiname* is how a user is displayed. Many user ids may map to a
     single wikiname. The user mapping module is responsible for mapping
     the user id to a wikiname.
   * A *group id* represents a group of users and other groups.
     The user mapping module is responsible for mapping from a group id to
     a list of canonical user ids for the users in that group.
   * An *email* is an email address asscoiated with a *login name*. A single
     login name may have many emails.
	 
*NOTE:* 
   * wherever the code references $cUID, its a canonical_id
   * wherever the code references $group, its a group_name
   * $name may be a group or a cUID

=cut

package Foswiki::Users;

use strict;
use warnings;
use Assert;

use Foswiki::AggregateIterator ();
use Foswiki::LoginManager      ();

#use Monitor;
#Monitor::MonitorMethod('Foswiki::Users');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new ($session)
Construct the user management object that is the facade to the BaseUserMapping
and the user mapping chosen in the configuration.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    # making basemapping
    my $implBaseUserMappingManager = $Foswiki::cfg{BaseUserMappingManager}
      || 'Foswiki::Users::BaseUserMapping';
    eval "require $implBaseUserMappingManager";
    die $@ if $@;
    $this->{basemapping} = $implBaseUserMappingManager->new($session);

    my $implUserMappingManager = $Foswiki::cfg{UserMappingManager};
    $implUserMappingManager = 'Foswiki::Users::TopicUserMapping'
      if ( $implUserMappingManager eq 'none' );

    if ( $implUserMappingManager eq 'Foswiki::Users::BaseUserMapping' ) {
        $this->{mapping} = $this->{basemapping};    #TODO: probly make undef..
    }
    else {
        eval "require $implUserMappingManager";
        die $@ if $@;
        $this->{mapping} = $implUserMappingManager->new($session);
    }

    $this->{loginManager} = Foswiki::LoginManager::makeLoginManager($session);

    # caches - not only used for speedup, but also for authenticated but
    # unregistered users
    # SMELL: this is basically a user object, something we had previously
    # but dropped for efficiency reasons
    $this->{cUID2WikiName} = {};
    $this->{cUID2Login}    = {};
    $this->{isAdmin}       = {};

    # the UI for rego supported/not is different from rego temporarily
    # turned off
    if ( $this->supportsRegistration() ) {
        $session->enterContext('registration_supported');
        $session->enterContext('registration_enabled')
          if $Foswiki::cfg{Register}{EnableNewUserRegistration};
    }

    return $this;
}

=begin TML

---++ ObjectMethod loadSession()

Setup the cgi session, from a cookie or the url. this may return
the login, but even if it does, plugins will get the chance to
override (in Foswiki.pm)

=cut

sub loadSession {
    my ( $this, $defaultUser ) = @_;

    # $this is passed in because it will be used to password check
    # a command-line login. The {remoteUser} in the session will be
    # whatever was passed in to the new Foswiki() call.
    my $remoteUser = $this->{loginManager}->loadSession( $defaultUser, $this );

    return $remoteUser;
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

    $this->{loginManager}->finish() if $this->{loginManager};
    $this->{basemapping}->finish()  if $this->{basemapping};

    $this->{mapping}->finish()
      if $this->{mapping}
      && $this->{mapping} ne $this->{basemapping};

    undef $this->{loginManager};
    undef $this->{basemapping};
    undef $this->{mapping};
    undef $this->{session};
    undef $this->{cUID2WikiName};
    undef $this->{cUID2Login};
    undef $this->{wikiName2cUID};
    undef $this->{login2cUID};
    undef $this->{isAdmin};

}

=begin TML

---++ ObjectMethod loginTemplateName () -> templateFile

allows UserMappings to come with customised login screens - that should preffereably only over-ride the UI function

=cut

sub loginTemplateName {
    my $this = shift;

    #use login.sudo.tmpl for admin logins
    return $this->{basemapping}->loginTemplateName()
      if ( $this->{session}->inContext('sudo_login') );
    return $this->{mapping}->loginTemplateName() || 'login';
}

# ($cUID, $login, $wikiname, $noFallBack) -> usermapping object
sub _getMapping {
    my ( $this, $cUID, $login, $wikiname, $noFallBack ) = @_;

    $login    = '' unless defined $login;
    $wikiname = '' unless defined $wikiname;

    $wikiname =~ s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;

    # The base user mapper users must always override those defined in
    # custom mappings, even though that makes it impossible to maintain 100%
    # compatibility with earlier releases (guest user edits will get saved as
    # edits by $DEFAULT_USER_CUID).
    return $this->{basemapping}
      if ( $this->{basemapping}->handlesUser( $cUID, $login, $wikiname ) );

    return $this->{mapping}
      if ( $this->{mapping}->handlesUser( $cUID, $login, $wikiname ) );

    # The base mapping and the selected mapping claim not to know about
    # this user. Use the base mapping unless the caller has explicitly
    # requested otherwise.
    return $this->{basemapping} unless ($noFallBack);

    return;
}

=begin TML

---++ ObjectMethod supportsRegistration () -> boolean

#return 1 if the  main UserMapper supports registration (ie can create new users)

=cut

sub supportsRegistration {
    my ($this) = @_;
    return $this->{mapping}->supportsRegistration();
}

=begin TML

---++ ObjectMethod validateRegistrationField ( $field, $value ) -> text

Return the registration formfield sanitized by the mapper,  or oops thrown to block the registration.

=cut

sub validateRegistrationField {
    my ($this) = shift;
    return $this->{mapping}->validateRegistrationField(@_);
}

=begin TML

---++ ObjectMethod initialiseUser ($login) -> $cUID

Given a login (which must have been authenticated) determine the cUID that
corresponds to that user. This method is used from Foswiki.pm to map the
$REMOTE_USER to a cUID.

=cut

sub initialiseUser {
    my ( $this, $login ) = @_;

    # For compatibility with older ways of building login managers,
    # plugins can provide an alternate login name.
    my $plogin = $this->{session}->{plugins}->load();

    #Monitor::MARK("Plugins loaded");

    $login = $plogin if $plogin;

    my $cUID;
    if ( defined($login) && $login ne '' ) {

        # In the case of a user mapper that accepts any identifier as
        # a cUID,
        $cUID = $this->getCanonicalUserID($login);

        # see BugsItem4771 - it seems that authenticated, but unmapped
        # users have rights too
        if ( !defined($cUID) ) {

            # There is no known canonical user ID for this login name.
            # Generate a cUID for the login, and add it anyway. There is
            # a risk that the generated cUID will overlap a cUID generated
            # by a custom mapper, but since (1) the user has to be
            # authenticated to get here and (2) the custom user mapper
            # is specific to the login process used, that risk should be
            # small (unless the author of the custom mapper screws up)
            $cUID = mapLogin2cUID($login);

            $this->{cUID2Login}->{$cUID}    = $login;
            $this->{cUID2WikiName}->{$cUID} = $login;

            # needs to be WikiName safe
            $this->{cUID2WikiName}->{$cUID} =~ s/$Foswiki::cfg{NameFilter}//g;
            $this->{cUID2WikiName}->{$cUID} =~ s/\.//g;

            $this->{login2cUID}->{$login} = $cUID;
            $this->{wikiName2cUID}->{ $this->{cUID2WikiName}->{$cUID} } = $cUID;
        }
    }

    # if we get here without a login id, we are a guest. Get the guest
    # cUID.
    $cUID ||= $this->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );

    return $cUID;
}

# global used by test harness to give predictable results
use vars qw( $password );

=begin TML

---++ randomPassword()
Static function that returns a random password. This function is not used
in this module; it is provided as a service for other modules, such as
custom mappers and registration modules.

=cut

sub randomPassword {

    my $pwlen =
      ( $Foswiki::cfg{MinPasswordLength} > 8 )
      ? $Foswiki::cfg{MinPasswordLength}
      : 8;
    my @chars = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9, '_', '.', '/' );
    my $newpw;

    foreach ( 1 .. $pwlen ) {
        $newpw .= $chars[ rand @chars ];
    }
    return $newpw;

}

=begin TML

---++ ObjectMethod addUser($login, $wikiname, $password, $emails) -> $cUID

   * =$login= - user login name. If =undef=, =$wikiname= will be used as
     the login name.
   * =$wikiname= - user wikiname. If =undef=, the user mapper will be asked
     to provide it.
   * =$password= - password. If undef, a password will be generated.

Add a new Foswiki user identity, returning the canonical user id for the new
user. Used ONLY for user registration.

The user is added to the password system (if there is one, and if it accepts
changes). If the user already exists in the password system, then the password
is checked and an exception thrown if it doesn't match. If there is no
existing user, and no password is given, a random password is generated.

$login can be undef; $wikiname must always have a value.

The return value is the canonical user id that is used
by Foswiki to identify the user.

=cut

sub addUser {
    my ( $this, $login, $wikiname, $password, $emails ) = @_;
    my $removeOnFail = 0;

    ASSERT( $login || $wikiname ) if DEBUG;    # must have at least one

    # create a new user and get the canonical user ID from the user mapping
    # manager.
    my $cUID =
      $this->{mapping}->addUser( $login, $wikiname, $password, $emails );

    # update the cached values
    $this->{cUID2Login}->{$cUID}    = $login;
    $this->{cUID2WikiName}->{$cUID} = $wikiname;

    $this->{login2cUID}->{$login}       = $cUID;
    $this->{wikiName2cUID}->{$wikiname} = $cUID;

    return $cUID;
}

=begin TML

---++ StaticMethod mapLogin2cUID( $login ) -> $cUID

This function maps an arbitrary string into a valid cUID. The transformation
is reversible, but the function is not idempotent (a cUID passed to this
function will NOT be returned unchanged). The generated cUID will be unique
for the given login name.

This static function is designed to be called from custom user mappers that
support 1:1 login-to-cUID mappings.

=cut

sub mapLogin2cUID {
    my $cUID = shift;

    ASSERT( defined($cUID) ) if DEBUG;

    # use bytes to ignore character encoding
    use bytes;
    $cUID =~ s/([^a-zA-Z0-9])/'_'.sprintf('%02x', ord($1))/ge;
    no bytes;
    return $cUID;
}

=begin TML

---++ ObjectMethod getCGISession()
Get the currect CGI session object

=cut

sub getCGISession {
    my $this = shift;
    return $this->{loginManager}->getCGISession();
}

=begin TML

---++ ObjectMethod getLoginManager() -> $loginManager

Get the Foswiki::LoginManager object associated with this session, if there is
one. May return undef.

=cut

sub getLoginManager {
    my $this = shift;
    return $this->{loginManager};
}

=begin TML

---++ ObjectMethod getCanonicalUserID( $identifier ) -> $cUID

Works out the Foswiki canonical user identifier for the user who either
(1) logs in with the login name $identifier or (2) has the wikiname
$identifier.

The canonical user ID is an alphanumeric string that is unique
to the login name, and can be mapped back to a login name and the
corresponding wiki name using the methods of this class.

Note that if the login name to wiki name mapping is not 1:1, this
method will map a wikiname to one of the login names that corresponds
to the wiki name, but there is no guarantee which one.

Returns undef if the user does not exist.

=cut

# This function was previously known as forceCUID. It differs from that
# implementation in that it does *not* accept a CUID as parameter, which
# if why it has been renamed.
sub getCanonicalUserID {
    my ( $this, $identifier ) = @_;
    my $cUID;

    ASSERT( defined $identifier ) if DEBUG;

    # Someone we already know?

    if ( defined( $this->{login2cUID}->{$identifier} ) ) {
        $cUID = $this->{login2cUID}->{$identifier};
    }
    elsif ( defined( $this->{wikiName2cUID}->{$identifier} ) ) {
        $cUID = $this->{wikiName2cUID}->{$identifier};
    }
    else {

        # See if a mapping recognises the identifier as a login name
        my $mapping = $this->_getMapping( undef, $identifier, undef, 1 );
        if ($mapping) {
            if ( $mapping->can('login2cUID') ) {
                $cUID = $mapping->login2cUID($identifier);
            }
            elsif ( $mapping->can('getCanonicalUserID') ) {

                # Old name of login2cUID. Name changed to avoid confusion
                # with Foswiki::Users::getCanonicalUserID. See
                # Codev.UserMapperChangesBetween420And421 for more.
                $cUID = $mapping->getCanonicalUserID($identifier);
            }
            else {
                die(
"Broken user mapping $mapping; does not implement login2cUID"
                );
            }
        }

        unless ($cUID) {

            # Finally see if it's a valid user wikiname

            # Strip users web id (legacy, probably specific to
            # TopicUserMappingContrib but may be used by other mappers
            # that support user topics)
            my ( $dummy, $nid ) =
              $this->{session}->normalizeWebTopicName( '', $identifier );
            $identifier = $nid if ( $dummy eq $Foswiki::cfg{UsersWebName} );

            my $found = $this->findUserByWikiName($identifier);
            $cUID = $found->[0] if ( $found && scalar(@$found) );
        }
    }
    return $cUID;
}

=begin TML

---++ ObjectMethod findUserByWikiName( $wn ) -> \@users
   * =$wn= - wikiname to look up
Return a list of canonical user names for the users that have this wikiname.
Since a single wikiname might be used by multiple login ids, we need a list.

If $wn is the name of a group, the group will *not* be expanded.

=cut

sub findUserByWikiName {
    my ( $this, $wn ) = @_;
    ASSERT($wn) if DEBUG;

    # Trim the (pointless) userweb, if present
    $wn =~ s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;
    my $mapping = $this->_getMapping( undef, undef, $wn );

    #my $mapping = $this->_getMapping( $wn, $wn, $wn ); # why not?
    return $mapping->findUserByWikiName($wn);
}

=begin TML

---++ ObjectMethod findUserByEmail( $email ) -> \@users
   * =$email= - email address to look up
Return a list of canonical user names for the users that have this email
registered with the user mapping managers.

=cut

sub findUserByEmail {
    my ( $this, $email ) = @_;
    ASSERT($email) if DEBUG;

    my $users = $this->{mapping}->findUserByEmail($email);
    push @{$users}, @{ $this->{basemapping}->findUserByEmail($email) };

    return $users;
}

=begin TML

---++ ObjectMethod getEmails($name) -> @emailAddress

If $name is a cUID, return their email addresses. If it is a group,
return the addresses of everyone in the group.

The password manager and user mapping manager are both consulted for emails
for each user (where they are actually found is implementation defined).

Duplicates are removed from the list.

=cut

sub getEmails {
    my ( $this, $name ) = @_;

    return () unless ($name);
    if ( $this->{mapping}->isGroup($name) ) {
        return $this->{mapping}->getEmails($name);
    }

    return $this->_getMapping($name)->getEmails($name);
}

=begin TML

---++ ObjectMethod setEmails($cUID, @emails)

Set the email address(es) for the given user.
The password manager is tried first, and if it doesn't want to know the
user mapping manager is tried.

=cut

sub setEmails {
    my $this   = shift;
    my $cUID   = shift;
    my @emails = @_;
    return $this->_getMapping($cUID)->setEmails( $cUID, @emails );
}

=begin TML

---++ ObjectMethod isAdmin( $cUID ) -> $boolean

True if the user is an admin
   * is $Foswiki::cfg{SuperAdminGroup}
   * is a member of the $Foswiki::cfg{SuperAdminGroup}
   * Foswiki is bootstrapping a new configuration

=cut

sub isAdmin {
    my ( $this, $cUID ) = @_;

    return 0 unless defined $cUID;

    return $this->{isAdmin}->{$cUID}
      if ( defined( $this->{isAdmin}->{$cUID} ) );

    my $mapping = $this->_getMapping($cUID);
    my $otherMapping =
      ( $mapping eq $this->{basemapping} )
      ? $this->{mapping}
      : $this->{basemapping};

    if ( $mapping eq $otherMapping ) {
        return $mapping->isAdmin($cUID);
    }
    $this->{isAdmin}->{$cUID} =
      ( $mapping->isAdmin($cUID) || $otherMapping->isAdmin($cUID) );
    return $this->{isAdmin}->{$cUID};
}

=begin TML

---++ ObjectMethod isInUserList( $cUID, \@list ) -> $boolean

Return true if $cUID is in a list of user *wikinames*, *logins* and group ids.

The list may contain the conventional web specifiers (which are ignored).

=cut

sub isInUserList {
    my ( $this, $cUID, $userlist ) = @_;

    return 0 unless defined $userlist && defined $cUID;

    foreach my $ident (@$userlist) {

        # The Wildcard match.  Any user matches the "*" identifier.
        if ( $ident eq '*' ) {
            return 1;
        }

        my $identCUID = $this->getCanonicalUserID($ident);

        if ( defined $identCUID ) {
            return 1 if ( $identCUID eq $cUID );
        }
        if ( $this->isGroup($ident) ) {
            return 1 if ( $this->isInGroup( $cUID, $ident ) );
        }
    }
    return 0;
}

=begin TML

---++ ObjectMethod getLoginName($cUID) -> $login

Get the login name of a user. Returns undef if the user is not known.

=cut

sub getLoginName {
    my ( $this, $cUID ) = @_;

    return unless defined($cUID);

    return $this->{cUID2Login}->{$cUID}
      if ( defined( $this->{cUID2Login}->{$cUID} ) );

    ASSERT( $this->{basemapping} ) if DEBUG;
    my $mapping = $this->_getMapping($cUID);
    my $login;
    if ( $cUID && $mapping ) {
        $login = $mapping->getLoginName($cUID);
    }

    if ( defined $login ) {
        $this->{cUID2Login}->{$cUID}  = $login;
        $this->{login2cUID}->{$login} = $cUID;
    }

    return $login;
}

=begin TML

---++ ObjectMethod getWikiName($cUID) -> $wikiName

Get the wikiname to display for a canonical user identifier.

Can return undef if the user is not in the mapping system
(or the special case from initialiseUser)

=cut

sub getWikiName {
    my ( $this, $cUID ) = @_;
    return 'UnknownUser' unless defined($cUID);
    return $this->{cUID2WikiName}->{$cUID}
      if ( defined( $this->{cUID2WikiName}->{$cUID} ) );

    my $wikiname;
    my $mapping = $this->_getMapping($cUID);
    $wikiname = $mapping->getWikiName($cUID) if $mapping;

    #don't cache unknown users - it really makes a mess later.
    if ( !defined($wikiname) ) {
        if ( $Foswiki::cfg{RenderLoggedInButUnknownUsers} ) {
            $wikiname = "UnknownUser (<nop>$cUID)";
        }
        else {
            $wikiname = $cUID;
        }
    }
    else {

        # remove the web part
        # SMELL: is this really needed?
        $wikiname =~ s/^($Foswiki::cfg{UsersWebName}|%MAINWEB%|%USERSWEB%)\.//;

        $this->{cUID2WikiName}->{$cUID}     = $wikiname;
        $this->{wikiName2cUID}->{$wikiname} = $cUID;
    }
    return $wikiname;
}

=begin TML

---++ ObjectMethod webDotWikiName($cUID) -> $webDotWiki

Return the fully qualified wikiname of the user

=cut

sub webDotWikiName {
    my ( $this, $cUID ) = @_;

    return $Foswiki::cfg{UsersWebName} . '.' . $this->getWikiName($cUID);
}

=begin TML

---++ ObjectMethod userExists($cUID) -> $boolean

Determine if the user already exists or not. A user exists if they are
known to to the user mapper.

=cut

sub userExists {
    my ( $this, $cUID ) = @_;
    return $this->_getMapping($cUID)->userExists($cUID);
}

=begin TML

---++ ObjectMethod eachUser() -> Foswiki::Iterator of cUIDs

Get an iterator over the list of all the registered users *not* including
groups.

list of canonical_ids ???

Use it as follows:
<verbatim>
    my $iterator = $umm->eachUser();
    while ($iterator->hasNext()) {
        my $user = $iterator->next();
        ...
    }
</verbatim>

=cut

sub eachUser {
    my $this = shift;
    my @list =
      ( $this->{basemapping}->eachUser(@_), $this->{mapping}->eachUser(@_) );
    return new Foswiki::AggregateIterator( \@list, 1 );

    return shift->{mapping}->eachUser(@_);
}

=begin TML

---++ ObjectMethod eachGroup() ->  $iterator

Get an iterator over the list of all the group names.

=cut

sub eachGroup {
    my $this = shift;
    my @list =
      ( $this->{basemapping}->eachGroup(@_), $this->{mapping}->eachGroup(@_) );
    return new Foswiki::AggregateIterator( \@list, 1 );
}

=begin TML

---++ ObjectMethod eachGroupMember($group) -> $iterator

Return a iterator of user ids that are members of this group.
Should only be called on groups.

Note that groups may be defined recursively, so a group may contain other
groups. This method should *only* return users i.e. all contained groups
should be fully expanded.

=cut

sub eachGroupMember {
    my $this = shift;
    my @list = (
        $this->{basemapping}->eachGroupMember(@_),
        $this->{mapping}->eachGroupMember(@_)
    );
    return new Foswiki::AggregateIterator( \@list, 1 );
}

=begin TML

---++ ObjectMethod isGroup($name) -> boolean

Establish if a $name refers to a group or not. If $name is not
a group name it will probably be a canonical user id, though that
should not be assumed.

=cut

sub isGroup {
    my $this = shift;
    return ( $this->{basemapping}->isGroup(@_) )
      || ( $this->{mapping}->isGroup(@_) );
}

=begin TML

---++ ObjectMethod isInGroup( $cUID, $group, $options) -> $boolean

Test if the user identified by $cUID is in the given group.   Options
is a hash array of options effecting the search.  Available options are:

   * =expand => 1=  0/1 - should nested groups be expanded when searching for the user. Default is 1, to expand nested groups.

=cut

sub isInGroup {
    my ( $this, $cUID, $group, $options ) = @_;
    return unless ( defined($cUID) );

    my $expand = $options->{expand};
    $expand = 1 unless ( defined $expand );

    my $mapping = $this->_getMapping($cUID);
    my $otherMapping =
      ( $mapping eq $this->{basemapping} )
      ? $this->{mapping}
      : $this->{basemapping};
    return 1 if $mapping->isInGroup( $cUID, $group, { expand => $expand } );

    return $otherMapping->isInGroup( $cUID, $group, { expand => $expand } )
      if ( $otherMapping ne $mapping );
}

=begin TML

---++ ObjectMethod eachMembership($cUID) -> $iterator

Return an iterator over the groups that $cUID
is a member of.

=cut

sub eachMembership {
    my ( $this, $cUID ) = @_;

    my $mapping  = $this->_getMapping($cUID);
    my $wikiname = $mapping->getWikiName($cUID);

    #stop if the user has no wikiname (generally means BugsItem4771)
    unless ( defined($wikiname) ) {
        require Foswiki::ListIterator;
        return new Foswiki::ListIterator( \() );
    }

    my $otherMapping =
      ( $mapping eq $this->{basemapping} )
      ? $this->{mapping}
      : $this->{basemapping};
    if ( $mapping eq $otherMapping ) {

        # only using BaseMapping.
        return $mapping->eachMembership($cUID);
    }

    my @list =
      ( $mapping->eachMembership($cUID), $otherMapping->eachMembership($cUID) );
    return new Foswiki::AggregateIterator( \@list, 1 );
}

=begin TML

---++ ObjectMethod groupAllowsView($group) -> boolean

returns 1 if the group is able to be modified by the current logged in user

=cut

sub groupAllowsView {
    my $this    = shift;
    my $group   = shift;
    my $mapping = $this->{mapping};
    return $mapping->groupAllowsView($group);
}

=begin TML

---++ ObjectMethod groupAllowsChange($group, $cuid) -> boolean

returns 1 if the group is able to be modified by the current logged in user

=cut

sub groupAllowsChange {
    my $this  = shift;
    my $group = shift;
    my $cuid  = shift || $this->{session}->{user};

    return (  $this->{basemapping}->groupAllowsChange( $group, $cuid )
          and $this->{mapping}->groupAllowsChange( $group, $cuid ) );
}

=begin TML

---++ ObjectMethod addToGroup( $cuid, $group, $create ) -> $boolean
adds the user specified by the cuid to the group.
If the group does not exist, it will return false and do nothing, unless the create flag is set.

=cut

sub addUserToGroup {
    my ( $this, $cuid, $group, $create ) = @_;
    my $mapping = $this->{mapping};
    return $mapping->addUserToGroup( $cuid, $group, $create );
}

=begin TML

---++ ObjectMethod removeFromGroup( $cuid, $group ) -> $boolean

=cut

sub removeUserFromGroup {
    my ( $this, $cuid, $group ) = @_;
    my $mapping = $this->{mapping};
    return $mapping->removeUserFromGroup( $cuid, $group );
}

=begin TML

---++ ObjectMethod checkLogin( $login, $passwordU ) -> $boolean

Finds if the password is valid for the given user. This method is
called using the login name rather than the $cUID so that it can be called
with a user who can be authenticated, but may not be mappable to a
cUID (yet).

Returns 1 on success, undef on failure.

TODO: add special check for BaseMapping admin user's login, and if
its there (and we're in sudo_context?) use that..

=cut

sub checkPassword {
    my ( $this, $login, $pw ) = @_;
    my $mapping = $this->_getMapping( undef, $login, undef, 0 );
    return $mapping->checkPassword( $login, $pw );
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
    ASSERT($cUID) if DEBUG;
    return $this->_getMapping($cUID)
      ->setPassword( $this->getLoginName($cUID), $newPassU, $oldPassU );
}

=begin TML

---++ ObjectMethod passwordError($cUID) -> $string

Returns a string indicating the error that happened in the password handler
The cUID is used to determine which mapper is handling the user.  If called
without a cUID, then the Base mapping is used.

TODO: these delayed error's should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my ( $this, $cUID ) = @_;

    my $error = $this->_getMapping($cUID)->passwordError();

    return unless defined $error;

    return Foswiki::entityEncode($error);
}

=begin TML

---++ ObjectMethod removeUser( $cUID ) -> $boolean

Delete the users entry. Removes the user from the password
manager and user mapping manager. Does *not* remove their personal
topics, which may still be linked.

=cut

sub removeUser {
    my ( $this, $cUID ) = @_;
    $this->_getMapping($cUID)->removeUser($cUID);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
