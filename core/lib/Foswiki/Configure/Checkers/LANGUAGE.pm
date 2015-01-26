# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LANGUAGE;

use strict;
use warnings;

use Assert;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

=begin TML

---++ ObjectMethod check() -> $checkmsg

This is a generic (item-independent) checker for LANGUAGE items.

These have keys of the form {Languages}{ language }{Enabled}.

=cut

sub check_current_value {
    my ( $this, $reporter ) = @_;

    return unless ( $Foswiki::cfg{UserInterfaceInternationalisation} );

    my $enabled = $this->checkExpandedValue($reporter);
    return unless $enabled;

    my $dir = $Foswiki::cfg{LocalesDir};
    Foswiki::Configure::Load::expandValue($dir);
    my $compress = $Foswiki::cfg{LanguageFileCompression};

    my $lang = $this->{item}->{keys};
    unless ( $lang =~ s/^\{Languages\}\{'?([\w-]+)'?\}\{Enabled\}$/$1/ ) {
        die "Invalid item key $lang for LANGUAGE";
    }

    return $reporter->ERROR("Missing language file $dir/$lang.po")
      unless ( -r "$dir/$lang.po" );

    if ($compress) {
        my $ok = -r "$dir/$lang.mo" && -M "$dir/$lang.po" >= -M "$dir/$lang.mo";

        unless ($ok) {
            eval("require Locale::Msgfmt;");
            if ($@) {
                return $reporter->ERROR(
"Locale::Msgfmt can not be loaded, unable to compile strings."
                );
            }
            my $umask =
              umask( oct(777) - $Foswiki::cfg{Store}{filePermission} );
            eval {
                Locale::Msgfmt::msgfmt(
                    {
                        in      => "$dir/$lang.po",
                        out     => "$dir/$lang.mo",
                        verbose => 0
                        , # verbose is not documented, but prints results to STDERR
                    }
                );
            };
            if ($@) {
                $reporter->ERROR(
                    "Unable to compress strings: compilation failed.");
            }
            else {
                $reporter->NOTE("Successfully compressed strings");
            }
            umask($umask);
        }
    }
    else {
        if ( -f "$dir/$lang.mo" ) {
            if ( unlink("$dir/$lang.mo") ) {
                $reporter->NOTE("Removed compressed strings");
            }
            else {
                $reporter->ERROR(
                    "Unable to remove compressed strings in $dir/$lang.mo: $!");
            }
        }
    }
}

sub refresh_cache {
    my ( $this, $string, $reporter ) = @_;

    if ( $Foswiki::cfg{UserInterfaceInternationalisation} ) {
        my $dir = $Foswiki::cfg{LocalesDir};

        if ( -f "$dir/languages.cache" ) {
            if ( unlink("$dir/languages.cache") ) {
                $reporter->NOTE("Flushed languages cache");
            }
            else {
                $reporter->ERROR("Failed to remove $dir/languages.cache: $!");
            }
        }
    }
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
