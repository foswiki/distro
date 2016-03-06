# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Contrib::PlainFileStoreContrib

=cut

package Foswiki::Contrib::PlainFileStoreContrib;

use strict;
use warnings;

use Foswiki::Configure::FileUtil;
use Foswiki::Configure::Load;

our $VERSION          = '1.45';
our $RELEASE          = '2016-03-06';
our $SHORTDESCRIPTION = 'Store Foswiki data using plain text files';

1;

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
                $Foswiki::cfg{DataDir}, qr/,v$/, qr/,pfv$/ )
              || Foswiki::Configure::FileUtil::findFileOnTree(
                $Foswiki::cfg{PubDir}, qr/,v$/, qr/,pfv$/
              )
        )
      )
    {

        print STDERR
"AUTOCONFIG: Unable to use PlainFileStore: ,v files were found in data or pub, which indicates this installation is already configured for RCS e.g. $hit\n"
          if (Foswiki::Configure::Load::TRAUTO);

        # See if there is any evidence of PlainFileStore
        if (
            $hit = (
                Foswiki::Configure::FileUtil::findFileOnTree(
                    $Foswiki::cfg{DataDir}, qr/,pfv$/, qr/,pfv$/ )
                  || Foswiki::Configure::FileUtil::findFileOnTree(
                    $Foswiki::cfg{PubDir}, qr/,pfv$/, qr/,pfv$/
                  )
            )
          )
        {
            die
"AUTOCONFIG: WARNING: both ,v and ,pfv files were found in data or pub, suggesting that both PlainFile and RCS have been used at some point. Unable to autoconfigure - please resolve the histories manually.\n";
        }
        return;
    }

# PlainFile is preferred over Rcs based stores,  so override any Rcs based store
# Otherwise accept whatever store is configured.
    if (  !$Foswiki::cfg{Store}{Implementation}
        || $Foswiki::cfg{Store}{Implementation} =~ m/^Foswiki::Store::Rcs/ )
    {
        $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::PlainFile';
        print STDERR "AUTOCONFIG: Store configured for PlainFile\n"
          if (Foswiki::Configure::Load::TRAUTO);
    }
}

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: CrawfordCurrie

Copyright (C) 2012-2016 Crawford Currie http://c-dot.co.uk
and Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
