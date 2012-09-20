#! /usr/bin/perl
#
# Static TML -> HTML converter
#
# cd to the tools directory to run it

use strict;

do '../bin/setlib.cfg';
use Foswiki::Plugins::WysiwygPlugin::TML2HTML;
my $conv = new Foswiki::Plugins::WysiwygPlugin::TML2HTML();
undef $/;
my $html = <>;
my $tml = $conv->convert( $html, { very_clean => 1 } );
print $tml;
