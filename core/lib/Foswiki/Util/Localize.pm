# See bottom of file for license and copyright information

=begin TML

---++!! Role Foswiki::Util::Localize

This role determines classes which are able to simulate =local= Perl operator
using OO approach. They do it by providing two methods: =localize()= and
=restore()=. The first one cleans up object to some desired state. For example –
by cleaning up all attributes and by settings some of them to user-provided
values. An instance of =Foswiki::Util::Holder= class is been created then and stores
a refernce to the object being localized. The holder is supposed to be stored in
a =my= variable within same scope for where we would like the =local= operator
to be active. When we leaving the scope the holder object destroyer method calls
the =restore()= method of the localized object. After that we expect that the
object is been restored to its pre-localized state.

Though it may sound a bit complicated the actual use is as simple as:

<verbatim>
sub someMethod {
    my $localizableObj = Foswiki::Localizable->new( attr => 'attr string' );
    if ($some_condition) {
        my $holder = $localizableObj->localize( attr => 'another string' );
        
        ...; # Do something here
    }
    # At this point $localizableObj is in the same state as it was before the
    # if() clause.
}
</verbatim>

Note that =$holder->object= is equal to =$localizedObj=; in other words it's not
the object in its pre-localized state but in its current state. It's not
recommended to use the holder object other than in the last code sample.

This role HAS to be considered temporary compatibility solution. In the future
use of the =localize()= method must be replaced by temporary objects of the same
class.

=cut

package Foswiki::Util::Localize;
use v5.14;

use Foswiki::Util::Holder ();

use Try::Tiny;

use Moo::Role;

# _dataStack is a storage for configurations active upon localize() method
# calls.
has _dataStack => ( is => 'rw', lazy => 1, default => sub { [] }, );

=begin TML

---++ ObjectAttribute _localizableAttributes

Array of object attributes to be saved on =_dataStack=.

=cut

has _localizableAttributes => (
    is      => 'ro',
    lazy    => 1,
    default => sub { return [ $_[0]->setLocalizableAttributes ]; },
);

=begin TML

---++ ObjectAttribute _localizeState => $stateStr

Have one of the following values:

   * '' (empty string) – object is in normal state;
   * localizing – object is being currently localized, i.e. the =localize()= method is working.
   * restoring - object is being currently restored, i.e. the =restore()= method is working.

=cut

has _localizeState => ( is => 'rw', lazy => 1, clearer => 1, default => '', );

has _localizeFlags =>
  ( is => 'rw', lazy => 1, builder => '_setLocalizeFlags', );

# Removes attribute from the object.
sub _clearAttrs {
    my $this = shift;
    my @attrs = @_ > 0 ? @_ : @{ $this->_localizableAttributes };

    # Cache clear methods found by previous runs.
    state %methodsCache;

    my $class = ref($this);

    my $classCache = ( $methodsCache{$class} //= {} );

    foreach my $attr (@attrs) {

        if ( !defined $classCache->{$attr} ) {
            my $clear_method = $attr;

            # Take care of the lead _ in the attribute name.
            $clear_method =~ s/^(_?)//;
            my $prefix = $1 // '';
            $clear_method = "${prefix}clear_${clear_method}";
            unless ( $classCache->{$attr} = $class->can($clear_method) ) {
                $classCache->{$attr} = eval "sub { delete \$_[0]->{'$attr'} }";
            }
        }

        $classCache->{$attr}->($this);
    }
}

=begin TML

---++ ObjectMethod localize( %newAttributes ) => $holder

This method pushes on =_dataStack= all attributes defined by
=_localizableAttributes=. New attribute values are set using =%newAttributes=
hash.

Returns a newly created =Foswiki::Util::Holder= instance.

If a class with this role wants to implement its own localization method then it
must not inherit this method but =doLocalize()=. 

*NOTE* This method operates on low-level object hash accessing directly
attribute keys on =$this=. This is due to risk of auto-vivification of some lazy
attributes with defined =default= or =builder= properties. This way it avoids
storing of non-set attributes too without demanding =predicate= attribute
property to be set true.

Contrary to this new attribute values are set using normal
=$this-&gt;attr($newValue)= method.

=cut

sub localize {
    my $this = shift;
    my @args = @_;

    $this->_localizeState('localizing');
    try {
        $this->doLocalize(@args);
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    }
    finally {
        $this->_clear_localizeState;
    };

    return Foswiki::Util::Holder->new( object => $this );
}

sub doLocalize {
    my $this          = shift;
    my %newAttributes = @_;

    my $dataHash =
      { map { exists $this->{$_} ? ( $_ => $this->{$_} ) : () }
          @{ $this->_localizableAttributes } };

    push @{ $this->_dataStack }, $dataHash;

    $this->_clearAttrs if $this->_localizeFlags->{clearAttributes};

    foreach my $attr ( keys %newAttributes ) {
        $this->$attr( $newAttributes{$attr} // undef );
    }
}

=begin TML

---++ ObjectMethod restore()

This method shall restore a object to its state before the last call to the
=localize()= method.

=cut

sub restore {
    my $this = shift;

    $this->_localizeState('restoring');
    try {
        $this->doRestore(@_);
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    }
    finally {
        $this->_clear_localizeState;
    };
}

sub doRestore {
    my $this = shift;

    $this->_clearAttrs if $this->_localizeFlags->{clearAttributes};

    my $prevState = pop @{ $this->_dataStack };
    foreach my $attr ( @{ $this->_localizableAttributes } ) {
        $this->$attr( $prevState->{$attr} ) if exists $prevState->{$attr};
    }
}

sub setLocalizeFlags {
    return clearAttributes => 1;
}

sub _setLocalizeFlags {
    return { $_[0]->setLocalizeFlags };
}

=begin TML

---++ Required setLocalizableAttributes => @attrList

Must return a list of attributes to be stored/restored upon localization
procedure.

=cut

requires 'setLocalizableAttributes';

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
