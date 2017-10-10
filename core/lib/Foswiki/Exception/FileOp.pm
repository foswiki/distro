# See bottom of file for license and copyright information

=begin TML

---+!! Class Foswiki::Exception::FileOp

Base exception for failed file operations.

Attributes:

| *Name* | *Description* | *Required* |
| =file= | File name | _yes_ |
| =op= | Operation caused the failure, single verb like 'read' | _yes' |

=cut

package Foswiki::Exception::FileOp;
use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);

has file  => ( is => 'rw', required => 1, );
has op    => ( is => 'rw', required => 1, );
has errno => ( is => 'rw', builder  => 'prepareErrno', );

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    return "Failed to " . $this->op . " " . $this->file . ": " . $orig->($this);
};

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return $!;    # text attribute to be set from last file operation error.
};

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
