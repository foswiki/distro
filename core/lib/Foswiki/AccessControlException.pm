# See bottom of file for license and copyright information
=pod twiki

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

=cut

package Foswiki::AccessControlException;
use base 'Error';

use strict;

=pod

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

=pod

---++ ObjectMethod stringify() -> $string

Generate a summary string. This is mainly for debugging.

=cut

sub stringify {
    my $this = shift;
    return
"AccessControlException: Access to $this->{mode} $this->{web}.$this->{topic} for $this->{user} is denied. $this->{reason}";
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
# Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
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
