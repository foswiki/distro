# See bottom of file for license and copyright information

package Foswiki::Config::Expandable::LANGUAGES;

use Assert;
use Locale::Language;
use Locale::Country;

require Foswiki::Configure::FileUtil;

use Foswiki::Class qw(app);
extends qw(Foswiki::Object);
with qw(Foswiki::Config::CfgObject);

sub compose {
    my $this = shift;

    # Insert a bunch of configuration items based on what's in
    # the locales dir

    # Force initialize i18n
    #$this->app->i18n->_lh;

    my $cfg = $this->cfg;

    my $d =
         $cfg->data->{LocalesDir}
      || Foswiki::Configure::FileUtil::findFileOnPath('../locale')
      || '';

    $d = $cfg->expandStr( str => $d );

    my $dh;
    opendir( $dh, $d )
      or
      Foswiki::Exception::FileOp->throw( op => "open directory", file => $d, );

    my %langs;

    foreach my $file ( readdir $dh ) {
        next unless ( $file =~ m/^([\w-]+)\.po$/ );
        my $lang = $1;
        my $keys = $lang;

        #$keys = "'$keys'" if $keys =~ m/\W/;

        my $label;
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
            $label = Locale::Language::code2language($lang) || "$lang";
        }

        $langs{$label} = [
            "Languages.$keys.Enabled" => "BOOLEAN" => [
                -label      => $label,
                -default    => 0,
                -checker    => 'LANGUAGE',
                -display_if => "{UserInterfaceInternationalisation}",
                -check      => "undefok emptyok",
                -onsave     => 1,
            ]
        ];

    }
    closedir($dh);

    return map { @{ $langs{$_} } } sort keys %langs;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2017 Foswiki Contributors. Foswiki Contributors
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
