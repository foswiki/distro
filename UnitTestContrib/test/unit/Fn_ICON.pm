# tests for the correct expansion of ICON*
package Fn_ICON;

use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
use Assert;

sub new {
    my $self = shift()->SUPER::new( 'ICON', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    my $it = Foswiki::Func::getPreferencesValue('ICONTOPIC');
    $it =~ s/\./\//;
    $this->{reliconurl} =
      $Foswiki::cfg{PubUrlPath} . '/'
      . Foswiki::Func::expandCommonVariables($it);
    $this->{absiconurl} = $Foswiki::cfg{DefaultUrlHost} . $this->{reliconurl};
}

sub test_ICONURL {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables('%ICONURL%');
    $this->assert_equals( $this->{absiconurl} . '/else.png', $t );
    $t = Foswiki::Func::expandCommonVariables('%ICONURL{"unknown"}%');
    $this->assert_equals( $this->{absiconurl} . '/else.png', $t );
    $t = Foswiki::Func::expandCommonVariables('%ICONURL{"else"}%');
    $this->assert_equals( $this->{absiconurl} . '/else.png', $t );
    $t = Foswiki::Func::expandCommonVariables('%ICONURL{"else.gif"}%');
    $this->assert_equals( $this->{absiconurl} . '/gif.png', $t );
    $t = Foswiki::Func::expandCommonVariables('%ICONURL{"doc"}%');
    $this->assert_equals( $this->{absiconurl} . '/doc.png', $t );
}

sub test_ICONURLPATH {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables('%ICONURLPATH%');
    $this->assert_str_equals( $this->{reliconurl} . '/else.png', $t );
    $t = Foswiki::Func::expandCommonVariables('%ICONURLPATH{"unknown"}%');
    $this->assert_equals( $this->{reliconurl} . '/else.png', $t );
    $t = Foswiki::Func::expandCommonVariables('%ICONURLPATH{"else"}%');
    $this->assert_equals( $this->{reliconurl} . '/else.png', $t );
    $t = Foswiki::Func::expandCommonVariables('%ICONURLPATH{"else.gif"}%');
    $this->assert_equals( $this->{reliconurl} . '/gif.png', $t );
    $t = Foswiki::Func::expandCommonVariables('%ICONURLPATH{"doc"}%');
    $this->assert_equals( $this->{reliconurl} . '/doc.png', $t );
}

sub test_ICON {
    my $this     = shift;
    my $html     = '<span class=foswikiIcon><img width="16" height="16" src="';
    my $postHtml = '</span>';
    my $t        = Foswiki::Func::expandCommonVariables("%ICON%");
    $this->assert_html_equals(
        $html . $this->{reliconurl} . '/else.png" alt="else"/>' . $postHtml,
        $t );
    $t = Foswiki::Func::expandCommonVariables(
        '%ICON{"unknown" default="argh" alt="argh"}%');
    $this->assert_html_equals(
        $html . $this->{reliconurl} . '/else.png" alt="argh" />' . $postHtml,
        $t );
    $t = Foswiki::Func::expandCommonVariables(
        '%ICON{"unknown" default="gif" alt="argh"}%');
    $this->assert_html_equals(
        $html . $this->{reliconurl} . '/gif.png" alt="argh" />' . $postHtml,
        $t );
    $t = Foswiki::Func::expandCommonVariables(
        '%ICON{"unknown.trap" default="flup.doc"}%');
    $this->assert_html_equals(
        $html
          . $this->{reliconurl}
          . '/doc.png" alt="unknown.trap" />'
          . $postHtml,
        $t
    );
    $t = Foswiki::Func::expandCommonVariables('%ICON{"else"}%');
    $this->assert_html_equals(
        $html . $this->{reliconurl} . '/else.png" alt="else" />' . $postHtml,
        $t );
    $t = Foswiki::Func::expandCommonVariables('%ICON{"else.gif"}%');
    $this->assert_html_equals(
        $html . $this->{reliconurl} . '/gif.png" alt="else.gif" />' . $postHtml,
        $t
    );
    $t = Foswiki::Func::expandCommonVariables('%ICON{"doc"}%');
    $this->assert_html_equals(
        $html . $this->{reliconurl} . '/doc.png" alt="doc" />' . $postHtml,
        $t );

    $t = Foswiki::Func::expandCommonVariables('%ICON{"doc" quote="\'"}%');
    $this->assert_matches( qr/'/, $t );
    $t = Foswiki::Func::expandCommonVariables('%ICON{"doc" quote="\\""}%');
    $this->assert_matches( qr/"/, $t );
    $t = Foswiki::Func::expandCommonVariables('%ICON{"doc" quote="$quot"}%');
    $this->assert_matches( qr/\$quot/, $t );

    # SMELL: depends on _filetypes.txt being correct
    $t = Foswiki::Func::expandCommonVariables(
        '%ICON{"unknown.tgz" default="argh" alt="bunshop"}%');
    $this->assert_html_equals(
        $html . $this->{reliconurl} . '/zip.png" alt="bunshop" />' . $postHtml,
        $t
    );
}

sub test_PUBURL {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables('%PUBURL%');
    $this->assert_URI_equals(
        "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}", $t );
    $t = Foswiki::Func::expandCommonVariables('%PUBURL{web="Web"}%');
    $this->assert_URI_equals(
        "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}/Web", $t );
    $t = Foswiki::Func::expandCommonVariables('%PUBURL{topic="Web.Topic"}%');
    $this->assert_URI_equals(
        "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}/Web/Topic",
        $t );
    $t =
      Foswiki::Func::expandCommonVariables('%PUBURL{web="Web" topic="Topic"}%');
    $this->assert_URI_equals(
        "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}/Web/Topic",
        $t );
    $t = Foswiki::Func::expandCommonVariables(
        '%PUBURL{topic="Web.Topic" "att.dat"}%');
    $this->assert_URI_equals(
"$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}/Web/Topic/att.dat",
        $t
    );
}

sub test_PUBURLPATH {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables('%PUBURLPATH%');
    $this->assert_URI_equals( $Foswiki::cfg{PubUrlPath}, $t );
    $t = Foswiki::Func::expandCommonVariables('%PUBURLPATH{web="Web"}%');
    $this->assert_URI_equals( "$Foswiki::cfg{PubUrlPath}/Web", $t );
    $t =
      Foswiki::Func::expandCommonVariables('%PUBURLPATH{topic="Web.Topic"}%');
    $this->assert_URI_equals( "$Foswiki::cfg{PubUrlPath}/Web/Topic", $t );
    $t = Foswiki::Func::expandCommonVariables(
        '%PUBURLPATH{topic="Web.Topic" "att.dat"}%');
    $this->assert_URI_equals( "$Foswiki::cfg{PubUrlPath}/Web/Topic/att.dat",
        $t );
}

sub test_ATTACHURL {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables('%ATTACHURL%');
    $this->assert_URI_equals(
"$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{PubUrlPath}/$this->{test_web}/$this->{test_topic}",
        $t
    );
}

sub test_ATTACHURLPATH {
    my $this = shift;
    my $t    = Foswiki::Func::expandCommonVariables('%ATTACHURLPATH%');
    $this->assert_URI_equals(
        "$Foswiki::cfg{PubUrlPath}/$this->{test_web}/$this->{test_topic}", $t );
}

1;
