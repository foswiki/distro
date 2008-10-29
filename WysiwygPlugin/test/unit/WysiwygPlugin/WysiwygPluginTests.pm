# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

# Tests for the plugin component
#
package WysiwygPluginTests;
use base 'TWikiFnTestCase';

use strict;

use Unit::Request;
use Unit::Response;
use TWiki;
use TWiki::Plugins::WysiwygPlugin;

use Carp;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $TWiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;
    $WC::encoding = undef;
    $WC::safe_entities = undef;
    $TWiki::cfg{Site}{CharSet} = undef;
    $TWiki::cfg{Site}{Locale} = undef;
    $TWiki::cfg{Site}{UseLocale} = 0;
}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();
}

sub anal {
    my $out = shift;
    my @s;
    foreach my $i (split(//, $out)) {
        my $n = ord($i);
        if ($n > 127) {
            push(@s, $n);
        } else {
            push(@s, $i);
        }
    }
    return join(' ', @s);
}

sub save_test {
    my ($this, $charset, $firstchar, $lastchar) = @_;

    $TWiki::cfg{Site}{CharSet} = $charset;

    my @test;
    for (my $i = $firstchar; $i <= $lastchar; $i++) {
        push(@test, chr($i));
    }
    my $text = join('', @test).".";
    my $t = $charset ? Encode::encode($charset, $text) : $text;

    my $query = new Unit::Request({
        'wysiwyg_edit' => [ 1 ],
        'action_save' => [ 1 ],
        'text' => [ $t ],
    });
    $query->path_info("/$this->{test_web}/WysiwygPluginTest" );
    $query->param(text => $t);

    $TWiki::Plugins::SESSION = new TWiki('guest', $query );
	# charset definition affects output, so it is a response method and
	# can only be adjusted after creating session object.
	$TWiki::Plugins::SESSION->{response}->charset($charset) if $charset;

    require TWiki::UI::Save;
    my ($dummy, $result) =
      $this->capture( \&TWiki::UI::Save::save, $TWiki::Plugins::SESSION);

    $this->assert(!$result, $result);
    my ($meta, $out) = TWiki::Func::readTopic(
        $this->{test_web}, 'WysiwygPluginTest');

    $out =~ s/\s*$//s;

    $this->assert($t eq $out, "'".anal($out)."' !=\n'".anal($t)."'");
}

sub TML2HTML_test {
    my ($this, $charset, $firstchar, $lastchar) = @_;

    # Is this enough? Regexes are inited before we get here, aren't they?
    $TWiki::cfg{Site}{CharSet} = $charset;

    my @test;
    for (my $i = $firstchar; $i <= $lastchar; $i++) {
        push(@test, chr($i));
    }
    my $text = join('', @test).".";
    my $query = new Unit::Request({
        'wysiwyg_edit' => [ 1 ],
        # REST parameters are always UTF8 encoded
        'text' => [ Encode::encode_utf8($text) ],
    });

    my $twiki = new TWiki('guest', $query );
	$twiki->{response}->charset($charset) if $charset;

    my ($out, $result) = $this->capture(
        \&TWiki::Plugins::WysiwygPlugin::_restTML2HTML,
        $twiki, undef, undef, $twiki->{response});

    $this->assert(!$result, $result);
    # Strip ASCII header
    $this->assert_matches(qr/Content-Type: text\/plain;charset=UTF-8/, anal($out));
    $out =~ s/^.*?\r\n\r\n//s;

    $out = Encode::decode_utf8($out);

    my $id = "<!--$TWiki::Plugins::WysiwygPlugin::SECRET_ID-->";
    $this->assert($out =~ s/^\s*$id<p>\s*//s, anal($out));
    $out =~ s/\s*<\/p>\s*$//s;

    require TWiki::Plugins::WysiwygPlugin::Constants;
    WC::mapUnicode2HighBit($out);

    $this->assert($text eq $out, "'".anal($out)."' !=\n'".anal($text)."'");
}

sub HTML2TML_test {
    my ($this, $charset, $firstchar, $lastchar) = @_;

    # Is this enough? Regexes are inited before we get here, aren't they?
    $TWiki::cfg{Site}{CharSet} = $charset;

    my @test;
    for (my $i = $firstchar; $i <= $lastchar; $i++) {
        push(@test, chr($i));
    }
    my $text = join('', @test).".";
    my $query = new Unit::Request({
        'wysiwyg_edit' => [ 1 ],
        # REST parameters are always UTF8 encoded
        'text' => [ Encode::encode_utf8($text) ],
    });

    my $twiki = new TWiki('guest', $query );
	$twiki->{response}->charset($charset) if $charset;

    my ($out, $result) = $this->capture(
        \&TWiki::Plugins::WysiwygPlugin::_restHTML2TML,
        $twiki, undef, undef, $twiki->{response});

    $this->assert(!$result, $result);
    # Strip ASCII header
    $this->assert_matches(qr/Content-Type: text\/plain;charset=UTF-8/,
                          anal($out));
    $out =~ s/^.*?\r\n\r\n//s;

    $out = Encode::decode_utf8($out);

    require TWiki::Plugins::WysiwygPlugin::Constants;
    WC::mapUnicode2HighBit($out);

    $out =~ s/\s*$//s;

    $this->assert($text eq $out, "'".anal($out)."' !=\n'".anal($text)."'");
}

# tests for various charsets
sub test_restTML2HTML_undef {
    my $this = shift;
    $this->TML2HTML_test(undef, 127, 255);
}

sub test_restTML2HTML_iso_8859_1 {
    my $this = shift;
    $this->TML2HTML_test('iso-8859-1', 127, 255);
}

sub test_restTML2HTML_iso_8859_15 {
    my $this = shift;
    $this->TML2HTML_test('iso-8859-15', 127, 163);
    $this->TML2HTML_test('iso-8859-15', 169, 179);
    $this->TML2HTML_test('iso-8859-15', 181, 183);
    $this->TML2HTML_test('iso-8859-15', 191, 255);
}

sub test_restTML2HTML_utf_8 {
    my $this = shift;
    $this->TML2HTML_test('utf-8', 127, 300);
    $this->TML2HTML_test('utf-8', 301, 400);
    $this->TML2HTML_test('utf-8', 401, 500);
    # Chinese
    $this->TML2HTML_test('utf-8', 8000, 9000);
}

sub test_restHTML2TML_undef {
    my $this = shift;
    $this->HTML2TML_test(undef, 127, 255);
}

sub test_restHTML2TML_iso_8859_1 {
    my $this = shift;
    $this->HTML2TML_test('iso-8859-1', 127, 255);
}

sub test_restHTML2TML_iso_8859_15 {
    my $this = shift;
    $this->HTML2TML_test('iso-8859-15', 127, 163);
    $this->HTML2TML_test('iso-8859-15', 169, 179);
    $this->HTML2TML_test('iso-8859-15', 181, 183);
    $this->HTML2TML_test('iso-8859-15', 191, 255);
}

sub test_restHTML2TML_utf_8 {
    my $this = shift;
    $this->HTML2TML_test('utf-8', 127, 300);
    $this->HTML2TML_test('utf-8', 301, 400);
    $this->HTML2TML_test('utf-8', 401, 500);
    # Chinese
    $this->HTML2TML_test('utf-8', 8000, 9000);
}

sub test_save_undef {
    my $this = shift;
    $this->save_test(undef, 127, 255);
}

sub test_save_iso_8859_1 {
    my $this = shift;
    $this->save_test('iso-8859-1', 127, 255);
}

sub test_save_iso_8859_15 {
    my $this = shift;
    $this->save_test('iso-8859-15', 127, 163);
    $this->save_test('iso-8859-15', 169, 179);
    $this->save_test('iso-8859-15', 181, 183);
    $this->save_test('iso-8859-15', 191, 255);
}

sub test_save_utf_8a {
    my $this = shift;
    $this->save_test('utf-8', 127, 300);
}

sub test_save_utf_8b {
    my $this = shift;
    $this->save_test('utf-8', 301, 400);
}

sub test_save_utf_8d {
    my $this = shift;
    $this->save_test('utf-8', 401, 500);
}

sub test_save_utf_8e {
    my $this = shift;
    # Chinese
    $this->save_test('utf-8', 8000, 9000);
}

1;
