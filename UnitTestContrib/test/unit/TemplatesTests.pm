use strict;

#
# Unit tests for Foswiki::Templates
#

package TemplatesTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Foswiki;
use Foswiki::Templates;
use File::Path;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $test_tmpls;
my $test_data;

my $session;
my $tmpls;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $here = Cwd::cwd();
    $here =~ m/^(.*)$/;
    $test_tmpls = $1 . '/fake_templates';
    $test_data  = $1 . '/fake_data';

    File::Path::mkpath($test_tmpls);
    File::Path::mkpath($test_data);

    $session = new Foswiki();
    $tmpls   = $session->templates;

    $Foswiki::cfg{TemplateDir} = $test_tmpls;
    $Foswiki::cfg{DataDir}     = $test_data;
    $Foswiki::cfg{TemplatePath} =
'$Foswiki::cfg{PubDir}/$web/$name.$skin.tmpl,$Foswiki::cfg{TemplateDir}/$web/$name.$skin.tmpl,$Foswiki::cfg{TemplateDir}/$name.$skin.tmpl,$Foswiki::cfg{TemplateDir}/$web/$name.tmpl,$Foswiki::cfg{TemplateDir}/$name.tmpl,$web.$skinSkin$nameTemplate,$Foswiki::cfg{SystemWebName}.$skinSkin$nameTemplate,$web.$nameTemplate,$Foswiki::cfg{SystemWebName}.$nameTemplate';
    $Foswiki::cfg{TemplatePath} =~
      s/\$Foswiki::cfg{TemplateDir}/$Foswiki::cfg{TemplateDir}/geo;
    $Foswiki::cfg{TemplatePath} =~
      s/\$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{SystemWebName}/geo;

}

sub tear_down {
    my $this = shift;
    $session->finish();
    $this->SUPER::tear_down();
    File::Path::rmtree($test_tmpls);
    File::Path::rmtree($test_data);
}

sub write_template {
    my ( $tmpl, $content ) = @_;

    $content ||= $tmpl;
    if ( $tmpl =~ m!^(.*)/[^/]*$! ) {
        File::Path::mkpath("$test_tmpls/$1") unless -d "$test_tmpls/$1";
    }
    open( F, ">$test_tmpls/$tmpl.tmpl" ) || die;
    print F $content;
    close(F);
}

sub write_topic {
    my ( $web, $topic, $content ) = @_;

    File::Path::mkpath("$test_data/$web") unless -d "$test_data/$web";
    open( F, ">$test_data/$web/$topic.txt" ) || die;
    $content = $content || "$web/$topic";
    print F $content;
    close(F);
}

sub test_skinPathBasic {
    my $this = shift;
    my $data;

    write_template( 'script', 'scripttmplcontent' );

    $data = $tmpls->readTemplate( 'script', skins => undef, web => undef );
    $this->assert_str_equals( "scripttmplcontent", $data );

    $data = $tmpls->readTemplate( 'script' );
    $this->assert_str_equals( 'scripttmplcontent', $data );

    $data = $tmpls->readTemplate( 'script', skins => 'skin' );
    $this->assert_str_equals( 'scripttmplcontent', $data );

    $data = $tmpls->readTemplate( 'script', skins => 'skin', web => 'web' );
    $this->assert_str_equals( 'scripttmplcontent', $data );
}

sub test_skinPathWeb {
    my $this = shift;
    my $data;

    write_template('script');
    write_template('script.skin');
    write_template('web/script');
    write_template('web/script.skin');

    $data = $tmpls->readTemplate( 'script' );
    $this->assert_str_equals( 'script', $data );

    $data = $tmpls->readTemplate( 'script', skins => 'skin' );
    $this->assert_str_equals( 'script.skin', $data );

    $data = $tmpls->readTemplate( 'script', web => 'web' );
    $this->assert_str_equals( 'web/script', $data );

    $data = $tmpls->readTemplate( 'script', skins => 'skin', web => 'web' );
    $this->assert_str_equals( 'web/script.skin', $data );

}

sub test_skinPathsOneSkin {
    my $this = shift;
    my $data;

    write_template('script');
    write_template('script.scaly');

    $data = $tmpls->readTemplate( 'script', skins => undef, web => undef );
    $this->assert_str_equals( 'script', $data );

    $data = $tmpls->readTemplate( 'script', web => 'web' );
    $this->assert_str_equals( "script", $data );

    $data = $tmpls->readTemplate( 'script', skins => 'scaly' );
    $this->assert_str_equals( "script.scaly", $data );

    $data = $tmpls->readTemplate( 'script', skins => 'scaly', web => 'web' );
    $this->assert_str_equals( "script.scaly", $data );
}

sub test_skinPathsOneSkinWeb {
    my $this = shift;
    my $data;

    write_template('script');
    write_template('script.burnt');
    write_template('web/script.burnt');

    $data = $tmpls->readTemplate( 'script', skins => 'burnt' );
    $this->assert_str_equals( 'script.burnt', $data );

    $data = $tmpls->readTemplate( 'script', skins => 'burnt', web => 'web' );
    $this->assert_str_equals( 'web/script.burnt', $data );
}

sub test_skinPathsTwoSkins {
    my $this = shift;
    my $data;

    write_template('script');
    write_template('kibble');
    write_template('script.suede');
    write_template('script.tanned');
    write_template('kibble.tanned');

    $data = $tmpls->readTemplate( 'script', skins => 'suede' );
    $this->assert_str_equals( "script.suede", $data );

    $data = $tmpls->readTemplate( 'script', skins => 'tanned' );
    $this->assert_str_equals( "script.tanned", $data );

    $data = $tmpls->readTemplate( 'script', skins => 'suede,tanned' );
    $this->assert_str_equals( "script.suede", $data );

    $data = $tmpls->readTemplate( 'script', skins => 'tanned,suede' );
    $this->assert_str_equals( "script.tanned", $data );

    $data = $tmpls->readTemplate( 'kibble', skins => 'suede,tanned' );
    $this->assert_str_equals( "kibble.tanned", $data );

    $data = $tmpls->readTemplate( 'kibble', skins => 'tanned,suede' );
    $this->assert_str_equals( "kibble.tanned", $data );

    $data = $tmpls->readTemplate( 'kibble', skins => 'suede' );
    $this->assert_str_equals( "kibble", $data );
}

sub test_pathOdd {
    my $this = shift;
    my $data;

    # To verify that a name with dot in it is also considered
    write_template( 'script.skin', 'the script.skin.tmpl template' );
    write_template( 'script.skinA.skin',
        'the script.skinA.skin.tmpl template' );

    $data = $tmpls->readTemplate( 'script.skin' );
    $this->assert_str_equals( 'the script.skin.tmpl template', $data );

    $data = $tmpls->readTemplate( 'script.skin', skins => 'pattern' );
    $this->assert_str_equals( 'the script.skin.tmpl template', $data );

    $data = $tmpls->readTemplate( 'script.skinA', skins => 'skin' );
    $this->assert_str_equals( 'the script.skinA.skin.tmpl template', $data );

    # Works but should never be called in code
    $data = $tmpls->readTemplate( 'script', skins => 'skinA.skin' );
    $this->assert_str_equals( 'the script.skinA.skin.tmpl template', $data );

}

sub test_pathOtherUses {
    my $this = shift;
    my $data;

    # To verify a concern by SvenDowideit on fallback to "default" templates
    write_template( 'scriptA.skin',    'the scriptA.skin.tmpl template' );
    write_template( 'scriptB',         'the scriptB.tmpl template' );
    write_template( 'scriptC.pattern', 'the scriptC.pattern.tmpl template' );
    write_template( 'scriptD',         'the scriptD.tmpl template' );
    write_template( 'scriptD.pattern', 'the scriptD.pattern.tmpl template' );
    write_template( 'scriptD.override',
        'the scriptD.override.tmpl template %TMPL:INCLUDE{"scriptD"}%' );

    $data = $tmpls->readTemplate( 'scriptA', skins => 'noskin', no_oops => 1 );
    $this->assert_null($data );

    $data = $tmpls->readTemplate( 'scriptB', skins => 'skin,pattern' );
    $this->assert_str_equals( 'the scriptB.tmpl template', $data );

    $data = $tmpls->readTemplate( 'scriptC', skins => 'skin,pattern' );
    $this->assert_str_equals( 'the scriptC.pattern.tmpl template', $data );

    $data = $tmpls->readTemplate( 'scriptD', skins => 'override,pattern' );
    $this->assert_str_equals(
        'the scriptD.override.tmpl template the scriptD.pattern.tmpl template',
        $data
    );

    $data = $tmpls->readTemplate( 'scriptD', skins => 'override' );
    $this->assert_str_equals(
        'the scriptD.override.tmpl template the scriptD.tmpl template', $data );

    $data =
      $tmpls->readTemplate( 'scriptD', skins => ', , ,, override,, , ,noskin,,' );
    $this->assert_str_equals(
        'the scriptD.override.tmpl template the scriptD.tmpl template', $data );

}

sub test_directLookupInUsertopic {
    my $this = shift;
    my $data;

    # To verify a use case raised by Michael Daum: $web.$script looks up
    # template topic $script in $web, no further searching is done
    # Note the order in which templates are found. It sure is
    # counter-intuitive to not consider the skin templates first.
    write_topic( 'Web', 'TestTemplate', 'the Web.TestTemplate template' );
    $data = $tmpls->readTemplate( 'web.test', skins => 'skin' );
    $this->assert_str_equals( 'the Web.TestTemplate template', $data );

    write_topic( 'Web', 'SkinSkinTestTemplate',
        'the Web.SkinSkinTestTemplate template' );
    $data = $tmpls->readTemplate( 'web.test', skins => 'skin' );
    $this->assert_str_equals( 'the Web.SkinSkinTestTemplate template', $data );

    write_template( 'web.test', 'the web.test.tmpl template' );
    $data = $tmpls->readTemplate( 'web.test', skins => 'skin' );
    $this->assert_str_equals( 'the web.test.tmpl template', $data );

    write_template( 'web.test.skin', 'the web.test.skin.tmpl template' );
    $data = $tmpls->readTemplate( 'web.test', skins => 'skin' );
    $this->assert_str_equals( 'the web.test.skin.tmpl template', $data );

    write_topic( 'Web', 'Test', 'the Web.Test template' );
    $data = $tmpls->readTemplate( 'web.test', skins => 'skin' );
    $this->assert_str_equals( 'the Web.Test template', $data );

    $data = $tmpls->readTemplate( 'web.test' );
    $this->assert_str_equals( 'the Web.Test template', $data );
}

sub test_WebTopicsA {
    my $this = shift;
    my $data;
    my $sys = $Foswiki::cfg{SystemWebName};

    # $SystemWebName.${name}Template
    write_topic( $sys, 'ScriptTemplate' );
    $data = $tmpls->readTemplate( 'script' );
    $this->assert_str_equals( "$sys/ScriptTemplate", $data );

    $data = $tmpls->readTemplate( 'script', web => 'web' );
    $this->assert_str_equals( "$sys/ScriptTemplate", $data );

    $data = $tmpls->readTemplate( 'script', skins => 'burnt' );
    $this->assert_str_equals( "$sys/ScriptTemplate", $data );

    $data = $tmpls->readTemplate( 'script', skins => 'burnt', web => 'web' );
    $this->assert_str_equals( "$sys/ScriptTemplate", $data );
}

sub test_WebTopicsB {
    my $this = shift;
    my $data;
    my $sys = $Foswiki::cfg{SystemWebName};

    # $SystemWebName.${skin}Skin${name}Template
    write_topic( $sys, 'ScriptTemplate' );
    write_topic( $sys, 'BurntSkinScriptTemplate' );

    $data = $tmpls->readTemplate( 'script' );
    $this->assert_str_equals( "$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', web => 'web' );
    $this->assert_str_equals( "$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', skins => 'burnt', web => 'web' );
    $this->assert_str_equals( "$sys/BurntSkinScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', skins => 'burnt' );
    $this->assert_str_equals( "$sys/BurntSkinScriptTemplate", $data );
}

sub test_WebTopicsC {
    my $this = shift;
    my $data;
    my $sys = $Foswiki::cfg{SystemWebName};

    # $web.${name}Template
    write_topic( $sys,  'ScriptTemplate' );
    write_topic( $sys,  'BurntSkinScriptTemplate' );
    write_topic( 'Web', 'ScriptTemplate' );

    $data = $tmpls->readTemplate( 'script' );
    $this->assert_str_equals( "$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', web => 'web' );
    $this->assert_str_equals( "Web/ScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', skins => 'burnt' );
    $this->assert_str_equals( "$sys/BurntSkinScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', skins => 'burnt', web => 'web' );
    $this->assert_str_equals( "$sys/BurntSkinScriptTemplate", $data );
}

sub test_WebTopicsD {
    my $this = shift;
    my $data;
    my $sys = $Foswiki::cfg{SystemWebName};

    # $web.${skin}Skin${name}Template
    write_topic( $sys,  'ScriptTemplate' );
    write_topic( $sys,  'BurntSkinScriptTemplate' );
    write_topic( 'Web', 'ScriptTemplate' );
    write_topic( 'Web', 'BurntSkinScriptTemplate' );

    $data = $tmpls->readTemplate( 'script' );
    $this->assert_str_equals( "$sys/ScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', web => 'web' );
    $this->assert_str_equals( "Web/ScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', skins => 'burnt' );
    $this->assert_str_equals( "$sys/BurntSkinScriptTemplate", $data );
    $data = $tmpls->readTemplate( 'script', skins => 'burnt', web => 'web' );
    $this->assert_str_equals( "Web/BurntSkinScriptTemplate", $data );
}

sub test_webTopicsE {
    my $this = shift;
    my $data;
    my $sys = $Foswiki::cfg{SystemWebName};

    # $web.$name
    write_topic( $sys,  'ScriptTemplate' );
    write_topic( $sys,  'BurntSkinScriptTemplate' );
    write_topic( 'Web', 'ScriptTemplate' );
    write_topic( 'Web', 'BurntSkinScriptTemplate' );
    write_topic( 'Web', 'Script' );
    $data = $tmpls->readTemplate( 'Web.Script' );
    $this->assert_str_equals( "Web/Script", $data );
    $data = $tmpls->readTemplate( 'Web.Script', web => 'web' );
    $this->assert_str_equals( "Web/Script", $data );
    $data = $tmpls->readTemplate( 'Web.Script', skins => 'burnt' );
    $this->assert_str_equals( "Web/Script", $data );
    $data = $tmpls->readTemplate( 'Web.Script', skins => 'burnt', web => 'web' );
    $this->assert_str_equals( "Web/Script", $data );
}

#Wishlist
# sub test_MixWebAndTemplates {
#
#    my $this = shift;
#    my $data;
#    my $sys = $Foswiki::cfg{SystemWebName};
#
#    write_template( 'script' );
#    write_template( 'script.skinned' );
#
#    write_topic( $sys, 'ScriptTemplate' );
#    write_topic( $sys, 'BaredSkinScriptTemplate' );
#    write_topic( 'Web', 'ScriptTemplate' );
#    write_topic( 'Web', 'SkinnedSkinScriptTemplate' );
#
#
#
#    $data = $tmpls->readTemplate('script' );
#    $this->assert_str_equals("script", $data );
#
#    $data = $tmpls->readTemplate('script', web => 'web' );
#    $this->assert_str_equals("Web/ScriptTemplate", $data );
#
#    $data = $tmpls->readTemplate('script', skins => 'skinned' );
#    $this->assert_str_equals("script.skinned", $data );
#
#
#    $data = $tmpls->readTemplate('script', skins => 'skinned', web => 'web' );
#    $this->assert_str_equals("Web/SkinnedSkinScriptTemplate", $data );
#
#    $data = $tmpls->readTemplate('script', skins => 'bared' );
#    $this->assert_str_equals("$sys/BaredSkinScriptTemplate", $data );
#
#Which one makes more sense?
#    $data = $tmpls->readTemplate('script', web => 'bared,skinned','web' );
#    $this->assert_str_equals("Web/SkinnedSkinScriptTemplate", $data );
#    $this->assert_str_equals("Web/BaredSkinScriptTemplate", $data );
#
#}

sub language_setup {
    write_template(
        'strings', '
%TMPL:DEF{"Question"}%Do you see?%TMPL:END%
%TMPL:DEF{"Yes"}%Yes%TMPL:END%
%TMPL:DEF{"No"}%No%TMPL:END%
'
    );
    write_template(
        'strings.gaelic', '
%TMPL:DEF{"Question"}%An faca sibh?%TMPL:END%
%TMPL:DEF{"Yes"}%Chunnaic%TMPL:END%
%TMPL:DEF{"No"}%Chan fhaca%TMPL:END%
'
    );
    write_template( "pattern", '%TMPL:INCLUDE{"strings"}%SKIN=pattern ' );

    write_template(
        'example', '%TMPL:INCLUDE{"pattern"}%%TMPL:P{"Question"}%
<input type="button" value="%TMPL:P{"No"}%">
<input type="button" value="%TMPL:P{"Yes"}%">
'
    );
}

sub test_languageEnglish {
    my $this = shift;
    my $data;

    language_setup();
    $data = $tmpls->readTemplate( 'example', skins => 'pattern' );
    $this->assert_str_equals( '
SKIN=pattern Do you see?
<input type="button" value="No">
<input type="button" value="Yes">
', $data );
}

sub test_languageGaelic {
    my $this = shift;
    my $data;

    language_setup();
    $data = $tmpls->readTemplate( 'example', skins => 'gaelic,pattern' );
    $this->assert_str_equals( '
SKIN=pattern An faca sibh?
<input type="button" value="Chan fhaca">
<input type="button" value="Chunnaic">
', $data );
}

sub test_TMPLPREV {
    my $this = shift;
    my $data;

    language_setup();
    
    write_template(
        'strings.prev', '%TMPL:INCLUDE{strings}%
%TMPL:DEF{"Question"}%%TMPL:PREV% - 1234%TMPL:END%
'
    );
    
    $data = $tmpls->readTemplate( 'example', skins => 'prev,gaelic,pattern' );
    $this->assert_str_equals( '
SKIN=pattern An faca sibh? - 1234
<input type="button" value="Chan fhaca">
<input type="button" value="Chunnaic">
', $data );

    $data = $tmpls->readTemplate( 'example', skins => 'prev,pattern' );
    $this->assert_str_equals( '
SKIN=pattern Do you see? - 1234
<input type="button" value="No">
<input type="button" value="Yes">
', $data );

}

1;
