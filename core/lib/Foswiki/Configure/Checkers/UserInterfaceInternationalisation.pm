# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::UserInterfaceInternationalisation;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Dependency ();

my $maketext_minver = 1.23;
my @required        = (
    {
        name           => 'Locale::Maketext',
        usage          => 'I18N translations',
        minimumVersion => $maketext_minver,
    },
    {
        name  => 'Locale::Maketext::Lexicon',
        usage => 'I18N translations',
    },
    {
        name  => 'Locale::Msgfmt',
        usage => 'I18N Language file compression',
    },
);

if ( $Foswiki::cfg{DetailedOS} eq 'MSWin32' ) {
    push(
        @required,
        {
            name           => 'Win32::Console',
            usage          => 'I18N conversions on Windows platforms',
            minimumVersion => 1,
        },
    );
}

# Item12285
sub _have_vulnerable_maketext {
    my ($this) = @_;
    require Foswiki::Configure::Dependency;
    my $dep = Foswiki::Configure::Dependency->new(
        type    => 'perl',
        module  => 'Locale::Maketext',
        version => ">=$maketext_minver",
    );
    my ($result) = $dep->checkDependency();
    my $maketext_ver = eval {
        require Locale::Maketext;
        $Locale::Maketext::VERSION;
    } || '';

    return $result ? '' : <<"HERE";
Your version of Locale::Maketext $maketext_ver may introduce a dangerous code injection security vulnerability. Upgrade to version $maketext_minver or newer. See [[http://foswiki.org/Support/SecurityAlert-CVE-2012-6329][CVE-2012-6329]] for more advice.
Foswiki includes its own fix for older versions. However, some distributions of Locale::Maketext have fixed this issue without updating the version number, and this combination will result in misformatted output in some cases. You can install an up-to-date version from CPAN to fix that and get rid of this message, until your distribution provides a correctly versioned package.
HERE
}

sub check_current_value {
    my ( $this, $reporter ) = @_;
    my $vuln_msg = $this->_have_vulnerable_maketext();

    return unless $Foswiki::cfg{UserInterfaceInternationalisation};

    if ($vuln_msg) {
        if ( $Foswiki::cfg{UserInterfaceInternationalisation} ) {
            $reporter->ERROR($vuln_msg);
        }
        else {
            $reporter->WARN($vuln_msg);
        }
    }

    Foswiki::Configure::Dependency::checkPerlModules(@required);
    foreach my $mod (@required) {
        if ( !$mod->{ok} && !$mod->{optional} ) {
            if ( $Foswiki::cfg{UserInterfaceInternationalisation} ) {
                $reporter->ERROR( $mod->{check_result} );
            }
            else {
                $reporter->WARN( $mod->{check_result} );
            }
        }
        else {
            $reporter->NOTE( $mod->{check_result} );
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
