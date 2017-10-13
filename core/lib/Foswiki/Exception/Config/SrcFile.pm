# See bottom of file for license and copyright information

package Foswiki::Exception::Config::SrcFile;

=begin TML

---+!! Role Foswiki::Exception::Config::SrcFile

Used to prefix exception text with source file info.

=cut

use Moo::Role;
use namespace::clean;

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute srcFile

Source file name. Read only.

=cut

has srcFile => ( is => 'ro', required => 1, );

=begin TML

---+++ ObjectAttribute srcLine

Source line in the file. Read only.

=cut

has srcLine => ( is => 'ro', );

=begin TML

---++ METHODS

=cut

=begin TML

---+++ ObjectMethod sourceInfo

Returns a string with source file and line (if latter is defined).

=cut

sub sourceInfo {
    my $this = shift;

    my $file = $this->srcFile;
    if ( UNIVERSAL::isa( $file, 'Foswiki::File' ) ) {
        $file = $file->path;
    }
    if ( $file && defined $this->srcLine ) {
        $file .= ":" . $this->srcLine;
    }

    return $file // '';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2017 Foswiki Contributors. Foswiki Contributors
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
