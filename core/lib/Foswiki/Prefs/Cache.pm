# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Prefs::Cache

Preferences cache. This can be the preferences for a single topic, or
may be preferences for a single scope such as SESSION.

=cut

package Foswiki::Prefs::Cache;

use strict;
use Assert;

use Foswiki::Prefs::Parser ();

=begin TML

---++ ClassMethod new( $obj )

Creates a new topic preferences object and (if $obj is defined)
loads preferences from a topic.

=cut

sub new {
    my ( $class, $obj ) = @_;
    my $this = bless(
        {
            locals => {},
            values => {},
        },
        $class
    );

    if ( UNIVERSAL::isa( $obj, 'Foswiki::Meta' ) ) {
        $this->{web}   = $obj->web();
        $this->{topic} = $obj->topic();
        Foswiki::Prefs::Parser::parse( $obj, $this );
    }
    elsif ( UNIVERSAL::isa( $obj, 'Foswiki::Prefs::Cache' ) ) {

        # Copy all from the other cache
        $this->{web}   = $obj->{web};
        $this->{topic} = $obj->{topic};
        while ( my ( $k, $v ) = each %{ $obj->{values} } ) {
            $this->{values}->{$k} = $v;
        }
        while ( my ( $k, $v ) = each %{ $obj->{locals} } ) {
            $this->{locals}->{$k} = $v;
        }
    }

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
    undef $this->{values};
    undef $this->{locals};
}

=begin TML

---++ ObjectMethod insert($type, $key, $val) -> $boolean

Adds a key-value pair of the given type to the object. Type is Set or Local.
Callback used for the Prefs::Parser object, or can be used to add
arbitrary new entries to a prefs cache.

Returns 1 if the preference was defined, 0 otherwise.

=cut

# Callback used for the Prefs::Parser object
sub insert {
    my ( $this, $type, $key, $value ) = @_;

    $value = '' unless defined $value;
    $value =~ tr/\t/ /;                  # replace TAB by space
    $value =~ s/([^\\])\\n/$1\n/g;       # replace \n by new line
    $value =~ s/([^\\])\\\\n/$1\\n/g;    # replace \\n by \n
    $value =~ tr/`//d;                   # filter out dangerous chars
    if ( $type eq 'Local' ) {
        $this->{locals}->{$key} = $value;
    }
    else {
        $this->{values}->{$key} = $value;
    }

    return 1;
}

sub get {
    my ( $this, $key ) = @_;
    return $this->{values}->{$key};
}

sub getLocal {
    my ( $this, $key ) = @_;
    return $this->{locals}->{$key};
}

1;
__END__

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some of the code in this file, as follows

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2001-2008 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
