# See bottom of file for license and copyright information

package Foswiki::Exception;
use v5.14;

=begin TML

---+ Class Foswiki::Exception

Base class for all Foswiki exceptions. This is still a concept only.

Basic principles behind exceptions:

   1. Exceptions are using =Try::Tiny=. Use of =CPAN:Error= module is no longer
      recommended.
   1. Exception classes are inheriting from =Foswiki::Exception=.
   1. =Foswiki::Exception= is an integral part of Fowiki's OO system and inheriting from =Foswiki::Object=.
   1. =Foswiki::Exception= is utilizing =Throwable= role. Requires this module to be installed.
   1. Exception classes inheritance shall form a tree of relationships for fine-grained error hadling.
   
The latter item might be illustrated with the following expample (for inherited
classes =Foswiki::Exception= prefix is skipped for simplicity though it is
recommended for code readability):

   * Foswiki::Exception
      * Core
        * Engine
        * CGI
      * Rendering
        * UI
        * Validation
        * Oops
           * Fatal

This example is not proposed for implementation as hierarchy is exceptions has to be thought out based on many factors.
It would be reasonable to consider splitting Oops exception into a fatal and non-fatal variants, for example.

---++ Notes on Try::Tiny

Unlike =CPAN:Error=, =CPAN:Try::Tiny= doesn't support catching of exceptions based on
their respective classes. It has to be done manually.

Alternatively =CPAN:Try::Tiny::ByClass= might be considered. It adds one more dependency
of =CPAN:Dispatch::Class= module.

One more alternative is =CPAN:TryCatch= but it is not found neither in MacPorts,
nor in Ubuntu 15.10 repository, nor in CentOS. Though it is a part of FreeBSD ports tree.
=cut

use Assert;
use Data::Dumper;
use Try::Tiny;
use Carp         ();
use Scalar::Util ();

use Foswiki::Class;
extends qw(Foswiki::Object);
with 'Throwable';

our $EXCEPTION_TRACE = 0;

=begin TML

---++ ObjectAttribute file

Name of the file where the exception has been raised as returned by the =caller=
funtion.

=cut

has file => (
    is        => 'rwp',
    predicate => 1,
);

=begin TML

---++ ObjectAttribute line

Number of the line in the source file where the exception has been raised as
returned by the =caller= funtion.

=cut

has line => (
    is        => 'rwp',
    predicate => 1,
);

=begin TML

---++ ObjectAttribute text

Simple text explaining what's went wrong. Must always be set to something
meaningful. If a child class doesn't expect this attribute to be set by the code
throwing the exception then it must generate it using other attributes.

=cut

has text => (
    is        => 'rwp',
    lazy      => 1,
    builder   => 'prepareText',
    clearer   => 1,
    predicate => 1,
);

=begin TML

---++ ObjectAttribute object

Might be set by the object which generated the exception to inidicate the source
of problem.

=cut

has object => ( is => 'ro', );

=begin TML

---++ ObjectAttribute stacktrace

Contains full stack trace if =DEBUG= is =TRUE=. The trace includes calls to
=Foswiki::Exception= methods too to provide as much information for tracing down
errors as possible.

=cut

has stacktrace => (
    is        => 'rwp',
    predicate => 1,
);

sub BUILD {
    my $this = shift;

    unless ( $this->has_stacktrace ) {
        my $trace = Carp::longmess('');
        $this->_set_stacktrace($trace);
    }
    my ( undef, $file, $line ) = caller;
    $this->_set_file($file) unless $this->has_file;
    $this->_set_line($line) unless $this->has_line;
    $this->_set_text(
        ref($this)
          . " didn't set a meaningful error text in case it would be treated as a simple Foswiki::Exception"
    ) unless $this->text;

    state $tryLogging = 1;
    if (   $tryLogging
        && DEBUG
        && defined $Foswiki::app
        && $Foswiki::app->has_logger )
    {

        # Do our best to log this exception. Though the logging process is
        # pretty much complicated and may generate an exception any time;
        # especially in debug mode. In such a case we shall just suppress any
        # extra exception.
        local $SIG{__DIE__};
        local $SIG{__WARN__};
        try {
            # If a Foswiki::Exception gets thrown make sure we don't go into
            # recursion.
            $tryLogging = 0;
            $Foswiki::app->logger->log( 'debug', $this->stringify, );
            $tryLogging = 1;
        };
    }

    say STDERR "New exception object created: ", $this->stringify
      if DEBUG && $EXCEPTION_TRACE;
}

sub stringifyPostfix {
    my $this = shift;
    return (
        DEBUG
        ? "\n" . $this->stacktrace
        : ' at ' . $this->file . ' line ' . $this->line
    );
}

sub stringifyText {
    my $this = shift;
    my $text = shift;
    return $text;
}

sub stringify {
    my $this = shift;

    return $this->stringifyText( $this->text ) . $this->stringifyPostfix;
}

around to_str => sub {
    my $orig = shift;
    my $this = shift;

    my $boundary = '-' x 60;
    my $msg      = join( "\n",
        $boundary, map( { "    " . $_ } split /\n/, $this->stringify ),
        $boundary );
    return $msg;
};

# We must not get into this. But if we do then let's not hide a error but let it
# thru to the end user via JsonRPC interfaces.
sub TO_JSON {
    my $this = shift;
    return $this->stringify;
}

=begin TML

---++ ClassMethod rethrow($class [, $exception[, %params]])

Receives any exception class or a error text and rethrows it as an
Foswiki::Exception descendant. $class specifies the final class of rethrown
exception.

=$e->rethrow=, where =$e->isa('Foswiki::Exception')= is no different
of =$e->throw= and might be used for readability. In this case any additional
parameters to =rehrow()= except of $class are ignored.

Examples:

<verbatim>
# Rethrow synax error as Foswiki::Exception::Fatal
eval "bad perl code";
Foswiki::Exception::Fatal->rethrow($@) if $@;

# Propagate a caught exception thrown in try block.
try {
    ...
}
catch {
    if ($_->isa('Foswiki::Exception')) {
        $_->rethrow;
        # Note that:
        #
        # $_->rethrow( text => "Try to override error text" );
        #
        # is no different of the uncommented code.
    }
    # Any other kind of exception is converted into
    # Foswiki::Exception::SomeOtherException and propagaded.
    Foswiki::Exception::SomeOtherException->rethrow(
        $_,
        someParam => 'Has value',
    );
}

</verbatim>

=cut

sub rethrow {
    my $class = shift;

    if ( ref($class) && $class->isa('Foswiki::Exception') ) {

        # Never call transmute on a Foswiki::Exception descendant because this
        # is not what is expected from rethrow.
        $class->throw;
    }

    my $e = shift;

    $class->transmute( $e, 0, @_ )->throw;
}

=begin TML

---++ ClassMethod rethrowAs($class, $exception[, %params])

Similar to the =rethrow()= method but always reinstantiates $exception into
$class using =transmute()=. Note that if =%params= are defined and =$exception=
is a =Foswiki::Exception= descendant then they will override =$exception= object
attributes unless =$exception= class is equal to =$class=.

=cut

sub rethrowAs {
    my $class = shift;
    my $e     = shift;
    $class->transmute( $e, 1, @_ )->throw;
}

=begin TML

---++ ClassMethod transmute($class, $exception, $enforce) => $exceptionObject

Reinstantiates $exception into $class.

If =$enforce= is *FALSE* and =$exception='s class is a =Foswiki::Exception=
descendant then no action would be taken. If =$enforce= is true then no matter
what the =$exception= type is - it would be coerced into =$class=.

=transmute()= will do its best while trying to find a best way to convert =$exception= and use whatever method is possible:

   * Check if =$exception= is a deprecated =Error= thrown by some old-style Foswiki code.
   * Check if =$exception= is an object and can do =stringify()= or =as_text()= methods in the order thet mentioned here.
   * Simply use =Data::Dumper= to provide user with as much information about what's went wrong as possible.

=cut

sub transmute {
    my $class   = shift;
    my $e       = shift;
    my $enforce = shift;

    $class = ref($class) if ref($class);
    ASSERT( $class->isa('Foswiki::Exception'),
        "Bad destination exception type $class for transmuting" )
      if DEBUG;
    if ( ref($e) ) {
        if ( $e->isa('Foswiki::Exception') ) {
            if ( !$enforce || $e->isa($class) ) {
                return $e;
            }
            return $class->new( %$e, @_ );
        }
        elsif ( $e->isa('Error') ) {
            return $class->new(
                text       => $e->text,
                line       => $e->line,
                file       => $e->file,
                stacktrace => $e->stacktrace,
                object     => $e->object,
                @_,
            );
        }

        # Wild cases of non-exception objects. Generally it's a serious bug but
        # we better try to provide as much information on what's happened as
        # possible.
        elsif ( $e->can('stringify') ) {
            return $class->new(
                text => "(Exception from stringify() method of "
                  . ref($e) . ") "
                  . $e->stringify,
                @_
            );
        }
        elsif ( $e->can('as_text') ) {
            return $class->new(
                text => "(Exception from as_text() method of "
                  . ref($e) . ") "
                  . $e->as_text,
                @_
            );
        }
        else {
            # Finally we're no idea what kind of a object has been thrown to us.
            return $class->new(
                text => "Unknown class of exception received: "
                  . ref($e) . "\n"
                  . Dumper($e),
                @_
            );
        }
    }
    return $class->new( text => $e, @_ );
}

=begin TML

---++ StaticMethod errorStr($error)

Gets a error in $error and converts it into a text message by trying to
determine error type and properly stringify it.

=cut

sub errorStr {
    my ($err) = @_;

    my $str = $err;

    if ( ref($err) ) {
        if ( Scalar::Util::blessed($err) ) {
            if ( $err->can('stringify') ) {
                $str = $err->stringify;
            }
            elsif ( $err->can('text') ) {
                $str = $err->text;
            }
            else {
                $str =
                    "Error object of type "
                  . ref($err)
                  . " doesn't support stringification.";
            }
        }
        else {
            $str =
                "Cannot convert "
              . ref($err)
              . " reference into a meaningful error message.";
        }
    }
    return $str;
}

# A child exception class must override this method if text can be autogenerated
# from other exception data.
sub prepareText {
    my $this = shift;
    return "text attribute hasn't been set";
}

package Foswiki::Exception::Harmless;
use Foswiki::Class;
extends qw(Foswiki::Exception);

# For informational exceptions.

package Foswiki::Exception::Fatal;
use Assert;
use Foswiki::Class;
extends qw(Foswiki::Exception);

#sub BUILD {
#    my $this = shift;
#
#    say STDERR $this->stringify, $this->stacktrace if DEBUG;
#}

# To cover perl/system/core errors.

package Foswiki::Exception::ASSERT;
use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);

# This class is only for distinguishing ASSERT-generated exceptions.

=begin TML

---++ Exception Foswiki::Exception::FileOp

Base exception for failed file operations.

Attributes:

| *Name* | *Description* | *Required* |
| =file= | File name | _yes_ |
| =op= | Operation caused the failure, single verb like 'read' | _yes' |

=cut

package Foswiki::Exception::FileOp;
use Foswiki::Class;
extends qw(Foswiki::Exception::Fatal);

has file  => ( is => 'rw', required => 1, );
has op    => ( is => 'rw', required => 1, );
has errno => ( is => 'rw', builder  => 'prepareErrno', );

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    return
        "Failed to "
      . $this->op
      . " file "
      . $this->file . ": "
      . $orig->($this);
};

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return $!;    # text attribute to be set from last file operation error.
};

sub prepareErrno {
    return int($!);
}

=begin TML

---+ Exception Foswiki::Exception::HTTPResponse

Used to send HTTP status responses to the user.

Attributes:

   * =status= - HTTP status code, integer; response status code used if omitted.
   * =response= - a Foswiki::Response object. If not supplied then the default from $Foswiki::app->response is used.
   * =text= – read-only, generated using the exception attributes.

=cut

package Foswiki::Exception::HTTPResponse;
use Foswiki::Class;
extends qw(Foswiki::Exception);

has status =>
  ( is => 'ro', lazy => 1, default => sub { $_[0]->response->status, }, );
has response => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return defined($Foswiki::app)
          ? $Foswiki::app->response
          : Foswiki::Response->new;
    },
);

# SMELL To be replaced by prepareText() overriding.
has '+text' => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return 'HTTP status code "' . $_[0]->status;
    },
);

sub _useHTTP {
    my $this = shift;
    return
         defined($Foswiki::app)
      && defined( $Foswiki::app->engine )
      && $Foswiki::app->engine->HTTPCompliant;
}

# Simplified version of stringify() method.
around stringify => sub {
    my $orig = shift;
    my $this = shift;

    my $str = '';
    if ( $this->_useHTTP ) {
        $str .= $this->response->printHeaders;
    }

    $str .= $this->response->body;

    return $str;
};

package Foswiki::Exception::HTTPError;

use CGI ();
use Assert;

use Foswiki::Class;
extends qw(Foswiki::Exception::HTTPResponse);

has header => ( is => 'rw', default => '' );

around stringify => sub {
    my $orig = shift;
    my $this = shift;

    my $res = $this->response;
    $res->body('');
    if ( $this->_useHTTP ) {
        $res->header( -type => 'text/html', -status => $this->status );
        my $html = CGI::start_html( $this->status . ' ' . $this->header );
        $html .= CGI::h1( {}, $this->header );
        $html .= CGI::p( {}, $this->text );
        $html .= CGI::p( {}, CGI::pre( $this->stacktrace ) ) if DEBUG;
        $html .= CGI::end_html();
        $res->print($html);
    }
    else {
        $res->print( $this->status . " "
              . $this->header . "\n\n"
              . $this->text
              . $this->stringifyPostfix );
    }

    return $orig->($this);
};

=begin TML
---++ Exception Foswiki::Exception::Engine

Descendant of =Foswiki::Exception::HTTPResponse=.

Attributes:

   * =reason= - reason text, required
   * =text= – read-only, generated using the exception attributes.

=cut

package Foswiki::Exception::Engine;
use Foswiki::Class;
extends qw(Foswiki::Exception::HTTPError);

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;

    $params{status} //= 500;
    $params{header} //= 'Internal Server Error';

    # Simulate the old Foswiki::EngineException behavior.
    $params{text} //= $params{response}
      if defined $params{response};

    return $orig->( $class, %params );
};

package Foswiki::Exception::Ext;
use Foswiki::Class;
extends qw(Foswiki::Exception);

=begin TML
---++ package Foswiki::Exception::Ext

Base class for Foswiki::Extensions-related exceptions.

Generic. Must not be used directly.

=cut

=begin TML

---++ ObjectAttribute extension => string

Extension name.

=cut

has extension => (
    is        => 'ro',
    predicate => 1,

    # Coerce a ref into class name.
    coerce => sub { ref( $_[0] ) // $_[0] },
);

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return $this->has_extension
      ? "Reported extension: " . $this->extension
      : "No reported extension";
};

package Foswiki::Exception::Ext::BadName;
use Foswiki::Class;
extends qw(Foswiki::Exception::Ext);

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return "Bad extension name: '" . $this->extension . "'";
};

package Foswiki::Exception::Ext::Load;
use Foswiki::Class;
extends qw(Foswiki::Exception::Ext);

has reason => (
    is       => 'rw',
    required => 1,
);

around prepareText => sub {
    my $orig = shift;
    my $this = shift;

    return
        "Failed to load extension '"
      . $this->extension . "': "
      . $this->reason;
};

package Foswiki::Exception::Ext::Flow;
use Foswiki::Class;
extends qw(Foswiki::Exception::Ext);

=begin TML

---+ package Foswiki::Exception::Ext::Flow

Base class of extension flow control events. Pure virtual, makes no sense on its
own.

=cut

package Foswiki::Exception::Ext::Last;
use Foswiki::Class;
extends qw(Foswiki::Exception::Ext::Flow);

=begin TML

---+ package Foswiki::Exception::Ext::Last

Subclass of =Foswiki::Exception::Ext::Flow=.

Inidicates that an extension is requesting to be the last in the execution line.

=cut

=begin TML

---++ ObjectAttribute rc

Return value of a method call.

=cut

has rc => ( is => 'rw', predicate => 1, );

package Foswiki::Exception::Ext::Restart;
use Foswiki::Class;
extends qw(Foswiki::Exception::Ext::Flow);

=begin TML

---+ package Foswiki::Exception::Ext::Restart

Subclass of =Foswiki::Exception::Ext::Flow=.

Inidicates that an extensions is requesting the execution line to be restarted
from the beginning. Calling parameters would be preserved in their state at the
moment when this exception was raised.

Highly experimental feature. Might be removed upon consideration.

=cut

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2016 Foswiki Contributors. Foswiki Contributors
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
