# See bottom of file for license and copyright

package Unit::TestApp;
use v5.14;

use Assert;

use Scalar::Util qw(blessed weaken refaddr);
use Try::Tiny;

use Foswiki::Class qw(callbacks);
extends qw(Foswiki::App);

callback_names qw(testPreHandleRequest testPostHandleRequest);

#with qw(Foswiki::Aux::Localize);

#sub setLocalizableAttributes {
#    return
#        qw(
#          access attach cache cfg env forms
#          logger engine heap i18n plugins prefs
#          renderer request requestParams response
#          search store templates macros context
#          ui remoteUser user users zones _dispatcherAttrs
#          )
#    ;
#}

# requestParams hash is used to initialize a new request object.
has requestParams => (
    is      => 'rwp',
    lazy    => 1,
    default => sub { {} },
);

# engineParams hash is used to initialize a new engine object.
has engineParams => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

# Hash of the test callbacks to be registered on the app object.
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

before BUILDARGS => sub {

};

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

1;

__DATA__

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2007-2016 Foswiki Contributors
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
