# See bottom of file for license and copyright information

package Foswiki::Object;
use v5.14;

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
use Scalar::Util qw(blessed refaddr weaken isweak);
use Foswiki::Exception;

use Moo;
use namespace::clean;

use Assert;

=begin TML

---++ ClassMethod BUILDARGS()

Converts positional constructor parameters to named ones. Tries to detect if constructor is already being called using named notation.

The =BUILDARGS()= uses array =@_newParameters= declared statically on a class to get information about the order of parameters.
For example, for =Foswiki::Class=:

<verbatim>
package Foswiki::Class;
use Moo;

our @_newParameters = qw( param1 param2 );
use namespace::clean;

has param1 => (is => 'rw');
has param2 => (is => 'ro');
has param3 => (is => 'rw');

1;
</verbatim>

the following notations are valid:

<verbtaim>
my $object1 = Foswiki::Class->new($param1, $param2);
my $object2 = Foswiki::Class->new($param1);
my $object3 = Foswiki::Class->new(param1 => 1, param2 => '2', param3 => 'additional');
my $object3 = Foswiki::Class->new({param1 => 1, param2 => '2', param3 => 'additional'});
</verbatim>

Note that for =$object2= the =BUILD()= method will be called with no param2 key.

Key/value pairs as in =$object3= example are valid as soon as at least one key is mentioned in =@_newParameters=.
This limitation will remain actual until constructor are no more called with positional parameters.

=cut

has __orig_file  => ( is => 'rw', clearer => 1, );
has __orig_line  => ( is => 'rw', clearer => 1, );
has __orig_stack => ( is => 'rw', clearer => 1, );

sub BUILDARGS {
    my ( $class, @params ) = @_;

    # Skip processing if already have passed with a hash ref.
    return $params[0] if @params == 1 && ref( $params[0] ) eq 'HASH';

    # Take care of clone-like methods.
    if ( ref($class) ) {
        $class = ref($class);
    }

    my $paramHash;

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
}

sub BUILD {
    my $this = shift;

    if (DEBUG) {
        my ( $pkg, $file, $line );
        my $sFrame = 0;
        do {
            ( $pkg, $file, $line ) = caller( ++$sFrame );
          } while (
            $pkg =~ /^(Foswiki::Object|Moo::|Method::Generate::Constructor)/ );
        $this->__orig_file($file);
        $this->__orig_line($line);
        $this->__orig_stack( Carp::longmess('') );
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
            unless ( $this->can($key) ) {
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

has __clone_heap =>
  ( is => 'rw', clearer => 1, lazy => 1, default => sub { {} }, );

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
                  "Circular dependecy detected on a object being cloned" );
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
                    $cloned = $this->_cloneData( \%{$val}, $attr );
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

# XXX Experimental.
# clone works on low-level bypassing Moo's accessor methods.
sub clone {
    my $this = shift;

    $this->_clear__clone_heap;
    my @profile;
    foreach my $attr ( keys %$this ) {
        my $clone_method = "_clone_" . $attr;
        my $attrVal;
        if ( my $method = $this->can($clone_method) ) {
            $attrVal = $method->($this);
        }
        else {
            $attrVal = $this->_cloneData( $this->{$attr}, $attr );
        }

        push @profile, $attr, $attrVal;
    }

    my $newObj = ref($this)->new(@profile);

    return $newObj;
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
