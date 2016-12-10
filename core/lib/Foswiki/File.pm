# See bottom of file for license and copyright information

package Foswiki::File;

use Try::Tiny;
use File::stat;
use Foswiki::Exception ();

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

has path => (
    is       => 'ro',
    required => 1,
);

has unicode => (
    is      => 'rw',
    builder => 'prepareUnicode',
);

has content => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    builder   => 'prepareContent',
    trigger   => 1,
);

has stat => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareStat',
);

has raiseError => (
    is      => 'rw',
    builder => 'prepareRaiseError',
);

# Write automatically upon content change.
has autoWrite => (
    is      => 'rw',
    builder => 'prepareAutoWrite',
);

has exception => (
    is      => 'rw',
    clearer => 1,
    builder => 'prepareException',
    trigger => 1,
);

stubMethods qw(prepareException);

sub _createException {
    my $this    = shift;
    my %profile = @_;

    my $exception = $profile{exception} // 'Foswiki::Exception::FileOp';
    delete $profile{exception};
    $profile{file} //= $this->path;

    return $this->create( $exception, %profile );
}

sub throwFileOp {
    my $this = shift;
    $this->_createException(@_)->throw;
}

sub prepareContent {
    my $this = shift;

    return $this->slurp;
}

sub prepareStat {
    my $this = shift;

    my $path = $this->path;

    unless ( -r $path ) {
        $this->exception(
            $this->_createException(
                'Foswiki::Exception::FileOp',
                text => "Don't have read access to " . $path . ", cannot stat",
                op   => "stat",
            )
        );
        return undef;
    }

    return stat($path);
}

sub prepareRaiseError {
    return 1;
}

sub prepareUnicode {
    return 1;
}

sub prepareAutoWrite {
    return 1;
}

sub _trigger_exception {
    my $this = shift;
    my ($excpt) = @_;

    $excpt->throw if ( $this->raiseError );
}

sub _trigger_content {
    my $this = shift;
    $this->flush if $this->autoWrite;
}

sub _openmode {
    my $this = shift;
    my ($mode) = @_;
    return $mode . ( $this->unicode ? ":encoding(utf-8)" : "" );
}

sub slurp {
    my $this = shift;

    my ( $fh, $content );

    try {
        open( $fh, $this->_openmode("<"), $this->path )
          or $this->throwFileOp( op => "open", );

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

sub flush {
    my $this = shift;

    my ( $fh, $rc );

    try {
        open( $fh, $this->_openmode(">"), $this->path )
          or $this->throwFileOp( op => "open", );

        print $fh $this->content
          or $this->throwFileOp( op => "write", );
    }
    catch {
        $this->exception( Foswiki::Exception::Fatal->transmute( $_, 0 ) );
    }
    finally {
        close $fh;
    };
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
