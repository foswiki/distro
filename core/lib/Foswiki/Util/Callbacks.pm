# See bottom of file for license and copyright information

package Foswiki::Util::Callbacks;
use v5.14;

=begin TML

---+!! Role Foswiki::Util::Callbacks

Support of callbacks for classes which need them.

---++ SYNOPSIS

<verbatim>
package Foswiki::CBSample;

use Foswiki::Class qw<callbacks>;
extends qw<Foswiki::Object>;

__PACKAGE__->registerCallbackNames( qw<sampleCB1 sampleCB2> );

sub aMethod {
    my $this = shift;
    
    ...
    
    my $cbParams = {
        arg1 => $aScalar,
        arg2 => \%aHash,
    };
    
    $this->callback( sampleCB1 => $cbParams );
    
    if ( defined $cbParams->{rc} ) {
        say "Received a message for callback handler: ", $cbParams->{rc}{msg};
    }
    
    ...
}

</verbatim>

<verbatim>
package Foswiki::Util::UserModule;

use Scalar::Util qw<weaken>;

use Foswiki::Class qw<callbacks>;
extends qw<Foswiki::Object>;

sub BUILD {
    my $this = shift;
    
    my $cbData = {
        this => $this,  
    };
    
    weaken( $cbData->{this} );
    
    $this->registerCallback( 'Foswiki::CBSample::sambleCB1', $cbData );
}

sub DEMOLISH {
    my $this = shift;
    
    $this->deregisterCallback( 'Foswiki::CBSample::sambleCB1' );
}

sub cbHandler {
    my $obj = shift;
    my %args = @_;
    my $this = $args{data}{this};
    
    $args{params}{rc}{msg} = "Hello from cbHandler!";
}

</verbatim>

---++ DESCRIPTION

Read about [[%SYSTEMWEB%.CallbacksFramework][callbacks basics]] first.

---+++ Components

Callback as a phenomenon consists of:

   $ Name : unique identifier
   $ Caller or calling object : instance of a class with this role applied which
   executes the callback
   $ Callee or callback handler : a code which is called when callback is
   executed

Name uniquely identifies callback. It is composed of a namespace and a short
name joined together by double colon (_::_). By default the namespace is the
module name where the callback is been registered. For example, =Foswiki::App=
registers a callback by its short name =postConfig=. In this case the full name
is =Foswiki::App::postConfig=.

Whenever the namespace is guessable the short name only could be used. So, when
=Foswiki::App= is executing =postConfig= it can do it by with the following
code:

<verbatim>
$this->callback( 'postConfig', $params );
</verbatim>

The namespace is then guessed by the =callback()= method using caller's package
name.

Similarly to this a client registering a callback handler may use a short name.
Though this would work exclusively if the short name is unique among all
namespaces. Otherwise an exception will be raised.

Callback handler is a coderef (a sub) which gets called when the callback is
executed. The handler sub receives the following arguments:

   1 Reference to the calling object.
   1 A list of key/value parameters.
      
Parameter keys are:

| *Key* | *Description* |
| =data= | User data if supplied by the object which has registered this\
           callback handler. Data format determined by the registering object. |
| =params= | Parameteres supplied by the calling object. Must be a hashref.\
             Keys of the hash are defined by the calling class and must be\
             documented. The only key which is reserved for the internal use \
             is _.cbData_. |

A sample callback handler is demonstrated in SYNOPSIS above. Note that =$obj= in
the example is the calling object while =$this= points to the callee object.

%X% It is worth paying special attention to the =weaken()= call. It prevents a
memory leak where the callee object is never destroyed. This happens because
storing =$this= in =$cbData= increases its reference count. =$cbData= is then
stored by the callbacks framework in a permanent storage (see Internals section
below) where it rests until =deregisterCallback()= cleans up the handler
registration. And here comes the 'oops' because deregistration takes place in
the object destructor and it will never get called because the object is still
references from the stored =$cbData=! Weaking of =this= key in =$cbData= breaks
this circular dependency (read about weak references in CPAN:perlref).
      
A named callback may have more than one handler. In this case all handlers are
executed in the order they were registerd. Their return values are ignored.
If a handler wants to be the last in the calling sequence it must raise
=Foswiki::Exception::Ext::Last= exception. If set, exception's =rc= attribute
contains what is returned by =callback()= method then.

%X% *NOTE:* Read about
[[%SYSTEMWEB%.ChainedExecutionFlow][chained execution flow]].

If a callback handler raises any other exception besides of
=Foswiki::Exception::Ext::*= then that exception is rethrown further up the call
stack.

A sample callback handler utilizing exceptions may look like this:

<verbatim>
sub cbHandler {
    my $obj = shift;
    my %args = @_;
    
    my $this = $args{data}{this};
    
    my $rc;
    
    ... # Do something.
    
    if ($errorHappened) {
        Foswiki::Exception::Fatal->throw( text => "That's bad!" );
    }
    
    # Assuming that $rc might have been set by the code hidden under the '...'
    # statement:
    if (defined $rc) {
        Foswiki::Exception::Ext::Last->throw( rc => $rc );
    }
}
</verbatim>

---+++ Construction And Destruction

As a role, callbacks framework takes care of construction and destruction stages
of object's life cycle.

The construction stage is only relevant as =callbacksInit()= gets called. Note
that it happens _before_ the class' main =BUILD()= method is called. So, if
there is something your code must have done at the very early stage of object's
life then overriding the =callbacksInit()= method is the way to go.

What is more important is that the framework takes care of deregistering all
object's callback handlers. This is also done _before_ object's =DEMOLISH()=
method gets called.

---+++ Internals

The registration subsystem of callbacks requires some kind of permanent storage
to function correctly. 'Permanent' means here 'until the application object is
alive'. As long as the application object is the only entity which is guaranteed
to conform the requirement then its the best storage we can use for the purpose!
And since there is %PERLDOC{"Foswiki::App" attr="heap"}% attribute it is used to
keep callbacks data in =_aux_registered_callbacks= key.

   : <em>So, please, would you ever need the heap for something – leave the key
   alone, don't use it, don't change it's value! Callbacks framework would
   appreciate your udnerstanding!</em>
   
Because of the use of the application object it is strongly recommended for
the callbacks to be used by either classes with %PERLDOC{"Foswiki::AppObject"}%
role, or with %PERLDOC{"Foswiki::Class" anchor="extensible"}% *extensible*
modifier - read about the framework's
[[%SYSTEMWEB%.CallbacksFramework#Common_Principles][common principles]].
   
=cut

use Assert;
use Try::Tiny;
use Scalar::Util qw(weaken);

# Hash of registered callback names in a form of:
# $_registeredNames{'Foswiki::NameSpace'}{callbackName} = 1;
my %_registeredCBNames;
my %_cbNameIndex;

use Moo::Role;

=begin TML

---++ METHODS

=cut

around BUILD => sub {
    my $orig = shift;
    my $this = shift;

    $this->callbacksInit;
    return $orig->( $this, @_ );
};

before DEMOLISH => sub {
    my $this = shift;
    my ($in_global) = @_;

    # Cleanup all callbacks registed by this object.
    unless ($in_global) {
        my $app = $this->guessApp;

        # The application object could have been already destroyed at this
        # moment. This is normal for auto-destruction.
        if ( defined $app ) {
            my $appHeap = $app->heap;

    # SMELL It's actually pretty slow way of doing the task. Needs optimization.
            foreach
              my $cbName ( keys %{ $appHeap->{_aux_registered_callbacks} } )
            {
                $this->deregisterCallback($cbName);
            }
        }

    }
};

# Splits full callback name into namespace and short name.
sub _splitCBName {
    my $this = shift;

    $_[0] =~ /^(.*)::([^:]+)$/;
    return ( $1, $2 );
}

# Normilizes callback name to it's full form of 'namespace::cbName'. If cbName
# is short (i.e. doesn't contain ::) then namespace if fetched from index. If
# more than one namespace registered a callback with the same name then assert
# exception is raised.
sub _guessCallbackName {
    my $this = shift;
    my ($name) = @_;

    return $name if $name =~ /::/;

    my @ns = @{ $_cbNameIndex{$name} };

    return $name unless @ns;

    ASSERT(
        @ns == 1,
        "Ambiguous callback name `$name': registered by "
          . scalar(@ns)
          . " namespace(s)"
    );

    return $ns[0] . '::' . $name;
}

=begin TML

---+++ ObjectMethod callbacksInit()

Virtual method. Can be overriden by classes to which this role has been applied.
It is guaranteed to be called before any actual callback is called by an object
of the class.

=cut

sub callbacksInit {
}

=begin TML

---+++ ObjectMethod registerCallback($name, $fn, $userData)

Adds coderef =$fn= to the list of registered handlers of callback =$name=.

Callback =$name= must be supported by the class.

=cut

sub registerCallback {
    my $this = shift;
    my ( $name, $fn, $userData ) = @_;

    ASSERT( ref($fn) eq 'CODE',
        "callback must be a coderef in a call to registerCallback method" );

    $name = $this->_guessCallbackName($name);

    ASSERT( $_registeredCBNames{$name}, "unknown callback '$name'" );

    my $cbInfo = {
        code => $fn,
        data => $userData,
        obj  => $this->__id,
    };

    my $app = $this->guessApp;

    ASSERT( defined $app,
        "Callback cannot be registered without an active application object" );

    push @{ $app->heap->{_aux_registered_callbacks}{$name} }, $cbInfo;
}

=begin TML

---+++ ObjectMethod deregisterCallback( $name [, $fn] )

Deregisters callbacks registered by the object and defined by =$name=. If =$fn=
is not defined then all registrations for callback =$name= are dropped.
Otherwise it's only those pointing at coderef in =$fn= are affected. 

=cut

sub deregisterCallback {
    my $this = shift;
    my ( $name, $fn ) = @_;

    ASSERT( ref($fn) eq 'CODE',
        "callback must be a coderef in a call to deregisterCallback method" )
      if defined $fn;

    $name = $this->_guessCallbackName($name);

    ASSERT( $_registeredCBNames{$name}, "unknown callback '$name'" );

    my $objId   = $this->__id;
    my $appHeap = $this->guessApp->heap;
    my $oldList = $appHeap->{_aux_registered_callbacks}{$name};
    my $newList = [];

    #$this->_traceMsg("Deregistering callback `$name' for object $objId");

    foreach my $cbInfo (@$oldList) {
        push @$newList, $cbInfo
          unless ( $cbInfo->{obj} eq $objId )
          && ( !defined($fn) || $cbInfo->{code} == $fn );
    }

    $appHeap->{_aux_registered_callbacks}{$name} = $newList;
}

=begin TML

---+++ ObjectMethod callback( $name [, \%params] )

Execute a callback defined by =$name=. Reference to =%params= is passed over
to registered callback subs in =params= profile key.

=cut

sub callback {
    my $this = shift;
    my ( $name, $params ) = @_;

    $name = caller . "::$name" unless $name =~ /::/;
    $params //= {};

    ASSERT( $_registeredCBNames{$name}, "unknown callback '$name'" );
    ASSERT( ref($params) eq 'HASH', "callback params must be a hashref" );

    my $lastException;
    my $cbList = $this->guessApp->heap->{_aux_registered_callbacks}{$name};

    return unless $cbList;

    my $restart;
    do {
        $restart = 0;
        my $lastIteration = 0;
        my ( $cbIdx, $cbInfo );
        values @$cbList;
        while (!$lastIteration
            && !$lastException
            && ( ( $cbIdx, $cbInfo ) = each @$cbList ) )
        {
            try {
                $cbInfo->{code}
                  ->( $this, data => $cbInfo->{data}, params => $params, );
            }
            catch {
                my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
                if ( $e->isa('Foswiki::Exception::Ext::Flow') ) {
                    if ( $e->isa('Foswiki::Exception::Ext::Last') ) {
                        $lastException = $e;
                    }
                    elsif ( $e->isa('Foswiki::Exception::Ext::Restart') ) {
                        $params->{'.cbData'}{execRestarted} = {
                            code => $cbInfo->{code},
                            data => $cbInfo->{data},
                        };
                        $lastIteration = $restart = 1;
                    }
                    else {
                        Foswiki::Exception::Fatal->throw(
                                text => "Unknown callback exception "
                              . ref($e)
                              . "; the exception data is following:\n"
                              . $e->stringify, );
                    }
                }
                else {
                    $e->rethrow;
                }
            };
        }
    } while ($restart);

    if ( $lastException && $lastException->has_rc ) {
        return $lastException->rc;
    }

    return;
}

=begin TML

---+++ StaticMethod registerCallbackNames($namespace, @cbNames)

Declare callback names on name space =$namespace=. Called by
=%PERLDOC{Foswiki::Class}%= exported =callback_names=.

=cut

sub registerCallbackNames {
    my $namespace = shift;
    $namespace = ref($namespace) || $namespace;

    foreach (@_) {
        my $cbName = "${namespace}::$_" unless /::/;
        ASSERT( !$_registeredCBNames{$cbName},
            "Duplicate registration of $cbName callback" );
        $_registeredCBNames{$cbName} = 1;
        push @{ $_cbNameIndex{$_} }, $namespace;
    }
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
