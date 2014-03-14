# See bottom of file for license and copyright information

=begin TML

---+ UNPUBLISHED package Foswiki::Prefs::Web

This class is a simple wrapper around Foswiki::Prefs::Stack. Since Webs has an
hierarchical structure it's needed only one stack to deal with preferences from
Web and Web/Subweb and Web/Subweb/Subsubweb. This class has a reference to a
stack and the level where the web is.

This class is used by Foswiki::Prefs to pass web preferences to Foswiki::Meta
and should not be used for anything else.

=cut

package Foswiki::Prefs::Web;
use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new( $session )

Creates a new WebPrefs object. 

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my ( $stack, $level ) = @_;
    my $this = {
        stack => $stack,
        level => $level,
    };
    return bless $this, $class;
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
    $this->{stack}->finish() if $this->{stack};
    undef $this->{stack};
    undef $this->{level};
}

=begin TML

---++ ObjectMethod isInTopOfStack() -> $boolean

Returns true if this web is the hihger of the underlying stack object.

=cut

sub isInTopOfStack {
    my $this = shift;
    return $this->{level} == $this->{stack}->size() - 1;
}

=begin TML

---++ ObjectMethod stack() -> $stack

Read-only accessor to the underlying stack object.

=cut

sub stack {
    return $_[0]->{stack};
}

=begin TML

---++ ObjectMethod cloneStack($level) -> $stack

This method clone the underlying stack object, to the given $level. See
Foswiki::Prefs::Stack::clone documentation.

This method exists because WebPrefs objects are used by Foswiki::Prefs instead
of bar Foswiki::Prefs::Stack and this operation is needed.

=cut

sub cloneStack {
    my ( $this, $level ) = @_;
    return $this->{stack}->clone($level);
}

=begin TML

---++ ObjectMethod get($pref) -> $value

Returns the $value of the given $pref.

=cut

sub get {
    my ( $this, $key ) = @_;
    $this->{stack}->getPreference( $key, $this->{level} );
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
