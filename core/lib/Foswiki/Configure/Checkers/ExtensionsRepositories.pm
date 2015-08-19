# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ExtensionsRepositories;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Checkers::URL ();
use Foswiki::Configure::Load          ();

# Checks the Extensions repository list.
# Syntax:
#   list := repospec[;repospec...]
#   repospec := name=(listurl,puburl[,username,password])
sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $replist = $this->checkExpandedValue($reporter);
    return unless defined $replist;

    my @list;
    while ( $replist =~ s/^\s*([^=;]+)=\(([^)]*)\)\s*// ) {
        my ( $name, $value ) = ( $1, $2 );
        if ( $value =~
            m/^([a-z]+:[^,]+),\s*([a-z]+:[^,]+)(?:,\s*([^,]*),\s*(.*))?$/ )
        {
            push @list,
              {
                name => $name,
                data => $1,
                pub  => $2,
                user => $3,
                pass => $4
              };
        }
        else {
            $reporter->ERROR("Syntax error in list at $value)$replist");
            last;
        }
        last unless ( $replist =~ s/^;\s*// );
    }

    foreach my $repo (@list) {
        Foswiki::Configure::Checkers::URL::checkURI(
            $reporter,
            $repo->{data},
            parts    => [qw/scheme authority path query/],
            partsreq => [qw/scheme authority path/],
            authtype => ['hostip'],
            pass     => [1],
        );
        Foswiki::Configure::Checkers::URL::checkURI(
            $reporter,
            $repo->{pub},
            parts    => [qw/scheme authority path query/],
            partsreq => [qw/scheme authority path/],
            authtype => ['hostip'],
            pass     => [1],
        );
    }

    if ($Foswiki::pluginModuleInconsistencies) {
        $reporter->WARN(
"Plugin module inconsistencies detected - merge of extension settings recommended."
        );
    }

    foreach my $ext ( Foswiki::Configure::Load::specChanged() ) {
        $reporter->WARN(
"The Config.spec for $ext is more recent than the latest configuration. 'merge extension settings' is required."
        );
    }
}

1;

__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012-2014 Foswiki Contributors. Foswiki Contributors
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
