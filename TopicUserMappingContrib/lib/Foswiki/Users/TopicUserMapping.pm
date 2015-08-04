# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Users::TopicUserMapping @isa Foswiki::UserMapping');

use

The User mapping is the process by which Foswiki maps from a username (a login name)
to a wikiname and back. It is also where groups are defined.

By default Foswiki maintains user topics and group topics in the %MAINWEB% that
define users and group. These topics are
   * !WikiUsers - stores a mapping from usernames to Wiki names
   * !WikiName - for each user, stores info about the user
   * !GroupNameGroup - for each group, a topic ending with "Group" stores a list of users who are part of that group.

Many sites will want to override this behaviour, for example to get users and groups from a corporate database.

This class implements the basic Foswiki behaviour using topics to store users,
but is also designed to be subclassed so that other services can be used.

Subclasses should be named 'XxxxUserMapping' so that configure can find them.

=cut

package Foswiki::Users::TopicUserMapping;
use Foswiki::UserMapping ();
our @ISA = ('Foswiki::UserMapping');

use strict;
use warnings;
use Assert;
use Error qw( :try );
use Foswiki::ListIterator ();
use Foswiki::Func         ();

#use Monitor;
#Monitor::MonitorMethod('Foswiki::Users::TopicUserMapping');

=begin TML

---++ ClassMethod new ($session, $impl)

Constructs a new user mapping handler of this type, referring to $session
for any required Foswiki services.

=cut

# The null mapping name is reserved for Foswiki for backward-compatibility.
# We declare this as a global variable so we can override it during testing.
our $FOSWIKI_USER_MAPPING_ID = '';

#our $FOSWIKI_USER_MAPPING_ID = 'TestMapping_';

sub new {
    my ( $class, $session ) = @_;

    my $this = $class->SUPER::new( $session, $FOSWIKI_USER_MAPPING_ID );

    my $implPasswordManager = $Foswiki::cfg{PasswordManager};
    $implPasswordManager = 'Foswiki::Users::Password'
      if ( $implPasswordManager eq 'none' );
    eval "require $implPasswordManager";
    die $@ if $@;
    $this->{passwords} = $implPasswordManager->new($session);

    unless ( $this->{passwords}->readOnly() ) {
        $this->{session}->enterContext('passwords_modifyable');
    }

    #SMELL: and this is a second user object
    #TODO: combine with the one in Foswiki::Users
    #$this->{U2L} = {};
    $this->{L2U}                = {};
    $this->{U2W}                = {};
    $this->{W2U}                = {};
    $this->{eachGroupMember}    = {};
    $this->{singleGroupMembers} = ();

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

    $this->{passwords}->finish() if $this->{passwords};
    undef $this->{L2U};
    undef $this->{U2W};
    undef $this->{W2U};
    undef $this->{passwords};
    undef $this->{eachGroupMember};
    undef $this->{singleGroupMembers};
    $this->SUPER::finish();
}

=begin TML

---++ ObjectMethod supportsRegistration () -> false
return 1 if the UserMapper supports registration (ie can create new users)

=cut

sub supportsRegistration {
    return 1;
}

=begin TML

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the Foswiki::Users object to determine which loaded mapping
to use for a given user.

The user can be identified by any of $cUID, $login or $wikiname. Any of
these parameters may be undef, and they should be tested in order; cUID
first, then login, then wikiname. This mapping is special - for backwards
compatibility, it assumes responsibility for _all_ non BaseMapping users.
If you're needing to mix the TopicUserMapping with other mappings,
define $this->{mapping_id} = 'TopicUserMapping_';

=cut

sub handlesUser {
    my ( $this, $cUID, $login, $wikiname ) = @_;
    if ( defined $cUID && !length( $this->{mapping_id} ) ) {

        # Handle all cUIDs if the mapping ID is not defined
        return 1;
    }
    else {

        # Used when (if) TopicUserMapping is subclassed
        return 1 if ( defined $cUID && $cUID =~ m/^($this->{mapping_id})/ );
    }

    # Check the login id to see if we know it
    return 1 if ( $login && $this->_userReallyExists($login) );

    # Or the wiki name
    if ($wikiname) {
        $this->_loadMapping();    # Sorry Sven, has to be done
        return 1 if defined $this->{W2U}->{$wikiname};
    }

    return 0;
}

=begin TML

---++ ObjectMethod login2cUID ($login, $dontcheck) -> $cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

(if dontcheck is true, return a cUID for a nonexistant user too.
This is used for registration)

=cut

sub login2cUID {
    my ( $this, $login, $dontcheck ) = @_;

    unless ($dontcheck) {
        return unless ( _userReallyExists( $this, $login ) );
    }

    return $this->{mapping_id} . Foswiki::Users::mapLogin2cUID($login);
}

=begin TML

---++ ObjectMethod getLoginName ($cUID) -> login

Converts an internal cUID to that user's login
(undef on failure)

=cut

sub getLoginName {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $login = $cUID;

    #can't call userExists - its recursive
    #return unless (userExists($this, $user));

    # Remove the mapping id in case this is a subclass
    $login =~ s/$this->{mapping_id}// if $this->{mapping_id};

    use bytes;

    # Reverse the encoding used to generate cUIDs in login2cUID
    # use bytes to ignore character encoding
    $login =~ s/_([0-9a-f][0-9a-f])/chr(hex($1))/gei;
    no bytes;

    return unless _userReallyExists( $this, $login );
    return unless ( $cUID eq $this->login2cUID($login) );

    # Validated
    return Foswiki::Sandbox::untaintUnchecked($login);
}

# test if the login is in the WikiUsers topic, or in the password file
# depending on the AllowLoginNames setting
sub _userReallyExists {
    my ( $this, $login ) = @_;

    if (   $Foswiki::cfg{Register}{AllowLoginName}
        || $Foswiki::cfg{PasswordManager} eq 'none' )
    {

        # need to use the WikiUsers file
        $this->_loadMapping();
        return 1 if ( defined( $this->{L2U}->{$login} ) );
    }

    if ( $this->{passwords}->canFetchUsers() ) {

        # AllowLoginName mapping failed, maybe the user is however
        # present in the Wiki managed pwd file
        # can use the password file if available
        my $pass = $this->{passwords}->fetchPass($login);
        return unless ( defined($pass) );
        return if ( $pass eq '0' );    # login invalid... (SMELL: what
                                       # does that really mean)
        return 1;
    }
    else {
        return 0;
    }

    return 0;
}

=begin TML

---++ ObjectMethod addUser ($login, $wikiname, $password, $emails) -> $cUID

throws an Error::Simple

Add a user to the persistent mapping that maps from usernames to wikinames
and vice-versa. The default implementation uses a special topic called
"WikiUsers" in the users web. Subclasses will provide other implementations
(usually stubs if they have other ways of mapping usernames to wikinames).
Names must be acceptable to $Foswiki::cfg{NameFilter}
$login must *always* be specified. $wikiname may be undef, in which case
the user mapper should make one up.
This function must return a *canonical user id* that it uses to uniquely
identify the user. This can be the login name, or the wikiname if they
are all guaranteed unigue, or some other string consisting only of 7-bit
alphanumerics and underscores.
if you fail to create a new user (for eg your Mapper has read only access),
            throw Error::Simple(
               'Failed to add user: '.$ph->error());

=cut

sub addUser {
    my ( $this, $login, $wikiname, $password, $emails ) = @_;

    ASSERT($login) if DEBUG;

    # SMELL: really ought to be smarter about this e.g. make a wikiword
    $wikiname ||= $login;

    if ( $this->{passwords}->fetchPass($login) ) {

        # They exist; their password must match
        unless ( $this->{passwords}->checkPassword( $login, $password ) ) {
            throw Error::Simple(
                $this->{session}->i18n->maketext(
'User exists in the Password Manager,  and the password you provided is different from the users current password.   You cannot add a user and change the password at the same time.'
                )
            );
        }

        # User exists, and the password was good.
    }
    else {

        # add a new user

        unless ( defined($password) ) {
            require Foswiki::Users;
            $password = Foswiki::Users::randomPassword();
        }

        unless ( $this->{passwords}->setPassword( $login, $password ) == 1 ) {

            throw Error::Simple(
                    $this->{session}->i18n->maketext('Failed to add user: ')
                  . $this->{passwords}->error() );
        }
    }

    $this->{CACHED} = 0;
    my $user = $this->_maintainUsersTopic( 'add', $login, $wikiname );

#can't call setEmails here - user may be in the process of being registered
#TODO; when registration is moved into the mapping, setEmails will happend after the createUserTOpic
#$this->setEmails( $user, $emails );

    return $user;
}

=begin TML

---++ ObjectMethod _maintainUsersTopic ( $action, $login, $wikiname )

throws an Error::Simple

Add or remove  a user to/from the persistent mapping that maps from usernames to wikinames
and vice-versa. The default implementation uses a special topic called
"WikiUsers" in the users web. =cut

=cut

sub _maintainUsersTopic {
    my ( $this, $action, $login, $wikiname ) = @_;

    my $usersTopicObject;

    if (
        $this->{session}->topicExists(
            $Foswiki::cfg{UsersWebName},
            $Foswiki::cfg{UsersTopicName}
        )
      )
    {

        # Load existing users topic
        $usersTopicObject = Foswiki::Meta->load(
            $this->{session},
            $Foswiki::cfg{UsersWebName},
            $Foswiki::cfg{UsersTopicName}
        );
    }
    else {

        return undef if ( $action eq 'del' );

        # Construct a new users topic from the template
        my $templateTopicObject =
          Foswiki::Meta->load( $this->{session}, $Foswiki::cfg{SystemWebName},
            'UsersTemplate' );
        $usersTopicObject = Foswiki::Meta->new(
            $this->{session},              $Foswiki::cfg{UsersWebName},
            $Foswiki::cfg{UsersTopicName}, $templateTopicObject->text()
        );

        $usersTopicObject->copyFrom($templateTopicObject);
        $usersTopicObject->put( "TOPICPARENT",
            { name => $Foswiki::cfg{HomeTopicName} } );
    }

    my $entry = "   * $wikiname - ";
    $entry .= $login . " - " if $login;

    require Foswiki::Time;
    my $today =
      Foswiki::Time::formatTime( time(), $Foswiki::cfg{DefaultDateFormat},
        'gmtime' );

    my $user;

    # add to the mapping caches unless removing a user
    unless ( $action eq 'del' ) {
        $user = _cacheUser( $this, $wikiname, $login );
        ASSERT($user) if DEBUG;
    }

    # add name alphabetically to list

 # insidelist is used to see if we are before the first record or after the last
 # 0 before, 1 inside, 2 after
    my $insidelist = 0;
    my $input      = $usersTopicObject->text();
    my $output     = '';
    foreach my $line ( split( /\r?\n/, $input || '' ) ) {

        # TODO: I18N fix here once basic auth problem with 8-bit user names is
        # solved
        if ($entry) {
            my ( $web, $name, $odate ) = ( '', '', '' );
            if ( $line =~
m/^\s+\*\s($Foswiki::regex{webNameRegex}\.)?($Foswiki::regex{wikiWordRegex})\s*(?:-\s*\w+\s*)?-\s*(.*)/
              )
            {
                $web   = $1 || $Foswiki::cfg{UsersWebName};
                $name  = $2;
                $odate = $3;

                # Filter-in date format matching {DefaultDateFormat}
                # The admin may have changed the format at some point of time
                # so we test with a generic format that matches all 4 formats.
                $odate = ''
                  unless $odate =~ m/^\d+[- .\/]+[A-Za-z0-9]+[- .\/]+\d+$/;
                $insidelist = 1;
            }
            elsif ( $line =~ m/^\s+\*\s([A-Z]) - / ) {

                #	* A - <a name="A">- - - -</a>^M
                $name       = $1;
                $insidelist = 1;
            }
            elsif ( $insidelist == 1 ) {

              # After last entry we have a blank line or some comment
              # We assume no blank lines inside the list of users
              # We cannot look for last after Z because Z is not the last letter
              # in all alphabets
                $insidelist = 2;
                $name       = '';
            }
            if ( ( $name && ( $wikiname le $name ) ) || $insidelist == 2 ) {

                # found alphabetical position or last record
                if ( $wikiname eq $name ) {

                    next if ( $action eq 'del' );

                    # adjusting existing user - keep original registration date
                    $entry .= $odate;
                }
                else {
                    $entry .= $today . "\n" . $line;
                }

                # don't adjust if unchanged
                return $user if ( $entry eq $line && $action eq 'add' );
                $line = $entry if ( $action eq 'add' );
                $entry = '';
            }
        }
        $output .= $line . "\n";
    }

    if ( $entry && $action eq 'add' ) {

        # brand new file - add to end
        $output .= "$entry$today\n";
    }
    $usersTopicObject->text($output);

    $this->{CACHED} = 0;
    try {
        $usersTopicObject->save(
            author =>

              # SMELL: why is this Admin and not the RegoAgent??
              $this->{session}->{users}
              ->getCanonicalUserID( $Foswiki::cfg{AdminUserLogin} )
        );
    }
    catch Error with {

        # Failed to add user; must remove them from the password system too,
        # otherwise their next registration attempt will be blocked
        my $e = shift;
        $this->{passwords}->removeUser($login);
        throw $e;
    };

    return $user;
}

=begin TML

---++ ObjectMethod removeUser( $cUID ) -> $boolean

Delete the users entry. Removes the user from the password
manager and user mapping manager. Does *not* remove their personal
topics, which may still be linked.

Note that this must be called with the cUID.  If any doubt,  resolve the cUID
by $this->{session}->{users}->getCanonicalUserID($identity).

=cut

sub removeUser {
    my ( $this, $cUID ) = @_;

    my $ln       = $this->getLoginName($cUID);
    my $wikiname = $this->getWikiName($cUID);
    $this->{passwords}->removeUser($ln) if ($ln);

   # SMELL: If for some reason the login or wikiname is not found in the mapping
   # Then the WikiUsers topic will not be maintained.
    $this->_maintainUsersTopic( 'del', $ln, $wikiname ) if ( $ln && $wikiname );

    # SMELL: does not update the internal caches,
    # needs someone to implement it
    # Brutal update - invalidate them all

    $this->{CACHED}             = 0;
    $this->{L2U}                = {};
    $this->{U2W}                = {};
    $this->{W2U}                = {};
    $this->{eachGroupMember}    = {};
    $this->{singleGroupMembers} = ();

    return 1;

}

=begin TML

---++ ObjectMethod getWikiName ($cUID) -> $wikiname

Map a canonical user name to a wikiname. If it fails to find a
WikiName, it will attempt to find a matching loginname, and use
an escaped version of that.
If there is no matching WikiName or LoginName, it returns undef.

=cut

sub getWikiName {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;
    ASSERT( $cUID =~ m/^$this->{mapping_id}/ ) if DEBUG;

    my $wikiname;

    if ( $Foswiki::cfg{Register}{AllowLoginName} ) {
        $this->_loadMapping();
        $wikiname = $this->{U2W}->{$cUID};
    }
    else {

        # If the mapping isn't enabled there's no point in loading it
    }

    unless ($wikiname) {
        $wikiname = $this->getLoginName($cUID);
        if ($wikiname) {

            # sanitise the generated WikiName
            $wikiname =~ s/$Foswiki::cfg{NameFilter}//g;
        }
    }

    return $wikiname;
}

=begin TML

---++ ObjectMethod userExists($cUID) -> $boolean

Determine if the user already exists or not. Whether a user exists
or not is determined by the password manager.

=cut

sub userExists {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    # Do this to avoid a password manager lookup
    return 1 if $cUID eq $this->{session}->{user};

    my $loginName = $this->getLoginName($cUID);
    return 0 unless defined($loginName);

    return 1 if ( $loginName eq $Foswiki::cfg{DefaultUserLogin} );

    # Foswiki allows *groups* to log in
    return 1 if ( $this->isGroup($loginName) );

    # Look them up in the password manager (can be slow).
    return 1
      if ( $this->{passwords}->canFetchUsers()
        && $this->{passwords}->fetchPass($loginName) );

    unless ( $Foswiki::cfg{Register}{AllowLoginName}
        && $this->{passwords}->canFetchUsers() )
    {

        #if there is no pwd file, then its external auth
        #and if AllowLoginName is also off, then the only way to know if
        #the user has registered is to test for user topic?
        my $wikiname = $this->{session}->{users}->getWikiName($cUID);
        if (
            Foswiki::Func::topicExists(
                $Foswiki::cfg{UsersWebName}, $wikiname
            )
          )
        {
            return 1;
        }
    }

    return 0;
}

=begin TML

---++ ObjectMethod eachUser () -> Foswiki::Iterator of cUIDs

See baseclass for documentation

=cut

sub eachUser {
    my ($this) = @_;

    $this->_loadMapping();
    my @list = keys( %{ $this->{U2W} } );
    my $iter = new Foswiki::ListIterator( \@list );
    $iter->{filter} = sub {

        # don't claim users that are handled by the basemapping
        my $cUID     = $_[0] || '';
        my $login    = $this->{session}->{users}->getLoginName($cUID);
        my $wikiname = $this->{session}->{users}->getWikiName($cUID);

        return !( $this->{session}->{users}->{basemapping}
            ->handlesUser( undef, $login, $wikiname ) );
    };
    return $iter;
}

=begin TML

---++ ObjectMethod eachGroupMember ($group) ->  listIterator of cUIDs

See baseclass for documentation

=cut

my %expanding;    # Prevents loops in nested groups

sub eachGroupMember {
    my ( $this, $group, $options ) = @_;

    my $expand = $options->{expand};

    if ( Scalar::Util::tainted($group) ) {
        $group = Foswiki::Sandbox::untaint( $group,
            \&Foswiki::Sandbox::validateTopicName );
    }

    $expand = 1 unless ( defined $expand );

    #    print STDERR "eachGroupMember called for $group - expand $expand \n";

    if ( !$expand && defined( $this->{singleGroupMembers}->{$group} ) ) {

        #        print STDERR "Returning cached unexpanded list for $group\n";
        return new Foswiki::ListIterator(
            $this->{singleGroupMembers}->{$group} );
    }

    if ( $expand && defined( $this->{eachGroupMember}->{$group} ) ) {

        #        print STDERR "Returning cached expanded list for $group\n";
        return new Foswiki::ListIterator( $this->{eachGroupMember}->{$group} );
    }

    #    print "Cache miss for $group expand $expand \n";

    my $session = $this->{session};
    my $users   = $session->{users};

    my $members            = [];
    my $singleGroupMembers = [];

# Determine if we are called recursively, either directly, or by the _expandUserList routine
    unless ( ( caller(1) )[3] eq ( caller(0) )[3]
        || ( caller(2) )[3] eq ( caller(0) )[3] )
    {

        #        print "eachGroupMember $group  - TOP LEVEL \n";
        %expanding = ();
    }

    if (  !$expanding{$group}
        && $session->topicExists( $Foswiki::cfg{UsersWebName}, $group ) )
    {
        $expanding{$group} = 1;

        #        print "Expanding $group \n";
        my $groupTopicObject =
          Foswiki::Meta->load( $this->{session}, $Foswiki::cfg{UsersWebName},
            $group );

        if ( !$expand ) {
            $singleGroupMembers =
              _expandUserList( $this,
                $groupTopicObject->getPreference('GROUP'), 0 );
            $this->{singleGroupMembers}->{$group} = $singleGroupMembers;

#            print "Returning iterator for singleGroupMembers $group, members $singleGroupMembers \n";
            return new Foswiki::ListIterator(
                $this->{singleGroupMembers}->{$group} );
        }
        else {
            $members =
              _expandUserList( $this,
                $groupTopicObject->getPreference('GROUP') );
            $this->{eachGroupMember}->{$group} = $members;
        }

        delete $expanding{$group};
    }

    #    print "Returning iterator for eachGroupMember $group \n";
    return new Foswiki::ListIterator( $this->{eachGroupMember}->{$group} );
}

=begin TML

---++ ObjectMethod isGroup ($user) -> boolean

See baseclass for documentation

=cut

sub isGroup {
    my ( $this, $user ) = @_;

    # Groups have the same username as wikiname as canonical name
    return 1 if $user eq $Foswiki::cfg{SuperAdminGroup};

    return 0 unless ( $user =~ m/Group$/ );

   #actually test for the existance of this group
   #TODO: SMELL: this is still a lie, because it will claim that a
   #Group which the currently logged in user does _not_
   #have VIEW permission for simply is non-existant.
   #however, this may be desirable for security reasons.
   #SMELL: this is why we should not use topicExist to test for createability...
    my $iterator = $this->eachGroup();
    while ( $iterator->hasNext() ) {
        my $groupname = $iterator->next();
        return 1 if ( $groupname eq $user );
    }
    return 0;
}

=begin TML

---++ ObjectMethod eachGroup () -> ListIterator of groupnames

See baseclass for documentation

=cut

sub eachGroup {
    my ($this) = @_;
    _getListOfGroups($this);
    return new Foswiki::ListIterator( \@{ $this->{groupsList} } );
}

=begin TML

---++ ObjectMethod eachMembership ($cUID) -> ListIterator of groups this user is in

See baseclass for documentation

=cut

sub eachMembership {
    my ( $this, $user ) = @_;

    _getListOfGroups($this);
    my $it = new Foswiki::ListIterator( \@{ $this->{groupsList} } );
    $it->{filter} = sub {
        $this->isInGroup( $user, $_[0] );
    };
    return $it;
}

=begin TML

---++ ObjectMethod groupAllowsView($group) -> boolean

returns 1 if the group is able to be viewed by the current logged in user

implemented using topic VIEW permissions

=cut

sub groupAllowsView {
    my $this  = shift;
    my $Group = shift;

    my $user = $this->{session}->{user};
    return 1 if $this->{session}->{users}->isAdmin($user);

    $Group = Foswiki::Sandbox::untaint( $Group,
        \&Foswiki::Sandbox::validateTopicName );
    my ( $groupWeb, $groupName ) =
      $this->{session}
      ->normalizeWebTopicName( $Foswiki::cfg{UsersWebName}, $Group );

# If a Group or User topic normalized somewhere else,  doesn't make sense, so ignore the Webname
    $groupWeb = $Foswiki::cfg{UsersWebName};

    $groupName = undef
      if ( not $this->{session}->topicExists( $groupWeb, $groupName ) );

    return Foswiki::Func::checkAccessPermission( 'VIEW', $user, undef,
        $groupName, $groupWeb );
}

=begin TML

---++ ObjectMethod groupAllowsChange($group, $cuid) -> boolean

returns 1 if the group is able to be modified by $cuid

implemented using topic CHANGE permissions

=cut

sub groupAllowsChange {
    my $this  = shift;
    my $Group = shift;
    my $user  = shift;
    ASSERT( defined $user ) if DEBUG;

    $Group = Foswiki::Sandbox::untaint( $Group,
        \&Foswiki::Sandbox::validateTopicName );
    my ( $groupWeb, $groupName ) =
      $this->{session}
      ->normalizeWebTopicName( $Foswiki::cfg{UsersWebName}, $Group );

    # SMELL: Should NobodyGroup be configurable?
    return 0 if $groupName eq 'NobodyGroup';
    return 1 if $this->{session}->{users}->isAdmin($user);

# If a Group or User topic normalized somewhere else,  doesn't make sense, so ignore the Webname
    $groupWeb = $Foswiki::cfg{UsersWebName};

    $groupName = undef
      if ( not $this->{session}->topicExists( $groupWeb, $groupName ) );

    return Foswiki::Func::checkAccessPermission( 'CHANGE', $user, undef,
        $groupName, $groupWeb );
}

=begin TML

---++ ObjectMethod addToGroup( $cuid, $group, $create ) -> $boolean
adds the user specified by the cuid to the group.
If the group does not exist, it will return false and do nothing, unless the create flag is set.

cuid be a groupname which is added like it was an unknown user

=cut

sub addUserToGroup {
    my ( $this, $cuid, $Group, $create ) = @_;
    $Group = Foswiki::Sandbox::untaint( $Group,
        \&Foswiki::Sandbox::validateTopicName );
    my ( $groupWeb, $groupName ) =
      $this->{session}
      ->normalizeWebTopicName( $Foswiki::cfg{UsersWebName}, $Group );

    throw Error::Simple( $this->{session}
          ->i18n->maketext( 'Users cannot be added to [_1]', $Group ) )
      if ( $Group eq 'NobodyGroup' || $Group eq 'BaseGroup' );

    throw Error::Simple(
        $this->{session}->i18n->maketext('Group names must end in Group') )
      unless ( $Group =~ m/Group$/ );

    # the registration code will call this function using the rego agent
    my $user = $this->{session}->{user};

    my $usersObj = $this->{session}->{users};

    print STDERR "$user, aka("
      . $usersObj->getWikiName($user)
      . ") is TRYING to add $cuid aka("
      . $usersObj->getWikiName($cuid)
      . ") to $groupName\n"
      if ( $cuid && DEBUG );

    my $membersString = '';
    my $allowChangeString;
    my $groupTopicObject;

    if ( $usersObj->isGroup($groupName) ) {

        $groupTopicObject =
          Foswiki::Meta->load( $this->{session}, $groupWeb, $groupName );

        if ( !$groupTopicObject->haveAccess( 'CHANGE', $user ) ) {
            throw Error::Simple( $this->{session}
                  ->i18n->maketext( 'CHANGE not permitted by [_1]', $user ) );
        }

        $membersString = $groupTopicObject->getPreference('GROUP') || '';

        my @l;
        foreach my $ident ( split( /[\,\s]+/, $membersString ) ) {
            $ident =~ s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;
            push( @l, $ident ) if $ident;
        }
        $membersString = join( ', ', @l );

        if ( $create and !defined($cuid) ) {

            #upgrade group topic.
            $this->_writeGroupTopic(
                $groupTopicObject, $groupWeb, $groupName,
                $membersString,    $allowChangeString
            );

            return 1;
        }
    }
    else {

# see if we have permission to add a topic, or to edit the existing topic, etc..

        throw Error::Simple( $this->{session}
              ->i18n->maketext('Group does not exist and create not permitted')
        ) unless ($create);

        throw Error::Simple(
            $this->{session}->i18n->maketext(
                'CHANGE not permitted for [_1] by [_2]',
                ( $groupName, $user )
            )
          )
          unless (
            Foswiki::Func::checkAccessPermission(
                'CHANGE', $user, '', $groupName, $groupWeb
            )
          );

        $groupTopicObject =
          Foswiki::Meta->load( $this->{session}, $groupWeb, 'GroupTemplate' );

        # expand the GroupTemplate as best we can.
        $this->{session}->{request}
          ->param( -name => 'topic', -value => $groupName );
        $groupTopicObject->expandNewTopic();

        $allowChangeString = $groupName;
    }

    my $wikiName = '';
    $wikiName = $usersObj->getWikiName($cuid) if ($cuid);

    if ( $membersString !~ m/\b$wikiName\b/ ) {
        $membersString .= ', ' if ( $membersString ne '' );
        $membersString .= $wikiName;
    }

    Foswiki::Func::writeEvent( 'addUserToGroup',
        "$groupName: $wikiName added by $user" );

    $this->_clearGroupCache($groupName);

    $this->_writeGroupTopic(
        $groupTopicObject, $groupWeb, $groupName,
        $membersString,    $allowChangeString
    );

    # reparse groups brute force :/
    _getListOfGroups( $this, 1 ) if ($create);
    return 1;
}

#start by just writing the new form.
sub _writeGroupTopic {
    my $this              = shift;
    my $groupTopicObject  = shift;
    my $groupWeb          = shift;
    my $groupName         = shift;
    my $membersString     = shift;
    my $allowChangeString = shift;

    my $text = $groupTopicObject->text() || '';

#TODO: do an attempt to convert existing old style topics - compare to 'normal' GroupTemplate? (I'm hoping to keep any user added descriptions for the group
    if (
        (
            !defined $groupTopicObject->getPreference('VIEW_TEMPLATE')
            or $groupTopicObject->getPreference('VIEW_TEMPLATE') ne 'GroupView'
        )
        or ( $text =~ m/^---\+!! <nop>.*$/ )
        or ( $text =~ m/^(\t|   )+\* Set GROUP = .*$/ )
        or ( $text =~ m/^(\t|   )+\* Member list \(comma-separated list\):$/ )
        or ( $text =~ m/^(\t|   )+\* Persons\/group who can change the list:$/ )
        or ( $text =~ m/^(\t|   )+\* Set ALLOWTOPICCHANGE = .*$/ )
        or ( $text =~ m/^\*%MAKETEXT\{"Related topics:"\}%.*$/ )
      )
    {
        if ( !defined($allowChangeString) ) {
            $allowChangeString =
              $groupTopicObject->getPreference('ALLOWTOPICCHANGE') || '';
        }

        $text =~ s/^---\+!! <nop>.*$//s;
        $text =~ s/^(\t|   )+\* Set GROUP = .*$//s;
        $text =~ s/^(\t|   )+\* Member list \(comma-separated list\):$//s;
        $text =~ s/^(\t|   )+\* Persons\/group who can change the list:$//s;
        $text =~ s/^(\t|   )+\* Set ALLOWTOPICCHANGE = .*$//s;
        $text =~ s/^\*%MAKETEXT\{"Related topics:"\}%.*$//s;

        $text .= "\nEdit this topic to add a description to the $groupName\n";

#TODO: consider removing the VIEW_TEMPLATE that only very few people should ever have...
    }

    $groupTopicObject->text($text);

    $groupTopicObject->putKeyed(
        'PREFERENCE',
        {
            type  => 'Set',
            name  => 'GROUP',
            title => 'GROUP',
            value => $membersString
        }
    );
    if ( defined($allowChangeString) ) {
        $groupTopicObject->putKeyed(
            'PREFERENCE',
            {
                type  => 'Set',
                name  => 'ALLOWTOPICCHANGE',
                title => 'ALLOWTOPICCHANGE',
                value => $allowChangeString
            }
        );
    }
    $groupTopicObject->putKeyed(
        'PREFERENCE',
        {
            type  => 'Set',
            name  => 'VIEW_TEMPLATE',
            title => 'VIEW_TEMPLATE',
            value => 'GroupView'
        }
    );

    #TODO: should also consider securing the new topic?
    my $user = $this->{session}->{user};
    $groupTopicObject->saveAs(
        web              => $groupWeb,
        topic            => $groupName,
        author           => $user,
        forcenewrevision => ( $groupName eq $Foswiki::cfg{SuperAdminGroup} )
        ? 1
        : 0
    );

}

=begin TML

---++ ObjectMethod removeFromGroup( $cuid, $group ) -> $boolean

=cut

sub removeUserFromGroup {
    my ( $this, $cuid, $groupName ) = @_;
    $groupName = Foswiki::Sandbox::untaint( $groupName,
        \&Foswiki::Sandbox::validateTopicName );
    my ( $groupWeb, $groupTopic ) =
      $this->{session}
      ->normalizeWebTopicName( $Foswiki::cfg{UsersWebName}, $groupName );

    throw Error::Simple( $this->{session}
          ->i18n->maketext( 'Users cannot be removed from [_1]', $groupName ) )
      if ( $groupName eq 'BaseGroup' );

    throw Error::Simple(
        $this->{session}->i18n->maketext(
            '[_1] cannot be removed from [_2]',
            (
                $Foswiki::cfg{AdminUserWikiName}, $Foswiki::cfg{SuperAdminGroup}
            )
        )
      )
      if ( $groupName eq "$Foswiki::cfg{SuperAdminGroup}"
        && $cuid eq 'BaseUserMapping_333' );

    my $user     = $this->{session}->{user};
    my $usersObj = $this->{session}->{users};

    if (
        $usersObj->isGroup($groupName)
        and ( $this->{session}
            ->topicExists( $Foswiki::cfg{UsersWebName}, $groupName ) )
      )
    {
        if (   !$usersObj->isInGroup( $cuid, $groupName, { expand => 0 } )
            && !$usersObj->isGroup($cuid) )
        {

            throw Error::Simple(
                $this->{session}->i18n->maketext(
                    'User [_1] not in group, cannot be removed', $cuid
                )
            );
        }
        my $groupTopicObject =
          Foswiki::Meta->load( $this->{session}, $Foswiki::cfg{UsersWebName},
            $groupName );
        if ( !$groupTopicObject->haveAccess( 'CHANGE', $user ) ) {

            throw Error::Simple(
                $this->{session}->i18n->maketext(
                    'User [_1] does not have CHANGE permission on [_2].',
                    ( $user, $groupName )
                )
            );
        }

        my $WikiName = $usersObj->getWikiName($cuid);
        my $LoginName = $usersObj->getLoginName($cuid) || '';

        my $membersString = $groupTopicObject->getPreference('GROUP');
        my @l;
        foreach my $ident ( split( /[\,\s]+/, $membersString ) ) {
            $ident =~ s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;
            next if ( $ident eq $WikiName );
            next if ( $ident eq $LoginName );
            next if ( $ident eq $cuid );
            push( @l, $ident );
        }
        $membersString = join( ', ', @l );

        Foswiki::Func::writeEvent( 'removeUserFromGroup',
            "$groupTopic: $WikiName removed by $user" );

        $this->_writeGroupTopic( $groupTopicObject, $groupWeb, $groupTopic,
            $membersString );

        $this->_clearGroupCache($groupName);

        return 1;
    }

    return 0;
}

=begin TML

---++ ObjectMethod _clearGroupCache( $groupName )

Removes the cache entries for unexpanded and expanded groups,
and searches un-expanded groups for any nesting group references
clearing them as well.

Note:  This is not recursive and does not attempt to handle
more than one level of nested groups.

=cut

sub _clearGroupCache {
    my ( $this, $groupName ) = @_;

    delete $this->{eachGroupMember}->{$groupName};
    delete $this->{singleGroupMembers}->{$groupName};

    #SMELL:  This should probably be recursive.
    foreach my $groupKey ( keys( %{ $this->{singleGroupMembers} } ) ) {
        if ( $this->{singleGroupMembers}->{$groupKey} =~ m/$groupName/ ) {

            #           print STDERR "Deleting cache for $groupKey \n";
            delete $this->{eachGroupMember}->{$groupKey};
            delete $this->{singleGroupMembers}->{$groupKey};
        }
    }
}

=begin TML

---++ ObjectMethod isAdmin( $cUID ) -> $boolean

True if the user is an admin
   * is $Foswiki::cfg{SuperAdminGroup}
   * is a member of the $Foswiki::cfg{SuperAdminGroup}

=cut

sub isAdmin {
    my ( $this, $cUID ) = @_;
    my $isAdmin = 0;

    # TODO: this might not apply now that we have BaseUserMapping - test
    if ( $cUID eq $Foswiki::cfg{SuperAdminGroup} ) {
        $isAdmin = 1;
    }
    else {
        my $sag = $Foswiki::cfg{SuperAdminGroup};
        $isAdmin = $this->isInGroup( $cUID, $sag );
    }

    return $isAdmin;
}

=begin TML

---++ ObjectMethod findUserByEmail( $email ) -> \@cUIDs
   * =$email= - email address to look up
Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

The password manager is asked first for whether it maps emails.
If it doesn't, then the user mapping manager is asked instead.

=cut

sub findUserByEmail {
    my ( $this, $email ) = @_;
    ASSERT($email) if DEBUG;
    my @users;
    if (  !$Foswiki::cfg{TopicUserMapping}{ForceManageEmails}
        && $this->{passwords}->isManagingEmails() )
    {
        my $logins = $this->{passwords}->findUserByEmail($email);
        if ( defined $logins ) {
            foreach my $l (@$logins) {
                $l = $this->login2cUID($l);
                push( @users, $l ) if $l;
            }
        }
    }
    else {

        # if the password manager didn't want to provide the service, ask
        # the user mapping manager
        unless ( $this->{_MAP_OF_EMAILS} ) {
            $this->{_MAP_OF_EMAILS} = {};
            my $it = $this->eachUser();
            while ( $it->hasNext() ) {
                my $uo = $it->next();
                map { push( @{ $this->{_MAP_OF_EMAILS}->{$_} }, $uo ); }
                  $this->getEmails($uo);
            }
        }
        push( @users, @{ $this->{_MAP_OF_EMAILS}->{$email} } )
          if ( $this->{_MAP_OF_EMAILS}->{$email} );
    }
    return \@users;
}

=begin TML

---++ ObjectMethod getEmails($name) -> @emailAddress

If $name is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

The password manager and user mapping manager are both consulted for emails
for each user (where they are actually found is implementation defined).

Duplicates are removed from the list.

=cut

sub getEmails {
    my ( $this, $user, $seen ) = @_;

    $seen ||= {};

    my %emails = ();

    if ( $seen->{$user} ) {

        #print STDERR "preventing infinit recursion in getEmails($user)\n";
    }
    else {
        $seen->{$user} = 1;

        if ( $this->isGroup($user) ) {
            my $it = $this->eachGroupMember($user);
            while ( $it->hasNext() ) {
                foreach ( $this->getEmails( $it->next(), $seen ) ) {
                    $emails{$_} = 1;
                }
            }
        }
        else {
            if (  !$Foswiki::cfg{TopicUserMapping}{ForceManageEmails}
                && $this->{passwords}->isManagingEmails() )
            {

                # get emails from the password manager
                foreach ( $this->{passwords}
                    ->getEmails( $this->getLoginName($user), $seen ) )
                {
                    $emails{$_} = 1;
                }
            }
            else {

                # And any on offer from the user mapping manager
                foreach ( mapper_getEmails( $this->{session}, $user ) ) {
                    $emails{$_} = 1;
                }
            }
        }
    }
    return keys %emails;
}

=begin TML

---++ ObjectMethod setEmails($cUID, @emails) -> boolean

Set the email address(es) for the given user.
The password manager is tried first, and if it doesn't want to know the
user mapping manager is tried.

=cut

sub setEmails {
    my $this = shift;
    my $user = shift;

    if (  !$Foswiki::cfg{TopicUserMapping}{ForceManageEmails}
        && $this->{passwords}->isManagingEmails() )
    {
        $this->{passwords}->setEmails( $this->getLoginName($user), @_ );
    }
    else {
        mapper_setEmails( $this->{session}, $user, @_ );
    }
}

=begin TML

---++ StaticMethod mapper_getEmails($session, $user)

Only used if passwordManager->isManagingEmails= = =false or
$Foswiki::cfg{TopicUserMapping}{ForceManageEmails} is enabled.
(The emails are stored in the user topics.

Note: This method is PUBLIC because it is used by the tools/upgrade_emails.pl
script, which needs to kick down to the mapper to retrieve email addresses
from Wiki topics.

=cut

sub mapper_getEmails {
    my ( $session, $user ) = @_;

    my $topicObject = Foswiki::Meta->load(
        $session,
        $Foswiki::cfg{UsersWebName},
        $session->{users}->getWikiName($user)
    );

    my @addresses;

    # Try the form first
    my $entry = $topicObject->get( 'FIELD', 'Email' );
    if ($entry) {
        push( @addresses, split( /;/, $entry->{value} ) );
    }
    elsif ( defined $topicObject->text ) {

        # Now try the topic text
        foreach my $l ( split( /\r?\n/, $topicObject->text ) ) {
            if ( $l =~ m/^\s+\*\s+E-?mail:\s*(.*)$/mi ) {

                # SMELL: implicit unvalidated untaint
                push @addresses, split( /;/, $1 );
            }
        }
    }

    return @addresses;
}

=begin TML

---++ StaticMethod mapper_setEmails ($session, $user, @emails)

Only used if =passwordManager->isManagingEmails= = =false=
or $Foswiki::cfg{TopicUserMapping}{ForceManageEmails} is enabled.
(emails are stored in user topics

=cut

sub mapper_setEmails {
    my $session = shift;
    my $cUID    = shift;

    my $mails = join( ';', @_ );

    my $user = $session->{users}->getWikiName($cUID);

    my $topicObject =
      Foswiki::Meta->load( $session, $Foswiki::cfg{UsersWebName}, $user );

    if ( $topicObject->get('FORM') ) {

        # use the form if there is one
        $topicObject->putKeyed(
            'FIELD',
            {
                name       => 'Email',
                value      => $mails,
                title      => 'Email',
                attributes => 'h'
            }
        );
    }
    else {

        # otherwise use the topic text
        my $text = $topicObject->text() || '';
        unless ( $text =~ s/^(\s+\*\s+E-?mail:\s*).*$/$1$mails/mi ) {
            $text .= "\n   * Email: $mails\n";
        }
        $topicObject->text($text);
    }

    $topicObject->save();
}

=begin TML

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

See baseclass for documentation

The $skipExistanceCheck parameter
is private to this module, and blocks the standard existence check
to avoid reading .htpasswd when checking group memberships).

=cut

sub findUserByWikiName {
    my ( $this, $wn, $skipExistanceCheck ) = @_;
    my @users = ();

    if ( $this->isGroup($wn) ) {
        push( @users, $wn );
    }
    elsif ( $Foswiki::cfg{Register}{AllowLoginName} ) {

        #        print STDERR "AllowLoginName discovered \n";

        # Add additional mappings defined in WikiUsers
        $this->_loadMapping();
        if ( $this->{W2U}->{$wn} ) {

            # Wikiname to UID mapping is defined
            my $user = $this->{W2U}->{$wn};
            push( @users, $user ) if $user;
        }
        else {

           # Bloody compatibility!
           # The wikiname is always a registered user for the purposes of this
           # mapping. We have to do this because Foswiki defines access controls
           # in terms of mapped users, and if a wikiname is *missing* from the
           # mapping there is "no such user".
            my $user = $this->login2cUID($wn);
            push( @users, $user ) if $user;
        }
    }
    else {

        #        print STDERR "NOT AllowLoginName \n";

        # The wikiname is also the login name, so we can just convert
        # it directly to a cUID
        my $cUID = $this->login2cUID($wn);

        #        print STDERR "login2cUID for $wn returned $cUID \n";

 #        print STDERR "$wn EXISTS \n" if ( $cUID && $this->userExists($cUID) );
        if ( $skipExistanceCheck || ( $cUID && $this->userExists($cUID) ) ) {
            push( @users, $cUID );
        }
    }
    return \@users;
}

=begin TML

---++ ObjectMethod checkPassword( $login, $password ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my ( $this, $login, $pw ) = @_;

 # If we don't have a PasswordManager and use TemplateLogin,  always allow login
    return 1
      if ( $Foswiki::cfg{PasswordManager} eq 'none'
        && $Foswiki::cfg{LoginManager} eq
        'Foswiki::LoginManager::TemplateLogin' );

    return $this->{passwords}->checkPassword( $login, $pw );
}

=begin TML

---++ ObjectMethod setPassword( $cUID, $newPassU, $oldPassU ) -> $boolean

BEWARE: $user should be a cUID, but is a login when the resetPassword
functionality is used.
The UserMapper needs to convert either one to a valid login for use by
the Password manager

TODO: needs fixing

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
    my ( $this, $user, $newPassU, $oldPassU ) = @_;
    ASSERT($user) if DEBUG;
    my $login = $this->getLoginName($user) || $user;
    return $this->{passwords}->setPassword( $login, $newPassU, $oldPassU );
}

=begin TML

---++ ObjectMethod passwordError( ) -> $string

returns a string indicating the error that happened in the password handlers
TODO: these delayed error's should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my ($this) = @_;
    return $this->{passwords}->error();
}

=begin TML

---++ ObjectMethod validateRegistrationField($field, $value ) -> $string

This method is called for every field submitted during registration.  It is also used
to validate the username when adding a member to a group.

Returns a string containing the sanitized registration field, or can throw an Error::Simple
if the field contains illegal data to block the registration.

returns the string unchanged if no issue found.

=cut

sub validateRegistrationField {

    #my ($this, $field, $value) = @_;
    my $this = shift;

# For now just let Foswiki::UserMapping do the validation - nothing special needed.
    return $this->SUPER::validateRegistrationField(@_);
}

# TODO: and probably flawed in light of multiple cUIDs mapping to one wikiname
sub _cacheUser {
    my ( $this, $wikiname, $login ) = @_;
    ASSERT($wikiname) if DEBUG;

    $login ||= $wikiname;

    #discard users that are the BaseUserMapper's responsibility
    return
      if ( $this->{session}->{users}->{basemapping}
        ->handlesUser( undef, $login, $wikiname ) );

    my $cUID = $this->login2cUID( $login, 1 );
    return unless ($cUID);
    ASSERT($cUID) if DEBUG;

    #$this->{U2L}->{$cUID}     = $login;
    $this->{U2W}->{$cUID}     = $wikiname;
    $this->{L2U}->{$login}    = $cUID;
    $this->{W2U}->{$wikiname} = $cUID;

    return $cUID;
}

# callback for search function to collate results
sub _collateGroups {
    my $ref   = shift;
    my $group = shift;
    return unless $group;
    push( @{ $ref->{list} }, $group );
}

# get a list of groups defined in this Wiki
sub _getListOfGroups {
    my $this  = shift;
    my $reset = shift;

    ASSERT( $this->isa('Foswiki::Users::TopicUserMapping') ) if DEBUG;

    if ( !$this->{groupsList} || $reset ) {
        my $users = $this->{session}->{users};
        $this->{groupsList} = [];

        #create a MetaCache _before_ we do silly things with the session's users
        $this->{session}->search->metacache();

        # Temporarily set the user to admin, otherwise it cannot see groups
        # where %USERSWEB% is protected from view
        local $this->{session}->{user} = $Foswiki::cfg{SuperAdminGroup};

        $this->{session}->search->searchWeb(
            _callback => \&_collateGroups,
            _cbdata   => {
                list  => $this->{groupsList},
                users => $users
            },
            web       => $Foswiki::cfg{UsersWebName},
            topic     => "*Group",
            scope     => 'topic',
            search    => '1',
            type      => 'query',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            format    => '$topic',
            separator => '',
        );
    }
    return $this->{groupsList};
}

# Build hash to translate between username (e.g. jsmith)
# and WikiName (e.g. Main.JaneSmith).
# PRIVATE subclasses should *not* implement this.
sub _loadMapping {
    my $this = shift;

    return if $this->{CACHED};
    $this->{CACHED} = 1;

  #TODO: should only really do this mapping IF the user is in the password file.
  #       except if we can't 'fetchUsers' like in the Passord='none' case -
  #       in which case the only time we
  #       know a login is real, is when they are logged in :(
    if (   ( $Foswiki::cfg{Register}{AllowLoginName} )
        || ( !$this->{passwords}->canFetchUsers() ) )
    {
        my $session = $this->{session};
        if (
            $session->topicExists(
                $Foswiki::cfg{UsersWebName},
                $Foswiki::cfg{UsersTopicName}
            )
          )
        {
            my $usersTopicObject = Foswiki::Meta->load(
                $session,
                $Foswiki::cfg{UsersWebName},
                $Foswiki::cfg{UsersTopicName}
            );
            my $text = $usersTopicObject->text() || '';

            # Get the WikiNames and userids, and build hashes in both directions
            # This matches:
            #   * WikiGuest - guest - 10 Mar 2005
            #   * WikiGuest - 10 Mar 2005
            $text =~
s/^\s*\* (?:$Foswiki::regex{webNameRegex}\.)?($Foswiki::regex{wikiWordRegex})\s*(?:-\s*(\S+)\s*)?-.*$/(_cacheUser( $this, $1, $2)||'')/gme;
        }
    }
    else {

       #loginnames _are_ WikiNames so ask the Password handler for list of users
        my $iter = $this->{passwords}->fetchUsers();
        while ( $iter->hasNext() ) {
            my $login = $iter->next();
            _cacheUser( $this, $login, $login );
        }
    }
}

# Get a list of *canonical user ids* from a text string containing a
# list of user *wiki* names, *login* names, and *group ids*.
sub _expandUserList {
    my ( $this, $names, $expand ) = @_;

    $expand = 1 unless ( defined $expand );

    #    print STDERR "_expandUserList called  $names - expand $expand \n";

    $names ||= '';

    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC # something else"
    $names =~ s/(<[^>]*>)//g;    # Remove HTML tags

    my @l;
    foreach my $ident ( split( /[\,\s]+/, $names ) ) {

        # Dump the web specifier if userweb
        $ident =~ s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;
        next unless $ident;
        if ( $this->isGroup($ident) ) {
            if ( !$expand ) {
                push( @l, $ident );
            }
            else {
                my $it =
                  $this->eachGroupMember( $ident, { expand => $expand } );
                while ( $it->hasNext() ) {
                    push( @l, $it->next() );
                }
            }
        }
        else {

            # Might be a wiki name (wiki names may map to several cUIDs)
            my %namelist =
              map { $_ => 1 }
              @{ $this->{session}->{users}->findUserByWikiName($ident) };

            # If we were not successful in finding by WikiName we assumed it
            # may be a login name (login names map to a single cUID).
            # If user is unknown we return whatever was listed so we can
            # remove deleted or misspelled users
            unless (%namelist) {
                my $cUID = $this->{session}->{users}->getCanonicalUserID($ident)
                  || $ident;
                $namelist{$cUID} = 1 if $cUID;
            }
            push( @l, keys %namelist );
        }
    }
    return \@l;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2007-2008 Sven Dowideit, SvenDowideit@fosiki.com
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
