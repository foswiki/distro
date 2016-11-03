# See bottom of file for license and copyright information

package Foswiki::Engine::Test;
use v5.14;

=begin TML

---+!! package Foswiki::Engine::Test

This is unit tests support engine which is supposed to simulate real-life
environment for test cases.

---++ Object Initialization

A instance of this class initialize itself using the following sources of data
(in the order from higher to lower priority):

   1. Constructor stage:
      * User supplied parameters.
      * =setUrl= key of =initialAttributes= constuctor parameter.
      * Key =__foswikiEngineTestInit= on =env= constructor parameter. This key
        must be a hashref and it defines the defaults for constructor
        parameters.
      * =setUrl= key of =initialAttributes= parameter from
        =__foswikiEngineTestInit=.
   1. Run-time stage:
      * =initialAttributes= object attribute. For example,
        =$engine->pathData->{path_info}= would be fetched from
        =$engine->initialAttributes->{path_info}=.
      * =FOSWIKI_TEST_= prefixed keys of the =env= attribute hash for individual
        keys of =*Data= attributes (see =Foswiki::Engine=). For example,
        =$engine->pathData->{path_info}= would be set from
        =FOSWIKI_TEST_PATH_INFO=. These are used only when corresponding =*Data=
        attribute is not initialized at object construction stage.
      * Similar to other engines =FOSWIKI_ACTION= might be used if none of the
        above sources provides a value for the =$engine->pathData->{action}=
        key.
      * =FOSWIKI_TEST_QUERY_STRING= is used for setting =queryParameters=
        attribute.
      
*NOTE* Most of the time constructor parameter and object attribute are the
same thing - see CPAN:Moo. But remember that when 'constructor parameter'
is used it means at this stage attributes are not initialized yet. Or attribute
may differ from constructor parameter value.

*NOTE* on =__foswikiEngineTestInit=: it is a global default for all newly
created engine objects. So that instead of duplicating a call like this:

<verbatim>
$engine = Foswiki::Engine::Test->new(
    initialAttributes => {
        path_info => '/Web/TopicName',
    },
);
</verbatim>

or in terms of =Unit::FoswikiTestRole= =createNewFoswikiApp= method:

<verbatim>
# This is way more common throughout the tests code.
$testCase->createNewFoswikiApp(
    engineParams => {
        initialAttributes => {
            path_info => '/Web/TopicName',
        },
    },
);
</verbatim>

it would be easier to define the parameter once within =set_up= method:

<verbatim>
around set_up => sub {
    my $orig = shift;
    my $this = shift;
    
    $orig->($this, @_);
    
    $this->app->env->{__foswikiEngineTestInit} = {
        initialAttributes => {
            path_info => '/Web/TopicName',
        },
    };
};
</verbatim>

Since the =env= attribute is cloned by the =createNewFoswikiApp()= method from
previously active application object the key will be propagaded and all newly
created engines will use it as the default. Similar effect would be achieved
by setting =FOSWIKI_TEST_PATH_INFO= key of =env=. But whereas =FOSWIKI_TEST_*=
are used to setup request parameters, =__foswikiEngineTestInit= can define
any engine constructor parameter. For example:

<verbatim>
$this->app->env->{__foswikiEngineTestInit} = {
    simulate => 'cgi',    
};
</verbatim>

=cut

use Assert;

use Foswiki::Class;
extends qw(Foswiki::Engine);

=begin TML

---++ ObjectAttribute simulate -> [psgi|cgi]

The only valid values for this attribute are either 'psgi' or 'cgi'. It defines
how this engine communicates with the 'outside' worlds: either in PSGI way by
returning a three element array; or in CGI way by sending HTTP response to
stdout.

=cut

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

=begin TML

---++ ObjectAttribute initialAttributes

This is a hashref for initializing =Foswiki::Engine= =*Data= attributes. It is
used by =initFromEnv= method as described in the _Initialization_ section of
this document.

See =Foswiki::Engine= =pathData=, =connectionData= for the list of of keys.
Additionally the following keys are used:

| *Key* | *Initialized attribute* | *Comment* |
| =user=, =remote_user= | =user= | =user= takes precedence |
| =postData= | =postData= | What is defined by the key would end up in engine's =postData= attribute as is, with no modification and will be validated by a request object. |

=cut

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

=begin TML

---++ ObjectMethod initFromEnv(@keys)

Forms a data hash using keys either from initialAttributes (higher prio) or from
=env=. See the _Initialization_ section of this document. Requested keys are
defined by this method arguments.

Returns a hashref.

=cut

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

around preparePath => sub {
    my $orig = shift;
    my $this = shift;

    # Use the standard if test value is not provided.
    $this->env->{FOSWIKI_TEST_ACTION} //= $this->env->{FOSWIKI_ACTION};
    return $this->initFromEnv(qw(action path_info uri));
};

around prepareConnection => sub {
    my $orig = shift;
    my $this = shift;

    my $connData =
      $this->initFromEnv(qw(remoteAddress serverPort method secure));

    $connData->{method} //= 'GET';

    return $connData;
};

around prepareQueryParameters => sub {
    my $orig = shift;
    my $this = shift;

    my $queryString = $this->initialAttributes->{query_string}
      // $this->env->{FOSWIKI_TEST_QUERY_STRING};

    return $orig->( $this, $queryString ) if defined $queryString;
    return [];
};

around prepareHeaders => sub {
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

around prepareUser => sub {
    my $orig     = shift;
    my $this     = shift;
    my $initHash = $this->initFromEnv(qw(user remote_user));
    return $initHash->{user} // $initHash->{remote_user};
};

around preparePostData => sub {
    my $orig     = shift;
    my $this     = shift;
    my $initHash = $this->initFromEnv(qw(postData));
    return $initHash->{postData};
};

=begin TML

---++ ObjectMethod mergeAttrs(\%attrs1 [, \%attrs2 [, ...]])

Gets a list of hashrefs and deep merges them. The first one is the destination
hash which will contain the result of the merge.

By deep merge it is meant that any if more than one hash has a key SomeKey at
Nth depth level and the keys in turn contain hashrefs then those hashes are
merged too.

For example:

<verbatim>
my %attr1 = (
    A => B,
    Lev1 => {
        Lev2 => {
            A2 => B2,
            Lev3 => {
                C3 => D3,
            }
        }
    },
);
my %attr2 = (
    Lev1 => {
        A1 => B1,
        Lev2 => {
            A2 => Bb2,
            Lev3 => {
                A3 => B3,
            }
        }
    },
);
my %attr3 = (
    Lev1 => {
        A1 => Bb1,
        C1 => D1,
        Lev2 => {
            Lev3 => {
                A3 => Bb3,
                E3 => F3,
            }
        }
    },
);

mergeAttrs(\%attr1, \%attr2, \%attr3);
</verbatim>

This code will result in the following content in =%attr1=:
<verbatim>
(
    A => B,
    Lev1 => {
        A1 => B1,
        C1 => D1,
        Lev2 => {
            A2 => B2,
            Lev3 => {
                C3 => D3,
                A3 => B3,
                E3 => F3,
            }
        }
    }
)
</verbatim>

Keys =A2= from =%attr2=, =A3= and =A1= from =%attr3= are dropped due to lower
priority of these hashes.

=cut

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

=begin TML

---++ ObjectMethod parseURL($queryString) -> \%attrs

This method parses =$queryString= with complete URL and returns constructor-compatible attribute hash
where =initialAttributes= constructor parameter is initialized from the query string. The following keys
are set: =secure=, =headers= (_Host_ header), =query_string=, and =path_info=.

Returns attributes hash suitable to be used by the constructor method.

=cut

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
