# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Cache::MemoryLRU

Implementation of a Foswiki::Cache using an in-memory perl hash.
See Foswiki::Cache for details of the methods implemented by this class.

=cut

package Foswiki::Cache::MemoryLRU;

use strict;
use warnings;
use Foswiki::Cache;

@Foswiki::Cache::MemoryLRU::ISA = ('Foswiki::Cache');

our $sharedCache;

sub new {
    my ( $class, $session ) = @_;

    my $this;
    if ($sharedCache) {
        $this = $sharedCache;
    }
    else {
        $this = bless( $class->SUPER::new($session), $class );
        $sharedCache = $this;
        $this->{maxSize}  = $Foswiki::cfg{Cache}{MaxSize} || 1000;
        $this->{head}     = 0;
        $this->{tail}     = 0;
        $this->{nodes}    = ();
        $this->{hits}     = 0;
        $this->{requests} = 0;
    }

    $this->init($session);
    $this->{finished} = 0;

    return $this;
}

sub set {
    my ( $this, $key, $obj ) = @_;

    $key = $this->genKey($key);
    my $node = $this->_remove($key);

    if ($node) {
        $node->{obj} = $obj;
    }
    else {
        $node = {
            key  => $key,
            obj  => $obj,
            prev => 0,
            next => 0,
        };
    }

    $this->_append($node);

    #print STDERR "set:\n";
    #$this->_print();

    return $obj;
}

# appends a node to the internal structure
sub _append {
    my ( $this, $node ) = @_;

    #print STDERR "_append node: $node->{key}\n";
    $this->{nodes}{ $node->{key} } = $node;

    if ( $this->{tail} ) {
        $this->{tail}{next} = $node;
    }
    else {
        $this->{head} = $node;
    }

    $node->{prev} = $this->{tail};
    $this->{tail} = $node;
}

# remove a node from the internal structure
sub _remove {
    my ( $this, $key ) = @_;

    my $node = $this->{nodes}{$key};
    return unless $node;

    $this->{tail} = $node->{prev} if $node eq $this->{tail};
    $this->{head} = $node->{next} if $node eq $this->{head};
    $node->{next}{prev} = $node->{prev} if $node->{next};
    $node->{prev}{next} = $node->{next} if $node->{prev};
    $node->{next}       = 0;
    $node->{prev}       = 0;

    delete $this->{nodes}{$key};

    return $node;
}

#sub _print {
#    my $this = shift;
#
#    my $index = 1;
#    my %seen;
#    for ( my $node = $this->{head} ; $node ; $node = $node->{next} ) {
#        die "loop detected" if $seen{$node};
#        $seen{$node} = 1;
#        print STDERR "$index: $node->{key}\n";
#        $index++;
#    }
#}

sub get {
    my ( $this, $key ) = @_;

    $this->{requests}++;

    my $node = $this->_remove( $this->genKey($key) );
    return unless $node;

    $this->_append($node);
    $this->{hits}++;

    return $node->{obj};
}

sub delete {
    my ( $this, $key ) = @_;

    $this->_remove( $this->genKey($key) );
    return 1;
}

sub clear {
    my $this = shift;

    $this->{nodes} = ();
    $this->{head}  = 0;
    $this->{tail}  = 0;
}

sub finish {
    my $this = shift;

    return if $this->{finished};
    $this->{finished} = 1;
    my $size = keys %{ $this->{nodes} };

#my $percnt = 0;
#$percnt = int(100 * $this->{hits}/$this->{requests}) if $this->{requests};
#print STDERR "size=$size, hits=$this->{hits}, requests=$this->{requests} ($percnt%)\n";
#print STDERR "before:\n";
#$this->_print();

    for ( my $i = $this->{maxSize} ; $i < $size ; $i++ ) {
        $this->_remove( $this->{head}{key} );
    }

    #print STDERR "after:\n";
    #$this->_print();
    undef $this->{session};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2008 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
