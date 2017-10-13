# See bottom of file for license and copyright information

=begin TML

---+!! Class Foswiki::Exception::FileOp

Base exception for failed file system operations. Could be used for any kind
of file system object including files, directories, etc. Could automatically
pick up =errno= (=$!=) and form default error message.

=cut

package Foswiki::Exception::FileOp;

use POSIX qw<strerror>;

use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute file -> string

Object name on which the error happened.

=cut

has file => ( is => 'rw', required => 1, );

=begin TML

---+++ ObjectAttribute op -> string

Operation that caused the problem. Could be any verb which would fit after
_"Failed to "_ words. For example, _"read"_, _"write"_, _"open directory"_.

=cut

has op => ( is => 'rw', required => 1, );

=begin TML

---+++ ObjectAttribute errno -> integer

=errno= value. If not set by invoking code then picks the latest =$!= value.

=cut

has errno => ( is => 'rw', builder => 'prepareErrno', );

=begin TML

---++ METHODS

=cut

=begin TML

---+++ ObjectMethod stringify

Overrides the base class method.

=cut

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    return "Failed to " . $this->op . " " . $this->file . ": " . $orig->($this);
};

=begin TML

---+++ ObjectMethod prepareText

Overrides the base class method. Uses =CPAN:POSIX= =strerror()= to generate
default text.

=cut

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return strerror( $this->errno );
};

=begin TML

---+++ ObjectMethod prepareErrno

Initializer for the =errno= attribute.

=cut

sub prepareErrno {
    return int($!);
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
