# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Exception

Base class for all Foswiki exceptions. This is still a concept only.

Basic principles behind exceptions:

   1. Exceptions are using =CPAN:Try::Tiny=. Use of =CPAN:Error= module is no longer
      recommended.
   1. Exception classes are inheriting from =Foswiki::Exception=.
   1. =Foswiki::Exception= is an integral part of Fowiki's OO system and inheriting from =Foswiki::Object=.
   1. =Foswiki::Exception= is utilizing =Throwable= role. Requires this module to be installed.
   1. Exception classes inheritance shall form a tree of relationships for fine-grained error hadling.
   
The latter item might be illustrated with the following expample (for inherited classes =Foswiki::Exception= prefix is skipped for simplicity though it is recommended for code readability):

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

package Foswiki::Exception;
use Carp;
use Assert;
use Moo;
use namespace::clean;

extends qw(Foswiki::Object);

with 'Throwable';

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

has line       => ( is => 'ro' );
has file       => ( is => 'ro' );
has text       => ( is => 'ro', required => 1, );
has stacktrace => ( is => 'rwp' );

sub BUILD {
    my $this = shift;

    my $trace = Carp::longmess('');
    $this->_set_stacktrace($trace);
}

sub stringify {
    my $this = shift;

    return
        $this->text . ' at '
      . $this->file
      . ' line '
      . $this->line
      . ( DEBUG ? "\n" . $this->stacktrace : '' );
}

package Foswiki::Exception::Engine;
use Moo;
use namespace::clean;
extends qw(Foswiki::Exception);

our @_newParameters = qw(status reason response);

has status   => ( is => 'ro', required => 1, );
has reason   => ( is => 'ro', required => 1, );
has response => ( is => 'ro', required => 1, );

=begin TML

---++ ObjectMethod stringify() -> $string

Generate a summary string. This is mainly for debugging.

=cut

sub BUILD {
    my $this = shift;

    $this->text( 'EngineException: Status code "'
          . $this->status
          . ' defined because of "'
          . $this->reason );
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
Copyright (C) 2005 Martin at Cleaver.org
Copyright (C) 2005-2007 TWiki Contributors

and also based/inspired on Catalyst framework, whose Author is
Sebastian Riedel. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
for more credit and liscence details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
