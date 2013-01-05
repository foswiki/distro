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

    return $n;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    delete $this->{FeedbackProvided};

    return wantarray
      ? (
        $e,
        $Foswiki::cfg{UserInterfaceInternationalisation}
        ? [qw/{LanguageFileCompression}/]
        : 0
      )
      : $e;
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
