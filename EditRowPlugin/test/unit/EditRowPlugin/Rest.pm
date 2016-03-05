# See bottom of file for license and copyright information
package Rest;
use v5.14;

use Moo;
extends qw(FoswikiFnTestCase);

sub gettit {
    my ( $this, $t, $r, $c ) = @_;
    $this->clear_session;
    my %qd = (
        erp_version => "VERSION",
        erp_topic   => $this->test_web . "." . $this->test_topic,
        erp_table   => "TABLE_$t"
    );
    $qd{erp_row} = $r if defined $r;
    $qd{erp_col} = $c if defined $c;
    my $query = Unit::Request->new( initializer => \%qd );
    $this->session(
        Foswiki->new( user => $this->test_user_login, request => $query ) );
    my $response = Foswiki::Response->new();
    $this->assert_null(
        Foswiki::Plugins::EditRowPlugin::Get::process(
            $this->session, "EditRowPlugin", "get", $response
        )
    );
    return $response->body();
}

sub test_rest_get {
    my $this = shift;
    require Foswiki::Plugins::EditRowPlugin::Get;
    $this->assert( !$@, $@ );

    $this->clear_test_topicObject;
    $this->test_topicObject(
        ( Foswiki::Func::readTopic( $this->test_web, $this->test_topic ) )[0] );
    $this->test_topicObject->text(<<INPUT);
| 1 |

| A | B |
| C | D |
INPUT
    $this->test_topicObject->save();
    $this->clear_test_topicObject;
    $this->clear_session;

    $this->assert_equals( '"1"', $this->gettit( 0, 0, 0 ) );

    $this->assert_equals( '"A"', $this->gettit( 1, 0, 0 ) );
    $this->assert_equals( '"B"', $this->gettit( 1, 0, 1 ) );
    $this->assert_equals( '"C"', $this->gettit( 1, 1, 0 ) );
    $this->assert_equals( '"D"', $this->gettit( 1, 1, 1 ) );
    $this->assert_equals( '["A","B"]', $this->gettit( 1, 0 ) );
    $this->assert_equals( '["C","D"]', $this->gettit( 1, 1 ) );
    $this->assert_equals( '["A","C"]', $this->gettit( 1, undef, 0 ) );
    $this->assert_equals( '["B","D"]', $this->gettit( 1, undef, 1 ) );
    $this->assert_equals( '[["A","B"],["C","D"]]', $this->gettit(1) );

    #$this->assert_equals( '"C"', $this->gettit( 1, -1, 0 ) );
    #$this->assert_equals( '"D"', $this->gettit( 1, -1, -1 ) );
}

sub test_rest_save {
    my $this = shift;
    require Foswiki::Plugins::EditRowPlugin::Save;
    $this->assert( !$@, $@ );
    $this->clear_test_topicObject;
    $this->test_topicObject(
        ( Foswiki::Func::readTopic( $this->test_web, $this->test_topic ) )[0] );
    $this->test_topicObject->text(<<INPUT);
| 1 |

| A | B |
| C | D |
INPUT
    $this->test_topicObject->save();
    $this->clear_test_topicObject;
    $this->clear_session;

    my %qd = (
        CELLDATA    => "Spitoon",
        erp_action  => "saveCellCmd",
        erp_col     => 0,
        erp_row     => 0,
        erp_version => "VERSION",
        erp_topic   => $this->test_web . "." . $this->test_topic,
        erp_table   => "TABLE_1",
        noredirect  => 1,                                           # for AJAX
    );
    my $query = Unit::Request->new( initializer => \%qd );
    $this->session(
        Foswiki->new( user => $this->test_user_login, request => $query ) );
    my $response = Foswiki::Response->new();
    $this->assert_null(
        Foswiki::Plugins::EditRowPlugin::Save::process(
            $this->session, "EditRowPlugin", "save", $response
        )
    );
    $this->assert_equals( "RESPONSESpitoon", $response->body() );
    $this->clear_test_topicObject;
    $this->test_topicObject(
        ( Foswiki::Func::readTopic( $this->test_web, $this->test_topic ) )[0] );
    my $expected = <<EXPECTED;
| 1 |

| Spitoon | B |
| C | D |
EXPECTED
    $this->assert_equals( $expected, $this->test_topicObject->text() );
}

1;
