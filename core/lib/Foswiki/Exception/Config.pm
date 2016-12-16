# See bottom of file for license and copyright information

package Foswiki::Exception::Config;
use Foswiki::Exception;

package Foswiki::Exception::Config::NoNextDef;

use Foswiki::Class;
extends qw(Foswiki::Exception::Harmless);

package Foswiki::Exception::Config::BadSpec;

use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);

has section => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    builder   => 'prepareSection',
);
has key => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    builder   => 'prepareKey',
);
has nodeObject => (
    is        => 'rw',
    predicate => 1,
);

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    my $keyInfo = $this->has_key ? "key '" . $this->key . "' is " : "";
    my $sectionInfo =
      $this->has_section
      ? " (${keyInfo}part of section '" . $this->section . "')"
      : '';

    return $this->text . $sectionInfo . $this->stringifyPostfix;
};

sub prepareSection {
    my $this = shift;

    if ( $this->has_nodeObject ) {
        return $this->nodeObject->section;
    }
}

sub prepareKey {
    my $this = shift;

    if ( $this->has_nodeObject ) {
        return $this->nodeObject->fullName;
    }
}

package Foswiki::Exception::Config::BadSpecData;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::BadSpec);

package Foswiki::Exception::Config::BadSpecValue;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::BadSpec);

package Foswiki::Exception::Config::BadSpecSrc;

use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);

has file => (
    is       => 'ro',
    required => 1,
);

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    my $errMsg = $orig->( $this, @_ );

    my $file = $this->file;
    if ( UNIVERSAL::isa( $file, 'Foswiki::File' ) ) {
        $file = $file->path;
    }

    return "Failed to parse specs file " . $file . ": " . $errMsg;
};

=begin TML

---+ Exception Foswiki::Exception::Config::InvalidKeyName

If configuration key doesn't pass validation.

=cut

package Foswiki::Exception::Config::InvalidKeyName;
use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);

has keyName => ( is => 'rw', required => 1, );

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
