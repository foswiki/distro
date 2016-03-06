# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Access

A singleton object of this class manages the access control database.

=cut

package Foswiki::Access;
use v5.14;

use Assert;

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);

use constant MONITOR => 0;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

has session => (
    is       => 'rw',
    clearer  => 1,
    weak_ref => 1,
    isa      => Foswiki::Object::isaCLASS( 'session', 'Foswiki', noUndef => 1 ),
);
has failure => (
    is      => 'rw',
    clearer => 1,
);

=begin TML

---++ ClassMethod create($session)

Constructor. Never use new on Foswiki::Access!

=cut

sub create {
    my ( $class, $session ) = @_;

    my $imp = $Foswiki::cfg{AccessControl} || 'Foswiki::Access::TopicACLAccess';

    print STDERR "using $imp Access Control\n" if MONITOR;

    my $ok = eval("require $imp; 1;");
    ASSERT( $ok, $@ ) if DEBUG;
    my $this = $imp->new( session => $session, _indirect => 1, );
    ASSERT($this) if DEBUG;

    return $this;
}

around BUILDARGS => sub {
    my $orig = shift;

    my $params = $orig->(@_);

    ASSERT( $params->{_indirect},
            __PACKAGE__
          . "-derived object are to be instantiated using "
          . __PACKAGE__
          . "::create() constructor!" );

    delete $params->{_indirect};

    return $params;
};

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
#sub finish {
#    my $this = shift;
#    $this->clear_failure;
#    $this->clear_session;
#}

=begin TML

---++ ObjectMethod getReason() -> $string

Return a string describing the reason why the last access control failure
occurred.

=cut

sub getReason {
    my $this = shift;
    return $this->failure;
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
