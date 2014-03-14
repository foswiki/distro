# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Prefs::TopicRAM

This is a preference backend used to get preferences defined in a topic.

=cut

# See documentation on Foswiki::Prefs::BaseBackend to get details about the
# methods.

package Foswiki::Prefs::TopicRAM;

use strict;
use warnings;

use Foswiki::Prefs::BaseBackend ();
our @ISA = qw(Foswiki::Prefs::BaseBackend);

use Foswiki::Prefs::Parser ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my ( $proto, $topicObject ) = @_;

    my $this = $proto->SUPER::new();
    $this->{values} = {};
    $this->{local}  = {};

    if ( $topicObject->existsInStore() ) {
        Foswiki::Prefs::Parser::parse( $topicObject, $this );
    }
    $this->{topicObject} = $topicObject;

    return $this;
}

sub finish {
    my $this = shift;
    undef $this->{values};
    undef $this->{local};
    undef $this->{topicObject};
}

=begin TML

---++ ObjectMethod topicObject() -> $topicObject

Accessor to the topicObject used to create this object.

=cut

sub topicObject {
    my $this = shift;
    return $this->{topicObject};
}

sub prefs {
    my $this = shift;
    return keys %{ $this->{values} };
}

sub localPrefs {
    my $this = shift;
    return keys %{ $this->{local} };
}

sub get {
    my ( $this, $key ) = @_;
    return $this->{values}{$key};
}

sub getLocal {
    my ( $this, $key ) = @_;
    return $this->{local}{$key};
}

sub insert {
    my ( $this, $type, $key, $value ) = @_;

    $this->cleanupInsertValue( \$value );

    my $index = $type eq 'Set' ? 'values' : 'local';
    $this->{$index}{$key} = $value;
    return 1;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
