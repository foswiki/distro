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
     has preference over the defaults.
   * For both defaults and user parameters =setUrl= key of =initialAttributes=
     hash may be used to set those parameters which are not set implicitly by
     corresponding source.
   * =FOSWIKI_TEST_= prefixed =env= attribute hash keys for individual keys of
     =*Data= attributes. For example, =$engine->pathData->{path_info}= would be
     set from =FOSWIKI_TEST_PATH_INFO=. These are used only when corresponding
     =*Data= attribute is not initialized at object construction stage.
   * Similar to other engines =FOSWIKI_ACTION= might be used if none of the
     above sources provided a value for the =pathData->{action}= key.
   * =FOSWIKI_TEST_QUERY_STRING= is used for setting =queryParameters=
     attribute.

=cut

use Assert;

use Moo;
use namespace::clean;
extends qw(Foswiki::Engine);

has simulate => (
    is      => 'rw',
    default => 'psgi',
    coerce  => sub {
        my $method = lc shift;
        Foswiki::Engine::Fatal->throw( text =>
              "Unknown test engine simulate environment requested: $method" )
          unless $method =~ /^(psgi|cgi)$/;
        return $method;
    },
);
has initialAttributes => ( is => 'rw', default => sub { { headers => {}, } }, );

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;

    my %defaults;
    if ( defined $params{env}{__foswikiEngineTestInit} ) {
        %defaults = %{ $params{env}{__foswikiEngineTestInit} };
    }

    mergeAttrs(
        \%params,   parseURL( $params{initialAttributes}{setUrl} ),
        \%defaults, parseURL( $defaults{initialAttributes}{setUrl} )
    );

    return $orig->( $class, %params );
};

# Form a data hash using keys either from initialAttributes (higher prio) or
# from env.
sub initFromEnv {
    my $this      = shift;
    my $initAttrs = $this->initialAttributes;
    my $env       = $this->env;
    my %initHash  = map {
        my $eKey = uc( 'FOSWIKI_TEST_' . $_ );
        defined( $initAttrs->{$_} ) ? ( $_ => $initAttrs->{$_} )
          : (
            defined( $env->{$eKey} ) ? ( $_ => $env->{$eKey} )
            : ()
          )
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

    my $queryString = $this->initialAttributes->{query_string}
      // $this->env->{FOSWIKI_TEST_QUERY_STRING};

    return $orig->( $this, $queryString ) if defined $queryString;
    return [];
};

around _prepareHeaders => sub {
    my $orig = shift;
    my $this = shift;

    my $headers = $orig->($this);
    foreach my $header ( keys %{ $this->env } ) {
        next unless $header =~ m/^FOSWIKI_TEST_(?:HTTP|CONTENT|COOKIE)/i;
        ( my $field = $header ) =~ s/^FOSWIKI_TEST_//;
        $field =~ s/^HTTPS?_//;
        $headers->{$field} = $this->env->{$header};
    }

    # Initial attributes override environment values.
    my $initAttrs = $this->initialAttributes;
    if ( defined $initAttrs->{headers} ) {
        ASSERT(
            ref( $initAttrs->{headers} ) eq 'HASH',
            "Initial test engine headers key is a hashref"
        );
        $headers->{$_} = $initAttrs->{headers}{$_}
          foreach keys %{ $initAttrs->{headers} };
    }

    return $headers;
};

around _prepareUser => sub {
    my $orig     = shift;
    my $this     = shift;
    my $initHash = $this->initFromEnv(qw(user remote_user));
    return $initHash->{user} // $initHash->{remote_user};
};

around _preparePostData => sub {
    my $orig     = shift;
    my $this     = shift;
    my $initHash = $this->initFromEnv(qw(postData));
    return $initHash->{postData};
};

sub mergeAttrs {
    my @hashes = @_;
    ASSERT( UNIVERSAL::isa( $_, 'HASH' ),
        "Non-hash parameter in call to mergeAttrs()" )
      foreach @hashes;
    my $base = shift @hashes;

    my %skipKeys;
    foreach my $extra (@hashes) {
        foreach my $key ( keys %$extra ) {
            next if $skipKeys{$key};
            if ( UNIVERSAL::isa( $base->{$key}, 'HASH' ) ) {

                # Nested hashes.
                my @subhashes;
                $skipKeys{$key} = 1;
                push @subhashes, $_
                  foreach grep { UNIVERSAL::isa( $_, 'HASH' ) }
                  map { $_->{$key} } @hashes;
                mergeAttrs( $base->{$key}, @subhashes );
            }
            elsif ( !defined( $base->{$key} ) && defined $extra->{$key} ) {
                $skipKeys{$key} = 1
                  ; # Key is now set, no need to check agains the rest of the attribute hashes.
                $base->{$key} = $extra->{$key};
            }
        }
    }
}

sub parseURL {
    my ($queryString) = @_;

    return () unless $queryString;

    my %attrs     = ( initialAttributes => {} );
    my $initAttrs = $attrs{initialAttributes};
    my $path      = $queryString;
    my $urlParams = '';
    if ( $queryString =~ /(.*)\?(.*)/ ) {
        $path      = $1;
        $urlParams = $2;
    }

    if ( $path =~ s/(https?):\/\/(.*?)\/// ) {
        my $protocol = $1;
        my $host     = $2;
        if ( $protocol =~ /https/i ) {
            $initAttrs->{secure} = 1;
        }
        else {
            $initAttrs->{secure} = 0;
        }

        #print STDERR "setting Host to $host\n";
        $initAttrs->{headers}{Host} = $host;
    }

    $initAttrs->{query_string} = $urlParams;
    $initAttrs->{path_info}    = Foswiki::Sandbox::untaintUnchecked($path);
    return \%attrs;
}

around finalizeReturn => sub {
    my $orig     = shift;
    my $this     = shift;
    my ($return) = @_;

    my $rc = $return;
    if ( $this->simulate eq 'cgi' ) {
        $rc = 0;

        push @{ $return->[1] }, 'Status' => $return->[0];
        print $this->stringifyHeaders($return);
        print @{ $return->[2] };
    }
    return $rc;
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
