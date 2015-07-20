#! /usr/bin/env perl
#
# Author: Crawford Currie http://c-dot.co.uk
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2015 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

#
# Run from the root of a Foswiki install to generate a test web suitable
# for testing bulk_copy.pl
#
# Two parameters, the charset of the source install and the charset of the
# dest install
# e.g.
#
# $ perl tools/gen_bulk_copy_test_web.pl UTF-8 ISO-8859-1
#
# will generate a web with filenames encoded using UTF-8, but only using
# codepoints that map to ISO-8859-1
#
# If there is no second parameter, the same charset is assumed.
# If there are no parameters, the charset is taken from the LC_CTYPE.
#
# The web generated is called Testbulkcopy.
use strict;
use Encode;
use POSIX qw(locale_h);
use locale;

die "Not at the root of a conventional Foswiki install"
  unless -d "data" && -d "pub";

our $old_locale = setlocale(LC_CTYPE);
die "Could not determine locale"
  unless ( $old_locale && $old_locale =~ /^(.*?)\.(.*)$/ );

our ( $lang, $old_encoding ) = ( $1, $2 );

our $source_encoding = $ARGV[0] || $old_encoding;
our $dest_encoding   = $ARGV[1] || $source_encoding;
our $time            = 1422748800;

sub recode {
    my $s = shift;
    return Encode::encode( $old_encoding,
        Encode::decode( $source_encoding, $s, Encode::FB_CROAK ) );
}

sub report {
    my $s = join( ' ', @_ );
    return unless $s =~ /\S/;
    $s =~ s/\s*$//s;
    print recode($s) . "\n";
}

our $locale = "$lang.$source_encoding";
our $setlocale = POSIX::setlocale( LC_CTYPE, $locale );
die "Failed to set locale $locale. Is locale installed?" unless $setlocale;
report "Source encoding is $source_encoding";
report "Destination encoding is $dest_encoding";

# Explore the encodings
our $chlim = 65536;
my %classes = (
    'upper' => '',
    'lower' => '',
    'alnum' => '',
    'ascii' => '',
    'digit' => ''
);
my %rex = map { $_ => "[:$_:]" } keys %classes;

report "Exploring character sets... $source_encoding";
for ( $chlim = 0 ; $chlim < 65536 ; $chlim++ ) {
    my $uch = chr($chlim);
    eval {
        my $uuch = $uch;
        my $octets =
          Encode::encode( $source_encoding, $uuch, Encode::FB_CROAK );
    };
    if ($@) {
        print "SKIP $chlim\n" if $chlim < 256;
        next;
    }
    foreach my $class ( keys %classes ) {
        $classes{$class} .= $uch if $uch =~ /[$rex{$class}]/;
    }
}
report "...can use $chlim characters";
foreach my $c ( keys %classes ) {
    report "......", length( $classes{$c} ), $c;
}

# Make N characters in the source encoding
sub make_chars {
    my $n   = shift;
    my $chs = join( '', map { $classes{$_} } @_ );
    my $l   = length($chs);
    my $rex = quotemeta($chs);
    $n ||= 1;
    my $tries = 0;
    my $str   = '';
    while ( length($str) < $n ) {
        $tries++;
        my $codepoint = my $uch = substr( $chs, int( rand($l) ), 1 );

        # Avoid ASCII until we've tried lots of other things
        if ( $uch =~ /[[:ascii:]]/ ) {

            #report "$tries:",ord($uch),"$uch isascii";
            next unless $tries > $l;
            report "forced to pick", ord($uch), "$uch isascii";
        }
        $str .= Encode::encode( $source_encoding, $uch, Encode::FB_CROAK );
    }
    return $str;
}

# Make a 4-character wikiword
sub make_wikiword {
    return
        make_chars( 1, 'upper' )
      . make_chars( 1, 'lower', 'digit' )
      . make_chars( 1, 'upper' )
      . make_chars( 1, 'alnum' );
}

sub ci {
    my $path = shift;
    die "ci requires a path" unless -f $path;
    report `ci -q -mcomment -f -t-none -wProjectContributor $path`;
    report `rm -f $path`;
    report `co -q -l $path`;
    chmod( 0644, $path );
}

# Make a valid web name that incorporates dodgy chars. This doesn't work
# in 1.1.9 - it just doesn't see the web when copying because the regexes
# in 1.1.9 are fundamentally borked.
#our $web = 'System';
#while (-d "data/$web") {
#    $web = "Testbulkcopy".make_chars(5, 'alnum');
#}
our $web = "Testbulkcopy";
report "Web name is $web";

our @made;

sub make_topic {
    my ( $name, $text, $rev ) = @_;
    my $path = "data/$web/"
      . Encode::encode( $source_encoding, $name, Encode::FB_CROAK );
    push( @made, "topic $name version $rev " );
    open( F, ">:encoding($source_encoding)", "$path.txt" )
      || die recode("Failed $path $!");
    print F <<THIS;
%META:TOPICINFO{author="ProjectContributor" date="$time" format="1.1" version="$rev"}%
$text
THIS
    $time++;
    close(F);
    ci("$path.txt");
}

sub make_attachment {
    my ( $topic, $name, $data, $rev ) = @_;
    my $path = "pub/$web/"
      . Encode::encode( $source_encoding, $topic, Encode::FB_CROAK );
    mkdir $path;
    my $path =
      $path . Encode::encode( $source_encoding, $name, Encode::FB_CROAK );
    open( F, ">", $path ) || die recode("Failed $path $!");
    binmode(F);
    print F $data;
    close(F);
    ci($path);
    push( @made, "attachment $path:$rev" );
}

mkdir "data/$web";
mkdir "pub/$web";
make_topic( "WebPreferences", "REV 1", 1 );

# Make a topic that has no history
make_topic( "NoHistory", 'REV 4', 4 );

# Make a history that has no topic
make_topic( "NoTopic", 'History only, no cache', 4 );
unlink "data/$web/NoTopic.txt";

# Make a history that has out-of-sequence TOPICINFO
make_topic( "RevHistory", "REV 1", 3 );
make_topic( "RevHistory", "REV 2", 2 );
make_topic( "RevHistory", "REV 3", 1 );

# Make a web with an evil name
my $evil =
    substr( $classes{upper}, -10, 5 )
  . substr( $classes{lower}, -5 )
  . substr( $classes{upper}, -5 );
mkdir "data/$web/$evil";
make_topic( "$evil/WebPreferences", 'REV 1', 1 );

# Make a topic with the same name
make_topic( "$evil/$evil", $evil, 1 );

# Make a web with the same name

# Make a topic with attachments
my $att_name = make_chars( 5, 'alnum' ) . '.att';
make_topic( "HasAttachments", <<CONTENT, 1 );
%META:FILEATTACHMENT{name="$att_name" comment="logo" user="ProjectContributor" version="1" date="$time"}%
REV 1
CONTENT
$time++;

make_topic( "HasAttachments", <<CONTENT, 2 );
REV 2
%META:FILEATTACHMENT{name="$att_name" comment="logo" user="ProjectContributor" version="4" date="$time"}%
CONTENT
$time++;

make_attachment( "HasAttachments", $att_name, 'REV 1', 1 );
make_attachment( "HasAttachments", $att_name, 'REV 2', 2 );
make_attachment( "HasAttachments", $att_name, 'REV 3', 3 );
make_attachment( "HasAttachments", $att_name, 'REV 4', 4 );

my $made = join( "\n", map { "   * $_" } @made );
make_topic( "WebHome", <<DATA, 1 );
This is an automatically generated test web, designed to test the
ools/bulk_copy.pl script. It contains topic histories stored using RCS,
and targets particular types of damage that can occur.

The contents should be:
$made

The evil subweb is called $evil

DATA

1;
