# See bottom of file for license and copyright information

package Foswiki::Exception;

=begin TML

---+ Class Foswiki::Exception

Base class for all Foswiki exceptions.

Basic principles behind exceptions:

   1 Exceptions are using =CPAN:Try::Tiny=. Use of =CPAN:Error= module is no
   longer recommended.
   1 Exception classes are inheriting from =Foswiki::Exception=.
   1 =Foswiki::Exception= is an integral part of Fowiki's OO system and
   inherits from =%PERLDOC{Foswiki::Object}%=.
   1 =Foswiki::Exception= is utilizing =CPAN:Throwable= role. Requires the
   module to be installed.
   1 Exception classes inheritance shall form a tree of relationships for
   fine-grained error hadling.
   
The last item might be illustrated with the following expample (for inherited
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

This example is not proposed for implementation as hierarchy of exceptions has
to be thought out based on many factors. It would be reasonable to consider
splitting Oops exception into a fatal and non-fatal variants, for example.

---++ Notes on Try::Tiny

Unlike =CPAN:Error=, =CPAN:Try::Tiny= doesn't support catching of exceptions
based on their respective classes. It has to be done manually.

Alternatively =CPAN:Try::Tiny::ByClass= might be considered. It adds one more
dependency of =CPAN:Dispatch::Class= module.

One more alternative is =CPAN:TryCatch= but it is not found neither in MacPorts,
nor in Ubuntu 15.10 repository, nor in CentOS. Though it is a part of FreeBSD
ports tree.

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

---++ ATTRIBUTES

=cut

=begin TML

---+++ ObjectAttribute file

Name of the file where the exception has been raised as returned by the =caller=
funtion.

=cut

has file => (
    is        => 'rwp',
    predicate => 1,
);

=begin TML

---+++ ObjectAttribute line

Number of the line in the source file where the exception has been raised as
returned by the =caller= funtion.

=cut

has line => (
    is        => 'rwp',
    predicate => 1,
);

=begin TML

---+++ ObjectAttribute text

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

---+++ ObjectAttribute object

Might be set by the object which generated the exception to inidicate the source
of problem.

=cut

has object => ( is => 'ro', );

=begin TML

---+++ ObjectAttribute stacktrace

Contains full stack trace if =DEBUG= is =TRUE=. The trace includes calls to
=Foswiki::Exception= methods too to provide as much information for tracing down
errors as possible.

=cut

has stacktrace => (
    is        => 'rwp',
    predicate => 1,
);

=begin TML

---++ METHODS

=cut

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

=begin TML

---+++ ObjectMethod stringifyPostfix

Returns postfix that will be appended to the main exception message. In
=DEBUG= mode returns stacktrace stored in the
%PERLDOC{"Foswiki::Exception" attr="stacktrace"}% attribute; otherwise it is
filename and line only.

=cut

sub stringifyPostfix {
    my $this = shift;
    return (
        DEBUG
        ? "\n" . $this->stacktrace
        : ' at ' . $this->file . ', line ' . $this->line
    );
}

=begin TML

---+++ ObjectMethod stringifyText

Returns stringified main exception message –
%PERLDOC{"Foswiki::Exception" attr="text"}% attribute.

=cut

sub stringifyText {
    my $this = shift;
    return $this->text;
}

=begin TML

---+++ ObjectMethod stringify

Stringifies exception into a readable message. The message is a concatenation
of stringifyText() and stringifyPostfix() methods.

=cut

sub stringify {
    my $this = shift;

    return $this->stringifyText . $this->stringifyPostfix;
}

=begin TML

---+++ ObjectMethod to_str

Overrides %PERLDOC{"Foswiki::Object" method="to_str"}%.

=cut

around to_str => sub {
    my $orig = shift;
    my $this = shift;

    my $boundary = '-' x 60;
    my $msg      = join( "\n",
        $boundary, map( { "    " . $_ } split /\n/, $this->stringify ),
        $boundary );
    return $msg;
};

=begin TML

---+++ ObjectMethod TO_JSON

On a very rare occasion an exception object could be returned to a JsonRPC
caller. Though such situation resulting from a bug this method would simplify
catching and fixing the problem.

=cut

sub TO_JSON {
    my $this = shift;
    return $this->stringify;
}

=begin TML

---+++ ClassMethod rethrow($class [, $exception[, %params]])

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

---+++ ClassMethod rethrowAs($class, $exception[, %params])

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

---+++ ClassMethod transmute($class, $exception, $enforce) => $exceptionObject

Reinstantiates $exception into $class.

If =$enforce= is *FALSE* and =$exception= is a =Foswiki::Exception=
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

---+++ StaticMethod errorStr($error)

Converts $error into a text message by trying to determine error or exception
type and properly transform it into a string.

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

=begin TML

---+++ ObjectMethod prepareText

Initializer for %PERLDOC{"Foswiki::Exception" attr="text"}% attribute.
Inheriting exception class must override this method if text can be
autogenerated from other exception data.

=cut

sub prepareText {
    my $this = shift;
    return "text attribute hasn't been set";
}

use Foswiki;
for my $m (qw<Ext ASSERT Fatal FileOp HTTPResponse HTTPError Engine ModLoad>) {
    Foswiki::load_class( __PACKAGE__ . "::" . $m );
}

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
