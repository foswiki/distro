use strict;

package TOCTests;

=pod

These tests verify the proper working of the TOC.

The only tests currently covered concern that URL parameters are correctly
propagated into the TOC.

=cut


use base qw(FoswikiTestCase);

use strict;
use Foswiki;
use Foswiki::UI::Edit;
use Foswiki::Form;
use Unit::Request;
use Unit::Response;
use Error qw( :try );

my $testweb = "TestWeb";
my $testtopic1 = "TestTopic1";

my $twiki;
my $user;
my $testuser1 = "TestUser1";

my $setup_failure = '';

my $aurl; # Holds the %ATTACHURL%
my $surl;# Holds the %SCRIPTURL%

my $testtext1 = <<'HERE';
%TOC%

---+ A level 1 headline with %URLPARAMS{"param1"}%

---++ Followed by a level 2 headline with %URLPARAMS{"param2"}%

---++ Another level 2 headline

---+++ Now a level 3 headline

With a few words of text.

---++ And back to level 2

HERE

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    
    my $query = new Unit::Request();
    $twiki = new Foswiki( undef, $query );
    $this->{request}  = $query;
    $this->{response} = new Unit::Response;
    $user = $twiki->{user};

    $surl = $twiki->getScriptUrl(1);

    $twiki->{store}->createWeb($user, $testweb);


    $Foswiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($twiki, $testweb);
    eval {$twiki->finish()};
    $this->SUPER::tear_down();
}

sub setup_TOCtests {
  my ( $this, $text, $web, $topic, $params, $tocparams ) = @_;

  $twiki->{webName} = $web;
  $twiki->{topicName} = $topic;
  my $render = $twiki->renderer;

  use Foswiki::Attrs;
  my $attr = new Foswiki::Attrs( $params );
  foreach my $k ( keys %$attr ) {
    next if $k eq '_RAW';
    $this->{request}->param( -name=>$k, -value=>$attr->{$k});
  }

  # Now generate the TOC
  my $res = $twiki->_TOC( $text, $topic, $web, $tocparams );

  eval 'use HTML::TreeBuilder; use HTML::Element;';
  if( $@ ) {
      my $current_failure = $@;
      $current_failure =~ s/\(eval \d+\)//g; # remove number for comparison
      if ($current_failure  eq  $setup_failure) {
          # we've seen the same error before.  Probably one of the CPAN
          # prerequisites is missing.
          $this->assert(0,"Unable to set up test:  Same problem as above.");
      }
      else {
          $setup_failure  =  $current_failure;
          $this->assert(0,"Unable to set up test: '$@'");
      }
      return;
  }

  my $tree = HTML::TreeBuilder->new_from_content($res);

  # ----- now analyze the resultant $tree

  my @children = $tree->content_list();
  return ($children[1]->content_list())[0]->content_list();

}

sub test_parameters {
  my $this = shift;
  
  my @children = setup_TOCtests( $this, $testtext1, $testtopic1, $testweb, 'param1="a little luck" param2="no luck"', '' );
  # @children will have alternating ' * ' and an href
  foreach my $c ( @children ) {
    next if ($c eq " * ");
    my $res = $c->{href};
    $res =~ s/#.*$//o;  # Delete anchor
    $this->assert_matches(qr/\?[\w;&=%]+$/, $res);
    $this->assert_matches(qr/param2=no%20luck/, $res);
    $this->assert_matches(qr/param1=a%20little%20luck/, $res);
  }
}

sub test_no_parameters {
  my $this = shift;
  
  my @children = setup_TOCtests( $this, $testtext1, $testtopic1, $testweb, '', '' );
  # @children will have alternating ' * ' and an href
  foreach my $c ( @children ) {
    next if ($c eq " * ");
    my $res = $c->{href};
    $res =~ s/#.*$//o;  # Delete anchor
    $this->assert_str_equals('', $res);
  }
}


1;
