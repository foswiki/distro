package ViewScriptTests;
use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );

my $UI_FN;

my $topic1 = <<'HERE';
CONTENT
HERE

my $topic2 = <<'HERE';
----
MissingWikiWord %BR%
!ExclamationEscape <br />
<nop>NopEscape 
%RED% <pre> adsf </pre> <verbatim> qwerty </verbatim>
<p>A Paragraph </p>
#anchor
<a href="http://blah.com/">asdf</a>
<noautolink>
NotTOAutoLink
</noautolink>
----
HERE

my $topic2meta =
'%META:TOPICINFO{author="BaseUserMapping_666" comment="save topic" date="[0-9]{10,10}" format="1.1" version="1"}%'
  . "\n";
my $topic2metaQ = $topic2meta;
$topic2metaQ =~ s/"/&quot;/g;

my $topic2txtarea =
'<textarea name=""  rows="22" cols="70" readonly="readonly" style="width:99%" id="topic" class="foswikiTextarea foswikiTextareaRawView">';

my $topic2rawON = $topic2;
$topic2rawON =~ s/</&lt;/g;
$topic2rawON =~ s/>/&gt;/g;
$topic2rawON =~ s/"/&quot;/g;
$topic2rawON .= '</textarea>';

my $templateTopicContent1 = <<'HERE';
pretemplate%STARTTEXT%pre%TEXT%post%ENDTEXT%posttemplate
HERE

my $templateTopicContent2 = <<'HERE';
pretemplate%TEXT%post%ENDTEXT%posttemplate
HERE

my $templateTopicContent3 = <<'HERE';
pretemplate%STARTTEXT%pre%TEXT%posttemplate
HERE

my $templateTopicContent4 = <<'HERE';
pretemplate%TEXT%posttemplate
HERE

my $templateTopicContent5 = <<'HERE';
pretemplate%STARTTEXT%posttemplate
HERE

## Should this be supported?
my $templateTopicContentX = <<'HERE';
pretemplate%STARTTEXT%pre%ENDTEXT%posttemplate
HERE

sub new {
    my ( $class, @args ) = @_;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    return $class->SUPER::new( "ViewScript", @args );
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $UI_FN ||= $this->getUIFn('view');

    #set up nested web $this->{test_web}/Nest
    $this->{test_subweb} = $this->{test_web} . '/Nest';
    my $topic = 'TestTopic1';
    my ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'TestTopic1' );
    $meta->text($topic1);
    $meta->save();
    $meta->finish();

    $topic = 'TestTopic2';
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'TestTopic2' );
    $meta->text($topic2);
    $meta->save();
    $meta->finish();

    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'ViewoneTemplate' );
    $meta->text($templateTopicContent1);
    $meta->save( user => $this->{test_user_wikiname} );
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'ViewtwoTemplate' );
    $meta->text($templateTopicContent2);
    $meta->save( user => $this->{test_user_wikiname} );
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, 'ViewthreeTemplate' );
    $meta->text($templateTopicContent3);
    $meta->save( user => $this->{test_user_wikiname} );
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'ViewfourTemplate' );
    $meta->text($templateTopicContent4);
    $meta->save( user => $this->{test_user_wikiname} );
    $meta->finish();
    ($meta) = Foswiki::Func::readTopic( $this->{test_web}, 'ViewfiveTemplate' );
    $meta->text($templateTopicContent5);
    $meta->save( user => $this->{test_user_wikiname} );
    $meta->finish();

    try {
        $this->createNewFoswikiSession('AdminUser');

        my $webObject = $this->populateNewWeb( $this->{test_subweb} );
        $webObject->finish();
        $this->assert( $this->{session}->webExists( $this->{test_subweb} ) );
        my ($topicObject) =
          Foswiki::Func::readTopic( $this->{test_subweb},
            $Foswiki::cfg{HomeTopicName} );
        $topicObject->text("SMELL");
        $topicObject->save();
        $topicObject->finish();
        $this->assert(
            $this->{session}->topicExists(
                $this->{test_subweb}, $Foswiki::cfg{HomeTopicName}
            )
        );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_subweb}, $topic );
    $topicObject->text('nested topci1 text');
    $topicObject->save();
    $topicObject->finish();

    #set up nested web _and_ topic called $this->{test_web}/ThisTopic
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'ThisTopic' );
    $topicObject->text('nested ThisTopic text');
    $topicObject->save();
    $topicObject->finish();
    $this->{test_clashingsubweb} = $this->{test_web} . '/ThisTopic';
    $topic = 'TestTopic1';

    try {
        $this->createNewFoswikiSession('AdminUser');

        my $webObject = $this->populateNewWeb( $this->{test_clashingsubweb} );
        $webObject->finish();
        $this->assert(
            $this->{session}->webExists( $this->{test_clashingsubweb} ) );
        ($topicObject) = Foswiki::Func::readTopic( $this->{test_clashingsubweb},
            $Foswiki::cfg{HomeTopicName} );
        $topicObject->text("SMELL");
        $topicObject->save();
        $topicObject->finish();
        $this->assert(
            $this->{session}->topicExists(
                $this->{test_clashingsubweb},
                $Foswiki::cfg{HomeTopicName}
            )
        );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_clashingsubweb}, $topic );
    $topicObject->text('nested topci1 text');
    $topicObject->save();
    $topicObject->finish();

    return;
}

sub setup_view {
    my ( $this, $web, $topic, $tmpl, $raw, $ctype, $skin ) = @_;
    my $query = Unit::Request->new(
        {
            webName     => [$web],
            topicName   => [$topic],
            template    => [$tmpl],
            raw         => [$raw],
            contenttype => [$ctype],
            skin        => [$skin],
        }
    );
    $query->path_info("/$web/$topic");
    $query->method('POST');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    my ($text) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    my $editUrl =
      $this->{session}->getScriptUrl( '0', 'edit', $this->{test_web}, '' );

    $text =~ s/\r//g;
    $text =~ s/(^.*?\n\n+)//s;    # remove CGI header
    return ( $text, $1, $editUrl );
}

# This test verifies the rendering of the various raw views
sub test_render_raw {
    my $this = shift;
    my $text;
    my $hdr;

    ( $text, $hdr ) =
      $this->setup_view( $this->{test_web}, 'TestTopic2', 'viewfour', 'text' );
    $this->assert_equals( "$topic2", $text, "Unexpected output from raw=text" );
    $this->assert_matches( qr#^Content-Type: text/plain#ms,
        $hdr, "raw=text should return text/plain - got $hdr" );

    ( $text, $hdr ) =
      $this->setup_view( $this->{test_web}, 'TestTopic2', 'viewfour', 'all' );
    $this->assert_matches( qr#$topic2meta$topic2#, $text,
        "Unexpected output from raw=all" );
    $this->assert_matches( qr#^Content-Type: text/plain#ms,
        $hdr, "raw=all should return text/plain - got $hdr" );

    ( $text, $hdr ) =
      $this->setup_view( $this->{test_web}, 'TestTopic2', 'viewfour', 'on' );
    $this->assert_matches( qr#.*$topic2txtarea$topic2rawON.*#,
        $text, "Unexpected output from raw=on" );
    $this->assert_matches( qr#^Content-Type: text/html#ms,
        $hdr, "raw=on should return text/html - got $hdr" );

    ( $text, $hdr ) =
      $this->setup_view( $this->{test_web}, 'TestTopic2', 'viewfour', 'debug' );
    $this->assert_matches( qr#.*$topic2txtarea$topic2metaQ$topic2rawON.*#,
        $text, "Unexpected output from raw=debug" );
    $this->assert_matches( qr#^Content-Type: text/html#ms,
        $hdr, "raw=debug should return text/html - got $hdr" );

    return;
}

# This test verifies the rendering of the text/plain
sub test_render_textplain {
    my $this = shift;
    my $text;
    my $hdr;
    my $editUrl;

    ( $text, $hdr, $editUrl ) =
      $this->setup_view( $this->{test_web}, 'TestTopic2', 'viewfour', '',
        'text/plain', 'text' );
    $editUrl =~ s/WebHome/MissingWikiWord/;

    my $topic2plain = <<"HERE";
pretemplate<hr />
<span class="foswikiNewLink">MissingWikiWord<a href="$editUrl?topicparent=TemporaryViewScriptTestWebViewScript.TestTopic2" rel="nofollow" title="Create this topic">?</a></span> <br />
ExclamationEscape <br />
NopEscape 
<span class='foswikiRedFG'> <pre> adsf </pre> <pre> qwerty </pre>
<p>A Paragraph </p>
#anchor
<a href="http://blah.com/">asdf</a>
NotTOAutoLink
<hr />posttemplate
HERE
    chomp $topic2plain;
    $this->assert_matches( qr#^Content-Type: text/plain#ms,
        $hdr, "contenttype=text/plain should return text/plain - got $hdr" );
    $this->assert_does_not_match( qr#<(noautolink|nop)>#, $text,
        "autolink or nop found in text skin" );
    $this->assert_equals( "$topic2plain", $text,
        "Unexpected output from contentype=text/plain skin=text" );

    return;
}

# This test verifies the handling of preamble (the text following
# %STARTTEXT%) and postamble (the text between %TEXT% and %ENDTEXT%).
sub test_prepostamble {
    my $this = shift;
    my $text;

    ($text) = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewone' );
    $text =~ s/\n+$//s;
    $this->assert_equals(
        'pretemplatepreCONTENT
postposttemplate', $text
    );

    ($text) = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewtwo' );
    $this->assert_equals(
        'pretemplateCONTENT
postposttemplate', $text
    );

    ($text) = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewthree' );
    $this->assert_equals( 'pretemplatepreCONTENTposttemplate', $text );

    ($text) = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewfour' );
    $this->assert_equals( 'pretemplateCONTENTposttemplate', $text );

    ($text) = $this->setup_view( $this->{test_web}, 'TestTopic1', 'viewfive' );
    $this->assert_equals( 'pretemplateposttemplate', $text );

    return;
}

sub urltest {
    my ( $this, $url, $web, $topic ) = @_;
    my $query = Unit::Request->new( {} );
    $query->setUrl($url);
    $query->method('GET');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->assert_equals( $web,   $this->{session}->{webName} );
    $this->assert_equals( $topic, $this->{session}->{topicName} );

    return;
}

sub test_urlparsing {
    my $this = shift;

    $this->urltest( '',  $this->{users_web}, 'WebHome' );
    $this->urltest( '/', $this->{users_web}, 'WebHome' );

#SMELL: This has always been the case - sven recals changing it once and that causing issues?
    $this->urltest( '/?topic=WebChanges', '', 'WebChanges' );

    $this->urltest( '/?topic=System.WebChanges', 'System', 'WebChanges' );

    if ( $this->check_dependency('Foswiki,>=,1.2') ) {

        # the defaultweb parameter is new in 1.2
        $this->urltest( '/?topic=System.WebChanges;defaultweb=Sandbox',
            'System', 'WebChanges' );
        $this->urltest( '/?topic=WebChanges;defaultweb=Sandbox',
            'Sandbox', 'WebChanges' );
        $this->urltest( '/System?topic=WebChanges;defaultweb=Sandbox',
            'System', 'WebChanges' );
    }

    #    $this->urltest('Sandbox', 'Sandbox', 'WebHome');
    $this->urltest( '/Sandbox',           'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox/',          'Sandbox',         'WebHome' );
    $this->urltest( '//Sandbox',          'Sandbox',         'WebHome' );
    $this->urltest( '///Sandbox',         'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox//',         'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox///',        'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox/WebHome',   'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox//WebHome',  'Sandbox',         'WebHome' );
    $this->urltest( '/Sandbox/WebHome/',  'Sandbox/WebHome', 'WebHome' );
    $this->urltest( '/Sandbox/WebHome//', 'Sandbox/WebHome', 'WebHome' );

    $this->urltest( '/Sandbox/WebIndex',    'Sandbox',          'WebIndex' );
    $this->urltest( '/Sandbox//WebIndex',   'Sandbox',          'WebIndex' );
    $this->urltest( '/Sandbox///WebIndex',  'Sandbox',          'WebIndex' );
    $this->urltest( '/Sandbox/WebIndex/',   'Sandbox/WebIndex', 'WebHome' );
    $this->urltest( '/Sandbox/WebIndex//',  'Sandbox/WebIndex', 'WebHome' );
    $this->urltest( '/Sandbox/WebIndex///', 'Sandbox/WebIndex', 'WebHome' );

    $this->urltest( '/Sandbox/WebIndex?asd=w',    'Sandbox', 'WebIndex' );
    $this->urltest( '/Sandbox//WebIndex?asd=qwe', 'Sandbox', 'WebIndex' );
    $this->urltest( '/Sandbox/WebIndex/?asd=qwe', 'Sandbox/WebIndex',
        'WebHome' );
    $this->urltest( '/Sandbox/WebIndex//?asd=ewr', 'Sandbox/WebIndex',
        'WebHome' );

    $this->urltest( '/Sandbox/WebIndex?topic=WebChanges',
        'Sandbox', 'WebChanges' );
    $this->urltest( '/Sandbox//WebIndex?topic=WebChanges',
        'Sandbox', 'WebChanges' );
    $this->urltest( '/Sandbox/WebIndex/?topic=WebChanges',
        'Sandbox/WebIndex', 'WebChanges' );
    $this->urltest( '/Sandbox/WebIndex//?topic=WebChanges',
        'Sandbox/WebIndex', 'WebChanges' );

    $this->urltest( '/Sandbox?topic=WebChanges',   'Sandbox', 'WebChanges' );
    $this->urltest( '/Sandbox/?topic=WebChanges',  'Sandbox', 'WebChanges' );
    $this->urltest( '/Sandbox//?topic=WebChanges', 'Sandbox', 'WebChanges' );

    $this->urltest( '/Sandbox/WebIndex?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/Sandbox//WebIndex?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/Sandbox/WebIndex/?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/Sandbox/WebIndex//?topic=System.WebChanges',
        'System', 'WebChanges' );

    $this->urltest( '/Sandbox?topic=System.WebChanges', 'System',
        'WebChanges' );
    $this->urltest( '/Sandbox/?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/Sandbox//?topic=System.WebChanges',
        'System', 'WebChanges' );

#nested
#    $this->urltest($this->{test_subweb}, $this->{test_subweb}, 'WebHome');
#    $this->urltest('/'.$this->{test_subweb}, $this->{test_subweb}, 'WebHome');
#    $this->urltest('/'.$this->{test_subweb}.'/', $this->{test_subweb}, 'WebHome');
#    $this->urltest('//'.$this->{test_subweb}, $this->{test_subweb}, 'WebHome');
#    $this->urltest('///'.$this->{test_subweb}, $this->{test_subweb}, 'WebHome');
#    $this->urltest('/'.$this->{test_subweb}.'$this->{test_subweb}//', $this->{test_subweb}, 'WebHome');
#    $this->urltest('/'.$this->{test_subweb}.'///', $this->{test_subweb}, 'WebHome');
    $this->urltest( '/' . $this->{test_subweb} . '/WebHome',
        $this->{test_subweb}, 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '//WebHome',
        $this->{test_subweb}, 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebHome/',
        $this->{test_subweb} . '/WebHome', 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebHome//',
        $this->{test_subweb} . '/WebHome', 'WebHome' );

    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '//WebIndex',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '///WebIndex',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex/',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex//',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex///',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );

    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex?asd=w',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '//WebIndex?asd=qwe',
        $this->{test_subweb}, 'WebIndex' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex/?asd=qwe',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex//?asd=ewr',
        $this->{test_subweb} . '/WebIndex', 'WebHome' );

    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex?topic=WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '//WebIndex?topic=WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex/?topic=WebChanges',
        $this->{test_subweb} . '/WebIndex', 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '/WebIndex//?topic=WebChanges',
        $this->{test_subweb} . '/WebIndex', 'WebChanges' );

#    $this->urltest('/'.$this->{test_subweb}.'?topic=WebChanges', $this->{test_subweb}, 'WebChanges');
#    $this->urltest('/'.$this->{test_subweb}.'/?topic=WebChanges', $this->{test_subweb}, 'WebChanges');
#    $this->urltest('/'.$this->{test_subweb}.'//?topic=WebChanges', $this->{test_subweb}, 'WebChanges');

    $this->urltest(
        '/' . $this->{test_subweb} . '/WebIndex?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest(
        '/' . $this->{test_subweb} . '//WebIndex?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest(
        '/' . $this->{test_subweb} . '/WebIndex/?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest(
        '/' . $this->{test_subweb} . '/WebIndex//?topic=System.WebChanges',
        'System', 'WebChanges' );

    $this->urltest( '/' . $this->{test_subweb} . '?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '/?topic=System.WebChanges',
        'System', 'WebChanges' );
    $this->urltest( '/' . $this->{test_subweb} . '//?topic=System.WebChanges',
        'System', 'WebChanges' );

    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '/WebIndex?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '//WebIndex?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '/WebIndex/?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '/WebIndex//?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );

    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '/?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );
    $this->urltest(
        '/'
          . $this->{test_subweb}
          . '//?topic='
          . $this->{test_subweb}
          . '.WebChanges',
        $this->{test_subweb}, 'WebChanges'
    );

    $this->urltest(
        '/System/WebIndex?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest(
        '/System//WebIndex?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest(
        '/System/WebIndex/?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest(
        '/System/WebIndex//?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );

    $this->urltest( '/System?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest( '/System/?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );
    $this->urltest( '/System//?topic=' . $this->{test_subweb} . '.WebChanges',
        $this->{test_subweb}, 'WebChanges' );

    #nonexistant webs
    #noneexistant topics (Item598)
    $this->urltest( '/Sandbox/ThisTopicShouldNotExist',
        'Sandbox', 'ThisTopicShouldNotExist' );
    $this->urltest(
        '/Sandbox/ThisTopicShouldNotExist/',
        'Sandbox/ThisTopicShouldNotExist',
        'WebHome'
    );

    $this->urltest( '/' . $this->{test_subweb} . '/ThisTopicShouldNotExist',
        $this->{test_subweb}, 'ThisTopicShouldNotExist' );
    $this->urltest( '/' . $this->{test_subweb} . '/ThisTopicShouldNotExist/',
        $this->{test_subweb} . '/ThisTopicShouldNotExist', 'WebHome' );

    #both topic and subweb of same name exists (Item598)
    #$this->{test_web}/ThisTopic is both a web and a topic
    $this->urltest( '/' . $this->{test_web} . '/ThisTopic',
        $this->{test_web}, 'ThisTopic' );    #the only way yo get to the topic
    $this->urltest( '/' . $this->{test_web} . '/ThisTopic/',
        $this->{test_web} . '/ThisTopic', 'WebHome' );
    $this->urltest( '/' . $this->{test_web} . '/ThisTopic/WebHome',
        $this->{test_web} . '/ThisTopic', 'WebHome' );
    $this->urltest( '/' . $this->{test_web} . '/ThisTopic/WebHome/',
        $this->{test_web} . '/ThisTopic/WebHome', 'WebHome' );

    #invalid..

    # - Invalid web name - Tasks.Item8713
    $this->urltest( '/A:B/WebPreferences', '', 'WebPreferences' );

    return;
}

1;
