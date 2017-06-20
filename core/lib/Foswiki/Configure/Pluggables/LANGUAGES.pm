# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Pluggables::LANGUAGES
Pluggable for finding and handling languages. Implements 
<nop>*LANGUAGES* in Foswiki.spec.

=cut

package Foswiki::Configure::Pluggables::LANGUAGES;

use strict;
use warnings;

use Locale::Language ();
use Locale::Country  ();
use Error qw{ :try };

use Assert;
use Foswiki::Configure::Load  ();
use Foswiki::Configure::Value ();

sub construct {
    my ( $settings, $file, $line ) = @_;

    # Insert a bunch of configuration items based on what's in
    # the locales dir

    my $d =
         $Foswiki::cfg{LocalesDir}
      || Foswiki::Configure::FileUtil::findFileOnPath('../locale')
      || '';
    Foswiki::Configure::Load::expandValue($d);

    opendir( DIR, $d )
      or die "Failed to open LocalesDir $Foswiki::cfg{LocalesDir}";

    my %langs;
    foreach my $file ( readdir DIR ) {
        next unless ( $file =~ m/^([\w-]+)\.po$/ );
        my $lang = $1;
        my $keys = $lang;
        $keys = "'$keys'" if $keys =~ m/\W/;

        my $label;

        if ( $lang eq 'tlh' ) {
            $label = "Klingon";
        }
        else {
            try {
                if ( $lang =~ m/^(\w+)-(\w+)$/ ) {
                    my ( $lname, $cname ) = (
                        ( Locale::Language::code2language($1) || '' ),
                        ( Locale::Country::code2country($2)   || '' )
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
                    $label = Locale::Language::code2language($lang)
                      || "$lang";
                }
            }
            otherwise {
                $label = $lang;
            };
        }

        my $value = Foswiki::Configure::Value->new(
            'BOOLEAN',
            LABEL      => $label,
            keys       => '{Languages}{' . $keys . '}{Enabled}',
            default    => 0,
            CHECKER    => 'LANGUAGE',
            DISPLAY_IF => "{UserInterfaceInternationalisation}",
            opts       => 'CHECK="undefok emptyok"',
            ONSAVE     => 1,

        );
        $langs{$label} = $value;
    }
    closedir(DIR);

    foreach my $label ( sort keys %langs ) {
        push( @$settings, $langs{$label} );
    }
    return undef;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
