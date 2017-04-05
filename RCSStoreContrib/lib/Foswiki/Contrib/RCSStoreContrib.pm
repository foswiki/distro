# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Contrib::RCSStoreContrib

This is a stub module for a new contrib. Customise this module as
required.  It is typically not used by the Contrib.  Foswiki does not load it
automatically.  It is used by the Extensions Installer to detect the currently
installed version of the Contrib.

=cut

package Foswiki::Contrib::RCSStoreContrib;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Configure::Load;

our $VERSION = '1.06';
our $RELEASE = '4 Apr 2017';
our $SHORTDESCRIPTION =
  'A wiki topic and attachment store using the RCS revision control system';

=begin TML

---++ bootstrapStore

Class method called from configuration bootstrap to determine if this
store can be used.  If it's usable, it will take precedence over the RCS
based configurations.

This method "guesses" the following configuration settings

   * ={Store}{Implementation}=

It must run after the DataDir and PubDir settings have been applied.

If it detects both RCS and PlainFile store files, it dies to prevent
history corruption.

=cut

sub bootstrapStore {

    if (
        my $hit = (
            Foswiki::Configure::FileUtil::findFileOnTree(
                $Foswiki::cfg{DataDir}, qr/,pfv$/, qr/,v$/ )
              || Foswiki::Configure::FileUtil::findFileOnTree(
                $Foswiki::cfg{PubDir}, qr/,pfv$/, qr/,v$/
              )
        )
      )
    {

        print STDERR
"AUTOCONFIG: Unable to use RCSStore: ,pfv files were found in data or pub, which indicates this installation is already configured for PlainFileStore e.g. $hit\n"
          if (Foswiki::Configure::Load::TRAUTO);
        if (
            Foswiki::Configure::FileUtil::findFileOnTree(
                $Foswiki::cfg{DataDir}, qr/,v$/, qr/,pfv$/ )
            || Foswiki::Configure::FileUtil::findFileOnTree(
                $Foswiki::cfg{PubDir}, qr/,v$/, qr/,pfv$/
            )
          )
        {
            die
"AUTOCONFIG: WARNING: both ,pfv and ,v files were found in data or pub, suggesting that both stores have been used at some point. Unable to autoconfigure - please resolve the histories manually.\n";
        }
        return;
    }

    # If some other store is configured,  don't override it.  Rcs stores
    # are the last resort. Default to RcsLite, it's the most portable.
    unless ( $Foswiki::cfg{Store}{Implementation} ) {
        $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite';
        print STDERR "AUTOCONFIG: Store configured for RcsLite\n"
          if (Foswiki::Configure::Load::TRAUTO);
    }
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: FoswikiContributor

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
