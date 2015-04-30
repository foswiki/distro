# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Access::TopicACLAccess

Implements the traditional, longstanding ACL in topic preference style.

=cut

package Foswiki::Access::TopicACLAccess;

use Foswiki::Access;
@ISA = qw(Foswiki::Access);

use constant MONITOR => 0;

use strict;
use Assert;

use Foswiki          ();
use Foswiki::Address ();
use Foswiki::Meta    ();
use Foswiki::Users   ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my ( $class, $session ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;
    my $this = bless( { session => $session }, $class );

    return $this;
}

=begin TML

---++ ObjectMethod haveAccess($mode, $User, $web, $topic, $attachment) -> $boolean
---++ ObjectMethod haveAccess($mode, $User, $meta) -> $boolean
---++ ObjectMethod haveAccess($mode, $User, $address) -> $boolean

   * =$mode=  - 'VIEW', 'CHANGE', 'CREATE', etc. (defaults to VIEW)
   * =$cUID=    - Canonical user id (defaults to current user)
Check if the user has the given mode of access to the topic. This call
may result in the topic being read.

=cut

sub haveAccess {
    my ( $this, $mode, $cUID, $param1, $param2, $param3 ) = @_;
    $mode ||= 'VIEW';
    $cUID ||= $this->{session}->{user};

    my $session = $this->{session};
    undef $this->{failure};

    return 1
      if ( defined $Foswiki::cfg{LoginManager}
        && $Foswiki::cfg{LoginManager} eq 'none' );

    my $meta;

    if ( ref($param1) eq '' ) {

        #scalar - treat as web, topic
        $meta = Foswiki::Meta->load( $session, $param1, $param2 );
        ASSERT( not defined($param3) )
          if DEBUG
          ;    #attachment ACL not currently supported in traditional topic ACL
    }
    else {
        if ( ref($param1) eq 'Foswiki::Address' ) {
            $meta =
              Foswiki::Meta->load( $session, $param1->web(), $param1->topic() );
        }
        else {
            $meta = $param1;
        }
    }
    ASSERT( $meta->isa('Foswiki::Meta') ) if DEBUG;

    print STDERR "Check $mode access $cUID to " . $meta->getPath() . "\n"
      if MONITOR;

    # super admin is always allowed
    if ( $session->{users}->isAdmin($cUID) ) {
        print STDERR "$cUID - ADMIN\n" if MONITOR;
        return 1;
    }

    $mode = uc($mode);

    my ( $allow, $deny );
    if ( $meta->{_topic} ) {

        $allow = $this->_getACL( $meta, 'ALLOWTOPIC' . $mode );
        $deny  = $this->_getACL( $meta, 'DENYTOPIC' . $mode );

        # Check DENYTOPIC
        if ( defined($deny) ) {
            if ( scalar(@$deny) != 0 ) {
                if ( $session->{users}->isInUserList( $cUID, $deny ) ) {
                    $this->{failure} =
                      $session->i18n->maketext('access denied on topic');
                    print STDERR 'a ' . $this->{failure}, "\n" if MONITOR;
                    return 0;
                }
            }
            elsif ( $Foswiki::cfg{AccessControlACL}{EnableDeprecatedEmptyDeny} )
            {

                # If DENYTOPIC is empty, don't deny _anyone_
                # DEPRECATED SYNTAX.   Recommended replace with "ALLOWTOPIC=*"
                print STDERR "Access allowed: deprecated DENYTOPIC is empty\n"
                  if MONITOR;
                return 1;
            }
        }

        # Check ALLOWTOPIC. If this is defined the user _must_ be in it
        if ( defined($allow) && scalar(@$allow) != 0 ) {
            if ( $session->{users}->isInUserList( $cUID, $allow ) ) {
                print STDERR "in ALLOWTOPIC\n" if MONITOR;
                return 1;
            }
            $this->{failure} =
              $session->i18n->maketext('access not allowed on topic');
            print STDERR 'b ' . $this->{failure}, "\n" if MONITOR;
            return 0;
        }
        $meta = $meta->getContainer();    # Web
    }

    if ( $meta->{_web} ) {

        $deny = $this->_getACL( $meta, 'DENYWEB' . $mode );
        if ( defined($deny)
            && $session->{users}->isInUserList( $cUID, $deny ) )
        {
            $this->{failure} = $session->i18n->maketext('access denied on web');
            print STDERR 'c ' . $this->{failure}, "\n" if MONITOR;
            return 0;
        }

        # Check ALLOWWEB. If this is defined and not overridden by
        # ALLOWTOPIC, the user _must_ be in it.
        $allow = $this->_getACL( $meta, 'ALLOWWEB' . $mode );

        if ( defined($allow) && scalar(@$allow) != 0 ) {
            unless ( $session->{users}->isInUserList( $cUID, $allow ) ) {
                $this->{failure} =
                  $session->i18n->maketext('access not allowed on web');
                print STDERR 'd ' . $this->{failure}, "\n" if MONITOR;
                return 0;
            }
        }

    }
    else {

        # No web, we are checking at the root. Check DENYROOT and ALLOWROOT.
        $deny = $this->_getACL( $meta, 'DENYROOT' . $mode );

        if ( defined($deny)
            && $session->{users}->isInUserList( $cUID, $deny ) )
        {
            $this->{failure} =
              $session->i18n->maketext('access denied on root');
            print STDERR 'e ' . $this->{failure}, "\n" if MONITOR;
            return 0;
        }

        $allow = $this->_getACL( $meta, 'ALLOWROOT' . $mode );

        if ( defined($allow) && scalar(@$allow) != 0 ) {
            unless ( $session->{users}->isInUserList( $cUID, $allow ) ) {
                $this->{failure} =
                  $session->i18n->maketext('access not allowed on root');
                print STDERR 'f ' . $this->{failure}, "\n" if MONITOR;
                return 0;
            }
        }
    }

    if (MONITOR) {
        print STDERR "OK, permitted\n";
        print STDERR 'ALLOW: ' . join( ',', @$allow ) . "\n" if defined $allow;
        print STDERR 'DENY: ' . join( ',', @$deny ) . "\n" if defined $deny;
    }
    return 1;
}

# Get an ACL preference. Returns a reference to a list of cUIDs, or undef.
# If the preference is defined but is empty, then a reference to an
# empty list is returned.
# This function canonicalises the parsing of a users list. Is this the right
# place for it?
sub _getACL {
    my ( $this, $meta, $mode ) = @_;

    if ( defined $meta->topic && !defined $meta->getLoadedRev ) {

        # Lazy load the latest version.
        $meta->loadVersion();
    }

    my $text = $meta->getPreference($mode);
    return undef unless defined $text;

    # Remove HTML tags (compatibility, inherited from Users.pm
    $text =~ s/(<[^>]*>)//g;

    # Dump the users web specifier if userweb
    my @list = grep { /\S/ } map {
        s/^($Foswiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;
        $_
    } split( /[,\s]+/, $text );

    #print STDERR "getACL($mode): ".join(', ', @list)."\n";

    return \@list;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

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
