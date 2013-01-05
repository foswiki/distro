# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Pluggables::LANGUAGES
Pluggable for finding and handling languages. Implements 
<nop>*LANGUAGES* in Foswiki.spec.

=cut

package Foswiki::Configure::Pluggables::LANGUAGES;

use strict;
use warnings;

use Locale::Language;
use Locale::Country;

use Foswiki::Configure::Pluggable ();
our @ISA = ('Foswiki::Configure::Pluggable');

sub new {
    my ($class) = @_;

    # The *LANGUAGES*  plugin is already inside a
    # ---++ Languages section in Foswiki.spec, so no
    # SECTION is necessary.

    # Insert a bunch of configuration items based on what's in
    # the locales dir

    my $d = $Foswiki::cfg{LocalesDir};
    Foswiki::Configure::Load::expandValue($d);

    -d $d or return [];

    opendir( DIR, $d ) or return [];

    my %langs;
    foreach my $file ( readdir DIR ) {
        next unless ( $file =~ m/^([\w-]+)\.po$/ );
        my $lang = $1;
        my $keys = $lang;
        $keys = "'$keys'" if $keys =~ /\W/;

        my $label;
        if ( $lang =~ /^(\w+)-(\w+)$/ ) {
            my ( $lname, $cname ) = (
                ( code2language( $1, 'alpha-2' ) || '' ),
                ( code2country( $2, 'alpha-2' ) || '' )
            );
            if ( $lname && $cname ) {
                $label = "$lname ($cname)";
            }
            elsif ($lname) {
                $label = "$lname ($2)";
            }
            elsif ($cname) {
                $label = "$1 ($cname)";
            }
            else {
                $label = "$lang";
            }
        }
        else {
            $label = code2language($lang) || "$lang";
        }

        my $value = Foswiki::Configure::Value->new(
            'LANGUAGE',
            keys => '{Languages}{' . $keys . '}{Enabled}',
            opts =>
"LABEL=\"Enable \Q$label\E\" FEEDBACK=auto DISPLAY_IF {UserInterfaceInternationalisation}",
        );
        $value->addAuditGroup(qw/PARS:0 LANG:0/);
        $langs{$label} = $value;
    }
    closedir(DIR);

    my $langs = [];
    foreach my $label ( sort keys %langs ) {
        push @$langs, $langs{$label};
    }
    return $langs;
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
