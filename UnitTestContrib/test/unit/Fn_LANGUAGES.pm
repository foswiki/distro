# See bottom of file for license and copyright information
# tests for the correct expansion of LANGUAGES

package Fn_LANGUAGES;
use strict;
use warnings;
use utf8;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

my $topicObject;

# Force reload of I18N in case it wasn't enabled
if ( delete $INC{'Foswiki/I18N.pm'} ) {

    # Clean the symbol table to remove loaded subs
    no strict 'refs';
    @Foswiki::I18N::ISA = ();
    my $symtab = "Foswiki::I18N::";
    foreach my $symbol ( keys %{$symtab} ) {
        next if $symbol =~ m/\A[^:]+::\z/;
        delete $symtab->{$symbol};
    }
}

sub new {
    my $self = shift()->SUPER::new( 'LANGUAGES', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'WebHome' );
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();
    setLocalSite();
}

sub setLocalSite {
    $Foswiki::cfg{WebMasterEmail}                    = 'a.b@c.org';
    $Foswiki::cfg{UserInterfaceInternationalisation} = 1;
    foreach my $lang ( keys %{ $Foswiki::cfg{Languages} } ) {
        $Foswiki::cfg{Languages}{$lang}{Enabled} = 0;
    }
    $Foswiki::cfg{Languages}{de}{Enabled} = 1;
    $Foswiki::cfg{Languages}{fr}{Enabled} = 1;
    $Foswiki::cfg{Languages}{it}{Enabled} = 1;
    $Foswiki::cfg{Languages}{ru}{Enabled} = 1;
}

sub test_simple {
    my $this = shift;

    my $result   = $topicObject->expandMacros('%LANGUAGES{}%');
    my $expected = <<LANGS;
   * Deutsch
   * English
   * Français
   * Italiano
   * Русский
LANGS
    chomp $expected;
    $this->assert_str_equals( $expected, $result );
}

sub test_format {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%LANGUAGES{format="$langtag-$langname" separator="|"}%');
    my $expected = <<LANGS;
de-Deutsch|en-English|fr-Français|it-Italiano|ru-Русский
LANGS
    chomp $expected;
    $this->assert_str_equals( $expected, $result );
}

sub test_selected {
    my $this = shift;

    my $result = $topicObject->expandMacros(
'%LANGUAGES{format="$langtag-$langname$marker" separator="|" marker="**" selection="fr"}%'
    );
    my $expected = <<LANGS;
de-Deutsch|en-English|fr-Français**|it-Italiano|ru-Русский
LANGS
    chomp $expected;
    $this->assert_str_equals( $expected, $result );
}

sub test_standard_esc {
    my $this = shift;

    my $result = $topicObject->expandMacros(
'%LANGUAGES{format="$nop$langtag$dollar$lt$langname$gt$marker" separator="$comma" marker="$amp" selection="fr"}%'
    );
    my $expected = <<LANGS;
de\$<Deutsch>,en\$<English>,fr\$<Français>&,it\$<Italiano>,ru\$<Русский>
LANGS
    chomp $expected;
    $this->assert_str_equals( $expected, $result );
}

sub test_LANGUAGE {
    my $this = shift;

    my $result = $topicObject->expandMacros('%LANGUAGE%');
    $this->assert_str_equals( 'en', $result );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2007-2020 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
