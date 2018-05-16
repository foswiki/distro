# See bottom of file for license and copyright information

package Foswiki::Config::ItemRole;

=begin TML

---+!! Role Foswiki::Config::ItemRole

Base role for specs item classes. Defines basic functionality of a specs item
object.

=cut

require Foswiki::Object;

use Foswiki::Exception::Config;

use Foswiki::Role;

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute name

Key name of this node in parent's nodes hash.

=cut

has name => (
    is       => 'ro',
    required => 1,
);

=begin TML

---+++ ObjectAttribute source -> \@list

List of sources where definitions of this node exists. Each source defined by a
hash ref of two keys: =file= and =line=. =file= could be either a string or a
=Foswiki::File= object. =line= could be missing when not known.

=cut

has sources => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareSources',
    isa     => Foswiki::Object::isaARRAY('sources'),
);

=begin TML

---+++ ObjectAttribute parent

Parent container object of class =Foswiki::Config::DataHash=. 

=cut

# TODO There must be Parent/Child roles.
has parent => (
    is        => 'rw',
    weak_ref  => 1,
    predicate => 1,
    lazy      => 1,
    builer    => 'prepareParent',
);

=begin TML

---+++ ObjectAttribute options

Hash of =option => value= pairs. See more on options in specs documentation.

=cut

# Hash of option => value pairs
has options => (
    is      => 'rw',
    builder => 'prepareOptions',
    isa     => Foswiki::Object::isaHASH( 'options', noUndef => 1, ),
);

=begin TML

---+++ ObjectAttribute optDefs

This is option meta-data hash. For each option (hash key) accepted by the class
a subhash of its attributes is stored. See more in
%PERLDOC{method="optionDefinitions"}% documentation.

=cut

# Hash of option => definitionHash pairs defining options accepted by this
# object. Hash is a ref to a subhash in %classOptDefinitions unless
# _prepareOptDefs is overriden and returns something different.
has optDefs => (
    is      => 'rwp',
    builder => '_prepareOptDefs',
    isa     => Foswiki::Object::isaHASH( 'optDefs', noUndef => 1, ),
);

# Hash of class => optionsMap where optionsMap is a hash of option => 1 values.
my %classOptDefinitions;

=begin TML

---++ METHODS

Required method:
   
   $ =prepareParent= : Initializer for the =parent= attribute.

=cut

requires qw(prepareParent);

=begin TML

---+++ ObjectMethod allowedOpt($opt) -> bool

Checks if option =$opt= is valid for this object.

=cut

sub allowedOpt {
    my $this = shift;
    my ($opt) = @_;

    return defined( $this->optDefs->{$opt} ) || 0;
}

=begin TML

---+++ ObjectMethod optArities() -> @arities

Returns a list of =option => arity= values.

=cut

sub optArities {
    my $class = shift;

    $class = ref($class) || $class;

    $class->_setClassOptDefs;

    return map { $_ => $classOptDefinitions{$class}{$_}{arity} }
      keys %{ $classOptDefinitions{$class} };
}

=begin TML

---+++ ObjectMethod setOpt( $opt1 => $value1 [, $opt2 => $value2 [, ... ] ] )

Sets options to specified values.

If for a option =someOption= class defines method =setOpt_someOption= then value
is sent to this method and not handled by =setOpt()=.

Throws =Foswiki::Exception::Config::BadSpecData= exception if encounters an
invalid option. 

=cut

sub setOpt {
    my $this = shift;

    Foswiki::Exception::Fatal->throw(
        text => "Odd number of elemnts in option/value list", )
      unless @_ % 2 == 0;

    foreach my $seq ( 0 .. ( @_ / 2 - 1 ) ) {
        my $idx = $seq * 2;

        my ( $opt, $val ) = @_[ $idx, $idx + 1 ];

        $this->validateOpt( $opt, $val );

        my $setMethod = "setOpt_$opt";

        my $doSet = 1;

        if ( my $sub = $this->can($setMethod) ) {
            $doSet = $sub->( $this, $opt, $val );
        }

        $this->options->{$opt} = $val if $doSet;
    }
}

=begin TML

---+++ ObjectMethod getOpt($opt) -> $value

Returns value of option =$opt=. Doesn't make difference between option being set
to _undef_ and a missing option.

If for a option =someOption= class defines method =getOpt_someOption= then value
would be what this methods returns.

Throws =Foswiki::Exception::Config::BadSpecData= exception if option is invalid.

=cut

sub getOpt {
    my $this = shift;
    my $opt  = shift;

    $this->validateOpt($opt);

    my $getMethod = "getOpt_$opt";

    if ( my $sub = $this->can($getMethod) ) {
        return $sub->( $this, $opt );
    }

    my $opts = $this->options;

    unless ( exists $opts->{$opt} ) {
        my $defMethod = "defaultOpt_$opt";
        if ( my $def = $this->can($defMethod) ) {
            return $def->( $this, $opt );
        }
    }

    return $opts->{$opt};
}

=begin TML

---+++ ObjectMethod addText(@paragraphs)

Adds =@paragraphs= to =text= option. Paragraphs are joined with "\n\n"
separator.

=cut

sub addText {
    my $this = shift;

    $this->setOpt( 'text',
        join( "\n\n", $this->getOpt('text') // '', map { $_ // '' } @_ ) );
}

=begin TML

---+++ ObjectMethod addSource()

Adds a new entry to the attribute =sources= list. Parameters could be in one
of the following form:

   * A string with file name of a =Foswiki::File= object.
   * The above case plus line number as a second parameter.
   * A hash ref with =file= and possibly =line= keys.

=cut

sub addSource {
    my $this = shift;

    my $source;

    if ( @_ == 1 ) {
        if ( !ref( $_[0] ) || UNIVERSAL::isa( $_[0], 'Foswiki::File' ) ) {
            $source = { file => $_[0] };
        }
        elsif ( ref( $_[0] ) eq 'HASH' ) {
            $source = $_[0];
        }
    }
    elsif ( @_ == 2 ) {
        $source = { file => $_[0], line => $_[1] };
    }

    Foswiki::Exception::Config::BadSpecData->throw(
        text => "Bad source data format, see " . __PACKAGE__ . " documentation",
    ) unless defined $source;

    push @{ $this->sources }, $source;
}

=begin TML

---+++ ObjectMethod source()

A wrapper for the =addSource()= method, used to handle =-source= spec attribute.

=cut

sub source {
    my $this = shift;
    $this->addSource(@_);
}

sub setOpt_source {
    my $this = shift;
    my ( $opt, $value ) = @_;

    $this->addSource($value);

    return 0;
}

sub setOpt_sources {
    my $this = shift;
    my ( $opt, $value ) = @_;

    if ( ref($value) eq 'ARRAY' ) {
        $this->addSource(@_) foreach @{$value};
    }
    else {
        Foswiki::Exception::Config::BadSpecData->throw(
            text => "Option 'sources' must be an arrayref.", );
    }

    return 0;
}

=begin TML

---+++ ClassMethod optionDefinitions() -> @optionDefs

Returns a list of option definitions for a class. Note that a option definition
is a pair of =option => definition= where =option= is a option name; and
deinition is a hashref of option preferences.

A class with =Foswiki::Config::ItemRole= applied must override this method and
preferably combine what parent method returns with additional options the class
supports. For example, it might be done in the following way:

<verbatim>
package Foswiki::Config::Node::TYPE;

use Foswiki::Class;
extends qw(Foswiki::Config::Node);

my @optDefs = (
    newOption1 => { arity => 1, leaf => 1, },
    newOption2 => { arity => 0, dual => 1, },
);

around optionDefinitions => sub {
    my $orig = shift;
    
    return ( $orig->(@_), @optDefs );
};
</verbatim>

The following option preferences are supported:

| *Preference* | *Description* | *Mandatory* | *Note* |
| =arity= | Number of option parameters. Usually one but could be 0 for boolean\
  options (then the option could be prefixed with 'no') or 2+ for some specific\
  cases like section definition. | %Y% | |
| =leaf= | Options is valid in a leaf node only. | | =Foswiki::Config::Node=\
  only |
| =dual= | Option is valid for both leaf and branch node types. | | \
   =Foswiki::Config::Node= only |

*NOTE* Normally this method would be called once for each class. It's return
list would be cached by =Foswiki::Config::ItemRole=.

=cut

sub optionDefinitions {
    my $this = shift;

    return (
        text    => { arity => 1, dual => 1, },
        source  => { arity => 1, dual => 1, },
        sources => { arity => 1, dual => 1, },
    );
}

=begin TML

---+++ ObjectMethod validateOpt( $option [, $value ] )

Checks if =$option= is allowed for this item. If item's class implements
method with name _"validateOpt_" . $option_ then the method is called with
the same arguments, as =validateOpt()=.

In case of failure raises
=%PERLDOC{"Foswiki::Exception::Config::BadSpecData"}%=.

=cut

sub validateOpt {
    my $this = shift;
    my $opt  = shift;
    Foswiki::Exception::Config::BadSpecData->throw(
            text => "Unsupported option '"
          . $opt
          . "' by type "
          . $this->getOpt('type'), )
      unless $this->allowedOpt($opt);

    my $valMethod = "validateOpt_$opt";

    if ( my $sub = $this->can($valMethod) ) {
        $sub->( $this, $opt, @_ );
    }
}

=begin TML

---+++ ObjectMethod prepareSources

Initializer of =sources= attribute.

=cut

sub prepareSources {
    return [];
}

=begin TML

---+++ ObjectMethod prepareOptions

Initializer of =options= attribute.

=cut

sub prepareOptions {
    return {};
}

=begin TML

---+++ ObjectMethod _prepareValidOptions

Initializer of =optDefs= attribute.

=cut

sub _prepareOptDefs {
    my $this = shift;

    $this->_setClassOptDefs;

    return $classOptDefinitions{ ref($this) };
}

sub _setClassOptDefs {
    my $class = shift;

    $class = ref($class) || $class;

    return if $classOptDefinitions{$class};

    my %options = $class->optionDefinitions;

    $classOptDefinitions{$class} = \%options;
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
