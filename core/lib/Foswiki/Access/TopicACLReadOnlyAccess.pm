# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Access::AdminOnlyAccess

DENY any access except VIEW access - Admin permitted anythingeverything

=cut

package Foswiki::Access::TopicACLReadOnlyAccess;

use Foswiki::Access::TopicACLAccess;
@ISA = qw(Foswiki::Access::TopicACLAccess);
use constant MONITOR => 0;

use strict;
use Assert;

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

---++ ObjectMethod haveAccess($mode, $cUID, ...) -> $boolean

   * =$mode=  - 'VIEW', 'CHANGE', 'CREATE', etc. (defaults to VIEW)
   * =$cUID=    - Canonical user id (defaults to current user)
Check if the user has the given mode of access to the topic. This call
may result in the topic being read.

=cut

sub haveAccess {
    my ( $this, $mode, $cUID, $param1, $param2 ) = @_;
    $mode ||= 'VIEW';
    $cUID ||= $this->{session}->{user};

    my $session = $this->{session};
    undef $this->{failure};

    print STDERR "Check $mode access $cUID \n"
      if MONITOR;

    # super admin is always allowed
    if ( $session->{users}->isAdmin($cUID) ) {
        print STDERR "$cUID - ADMIN\n" if MONITOR;
        return 1;
    }

    unless ( $mode eq 'VIEW' ) {
        $this->{failure} = 'Denied: Entire site is READ ONLY: ';
        print STDERR "$cUID - deny non-VIEW \n" if MONITOR;
        return 0;
    }
    return $this->SUPER::haveAccess( $mode, $cUID, $param1, $param2 );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
