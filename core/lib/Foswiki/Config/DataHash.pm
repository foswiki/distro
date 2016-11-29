# See bottom of file for license and copyright information

package Foswiki::Config::DataHash;
use v5.14;

use Assert;
use Foswiki::Exception;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

# Hash nodes. Each key in the hash either doesn't exists or is a
# Foswiki::Config::Node object.
has nodes => (
    is      => 'rw',
    default => sub { {} },
    lazy    => 1,
    clearer => 1,
);

has _trace => (
    is      => 'rw',
    default => 0,
);
has _level => (
    is      => 'rw',
    default => 0,
);

sub TIEHASH {
    my $class = shift;

    $class = ref($class) || $class;

    my $this = $class->new(@_);

    return $this;
}

sub FETCH {
    my ( $this, $key ) = @_;

    $this->trace("FETCH($key)");

    return exists $this->nodes->{$key} ? $this->nodes->{$key}->value : undef;
}

sub STORE {
    my ( $this, $key, $value ) = @_;

    $this->trace("STORE($key)");

    my $nodes = $this->nodes;

    if ( ref($value) eq 'HASH' ) {
        my %newHash;
        my $class = ref($this);
        my $tieObj = tie %newHash, $class,
          app    => $this->app,
          _trace => $this->_trace,
          _level => $this->_level + 1,
          ;

        Foswiki::Exception::Fatal->throw(
            text => "Failed to create a tied " . $class . " hash", )
          unless $tieObj;

        # Copying one by one is not the fastest way but is the most pure one to
        # get all subhashes stores in $value to be tied too.
        foreach my $valueKey ( keys %$value ) {
            $this->trace( "COPY($valueKey => ",
                ( $value->{$valueKey} // '*undef*' ), ")" );
            $newHash{$valueKey} = $value->{$valueKey};
        }

        $value = \%newHash;
    }

    unless ( defined $nodes->{$key} ) {
        $nodes->{$key} = $this->create('Foswiki::Config::Node');
    }

    $nodes->{$key}->value($value);
}

sub DELETE {
    my ( $this, $key ) = @_;

    delete $this->nodes->{$key};
}

sub CLEAR {
    my ($this) = @_;

    $this->clear_nodes;
}

sub EXISTS {
    my ( $this, $key ) = @_;

    # Be strict. We don't allow undefined keys. If there is one then this is a
    # bug.
    return defined $this->nodes->{$key};
}

sub FIRSTKEY {
    my ($this) = @_;

    my $nodes = $this->nodes;

    # If there was previous each operation performed then reset it.
    my $_ignore = keys %{$nodes};

    return each %{$nodes};
}

sub NEXTKEY {
    my ($this) = @_;

    return each %{ $this->nodes };
}

sub SCALAR {
    my ($this) = @_;

    return scalar %{ $this->nodes };
}

sub UNTIE {
    my ($this) = @_;
}

sub trace {
    my $this = shift;

    if ( $this->_trace ) {
        my $prefix = "  " x $this->_level;
        my @msg = map { $prefix . $_ . "\n" } split /\n/, join( '', @_ );
        print STDERR @msg;
    }
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
