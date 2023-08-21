# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Access

A singleton object of this class manages the access control database.

=cut

package Foswiki::Access;

use strict;
use warnings;
use Assert;

use constant MONITOR => 0;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new($session)

Constructor.

=cut

sub new {
    my ( $class, $session ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;
    my $imp = $Foswiki::cfg{AccessControl} || 'Foswiki::Access::TopicACLAccess';

    print STDERR "using $imp Access Control\n" if MONITOR;

    my $ok = eval("require $imp; 1;");
    ASSERT( $ok, $@ ) if DEBUG;
    my $this = $imp->new($session);
    ASSERT($this) if DEBUG;

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
    undef $this->{cache};
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

---++ ObjectMethod haveAccess($mode, $User, $web, $topic, $attachment) -> $boolean
---++ ObjectMethod haveAccess($mode, $User, $meta) -> $boolean
---++ ObjectMethod haveAccess($mode, $User, $address) -> $boolean

   * =$mode=  - 'VIEW', 'CHANGE', 'CREATE', etc. (defaults to VIEW)
   * =$cUID=    - Canonical user id (defaults to current user)
Check if the user has the given mode of access to the topic. This call
may result in the topic being read.

=cut

sub haveAccess {
    die 'base class';
}

=begin TML

---++ ObjectMethod getCacheEntry($meta, $mode, $cUID) -> $boolean

returns the cached access result for a given meta object

=cut

sub getCacheEntry {
    my ( $this, $meta, $mode, $cUID ) = @_;

    ASSERT($meta) if DEBUG;
    return unless $meta;
    return if defined $meta->{_topic} && !defined $meta->getLoadedRev();

    $cUID ||= $this->{session}->{user};
    my $path = $meta->getPath();

    my $key = $mode . '::' . $cUID;

    return $this->{cache}{$path}{$key};
}

=begin TML

---++ ObjectMethod setCacheEntry($meta, $mode, $cUID, $boolean) -> $boolean

caches the result for a computed access right

=cut

sub setCacheEntry {
    my ( $this, $meta, $mode, $cUID, $boolean ) = @_;

    ASSERT($meta) if DEBUG;

    return unless $meta;
    return $boolean
      if defined $meta->{_topic} && !defined $meta->getLoadedRev();

    $cUID ||= $this->{session}->{user};
    my $path = $meta->getPath();

    my $key = $mode . '::' . $cUID;
    $this->{cache}{$path}{$key} = $boolean;

    return $boolean;
}

=begin TML

---++ ObjectMethod unsetCacheEntry($meta, $mode, $cUID) 

deletes a cache result for a computed access right

=cut

sub unsetCacheEntry {
    my ( $this, $meta, $mode, $cUID ) = @_;

    ASSERT($meta) if DEBUG;

    return unless $meta;
    return if defined $meta->{_topic} && !defined $meta->getLoadedRev();

    $cUID ||= $this->{session}->{user};
    my $path = $meta->getPath();

    if ( defined $mode ) {
        my $key = $mode . '::' . $cUID;
        delete $this->{cache}{$path}{$key};
    }
    else {
        delete $this->{cache}{$path};
    }
}

1;

# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
