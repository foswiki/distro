# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LanguageFileCompression;

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

    $reporter->WARN(
"Langugage file compression has been known to cause issues, and is considered experimental."
    );

}

=begin TML

---++ ObjectMethod onSave()

This routine is called during the Save wizard, for any key that being
saved, regardless of whether or not it has actually changed.  This
is enabled by including the ONSAVE key in the Spec. (In this case it is
automatically enabled by the =Pluggable/LANGUAGES.pm=

This will remove the languages.cache file from the WorkingDir, so that
the cache can be regenerated.

If compression is enabled, it also compresses the language file.

=cut

sub onSave {
    my ( $this, $reporter, $key, $val ) = @_;

    foreach ( keys %{ $Foswiki::cfg{Languages} } ) {
        if ($val) {
            compressLanguage( $reporter, $_ )
              if ( $Foswiki::cfg{Languages}{$_}{Enabled} );
        }
        else {
            removeCompression( $reporter, $_ );
        }
    }
}

sub compressLanguage {
    my ( $reporter, $lang ) = @_;

    my $dir = $Foswiki::cfg{LocalesDir};
    Foswiki::Configure::Load::expandValue($dir);

    my $ok = -r "$dir/$lang.mo" && -M "$dir/$lang.po" >= -M "$dir/$lang.mo";

    unless ($ok) {
        eval("require Locale::Msgfmt;");
        if ($@) {
            return $reporter->ERROR(
                "Locale::Msgfmt can not be loaded, unable to compile strings."
            );
        }
        my $umask = umask( oct(777) - $Foswiki::cfg{Store}{filePermission} );
        eval {
            Locale::Msgfmt::msgfmt(
                {
                    in      => "$dir/$lang.po",
                    out     => "$dir/$lang.mo",
                    verbose => 0
                    ,  # verbose is not documented, but prints results to STDERR
                }
            );
        };
        if ($@) {
            print STDERR "Compression failure: $@";
            $reporter->ERROR("Unable to compress strings: compilation failed.");
        }
        else {
            $reporter->NOTE("Successfully compressed $lang strings");
        }
        umask($umask);
    }
}

sub removeCompression {
    my ( $reporter, $lang ) = @_;

    my $dir = $Foswiki::cfg{LocalesDir};
    Foswiki::Configure::Load::expandValue($dir);

    if ( -f "$dir/$lang.mo" ) {
        if ( unlink("$dir/$lang.mo") ) {
            $reporter->NOTE("Removed compressed $lang strings");
        }
        else {
            $reporter->ERROR(
                "Unable to remove compressed strings in $dir/$lang.mo: $!");
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
