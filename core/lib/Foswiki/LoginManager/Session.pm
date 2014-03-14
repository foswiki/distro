# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::LoginManager::Session

Class to provide CGI::Session like infra-structure, compatible with
Runtime Engine mechanisms other than CGI.

It inherits from CGI::Session and redefine methods that uses %ENV directly,
replacing by calls to Foswiki::Request object, that is passed to constructor.

It also redefines =name= method, to avoid creating CGI object.

=cut

package Foswiki::LoginManager::Session;

use strict;
use warnings;

use CGI::Session ();
our @ISA = ('CGI::Session');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

*VERSION = \$CGI::Session::VERSION;
*NAME    = \$CGI::Session::NAME;

sub load {
    my $this = shift;

    # SMELL: This breaks mod_perl Foswikibug:Item691
    #    local %ENV = %ENV;
    $ENV{REMOTE_ADDR} = @_ == 1 ? $_[0]->remoteAddress : $_[1]->remoteAddress;
    $this->SUPER::load(@_);
}

sub query {
    my $self = shift;

    if ( $self->{_QUERY} ) {
        return $self->{_QUERY};
    }
    return $self->{_QUERY} = Foswiki::Request->new();
}

sub _ip_matches {
    return (
        $_[0]->{_DATA}->{_SESSION_REMOTE_ADDR} eq $_[0]->query->remoteAddress );
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

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
