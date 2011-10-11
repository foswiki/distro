# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Crawford Currie, http://c-dot.co.uk
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Plugins::TestFixturePlugin;

use strict;

use Foswiki::Func                                   ();    # The plugins API
use Foswiki::Attrs                                  ();
use Foswiki::Plugins::TestFixturePlugin::HTMLDiffer ();

# This is a test plugin designed to interact with Foswiki testcases.
# It should NOT be shipped with a release.
# It implements all possible plugin handlers, and generates selected
# results that interact with test cases in the TestCases web.
#
# To use this plugin, you will have to:
# 1 Have Algorithm::Diff installed
# 2 Create an empty topic in the 'Foswiki' web of your test installation,
#   called TestFixturePlugin.txt
#
# DO NOT USE THIS PLUGIN IN A USER INSTALLATION. IT IS DESIGNED FOR
# FOSWIKI CORE TESTING ONLY!!!
#
# The idea is that topics contain blocks marked by <!-- expected -->
# and <!-- actual --> tags. These blocks are compared in the
# endRenderingHandler. The comparison is only done when you provide
# the "test=compare" parameter on the URL.
#
# Stubs are provided for all the published handlers so you can hack
# the plugin to do other tests as well.
#
use vars qw(
  $installWeb $VERSION $RELEASE $pluginName
  $topic $web $user $installWeb
);

use CGI qw( :any );

$VERSION = '$Rev$';
$RELEASE = '22 Jul 2009';

$pluginName = 'TestFixturePlugin';

# Parse a topic extracting bracketed subexpressions
sub _parse {
    my ( $text, $tag ) = @_;

    $text =~ s/\r//g;
    $text =~ s/\t/   /g;
    $text =~ s/[^ -~\n]/./g;
    $text =~ s/<nop>//g;

    my @list = ();
    my $opt;
    my $lastTok;
    my $gathering = 1;

    foreach my $tok ( split( /(<!--\s*\/?$tag.*?-->)/, $text ) ) {
        if ( $tok =~ /<!--\s*$tag(.*?)-->/ ) {
            $opt       = $1;
            $gathering = 1;
        }
        elsif ( $tok =~ /<!--\s*\/$tag\s*-->/ ) {
            throw Error::Simple(
                "<!-- /$tag --> found without matching <!-- $tag --> $lastTok")
              unless ($gathering);
            push( @list, { text => $lastTok, options => $opt } );
            $gathering = 0;
        }
        elsif ($gathering
            && $tok =~ /^<!--\/?\s*(expected|actual).*?-->$/ )
        {
            throw Error::Simple(
                "$tok encountered when in open <!-- $tag --> bracket");
        }
        $lastTok = $tok;
    }
    if ($gathering) {
        push( @list, { text => $lastTok, options => $opt } );
    }

    return \@list;
}

# compare the expected and actual contents
sub _compareExpectedWithActual {
    my ( $expected, $actual, $topic, $web ) = @_;
    my $errors = '';

    unless ( $#$actual == $#$expected ) {
        my $mess =
"Numbers of actual ($#$actual) and expected ($#$expected) blocks don't match<table width=\"100%\"><th>Expected</th><th>Actual</th></tr>";
        for my $i ( 0 .. $#$actual ) {
            my $e  = $expected->[$i];
            my $et = $e->{text};
            my $at = $actual->[$i]->{text};
            $et =~ s/&/&amp;/g;
            $et =~ s/</&lt;/g;
            $at =~ s/&/&amp;/g;
            $at =~ s/</&lt;/g;
            $mess .= "<tr><td>$et</td><td>$at</td></tr>";
        }
        return "$mess</table>";
    }

    for my $i ( 0 .. $#$actual ) {
        my $e  = $expected->[$i];
        my $et = $e->{text};
        if ( $e->{options} =~ /\bagain\b/ ) {
            my $prev = $expected->[ $i - 1 ];
            $et = $prev->{text};

            # inherit the text so that the next 'again' will see the
            # previous text
            $e->{text} = $et;
        }
        if ( $e->{options} =~ /\bexpand\b/ ) {
            $et = Foswiki::Func::expandCommonVariables( $et, $topic, $web );
        }
        my $at      = $actual->[$i]->{text};
        my $control = {
            options  => $e->{options},
            reporter => \&_processDiff,
            result   => ''
        };

        if (
            Foswiki::Plugins::TestFixturePlugin::HTMLDiffer::diff(
                $et, $at, $control
            )
          )
        {

            $errors .= CGI::table(
                { border => 1 },
                CGI::Tr(
                    {},
                    CGI::th( {}, 'Expected ' . $e->{options} )
                      . $control->{result}
                )
            );
        }
    }

    return $errors;
}

sub _processDiff {
    my ( $code, $a, $b, $opts ) = @_;

    if ($code) {
        $opts->{result} .=
          CGI::Tr( {},
            CGI::td( { valign => 'top', colspan => 2 }, CGI::code($a) ) );
    }
    else {
        $opts->{result} .= CGI::Tr( { valign => 'top' },
            CGI::td( { bgcolor => '#99ffcc' }, CGI::pre( {}, $a ) ) );
        $opts->{result} .= CGI::Tr( { valign => 'top' },
            CGI::td( { bgcolor => '#ffccff' }, CGI::pre( {}, $b ) ) );
    }
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    Foswiki::Func::registerTagHandler( 'STRICTTAG', \&_STRICTTAG );

    return 1;
}

sub commonTagsHandler {
    $_[0] =~ s/%FRIENDLYTAG{(.*?)}%/&_extractParams($1)/ge;
}

sub _extractParams {
    my $params = new Foswiki::Attrs( shift, 1 );
    return $params->stringify();
}

sub _STRICTTAG {
    my ( $session, $params ) = @_;

    return $params->stringify();
}

my $iph = 0;
my $oph = 0;

sub preRenderingHandler {
    $iph = 0;
    $oph = 0;
}

sub outsidePREHandler {

    # Replace the text "%outsidePREHandler%" with some
    # recognisable text.
    $_[0] =~
s/%outsidePreHandler(\d+)%/$oph++;"$1OPH${oph}_line1\n$1OPH${oph}_line2\n$1OPH${oph}_line3\n"/ge;
}

sub insidePREHandler {

    # Replace the text "%insidePREHandler%" with some
    # recognisable text.
    $_[0] =~
s/%insidePreHandler(\d+)%/$iph++;"$1IPH${iph}_line1\n$1IPH${iph}_line2\n$1IPH${iph}_line3\n"/ge;
}

sub postRenderingHandler {
    my $q = Foswiki::Func::getCgiQuery();
    my $t;
    $t = $q->param('test') if ($q);
    $t = '' unless $t;

    if ( $t eq 'compare' && $_[0] =~ /<!--\s*actual\s*-->/ ) {
        my ( $meta, $expected ) = Foswiki::Func::readTopic( $web, $topic );
        my $res = _compareExpectedWithActual(
            _parse( $expected, 'expected' ),
            _parse( $_[0],     'actual' ),
            $topic, $web
        );
        if ($res) {
            my $failmsg =
              Foswiki::Func::expandCommonVariables('%FAILMSG{default=""}%');
            $res =
              "<font color=\"red\">TESTS FAILED</font><p />$failmsg<p />$res";
        }
        else {
            $res = "<font color=\"green\">ALL TESTS PASSED</font>";
        }
        $_[0] = $res;
    }
}

1;
