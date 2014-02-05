# See bottom of file for license and copyright information
package Foswiki::Contrib::DBIStoreContrib::Personality::mysql;

use strict;
use warnings;

use Foswiki::Contrib::DBIStoreContrib::Personality ();
our @ISA = ('Foswiki::Contrib::DBIStoreContrib::Personality');

sub startup {
    my ($this) = @_;

    # MySQL has to be kicked in the ANSIs
    $this->{store}->{handle}->do("SET sql_mode='ANSI'");
    $this->{store}->{handle}->do('SELECT @sql_mode');
}

sub regexp {
    my ( $this, $lhs, $rhs ) = @_;

    unless ( $rhs =~ s/^'(.*)'$/$1/s ) {

        # Somewhat risky....
        return "$lhs REGEXP $rhs";
    }

    # MySQL uses POSIX regular expressions.

    # The macro parser does horrible things with \, causing \\
    # to become \\\. Force it back to \\
    $rhs =~ s/\\{3}/\\\\/g;
    if ( quotemeta($rhs) eq $rhs ) {
        return "$lhs='$rhs'";
    }

    # POSIX has no support for (?i: etc
    $rhs =~ s/^\(\?[a-z]+:(.*)\)$/$1/;              # remove (?:i)
                                                    # Nor hex character codes
    $rhs =~ s/\\x([0-9a-f]{2})/_char("0x$1")/gei;
    $rhs =~ s/\\x{([0-9a-f]+)}/_char("0x$1")/gei;

    # Nor \d, \D
    $rhs =~ s/(^|(?<=[^\\]))\\d/[0-9]/g;
    $rhs =~ s/(^|(?<=[^\\]))\\D/[^0-9]/g;

    # Nor \s, \S, \w, \W
    $rhs =~ s/(^|(?<=[^\\]))\\s/[ \011\012\015]/g;
    $rhs =~ s/(^|(?<=[^\\]))\\S/[^ \011\012\015]/g;
    $rhs =~ s/(^|(?<=[^\\]))\\w/[a-zA-Z0-9_]/g;
    $rhs =~ s/(^|(?<=[^\\]))\\W/[^a-zA-Z0-9_]/g;

    # Convert X? to (X|)
    $rhs =~ s/(?<=[^\\])(\(.*\)|\[.*?\]|\\.|.)\?/($1|)/g;    # ?
         # Handle special characters
    $rhs =~ s/(?<=[^\\])\\n/\n/g;             # will this work?
    $rhs =~ s/(?<=[^\\])\\r/\r/g;
    $rhs =~ s/(?<=[^\\])\\t/\t/g;
    $rhs =~ s/(?<=[^\\])\\b//g;               # not supported
    $rhs =~ s/(?<=[^\\])\{\d+(,\d*)?\}//g;    # not supported
                                              # Escape '
    $rhs =~ s/'/\\'/g;

    return "$lhs REGEXP '$rhs'";
}

sub cast_to_numeric {
    my ( $this, $d ) = @_;
    return "CAST(($d) AS DECIMAL)";
}

sub cast_to_text {
    my ( $this, $d ) = @_;
    return "CAST(($d) AS CHAR)";
}

sub length {
    return "char_length($_[1])";
}

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2013 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
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
