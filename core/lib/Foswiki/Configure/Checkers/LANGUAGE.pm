# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LANGUAGE;

use strict;
use warnings;

use Assert;
use Foswiki::I18N;

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

    my $lang = $this->{item}->{keys};
    unless ( $lang =~ s/^\{Languages\}\{'?([\w-]+)'?\}\{Enabled\}$/$1/ ) {
        die "Invalid item key $lang for LANGUAGE";
    }

    return $reporter->ERROR("Missing language file $dir/$lang.po")
      unless ( -r "$dir/$lang.po" );

    # Code taken from Foswki::I18N
    if ( Foswiki::I18N->can('get_handle') ) {
        my $h = Foswiki::I18N->get_handle($lang);
        my $name = eval { $h->maketext("_language_name") };
        unless ($name) {
            $reporter->ERROR(
"Internal error: $lang is missing the '_language_name' from it's translation.  Language will not be usable."
            );
        }
    }
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

    if ( $Foswiki::cfg{UserInterfaceInternationalisation} ) {
        my $dir = $Foswiki::cfg{WorkingDir};

        if ( -f "$dir/languages.cache" ) {
            if ( unlink("$dir/languages.cache") ) {
                $reporter->NOTE("Flushed languages cache");
            }
            else {
                $reporter->ERROR("Failed to remove $dir/languages.cache: $!");
            }
        }
    }

    if ( $Foswiki::cfg{LanguageFileCompression} ) {
        require Foswiki::Configure::Checkers::LanguageFileCompression;
        $key =~ m/^\{Languages\}\{'?([\w-]+)'?\}\{Enabled\}$/;
        if ($val) {
            Foswiki::Configure::Checkers::LanguageFileCompression::compressLanguage(
                $reporter, $1 );
        }
        else {
            Foswiki::Configure::Checkers::LanguageFileCompression::removeCompression(
                $reporter, $1 );
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
