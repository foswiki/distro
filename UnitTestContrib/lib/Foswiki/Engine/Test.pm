# See bottom of file for license and copyright information

package Foswiki::Engine::Test;
use v5.14;

=begin TML

---+!! package Foswiki::Engine::Test

This is unit tests support engine which is supposed to simulate real-life
environment for test cases.

A instance of this class initialize itself using the following sources of data:

   * Key =__foswikiEngineTestInit= on =env= attribute hash. This key must be a
     hashref which is passed to the parent constructor as a hash of defaults
     alongside with user supplied parameters in =new()= call. User parameters
     has preference of the defaults.
   * =FOSWIKI_TEST_= prefixed =env= attribute hash keys for individual keys of
     =*Data= attributes. For example, =$engine->pathData->{path_info}= would be
     set from =FOSWIKI_TEST_PATH_INFO=. These are used only when corresponding
     =*Data= attribute is not initialized over object construction stage.
   * Similar to other engines =FOSWIKI_ACTION= might be used if none of the
     above sources provided a value for the =pathData->{action}= key.
   * =FOSWIKI_TEST_QUERY_STRING= is used for setting =queryParameters=
     attribute.

=cut

use Moo;
use namespace::clean;
extends qw(Foswiki::Engine);

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;

    my %defaults;
    if ( defined $params{env}{__foswikiEngineTestInit} ) {
        %defaults = %{ $params{env}{__foswikiEngineTestInit} };
    }
    return $orig->( $class, %defaults, @_ );
};

sub initFromEnv {
    my $this     = shift;
    my %initHash = map {
        my $eKey = uc( 'FOSWIKI_TEST_' . $_ );
        defined( $this->env->{$eKey} )
          ? ( $_ => $this->env->{$eKey} )
          : ()
    } @_;
    return \%initHash;
}

around _preparePath => sub {
    my $orig = shift;
    my $this = shift;

    # Use the standard if test value is not provided.
    $this->env->{FOSWIKI_TEST_ACTION} //= $this->env->{FOSWIKI_ACTION};
    return $this->initFromEnv(qw(action path_info uri));
};

around _prepareConnection => sub {
    my $orig = shift;
    my $this = shift;

    my $connData =
      $this->initFromEnv(qw(remoteAddress serverPort method secure));

    $connData->{method} //= 'GET';

    return $connData;
};

around _prepareQueryParameters => sub {
    my $orig = shift;
    my $this = shift;

    return $orig->( $this, $this->env->{FOSWIKI_TEST_QUERY_STRING} )
      if defined $this->env->{FOSWIKI_TEST_QUERY_STRING};
    return [];
};

1;

__END__
Author: Vadim Belman

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
