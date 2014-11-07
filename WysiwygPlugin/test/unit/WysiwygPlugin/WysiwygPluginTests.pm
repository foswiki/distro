# See bottom of file for license and copyright information

# Tests for the plugin component
#
package WysiwygPluginTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Unit::Request();
use Unit::Response();
use Foswiki();
use Foswiki::Plugins::WysiwygPlugin();
use Foswiki::Plugins::WysiwygPlugin::Handlers();
use Foswiki::Plugins::WysiwygPlugin::HTML2TML::WC;
use Encode();
use Carp();

my @unicodeCodepointsForWindows1252 = (

    # From http://www.alanwood.net/demos/ansi.html
    # unicode   windows-1252
    8364,    # 128
    8218,    # 130
    402,     # 131
    8222,    # 132
    8230,    # 133
    8224,    # 134
    8225,    # 135
    710,     # 136
    8240,    # 137
    352,     # 138
    8249,    # 139
    338,     # 140
    381,     # 142
    8216,    # 145
    8217,    # 146
    8220,    # 147
    8221,    # 148
    8226,    # 149
    8211,    # 150
    8212,    # 151
    732,     # 152
    8482,    # 153
    353,     # 154
    8250,    # 155
    339,     # 156
    382,     # 158
    376,     # 159
);

my $UI_FN;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('save');

    $Foswiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;
    Foswiki::Plugins::WysiwygPlugin::HTML2TML::WC::test_reset();
    $Foswiki::cfg{Site}{CharSet}   = undef;
    $Foswiki::cfg{Site}{Locale}    = undef;
    $Foswiki::cfg{Site}{UseLocale} = 0;

    return;
}

sub anal {
    my $out = shift;
    my @s;
    foreach my $i ( split( //, $out ) ) {
        my $n = ord($i);
        if ( $n > 127 ) {
            push( @s, $n );
        }
        else {
            push( @s, $i );
        }
    }
    return join( ' ', @s );
}

sub save_testCharsetCodesRange {
    my ( $this, $charset, $firstchar, $lastchar ) = @_;
    my @test;
    for ( my $i = $firstchar ; $i <= $lastchar ; $i++ ) {
        push( @test, Encode::decode( _perlEncodeCharset($charset), chr($i) ) );
    }
    my $text = join( '', @test ) . ".";

    $this->save_test( $charset, $text, $text );

    return;
}

sub save_testUnicodeCodepointsRange {
    my ( $this, $charset, $firstchar, $lastchar ) = @_;

    my @test;
    for ( my $i = $firstchar ; $i <= $lastchar ; $i++ ) {
        push( @test, chr($i) );
    }
    my $text = join( '', @test ) . ".";

    $this->save_test( $charset, $text, $text );

    return;
}

sub _perlEncodeCharset {
    my $charset = shift;

    # The default encoding is 'iso-8859-1'
    # Foswiki treats that encoding like windows-1252, as do browsers
    # Perl's Encode library treats them differently
    $charset = 'windows-1252' if not $charset or $charset eq 'iso-8859-1';
    return $charset;
}

# $input and $expectedOutput contain unicode codepoints;
# they are wide characters, NOT utf-8 encoded
sub save_test {
    my ( $this, $charset, $input, $expectedOutput, $topicName ) = @_;
    my ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( $this->{test_web},
        $topicName || 'WysiwygPluginTest' );

    # Is this enough? Regexes are inited before we get here, aren't they?
    $Foswiki::cfg{Site}{CharSet} = $charset;

    my $t =
      $charset
      ? Encode::encode( _perlEncodeCharset($charset), $input )
      : $input;

    my $e =
      $charset
      ? Encode::encode( _perlEncodeCharset($charset), $expectedOutput )
      : $expectedOutput;

    my $query = Unit::Request->new(
        {
            'wysiwyg_edit' => [1],
            'action_save'  => [1],
            'text'         => [$t],
        }
    );
    $query->path_info("/$web/$topic");
    $query->param( text => $t );
    $query->method('GET');

    $this->createNewFoswikiSession( 'guest', $query );
    $Foswiki::Plugins::SESSION = $this->{session};

    # charset definition affects output, so it is a response method and
    # can only be adjusted after creating session object.
    $Foswiki::Plugins::SESSION->{response}->charset($charset) if $charset;

    require Foswiki::UI::Save;

    my ( $responseText, $result, $stdout, $stderr ) = $this->captureWithKey(
        save => sub {
            no strict 'refs';
            &{$UI_FN}($Foswiki::Plugins::SESSION);
            use strict 'refs';
            $Foswiki::engine->finalize(
                $Foswiki::Plugins::SESSION->{response},
                $Foswiki::Plugins::SESSION->{request}
            );
        }
    );

    my ( $meta, $out ) = Foswiki::Func::readTopic( $web, $topic );
    $this->assert_not_null($out);
    $out =~ s/\s*$//s;

    $this->assert( $e eq $out, "'" . anal($out) . "' !=\n'" . anal($e) . "'" );

    return;
}

sub TML2HTML_testCharsetCodesRange {
    my ( $this, $charset, $firstchar, $lastchar ) = @_;
    my @test;
    for ( my $i = $firstchar ; $i <= $lastchar ; $i++ ) {
        push( @test, Encode::decode( _perlEncodeCharset($charset), chr($i) ) );
    }
    my $text = join( '', @test ) . ".";

    $this->TML2HTML_test( $charset, $text, $text );

    return;
}

sub TML2HTML_testUnicodeCodepointsRange {
    my ( $this, $charset, $firstchar, $lastchar ) = @_;

    my @test;
    for ( my $i = $firstchar ; $i <= $lastchar ; $i++ ) {
        push( @test, chr($i) );
    }
    my $text = join( '', @test ) . ".";

    $this->TML2HTML_test( $charset, $text, $text );

    return;
}

# $input and $expectedOutput contain unicode codepoints;
# they are wide characters, NOT utf-8 encoded
sub TML2HTML_test {
    my ( $this, $charset, $input, $expectedOutput ) = @_;

    # Is this enough? Regexes are inited before we get here, aren't they?
    $Foswiki::cfg{Site}{CharSet} = $charset;

    my $query = Unit::Request->new(
        {
            'wysiwyg_edit' => [1],

            # REST parameters are always UTF8 encoded
            'text' => [ Encode::encode_utf8($input) ],
        }
    );
    $query->method('GET');

    $this->createNewFoswikiSession( 'guest', $query );
    $this->{session}{response}->charset($charset)
      if $charset;    # why? REST responses are supposed to be UTF-8 encoded

    my ( $out, $result ) = $this->captureWithKey(
        save => sub {
            my $ok = Foswiki::Plugins::WysiwygPlugin::Handlers::REST_TML2HTML(
                $this->{session}, undef, undef, $this->{session}{response} );
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
            return $ok;
        }
    );

    $this->assert( !$result, $result );

    # Strip ASCII header
    $this->assert_matches( qr/Content-Type: *text\/plain; *charset=UTF-8/i,
        $out, anal($out) );
    $out =~ s/^.*?\r\n\r\n//s;

    $out = Encode::decode_utf8($out);

    my $id = "<!--$Foswiki::Plugins::WysiwygPlugin::Handlers::SECRET_ID-->";
    $this->assert( $out =~ s/^\s*$id<p>[ \t\n]*//s, anal($out) );
    $out =~ s/[ \t\n]*<\/p>\s*$//s;

    $this->assert( $expectedOutput eq $out,
        "'" . anal($out) . "' !=\n'" . anal($expectedOutput) . "'" );

    return;
}

sub HTML2TML_testCharsetCodesRange {
    my ( $this, $charset, $firstchar, $lastchar ) = @_;
    my @test;
    for ( my $i = $firstchar ; $i <= $lastchar ; $i++ ) {
        push( @test, Encode::decode( _perlEncodeCharset($charset), chr($i) ) );
    }
    my $text = join( '', @test ) . ".";

    $this->HTML2TML_test( $charset, $text, $text );

    return;
}

sub HTML2TML_testUnicodeCodepointsRange {
    my ( $this, $charset, $firstchar, $lastchar ) = @_;

    my @test;
    for ( my $i = $firstchar ; $i <= $lastchar ; $i++ ) {
        push( @test, chr($i) );
    }
    my $text = join( '', @test ) . ".";

    $this->HTML2TML_test( $charset, $text, $text );

    return;
}

# $input and $expectedOutput contain unicode codepoints;
# they are wide characters, NOT utf-8 encoded
sub HTML2TML_test {
    my ( $this, $charset, $input, $expectedOutput ) = @_;

    # Is this enough? Regexes are inited before we get here, aren't they?
    $Foswiki::cfg{Site}{CharSet} = $charset;

    my $query = Unit::Request->new(
        {
            'wysiwyg_edit' => [1],

            # REST parameters are always UTF8 encoded
            'text' => [ Encode::encode_utf8($input) ],
        }
    );
    $query->method('GET');
    $this->createNewFoswikiSession( 'guest', $query );
    $this->{session}{response}->charset($charset)
      if $charset;    # why? REST responses are supposed to be UTF-8 encoded

    my ( $out, $result ) = $this->captureWithKey(
        save => sub {
            my $ok = Foswiki::Plugins::WysiwygPlugin::Handlers::REST_HTML2TML(
                $this->{session}, undef, undef, $this->{session}{response} );
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
            return $ok;
        }
    );

    $this->assert( !$result, $result );

    # Strip ASCII header
    $this->assert_matches( qr/Content-Type: *text\/plain; *charset=UTF-8/,
        $out, anal($out) );
    $out =~ s/^.*?\r\n\r\n//s;

    $out = Encode::decode_utf8($out);

    $out =~ s/\s*$//s;

    $this->assert_str_equals( $expectedOutput, $out,
        "'" . anal($out) . "' !=\n'" . anal($expectedOutput) . "'" );

    return;
}

# tests for various charsets
sub test_restTML2HTML_undef {
    my $this = shift;
    $this->TML2HTML_testUnicodeCodepointsRange( undef, 160, 255 );

    # Browsers commonly treat iso-8859-1 as if it is windows-1252
    # and so does Foswiki
    my $unicodeOfWindows1252 =
      join( '', map { chr($_) } @unicodeCodepointsForWindows1252 );

    $this->TML2HTML_test( undef, $unicodeOfWindows1252, $unicodeOfWindows1252 );

    $this->TML2HTML_test( undef, chr(0x3B1) . chr(0x2640), '&alpha;&#x2640;' );

    return;
}

sub test_restTML2HTML_iso_8859_1 {
    my $this = shift;
    $this->TML2HTML_testUnicodeCodepointsRange( 'iso-8859-1', 160, 255 );

    # Browsers commonly treat iso-8859-1 as if it is windows-1252
    # and so does Foswiki
    my $unicodeOfWindows1252 =
      join( '', map { chr($_) } @unicodeCodepointsForWindows1252 );

    $this->TML2HTML_test( 'iso-8859-1', $unicodeOfWindows1252,
        $unicodeOfWindows1252 );

    $this->TML2HTML_test( 'iso-8859-1', chr(0x3B1) . chr(0x2640),
        '&alpha;&#x2640;' );

    return;
}

sub test_restTML2HTML_iso_8859_7 {
    my $this = shift;

    $this->TML2HTML_testCharsetCodesRange( 'iso-8859-7', 160, 173 );
    $this->TML2HTML_testCharsetCodesRange( 'iso-8859-7', 175, 209 );
    $this->TML2HTML_testCharsetCodesRange( 'iso-8859-7', 211, 254 );

    return;
}

sub test_restTML2HTML_iso_8859_15 {
    my $this = shift;
    $this->TML2HTML_testUnicodeCodepointsRange( 'iso-8859-15', 127, 163 );
    $this->TML2HTML_testUnicodeCodepointsRange( 'iso-8859-15', 169, 179 );
    $this->TML2HTML_testUnicodeCodepointsRange( 'iso-8859-15', 181, 183 );
    $this->TML2HTML_testUnicodeCodepointsRange( 'iso-8859-15', 191, 255 );

    # These are the codes that are different to iso-8859-1, and thus
    # different to unicode
    for my $code ( 0xA4, 0xA6, 0xA8, 0xB4, 0xBC, 0xBD, 0xBE ) {
        $this->TML2HTML_testCharsetCodesRange( 'iso-8859-15', $code, $code );
    }

    return;
}

sub test_restTML2HTML_utf_8 {
    my $this = shift;
    $this->TML2HTML_testUnicodeCodepointsRange( 'utf-8', 127, 300 );
    $this->TML2HTML_testUnicodeCodepointsRange( 'utf-8', 301, 400 );
    $this->TML2HTML_testUnicodeCodepointsRange( 'utf-8', 401, 500 );

    # Chinese
    $this->TML2HTML_testUnicodeCodepointsRange( 'utf-8', 8000, 9000 );

    return;
}

sub test_restHTML2TML_undef {
    my $this = shift;
    $this->HTML2TML_testUnicodeCodepointsRange( undef, 160, 255 );

    # Browsers commonly treat iso-8859-1 as if it is windows-1252
    # and so does Foswiki
    my $unicodeOfWindows1252 =
      join( '', map { chr($_) } @unicodeCodepointsForWindows1252 );

    $this->HTML2TML_test( undef, $unicodeOfWindows1252, $unicodeOfWindows1252 );

    return;
}

sub test_restHTML2TML_iso_8859_1 {
    my $this = shift;
    $this->HTML2TML_testUnicodeCodepointsRange( 'iso-8859-1', 160, 255 );

    # Browsers commonly treat iso-8859-1 as if it is windows-1252
    # and so does Foswiki
    my $unicodeOfWindows1252 =
      join( '', map { chr($_) } @unicodeCodepointsForWindows1252 );

    $this->HTML2TML_test( 'iso-8859-1', $unicodeOfWindows1252,
        $unicodeOfWindows1252 );

    return;
}

sub test_restHTML2TML_iso_8859_7 {
    my $this = shift;

    $this->HTML2TML_testCharsetCodesRange( 'iso-8859-7', 160, 173 );
    $this->HTML2TML_testCharsetCodesRange( 'iso-8859-7', 175, 209 );
    $this->HTML2TML_testCharsetCodesRange( 'iso-8859-7', 211, 254 );

    return;
}

sub test_restHTML2TML_iso_8859_15 {
    my $this = shift;
    $this->HTML2TML_testUnicodeCodepointsRange( 'iso-8859-15', 127, 163 );
    $this->HTML2TML_testUnicodeCodepointsRange( 'iso-8859-15', 169, 179 );
    $this->HTML2TML_testUnicodeCodepointsRange( 'iso-8859-15', 181, 183 );
    $this->HTML2TML_testUnicodeCodepointsRange( 'iso-8859-15', 191, 255 );

    # These are the codes that are different to iso-8859-1, and thus
    # different to unicode
    for my $code ( 0xA4, 0xA6, 0xA8, 0xB4, 0xBC, 0xBD, 0xBE ) {
        $this->HTML2TML_testCharsetCodesRange( 'iso-8859-15', $code, $code );
    }

    return;
}

sub test_restHTML2TML_utf_8 {
    my $this = shift;
    $this->HTML2TML_testUnicodeCodepointsRange( 'utf-8', 127, 300 );
    $this->HTML2TML_testUnicodeCodepointsRange( 'utf-8', 301, 400 );
    $this->HTML2TML_testUnicodeCodepointsRange( 'utf-8', 401, 500 );

    # Chinese
    $this->HTML2TML_testUnicodeCodepointsRange( 'utf-8', 8000, 9000 );

    return;
}

sub test_save_undef {
    my $this = shift;
    $this->save_testUnicodeCodepointsRange( undef, 127, 128 );
    $this->save_testUnicodeCodepointsRange( undef, 130, 140 );
    $this->save_testUnicodeCodepointsRange( undef, 142, 142 );
    $this->save_testUnicodeCodepointsRange( undef, 145, 156 );
    $this->save_testUnicodeCodepointsRange( undef, 158, 255 );

    return;
}

sub test_save_iso_8859_1 {
    my $this = shift;
    $this->save_testUnicodeCodepointsRange( 'iso-8859-1', 160, 255 );

    # Browsers commonly treat iso-8859-1 as if it is windows-1252
    # and so does Foswiki
    my $unicodeOfWindows1252 =
      join( '', map { chr($_) } @unicodeCodepointsForWindows1252 );

    $this->save_test( 'iso-8859-1', $unicodeOfWindows1252,
        $unicodeOfWindows1252 );

    return;
}

sub test_save_iso_8859_7 {
    my $this = shift;

    $this->save_testCharsetCodesRange( 'iso-8859-7', 160, 173 );
    $this->save_testCharsetCodesRange( 'iso-8859-7', 175, 209 );
    $this->save_testCharsetCodesRange( 'iso-8859-7', 211, 254 );

    return;
}

sub test_save_iso_8859_15 {
    my $this = shift;
    $this->save_testUnicodeCodepointsRange( 'iso-8859-15', 127, 163 );
    $this->save_testUnicodeCodepointsRange( 'iso-8859-15', 169, 179 );
    $this->save_testUnicodeCodepointsRange( 'iso-8859-15', 181, 183 );
    $this->save_testUnicodeCodepointsRange( 'iso-8859-15', 191, 255 );

    # These are the codes that are different to iso-8859-1, and thus
    # different to unicode
    for my $code ( 0xA4, 0xA6, 0xA8, 0xB4, 0xBC, 0xBD, 0xBE ) {
        $this->save_testCharsetCodesRange( 'iso-8859-15', $code, $code );
    }

    return;
}

sub test_save_utf_8a {
    my $this = shift;
    $this->save_testUnicodeCodepointsRange( 'utf-8', 127, 300 );

    return;
}

sub test_save_utf_8b {
    my $this = shift;
    $this->save_testUnicodeCodepointsRange( 'utf-8', 301, 400 );

    return;
}

sub test_save_utf_8d {
    my $this = shift;
    $this->save_testUnicodeCodepointsRange( 'utf-8', 401, 500 );

    return;
}

sub test_save_utf_8e {
    my $this = shift;

    # Chinese
    $this->save_testUnicodeCodepointsRange( 'utf-8', 8000, 9000 );

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005 ILOG http://www.ilog.fr

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
