# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Engine

The engine class is a singleton that implements details about Foswiki's
execution mode. This is the base class and implements basic behavior.

Each engine should inherits from this and overload methods necessary
to achieve correct behavior.

=cut

package Foswiki::Engine;
use v5.14;

use Try::Tiny;
use Assert;
use Scalar::Util ();
use Unicode::Normalize;

use Moo;
use namespace::clean;
extends qw(Foswiki::AppObject);

use constant HTTP_COMPLIANT => undef;    # This is a generic class.

has env => (
    is  => 'rw',
    isa => Foswiki::Object::isaHASH( 'env', noUndef => 1, ),
    default => sub { $_[0]->app->env },
);
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

---++ ObjectAttribute pathData

pathData attribute is a hash with the following keys: =action=, =path_info=, =uri=.

The =uri= key can be undef under certain circumstances.

=cut

has pathData => ( is => 'rw', lazy => 1, builder => '_preparePath', );

=begin TML

---++ ObjectAttribute connectionData

connectionData attribute is a hash with the following keys:

   * =remoteAddress=
   * =serverPort=
   * =method=
   * =secure=

=cut

has connectionData =>
  ( is => 'rw', lazy => 1, builder => '_prepareConnection', );

=begin TML

---++ ObjectAttribute queryParameters and bodyParameters

Parameter attributes are arrays of hashrefs with keys =-name= and =-value= where
the former is a plain string and the latter may be either a scalar or an
arrayref. In addition to those two =bodyParamaters= element hashref may contain
additional key =-upload= which value is boolean. 

=cut

has queryParameters =>
  ( is => 'rw', lazy => 1, builder => '_prepareQueryParameters', );
has bodyParameters =>
  ( is => 'rw', lazy => 1, builder => '_prepareBodyParameters', );

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

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML
---++ ClassMethod start(env => \%env)

Determines the type of environment we're running in and creates an instance of
corresponding class.

=cut

sub start {
    my %params = @_;

    my $cfg = $Foswiki::app->cfg;
    my $engine;
    if ( defined $cfg->data->{Engine} ) {
        $engine = $cfg->data->{Engine};
    }
    elsif ( $params{env}{GATEWAY_INTERFACE} || $params{env}{MOD_PERL} ) {
        $engine = 'Foswiki::Engine::CGI';
    }
    elsif ( $params{env}{'psgi.version'} ) {

        # SMELL TODO We don't have PSGI support yet.
        $engine = 'Foswiki::Engine::PSGI';
    }
    else {
        $engine = 'Foswiki::Engine::CLI';
    }

    if ($engine) {
        Foswiki::load_class($engine);
        return $engine->new(%params);
    }
    else {
        return undef;
    }
}

=begin TML

---++ ClassMethod new() -> $engine

Constructs an engine object.

=cut

=begin TML

---++ Obsolete ObjectMethod run()

Start point to Runtime Engines.

=cut

#sub run {
#    my $this = shift;
#    my $req  = $this->prepare();
#    if ( ref($req) ) {
#        my $res = Foswiki::UI::handleRequest($req);
#        $this->finalize( $res, $req );
#    }
#}

=begin TML

---++ Obsolete ObjectMethod prepare() -> $req

Initialize a Foswiki::Request object by calling many preparation methods
and returns it, or a status code in case of error.

=cut

sub prepare {
    my $this = shift;
    my $req;

    if ( $Foswiki::cfg{Store}{overrideUmask} && $Foswiki::cfg{OS} ne 'WINDOWS' )
    {

# Note: The addition of zero is required to force dirPermission and filePermission
# to be numeric.   Without the additition, certain values of the permissions cause
# runtime errors about illegal characters in subtraction.   "and" with 777 to prevent
# sticky-bits from breaking the umask.
        my $oldUmask = umask(
            (
                oct(777) - (
                    (
                        $Foswiki::cfg{Store}{dirPermission} + 0 |
                          $Foswiki::cfg{Store}{filePermission} + 0
                    )
                ) & oct(777)
            )
        );

#my $umask = sprintf('%04o', umask() );
#$oldUmask = sprintf('%04o', $oldUmask );
#my $dirPerm = sprintf('%04o', $Foswiki::cfg{Store}{dirPermission}+0 );
#my $filePerm = sprintf('%04o', $Foswiki::cfg{Store}{filePermission}+0 );
#print STDERR " ENGINE changes $oldUmask to  $umask  from $dirPerm and $filePerm \n";
    }

    try {
        $req = $this->create('Foswiki::Request');
        $this->prepareHeaders($req);
        $this->prepareCookies($req);
        $this->prepareBody($req);
        $this->prepareUploads($req);
    }
    catch {
        # SMELL returns within Try::Tiny try/catch block doesn't return from the
        # calling sub but from the try/catch block itself.
        my $e = $_;
        unless ( ref($e) ) {
            Foswiki::Exception::Fatal->rethrow($e);
        }

        if (   $e->isa('Foswiki::EngineException')
            || $e->isa('Foswiki::Exception::Engine') )
        {
            my $res = $e->response;
            unless ( defined $res ) {
                $res = Foswiki::Response->new;
                $res->header( -type => 'text/html', -status => $e->status );
                my $html = CGI::start_html( $e->status . ' Bad Request' );
                $html .= CGI::h1( {}, 'Bad Request' );
                $html .= CGI::p( {}, $e->reason );
                $html .= CGI::end_html();
                $res->print($html);
            }
            $this->finalizeError( $res, $req );
            return $e->status;
        }
        else {    # Not Foswiki::EngineException
            my $res = Foswiki::Response->new();
            my $mess =
                $e->can('stringify')
              ? $e->stringify()
              : 'Unknown ' . ref($e) . ' exception: ' . $@;
            $res->header( -type => 'text/plain', -status => '500' );
            if (DEBUG) {

                # output the full message and stacktrace to the browser
                $res->print($mess);
            }
            else {
                print STDERR $mess;

                # tell the browser where to look for more help
                my $text =
'Foswiki detected an internal error - please check your Foswiki logs and webserver logs for more information.'
                  . "\n\n";
                $mess =~ s/ at .*$//s;

                # cut out pathnames from public announcement
                $mess =~ s#/[\w./]+#path#g;
                $text .= $mess;
                $res->print($text);
            }
            $this->finalizeError( $res, $req );
            return 500;    # Internal server error
        }
    };
    return $req;
}

=begin TML

---++ ObjectMethod _prepareConnection

Initializer method of =connectionData= attribute.

=cut

sub _prepareConnection { }

# Initializer for queryParameters attribute.
sub _prepareQueryParameters {
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

---++ ObjectMethod prepareHeaders( $req )

Abstract method, must be defined by inherited classes.
   * =$req= - Foswiki::Request object to populate

Should fill $req's headers and remoteUser fields.

=cut

sub prepareHeaders { }

=begin TML

---++ ObjectMethod _preparePath( )

Initializer method of =pathData=.

=cut

sub _preparePath { }

=begin TML

---++ ObjectMethod prepareCookies( $req )

   * =$req= - Foswiki::Request object to populate

Should fill $req's cookie field. This method take cookie data from
previously populated headers field and initializes from it. Maybe 
doesn't need to overload in children classes.

=cut

sub prepareCookies {
    my ( $this, $req ) = @_;
    eval { require CGI::Cookie };
    Foswiki::Exception::Fatal->throw( text => $@ ) if $@;
    $req->cookies( scalar( CGI::Cookie->parse( $req->header('Cookie') ) ) )
      if $req->header('Cookie');
}

# Abstract initializer for bodyParameters
sub _prepareBodyParameters { return []; }

=begin TML

---++ ObjectMethod prepareUploads( $req )

Abstract method, must be defined by inherited classes.
   * =$req= - Foswiki::Request object to populate

Should fill $req's {uploads} field. This is a hashref whose keys are
upload names and values Foswiki::Request::Upload objects.

Implementations must convert upload names to unicode.

=cut

sub prepareUploads { }

=begin TML

---++ ObjectMethod finalize($res, $req)

Finalizes the request by calling many methods to send response to client and 
take any appropriate finalize actions, such as delete temporary files.
   * =$res= is the Foswiki::Response object
   * =$req= it the Foswiki::Request object.

=cut

sub finalize {
    my ( $this, $res, $req ) = @_;
    if ( $res->outputHasStarted() ) {
        $this->flush( $res, $req );
    }
    else {
        $this->finalizeUploads( $res, $req );
        $this->finalizeHeaders( $res, $req );
        $this->finalizeBody($res);
    }
}

=begin TML

---++ ObjectMethod finalizeUploads( $res, $req )

Abstract method, must be defined by inherited classes.
   * =$res= - Foswiki::Response object to get data from
   * =$req= - Foswiki::Request object to get data from

Should delete any temp files created in preparation phase.

=cut

sub finalizeUploads { }

=begin TML

---++ ObjectMethod finalizeError( $res, $req )

Called if some engine specific error happens.

   * =$res= - Foswiki::Response object to get data from
   * =$req= - Foswiki::Request object to get data from

=cut

sub finalizeError {
    my ( $this, $res, $req ) = @_;
    $this->finalizeHeaders( $res, $req );
    $this->finalizeBody( $res, $req );

    # Item12590: prevent duplicated output by later call to finalize()
    $res->body('');
    $res->outputHasStarted(1);
}

=begin TML

---++ ObjectMethod finalizeHeaders( $res, $req )

Base method, must be redefined by inherited classes. For convenience
this method deals with HEAD requests related stuff. Children classes
should call SUPER.
   * =$res= - Foswiki::Response object to get data from
   * =$req= - Foswiki::Request object to get data from

Should call finalizeCookies and then send $res' headers to client.

=cut

sub finalizeHeaders {
    my ( $this, $res, $req ) = @_;
    $this->finalizeCookies($res);
    if ( $req && $req->method() && uc( $req->method() ) eq 'HEAD' ) {
        $res->body('');
        $res->deleteHeader('Content-Length');
    }
}

=begin TML

---++ ObjectMethod finalizeCookies( $res )

   * =$res= - Foswiki::Response object to both get data from and populate

Should populate $res' headers field with cookies, if any.

=cut

sub finalizeCookies {
    my ( $this, $res ) = @_;

    # SMELL: Review comment below, from CGI:
    #    if the user indicates an expiration time, then we need
    #    both an Expires and a Date header (so that the browser is
    #    uses OUR clock)
    $res->pushHeader( 'Set-Cookie',
        Scalar::Util::blessed $_
          && $_->isa('CGI::Cookie') ? $_->as_string : $_ )
      foreach $res->cookies;
}

=begin TML

---++ ObjectMethod finalizeBody( $res, $req )

   * =$res= - Foswiki::Response object to get data from
   * =$req= - Foswiki::Request object to get data from

Should send $res' body to client. This method calls =write()=
as needed, so engines should redefine that method insted of this one.

=cut

sub finalizeBody {
    my ( $this, $res, $req ) = @_;
    my $body = $res->body;
    return unless defined $body;
    $this->prepareWrite($res);
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

---++ flush($res, $req)

Forces the response headers to be emitted if they haven't already been sent
(note that this may in some circumstances result in cookies being missed)
before flushing what is in the body so far.

Before headers are sent, any Content-length is removed, as a call to
flush is a statement that there's more to follow, but we don't know
how much at this point.

This function should be used with great care! It requires that the output
headers are fully complete before it is first called. Once it *has* been
called, the response object will refuse any modifications that would alter
the header.

=cut

sub flush {
    my ( $this, $res, $req ) = @_;

    unless ( $res->outputHasStarted() ) {
        $res->deleteHeader('Content-Length');
        $this->finalizeUploads( $res, $req );
        $this->finalizeHeaders( $res, $req );
        $this->prepareWrite($res);
        $res->outputHasStarted(1);
    }

    my $body = $res->body();

    if ( Scalar::Util::blessed($body) || ref($body) eq 'GLOB' ) {
        throw Foswiki::EngineException('Cannot flush non-text response body');
    }

    $this->write($body);
    $res->body('');
}

=begin TML

---++ ObjectMethod prepareWrite( $res )

Abstract method, may be defined by inherited classes.
   * =$res= - Foswiki::Response object to get data from

Should perform any task needed before writing.
That's ok if none needed ;-)

=cut

sub prepareWrite { }

=begin TML

---++ ObjectMethod write( $buffer )

Abstract method, must be defined by inherited classes.
   * =$buffer= - chunk of data to be sent

Should send $buffer to client.

=cut

sub write {
    ASSERT('Pure virtual method - should never be called');
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
