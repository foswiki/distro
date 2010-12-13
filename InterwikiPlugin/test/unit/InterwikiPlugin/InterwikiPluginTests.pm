package InterwikiPluginTests;

use strict;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::Func;
use Foswiki::Plugins::InterwikiPlugin;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{test_user} = 'scum';
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
        Foswiki::Func::renderText( "Wikipedia:Perl", $this->{test_web} )
    );
}

sub test_link_from_local_rules_topic {
    my $this            = shift;
    my $localRulesTopic = "LocalInterWikis";

    Foswiki::Func::saveTopic( $this->{test_web}, $localRulesTopic, undef,
        <<'HERE');
---+++ Local rules
<noautolink>
| *Alias:* | *URL:* | *Tooltip Text:* |
| Localrule | http://rule.invalid.url?page= | Local rule |
</nautolink>
HERE

    Foswiki::Func::setPreferencesValue( "INTERWIKIPLUGIN_RULESTOPIC",
        "$this->{test_web}.$localRulesTopic" );
    Foswiki::Plugins::InterwikiPlugin::initPlugin(
        $this->{test_web},  $this->{test_topic},
        $this->{test_user}, $Foswiki::cfg{SystemWebName}
    );

    $this->assert_html_equals(
'<a class="interwikiLink" href="http://rule.invalid.url?page=Topage" title="Local rule"><noautolink>Localrule:Topage</noautolink></a>',
        Foswiki::Func::renderText( "Localrule:Topage", $this->{test_web} )
    );
}

sub test_link_from_inherted_rules_topic {
    my $this              = shift;
    my $inheritRulesTopic = "InheritInterWikis";

    Foswiki::Func::saveTopic( $this->{test_web}, $inheritRulesTopic, undef,
        <<'HERE');
---+++ Local rules
<noautolink>
| *Alias:* | *URL:* | *Tooltip Text:* |
| Localrule | http://rule.invalid.url?page= | Local rule |
| Wiki | http://foo.bar/cgi/wiki? | Redefined rule |
</nautolink>
HERE

    Foswiki::Func::setPreferencesValue( "INTERWIKIPLUGIN_RULESTOPIC",
"$Foswiki::cfg{SystemWebName}.InterWikis, $this->{test_web}.$inheritRulesTopic"
    );
    Foswiki::Plugins::InterwikiPlugin::initPlugin(
        $this->{test_web},  $this->{test_topic},
        $this->{test_user}, $Foswiki::cfg{SystemWebName}
    );

    # local rule
    $this->assert_html_equals(
'<a class="interwikiLink" href="http://rule.invalid.url?page=Topage" title="Local rule"><noautolink>Localrule:Topage</noautolink></a>',
        Foswiki::Func::renderText( "Localrule:Topage", $this->{test_web} ),
        'local rule'
    );

    # default rule
    $this->assert_html_equals(
'<a class="interwikiLink" href="http://en.wikipedia.org/wiki/Perl" title="\'Perl\' on \'Wikipedia\'"><noautolink>Wikipedia:Perl</noautolink></a>',
        Foswiki::Func::renderText( "Wikipedia:Perl", $this->{test_web} ),
        'default rule'
    );

    # redefined rule
    $this->assert_html_equals(
'<a class="interwikiLink" href="http://foo.bar/cgi/wiki?Perl" title="Redefined rule"><noautolink>Wiki:Perl</noautolink></a>',
        Foswiki::Func::renderText( "Wiki:Perl", $this->{test_web} ),
        'redefined rule'
    );
}

sub test_cant_view_rules_topic {
    my $this       = shift;
    my $rulesTopic = "CantReadInterWikis";

    Foswiki::Func::saveTopic( $this->{test_web}, $rulesTopic, undef, <<'HERE');
---+++ Local rules
<noautolink>
| *Alias:* | *URL:* | *Tooltip Text:* |
| Localrule | http://rule.invalid.url?page= | Local rule |
</nautolink>

   * Set DENYTOPICVIEW = %USERSWEB%.WikiGuest
HERE

    Foswiki::Func::setPreferencesValue( "INTERWIKIPLUGIN_RULESTOPIC",
        "$this->{test_web}.$rulesTopic" );
    Foswiki::Plugins::InterwikiPlugin::initPlugin( $this->{test_web},
        $this->{test_topic}, 'guest', $Foswiki::cfg{SystemWebName} );

    $this->assert_html_equals( 'Localrule:Topage',
        Foswiki::Func::renderText( "Localrule:Topage", $this->{test_web} ) );
}

sub test_link_with_url {
    my $this = shift;
    $this->assert_html_equals(
'<a class="interwikiLink" href="http://en.wikipedia.org/wiki/http://www.google.com/search?q=foswiki&foo=bar" title="\'http://www.google.com/search?q=foswiki&foo=bar\' on \'Wikipedia\'"><noautolink>Wikipedia:http://www.google.com/search?q=foswiki&foo=bar</noautolink></a>',
        Foswiki::Func::renderText(
            "Wikipedia:http://www.google.com/search?q=foswiki&foo=bar",
            $this->{test_web}
        )
    );
}

# tests the following characters:
# ' . & = " /
sub test_link_with_complex_url {
    my $this = shift;
    $this->assert_html_equals(
'<a class="interwikiLink" href="http://en.wikipedia.org/wiki/http://www.google.com/search?q=foswiki&foo="bar"/\'baz.\'" title="\'http://www.google.com/search?q=foswiki&foo="bar"/\'baz.\'\' on \'Wikipedia\'"><noautolink>Wikipedia:http://www.google.com/search?q=foswiki&foo="bar"/\'baz.\'</noautolink></a>',
        Foswiki::Func::renderText(
'Wikipedia:http://www.google.com/search?q=foswiki&foo="bar"/\'baz.\'',
            $this->{test_web}
        )
    );
}

sub test_link_with_topic_name {
    my $this            = shift;
    my $localRulesTopic = "LocalInterWikis";

    Foswiki::Func::saveTopic( $this->{test_web}, $localRulesTopic, undef,
        <<'HERE');
---+++ Local rules
<noautolink>
| *Alias:* | *URL:* | *Tooltip Text:* |
| WebHome | http://rule.invalid.url?page= | Local rule |
</nautolink>
HERE

    Foswiki::Func::setPreferencesValue( "INTERWIKIPLUGIN_RULESTOPIC",
        "$this->{test_web}.$localRulesTopic" );
    Foswiki::Plugins::InterwikiPlugin::initPlugin(
        $this->{test_web},  $this->{test_topic},
        $this->{test_user}, $Foswiki::cfg{SystemWebName}
    );

    $this->assert_html_equals(
'<a class="interwikiLink" href="http://rule.invalid.url?page=Topage" title="Local rule"><noautolink>WebHome:Topage</noautolink></a>',
        Foswiki::Func::renderText( "WebHome:Topage", $this->{test_web} )
    );
}

# http://foswiki.org/Tasks/Item10151
sub test_link_with_parentheses {
    my $this = shift;
    $this->assert_html_equals(
'<a class="interwikiLink" href="http://en.wikipedia.org/wiki/Fork_(software_development)" title="\'Fork_(software_development)\' on \'Wikipedia\'"><noautolink>Wikipedia:Fork_(software_development)</noautolink></a>',
        Foswiki::Func::renderText( "Wikipedia:Fork_(software_development)", $this->{test_web} )
    );
}

1;
