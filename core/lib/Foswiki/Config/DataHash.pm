# See bottom of file for license and copyright information

package Foswiki::Config::DataHash;

=begin TML

---+!! Class Foswiki::Config::DataHash

Container class for config specs. The =Foswiki::Config= attribute =data= hash is
tied to this class when config is in specs mode.

---++ DESCRIPTION

This is only a container class. Actual specs are stored in a node data defined
by =Foswiki::Config::Node= class. Node data are kept in =nodes= hash. For
example:

<verbatim>
$app->cfg->data->{Email}{MailMethod} = 'Net::SMTP';
</verbatim>

is actually represented by four objects: 

   * =$app->cfg->data= is the root hashref tied to =Foswiki::Config::DataHash=.
      * Key _Email_ of the hash in =nodes= attribute contains
      a =Foswiki::Config::Node= object.
         * The node object's =value= attribute contains a reference to hash tied
         to =Foswiki::Config::DataHash=; its =name= attribute contains
         _'Email'_. 
            * Its =nodes= attribute hash has a key _MailMethod_. The key is in
            turn a =Foswiki::Config::Node= object.
               * The node object's =value= is the string _'Net::SMTP'_.

Though this structure may seem a bit complicated but it serves two purposes:

   1 Use of tied hashes keeps the structure transparent for code using config
   data. The code would deal with config data hash as usual and doesn't care
   whether it's a plain data hash or specs loaded in memory.
   1 Separates actual container (a =Foswiki::Config::DataHash= object) from
   specs data. 

=cut

use Assert;
use Foswiki::Exception;
use Foswiki ();

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);
with qw(Foswiki::Config::CfgObject);

use constant NODE_CLASS => 'Foswiki::Config::Node';

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute nodes -> \%nodes

Hash nodes. Each key in the hash either doesn't exists or is
a =Foswiki::Config::Node= object. No other values like a scalar value or
a object of any other but =Foswiki::Config::Node= class are allowed.

=cut

has nodes => (
    is      => 'rw',
    builder => 'prepareNodes',
    lazy    => 1,
    clearer => 1,
);

=begin TML

---+++ ObjectAttribute parent

Parent container object.

=cut

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

=begin TML

---+++ ObjectAttribute name

This container name – same as the key name on the parent's =nodes= hash.
Undefined for the root node.

=cut

has name => (
    is        => 'rw',
    predicate => 1,
);

=begin TML

---+++ ObjectAttribute level

Depth level of this hash, 0 for the root.

=cut

has level => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareLevel',
);

=begin TML

---+++ ObjectAttribute fullPath -> \@cfgPath

List of keys on the path from the root to this node. I.e. for a key in
normalized form _JQueryPlugin.Plugins.BlockUI.Enabled_ the path would consist of
all elements from _JQueryPlugin_ to _Enabled_. 

=cut

has fullPath => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareFullPath',
);

=begin TML

---+++ ObjectAttribute fullName

Normalized full name of this node – see example in =fullPath= above.

=cut

has fullName => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareFullName',
);

=begin TML

---+++ ObjectAttribute _trace -> bool

Turns on debug tracing of all hash operations.

=cut

has _trace => (
    is      => 'rw',
    lazy    => 1,
    builder => '_prepareTrace',
);

=begin TML

---++ METHODS

=cut

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;

    my @profile;

    # Simplify object creation by using app's cfg for required attribute cfg
    # from Foswiki::Config::CfgObject. Won't work during app's construction
    # stage.
    if ( !$params{cfg} && $params{app} && $params{app}->has_cfg ) {
        push @profile, cfg => $params{app}->cfg;
    }

    return $orig->( $class, @profile, @_ );
};

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

    Foswiki::load_class(NODE_CLASS);

    return $this;
}

sub FETCH {
    my ( $this, $key ) = @_;

    $this->trace("FETCH($key)");

    return exists $this->nodes->{$key} ? $this->nodes->{$key}->getValue : undef;
}

sub STORE {
    my ( $this, $key, $value ) = @_;

    $this->trace("STORE($key)");

    my $nodes = $this->nodes;

    my $node = $this->makeNode( key => $key, );

    # Check if node is a leaf. If it is then the hash being assigned isn't a LSC
    # subhash but actual key value. Though not really affecting $app->cfg
    # functionality but is much cleaner and sometimes may even speed up
    # operations too.
    if ( !$node->isLeaf && ref($value) eq 'HASH' && !tied(%$value) ) {

        # Check if the node value is a tied hash already.
        my $nVal = $node->value;
        unless ( defined($nVal) && ref($nVal) eq 'HASH' && tied(%$nVal) ) {
            $this->tieNode($key);
        }

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

        # Mark node as leaf if
        $node->setLeafState(&Foswiki::Config::Node::LEAF) if $node->isVague;
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

=begin TML

---+++ ObjectMethod trace(\@msg)

Prints a debug message formatted to take intou account current key nested level
as defined in =level= attribute.

=cut

sub trace {
    my $this = shift;

    if ( $this->_trace ) {
        my $prefix = "  " x $this->_level;
        my @msg = map { $prefix . $_ . "\n" } split /\n/, join( '', @_ );

        # SMELL Replace with $app logging facilities.
        print STDERR @msg;
    }
}

=begin TML

---+++ ObjectMethod getKeyObject(@keyPath) -> $keyObject

Returns the object tied to a subhash. Note that if key path refers to a leaf
node then no object could be returned. For the example from =fullPath= attribute
this method would return a =Foswiki::Config::DataHash= object for
_JQueryPlugin.Plugins.BlockUI_ but will return undefined value for
_JQueryPlugin.Plugins.BlockUI.Enabled_ because _Enabled_ is a leaf and it's
=value= attribute is a boolean, not a tied hash ref.

If say key _JQueryPlugin_ already exists while _Plugins_ doesn't then the latter
and _BlockUI_ will be auto-vivified and their type will be set to branch. This
is because this method is expected to do it's best to return a container object.
This behaivor may has a side-effect in case the full path including _Enabled_ is
requested. In this case _Enabled_ will be auto-vivified as a branch node and
this might have unpredictable side effects.

=@keyPath= must be an array of simple scalars. If there is a non-scalar object
in the array it'll be stringified.

This is a low-level API method. See =Foswiki::Config= for the high-level analog.

=cut

sub getKeyObject {
    my $this = shift;

    my $keyObj = $this;

    while (@_) {
        my $key = shift;

        my $node = $keyObj->nodes->{$key};

        unless ($node) {

            # Auto-vivify key if doesn't exists. We always create a non-leaf
            # here because this is what this method is supposed to do.
            $node = $keyObj->makeNode(
                key         => $key,
                nodeProfile => { leafState => 0, },
            );

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
            $keyObj->tieNode($key);
        }

        $keyObj = tied( %{ $node->value } );
    }
    return $keyObj;
}

=begin TML

---+++ ObjectMehtod makeNode( %params ) -> $node

This method initializes and returns a node in =nodes= attribute hash. The following keys are
expected in =%params= hash:

| *Key* | *Description* |
| =key= | Node key name. |
| =nodeType= | Type of the new node. The types are defined in =Foswiki::Config::Node=. If key is ommited or undefined then =Foswiki::Config::Node= it used as node class. |
| =nodeProfile= | Defined a profile for the new node constructor method. |

If the node already exists then =nodeProfile= is treated as an attribute/value
pair list and for each attribute from the list it is set to the value.

*NOTE* In some cases a node object might behave differently for situations when
attributes are initialized by node's constructur or re-initialized through their
respective accessors. The nuances could be caused by the ways Moo works with
attributes.

=cut

sub makeNode {
    my $this   = shift;
    my %params = @_;

    my ( $key, $type, $profile ) = @params{qw(key nodeType nodeProfile)};

    $profile = [%$profile] if ref($profile) eq 'HASH';
    $profile //= [];

    #my %profile = @_;

    my $nodes = $this->nodes;
    my $node  = $nodes->{$key};
    my $section;

    if ($node) {
        my $i = 0;

        while ( $i < @$profile ) {
            my ( $key, $val ) = ( $profile->[ $i++ ], $profile->[ $i++ ] );
            $node->$key($val);
        }
    }
    else {
        $nodes->{$key} = $node =
          $this->createNode( $type, @$profile, name => $key, );
        $this->tieNode($key) if $node->isBranch;
    }

    return $node;
}

=begin TML

---+++ ObjectMethod tieNode($node) => $nodeObj

Node could be either a node object or key name on =nodes= attribute hash.

Sets node type to branch by assigning it's =value= to a hash tied to
=Foswiki::Config::DataHash= and setting node's =isLeaf= attribute to =FALSE=.

This method is considered an assign operation and therefore if the node
was a leaf and had a value then the value is lost.

=cut

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
    my $tieObj = tie %newHash, $class,
      cfg    => $this->cfg,
      name   => $key,
      parent => $node->parent,
      @_;

    Foswiki::Exception::Fatal->throw(
        text => "Failed to create a tied " . $class . " hash", )
      unless $tieObj;

    # XXX This drops any old value previously stored in the key! But this is
    # intended behaviour. After all, it's an assignment operation.
    $node->value( \%newHash );

    # Tieing of a node makes it non-leaf implcitly.
    $node->leafState(0);

    return $node;
}

=begin TML

---+++ ObjectMethod createNode($type, @nodeProfile) -> $nodeObject

Creates a new =Foswiki::Config::Node= object of type =$type= using =@nodeProfile=.

=cut

sub createNode {
    my $this = shift;
    my $type = shift;

    my $nodeClass = NODE_CLASS;

    if ( defined $type ) {
        $nodeClass = $nodeClass->type2class($type);
        Foswiki::Exception::Fatal->throw(
            text => "Cannot get node class for type " . $type, )
          unless $nodeClass;
    }

    # Set this node type to branch because this is what it is.
    $this->parent->nodes->{ $this->name }
      ->setLeafState(&Foswiki::Config::Node::BRANCH)
      if $this->level > 0;

    return $this->create( $nodeClass, parent => $this, @_ );
}

=begin TML

---+++ ObjectMethod getLeftNodes => @nodes

Returns all leaf nodes stored in this hash and all subhashes.

=cut

sub getLeafNodes {
    my $this = shift;

    my @leafs;

    foreach my $node ( values %{ $this->nodes } ) {
        if ( $node->isLeaf ) {
            push @leafs, $node;
        }
        elsif ( $node->isBranch ) {
            push @leafs, tied( %{ $node->value } )->getLeafNodes;
        }
    }

    return @leafs;
}

=begin TML

---+++ ObjectMethod prepareNodes

Initializer of =nodes= attribute.

=cut

sub prepareNodes { {} }

=begin TML

---+++ ObjectMethod prepareLevel

Initializer of =level= attribute.

=cut

sub prepareLevel {
    my $this = shift;
    if ( $this->has_parent ) {
        return $this->parent->level + 1;
    }
    return 0;
}

=begin TML

---+++ ObjectMethod prepareFullPath

Initializer of =fullPath= attribute.

=cut

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

=begin TML

---+++ ObjectMethod prepareFullName

Initializer of =fullName= attribute.

=cut

sub prepareFullName {
    my $this = shift;

    return $this->cfg->normalizeKeyPath( $this->fullPath );
}

=begin TML

---+++ ObjectMethod _prepareTrace

Initializer of =_trace= attribute.

=cut

sub _prepareTrace {
    my $this = shift;
    return $this->has_parent ? $this->parent->_trace : 0;
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
