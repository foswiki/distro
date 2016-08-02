# See bottom of file for license and copyright information

package Unit::PlackTestCase;
use v5.14;

use Plack::Test;
use FindBin;

use Moo;
use namespace::clean;
extends qw(Unit::TestCase);

BEGIN {
    if (Unit::TestRunner::CHECKLEAK) {
        eval "use Devel::Leak::Object qw{ GLOBAL_bless };";
        die $@ if $@;
        $Devel::Leak::Object::TRACKSOURCELINES = 1;
        $Devel::Leak::Object::TRACKSTACK       = 1;
    }
}

has app => (
    is        => 'rw',
    weak_ref  => 1,
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    isa => Foswiki::Object::isaCLASS( 'app', 'Unit::TestApp', noUndef => 1, ),
);

=begin TML

---++ ObjectAttribute testClientList : arrayref

List of hashrefs with test parameters.

Keys:

   * =app= 
   * =client= - required, client sub

=cut 

has testClientList => (
    is      => 'rw',
    lazy    => 1,
    isa     => Foswiki::Object::isaARRAY( 'testList', noUndef => 1, ),
    builder => 'prepareTestClientList',
);
has defaultAppClass => (
    is      => 'rw',
    default => 'Unit::TestApp',
);

sub initialize {
    my $this = shift;
    my %args = @_;

    if ( defined $args{testParams}{init} ) {
        my $init = $args{testParams}{init};
        $this->assert( ref($init) eq 'CODE',
            "testParams init key must be a coderef" );
        $init->( $this, %args );
    }
}

sub shutdown {
    my $this = shift;
}

around list_tests => sub {
    my $orig = shift;
    my $this = shift;

    my @tests;

    my $suite = $this->testSuite;
    foreach my $clientHash ( @{ $this->testClientList } ) {

        $this->assert_not_null( $clientHash->{name},
            "client test name undefined" );

        unless ( defined $clientHash->{app} ) {
            $clientHash->{app} = $this->_genDefaultAppSub($clientHash);
        }
        my $testSubName = "test_$clientHash->{name}";
        unless ( $suite->can($testSubName) ) {
            no strict 'refs';
            *{"$suite\:\:$testSubName"} = sub {
                my $test = Plack::Test->create( $clientHash->{app} );
                $clientHash->{client}->( $this, $test );
            };
            use strict 'refs';
        }
        push @tests, $testSubName;
    }

    return @tests;
};

sub prepareTestClientList {
    my $this = shift;
    my @tests;
    my $suite = $this->testSuite;

    my $clz = new Devel::Symdump($suite);
    foreach my $method ( $clz->functions ) {
        next unless $method =~ /^$suite\:\:(client_(.+))$/;
        my $subName   = $1;
        my $shortName = $2;
        push @tests, { name => $shortName, client => $suite->can($subName), };
    }
    return \@tests;
}

sub _cbPreHandleRequest {
    my $this       = shift;
    my $app        = shift;
    my $clientHash = shift;
    my %args       = @_;

    $this->app($app);
    $this->initialize( %args, testParams => $clientHash, );
}

sub _cbPostHandleRequest {
    my $this       = shift;
    my $app        = shift;
    my $clientHash = shift;
    my %args       = @_;

    $this->shutdown( %args, testParams => $clientHash, );
}

sub _genDefaultAppSub {
    my $this = shift;
    my ($clientHash) = @_;

    my %runArgs;
    foreach my $key ( grep { !/^(?:app|appClass|client)$/ } keys %$clientHash )
    {
        $runArgs{$key} = $clientHash->{$key};
    }

    my $appClass = $clientHash->{appClass} // $this->defaultAppClass;

    # Users must not use this callback.
    $runArgs{callbacks}{testPreHandleRequest} = sub {
        my $app = shift;
        $this->_cbPreHandleRequest( $app, $clientHash, @_ );
    };
    $runArgs{callbacks}{testPostHandleRequest} = sub {
        my $app = shift;
        $this->_cbPostHandleRequest( $app, $clientHash, @_ );
    };

    return sub {
        my $env = shift;

        Devel::Leak::Object::checkpoint() if Unit::TestRunner::CHECKLEAK;

        $runArgs{env} //= $env;

        my $rc = $appClass->run(%runArgs);

        if (Unit::TestRunner::CHECKLEAK) {
            Devel::Leak::Object::status();
            eval {
                require Devel::MAT::Dumper;
                Devel::MAT::Dumper::dump( $FindBin::Bin
                      . "/../working/logs/"
                      . $this->testSuite
                      . ".pmat" );
            };
        }

        return $rc;
    };
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
