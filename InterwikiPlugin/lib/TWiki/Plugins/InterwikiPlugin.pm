# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Plugins::InterwikiPlugin

Recognises and processes special links to other sites defined
using "inter-site syntax".

The recognized syntax is:
<pre>
       InterSiteName:TopicName
</pre>

Sites must start with upper case and must be preceded by white
space, '-', '*' or '(', or be part of the link expression
in a [[link]] or [[link][text]] expression.

=cut

package TWiki::Plugins::InterwikiPlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw(
            $VERSION
            $RELEASE
            $interWeb
            $interLinkFormat
            $sitePattern
            $pagePattern
            %interSiteTable
    );

# This should always be $Rev: 14913 (17 Sep 2007) $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 14913 (17 Sep 2007) $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '03 Aug 2008';

BEGIN {
    # 'Use locale' for internationalisation of Perl sorting and searching - 
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale ();
    }
}

# Read preferences and get all InterWiki Site->URL mappings
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    $interWeb = $installWeb;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between InterwikiPlugin and Plugins.pm" );
        return 0;
    }

    # Regexes for the Site:page format InterWiki reference
    my $man = TWiki::Func::getRegularExpression('mixedAlphaNum');
    my $ua = TWiki::Func::getRegularExpression('upperAlpha');
    $sitePattern    = "([$ua][$man]+)";
    $pagePattern    = "([${man}_\/][$man" . '\.\/\+\_\,\;\:\!\?\%\#\@\-]*?)';

    # Get plugin preferences from InterwikiPlugin topic
    $interLinkFormat =
      TWiki::Func::getPreferencesValue( 'INTERWIKIPLUGIN_INTERLINKFORMAT' ) ||
      '<a href="$url" title="$tooltip"><noautolink>$label</noautolink></a>';

    my $interTopic =
      TWiki::Func::getPreferencesValue( 'INTERWIKIPLUGIN_RULESTOPIC' )
          || 'InterWikis';
    ( $interWeb, $interTopic ) =
      TWiki::Func::normalizeWebTopicName( $interWeb, $interTopic );
    if( $interTopic =~ s/^(.*)\.// ) {
        $interWeb = $1;
    }

    my $text = TWiki::Func::readTopicText( $interWeb, $interTopic, undef, 1 );

    # '| alias | URL | ...' table and extract into 'alias', "URL" list
    $text =~ s/^\|\s*$sitePattern\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|.*$/_map($1,$2,$3)/mego;

    $sitePattern = "(" . join( "|", keys %interSiteTable ) . ")";
    return 1;
}

sub _map {
    my( $site, $url, $tooltip ) = @_;
    if( $site ) {
        $interSiteTable{$site}{url} = $url || '';
        $interSiteTable{$site}{tooltip} = $tooltip || '';
    }
    return '';
}

sub preRenderingHandler {
    # ref in [[ref]] or [[ref][
    $_[0] =~ s/(\[\[)$sitePattern:$pagePattern(\]\]|\]\[[^\]]+\]\])/_link($1,$2,$3,$4)/geo;
    # ref in text
    $_[0] =~ s/(^|[\s\-\*\(])$sitePattern:$pagePattern(?=[\s\.\,\;\:\!\?\)\|]*(\s|$))/_link($1,$2,$3)/geo;
}

sub _link {
    my( $prefix, $site, $page, $postfix ) = @_;

    $prefix ||= '';
    $site ||= '';
    $page ||= '';
    $postfix ||= '';

    my $text = $prefix;
    if( defined( $interSiteTable{$site} ) ) {
        my $tooltip = $interSiteTable{$site}{tooltip};
        my $url = $interSiteTable{$site}{url};
        $url .= $page unless( $url =~ /\$page/ );
        my $label = '$site:$page';

        if( $postfix ) {
            # [[...]] or [[...][...]] interwiki link
            $text = '';
            if( $postfix =~ /^\]\[([^\]]+)/ ) {
                $label = $1;
            }
        }

        my $format = $interLinkFormat;
        $format =~ s/\$url/$url/g;
        $format =~ s/\$tooltip/$tooltip/g;
        $format =~ s/\$label/$label/g;
        $format =~ s/\$site/$site/g;
        $format =~ s/\$page/$page/g;
        $text .= $format;
    } else {
        $text .= "$site\:$page$postfix";
    }
    return $text;
}

1;
