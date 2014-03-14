# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::AccessControlException

Exception used raise an access control violation. This exception has the
following fields:
   * =web= - the web which was being accessed
   * =topic= - the topic being accessed (if any)
   * =user= - canonical username of the person doing the accessing. Use
   the methods of the Foswiki::Users class to get more information about the
   user.
   * =mode= - the access mode e.g. CHANGE, VIEW etc
   * =reason= a text string giving the reason for the refusal.

The exception may be thrown by plugins. If a plugin throws the exception, it
will normally be caught and the browser redirected to a login screen (if the
user is not logged in) or reported (if they are and just don't have access).

---++ Throwing an exception

If your code needs to abort processing and inform the user (or the higher level caller)
that some operation was denied, throw an =AccessControlException=.

<verbatim>
    use Error qw(:try);
    use Foswiki::AccessControlException;
    ...
    unless (
        Foswiki::Func::checkAccessPermission(
            "VIEW", $session->{user}, undef, $topic, $web
        )
      )
    {
        throw Foswiki::AccessControlException( "VIEW", $session->{user}, $web,
            $topic,  $Foswiki::Meta::reason );
    }
</verbatim>

---++ Catching an exception

If you are calling a function that can detect and throw an access violation, and
you would prefer to intercept the exception to perform some further processing,
use the =try { } catch { }= structure.

<verbatim>
    my $exception;
    try {
        Foswiki::Func::moveWeb( "Oldweb", "Newweb" );
    } catch Foswiki::AccessControlException with {
        $exception = shift;
    } otherwise {
        ...
    };
</verbatim>

---++ Notes

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

package Foswiki::AccessControlException;

use strict;
use warnings;

use Error ();
our @ISA = ('Error');    # base class

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---+ ClassMethod new($mode, $user, $web, $topic, $reason)

   * =$mode= - mode of access (view, change etc)
   * =$user= - canonical user name of user doing the accessing
   * =$web= - web being accessed
   * =$topic= - topic being accessed
   * =$reason= - string reason for failure

All the above fields are accessible from the object in a catch clause
in the usual way e.g. =$e->{web}= and =$e->{reason}=

=cut

sub new {
    my ( $class, $mode, $user, $web, $topic, $reason ) = @_;

    return $class->SUPER::new(
        web    => $web,
        topic  => $topic,
        user   => $user,
        mode   => $mode,
        reason => $reason,
    );
}

=begin TML

---++ ObjectMethod stringify() -> $string

Generate a summary string. This is mainly for debugging.

=cut

sub stringify {
    my $this  = shift;
    my $topic = $this->{topic}
      || '';   # Access checks of Web objects causes uninitialized string errors
    return
"AccessControlException: Access to $this->{mode} $this->{web}.$topic for $this->{user} is denied. $this->{reason}";
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
