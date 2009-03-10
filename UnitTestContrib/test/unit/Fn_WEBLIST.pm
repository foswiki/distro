# tests for the correct expansion of WEBLIST

package Fn_WEBLIST;
use base qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'WEBLIST', @_ );
    return $self;
}

my @allWebs;
my @rootWebs;
my @templateWebs;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $webObject =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}/Subweb" );
    $webObject->populateNewWeb();
    Foswiki::Func::readTemplate('foswiki');
    @allWebs      = Foswiki::Func::getListOfWebs('user,public');
    @rootWebs     = grep { !/\// } @allWebs;
    @templateWebs = Foswiki::Func::getListOfWebs('template');
}

sub test_separator {
    my $this = shift;

    # separator=", " 	Line separator Default: "$n" (new line)
    my $text = $this->{test_topicObject}->expandMacros('%WEBLIST%');
    $this->assert_str_equals( join( "\n", @rootWebs ), $text );
    $text = $this->{test_topicObject}->expandMacros('%WEBLIST{separator=";"}%');
    $this->assert_str_equals( join( ';', @rootWebs ), $text );
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
    $this->assert_str_equals(
        join( "\n", map { "$_:\"$_\":sponge" } @rootWebs ), $text );
    $text =
      $this->{test_topicObject}->expandMacros('%WEBLIST{"$name:$qname:$web"}%');
    $this->assert_str_equals( join( "\n", map { "$_:\"$_\":" } @rootWebs ),
        $text );

    # format="format" 	(Alternative to above) Default: "$name"
    $text =
      $this->{test_topicObject}
      ->expandMacros('%WEBLIST{format="$name:$qname:$web" web="sponge"}%');
    $this->assert_str_equals(
        join( "\n", map { "$_:\"$_\":sponge" } @rootWebs ), $text );
}

sub test_subwebs {
    my $this = shift;

    # subwebs="Sandbox" show sub-webs of this web (recursively) Default: ""
    my $text =
      $this->{test_topicObject}
      ->expandMacros( '%WEBLIST{subwebs="' . $this->{test_web} . '"}%' );
    $this->assert_str_equals( "$this->{test_web}/Subweb", $text );
    $text =
      $this->{test_topicObject}->expandMacros('%TMPL:P{"webListIndent"}%');
}

sub test_indentedname {
    my $this = shift;

    #          $indentedname (the name of the web with parent web names
    #          replaced by indents, for use in indented lists)
    my $text =
      $this->{test_topicObject}->expandMacros(
        '%WEBLIST{"$indentedname" subwebs="' . $this->{test_web} . '"}%' );
    $this->assert_str_equals( "<span class='foswikiWebIndent'></span>Subweb",
        $text );
}

sub test_marker {
    my $this = shift;

    # marker="selected" Text for $marker if the item matches selection
    #                   Default: "selected"
    # selection="%WEB%" Current value to be selected in list Default: "%WEB%"
    my $text =
      $this->{test_topicObject}->expandMacros(
        '%WEBLIST{selection="' . $allWebs[1] . '" format="$name$marker"}%' );
    my @munged = @rootWebs;
    $munged[1] = "$munged[1]selected=\"selected\"";
    $this->assert_str_equals( join( "\n", @munged ), $text );
    $text =
      $this->{test_topicObject}->expandMacros( '%WEBLIST{selection="'
          . $allWebs[1]
          . '" marker="sponge" format="$name$marker"}%' );
    @munged = @rootWebs;
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
    $this->assert_str_equals( join( "\n", @rootWebs ), $text );
    $text =
      $this->{test_topicObject}->expandMacros('%WEBLIST{webs="webtemplate"}%');
    $this->assert_str_equals( join( "\n", @templateWebs ), $text );
}

1;
