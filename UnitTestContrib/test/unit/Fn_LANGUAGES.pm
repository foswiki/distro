# tests for the correct expansion of LANGUAGES

package Fn_LANGUAGES;
use v5.14;
use utf8;

use Foswiki;
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

my $topicObject;

# Force reload of I18N in case it wasn't enabled
#if ( delete $INC{'Foswiki/I18N.pm'} ) {
#
#    # Clean the symbol table to remove loaded subs
#    no strict 'refs';
#    @Foswiki::I18N::Base::ISA = ();
#    my $symtab = "Foswiki::I18N::Base::";
#    foreach my $symbol ( keys %{$symtab} ) {
#        next if $symbol =~ m/\A[^:]+::\z/;
#        delete $symtab->{$symbol};
#    }
#}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    return $orig->( $class, @_, testSuite => 'LANGUAGES' );
};

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $this->__EnvReset->{$_} = undef
      foreach grep { /(?:^LANG$|^LC_)/ } keys %ENV;

    $orig->( $this, @_ );

    ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'WebHome' );

};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );
};

around loadExtraConfig => sub {
    my $orig = shift;
    my $this = shift;
    $orig->( $this, @_ );
    setLocalSite();
};

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
    $Foswiki::cfg{Languages}{uk}{Enabled} = 1;
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
   * Українська
LANGS
    chomp $expected;
    $this->assert_str_equals( $expected, $result );
}

sub test_format {
    my $this = shift;

    my $result = $topicObject->expandMacros(
        '%LANGUAGES{format="$langtag-$langname" separator="|"}%');
    my $expected = <<LANGS;
de-Deutsch|en-English|fr-Français|it-Italiano|ru-Русский|uk-Українська
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
de-Deutsch|en-English|fr-Français**|it-Italiano|ru-Русский|uk-Українська
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
de\$<Deutsch>,en\$<English>,fr\$<Français>&,it\$<Italiano>,ru\$<Русский>,uk\$<Українська>
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
