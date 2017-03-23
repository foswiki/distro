# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::OopsException

Exception used to raise a request to output a preformatted page.

Despite the name, =oops= is not used just for errors; it is also used
for one-time redirection, for example during the registration process.

The =Foswiki::UI::run= function, which is in the call stack for almost
all cases where an =OopsException= will be thrown, traps the exception
and outputs an =oops= page to the browser. This requires
the name of a template file from the =templates= directory, which it
expands.  (The passed template name is prefixed with "oops", as shown below.)

Parameter values passed to the exception are instantiated in
the expanded template. The =oops= page is output with an HTTP status
appropriate to the event that caused the exception (default 500).

Extensions may throw =Foswiki::OopsException=. For example:

<verbatim>
use Error qw(:try);

...

throw Foswiki::OopsException( 'bathplugin',
                            status => 418,
                            web => $web,
                            topic => $topic,
                            params => [ 'big toe', 'stuck in', 'hot tap' ] );
</verbatim>
This will raise an exception that uses the =oopsbathplugin.tmpl= template. If
=UI::run= handles the exception it will generate a redirect to:
<verbatim>
oops?template=oopsbathplugin;param1=bigtoe;param2=hot%20tap
</verbatim>
The =oopsbathplugin.tmpl= might contain:
(&lt;nop> inserted to prevent translation interface from extracting these examples)
<verbatim>
%TMPL:INCLUDE{"oops"}%
%TMPL:DEF{"titleaction"}% %<nop>MAKETEXT{"Bathing problem"}% %TMPL:END%
%TMPL:DEF{"heading"}%%<nop>MAKETEXT{"Problem filling bath"}%%TMPL:END%
%TMPL:DEF{"topicactionbuttons"}%%TMPL:P{"oktopicaction"}%%TMPL:END%
%TMPL:DEF{"script"}%<meta http-equiv="refresh" content="0;url=%SCRIPTURL{view}%/%WEB%/%TOPIC%" />%TMPL:END%
%TMPL:DEF{"pagetitle"}%%TMPL:P{"heading"}%%TMPL:END%
%TMPL:DEF{"webaction"}% *%<nop>MAKETEXT{"Warning"}%* %TMPL:END%
%TMPL:DEF{"message"}%
%<nop>MAKETEXT{"Your bath cannot be filled because your [_1] is [_2] the [_3]" args="drain,flooding,basement"}%%TMPL:END%
</verbatim>
In this case the =oops= page will be rendered with a 418 ("I'm a teapot")
status in the HTTP header.

A more practical example for plugins authors that does not require them to
provide their own template file involves use of the generic message template
available from =oopsattention.tmpl=:
<verbatim>
throw Foswiki::OopsException( 'attention', def => 'generic',
   params => [ Operation is not allowed  ] );
</verbatim>

Note that to protect against cross site scripting all parameter values are
automatically and unconditionally entity-encoded so you cannot pass macros
if you need messages to be automatically translated you either need to handle
it in the perl code before throwing Foswiki::OopsException or put the %MAKETEXT
in the template. You cannot pass macros through the parameters.

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (TWiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

# THIS PACKAGE IS PART OF THE PUBLISHED API USED BY EXTENSION AUTHORS.
# DO NOT CHANGE THE EXISTING APIS (well thought out extensions are OK)
# AND ENSURE ALL POD DOCUMENTATION IS COMPLETE AND ACCURATE.

package Foswiki::OopsException;
use strict;
use warnings;

use Error ();
our @ISA = ('Error');

use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new( $template, ...)
   * =template= is the name of an oops template. e.g. 'bathplugin' refers to =templates/oopsbathplugin.tmpl=
The remaining parameters are interpreted as key-value pairs. The following keys are used:
   * =web= will be used as the web for the oops
   * =topic= will be used as the topic for the oops
   * =def= - is the (optional) name of a TMPL:DEF within the template
   * =keep= - if set, the exception handler should try its damnedest to retain parameter values from the query.
   * =params= is a reference to an array of parameters. These will be substituted for !%PARAM1%, !%PARAM2% ... !%PARAMn% in the template.

For an example of how to use the =def= parameter, see the =oopsattention=
template.

NOTE: parameter values are automatically and unconditionally entity-encoded

=cut

sub new {
    my $class    = shift;
    my $template = shift;
    my $this     = $class->SUPER::new();
    $this->{template} = $template || 'generic';
    $this->{status} = 500;    # default server error
    ASSERT( scalar(@_) % 2 == 0, join( ";", map { $_ || 'undef' } @_ ) )
      if DEBUG;
    while ( my $key = shift @_ ) {
        my $val = shift @_;
        if ( $key eq 'params' ) {
            if ( ref($val) ne 'ARRAY' ) {
                $val = [$val];
            }
            $this->{params} = $val;
        }
        else {
            $this->{$key} = $val || '';
        }
    }
    return $this;
}

=begin TML

---++ ObjectMethod stringify( [$session] ) -> $string

Generates a string representation for the object. if a session is passed in,
and the exception specifies a def, then that def is expanded. This is to allow
internal expansion of oops exceptions for example when performing bulk
operations, and also for debugging.

=cut

sub stringify {
    my ( $this, $session ) = @_;

    if ( $this->{template} && $this->{def} && $session ) {

        # load the defs
        $session->templates->readTemplate( 'oops' . $this->{template},
            no_oops => 1 );
        my $message = $session->templates->expandTemplate( $this->{def} )
          || "Failed to find '$this->{def}' in 'oops$this->{template}'";
        my $topicObject =
          Foswiki::Meta->new( $session, $this->{web}, $this->{topic} );
        $message = $topicObject->expandMacros($message);
        my $n = 1;
        foreach my $param ( @{ $this->{params} } ) {
            $message =~ s/%PARAM$n%/$param/g;
            $n++;
        }
        return $message;
    }
    else {
        my $s = 'OopsException(';
        $s .= $this->{template};
        $s .= '/' . $this->{def} if $this->{def};
        $s .= ' web=>' . $this->{web} if $this->{web};
        $s .= ' topic=>' . $this->{topic} if $this->{topic};
        $s .= ' keep=>1' if $this->{keep};
        if ( defined $this->{params} ) {
            $s .= ' params=>[' . join( ',', @{ $this->{params} } ) . ']';
        }
        return $s . ')' . ( (DEBUG) ? $this->stacktrace : '' );
    }
}

# Generate a redirect to an 'oops' script for this exception.
#
# If the 'keep' parameter is set in the
# exception, it saves parameter values into the query as well. This is needed
# if the query string might get lost during a passthrough, due to a POST
# being redirected to a GET.
# This redirect has been replaced by the generate function below and should
# not be called in new code.
sub redirect {
    my ( $this, $session ) = @_;

    my @p = $this->_prepareResponse($session);
    my $url =
      $session->getScriptUrl( 1, 'oops', $this->{web}, $this->{topic}, @p );
    $session->redirect( $url, 1 );
}

=begin TML

---++ ObjectMethod generate( $session )

Generate an error page for the exception. This will output the error page
to the browser. The default HTTP Status for an Oops page is 500. This
can be overridden using the 'status => ' parameter to the constructor.

=cut

sub generate {
    my ( $this, $session ) = @_;

    my @p = $this->_prepareResponse($session);
    $session->{response}->status( $this->{status} );
    require Foswiki::UI::Oops;
    Foswiki::UI::Oops::oops( $session, $this->{web}, $this->{topic},
        $session->{request}, 0 );
}

sub _prepareResponse {
    my ( $this, $session ) = @_;
    my @p = ();

    $this->{template} = "oops$this->{template}"
      unless $this->{template} =~ m/^oops/;
    push( @p, template => $this->{template} );
    push( @p, def => $this->{def} ) if $this->{def};
    my $n = 1;
    push( @p, map { 'param' . ( $n++ ) => $_ } @{ $this->{params} } );
    while ( my $p = shift(@p) ) {
        $session->{request}->param( -name => $p, -value => shift(@p) );
    }
    return @p;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
