package InterwikiPluginTests;

use strict;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::Func;

my $localRulesTopic = "LocalInterWikis";

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    # local rules topic
    Foswiki::Func::saveTopic( $this->{test_web}, $localRulesTopic, undef,
        <<'HERE');
---+++ Local rules
<noautolink>
| *Alias:* | *URL:* | *Tooltip Text:* |
| Localrule | http://rule.invalid.url?page= | Local rule |
| Wiki | http://c2.com/cgi/wiki? | Redefined global rule to wiki page |
</nautolink>
HERE

}

sub tear_down {
   my $this = shift;
   $this->SUPER::tear_down();
}

############################################################

sub test_link_from_default_rules_topic {
   my $this = shift;
   $this->assert_html_equals(
      '<a class="interwikiLink" href="http://en.wikipedia.org/wiki/Perl" title="\'Perl\' on \'Wikipedia\'"><noautolink>Wikipedia:Perl</noautolink></a>',
      Foswiki::Func::renderText("Wikipedia:Perl", $this->{test_topic})
   );
}

# No longer working
#sub test_link_from_local_rules_topic {
#   my $this = shift;
#   Foswiki::Func::setPreferencesValue("INTERWIKIPLUGIN_RULESTOPIC", "$this->{test_web}.$localRulesTopic");
#   $this->assert_html_equals(
#      '<a class="interwikiLink" href="http://rule.invalid.url?page=Topage" title="Local rule"><noautolink>Localrule:Topage</noautolink></a>',
#      Foswiki::Func::renderText("Localrule:Topage", $this->{test_web})
#   );
#}

1;
