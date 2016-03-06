# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Store::PlainFile::Implementation;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $bad = 0;
    $bad ||= _checkDir( $Foswiki::cfg{DataDir}, $reporter )
      if ( defined $Foswiki::cfg{DataDir} );
    $bad ||= _checkDir( $Foswiki::cfg{PubDir}, $reporter )
      if ( defined $Foswiki::cfg{PubDir} );

    if (   _checkPFV( $Foswiki::cfg{DataDir} )
        || _checkPFV( $Foswiki::cfg{PubDir} ) )
    {
        $reporter->NOTE( <<HERE);
PlainFile history found.  This is the correct choice.
*Caution* If you intend to migrate data from an older system, you will
need to migrate your data using the =tools/bulk_copy.pl= script!
HERE
    }
    else {

        if ( !$bad && $Foswiki::cfg{Store}{Implementation} =~ /PlainFile/ ) {
            $reporter->NOTE(
'No RCS revision files were found.  You may safely use the PlainFile Store.'
            );
            $reporter->WARN( <<HERE);
*Caution* If you intend to migrate data from an older version of Foswiki, you should select
one of the RCS based store now before editing any wiki topics or registering any users!
HERE
            $reporter->NOTE( <<HERE);
If you want to convert to the =PlainFile= store, you will
need to migrate your data using the =tools/bulk_copy.pl= script!
HERE
        }
    }

    if ( $Foswiki::cfg{RCS}{AutoAttachPubFiles} ) {
        $reporter->WARN(
'PlainFile store is not compatible with ={RCS}{AutoAttachPubFiles}=.  Consider the [[http://foswiki.org/Extensions/UpdateAttachmentsPlugin]] as an alternative.'
        );
    }

    return;
}

sub _checkDir {
    my ( $ddir, $reporter ) = @_;
    Foswiki::Configure::Load::expandValue($ddir);

    my $bad =
      Foswiki::Configure::FileUtil::findFileOnTree( $ddir, qr/,v$/, qr/,pfv$/ );

    if ($bad) {
        $reporter->WARN(
'RCS ,v files detected. Loss of the history stored in these files is possible if you continue with the PlainFile store. You may want to consider migrating RCS files using =tools/bulk_copy.pl=, or choosing one of the RCS stores.'
        );
        $reporter->NOTE("First RCS file encountered: $bad");
        return 1;
    }
}

sub _checkPFV {
    my $ddir = shift;
    Foswiki::Configure::Load::expandValue($ddir);

    my $bad =
      Foswiki::Configure::FileUtil::findFileOnTree( $ddir, qr/,pfv$/, qr/,v$/ );

    return $bad;

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
