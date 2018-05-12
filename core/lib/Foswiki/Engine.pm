# See bottom of file for license and copyright information

=begin TML

---+!! Class Foswiki::Engine

Engine is a mediator between the 'outside' world (i.e. – user side browser or a
test unit code) and %WIKITOOLNAME% core; in particular –
=%PERLDOC{Foswiki::Request}%= object.

This is the base class which implements basic functionality only. Each engine
should inherit from it and overload methods necessary to achieve correct
behavior.

=cut

package Foswiki::Engine;
use v5.14;

use Try::Tiny;
use Assert;
use Scalar::Util ();
use Unicode::Normalize;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);

use constant HTTP_COMPLIANT => undef;    # This is a generic class.

=begin TML

---++ ObjectAttribute env -> hash

Hashref of environment variables. Depending on engine might be fetched from
different sources. For example, for PSGI it's application sub argument.

Default: application object =env= attribute.

=cut 

has env => (
    is  => 'rw',
    isa => Foswiki::Object::isaHASH( 'env', noUndef => 1, ),
    default => sub { $_[0]->app->env },
);

=begin TML

---++ ObjectMethod gzipAccepted -> bool

True if client accepts gzip compression.

=cut

has gzipAccepted => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $this = shift;
        my $encoding;
        if ( ( $this->env->{'HTTP_ACCEPT_ENCODING'} || '' ) =~
            /(?:^|\b)((?:x-)?gzip)(?:$|\b)/ )
        {
            $encoding = $1;
        }
        elsif ( $this->env->{'SPDY'} ) {
            $encoding = 'gzip';
        }
        return $encoding;
    },
);

=begin TML

---++ ObjectAttribute pathData -> hash

pathData attribute is a hash with the following keys:

   * =action=
   * =path_info=
   * =uri=

The =uri= key can be undef under certain circumstances.

=cut

has pathData => ( is => 'rw', lazy => 1, builder => 'preparePath', );

=begin TML

---++ ObjectAttribute connectionData -> hash

connectionData attribute is a hash with the following keys:

   * =remoteAddress=
   * =serverName=
   * =serverPort=
   * =method=
   * =secure=

=cut

has connectionData =>
  ( is => 'rw', lazy => 1, builder => 'prepareConnection', );

=begin TML

---++ ObjectAttribute queryParameters and bodyParameters

Parameter attributes are arrays of hashrefs with keys =-name= and =-value= where
the former is a plain string and the latter may be either a scalar or an
arrayref.

=cut

has queryParameters => (
    is      => 'rw',
    lazy    => 1,
    isa     => Foswiki::Object::isaARRAY( 'queryParameters', noUndef => 1 ),
    builder => 'prepareQueryParameters',
);
has bodyParameters => (
    is      => 'rw',
    lazy    => 1,
    isa     => Foswiki::Object::isaARRAY( 'bodyParameters', noUndef => 1 ),
    builder => 'prepareBodyParameters',
);

=begin TML

---++ ObjectAttribute postData

Containts raw, non-decoded, POST data.

=cut

has postData => (
    is      => 'ro',
    lazy    => 1,
    builder => 'preparePostData',
);

=begin TML

---++ ObjectAttribute uploads

Hash of =$filename => \%uploadInfo= pairs.

=cut

has uploads =>
  ( is => 'rw', lazy => 1, clearer => 1, builder => 'prepareUploads', );

=begin TML

---++ ObjectAttribute HTMLcompliant

Boolean. True if engine is HTTP compliant. For now the only false is possible
for the CLI engine class.

Lazy set from Foswiki::Engine::<engine>::HTTP_COMPLIANT constant.

=cut

has HTTPCompliant => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return eval( ref( $_[0] ) . "::HTTP_COMPLIANT" );
    },
);

=begin TML

---++ ObjectAttribute user

Suggested username.

=cut

has user => ( is => 'rw', lazy => 1, builder => 'prepareUser', );

=begin TML

---++ ObjectAttribute headers

Hashref of headers.

=cut

has headers => ( is => 'rw', lazy => 1, builder => 'prepareHeaders', );

=begin TML

---++ StaticMethod start(env => \%env)

Determines the type of environment we're running under and creates an instance
of corresponding class. The environment is been detected by:

   * reading configuration key =Engine=;
   * reading =FOSWIKI_ENGINE= environment variable
   * loading all engines defined by =EngineList= configuration key and calling
     their =probe()= static method;
   * assuming that if no engine has been detected then CLI must be used.

=cut

sub start {
    my %params = @_;

    my $app = $params{app};
    my $cfg = $app->cfg;
    my $env = $app->env;
    my $engine;
    $engine //= $cfg->data->{Engine};
    $engine //= $ENV{FOSWIKI_ENGINE};
    unless ( defined $engine ) {
        foreach my $shortName ( @{ $cfg->data->{EngineList} } ) {
            my $engMod = "Foswiki::Engine::$shortName";

            $engMod = $app->extMgr->mapClass($engMod);

            # Do not catch errors here because engines have to be impeccable.
            # Nothing is allowed to fail.
            Foswiki::load_package( $engMod, method => 'probe' );
            my $probe = $engMod->can('probe');
            if ( $probe->(%params) ) {
                $engine = $engMod;
                last;
            }
        }
    }

    if ($engine) {
        Foswiki::load_class($engine);
        return $app->create( $engine, %params );
    }
    else {
        return undef;
    }
}

=begin TML

---++ ObjectMethod prepareConnection

Initializer method of =connectionData= attribute.

=cut

# SMELL Must be non-private as well as other initializers.
sub prepareConnection { }

# Initializer for queryParameters attribute.
sub prepareQueryParameters {
    my $this = shift;
    my ($queryString) = @_;

    # Shall be able to cover most HTTP environments.
    $queryString //= $this->env->{QUERY_STRING} || ''
      if $this->HTTPCompliant;

    my @pairs = split /[&;]/, $queryString;
    my ( $param, $value, %params, @plist );
    foreach my $pair (@pairs) {
        ( $param, $value ) = split( '=', $pair, 2 );

        if ( defined $param ) {
            if ( defined $value ) {
                $value =~ tr/+/ /;
                $value = NFC( Foswiki::urlDecode($value) );
            }
            $param =~ tr/+/ /;
            $param = NFC( Foswiki::urlDecode($param) );
            push @plist, { -name => $param, -value => $value };
        }
    }
    return \@plist;
}

=begin TML

---++ ObjectMethod prepareHeaders

Abstract initializer for the =headers= object attribute.

=cut

sub prepareHeaders { return {}; }

=begin TML

---++ ObjectMethod prepareUser

Initializer for the =user= object attribute.

Returns =$req= - Foswiki::Request object, populated with the action and the path.

=cut

sub prepareUser { return shift->env->{REMOTE_USER}; }

=begin TML

---++ ObjectMethod preparePostData

Abstract initializer for the =postData= object attribute.

=cut

sub preparePostData { }

=begin TML

---++ ObjectMethod preparePath( )

Initializer method of =pathData=.

=cut

sub preparePath { }

# Abstract initializer for bodyParameters
sub prepareBodyParameters { return []; }

=begin TML

---++ ObjectMethod prepareUploads( )

Abstract method, must be defined by inherited classes.

Implementations must convert upload names to unicode.

=cut

# Abstract initializer for uploads
sub prepareUploads { return []; }

=begin TML

---++ ObjectMethod stringifyHeaders(\@psgiReturnArray) -> $headersText

Converts headers from PSGI format to string in HTTP response format.

=cut

sub stringifyHeaders {
    my $this = shift;
    my ($return) = @_;

    my $CRLF    = "\x0D\x0A";
    my $headers = '';

    for ( my $i = 0 ; $i < scalar( @{ $return->[1] } ) ; $i += 2 ) {
        my ( $hdr, $val ) = @{ $return->[1] }[ $i, $i + 1 ];
        $headers .= $hdr . ': ' . Foswiki::encode_utf8($val) . $CRLF;
    }

    return $headers . $CRLF;
}

=begin TML

---++ ObjectMethod stringifyBody(\@psgiReturnArray) -> $bodyText

=cut

sub stringifyBody {
    my $this = shift;
    my ($return) = @_;

    return join( '', @{ $return->[2] } );
}

#=begin TML
#
#---++ ObjectMethod _writeBody( $body )
#
#   * =$body= - the third element of PSGI return array
#
#Should send response body to client. This method calls =write()=
#as needed, so engines should redefine that method insted of this one.
#
#=cut

sub _writeBody {
    my $this = shift;
    my ($body) = @_;
    return unless defined $body;
    if ( Scalar::Util::blessed($body) && $body->can('read')
        or ref $body eq 'GLOB' )
    {
        while ( !eof $body ) {
            read $body, my $buffer, 4096;
            last unless $this->write($buffer);
        }
        close $body;
    }
    else {
        $this->write($body);
    }
}

=begin TML

---++ ObjectMethod finalizeReturn(\@rc) -> $rc

Abstract method, must be defined by inherited classes.

   * =@rc= - 3-element array as defined by PSGI spec.

This method must process supplied =@rc= array in correspondance to current
environment requirements and return the value which will become the
application's return value. For PSGI it would return @rc itself; for CGI – shell
exit code; and so on.
   
=cut

sub finalizeReturn {
    ASSERT( __PACKAGE__
          . '::finalizeReturn is a pure virtual method - should never be called'
    );
}

=begin TML

---++ ObjectMethod write( $buffer )

Abstract method, must be defined by inherited classes.
   * =$buffer= - chunk of data to be sent

Should send $buffer to client.

=cut

sub write {
    ASSERT( __PACKAGE__
          . '::write is a pure virtual method - should never be called' );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This module is based/inspired on Catalyst framework. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
for credits and liscence details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
