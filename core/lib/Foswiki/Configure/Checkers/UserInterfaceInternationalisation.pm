# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::UserInterfaceInternationalisation;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

my @required = (
    {
        name  => 'Locale::Maketext::Lexicon',
        usage => 'I18N translations',
    },
    {
        name  => 'Locale::Msgfmt',
        usage => 'I18N Language file compression',
    },
);

my @perl56 = (
    {
        name            => 'Unicode::String',
        usage           => 'I18N conversions',
        requiredVersion => 1,
    },
    {
        name            => 'Unicode::MapUTF8',
        usage           => "I18N conversions",
        requiredVersion => 1,
    },
    {
        name            => 'Unicode::Map',
        usage           => "I18N conversions",
        requiredVersion => 1,
    },
    {
        name            => 'Unicode::Map8',
        usage           => "I18N conversions",
        requiredVersion => 1,
    },
    {
        name            => 'Jcode',
        usage           => "I18N conversions",
        requiredVersion => 1,
    },
);

my @perl58 = (
    {
        name            => 'Encode',
        usage           => "I18N conversions (core module in Perl 5.8)",
        requiredVersion => 1,
    },
);

sub check {
    my $this = shift;

    my $n = $this->checkPerlModules( 0, \@required );

    if ( $] >= 5.008 ) {
        $n .= $this->checkPerlModules( 0, \@perl58 );
    }
    else {
        $n .= $this->checkPerlModules( 0, \@perl56 );
    }

    # If Internalization is enabled, compile the .po files into .mo files
    # for all enabled languages.
    #
    if ( $Foswiki::cfg{UserInterfaceInternationalisation} ) {
        eval "require Locale::Msgfmt";
        if ($@) {
            $n .= $this->WARN(
"Cannot compile language files - error loading 'Locale::Msgfmt'\n"
            );
        }
        else {
            my $compMsgs = '';
            my $svUmask =
              umask( oct(777) - $Foswiki::cfg{RCS}{filePermission} );

            foreach my $lang ( keys %{ $Foswiki::cfg{Languages} } ) {
                if ( $Foswiki::cfg{Languages}{$lang}{Enabled}
                    && -e "$Foswiki::cfg{LocalesDir}/$lang.po" )
                {
                    next
                      if (
                        -e "$Foswiki::cfg{LocalesDir}/$lang.mo"
                        && ( -M "$Foswiki::cfg{LocalesDir}/$lang.po" >=
                            -M "$Foswiki::cfg{LocalesDir}/$lang.mo" )
                      );
                    if (
                        !$Foswiki::cfg{LanguageFileCompression}
                        &&   -e "$Foswiki::cfg{LocalesDir}/$lang.mo"
                        && ( -M "$Foswiki::cfg{LocalesDir}/$lang.po" <
                            -M "$Foswiki::cfg{LocalesDir}/$lang.mo" )
                      )
                    {
                        $n .= $this->WARN(
"Stale language file $Foswiki::cfg{LocalesDir}/$lang.mo should be removed - Language file compression is disabled"
                        );
                    }
                    next unless $Foswiki::cfg{LanguageFileCompression};

                    $compMsgs .= "Compiling $lang.po into $lang.mo <br/>\n";
                    eval { Locale::Msgfmt::msgfmt(
                            {
                                in      => "$Foswiki::cfg{LocalesDir}/$lang.po",
                                out     => "$Foswiki::cfg{LocalesDir}/$lang.mo",
                                verbose => 0
                                , # verbose is not documented, but prints results to STDERR
                            }
                        );
                    };
                    if ( $@ ) {
                        $n .= $this->ERROR( "Compile of locale $lang.po failed - further compiles skipped");
                        $compMsgs .= $this->NOTE( $@ );
                        last;
                    }
                }
            }
            umask($svUmask);    # Restore modified umask
            $n .= $this->NOTE(
                "<b>Compiling modified Language files</b> found in $Foswiki::cfg{LocalesDir}<br/>\n$compMsgs")
              if $compMsgs;
        }
    }

    return $n;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
