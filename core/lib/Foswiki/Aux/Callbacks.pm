# See bottom of file for license and copyright information

=begin TML

---+ Role Foswiki::Aux::Callbacks

*Experimental*

Support of callbacks for classes which may need them. Might be replaced by
future new plugins code or become a part of it.

Callback is a coderef (a sub) which gets called at certain moments of a class
life cycle. A callback sub is called with the following arguments:

   1 Reference to the object which is calling the callback.
   1 A list of key/value pairs where the following keys are defined:
      * =data= User data if supplied by the object which has registered this callback. Data format determined by the registering object.
      * =params= Parameteres supplied by the calling object. Data format defined by the object and must be documented.
      
A named callback may have more than one handler. In this case all handlers are
executed in the order they were registerd. No return values are respecred. If a
handler wants to be the last it must raise =Foswiki::Exception::CB::Last=
exception. If set, exception's =returnValue= attribute contains what is returned
by =callback()= method then.

If a callback handler raises any other exception besides of
=Foswiki::Exception::CB::*= then that exception is rethrown further up the call
stack.

Example callback handler may look like:

<verbatim>
sub cbHandler {
    my $obj = shift;
    my %args = @_;
    
    my $this = $args{data}{this};
    
    my $rc;
    
    ... # Do something.
    
    if ($errorHappened) {
        Foswiki::Exception::Fatal->throw( text => "That's bad!" );
    }
    
    # Suppose that $rc is set when the 
    if (defined $rc) {
        Foswiki::Exception::CB::Last->throw( returnValue => $rc );
    }
}
</verbatim>

=cut

package Foswiki::Aux::Callbacks;
use v5.14;

use Assert;
use Try::Tiny;

use Moo::Role;

has _validCBs => (
    is      => 'rw',
    lazy    => 1,
    default => sub { return [ $_[0]->_validCallbacks ]; },
);
has _validIndex => (
    is      => 'rw',
    clearer => 1,
    lazy    => 1,
    default => sub {
        my $this = shift;
        return { map { $_ => 1 } @{ $this->_validCBs } };
    },
);
has _registeredCB => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

=begin TML

---++ ObjectMethod registerCallback($name, $fn, $userData)

Adds coderef =$fn= to the list of registered handlers of callback =$name=.

Callback =$name= must be supported by the class.

=cut

sub registerCallback {
    my $this = shift;
    my ( $name, $fn, $userData ) = @_;

    ASSERT( ref($fn) eq 'CODE', "callback must be a coderef" );

    ASSERT( $this->_validIndex->{$name},
        "callback '$name' must be supported by class " . ref($this) );

    push @{ $this->_registeredCB->{$name} },
      {
        code => $fn,
        data => $userData,
      };
}

=begin TML

---++ ObjectMethod callback($name, @params)

=cut

sub callback {
    my $this = shift;
    my ( $name, $params ) = @_;

    ASSERT( $this->_validIndex->{$name},
        "callback '$name' must be supported by class " . ref($this) );

    my $lastException;
    foreach my $cbInfo ( @{ $this->_registeredCB->{$name} } ) {
        try {
            $cbInfo->{code}
              ->( $this, data => $cbInfo->{data}, params => $params, );
        }
        catch {
            my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
            if ( $e->isa('Foswiki::Exception::CB') ) {
                if ( $e->isa('Foswiki::Exception::CB::Last') ) {
                    $lastException = $e;
                }
                else {
                    Foswiki::Exception::Fatal->throw(
                            text => "Unknown callback exception "
                          . ref($e)
                          . "; the exception data is following:\n"
                          . $e->stringify, );
                }
            }
            else {
                $e->rethrow;
            }
        };
        last if $lastException;
    }

    if ( $lastException && $lastException->has_returnValue ) {
        return $lastException->returnValue;
    }

    return;
}

=begin TML

---++ RequiredMethod _validCallbacks => \@cbList

Returns a list of names of callbacks valid for a class.

=cut

requires '_validCallbacks';

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
