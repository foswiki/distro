# See bottom of file for license and copyright information

package Foswiki::Object;

# TODO Implement methods Throw, Rethrow, Transmute as wrappers around respective Foswiki::Exception methods
# The purpose is to fill in object-related attributes of new exceptions.

=begin TML

---+ Class Foswiki::Object

This is the base object for all Foswiki classes. It defines the default
behaviour and general policies for its descendants.

---++ Implementation details.

=Foswiki::Object= is a subclass of Moo and as such inherits all its features.

---+++ Behavior changing conditions

This class' behavior could be changed by either a environment variable
=FOSWIKI_NOSTACKTRACE= and =%PERLDOC{"Assert" text="Assert's"}%= module constant
=DEBUG=. These changes should be completely transparent for the rest of core
code and only be of any interest for debugging purposes. The =DEBUG= constant is
of main significance here. =FOSWIKI_NOSTACKTRACE= is taken into account with
=DEBUG= being _true_ only.

With =DEBUG= this class:

   * records object origins recording information about the source which created
     the object. The information includes: file, line, package, subroutine name,
     and stack trace of the point where and when the =new()= method has been
     called. The information is stored in ==__origin_*= set of object
     attributes.
   * Dumps any keys found on object's hash which are not attributes declared
     with =Moo= =has=. This is to trace down legacy use of object.
     
When =FOSWIKI_NOSTACKTRACE= environment variable is set to a _true_ value then
stack trace recording is switched off. The recording is quite lingering
procedure and object creation is something done pretty frequently. So, running
code in =DEBUG= mode might become a part of Buddhist patience training for some.

---+++ Attribute validators.

Since =Moo= doesn't provide any standard checker for an attribute =isa= option
we wrote our own basic validtation methods. Those are static methods which are
named =isaTYPE()=. Currently only three =TYPEs= are supported: *ARRAY*, *HASH*,
and *CLASS*. See respective methods documentation.

A typical use of them would look like the following code:

<verbatim class="perl">
package Foswiki::SomeClass;
...
has meta => (
    is => 'rw',
    isa => Foswiki::Object::isaCLASS( 'meta', 'Foswiki::Meta', noUndef => 1, ),
);
</verbatim>

See =CPAN:Moo= IMPORTED SUBROUTINES -> =has= documentation.

---+++ Object stringifiction

=Foswiki::Object= overrides the stringification operator =""=
(see CPAN:overload) and maps it onto
=%PERLDOC{"Foswiki::Object" method="to_str" text="to_str()"}%= method. The
original method preserves Perl's standard behavior but could be overridden
by inheriting classes to achieve their goals. Check the
%PERLDOC{Foswiki::Exception}% code for an example use of this method.

=cut

require Carp;
require Foswiki::Exception;
use Try::Tiny;
use Scalar::Util qw(blessed refaddr reftype weaken isweak);
use Foswiki qw<indentInc indentMsg>;

use Foswiki::Class;

use overload fallback => 1, '""' => 'to_str';

use Assert;

=begin TML

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute app

Reference to the parent application object.

=cut

has app => (
    is        => 'rwp',
    predicate => 1,
    weak_ref  => 1,
    isa       => Foswiki::Object::isaCLASS( 'app', 'Foswiki::App', ),
    clearer   => 1,
);

# Debug-only attributes for recording object's origins; i.e. the location in the
# core where it was created. Useful for tracking down the source of problems.
has __orig_file  => ( is => 'rw', clearer => 1, );
has __orig_line  => ( is => 'rw', clearer => 1, );
has __orig_pkg   => ( is => 'rw', clearer => 1, );
has __orig_sub   => ( is => 'rw', clearer => 1, );
has __orig_stack => ( is => 'rw', clearer => 1, );

=begin TML

---+++ ObjectAttribute __id

A unique id is used to differentiate two objects of same class.

=cut

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

# Temporary storage for the group of cloning method.
has __clone_heap =>
  ( is => 'rw', clearer => 1, lazy => 1, default => sub { {} }, );

=begin TML

---++ METHODS

=cut

=begin TML

---+++ ObjectMethod new( %params ) -> $obj

All Foswiki classes must use named parameters for their =new()= method and must
be created using =%PERLDOC{"Foswiki::App" method="create"}%= method unless it is
not possible for a strong reason.

=cut

sub BUILD {
    my $this = shift;
    my ($args) = @_;

    if (DEBUG) {

        #my ( $pkg, $file, $line );
        #my $sFrame = 0;
        #do {
        #    ( $pkg, $file, $line ) = caller( ++$sFrame );
        #  } while (
        #    $pkg =~ /^(Foswiki::Object|Moo::|Method::Generate::Constructor)/ );

        my $noStackTrace = $ENV{FOSWIKI_NOSTACKTRACE} // 0;

        $this->__orig;
        $this->__orig_stack( Carp::longmess('') ) unless $noStackTrace;

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
        my %validAttrs =
          map { $_ => 1 } $this->classAttributes( ref($this) );
        foreach my $key ( keys %{$this} ) {
            unless ( $validAttrs{$key} || $key =~ /^(?:__)+orig_/ ) {
                say STDERR "Key $key on ", ref($this),
                  " isn't an attribute declared with Moo::has.";
                if ( UNIVERSAL::isa( $this->{key}, 'Foswiki::Object' ) ) {
                    say STDERR "    $key is a Foswiki::Object created in ",
                      $this->{key}->__orig_file, ":", $this->{key}->__orig_line;
                }
            }
        }
    }
}

=begin TML

---+++ ObjectMethod create( $className, @params ) -> $object

Creates a new object of class =$className=. If application object could be
guessed with %PERLDOC{"Foswiki::Object" method="guessApp"}% then its
%PERLDOC{"Foswiki::App" method="create" text="create()"}% method would be used.
Otherwise the =$object= would be created with =$className='s =new()= method.

=cut

sub create {
    my $this = shift;

    my $app = $this->guessApp;

    if ( defined $app ) {
        return $app->create(@_);
    }

    my $class = shift;
    return $class->new(@_);
}

sub _cloneData {
    my $this = shift;
    my ( $val, $attr ) = @_;

    my $heap = $this->__clone_heap;

    my $cloned;
    if ( my $dataType = ref($val) ) {
        my $refAddr = refaddr($val);

        # Check if ref is being cloned now at some upper stack frames and avoid
        # deep recursion.
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
                if ( $val->isa(__PACKAGE__) ) {

                    # Only Foswiki::Object descendants are expected to do valid
                    # clone()
                    try {
                        $val->__clone_heap($heap);
                        $val->__clone_heap->{parent} = $this;
                        $cloned = $val->clone;
                    }
                    catch {
                        # Don't hide errors as it most likely is crucial not to
                        # leave incomplete cloning behind.
                        Foswiki::Exception::Fatal->rethrow($_);
                    }
                    finally {
                        # No matter what happens inside clone() – always clear
                        # the heap.
                        $val->_clear__clone_heap;
                    };
                }
                elsif ( ref($val) eq 'Regexp' ) {
                    $cloned = $val;
                }
                else {
                    # Class without clone method. Try to copy it 'manually' by
                    # cloning as a hash and blessing the resulting hashref into
                    # $val's class.
                    # SMELL Pretty much unreliable for complex classes.
                    my $reftype = reftype($val);
                    if ( $reftype eq 'HASH' ) {
                        $cloned =
                          $this->_cloneData( {%$val}, "$attr.blessed($class)" );
                    }
                    elsif ( $reftype eq 'ARRAY' ) {
                        $cloned =
                          $this->_cloneData( [@$val], "$attr.blessed($class)" );
                    }
                    elsif ( $reftype eq 'SCALAR' ) {
                        $cloned =
                          $this->_cloneData( \$$val, "$attr.blessed($class)" );
                    }
                    else {
                        # Cannot clone unknown datatypes, just copy the original
                        # ref.
                        $cloned = $val;
                    }
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

---++ ClassMethod classAttributes -> \@attributes

A convenience shortcat to =Foswiki::Class::getClassAttributes()=.

Returns a list of names of class attributes.

This method could be used both as class and object method:

<verbatim>

my @attrs = $obj->classAttributes;

@attrs = Foswiki::Object->classAttributes;

</verbatim>

=cut

sub classAttributes {
    my $class = shift;

    # Make both class and object method style calls possible.
    $class = ref($class) || $class;
    return Foswiki::Class::getClassAttributes($class);
}

=begin TML

---++ ObjectMethod clone() -> $clonedObject

This method tries to do it's best to create an exact copy of existing object.
For that purpose this method considers a object as a data structure and
traverses it recursively creating a profile for new object's constructor. All
keys on object's hash are considered as attributes to be inserted into the
profile. In other words it means that if we have an object with keys =key1=,
=key2=, and =key3= then new object's constructor will get the following profile:

<verbatim>
my @profile = (
    key1 => $this->_cloneData( $this->{key1} ),  
    key2 => $this->_cloneData( $this->{key2} ),  
    key3 => $this->_cloneData( $this->{key3} ),  
);
my $newObj = ref($this)->new( @profile );
</verbatim>

But don't take this example seriously. The real life is more complicated. It's
ruled by the following statements:

   1. If a key name begins with =__[__[...]]orig_= prefix it is used for
      debugging needs and keeps object's creation history. To preserve the full
      history which would include the original creation moment as well as all
      cloning events such keys are prepended with additional =__= (double
      underscore) prefix. So, a clone of clone would have three copies of such
      keys named =__orig_*=, =____orig_*=, and =______orig_*=.
   1. All other attributes with =__= prefixed names are ignored and not
      duplicated.
   1. If a class wants to take care of cloning of an attribute it can define a
      =_clone_<attribute_name>()= method (say, =_clone_key2()= for the above
      example; or =_clone__attr()= for a private attribute =_attr=). In this
      case the attribute value will be ignored by cloning code and the return
      from the =_clone_<attribute_name>()= method would be used instead.
   1. Any blessed reference is considered a object. If the object has =clone()=
      method then the method is used to clone the object.
   1. For objects without =clone()= method they're copied as a hash which is
      then blessed into the object's class. %BR%
      *%X% NOTE:* This won't work for non-hash blessed references. They're must
      be taken care by the class itself by defining respective
      =_clone_attribute()= method.
   1. Regexp's refs are just copied into destination.
   1. Attributes containing references of *ARRAY*, *HASH*, and *SCALAR* types
      are cloned; refs of other types are just copied into destination. If
      copying is not a desirable behavior then respective =_clone_attribute()=
      method must be present.
   1. If a reference is weakened it's clone is weakened too.
   1. If same reference found at two or more locations of cloned object's
      structure then destination object will have identical cloned references at
      same locations; i.e. if
      <verbatim>$this->attr1 &#61;&#61; $this->attr2->subattr->[3]</verbatim>
      then
      <verbatim>$cloned->attr1 &#61;&#61; $cloned->attr2->subattr->[3]</verbatim>
      too.
   1. Circular dependecies are raising =Foswiki::Exception::Fatal=.

=cut

# XXX Experimental.
# clone works on low-level bypassing Moo's accessor methods.
sub clone {
    my $this = shift;

    $this->_clear__clone_heap unless defined $this->__clone_heap->{parent};
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

    # SMELL Should it be better to use same approach as in _cloneData - just
    # bless a profile hash?
    my $newObj = ref($this)->new(@profile);

    $this->_clear__clone_heap unless defined $this->__clone_heap->{parent};

    return $newObj;
}

=begin TML

---+++ ObjectMethod getApp -> $app

Returns application object depending on current object's status:

   1 for a %PERLDOC{"Foswiki::App"}% object returns itself
   1 if =app= attribute is set then returns its value.
   1 otherwise returns undef

=cut

sub getApp {
    my $this = shift;
    return (
          $this->isa('Foswiki::App')
        ? $this
        : ( $this->has_app ? $this->app : undef )
    );
}

=begin TML

---+++ ObjectMethod guessApp -> $app

Similar to the =getApp()= method above but tries harder and returns
=$Foswiki::app= when getApp() returns undef. Note that in some cases this
could be _undef_ too.

=cut

sub guessApp {
    my $this = shift;
    return $this->getApp // $Foswiki::app;
}

=begin TML

---++ ObjectMethod to_str => $string

This method is used to overload stringification operator "" (see
[[CPAN:overload][=perldoc overload=]]).

The default is to return object itself in order to preserve system default
behavior.

=cut

sub to_str {
    my @c = caller;
    return $_[0];
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

=begin TML

---+++ StaticMethod _normalizeAttributeName( $attributeName ) -> $normalizedName

For =Foswiki::Object= internal use only.

This method attempts to guess what class an attribute defined by it's name
belongs to. This is done for short names only (i.e. those without package name)
by traversing up the call stack until a frame not from =Foswiki::Object= is
found.

=cut

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

---+++ StaticMethod isaARRAY( $attributeName, %params )

isa validator generator checking for arrayrefs.

---++++!! Parameters

| *Key* | *Description* | *Default* |
| =noUndef= | do not allow undef value | _false_ |
| =noEmpty= | do not allow zero-length array | _false_ |

=cut

sub isaARRAY {
    my ( $attributeName, %opts ) = @_;

    $attributeName = _normalizeAttributeName($attributeName);

    return _validateIsaCode( $attributeName,
            'sub { Foswiki::Exception::Fatal->throw( text => "'
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

---++ StaticMethod isaHASH( $attributeName, \%params )

isa validator generator checking for hashrefs.

---++++!! Parameters

| *Key* | *Description* | *Default* |
| =noUndef= | do not allow undef value | _false_ |

=cut

sub isaHASH {
    my ( $attributeName, %opts ) = @_;

    $attributeName = _normalizeAttributeName($attributeName);

    return _validateIsaCode( $attributeName,
            'sub { Foswiki::Exception::Fatal->throw( text => "'
          . $attributeName
          . ' attribute may only be '
          . ( $opts{noUndef} ? '' : 'undef or an ' )
          . 'hashref." ) if '
          . ( $opts{noUndef} ? '!defined( $_[0] ) || ' : '' )
          . '( defined( $_[0] ) && ( ref( $_[0] ) ne "HASH" ) );'
          . ' }' );
}

=begin TML

---++ StaticMethod isaCLASS( $attributeName, $className, \%params )

isa validator generator checking if attribute is a class =$className= or it's
descendant.

---++++!! Parameters

| *Key* | *Description* | *Default* |
| =noUndef= | do not allow undef value | _false_ |
| =strictMatch= | allow only =$className=, no decsendants | _false_ |
| =does= | defines a role the class must do |  |

By using =does= we can define not only that the object must be, say, a
=Foswiki::Object= descendant but that it has to have =Foswiki::AppObject=
applied:

<verbatim>
has childObject => (
    is => 'rw',
    isa => Foswiki::Object::isaCLASS(
            'childObject',
            'Foswiki::Object',
            does => 'Foswiki::AppObject',
    ),
);
</verbatim>

Currently only a single role could be defined for =does=.

=cut

sub isaCLASS {
    my ( $attributeName, $className, %opts ) = @_;

    $attributeName = _normalizeAttributeName($attributeName);

    return _validateIsaCode(
        $attributeName,
        'sub { Foswiki::Exception::Fatal->throw( text => "'
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

sub _clone_app {
    return $_[0]->app;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016-2017 Foswiki Contributors. Foswiki Contributors
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
