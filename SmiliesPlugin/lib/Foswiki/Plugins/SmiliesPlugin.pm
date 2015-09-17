# See bottom of file for license and copyright information
#
# This plugin replaces smilies with small smilies bitmaps

package Foswiki::Plugins::SmiliesPlugin;

use strict;
use warnings;

use Foswiki::Func ();

our %cache = ();
our $current;

our $VERSION           = '2.03';
our $RELEASE           = '17 Sep 2015';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION  = 'Render smilies like :-) as icons';
our $doneHeader        = 0;

sub initPlugin {

    Foswiki::Func::registerTagHandler( 'SMILIES', \&_renderSmilies );

    my $web   = $Foswiki::cfg{SystemWebName};
    my $topic = Foswiki::Func::getPreferencesValue('SMILIESPLUGIN_TOPIC')
      || "SmiliesPlugin";

    $doneHeader = 0;

    _loadSmilies( $web, $topic );

    return 1;
}

sub preRenderingHandler {

    if ( $_[0] =~
        s/(\s|^)$cache{$current}{pattern}(?=\s|$)/_renderSmily($1,$2)/ge )
    {
        _addToZone();
    }
}

sub _addToZone {
    return if $doneHeader;
    $doneHeader = 1;
    Foswiki::Func::addToZone( "head", "SMILIESPLUGIN",
"<link rel='stylesheet' href='%PUBURLPATH%/%SYSTEMWEB%/SmiliesPlugin/smilies.css' type='text/css' media='all' />"
    );
}

sub _loadSmilies {
    my ( $web, $topic, $force ) = @_;

    ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );

    $current = "$web.$topic";
    return if !$force && defined $cache{$current};

    $cache{$current} = ();

    $cache{$current}{format} =
      Foswiki::Func::getPreferencesValue('SMILIESPLUGIN_FORMAT')
      || '<img class=\'smily\' src=\'$url\' alt=\'$tooltip\' title=\'$tooltip\' />';

    $cache{$current}{pattern} = "(";
    my $state = 0;
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    foreach my $line ( split( /\n/, $text || '' ) ) {

        # | smily | image | description |
        if ( $line =~ m/^\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$/ ) {

            my $alternatives = $1;
            my $image        = $2;
            my $desc         = $3;

            if ( $alternatives =~ m/^\*/ ) {
                $state = 1;
                next;
            }

            $image =~ s/%ATTACHURL(PATH)?%//g;
            $desc  =~ s/"//g;

            next unless $alternatives && $image;

            foreach my $key ( split( /\s+/, $alternatives ) ) {
                $key =~ s/<nop>|\&nbsp;//g;
                $cache{$current}{pattern} .= "\Q$key\E|";
                $cache{$current}{image}{$key} = $image;
                $cache{$current}{desc}{$key}  = $desc;
                $cache{$current}{alts}{$key}  = $alternatives;
            }
        }
        else {
            last if $state == 1;
        }
    }

    #$cache{$current}{pattern} =~ s/\|$//;
    $cache{$current}{pattern} .= ")";
    $cache{$current}{pubUrl} = Foswiki::Func::getPubUrlPath() . "/$web/$topic";

}

sub _renderSmily {
    my ( $pre, $smily ) = @_;

    return $pre unless $smily;
    return $pre . _formatSmily( $cache{$current}{format}, $smily );
}

sub _formatSmily {
    my ( $format, $smily ) = @_;

    my $text = $format;

    $text =~ s/\$key/<nop>$smily/g;
    $text =~ s/\$alternatives/$cache{$current}{alts}{$smily}/g;
    $text =~ s/\$emoticon/$smily/g;
    $text =~ s/\$tooltip/$cache{$current}{desc}{$smily}/g;
    $text =~
      s/\$url/$cache{$current}{pubUrl}\/$cache{$current}{image}{$smily}/g;

    return $text;
}

sub _renderSmilies {
    my ( $session, $params ) = @_;

    my $smily     = $params->{_DEFAULT};
    my $header    = $params->{header};
    my $format    = $params->{format};
    my $footer    = $params->{footer} || '';
    my $separator = $params->{separator} || '$n';

    $header =
'| *%MAKETEXT{"Notation"}%* | *%MAKETEXT{"Image"}%* | *%MAKETEXT{"Description"}%* |$n'
      unless defined $header;

    $format = '| $alternatives | $emoticon | $tooltip |' unless defined $format;

    my @smilies = ();
    if ( defined $smily ) {
        push @smilies, $smily;
    }
    else {
        @smilies =
          sort {
            lc( $cache{$current}{image}{$a} ) cmp
              lc( $cache{$current}{image}{$b} )
          }
          keys %{ $cache{$current}{alts} };
    }

    my @result = ();
    my %seen   = ();
    foreach my $smily (@smilies) {
        next if $seen{ $cache{$current}{alts}{$smily} };
        push @result, _formatSmily( $format, $smily );
        $seen{ $cache{$current}{alts}{$smily} } = 1;
    }

    return '' unless @result;

    _addToZone();

    return Foswiki::Func::decodeFormatTokens(
        $header . join( $separator, @result ) . $footer );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
