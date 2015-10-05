# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::PatchFoswikiContribPlugin

List details of patch files installed by Patch*Contribs

=cut

# change the package name!!!
package Foswiki::Plugins::PatchFoswikiContribPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func                 ();    # The plugins API
use Foswiki::Plugins              ();    # For the API version
use Foswiki::Configure::PatchFile ();

# Keep in sync with lib/Foswiki/Contrib/PatchFoswikiContrib.pm
our $VERSION = '2.1';
our $RELEASE = '02 Oct 2015';

our $SHORTDESCRIPTION =
  'Helper plugin to list patch files, and their application status.';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerTagHandler( 'PATCHREPORT', \&_PATCHREPORT );

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
sub _PATCHREPORT {
    my ( $session, $params, $topic, $web, $topicObject ) = @_;

    return '<div class="foswikiAlert">%X% Admin access only!</div>'
      unless Foswiki::Func::isAnAdmin();

    my $resp;

    if ( opendir( my $d, "$Foswiki::cfg{WorkingDir}/configure/patch/" ) ) {
        foreach my $f ( grep { /\.patch$/ } sort readdir $d ) {
            my $patchFile = Foswiki::Sandbox::untaintUnchecked(
                "$Foswiki::cfg{WorkingDir}/configure/patch/$f");

            my $ret .= "---+++ $f\n";
            my %result = Foswiki::Configure::PatchFile::parsePatch($patchFile);

            $ret .= "<verbatim>$result{error}</verbatim>\n"
              if ( $result{error} );
            $ret .= "<verbatim>$result{summary}</verbatim>\n"
              if ( $result{summary} );

            $ret .= "| *Patch target* | *MD5SUM* | *Status* | *Applies to* |\n";
            $ret .=
              Foswiki::Configure::PatchFile::checkPatch( undef, \%result );

            next
              unless ( $ret =~ m/\b\Q$Foswiki::RELEASE\E\b/
                || $params->{_DEFAULT} eq 'all' );
            $resp .= $ret;
        }

        closedir($d);
    }

    $resp ||=
      '<div class="foswikiAlert">%X% No patches found on this system!</div>';
    return $resp;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: %$AUTHOR%

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
