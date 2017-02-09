# See bottom of file for license and copyright information

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

our $VERSION           = '1.24';
our $RELEASE           = '8 Feb 2017';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
'Link !ExternalSite:Page text to external sites based on aliases defined in a rules topic';

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
    %interSiteTable = ();
    $sitePattern    = "([[:upper:]][[:alnum:]]+)";
    $pagePattern =
        "((?:'[^']*')|(?:\"[^\"]*\")|(?:[[:alnum:]\_\~\%\/][[:alnum:]"
      . '"\'\.\/\+\_\~\,\&\;\:\=\!\?\%\#\@\-\(\)]*?))';

    # Get plugin preferences from InterwikiPlugin topic
    $interLinkFormat =
      Foswiki::Func::getPreferencesValue('INTERWIKIPLUGIN_INTERLINKFORMAT')
      || '<a class="interwikiLink" href="$url" title="$tooltip"><noautolink>$label</noautolink></a>';

    my $rulesTopicPref =
      Foswiki::Func::getPreferencesValue('INTERWIKIPLUGIN_RULESTOPIC')
      || 'InterWikis';
    my @rulesTopics = split( ',', $rulesTopicPref );
    foreach my $topic (@rulesTopics) {
        $topic = _trimWhitespace($topic);

        my ( $interWeb, $interTopic ) =
          Foswiki::Func::normalizeWebTopicName( $installWeb, $topic );

        if (
            !Foswiki::Func::checkAccessPermission(
                'VIEW', $user, undef, $interTopic, $interWeb
            )
          )
        {
            Foswiki::Func::writeWarning(
"InterwikiPlugin: user '$user' did not have permission to read the rules topic at '$interWeb.$interTopic'"
            );
            return 1;
        }
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( $interWeb, $interTopic );

        # '| alias | URL | ...' table and extract into 'alias', "URL" list
        $text =~ s/
              ^\|\s*              # Start of table
              $sitePattern
              \s*\|\s*            # Column separator
              (.*?)               # URL
              \s*\|\s*            # Column separator
              (.*?)               # tooltip
              (?:
                  \s*\|\s*         # Colunmn separator
                  ([^\|\n]+)       # Not a separator or end of line
              )?
              \s*\|.*?           # Last column separator
            /_map($1,$2,$3,$4)/megx;

    }

    $sitePattern = "(" . join( "|", keys %interSiteTable ) . ")";

    return 1;
}

sub _map {
    my ( $site, $url, $tooltip, $format ) = @_;
    if ($site) {
        $interSiteTable{$site}{url}     = $url     || '';
        $interSiteTable{$site}{tooltip} = $tooltip || '';
        if ( defined $format ) {
            $format =~ s/\s*$//g;    # remove trailing spaces
            $interSiteTable{$site}{format} = $format;
        }
    }
    return '';
}

sub preRenderingHandler {

    # ref in [[ref]] or [[ref][
    $_[0] =~
s/(\[\[)$sitePattern:$pagePattern(\]\]|\]\[[^\]]+\]\])/_link($1,$2,$3,$4)/ge;

    # ref in text
    $_[0] =~
s/(^|[\s\-\*\=\_\(])$sitePattern:$pagePattern(?=[\s\.\,\;\:\!\?\)\*\=\_\|]*(\s|$))/_link($1,$2,$3)/ge;

    return;
}

sub _link {
    my ( $prefix, $site, $page, $postfix ) = @_;

    $prefix  ||= '';
    $site    ||= '';
    $page    ||= '';
    $postfix ||= '';

    my $upage = $page;
    if ( $page =~ m/^['"](.*)["']$/ ) {
        $page  = $1;
        $upage = Foswiki::urlEncode($1);
    }

    my $text = $prefix;
    if ( defined( $interSiteTable{$site} ) ) {
        my $tooltip = $interSiteTable{$site}{tooltip};
        my $url     = $interSiteTable{$site}{url};

        #$url .= $page unless ( $url =~ m/\$page/ );

        if ( $url =~ m/\$page/ ) {
            $url =~ s/\$page/$upage/g;
        }
        else {
            $url .= $upage;
        }
        my $label = '$site:$page';

        if ($postfix) {

            # [[...]] or [[...][...]] interwiki link
            $text = '';
            if ( $postfix =~ m/^\]\[([^\]]+)/ ) {
                $label = $1;
            }
        }

        my $format = $interSiteTable{$site}{format} || $interLinkFormat;
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
    $text = Foswiki::Func::expandCommonVariables($text);
    return $text;
}

sub _trimWhitespace {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
