#
# Copyright (C) 2004, 2006 Crawford Currie, http://c-dot.co.uk
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
package Unit::HTMLDiffer;
use base 'HTML::Parser';

# Module for comparing two blocks of HTML to see if
# they would render to the same thing.

use strict;
use Algorithm::Diff;
use HTML::Entities;

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new(
        start_h   => [ \&_openTag,  'self,tagname,attr' ],
        end_h     => [ \&_closeTag, 'self,tagname' ],
        default_h => [ \&_text,     'self,text,is_cdata' ]
    );

    $this->xml_mode(1);
    $this->unbroken_text(1);

    return $this;
}

# Convert HTML text into a stream of HTML items
sub _convert {
    my ( $this, $text ) = @_;

    $this->{items}         = ();
    $this->{last_was_text} = 0;
    $this->parse($text);
    $this->eof();
    return \@{ $this->{items} };
}

sub _openTag {
    my ( $this, $tag, $attrs ) = @_;
    my $a = join( ' ', map { $_ . '=' . $attrs->{$_} } sort keys %$attrs );
    $a = ' ' . $a if $a =~ /\S/;
    $this->{last_was_text} = 0;
    push( @{ $this->{items} }, '<' . $tag . $a . '>' );
}

sub _closeTag {
    my ( $this, $tag ) = @_;

    $this->{last_was_text} = 0;
    push( @{ $this->{items} }, '</' . $tag . '>' );
}

sub _text {
    my ( $this, $text, $is_cdata ) = @_;
    my $sep = '';

    unless ($is_cdata) {
        $text =~ s/^\s*(.*?)\s*$/$1/;
        $text =~ s/\s+/ /gs;

        # normalise entities
        $text = HTML::Entities::decode_entities($text);
        return unless $text =~ /\S/;
        $sep = ' ';
    }

    if ( $this->{last_was_text} ) {
        push( @{ $this->{items} }, pop( @{ $this->{items} } ) . $sep . $text );
    }
    else {
        push( @{ $this->{items} }, $text );
    }
    $this->{last_was_text} = 1;
}

sub _rexeq {
    my ( $a, $b ) = @_;
    my @res = ();
    while ( $a =~ s/\@REX\((.*?)\)/"!REX".scalar(@res)."!"/e ) {
        push( @res, $1 );
    }

    # escape regular expression chars
    $a =~ s/([\[\]\(\)\\\?\*\+\.\/\^\$])/\\$1/g;
    $a =~ s/\@DATE/[0-3]\\d [JFMASOND][aepuco][nbrylgptvc] [12][09]\\d\\d/g;
    $a =~ s/\@TIME/[012]\\d:[0-5]\\d/g;
    my $wikiword = '[A-Z]+[a-z]+[A-Z]+\w+';
    $a =~ s/\@WIKIWORD/$wikiword/og;
    my $satWord = '<a [^>]*class="foswikiLink"[^>]*>' . $wikiword . '</a>';
    my $unsatWord =
        '<span [^>]*class="foswikiNewLink"[^>]*>'
      . $wikiword
      . '<a [^>]*><sup>\?</sup></a
</span>';
    $a        =~ s/!REX(\d+)!/$res[$1]/g;
    $a        =~ s!/!\/!g;
    return $b =~ /^$a$/;
}

sub diff {
    my ( $this, $expected, $actual, $opts ) = @_;
    my $failed   = 0;
    my $rex      = ( $opts->{options} =~ /\brex\b/ );
    my $okset    = "";
    my $reporter = $opts->{reporter};

    my $e     = $this->_convert($expected);
    my $a     = $this->_convert($actual);
    my $diffs = Algorithm::Diff::sdiff( $e, $a );
    foreach my $diff (@$diffs) {
        my $a = $diff->[1] || '';
        $a =~ s/^\s+//;
        $a =~ s/\s+$//s;
        my $b = $diff->[2] || '';
        $b =~ s/^\s+//;
        $b =~ s/\s+$//s;
        my $ok = 0;

        if (   $diff->[0] eq 'u'
            || $a eq $b
            || $rex && _rexeq( $a, $b ) )
        {
            $ok = 1;
        }
        if ($ok) {
            $okset .= $a . ' ';
        }
        else {
            if ($okset) {
                if ($reporter) {
                    &$reporter( 1, $okset, undef, $opts );
                }
                $okset = "";
            }
            if ($reporter) {
                &$reporter( 0, $a, $b, $opts );
            }
            $failed = 1;
        }
    }
    return 0 unless $failed;
    if ( $okset && $reporter ) {
        &$reporter( 1, $okset, undef, $opts );
    }
    return $failed;
}

sub defaultReporter {
    my ( $code, $a, $b, $opts ) = @_;

    if ($code) {
        $opts->{result} .= $a;
    }
    else {
        $opts->{result} .= "\n- $a\n+ $b\n";
    }
}

# Parse the expected HTML
# Parse the actual HTML
# Scan the expected HTML and see if we can match the actual
sub html_matches {
    my ( $this, $e, $a ) = @_;
    my $expected = $this->_convert($e);
    my $actual   = $this->_convert($a);

    # see if the $actual contains $expected as a stream
    foreach my $i ( 0 .. $#$actual ) {
        return 0 if ( scalar(@$actual) - $i < scalar(@$expected) );
        my $matches = 1;
        foreach my $j ( 0 .. $#$expected ) {
            if ( $expected->[$j] ne $actual->[ $i + $j ] ) {
                $matches = 0;
                last;
            }
        }
        return 1 if $matches;
    }
    return 0;

}

1;
