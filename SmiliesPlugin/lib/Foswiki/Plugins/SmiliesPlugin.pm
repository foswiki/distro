# See bottom of file for license and copyright information
#
# This plugin replaces smilies with small smilies bitmaps

package Foswiki::Plugins::SmiliesPlugin;

use strict;
use warnings;

use Foswiki::Func ();

use vars qw(
  %smiliesUrls %smiliesEmotions
  $smiliesPubUrl $allPattern $smiliesFormat );

our $VERSION           = '$Rev$';
our $RELEASE           = '05 Dec 2011';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION  = 'Render smilies like :-) as icons';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Get plugin preferences
    $smiliesFormat = Foswiki::Func::getPreferencesValue('SMILIESPLUGIN_FORMAT')
      || '<img src="$url" alt="$tooltip" title="$tooltip" border="0" />';

    $topic = Foswiki::Func::getPreferencesValue('SMILIESPLUGIN_TOPIC')
      || "$installWeb.SmiliesPlugin";

    $web = $installWeb;
    if ( $topic =~ /(.+)\.(.+)/ ) {
        $web   = $1;
        $topic = $2;
    }

    $allPattern = "(";
    foreach (
        split( /\n/, Foswiki::Func::readTopicText( $web, $topic, undef, 1 ) ) )
    {

        # smilie       url            emotion
        if (
m/^\s*\|\s*<nop>(?:\&nbsp\;)?([^\s|]+)\s*\|\s*%ATTACHURL%\/([^\s]+)\s*\|\s*"([^"|]+)"\s*\|\s*$/o
          )
        {
            $allPattern .= "\Q$1\E|";
            $smiliesUrls{$1}     = $2;
            $smiliesEmotions{$1} = $3;
        }
    }
    $allPattern =~ s/\|$//o;
    $allPattern .= ")";
    $smiliesPubUrl = Foswiki::Func::getPubUrlPath() . "/$web/$topic";

    # Initialization OK
    return 1;
}

sub commonTagsHandler {

    # my ( $text, $topic, $web ) = @_;
    $_[0] =~ s/%SMILIES%/_allSmiliesTable()/geo;
}

sub preRenderingHandler {

    #    my ( $text, \%removed ) = @_;

    $_[0] =~ s/(\s|^)$allPattern(?=\s|$)/_renderSmily($1,$2)/geo;
}

sub _renderSmily {
    my ( $thePre, $theSmily ) = @_;

    return $thePre unless $theSmily;

    my $text = $thePre . $smiliesFormat;
    $text =~ s/\$emoticon/$theSmily/go;
    $text =~ s/\$tooltip/$smiliesEmotions{$theSmily}/go;
    $text =~ s/\$url/$smiliesPubUrl\/$smiliesUrls{$theSmily}/go;

    return $text;
}

sub _allSmiliesTable {
    my $text = "| *What to Type* | *Graphic That Will Appear* | *Emotion* |\n";

    foreach my $k (
        sort { $smiliesEmotions{$b} cmp $smiliesEmotions{$a} }
        keys %smiliesEmotions
      )
    {
        $text .= "| <nop>$k | $k | " . $smiliesEmotions{$k} . " |\n";
    }
    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
