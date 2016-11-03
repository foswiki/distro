# See bottom of file for license and copyright

package Unit::TestApp;
use v5.14;

=begin TML

---+ Class Unit::TestApp

This is the default application class for unit tests. It provides additional
functionality to support testing while offloading it from the parent
=Foswiki::App= class to reduce %WIKITOOLNAME% memory footprint and probably
avoid some slowdown by handling cases which are not gonna be met outside of
the testing environment.

Alongside to this class one must also study =Foswiki::Engine::Test=.

=cut

use Assert;

use Scalar::Util qw(blessed weaken refaddr);
use Try::Tiny;

use Foswiki::Class qw(callbacks);
extends qw(Foswiki::App);

=begin TML

---++ Callbacks

This class defines the following callbacks (see =Foswiki::Aux::Callbacks=):

| *name* | *Description* |
| =testPreHandleRequest= | Executed before control is passed over to =Foswiki::App= =handleRequest()= method. |
| =testPostHandleRequest= | Executed right after =Foswiki::App= =handleRequest()= method finishes. |

See [[#AttrCallbacks][=callbacks= attribute]].

---+++ Callback testPreHandleRequest

No =params= are sent to the handler.

---+++ Callback testPostHandleRequest

=params= contains one key: =rc= with =handleRequest= method return value.

=cut

callback_names qw(testPreHandleRequest testPostHandleRequest);

=begin TML

---++ ObjectAttribute requestParams -> hash

This is a hash of parameters to be passed over to =Foswiki::Request=
constructor.

=cut

has requestParams => (
    is      => 'rwp',
    lazy    => 1,
    default => sub { {} },
);

=begin TML

---++ ObjectAttribute engineParams -> hash

This is a hash of parameters to be passed over to =Foswiki::Engine=
constructor.

=cut

has engineParams => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

=begin TML

#AttrCallbacks
---++ ObjectAttribute callbacks -> hash

A hash of =callback =&gt; \&handler= pairs. Handlers are registered for their
respective callbacks. Each handler =data= parameter is a hash whith the only 
key =app= containing reference to the application object.

=cut

has callbacks => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    isa       => Foswiki::Object::isaHASH('callbacks'),
    default   => sub { {} },
);
has _cbRegistered => (
    is      => 'rw',
    default => 0,
);

around BUILDARGS => sub {
    my $orig = shift;
    my $this = shift;

    # SMELL The global $inUnitTestMode must be gone.
    $Foswiki::inUnitTestMode = 1;

    return $orig->( $this, inUnitTestMode => 1, @_ );
};

sub BUILD {
    my $this = shift;

    # Fixup Foswiki::AppObject descendants which have been cloned from objects
    # on another Foswiki::App instance.
    foreach my $attr ( keys %$this ) {
        if (
               blessed( $this->{$attr} )
            && $this->$attr->isa('Foswiki::Object')
            && $this->$attr->does('Foswiki::AppObject')
            && ( !defined( $this->$attr->app )
                || ( $this->$attr->app != $this ) )
          )
        {
            $this->$attr->_set_app($this);
        }
    }
}

=begin TML

---++ ObjectMethod cloneEnv => \%envHash

Clones current application =env= hash.

=cut

sub cloneEnv {
    my $this = shift;

    # SMELL Use Foswiki::Object internals.
    my $clonedEnv = $this->_cloneData( $this->env, 'env' );
    $this->_clear__clone_heap;
    return $clonedEnv;
}

sub registerCallbacks {
    my $this = shift;

    return if $this->_cbRegistered;

    my $cbData = { app => $this, };
    weaken( $cbData->{app} );
    foreach my $cbName ( keys %{ $this->callbacks } ) {
        $this->registerCallback( $cbName, $this->callbacks->{$cbName},
            $cbData );
    }

    $this->_cbRegistered(1);
}

around callbacksInit => sub {
    my $orig = shift;
    my $this = shift;

    $this->registerCallbacks;
    return $orig->( $this, @_ );
};

around _prepareRequest => sub {
    my $orig = shift;
    my $this = shift;

    return $orig->( $this, %{ $this->requestParams } );
};

around _prepareEngine => sub {
    my $orig = shift;
    my $this = shift;

    return $orig->( $this, %{ $this->engineParams } );
};

around handleRequest => sub {
    my $orig = shift;
    my $this = shift;

    my $rc;
    try {
        $this->callback('testPreHandleRequest');
        $rc = $orig->( $this, @_ );
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    }
    finally {
        $this->callback( 'testPostHandleRequest', { rc => $rc }, );
    };

    return $rc;
};

=begin TML

---++ Examples

---+++ A test case code

This code demonstrates a sample case of testing a request. Take a note that
tests are using =Foswiki::Engine::Test= engine.

What is demonstrated here is:

   * Handling of application's internal exceptions. Useful for cases when we expect an exception and test success depends on it. It would be then easier to get the exception itself instead of analyzing HTML output.
   * Passing of new application parameters via =createNewFoswikiApp= method.
   * Defining basic request parameters as engine constructor parameters.

<verbatim>
sub _cbHRE {
    my $obj  = shift;
    my %args = @_;
    $args{params}{exception}->rethrow;
}

sub test_someTest {
    my $this = shift;
    
    ...
    
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                templatetopic => $this->test_web . ".TemplateTopic",
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/" . $this->test_topic,
                user      => $this->app->cfg->data->{AdminUserLogin},
                action    => 'view',
                method    => 'GET',
            },
            simulate => 'psgi',
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );
    
    try {
        my ($text) = $this->capture(
            sub {
                return $this->app->handleRequest;
            }
        );
    } catch {
        my $e = Foswiki::Exception::Fatal->transmute($_, 0);
        
        # Handle any application exception here.
        unless ( $e->isa('Foswiki::OopsException') ) {
            # Assume that we expected an oops.
            $e->rethrow;
        }
        
        ...
    }
}
</verbatim>

---++ See also

=Unit::FoswikiTestRole=, =Foswiki::Engine::Test=

=cut

1;

__END__

Copyright (C) 2016 Foswiki Contributors
All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
