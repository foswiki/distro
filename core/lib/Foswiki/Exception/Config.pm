# See bottom of file for license and copyright information

package Foswiki::Exception::Config;
use Foswiki::Exception;

package Foswiki::Exception::Config::NoNextDef;

use Foswiki::Class;
extends qw<Foswiki::Exception>;
with qw<Foswiki::Exception::Harmless>;

# Role to prefix exception text with source file info.
package Foswiki::Exception::Config::SrcFile;

use Moo::Role;

has srcFile => ( is => 'ro', );
has srcLine => ( is => 'ro', );

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
    trigger   => 1,
);

sub BUILD {
    my $this = shift;

    $this->_setFromNodeObject;
}

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    my $nodeObject = $this->has_nodeObject ? $this->nodeObject : undef;

    # TODO Report sources too.
    my $keyInfo = $this->has_key
      || $nodeObject ? "key '" . $this->key . "' is " : "";

    my $sourceObject =
      defined $nodeObject
      ? $nodeObject
      : ( $this->has_section ? $this->section : undef );
    my $sourceInfo = '';
    if ( $sourceObject && @{ $sourceObject->sources } > 0 ) {
        $sourceInfo = " at "
          . join( ", ",
            map { $_->{file} . ( defined $_->{line} ? ":" . $_->{line} : "" ) }
              @{ $sourceObject->sources } );
    }

    my $sectionInfo =
      $this->has_section || $this->has_nodeObject
      ? " (${keyInfo}defined in section '"
      . $this->section . "'"
      . $sourceInfo . ")"
      : '';

    return $this->stringifyText . $sectionInfo . $this->stringifyPostfix;
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

# Sets key and section from nodeObject
sub _setFromNodeObject {
    my $this = shift;

    if ( $this->has_nodeObject ) {

        # Set section and key attrs manually if not set by user. This is to get
        # around a problem where exception is propagaded out of scope where
        # nodeObject's parent is defined making its fullName/fullPath methods
        # useless.
        unless ( $this->has_key ) {
            $this->key( $this->nodeObject->fullName );
        }
        unless ( $this->has_section ) {
            $this->section( $this->nodeObject->section );
        }
    }
}

sub _trigger_nodeObject {
    my $this = shift;

    $this->_setFromNodeObject;
}

package Foswiki::Exception::Config::BadSpecData;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::BadSpec);
with qw(Foswiki::Exception::Config::SrcFile);

around stringifyPostfix => sub {
    my $orig = shift;
    my $this = shift;

    my $errMsg = $orig->( $this, @_ );

    if ( defined $this->srcFile ) {
        $errMsg = " from " . $this->sourceInfo . " " . $errMsg;
    }

    return $errMsg;
};

package Foswiki::Exception::Config::BadSpecValue;

use Foswiki::Class;
extends qw(Foswiki::Exception::Config::BadSpec);
with qw(Foswiki::Exception::Config::SrcFile);

package Foswiki::Exception::Config::BadSpecSrc;

use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);
with qw(Foswiki::Exception::Config::SrcFile);

has '+srcFile' => (
    is       => 'ro',
    required => 1,
);

around stringifyText => sub {
    my $orig = shift;
    my $this = shift;

    my $errMsg = $orig->( $this, @_ );

    return "Failed to parse specs file " . $this->sourceInfo . ": " . $errMsg;
};

=begin TML

---+ Exception Foswiki::Exception::Config::InvalidKeyName

If configuration key doesn't pass validation.

=cut

package Foswiki::Exception::Config::InvalidKeyName;
use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);

has keyName => ( is => 'rw', required => 1, );

around stringifyText => sub {
    my $orig   = shift;
    my $this   = shift;
    my ($text) = @_;

    my $errMsg = $orig->( $this, @_ );
    my $key = $this->keyName;

    $errMsg .= " (the key is:"
      . ( defined $key ? ( ref($key) || $key ) : '*undef*' ) . ")";

    return $errMsg;
};

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
