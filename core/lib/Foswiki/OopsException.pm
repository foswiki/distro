# See bottom of file for license and copyright information
=pod twiki

---+ package Foswiki::OopsException

Exception used to raise a request to redirect to an Oops URL.

An OopsException thrown anywhere in the code will redirect the
browser to a url based on the =oops= script. =oops= requires
the name of an oops template file from the =templates= directory.
This file will be expanded and the
parameter values passed to the exception instantiated. The
result will be shown in the browser.

Plugins may throw Foswiki::OopsException. For example:

<verbatim>
use Error;

...

throw Foswiki::OopsException( 'bathplugin',
                            def => 'toestuck',
                            web => $web,
                            topic => $topic,
                            params => [ 'bigtoe', 'hot tap' ] );
</verbatim>

=cut

package Foswiki::OopsException;
use base 'Error';

use strict;
use Error;
use Assert;

=pod

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
    my $this     = bless( $class->SUPER::new(), $class );
    $this->{template} = $template;
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

=pod

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
            $session->getSkin() );
        my $message = $session->templates->expandTemplate( $this->{def} );
        $message =
          $session->handleCommonTags( $message, $this->{web}, $this->{topic} );
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
        return $s . ')';
    }
}

=pod

---++ ObjectMethod redirect( $twiki )

Generate a redirect to an 'oops' script for this exception.

If the 'keep' parameter is set in the
exception, it saves parameter values into the query as well. This is needed
if the query string might get lost during a passthrough, due to a POST
being redirected to a GET.

=cut

sub redirect {
    my ( $this, $session ) = @_;

    my @p = ();

    $this->{template} = "oops$this->{template}"
      unless $this->{template} =~ /^oops/;
    push( @p, template => $this->{template} );
    push( @p, def => $this->{def} ) if $this->{def};
    my $n = 1;
    push( @p, map { 'param' . ( $n++ ) => $_ } @{ $this->{params} } );
    my $url =
      $session->getScriptUrl( 1, 'oops', $this->{web}, $this->{topic}, @p );
    while ( my $p = shift(@p) ) {
        $session->{request}->param( -name => $p, -value => shift(@p) );
    }
    $session->redirect( $url, 1 );
}

1;
__DATA__
# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
