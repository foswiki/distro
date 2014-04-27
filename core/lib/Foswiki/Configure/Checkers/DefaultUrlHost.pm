# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DefaultUrlHost;

use strict;
use warnings;

require Foswiki::Configure::Checkers::URL;
our @ISA = ('Foswiki::Configure::Checkers::URL');

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $d    = $this->getCfg('{DefaultUrlHost}');
    my $mess = '';

    if ( $d && $d ne 'NOT SET' ) {
        $mess = $this->SUPER::check(@_);

        my $host = $ENV{HTTP_HOST};
        if ( $host && $Foswiki::cfg{DefaultUrlHost} !~ m,^https?://$host,i ) {
            return $mess
              . $this->WARN( 'Current setting does not match HTTP_HOST ',
                $ENV{HTTP_HOST} )
              . $this->NOTE(
                    'If url hostname is correct, set this field to <tt>http://'
                  . $host
                  . '</tt> or if using SSL, <tt>https://'
                  . $host
                  . '</tt>' );
        }
    }
    else {
        my $protocol = $Foswiki::query ? $Foswiki::query->url() : undef;
        $protocol ||= 'http://' . ( $ENV{HTTP_HOST} || 'localhost' );
        $protocol =~ s(^(.*?://.*?)/.*$)($1);
        $Foswiki::cfg{DefaultUrlHost} = $protocol;
        $this->{GuessedValue}         = $protocol;
        $mess                         = $this->SUPER::check(@_);
    }
    return $mess;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
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
