# See bottom of file for license and copyright information

package Foswiki::Extension::Sample::TiedConfig {
    use Assert;

    sub TIEHASH {
        my $class     = shift;
        my $cfgObject = shift;

        my $thisHash = { cfg => $cfgObject, _trace => 0, @_ };

        return bless $thisHash, $class;
    }

    sub FETCH {
        my ( $this, $key ) = @_;
        ASSERT( defined $this->{cfg} ) if DEBUG;
        if ( $key eq '.version' ) {
            return $Foswiki::Extension::Sample::Config::VERSION;
        }
        $this->trace("FETCH{$key}");
        return $this->{cfg}->data->{$key};
    }

    sub STORE {
        my ( $this, $key, $value ) = @_;
        ASSERT( defined $this->{cfg} ) if DEBUG;
        $this->trace("STORE{$key}");
        $this->{cfg}->data->{$key} = $value;
    }

    sub DELETE {
        my ( $this, $key ) = @_;
        ASSERT( defined $this->{cfg} ) if DEBUG;
        $this->trace("DELETE{$key}");
        delete $this->{cfg}->data->{$key};
    }

    sub CLEAR {
        my ($this) = @_;
        ASSERT( defined $this->{cfg} ) if DEBUG;
        $this->{cfg}->clear_data;
    }

    sub EXISTS {
        my ( $this, $key ) = @_;
        ASSERT( defined $this->{cfg} ) if DEBUG;
        return exists $this->{cfg}->data->{$key};
    }

    sub FIRSTKEY {
        my ($this) = @_;
        ASSERT( defined $this->{cfg} ) if DEBUG;
        my $_ignore = keys %{ $this->{cfg}->data };
        return each %{ $this->{cfg}->data };
    }

    sub NEXTKEY {
        my ($this) = @_;
        ASSERT( defined $this->{cfg} ) if DEBUG;
        return each %{ $this->{cfg}->data };
    }

    sub SCALAR {
        my ($this) = @_;
        ASSERT( defined $this->{cfg} ) if DEBUG;
        return scalar %{ $this->{cfg}->data };
    }

    sub UNTIE {
        my ($this) = @_;

        undef $this->{cfg};
    }

    sub setTrace {
        my $this = shift;
        $this->{_trace} = shift;
        say STDERR "Setting _trace to ", $this->{_trace};
    }

    sub trace {
        my $this = shift;
        if ( $this->{_trace} ) {
            say STDERR @_;
        }
    }
}

package Foswiki::Extension::Sample::Config;

use Carp;
use Moo::Role;

use version; our $VERSION = version->declare("v0.0.1");

around assignGLOB => sub {
    my $orig = shift;
    my $this = shift;

    my $class = 'Foswiki::Extension::Sample::TiedConfig';
    my $tieObj = tie %Foswiki::cfg, $class, $this;

    Foswiki::Exception::Fatal->throw(
        text => 'Failed to tie \%Foswiki::cfg to ' . $class, )
      unless $tieObj;
};

around unAssignGLOB => sub {
    my $orig = shift;
    my $this = shift;

    my $tied = tied(%Foswiki::cfg);

    if ( $tied && $tied == $this ) {
        untie %Foswiki::cfg;
    }
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
