# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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

=begin TML

---+ package Foswiki::Access

A singleton object of this class manages the access control database.

=cut

package Foswiki::Access;

use strict;
use Assert;

# Enable this for debug. Done as a sub to allow perl to optimise it out.
sub MONITOR { 0 }

=begin TML

---++ ClassMethod new($session)

Constructor.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

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
    undef $this->{failure};
    undef $this->{session};
}

=begin TML

---++ ObjectMethod getReason() -> $string

Return a string describing the reason why the last access control failure
occurred.

=cut

sub getReason {
    my $this = shift;

    return $this->{failure};
}

=begin TML

---++ ObjectMethod checkAccessPermission( $action, $user, $text, $meta, $topic, $web ) -> $boolean

Check if user is allowed to access topic
   * =$action=  - 'VIEW', 'CHANGE', 'CREATE', etc.
   * =$user=    - User id (*not* wikiname)
   * =$text=    - If undef or '': Read '$theWebName.$theTopicName' to check permissions
   * =$meta=    - If undef, but =$text= is defined, then metadata will be parsed from =$text=. If defined, then metadata embedded in =$text= will be ignored. Always ignored if =$text= is undefined. Settings in =$meta= override * Set settings in plain text.
   * =$topic=   - Topic name to check, e.g. 'SomeTopic' *undef to check web perms only)
   * =$web=     - Web, e.g. 'Know'
If the check fails, the reason can be recoveered using getReason.

=cut

sub checkAccessPermission {
    my ( $this, $mode, $user, $text, $meta, $topic, $web ) = @_;

    undef $this->{failure};

    print STDERR "Check $mode access $user to "
      . ( $web   || 'undef' ) . '.'
      . ( $topic || 'undef' ) . "\n"
      if MONITOR;

    # super admin is always allowed
    if ( $this->{session}->{users}->isAdmin($user) ) {
        print STDERR "$user - ADMIN\n" if MONITOR;
        return 1;
    }

    $mode = uc($mode);    # upper case

    my $prefs = $this->{session}->{prefs};

    my $allowText;
    my $denyText;

    # extract the * Set (ALLOWTOPIC|DENYTOPIC)$mode
    if ( defined $text ) {

        # override topic permissions.
        $allowText = $prefs->getTextPreferencesValue( 'ALLOWTOPIC' . $mode,
            $text, $meta, $web, $topic );
        $denyText = $prefs->getTextPreferencesValue( 'DENYTOPIC' . $mode,
            $text, $meta, $web, $topic );
    }
    elsif ($topic) {
        $allowText =
          $prefs->getTopicPreferencesValue( 'ALLOWTOPIC' . $mode, $web,
            $topic );
        $denyText =
          $prefs->getTopicPreferencesValue( 'DENYTOPIC' . $mode, $web, $topic );
    }

    # Check DENYTOPIC
    if ( defined($denyText) ) {
        if ( $denyText =~ /\S$/ ) {
            if ( $this->{session}->{users}->isInList( $user, $denyText ) ) {
                $this->{failure} =
                  $this->{session}->i18n->maketext('access denied on topic');
                print STDERR $this->{failure} . " ($denyText)\n" if MONITOR;
                return 0;
            }
        }
        else {

            # If DENYTOPIC is empty, don't deny _anyone_
            print STDERR "DENYTOPIC is empty\n" if MONITOR;
            return 1;
        }
    }

    # Check ALLOWTOPIC. If this is defined the user _must_ be in it
    if ( defined($allowText) && $allowText =~ /\S/ ) {
        if ( $this->{session}->{users}->isInList( $user, $allowText ) ) {
            print STDERR "in ALLOWTOPIC\n" if MONITOR;
            return 1;
        }
        $this->{failure} =
          $this->{session}->i18n->maketext('access not allowed on topic');
        print STDERR $this->{failure} . " ($allowText)\n" if MONITOR;
        return 0;
    }

    # Check DENYWEB, but only if DENYTOPIC is not set (even if it
    # is empty - empty means "don't deny anybody")
    unless ( defined($denyText) ) {
        $denyText = $prefs->getWebPreferencesValue( 'DENYWEB' . $mode, $web );
        if ( defined($denyText)
            && $this->{session}->{users}->isInList( $user, $denyText ) )
        {
            $this->{failure} =
              $this->{session}->i18n->maketext('access denied on web');
            print STDERR $this->{failure} . "\n" if MONITOR;
            return 0;
        }
    }

    # Check ALLOWWEB. If this is defined and not overridden by
    # ALLOWTOPIC, the user _must_ be in it.
    $allowText = $prefs->getWebPreferencesValue( 'ALLOWWEB' . $mode, $web );

    if ( defined($allowText) && $allowText =~ /\S/ ) {
        unless ( $this->{session}->{users}->isInList( $user, $allowText ) ) {
            $this->{failure} =
              $this->{session}->i18n->maketext('access not allowed on web');
            print STDERR $this->{failure} . "\n" if MONITOR;
            return 0;
        }
    }

    # Check DENYROOT and ALLOWROOT, but only if web is not defined
    unless ($web) {
        $denyText = $prefs->getPreferencesValue( 'DENYROOT' . $mode, $web );
        if ( defined($denyText)
            && $this->{session}->{users}->isInList( $user, $denyText ) )
        {
            $this->{failure} =
              $this->{session}->i18n->maketext('access denied on root');
            print STDERR $this->{failure} . "\n" if MONITOR;
            return 0;
        }

        $allowText = $prefs->getPreferencesValue( 'ALLOWROOT' . $mode, $web );

        if ( defined($allowText) && $allowText =~ /\S/ ) {
            unless ( $this->{session}->{users}->isInList( $user, $allowText ) )
            {
                $this->{failure} =
                  $this->{session}
                  ->i18n->maketext('access not allowed on root');
                print STDERR $this->{failure} . "\n" if MONITOR;
                return 0;
            }
        }
    }

    if (MONITOR) {
        print STDERR "OK, permitted\n";
        print STDERR "ALLOW: $allowText\n" if defined $allowText;
        print STDERR "DENY: $denyText\n"   if defined $denyText;
    }
    return 1;
}

1;
