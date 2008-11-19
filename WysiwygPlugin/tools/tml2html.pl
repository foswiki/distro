#!/usr/bin/perl
#
# Static TML -> HTML converter
#
# cd to the tools directory to run it

do '../bin/setlib.cfg';
require Foswiki::Plugins::WysiwygPlugin::TML2HTML;
my $conv = new Foswiki::Plugins::WysiwygPlugin::TML2HTML();
undef $/;
my $html = <>;
my $tml = $conv->convert( $html, { very_clean=>1 } );
print $tml;
