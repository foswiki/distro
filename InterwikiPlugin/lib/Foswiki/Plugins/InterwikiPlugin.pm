# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2009-2010 Foswiki Contributors
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

=begin TML

---+ package Foswiki::Plugins::InterwikiPlugin

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

package Foswiki::Plugins::InterwikiPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION           = '$Rev$';
our $RELEASE           = '10 Mar 2010';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
'Link ExternalSite:Page text to external sites based on aliases defined in a rules topic';

my $interLinkFormat;
my $sitePattern;
my $pagePattern;
my %interSiteTable;

BEGIN {

    # 'Use locale' for internationalisation of Perl sorting and searching -
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Read preferences and get all InterWiki Site->URL mappings
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Regexes for the Site:page format InterWiki reference
    my $man = Foswiki::Func::getRegularExpression('mixedAlphaNum');
    my $ua  = Foswiki::Func::getRegularExpression('upperAlpha');
    $sitePattern = "([$ua][$man]+)";
    $pagePattern = "([${man}_\/][$man" . '\.\/\+\_\,\&\;\:\=\!\?\%\#\@\-]*?)';

    # Get plugin preferences from InterwikiPlugin topic
    $interLinkFormat =
      Foswiki::Func::getPreferencesValue('INTERWIKIPLUGIN_INTERLINKFORMAT')
      || '<a class="interwikiLink" href="$url" title="$tooltip"><noautolink>$label</noautolink></a>';

    my ( $interWeb, $interTopic ) = Foswiki::Func::normalizeWebTopicName(
        $installWeb,
        Foswiki::Func::getPreferencesValue('INTERWIKIPLUGIN_RULESTOPIC')
          || 'InterWikis'
    );

    my $text = Foswiki::Func::readTopicText( $interWeb, $interTopic, undef, 1 );

    # '| alias | URL | ...' table and extract into 'alias', "URL" list
    $text =~
s/^\|\s*$sitePattern\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|.*$/_map($1,$2,$3)/mego;

    $sitePattern = "(" . join( "|", keys %interSiteTable ) . ")";
    return 1;
}

sub _map {
    my ( $site, $url, $tooltip ) = @_;
    if ($site) {
        $interSiteTable{$site}{url}     = $url     || '';
        $interSiteTable{$site}{tooltip} = $tooltip || '';
    }
    return '';
}

sub preRenderingHandler {

    # ref in [[ref]] or [[ref][
    $_[0] =~
s/(\[\[)$sitePattern:$pagePattern(\]\]|\]\[[^\]]+\]\])/_link($1,$2,$3,$4)/geo;

    # ref in text
    $_[0] =~
s/(^|[\s\-\*\(])$sitePattern:$pagePattern(?=[\s\.\,\;\:\!\?\)\|]*(\s|$))/_link($1,$2,$3)/geo;
}

sub _link {
    my ( $prefix, $site, $page, $postfix ) = @_;

    $prefix  ||= '';
    $site    ||= '';
    $page    ||= '';
    $postfix ||= '';

    my $text = $prefix;
    if ( defined( $interSiteTable{$site} ) ) {
        my $tooltip = $interSiteTable{$site}{tooltip};
        my $url     = $interSiteTable{$site}{url};
        $url .= $page unless ( $url =~ /\$page/ );
        my $label = '$site:$page';

        if ($postfix) {

            # [[...]] or [[...][...]] interwiki link
            $text = '';
            if ( $postfix =~ /^\]\[([^\]]+)/ ) {
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
    }
    else {
        $text .= "$site\:$page$postfix";
    }
    return $text;
}

1;
