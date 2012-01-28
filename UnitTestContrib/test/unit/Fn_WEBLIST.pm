# tests for the correct expansion of WEBLIST

package Fn_WEBLIST;
use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'WEBLIST', @_ );
    return $self;
}

my @allWebs;
my @templateWebs;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $webObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Dive1" );
    $webObject->populateNewWeb();

    $webObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Dive1/Dive2" );
    $webObject->populateNewWeb();

    $webObject =
      Foswiki::Meta->new( $this->{session},
        "$this->{test_web}/Dive1/Dive2/Dive3" );
    $webObject->populateNewWeb();

    $webObject =
      Foswiki::Meta->new( $this->{session},
        "$this->{test_web}/Dive1/_Dive2tmpl" );
    $webObject->populateNewWeb();

    Foswiki::Func::readTemplate('foswiki');
    @allWebs      = Foswiki::Func::getListOfWebs('user,public,allowed');
    @templateWebs = Foswiki::Func::getListOfWebs('template,allowed');

}

# The spec of the "webs" and "subwebs" parameters are utterly fucked.
# "webs" specifies a set of webs to consider. If it is undefined, then it
# defaults to all root level webs. Otherwise it is treated as an ordered
# list of web names. There are two pseudo-webs that can be included in this
# list, 'public' and 'webtemplate' which each generate complete lists of
# _all_ webs with "user,public,allowed" and "template,allowed" characteristics
# respectively. Obviously this can result in the same web being included in
# the list multiple times.
# If "subwebs" is also defined, then it is taken as the pathname of *a single
# web*. In this case, "public" and "webtemplate" become lists of webs
# relative to this web.

sub test_public {
    my $this = shift;

    # separator=", " 	Line separator Default: "$n" (new line)
    my $text = $this->{test_topicObject}->expandMacros('%WEBLIST%');
    $this->assert_str_equals( join( "\n", @allWebs ), $text );
    $text = $this->{test_topicObject}->expandMacros('%WEBLIST{webs="public"}%');
    $this->assert_str_equals( join( "\n", @allWebs ), $text );
}

sub test_template {
    my $this = shift;

    foreach my $tweb (@templateWebs) {
        $this->assert_matches( qr#^_|\/_#, $tweb,
            "non-template web returned from Func\n" );
    }

    my $text =
      $this->{test_topicObject}->expandMacros('%WEBLIST{webs="webtemplate"}%');
    $this->assert_str_equals( join( "\n", @templateWebs ), $text );

    $text =
      $this->{test_topicObject}->expandMacros(
        "%WEBLIST{webs=\"webtemplate\" subwebs=\"$this->{test_web}\"}%");
    $this->assert_str_equals( "$this->{test_web}/Dive1/_Dive2tmpl", $text );

}

sub test_no_format_no_separator {
    my $this = shift;

    # separator=", " 	Line separator Default: "$n" (new line)
    my $text = $this->{test_topicObject}->expandMacros('%WEBLIST{}%');
    $this->assert_str_equals( join( "\n", @allWebs ), $text );
}

sub test_no_format_with_separator {
    my $this = shift;

    # separator=", " 	Line separator Default: "$n" (new line)
    my $text =
      $this->{test_topicObject}->expandMacros('%WEBLIST{separator=";"}%');
    $this->assert_str_equals( join( ';', @allWebs ), $text );
}

sub test_no_format_empty_separator {
    my $this = shift;

    # separator=", " 	Line separator Default: "$n" (new line)
    my $text =
      $this->{test_topicObject}->expandMacros('%WEBLIST{separator=""}%');
    $this->assert_str_equals( join( "\n", @allWebs ), $text );
}

sub test_with_format_no_separator {
    my $this = shift;

    # separator=", " 	Line separator Default: "$n" (new line)
    my $text = $this->{test_topicObject}->expandMacros('%WEBLIST{"$name"}%');
    $this->assert_str_equals( join( "\n", @allWebs ), $text );
}

sub test_with_format_with_separator {
    my $this = shift;

    # separator=", " 	Line separator Default: "$n" (new line)
    my $text =
      $this->{test_topicObject}
      ->expandMacros('%WEBLIST{"$name" separator=";"}%');
    $this->assert_str_equals( join( ';', @allWebs ), $text );
}

sub test_with_format_empty_separator {
    my $this = shift;

    # separator=", " 	Line separator Default: "$n" (new line)
    my $text =
      $this->{test_topicObject}
      ->expandMacros('%WEBLIST{"$name" separator=""}%');
    $this->assert_str_equals( join( "\n", @allWebs ), $text );
}

sub test_format {
    my $this = shift;

    # "format" Format of one line, may include $name (the name of
    #          the web), $qname (the name of the web in double quotes),
    # web=""   if you specify $web in format, it will be replaced with
    #          this Default: ""
    my $text =
      $this->{test_topicObject}
      ->expandMacros('%WEBLIST{"$name:$qname:$web" web="sponge"}%');
    $this->assert_str_equals( join( "\n", map { "$_:\"$_\":sponge" } @allWebs ),
        $text );
    $text =
      $this->{test_topicObject}->expandMacros('%WEBLIST{"$name:$qname:$web"}%');
    $this->assert_str_equals( join( "\n", map { "$_:\"$_\":" } @allWebs ),
        $text );

    # format="format" 	(Alternative to above) Default: "$name"
    $text =
      $this->{test_topicObject}
      ->expandMacros('%WEBLIST{format="$name:$qname:$web" web="sponge"}%');
    $this->assert_str_equals( join( "\n", map { "$_:\"$_\":sponge" } @allWebs ),
        $text );
}

sub test_subwebs {
    my $this = shift;

    # subwebs="" show sub-webs of this web (recursively) Default: ""
    my $text =
      $this->{test_topicObject}
      ->expandMacros( '%WEBLIST{subwebs="' . $this->{test_web} . '"}%' );
    $this->assert_str_equals( <<THIS, "$text\n" );
$this->{test_web}/Dive1
$this->{test_web}/Dive1/Dive2
$this->{test_web}/Dive1/Dive2/Dive3
THIS
}

sub test_indentedname {
    my $this = shift;

    #          $indentedname (the name of the web with parent web names
    #          replaced by indents, for use in indented lists)
    my $text =
      $this->{test_topicObject}->expandMacros(
        '%WEBLIST{"$indentedname" subwebs="' . $this->{test_web} . '"}%' );
    $this->assert_str_equals( <<THIS, "$text\n" );
<span class='foswikiWebIndent'></span>Dive1
<span class='foswikiWebIndent'></span><span class='foswikiWebIndent'></span>Dive2
<span class='foswikiWebIndent'></span><span class='foswikiWebIndent'></span><span class='foswikiWebIndent'></span>Dive3
THIS
}

sub test_marker {
    my $this = shift;

    # marker="selected" Text for $marker if the item matches selection
    #                   Default: "selected"
    # selection="%WEB%" Current value to be selected in list Default: "%WEB%"
    my $text =
      $this->{test_topicObject}->expandMacros(
        '%WEBLIST{selection="' . $allWebs[1] . '" format="$name$marker"}%' );
    my @munged = @allWebs;
    $munged[1] = "$munged[1]selected=\"selected\"";
    $this->assert_str_equals( join( "\n", @munged ), $text );
    $text =
      $this->{test_topicObject}->expandMacros( '%WEBLIST{selection="'
          . $allWebs[1]
          . '" marker="sponge" format="$name$marker"}%' );
    @munged = @allWebs;
    $munged[1] = "$munged[1]sponge";
    $this->assert_str_equals( join( "\n", @munged ), $text );
}

sub test_webs {
    my $this = shift;

    # webs="public" 	Comma separated list of webs, public expands to all
    #                   non-hidden.
    #                   NOTE: Administrators will see all webs, not just the
    #                   public ones Default: "public"
    my $text =
      $this->{test_topicObject}
      ->expandMacros( '%WEBLIST{webs="' . $this->{test_web} . '"}%' );
    $this->assert_str_equals( $this->{test_web}, $text );
    $text = $this->{test_topicObject}->expandMacros('%WEBLIST{webs="public"}%');
    $this->assert_str_equals( join( "\n", @allWebs ), $text );
    $text =
      $this->{test_topicObject}->expandMacros('%WEBLIST{webs="webtemplate"}%');
    $this->assert_str_equals( join( "\n", @templateWebs ), $text );
}

# Tests moved from HierarchicalWebsTests.pm

sub test_WEBLIST_all {
    my $this = shift;

    my $text =
      $this->{test_topicObject}
      ->expandMacros(' %WEBLIST{format="#$name#" separator=" "}% ');

    foreach my $web ( $this->{test_web}, "$this->{test_web}/Dive1",
        $Foswiki::cfg{UsersWebName},
        'Sandbox', $Foswiki::cfg{SystemWebName} )
    {
        $this->assert_matches( qr!#$web#!, $text );
    }
}

sub test_WEBLIST_relative {
    my $this = shift;

    my $text =
      $this->{test_topicObject}
      ->expandMacros( ' %WEBLIST{format="#$name#" separator=" " subwebs="'
          . $this->{test_web}
          . '"}% ' );
    $this->assert_matches( qr!#$this->{test_web}/Dive1#!, $text );
}

sub test_WEBLIST_end {
    my $this = shift;

    my $text =
        ' %WEBLIST{format="#$name#" separator=" " subwebs="'
      . $this->{test_web}
      . '/Dive1/Dive2/Dive3"}% ';
    $text = $this->{test_topicObject}->expandMacros($text);
    $this->assert_equals( '  ', $text );
}

1;
__END__
%WEBLIST{ webs="webtemplate,public" }%
%WEBLIST{ webs="public" }%
