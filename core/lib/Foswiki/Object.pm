# See bottom of file for license and copyright information

package Foswiki::Object;

=begin TML

---+ Class Foswiki::Object

*NOTE:* This document is in draft status and may change as a result of
a discussion, raised concerns or reasonable proposals.

This is the base object for all Foswiki classes. It defines the default
behaviour and general policies for all descendants.

---++ Behavior

=Foswiki::Object= is a subclass of Moo and as such inherits all it's
features.

=cut

require Carp;
require Foswiki::Exception;
use Try::Tiny;
use Scalar::Util qw(blessed refaddr weaken isweak);

use Foswiki::Class;

use Assert;

=begin TML

---++ ClassMethod BUILDARGS()

Converts positional constructor parameters to named ones. Tries to detect if constructor is already being called using named notation.

The =BUILDARGS()= uses array =@_newParameters= declared statically on a class to get information about the order of parameters.
For example, for a =Foswiki::SampleClass=:

<verbatim>
package Foswiki::SampleClass;
use Foswiki::Class;
extends qw(Foswiki::Obejct);

our @_newParameters = qw( param1 param2 );

has param1 => (is => 'rw');
has param2 => (is => 'ro');
has param3 => (is => 'rw');

1;
</verbatim>

the following notations are valid:

<verbatim>
my $object1 = Foswiki::SampleClass->new($param1, $param2);
my $object2 = Foswiki::SampleClass->new($param1);
my $object3 = Foswiki::SampleClass->new(param1 => 1, param2 => '2', param3 => 'additional');
my $object3 = Foswiki::SampleClass->new({param1 => 1, param2 => '2', param3 => 'additional'});
</verbatim>

Note that for =$object2= the =BUILD()= method will be called with no param2 key.

Key/value pairs as in =$object3= example are valid as soon as at least one key is mentioned in =@_newParameters=.
This limitation will remain actual until constructors are called with positional parameters no more.

=cut

has __orig_file  => ( is => 'rw', clearer => 1, );
has __orig_line  => ( is => 'rw', clearer => 1, );
has __orig_pkg   => ( is => 'rw', clearer => 1, );
has __orig_sub   => ( is => 'rw', clearer => 1, );
has __orig_stack => ( is => 'rw', clearer => 1, );

has __id => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    default => sub {
        my $this  = shift;
        my $strID = ref($this) . '_' . refaddr($this);
        $strID =~ s/:/_/g;
        return $strID;
    },
);

has __clone_heap =>
  ( is => 'rw', clearer => 1, lazy => 1, default => sub { {} }, );

around BUILDARGS => sub {
    my $orig = shift;
    my ( $class, @params ) = @_;

    # Skip processing if already have passed with a hash ref.
    return $params[0] if @params == 1 && ref( $params[0] ) eq 'HASH';

    # Take care of clone-like methods.
    if ( ref($class) ) {
        $class = ref($class);
    }

    my $paramHash;

    Carp::confess("Undefined \$class") unless defined $class;
    no strict 'refs';
    if ( defined *{ $class . '::_newParameters' }{ARRAY} ) {
        my @newParameters = @{ $class . '::_newParameters' };
        my $isHash        = 0;

        # If there are even number of parameters passed suspect key/value pairs.
        # Note: at least one key has to be in @_newParameters for this to work.
        if ( ( @params % 2 ) == 0 ) {
            my $prop_re = '^(' . join( '|', @newParameters ) . ')$';

      # Check for potential keys if any of them is mentioned in @_newParameters.
      # Not key/value form if any single suspected-to-be-key is undef.
            for ( my $i = 0 ; !$isHash && $i < @params ; $i += 2 ) {
                next unless defined $params[$i];
                $isHash = ( $params[$i] =~ $prop_re );
            }
        }
        unless ($isHash) {
            ASSERT(
                scalar(@params) <= scalar(@newParameters),
"object constructor for class $class has received more parameters than defined in \@_newParameters"
            ) if DEBUG;
            while (@params) {
                $paramHash->{ shift @newParameters } = shift @params;
            }
        }
    }

# If $paramHash is undef at this point then either @params is a key/value pairs array or no @_newParameters array defined.
# SMELL XXX Number of elements in @params has to be checked and an exception thrown if it's inappropriate.
    unless ( defined $paramHash ) {
        Foswiki::Exception::Fatal->throw(
            text => "Odd number of elements in $class parameters hash" )
          if ( @params % 2 ) == 1;
        $paramHash = {@params};
    }

    use strict 'refs';

    return $paramHash;
};

sub BUILD {
    my $this = shift;
    my ($args) = @_;

    if (DEBUG) {
        my ( $pkg, $file, $line );
        my $sFrame = 0;
        do {
            ( $pkg, $file, $line ) = caller( ++$sFrame );
          } while (
            $pkg =~ /^(Foswiki::Object|Moo::|Method::Generate::Constructor)/ );
        $this->__orig;
        $this->__orig_stack( Carp::longmess('') );

        # Copy non-attribute __orig_ keys from constructor's profile or they'd
        # be lost.
        $this->{$_} = $args->{$_} foreach grep { /^(?:__)+orig_/ } keys %$args;
    }
}

sub DEMOLISH {
    my $this = shift;

    #say STDERR "In ", __PACKAGE__, ": ", ref($this), "::DEMOLISH; ",
    #  defined($Foswiki::Plugins::SESSION) ? "SESSION" : "NO SESSION"
    #  if DEBUG;
    if ( $this->can('finish') ) {
        say STDERR Carp::shortmess(
            ref($this) . " supports finish() but it shouldn't." );

     # SMELL every Foswiki::Object ancestor has to use DEMOLISH as the standard.
     # XXX We have to generate a warning if this condition is met.
        $this->finish;
    }
    if (DEBUG) {
        foreach my $key ( keys %{$this} ) {
            unless ( $key =~ /^(?:__)+orig_/ || $this->can($key) ) {
                say STDERR "Key $key on ", ref($this),
                  " isn't a valid attribute.";
                if ( UNIVERSAL::isa( $this->{key}, 'Foswiki::Object' ) ) {
                    say STDERR "    $key is a Foswiki::Object created in ",
                      $this->{key}->__orig_file, ":", $this->{key}->__orig_line;
                }

            }
        }
    }
}

sub _cloneData {
    my $this = shift;
    my ( $val, $attr ) = @_;

    my $heap = $this->__clone_heap;

    my $cloned;
    if ( my $dataType = ref($val) ) {
        my $refAddr = refaddr($val);

        # Check if ref has been cloned before and avoid deep recursion.
        if ( defined $heap->{cloning_ref}{$refAddr} ) {
            Foswiki::Exception::Fatal->throw( text =>
"Circular dependecy detected on a object being cloned for attribute $attr"
            );
        }
        elsif ( defined $heap->{cloned_ref}{$refAddr} ) {

            # This reference was already cloned once, try to replicate the
            # original data structure by preserving references too.
            $cloned = $heap->{cloned_ref}{$refAddr};
        }
        else {
            # Record the reference being cloned.
            $heap->{cloning_ref}{$refAddr} = $attr;
            if ( my $class = blessed($val) ) {
                if ( $val->can('clone') ) {
                    $cloned = $val->clone;
                }
                elsif ( ref($val) eq 'Regexp' ) {
                    $cloned = $val;
                }
                else {
                    # Class without clone method. Try to copy it 'manually' by
                    # cloning as a hash and blessing the resulting hashref into
                    # $val's class.
                    # SMELL Pretty much unreliable for complex classes.
                    $cloned =
                      $this->_cloneData( {%$val}, "$attr.blessed($class)" );
                    bless $cloned, ref($val)
                      if $cloned != $val;
                }
            }
            else {
                if ( $dataType eq 'ARRAY' ) {
                    $cloned = [];
                    my $idx = 0;
                    foreach my $item (@$val) {
                        push @$cloned,
                          $this->_cloneData( $item, "${attr}.array[$idx]" );
                        $idx++;
                    }
                }
                elsif ( $dataType eq 'HASH' ) {
                    $cloned = {};
                    foreach my $key ( keys %$val ) {
                        $cloned->{$key} =
                          $this->_cloneData( $val->{$key},
                            "${attr}.hash{$key}" );
                    }
                }
                elsif ( $dataType eq 'SCALAR' ) {
                    $cloned = \$$val;
                }
                else {
                    # One-to-one copy for non-clonable refs.
                    $cloned = $val;
                }
            }

            # Record the cloned reference.
            $heap->{cloned_ref}{$refAddr} = $cloned;
            delete $heap->{cloning_ref}{$refAddr};
        }

        weaken($cloned) if isweak($val);
    }
    else {
        $cloned = $val;
    }

    return $cloned;
}

=begin TML

---++ ObjectMethod clone() -> $clonedObject

This method tries to do it's best to create an exact copy of existing object.
For that purpose this method considers a object as a data structure and
traverses it recursively creating a profile for new object's constructor. All
keys on object's hash are considered as attributes to be inserted into the
profile. In other words it means then if we have an object with keys =key1=, =key2=, and =key3=
then new object's constructor will get the following profile:

<verbatim>
my @profile = (
    key1 => $this->_cloneData( $this->{key1} ),  
    key2 => $this->_cloneData( $this->{key2} ),  
    key3 => $this->_cloneData( $this->{key3} ),  
);
my $newObj = ref($this)->new( @profile );
</verbatim>

Actually the process is a bit more complicated than this example. It is guided by the following rules:

   1. If a key name begins with =__[__[...]]orig_= prefix it is used for debugging needs and keeps object's creation history. To preserve the history such keys are prefixed with additional =__= prefix. So, a clone of clone would have three kopies of such keys prefixed with =__orig_=, =____orig_=, and =______orig_=.
   1. All other attributes with =__= prefixed names are ignored and not duplicated.
   1. If a class wants to take care of cloning of an attribute it can define a =_clone_<attribute_name>()= method (say, =_clone_key2()= for the above example; or =_clone__attr()= for private attribute =_attr=). In this case the attribute value won't be traversed and return from the =_clone_<attribute_name>()= method would be used.
   1. For blessed references discovered during traversal their =clone()= method is used to create a copy if their respective classes have this method defined.
   1. For objects without =clone()= method they're copied as a hash which is then blessed into the object's class. *NOTE* This won't work for non-hash blessed references. They're must be taken care by the class the attribute belongs to.
   1. Regexp's refs are just copied into destination.
   1. Attributes containing references of *ARRAY*, *HASH*, and *SCALAR* types are cloned; refs of other types are just copied into destination.
   1. If a reference is weakened it's clone is weakened too.
   1. If same reference found at two or more locations of cloned object's structure then destination object will have identical cloned references at same locations; i.e. if =$this->attr1 == $this->attr2->subattr->[3]= then =$cloned->attr1 == $cloned->attr2->subattr->[3]= too.
   1. Circular dependecies are raising =Foswiki::Exception::Fatal=.

=cut

# XXX Experimental.
# clone works on low-level bypassing Moo's accessor methods.
sub clone {
    my $this = shift;

    $this->_clear__clone_heap;
    my @profile;

    #my $skipRx = '^(' . join( '|', @skip_attrs ) . ')$';
    foreach my $attr ( keys %$this ) {

        #next if $attr =~ /$skipRx/;
        my $destAttr = $attr;
        if ( $destAttr =~ /^__/ ) {

            next unless $destAttr =~ /^(?:__)+orig_/;

            # Debug attributes would be preserved but those coming from the
            # source object would be kinda pushed on a stack by adding extra __
            # prefix. This way we could trace object's history.
            $destAttr = "__$destAttr";
        }
        my $clone_method = "_clone_" . $attr;
        my $attrVal;
        if ( my $method = $this->can($clone_method) ) {
            $attrVal = $method->($this);
        }
        else {
            $attrVal = $this->_cloneData( $this->{$attr}, $attr );
        }

        push @profile, $destAttr, $attrVal;
    }

# SMELL Should it be better to use same approach as in _cloneData - just bless a profile hash?
    my $newObj = ref($this)->new(@profile);

    $this->_clear__clone_heap;

    return $newObj;
}

# Fixes __orig_file and __orig_line to bypass ::create() and point directly to
# where it was called.
# $level parameter – how many stack frames to skip.
sub __orig {
    my $this = shift;
    my ($level) = @_;

    my @frame;
    if ( defined $level ) {

        # Skip our own frame.
        $level++;
    }
    else {
        @frame = caller(1);

        # If called from BUILD then skip additional frame.
        $level = $frame[3] =~ /::BUILD$/ ? 2 : 1;
    }

    my (@foundFrame);
    my $waitForNew = 1;
    while ( @frame = caller($level) ) {
        if ( $frame[3] =~ /::(?:create|new)$/ ) {
            $waitForNew = 0;
            @foundFrame = @frame;
        }
        else {
            last unless $waitForNew;
        }
        $level++;
    }

   # Support static method call. Don't try to set object attributes if called as
   # Foswiki::Object->__orig or Foswiki::Object::__orig.
    if ( @foundFrame && @_ && ref($this) ) {
        $this->__orig_pkg( $foundFrame[0] // '' );
        $this->__orig_file( $foundFrame[1] );
        $this->__orig_line( $foundFrame[2] );
        $this->__orig_sub( $foundFrame[3] // '' );
    }
    return @foundFrame;
}

sub _normalizeAttributeName {
    my ($attributeName) = @_;

    # If attribute defined by its name only try to guess it's classname by
    # checking the callstack.
    unless ( $attributeName =~ /::/ ) {
        my $package;
        my $level = 1;
        while ( !defined $package ) {
            my $pkg = ( caller( $level++ ) )[0];
            $package = $pkg unless $pkg =~ /^Foswiki::Object/;
        }
        $attributeName = "$package::$attributeName";
    }
    return $attributeName;
}

sub _validateIsaCode {
    my ( $attributeName, $code ) = @_;

    #say STDERR "Validator code for $attributeName: $code" if DEBUG;
    my $codeRef = eval $code;
    if ($@) {
        Carp::confess
"Compilation of attribute 'isa' validator for $attributeName failed: $@\nValidator code: $code";
    }
    return $codeRef;
}

=begin TML

---++ StaticMethod isaARRAY( $attributeName, \%opts )

isa validator generator checking for arrayrefs.

=%opts= hash keys:

   * =noUndef= – do not allow undef value
   * =noEmpty= - do not allow empty array

=cut

sub isaARRAY {
    my ( $attributeName, %opts ) = @_;

    $attributeName = _normalizeAttributeName($attributeName);

    return _validateIsaCode( $attributeName,
            'sub { Foswiki::Exception->throw( text => "'
          . $attributeName
          . ' attribute may only be '
          . ( $opts{noUndef} ? '' : 'undef or an ' )
          . 'arrayref." ) if '
          . ( $opts{noUndef} ? '!defined( $_[0] ) || ' : '' )
          . '( defined( $_[0] ) && ( ref( $_[0] ) ne "ARRAY"'
          . ( $opts{noEmpty} ? ' || scalar( @{ $_[0] } ) == 0' : '' )
          . ' ) ); }' );
}

=begin TML

---++ StaticMethod isaHASH( $attributeName, \%opts )

isa validator generator checking for arrayrefs.

=%opts= hash keys:

   * =noUndef= – do not allow undef value

=cut

sub isaHASH {
    my ( $attributeName, %opts ) = @_;

    $attributeName = _normalizeAttributeName($attributeName);

    return _validateIsaCode( $attributeName,
            'sub { Foswiki::Exception->throw( text => "'
          . $attributeName
          . ' attribute may only be '
          . ( $opts{noUndef} ? '' : 'undef or an ' )
          . 'hashref." ) if '
          . ( $opts{noUndef} ? '!defined( $_[0] ) || ' : '' )
          . '( defined( $_[0] ) && ( ref( $_[0] ) ne "HASH" ) );'
          . ' }' );
}

=begin TML

---++ StaticMethod isaCLASS( $attributeName, $className, \%opts )

isa validator generator checking if attribute is of =$className= class or it's
descendant.

=%opts= hash keys:

   * =noUndef= – do not allow undef value
   * =strictMatch= - allow only =$className=, no decsendants
   * =does= - defines a Role class must do.

=cut

sub isaCLASS {
    my ( $attributeName, $className, %opts ) = @_;

    $attributeName = _normalizeAttributeName($attributeName);

    return _validateIsaCode(
        $attributeName,
        'sub { Foswiki::Exception->throw( text => "'
          . $attributeName
          . ' attribute may only be '
          . ( $opts{noUndef} ? '' : 'undef or an ' )
          . $className
          . ' but not " . (defined $_[0] ? ref($_[0]) || $_[0] : "undef") . "." ) if '
          . ( $opts{noUndef} ? '!defined( $_[0] ) || ' : '' )
          . '( defined( $_[0] ) && ('
          . (
            $opts{strictMatch}
            ? 'ref( $_[0] ) ne "' . $className . '"'
            : '!$_[0]->isa("' . $className . '")'
          )
          . ( $opts{does} ? ' || !$_[0]->does("' . $opts{does} . '")' : '' )
          . ')' . '); }'
    );
}

sub _traceMsg {
    my $this = shift;

    if (DEBUG) {
        my ( $pkg, $file, $line ) = caller;

        say STDERR $pkg, "(line ", $line, ", obj ", $this, "): ", @_;
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
