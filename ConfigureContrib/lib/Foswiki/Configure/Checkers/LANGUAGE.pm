# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LANGUAGE;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

=begin TML

---++ ObjectMethod check($valobj) -> $checkmsg

This is a generic (item-independent) checker for LANGUAGE items.

These have keys of the form {Languages}{ language }{Enabled}.

Functions:

check - verify (non) existence of compiled string files; correct issues.

provideFeedback - flush languages cache (since implies a change)
       create/destroy compiled string files.

=cut

sub check {
    my $this = shift;
    my ($valobj) = @_;

    my $e = '';

    return $e unless ( $Foswiki::cfg{UserInterfaceInternationalisation} );

    my ( $enabled, $keys, $lang, $dir, $compress ) = $this->_config($valobj);

    return $e unless ($enabled);

    return $this->ERROR("Missing language file $dir/$lang.po")
      unless ( -r "$dir/$lang.po" );

    if ($compress) {
        my $ok = -r "$dir/$lang.mo" && -M "$dir/$lang.po" >= -M "$dir/$lang.mo";

        unless ($ok) {
            eval "require Locale::Msgfmt;";
            if ($@) {
                return $e
                  . $this->ERROR(
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
                $e .= $this->ERROR(
                    "Unable to compress strings: compilation failed.");
            }
            else {
                $e .= $this->NOTE("Successfully compressed strings");
            }
            umask($umask);
        }
    }
    else {
        if ( -f "$dir/$lang.mo" ) {
            if ( unlink("$dir/$lang.mo") ) {
                $e .= $this->NOTE("Removed compressed strings");
            }
            else {
                $e .= $this->ERROR(
                    "Unable to remove compressed strings in $dir/$lang.mo: $!");
            }
        }
    }

    return $e;
}

sub _config {
    my ( $this, $valobj ) = @_;

    my $keys = ref($valobj) ? $valobj->{keys} : $valobj
      or die "No keys for value";

    my $enabled = $this->getItemCurrentValue($keys);

    my $dir      = $this->getCfg('{LocalesDir}');
    my $compress = $Foswiki::cfg{LanguageFileCompression};

    my $lang = $keys;
    die "Invalid item key $keys for LANGUAGE\n"
      unless ( $lang =~ s/^\{Languages\}\{'?([\w-]+)'?\}\{Enabled\}$/$1/ );

    return ( $enabled, $keys, $lang, $dir, $compress );
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    delete $this->{FeedbackProvided};

    if ( $Foswiki::cfg{UserInterfaceInternationalisation} ) {
        my ( $enabled, $keys, $lang, $dir, $compress ) =
          $this->_config($valobj);

        if ( -f "$dir/languages.cache" ) {
            if ( unlink("$dir/languages.cache") ) {
                $e .= $this->NOTE("Flushed languages cache");
            }
            else {
                $e .= $this->ERROR("Failed to remove $dir/languages.cache: $!");
            }
        }
    }

    return wantarray ? ( $e, 0 ) : $e;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
