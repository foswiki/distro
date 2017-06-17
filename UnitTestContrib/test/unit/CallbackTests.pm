# See bottom of file for license and copyright information

package CBTest::Provider;

use Foswiki::Class qw(callbacks);
extends qw(Foswiki::Object);

callback_names qw(testCB);

sub methodWithCB {
    my $this = shift;

    $this->callback( testCB => { testParam => 'See it!', } );
}

package CBTest::Handler;

use Scalar::Util qw(weaken);

use Foswiki::Class qw(callbacks);
extends qw(Foswiki::Object);

sub BUILD {
    my $this = shift;

    my $params = { this => $this, };
    weaken( $params->{this} );
    $this->registerCallback( 'CBTest::Provider::testCB', \&cbHandler, $params );
}

sub cbHandler {
    my $obj    = shift;
    my %params = @_;

    my $this = $params{data}{this};

    say STDERR "This is handler for object ", $this->__id;
}

package CallbackTests;

use Assert;
use Foswiki::Exception ();

use Foswiki::Class;
extends qw(FoswikiFnTestCase);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    return $orig->( $class, @_, testSuite => 'CallbackTests' );
};

sub test_multiObject {
    my $this = shift;

    my $provider = $this->create('CBTest::Provider');
    my @obj;

    for ( 1 .. 2 ) {
        push @obj, $this->create('CBTest::Handler');
    }

    $provider->methodWithCB;

    say "Deleting ", $obj[0]->__id;
    delete $obj[0];

    $this->leakDetectDump("CBTest");

    $provider->methodWithCB;
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
