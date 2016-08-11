package UIFnCompileTests;
use v5.14;

use Foswiki           ();
use Foswiki::UI::View ();
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

our %expected_status_main_webhome = (
    search       => 302,
    save         => 302,
    login        => 200,
    logon        => 200,
    attach       => 200,
    preview      => 200,
    rdiff        => 200,
    rest         => 404,
    restauth     => 404,
    changes      => 200,
    edit         => 200,
    compare      => 200,
    rdiffauth    => 200,
    statistics   => 200,
    compareauth  => 200,
    oops         => 200,
    previewauth  => 200,
    changes      => 200,
    rename       => 200,
    upload       => 400,
    resetpasswd  => 400,
    register     => 501,
    view         => 200,
    viewfile     => 404,
    viewfileauth => 404,
    viewauth     => 200,
    manage       => 400,
);

# TODO: this is beause we're calling the UI::function, not UI:Execute - need to
# re-write it to use the full engine
our %expect_non_html = (
    rest         => 1,
    restauth     => 1,
    viewfile     => 1,
    viewfileauth => 1,
    register     => 1,    # TODO: missing action make it throw an exception
    manage       => 1,    # TODO: missing action make it throw an exception
    upload       => 1,    # TODO: zero size upload
    resetpasswd  => 1,
    statistics   => 1,
);

has test_action => ( is => 'rw', );

around BUILDARGS => sub {
    my $orig = shift;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    $Foswiki::cfg{Stats}{AutoCreateTopic} = 0;
    return $orig->( @_, testSuite => 'UIFnCompile' );
};

sub fixture_groups {
    my $this = shift;
    my @groups;

    foreach my $script ( keys( %{ $Foswiki::cfg{SwitchBoard} } ) ) {

        # jsonrpc and configure are registered, but do things differently
        next if $script =~ m/^(jsonrpc|configure).*/;

        push( @groups, $script );
        next if ( defined( &{$script} ) );

        #print STDERR "defining $script\n";
        my $dispatcher = $Foswiki::cfg{SwitchBoard}{$script};

        if ( ref($dispatcher) eq 'ARRAY' ) {

            # Old-style array entry in switchboard from a plugin
            my @array = @{$dispatcher};
            $dispatcher = {
                package  => $array[0],
                function => $array[1],
                context  => $array[2],
            };
        }

        next unless ( ref($dispatcher) eq 'HASH' );    #bad switchboard entry.

        my $package = $dispatcher->{package} || 'Foswiki::UI';
        my $request = $dispatcher->{request} || 'Foswiki::Request';
        eval "require $package; 1;" or next;
        my $function = $dispatcher->{function} // $dispatcher->{method};
        my $sub = $package->can($function);

        no strict 'refs';
        *{$script} = sub {
            $this->test_action($script);
        };
        use strict 'refs';
    }

    return \@groups;
}

around createNewFoswikiApp => sub {
    my $orig = shift;
    my $this = shift;

    my $app = $orig->( $this, @_ );

    $app->cfg->data->{Plugins}{HomePagePlugin}{Enabled} = 0;

    return $app;
};

# Foswiki::App handleRequestException callback function.
sub _cbHRE {
    my $obj  = shift;
    my %args = @_;
    $args{params}{exception}->rethrow;
}

sub call_UI_FN {
    my ( $this, $web, $topic, $tmpl ) = @_;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                webName   => [$web],
                topicName => [$topic],

                #            template  => [$tmpl],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/$web/$topic",
                method    => 'POST',
                user      => $this->test_user_login,
                action    => $this->test_action,
            },
        },

        #callbacks => { handleRequestException => \&_cbHRE },
    );
    my ( $responseText, $result, $stdout, $stderr );
    $responseText = "Status: 500";    #errr, boom
    try {
        ( $responseText, $result, $stdout, $stderr ) = $this->captureWithKey(
            switchboard => sub {
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        if (
            ref($e)
            && (   $e->isa('Foswiki::OopsException')
                || $e->isa('Foswiki::EngineException') )
          )
        {
            $responseText = $e->stringify();
        }
        else {
            Foswiki::Exception::Fatal->rethrow($e);
        }
    };

    $this->assert($responseText);

    # Remove CGI header
    my $CRLF = "\015\012";    # "\r\n" is not portable
    my ( $header, $body );
    if ( $responseText =~ m/^(.*?)$CRLF$CRLF(.*)$/s ) {
        $header = $1;         # untaint is OK, it's a test
        $body   = $2;
    }
    else {
        $header = '';
        $body   = $responseText;
    }

    my $status = 666;
    if ( $header =~ m/^Status: (\d*).*/ms ) {
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
      $this->call_UI_FN( $this->test_web, $this->test_topic );

    # it turns out (see Foswiki:Tasks.Item9184) that hardcoding 200 status
    # prevents the use of BasicAuth - and we really should avoid preventing an
    # admin from setting the security policy where possible. 666 is a default
    # used in the UI_FN code above for 'unset'
    my $expectStatus = $expected_status_main_webhome{ $this->test_action }
      || 666;
    $this->assert_num_equals( $expectStatus, $status,
            "GOT Status : $status (EXPECTED: $expectStatus)\n"
          . "HEADER: $header\n\n<<<<<STDERR: "
          . ( $stderr || '' )
          . ">>>>>>STDERR\n" );
    if ( !defined( $expect_non_html{ $this->test_action } ) ) {
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
    local $ENV{FOSWIKI_ASSERTS} = 0;

    my ( $status, $header, $result, $stdout, $stderr ) =
      $this->call_UI_FN( 'Nosuchweb', $this->test_topic );

    # TODO: I was expecting pretty much all scripts to return 302 redirect to
    # oopsmissing. Shame we're still using 302 - when we're supposed to use
    # 303/307 (http 1.1)
    # TODO: save - no idea why it's returning OK-nostatus - especially as
    # NoSuchTopic works. It ought to return a 302
    our %expected_status = (
        attach       => 404,
        changes      => 404,
        compare      => 404,
        compareauth  => 404,
        edit         => 404,
        login        => 200,
        logon        => 200,
        manage       => 400,
        oops         => 200,
        preview      => 404,
        previewauth  => 404,
        rdiff        => 404,
        rdiffauth    => 404,
        register     => 501,
        rename       => 404,
        resetpasswd  => 400,
        rest         => 404,
        save         => 404,
        search       => 302,
        upload       => 404,
        view         => 404,
        viewauth     => 404,
        viewfile     => 404,
        viewfileauth => 404,
        statistics   => 200,
        restauth     => 404,
    );
    my $expectStatus = $expected_status{ $this->test_action } || 666;
    $this->assert_num_equals( $expectStatus, $status,
            "GOT Status : $status (EXPECTED: $expectStatus)\n"
          . "HEADER: $header\n\n<<<<<STDERR: "
          . ( $stderr || '' )
          . ">>>>>STDERR\n" );

    return;
}

sub verify_switchboard_function_nonExistantTopic {
    my $this = shift;

    #turn off ASSERTs so we can see what a normal run time will show
    local $ENV{FOSWIKI_ASSERTS} = 0;

    my ( $status, $header, $result, $stdout, $stderr ) =
      $this->call_UI_FN( $this->test_web, 'NoSuchTopicBySven' );

    our %expected_status = (
        attach       => 404,
        changes      => 200,
        compare      => 404,
        compareauth  => 404,
        edit         => 200,
        login        => 200,
        logon        => 200,
        manage       => 400,
        oops         => 200,
        preview      => 200,
        previewauth  => 200,
        rdiff        => 404,
        rdiffauth    => 404,
        register     => 501,
        rename       => 403,
        resetpasswd  => 400,
        rest         => 404,
        save         => 302,
        search       => 302,
        upload       => 404,
        view         => 404,
        viewauth     => 404,
        viewfile     => 404,
        viewfileauth => 404,
        statistics   => 200,
        restauth     => 404,
    );
    my $expectStatus = $expected_status{ $this->test_action } || 666;
    $this->assert_num_equals( $expectStatus, $status,
            "GOT Status : $status (EXPECTED: $expectStatus)\n"
          . "HEADER: $header\n\n<<<<<STDERR: "
          . ( $stderr || '' )
          . ">>>>>STDERR\n" );

    return;
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
