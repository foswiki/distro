package SecurityTests;
use FoswikiFnTestCase();
use Foswiki::UI::Attach();
our @ISA = qw( FoswikiFnTestCase );

# use strict;

my $session;    # Foswiki instance

sub new {
    my $self = shift()->SUPER::new(@_);

    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $session = undef;
}

sub create_session {
    my $this       = shift;
    my $query_opts = shift;

    # a simple query using attach
    my $query = new Unit::Request($query_opts);
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $query->action("attach");

    # Create a Foswiki instance
    $session =
      $this->createNewFoswikiSession( $this->{test_user_login}, $query );

    return $session;
}

sub tear_down {
    my $this = shift;    # the Test::Unit::TestCase object

    if ($session) {

        # FoswikiFnTestCase does most of this
        1;
    }

    # This will automatically restore the state of $Foswiki::cfg
    $this->SUPER::tear_down();
}

sub test_setup {

    # if this test fails, there may be something wrong with the design of
    # other tests testing real issues.

    my $this = shift;

    $this->create_session( { filename => ["goober"] } );
    my $query = $this->{request};

    $this->assert_str_equals( "attach",          $query->action() );
    $this->assert_str_equals( "filename=goober", $query->queryString() );
    $this->assert_str_equals( "goober", scalar( $query->param('filename') ) );

    # print $query->url(-query => 1), "\n";

    my ( $respText, $result, $stdout, $stderr ) = $this->captureWithKey(
        attach => sub {
            no strict 'refs';
            Foswiki::UI::Attach::attach( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    # print $respText, "\n";

    $this->assert_matches( qr/<input [^>]* value="goober"/, $respText );

}

sub test_attach_filename_xss {

    my $this = shift;

    # send filename="><sCrIpT>alert(66562)</sCrIpT>
    $this->create_session(
        { filename => ['"><sCrIpT>alert(66562)</sCrIpT>'] } );
    my $query = $this->{request};

    # print $query->url(-query => 1), "\n";

    my ( $respText, $result, $stdout, $stderr ) = $this->captureWithKey(
        attach => sub {
            no strict 'refs';
            Foswiki::UI::Attach::attach( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    # print $respText, "\n";

    # our filename got it in in some form...
    $this->assert_matches( qr/sCrIpT/, $respText,
        "Expected to see harmless trace of filename (sCrIpT)" );

    # ...but must not allow pop-up alert
    $this->assert_does_not_match(
        qr/<sCrIpT>alert\(66562\)<\/sCrIpT>/,
        $respText,
        "Detected Javascript injection: <sCrIpT>alert\(66562\)<\/sCrIpT>"
    );

}

1;
