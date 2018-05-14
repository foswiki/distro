package SecurityTests;

#use Foswiki::UI::Attach();

use Foswiki::Class;
extends qw(FoswikiFnTestCase);
our @ISA = qw( FoswikiFnTestCase );

# use strict;

sub create_session {
    my $this    = shift;
    my $reqOpts = shift;

    # Create a Foswiki app
    $this->createNewFoswikiApp(
        requestParams => { initializer => $reqOpts, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/" . $this->test_topic,
                action    => "attach",
                user      => $this->test_user_login,
            },
        }
    );
}

sub test_setup {

    # if this test fails, there may be something wrong with the design of
    # other tests testing real issues.

    my $this = shift;

    $this->create_session( { filename => ["goober"] } );
    my $query = $this->app->request;

    $this->assert_str_equals( "attach",          $query->action );
    $this->assert_str_equals( "filename=goober", $query->queryString );
    $this->assert_str_equals( "goober", scalar( $query->param('filename') ) );

    # print $query->url(-query => 1), "\n";

    my ( $respText, $result, $stdout, $stderr ) =
      $this->captureWithKey( attach => sub { $this->app->handleRequest }, );

    # print $respText, "\n";

    $this->assert_matches( qr/<input [^>]* value="goober"/, $respText );

}

sub test_attach_filename_xss {

    my $this = shift;

    # send filename="><sCrIpT>alert(66562)</sCrIpT>
    $this->create_session(
        { filename => ['"><sCrIpT>alert(66562)</sCrIpT>'] } );
    my $query = $this->app->request;

    # print $query->url(-query => 1), "\n";

    my ( $respText, $result, $stdout, $stderr ) =
      $this->captureWithKey( attach => sub { $this->app->handleRequest; } );

    # print $respText, "\n";

    # our filename got it in in some form...
    $this->assert_matches( qr/sCrIpT/, $respText,
        "Expected to see harmless trace of filename (sCrIpT)" );

    # ...but must not allow pop-up alert
    $this->assert_does_not_match( qr/<sCrIpT>alert\(66562\)<\/sCrIpT>/,
        $respText,
        "Detected Javascript injection: <sCrIpT>alert\(66562\)<\/sCrIpT>" );

}

1;
