# See bottom of file for license and copyright information

package Foswiki::File;

=begin TML

---+!! Class Foswiki::File

Simplistic object for in-memory manipulation with file content.

=cut

use Try::Tiny;
use File::stat;
use Foswiki::Exception ();

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute path

Full pathname to the file.

Required.

=cut

has path => (
    is       => 'ro',
    required => 1,
);

=begin TML

---+++ ObjectAttribute unicode

Wether to treat file content as unicode. Read-only.

=cut

has unicode => (
    is      => 'ro',
    builder => 'prepareUnicode',
);

=begin TML

---+++ ObjectAttribute binary

Wether to treat the file as binary (apply =binmode()= to the handle). Read-only.

=cut

has binary => (
    is      => 'ro',
    builder => 'prepareBinary',
);

=begin TML

---+++ ObjectAttribute content

File content, plain data. When changed sets =modified= attribute to _true_; if
=autoWrite= is set then the data is immediately flushed to disk.

Lazy.

=cut

has content => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    builder   => 'prepareContent',
    trigger   => 1,
);

=begin TML

---+++ ObjectAttribute stat

A =CPAN:File::stat= object.

Lazy. Always (re-)initialized by upon =content= attribute vivification.

=cut

has stat => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareStat',
);

=begin TML

---+++ ObjectAttribute raiseError

Boolean. If _false_ then setting the =exception= attribute will not raise
the exception.

Default: _true_

=cut

has raiseError => (
    is      => 'rw',
    builder => 'prepareRaiseError',
);

=begin TML

---+++ ObjectAttribute autoWrite

Boolean. =content= automatically flushed upon change if this attribute is
_true_.

Default: _true_

=cut

has autoWrite => (
    is      => 'rw',
    builder => 'prepareAutoWrite',
);

=begin TML

---+++ ObjectAttribute autoCreate

Boolean. If _true_ then file would be automatically created unless already
exists.

Default: _false_

=cut

has autoCreate => (
    is      => 'rw',
    builder => 'prepareAutoCreate',
);

=begin TML

---+++ ObjectAttribute modified

Boolean. Set to _true_ if =content= has been changed. Reset back to _false_
after successful =flush()= call or after =content= vivification. When
=autoWrite= is set then user's code will never see this one set unless =flush()=
fails.

=cut

has modified => (
    is      => 'rw',
    builder => 'prepareModified',
);

=begin TML

For internal use primarly. Will contains an exception object if an error occurs.
The exact type of exception object will depend on error's nature.

Setting this attribute triggers exception raising unless =raiseError= is reset.

=cut

has exception => (
    is      => 'rw',
    clearer => 1,
    builder => 'prepareException',
    trigger => 1,
);

=begin TML

---++ METHODS

=cut

stubMethods qw(prepareException);

sub DEMOLISH {
    my $this = shift;

    $this->flush if $this->modified && $this->autoWrite;
}

=begin TML

---+++ ObjectMethod throwFileOp( %params )

For internal use mostly.

Throws =Foswiki::Exception::FileOp= (unless different is specified in
parameters). The =%params= hash will mostly be passed over to exception's
constructor. Two keys of the hash are treated specially:

   $ exception: overrides the default exception class
   $ file: if not set in =%params= then will be auto set to the value of =path=
   attribute.

=cut

sub throwFileOp {
    my $this = shift;
    $this->_createException(@_)->throw;
}

=begin TML

---+++ ObjectMethod slurp()

Returns content of the file as a single chunk of data. Doesn't change the
=content= attribute but sets =exception= and returns empty string in case of an
error.

=cut

sub slurp {
    my $this = shift;

    my ( $fh, $content );

    return '' if ( !-e $this->path ) && $this->autoCreate;

    try {
        open( $fh, $this->_openmode("<"), $this->path )
          or $this->throwFileOp( op => "open", );

        binmode($fh) if $this->binary;

        local $/ = undef;

        $content = <$fh>;

        $this->throwFileOp( op => 'read', ) unless defined $content;
    }
    catch {
        $this->exception( Foswiki::Exception::Fatal->transmute( $_, 0 ) );
    }
    finally {
        close $fh;
    };

    return $content // '';
}

=begin TML

---+++ ObjectMethod flush()

Writes =content= back to disk. Sets =exception= upon errors.

=cut

sub flush {
    my $this = shift;

    my ( $fh, $rc );

    try {
        open( $fh, $this->_openmode(">"), $this->path )
          or $this->throwFileOp( op => "open", );

        binmode($fh) if $this->binary;

        print $fh $this->content
          or $this->throwFileOp( op => "write", );

        $this->modified(0);
        $this->clear_stat;
    }
    catch {
        $this->exception( Foswiki::Exception::Fatal->transmute( $_, 0 ) );
    }
    finally {
        close $fh;
    };
}

=begin TML

---+++ ObjectMethod prepareContent()

Initializer of =content= attribute.

=cut

sub prepareContent {
    my $this = shift;

    $this->clear_stat;
    my $content = $this->slurp;
    $this->stat;
    $this->modified(0);

    return $content;
}

=begin TML

---+++ ObjectMethod prepareStat()

Initialier of =stat= attribute.

=cut

sub prepareStat {
    my $this = shift;

    my $path = $this->path;

    if ( ( -e $path || !$this->autoCreate ) && !-r $path ) {
        $this->exception(
            $this->_createException(
                exception => 'Foswiki::Exception::FileOp',
                text      => "don't have read access to " . $path,
                op        => "stat",
            )
        );
        return undef;
    }

    return stat($path);
}

=begin TML

---+++ ObjectMethod prepareRaiseError()

Initialier of =raiseError= attribute.

=cut

sub prepareRaiseError {
    return 1;
}

=begin TML

---+++ ObjectMethod prepareUnicode()

Initialier of =unicode= attribute.

=cut

sub prepareUnicode {
    return 1;
}

=begin TML

---+++ ObjectMethod prepareBinary()

Initialier of =binary= attribute.

=cut

sub prepareBinary {
    return 0;
}

=begin TML

---+++ ObjectMethod prepareAutoWrite()

Initialier of =autoWrite= attribute.

=cut

sub prepareAutoWrite {
    return 1;
}

=begin TML

---+++ ObjectMethod prepareAutoCreate()

Initialier of =autoCreate= attribute.

=cut

sub prepareAutoCreate {
    return 0;
}

=begin TML

---+++ ObjectMethod prepareModified()

Initialier of =modified= attribute.

=cut

sub prepareModified {
    return 0;
}

sub _trigger_exception {
    my $this = shift;
    my ($excpt) = @_;

    $excpt->throw if ( $this->raiseError );
}

sub _trigger_content {
    my $this = shift;
    $this->modified(1);
    $this->flush if $this->autoWrite;
}

sub _createException {
    my $this    = shift;
    my %profile = @_;

    my $exception = $profile{exception} // 'Foswiki::Exception::FileOp';
    delete $profile{exception};
    $profile{file}   //= $this->path;
    $profile{object} //= $this;

    return $this->create( $exception, %profile );
}

sub _openmode {
    my $this = shift;
    my ($mode) = @_;
    return $mode
      . ( !$this->binary && $this->unicode ? ":encoding(utf-8)" : "" );
}

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
