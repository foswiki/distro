# See bottom of file for license and copyright information
# Foswiki::I18N::Fallback - a fallback class for when
# Locale::Maketext isn't available.

package Foswiki::I18N::Fallback;

use strict;
use warnings;

use Foswiki::I18N ();
our @ISA = ('Foswiki::I18N');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my $class = shift;
    my $this = bless( {}, $class );
    return $this;
}

sub finish {

    # No data, nothing to do.
    # Must call SUPER finish to avoid memory leaks
    my $this = shift;
    $this->SUPER::finish(@_);
}

sub maketext {
    my ( $this, $text, @args ) = @_;

    return '' unless $text;

    # substitute parameters:
    $text =~ s/\[\_(\d+)\]/$args[$1-1]/ge;

    # unescape escaped square brackets:
    $text =~ s/~(\[|\])/$1/g;

    #plurals:
    $text =~
      s/\[\*,\_(\d+),([^,]+)(,([^,]+))?\]/_handlePlurals($args[$1-1],$2,$4)/ge;

    return $text;
}

sub _handlePlurals {
    my ( $number, $singular, $plural ) = @_;

    # bad hack, but Locale::Maketext does it the same way ;)
    return
      $number . ' '
      . (
        ( $number == 1 )
        ? $singular
        : ( $plural ? ($plural) : ( $singular . 's' ) )
      );
}

sub language {
    return 'en';
}

sub enabled_languages {
    my $this = shift;
    return $this->{enabled_languages};
}

sub fromSiteCharSet {
    my ( $this, $text ) = @_;
    return $text;
}

sub toSiteCharSet {
    my ( $this, $text ) = @_;
    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
