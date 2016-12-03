# See bottom of file for license and copyright information

package Foswiki::Config::DataHash;

use Assert;
use Foswiki::Exception;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

use constant NODE_CLASS => 'Foswiki::Config::Node';

# Hash nodes. Each key in the hash either doesn't exists or is a
# Foswiki::Config::Node object.
has nodes => (
    is      => 'rw',
    builder => 'prepareNodes',
    lazy    => 1,
    clearer => 1,
);

# Parent DataHash object.
has parent => (
    is        => 'rw',
    predicate => 1,
    weak_ref  => 1,
    (
        DEBUG
        ? ( isa => Foswiki::Object::isaCLASS( 'parent', __PACKAGE__ ) )
        : ()
    ),
);

# Key name in parent's hash. Non-existant for the root object.
has name => (
    is        => 'rw',
    predicate => 1,
);

# Depth level of this has, 0 for the root.
has level => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareLevel',
);

has fullPath => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareFullPath',
);

has fullName => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareFullName',
);

has _trace => (
    is      => 'rw',
    lazy    => 1,
    builder => '_prepareTrace',
);

sub TIEHASH {
    my $class  = shift;
    my %params = @_;

    $class = ref($class) || $class;

    my @profile;

    if (  !$params{app}
        && $params{parent}
        && UNIVERSAL::isa( $params{parent}, __PACKAGE__ ) )
    {
        push @profile, app => $params{parent}->app;
    }

    my $this = $class->new( @profile, @_ );

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

    my $node = $this->makeNode($key);

   # Check if node is a leaf. If it is then the hash being assigned
   # isn't a LSC subhash but actual key value. Though not really affecting
   # $app->cfg functionality but is much cleaner and sometimes may even speed up
   # operations too.
    if ( !$node->isLeaf && ref($value) eq 'HASH' && !tied(%$value) ) {

        $this->tieNode($key);

        my $newHash = $node->value;

        # Copying one by one is not the fastest way but is the most pure one to
        # get all subhashes stores in $value to be tied too.
        foreach my $valueKey ( keys %$value ) {
            $this->trace( "COPY($valueKey => ",
                ( $value->{$valueKey} // '*undef*' ), ")" );
            $newHash->{$valueKey} = $value->{$valueKey};
        }
    }
    else {
        $node->value($value);
    }
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

# getKeyObject(@keyPath)
# Returns the object tied to a subhash. Note that if key path refers to a leaf
# node – i.e. to a leaf – no object could be returned.
# @keyPath must be an array of simple scalars.
sub getKeyObject {
    my $this = shift;

    my $keyObj = $this;

    while (@_) {
        my $key = shift;

        my $node = $keyObj->nodes->{$key};

        unless ($node) {

            # Auto-vivify key if doesn't exists. We always create a non-leaf
            # here because this is what this method is supposed to do.
            $node = $this->makeNode( $key, isLeaf => 0, );

            Foswiki::Exception::Fatal->throw(
                text => "Failed to auto-vivify key '$key' on "
                  . $keyObj->fullName )
              unless defined $node;
        }

        # A leaf node doesn't have an object tied to it.
        return undef if $node->isLeaf;

        unless ( $node->has_value ) {

            # If node doesn't have a value assigned or is not explicitly defined
            # as a leaf then make it a non-leaf and assign subhash.
            $this->tieNode($key);
        }

        $keyObj = tied( %{ $node->value } );
    }
    return $keyObj;
}

sub makeNode {
    my $this = shift;
    my $key  = shift;

    my $nodes = $this->nodes;
    my $node;

    if ( defined $nodes->{$key} ) {
        my %profile = @_;

        $node = $nodes->{$key};

        while ( my ( $key, $val ) = each %profile ) {
            $node->$key($val);
        }
    }
    else {
        $nodes->{$key} = $node = $this->create( NODE_CLASS, @_ );
        $this->tieNode($key) if $node->isBranch;
    }

    return $node;
}

# The first param could either be an existing node object or key name.
sub tieNode {
    my $this = shift;
    my $key  = shift;

    my $node = $this->nodes->{$key};

    Foswiki::Exception::Fatal->throw(
            text => "Cannot tie non-existent key '$key' on '"
          . $this->fullName
          . "'" )
      unless defined $node;

    my %newHash;
    my $class = ref($this);
    my $tieObj = tie %newHash, $class, name => $key, parent => $this, @_;

    Foswiki::Exception::Fatal->throw(
        text => "Failed to create a tied " . $class . " hash", )
      unless $tieObj;

    # XXX This drops any old value previously stored in the key! But this is
    # intended behaviour. After all, it's an assignment operation.
    $node->value( \%newHash );

    # Tieing of a node makes it non-leaf implcitly.
    $node->isLeaf(0);

    return $node;
}

sub prepareNodes { {} }

sub prepareLevel {
    my $this = shift;
    if ( $this->has_parent ) {
        return $this->parent->level + 1;
    }
    return 0;
}

sub prepareFullPath {
    my $this = shift;

    my @keys;
    push @keys, $this->name if $this->has_name;

    my $ancestor = $this->parent;

    while ($ancestor) {
        push @keys, $ancestor->name;
        $ancestor = $ancestor->parent;
    }

    return [ reverse @keys ];
}

sub prepareFullName {
    my $this = shift;

    return $this->app->cfg->normalizeKeyPath( $this->fullPath );
}

sub _prepareTrace {
    my $this = shift;
    return $this->has_parent ? $this->parent->_trace : 0;
}

# Submit parent parameter by default.
around create => sub {
    my $orig  = shift;
    my $this  = shift;
    my $class = shift;

    return $orig->( $this, $class, parent => $this, @_ );
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
