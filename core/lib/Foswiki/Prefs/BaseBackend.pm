# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Prefs::BaseBackend

This is the base module for preferences backends. Its main purpose is to
document the interface and provide facilities methods.

=cut

package Foswiki::Prefs::BaseBackend;

use strict;
use warnings;
use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new(@_)

Creates a preferences backend object.

=cut

sub new {
    my ( $proto, $values ) = @_;
    my $class = ref($proto) || $proto;

    return bless {}, $class;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish { }

=begin TML

---++ ObjectMethod prefs() -> @preferenceKeys

Return a list with the names of defined preferences.

=cut

sub prefs {
    ASSERT('Pure virtual method - child classes must redefine');
}

=begin TML

---++ ObjectMethod localPrefs() -> @preferenceKeys

Return a list with the names of 'Local' preferences.

=cut

sub localPrefs {
    ASSERT('Pure virtual method - child classes must redefine');
}

=begin TML

---++ ObjectMethod get($key) -> $value

Return the value of the preference $key.

=cut

sub get {
    ASSERT('Pure virtual method - child classes must redefine');
}

=begin TML

---++ ObjectMethod getLocal($key) -> $value

Return the 'Local' value of the preference $key.

=cut

sub getLocal {
    ASSERT('Pure virtual method - child classes must redefine');
}

=begin TML

---++ ObjectMethod insert($type, $key, $value ) = @_;

Insert the preference named $key as $value. $type can be 'Local' or 'Set'.

=cut

sub insert {
    ASSERT('Pure virtual method - child classes must redefine');
}

=begin TML

---++ ObjectMethod cleanupInsertValue($value_ref)

Utility method that cleans $$vaue_ref for later use in insert().

=cut

sub cleanupInsertValue {
    my ( $this, $value_ref ) = @_;

    return unless defined $$value_ref;

    $$value_ref =~ tr/\r//d;                  # Delete \r
    $$value_ref =~ tr/\t/ /;                  # replace TAB by space
    $$value_ref =~ s/([^\\])\\n/$1\n/g;       # replace \n by new line
    $$value_ref =~ s/([^\\])\\\\n/$1\\n/g;    # replace \\n by \n
    $$value_ref =~ tr/`//d;                   # filter out dangerous chars
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
