package UIFnCompileTests;
use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );

our $UI_FN;
our $SCRIPT_NAME;
our %expected_status_main_webhome = (
    search => 302,
    save   => 302,
    login  => 200,
    logon  => 200,
);

# TODO: this is beause we're calling the UI::function, not UI:Execute - need to
# re-write it to use the full engine
our %expect_non_html = (
    rest        => 1,
    restauth        => 1,
    viewfile    => 1,
    viewfileauth => 1,
    register    => 1,    # TODO: missing action make it throw an exception
    manage      => 1,    # TODO: missing action make it throw an exception
    upload      => 1,    # TODO: zero size upload
    resetpasswd => 1,
    statistics  => 1,
);

sub new {
    my ( $class, @args ) = @_;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    $Foswiki::cfg{Stats}{AutoCreateTopic} = 0;
    my $self = $class->SUPER::new( "UIFnCompile", @args );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    return;
}

sub fixture_groups {
    my @groups;

    foreach my $script ( keys( %{ $Foswiki::cfg{SwitchBoard} } ) ) {
        push( @groups, $script );
        next if ( defined(&$script) );

        #print STDERR "defining $script\n";
        my $dispatcher = $Foswiki::cfg{SwitchBoard}{$script};
        if ( ref($dispatcher) eq 'ARRAY' ) {

            # Old-style array entry in switchboard from a plugin
            my @array = @$dispatcher;
            $dispatcher = {
                package  => $array[0],
                function => $array[1],
                context  => $array[2],
            };
        }
        
        next unless (ref($dispatcher) eq 'HASH');#bad switchboard entry.

        my $package = $dispatcher->{package} || 'Foswiki::UI';
        eval "require $package" or next;
        my $function = $dispatcher->{function};
        my $sub      = $package->can($function);

        no strict 'refs';
        *$script = sub {
            $UI_FN       = $sub;
            $SCRIPT_NAME = $script;
        };
        use strict 'refs';
    }

    return \@groups;
}

sub call_UI_FN {
    my ( $this, $web, $topic, $tmpl ) = @_;
    my $query = Unit::Request->new(
        {
            webName   => [$web],
            topicName => [$topic],

            #            template  => [$tmpl],
        }
    );
    $query->path_info("/$web/$topic");
    $query->method('POST');
    my $fatwilly = Foswiki->new( $this->{test_user_login}, $query );
    my ( $responseText, $result, $stdout, $stderr );
    $responseText = "Status: 500";    #errr, boom
    try {
        ( $responseText, $result, $stdout, $stderr ) = $this->captureWithKey(
            switchboard => sub {
                no strict 'refs';
                &${UI_FN}($fatwilly);
                use strict 'refs';
                $Foswiki::engine->finalize( $fatwilly->{response},
                    $fatwilly->{request} );
            }
        );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $responseText = $e->stringify();
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $responseText = $e->stringify();
    };
    $fatwilly->finish();

    $this->assert($responseText);

    # Remove CGI header
    my $CRLF = "\015\012";    # "\r\n" is not portable
    my ( $header, $body );
    if ( $responseText =~ /^(.*?)$CRLF$CRLF(.*)$/s ) {
        $header = $1;         # untaint is OK, it's a test
        $body   = $2;
    }
    else {
        $header = '';
        $body   = $responseText;
    }

    my $status = 666;
    if ( $header =~ /Status: (\d*)./ ) {
        $status = $1;
    }

    $this->assert_num_not_equals( 500, $status, 'exception thrown' );

    return ( $status, $header, $body, $stdout, $stderr );
}

# TODO: work out why some 'Use of uninitialised vars' don't crash the test (see
# preview) this verifies that the code called by default 'runs' with ASSERTs on
# which would have been enough to pick up Item2342 and that the switchboard
# still works.
sub verify_switchboard_function {
    my $this = shift;

    my ( $status, $header, $result, $stdout, $stderr ) =
      $this->call_UI_FN( $this->{test_web}, $this->{test_topic} );

    # it turns out (see Foswiki:Tasks.Item9184) that hardcoding 200 status
    # prevents the use of BasicAuth - and we really should avoid preventing an
    # admin from setting the security policy where possible. 666 is a default
    # used in the UI_FN code above for 'unset'
    $this->assert_num_equals(
        $expected_status_main_webhome{$SCRIPT_NAME} || 666,
        $status,
        "GOT Status : $status\nHEADER: $header\n\nSTDERR: "
          . ( $stderr || '' ) . "\n"
    );
    if ( !defined( $expect_non_html{$SCRIPT_NAME} ) ) {
        $this->assert_str_not_equals( '', $header );
        if ( $status != 302 ) {
            $this->assert_str_not_equals( '', $result, "$status: $result" );
        }
        else {

            #$this->assert_null($result);
        }
    }
    return;
}

sub verify_switchboard_function_nonExistantWeb {
    my $this = shift;

    #turn off ASSERTs so we can see what a normal run time will show
    $ENV{FOSWIKI_ASSERTS} = 0;

    my ( $status, $header, $result, $stdout, $stderr ) =
      $this->call_UI_FN( 'Nosuchweb', $this->{test_topic} );

    # TODO: I was expecting pretty much all scripts to return 302 redirect to
    # oopsmissing. Shame we're still using 302 - when we're supposed to use
    # 303/307 (http 1.1)
    # TODO: save - no idea why it's returning OK-nostatus - especially as
    # NoSuchTopic works. It ought to return a 302
    our %expected_status = (

        #        compare => 302, throws but doesn't catch no_such_web exception
        search => 302,
        login  => 200,
        logon  => 200,
    );
    $this->assert_num_equals(
        $expected_status{$SCRIPT_NAME} || 666,
        $status,
        "GOT Status : $status\nHEADER: $header\n\nSTDERR: "
          . ( $stderr || '' ) . "\n"
    );
}

sub verify_switchboard_function_nonExistantTopic {
    my $this = shift;

    #turn off ASSERTs so we can see what a normal run time will show
    $ENV{FOSWIKI_ASSERTS} = 0;

    my ( $status, $header, $result, $stdout, $stderr ) =
      $this->call_UI_FN( $this->{test_web}, 'NoSuchTopicBySven' );

    our %expected_status = (

       #        compare => 302, throws but doesn't catch no_such_topic exception
        search   => 302,
        save     => 302,
        login    => 200,
        logon    => 200,
        viewauth => 404,
        view     => 404,
    );
    $this->assert_num_equals(
        $expected_status{$SCRIPT_NAME} || 666,
        $status,
        "GOT Status : $status\nHEADER: $header\n\nSTDERR: "
          . ( $stderr || '' ) . "\n"
    );
}

# TODO: add test_viewfile:
#       Failures due to non-exist are done above, but we still need:
#       Sucess
#       Failures due to permissions (guest and non-authorized user), groups...

# TODO: add verify_switchboard_function_SecuredTopic_DENiedView

# TODO: craft specific tests for each script

# TODO: including timing expectations... (imo statistics takes a long time in
#       this test)

1;
