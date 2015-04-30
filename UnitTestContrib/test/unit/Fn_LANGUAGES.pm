# tests for the correct expansion of LANGUAGES

package Fn_LANGUAGES;
use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
use Encode;

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
}

sub test_simple {
    my $this = shift;

    my $result   = $topicObject->expandMacros('%LANGUAGES{}%');
    my $expected = <<LANGS;
   * Deutsch
   * English
   * Français
   * Italiano
LANGS
    chomp $expected;
    $expected = Encode::encode( $Foswiki::cfg{Site}{CharSet},
        $expected, Encode::FB_CROAK );
    $this->assert_str_equals( $expected, $result );
}

sub test_format {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%LANGUAGES{format="$langtag-$langname" separator="|"}%');
    my $expected = <<LANGS;
de-Deutsch|en-English|fr-Français|it-Italiano
LANGS
    chomp $expected;
    $expected = Encode::encode( $Foswiki::cfg{Site}{CharSet},
        $expected, Encode::FB_CROAK );
    $this->assert_str_equals( $expected, $result );
}

sub test_selected {
    my $this = shift;

    my $result = $topicObject->expandMacros(
'%LANGUAGES{format="$langtag-$langname$marker" separator="|" marker="**" selection="fr"}%'
    );
    my $expected = <<LANGS;
de-Deutsch|en-English|fr-Français**|it-Italiano
LANGS
    chomp $expected;
    $expected = Encode::encode( $Foswiki::cfg{Site}{CharSet},
        $expected, Encode::FB_CROAK );
    $this->assert_str_equals( $expected, $result );
}

sub test_standard_esc {
    my $this = shift;

    my $result = $topicObject->expandMacros(
'%LANGUAGES{format="$nop$langtag$dollar$lt$langname$gt$marker" separator="$comma" marker="$amp" selection="fr"}%'
    );
    my $expected = <<LANGS;
de\$<Deutsch>,en\$<English>,fr\$<Français>&,it\$<Italiano>
LANGS
    chomp $expected;
    $expected = Encode::encode( $Foswiki::cfg{Site}{CharSet},
        $expected, Encode::FB_CROAK );
    $this->assert_str_equals( $expected, $result );
}

sub test_LANGUAGE {
    my $this = shift;

    my $result = $topicObject->expandMacros('%LANGUAGE%');
    $this->assert_str_equals( 'en', $result );
}

1;
