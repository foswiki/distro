use strict;

package UIFnCompileTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );

our $UI_FN;
our $SCRIPT_NAME;
our %expected_status = (
        search  => 302,
        save  => 302,
);
#TODO: this is beause we're calling the UI::function, not UI:Execute - need to re-write it to use the full engine
our %expect_non_html = (
        rest  => 1,
        viewfile => 1,
        register => 1,       #TODO: missing action make it throw an exception
        manage => 1,       #TODO: missing action make it throw an exception
        upload => 1,         #TODO: zero size upload   
        resetpasswd => 1,
        statistics => 1,
);


sub new {
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $self = shift()->SUPER::new( "UIFnCompile", @_ );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
}

sub fixture_groups {
	my @groups;
	
	foreach my $script (keys (%{$Foswiki::cfg{SwitchBoard}})) {
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

    my $package = $dispatcher->{package} || 'Foswiki::UI';
    my $function = $dispatcher->{function};
    my $sub = $package .'::'. $function;
#print STDERR "call $sub\n";

        eval <<SUB;
sub $script {
    eval "require \$package" if (defined(\$package));
	\$UI_FN = \$sub;
	\$SCRIPT_NAME = \$script;
}
SUB
        die $@ if $@;
    }
	
	return \@groups;
}

sub call_UI_FN {
    my ( $this, $web, $topic, $tmpl ) = @_;
    my $query = new Unit::Request(
        {
            webName   => [$web],
            topicName => [$topic],
#            template  => [$tmpl],
        }
    );
    $query->path_info("/$web/$topic");
    $query->method('POST');
    my $fatwilly = new Foswiki( $this->{test_user_login}, $query );
    my ($responseText, $result, $stdout, $stderr);
    $responseText = "Status: 500";      #errr, boom
    try {
		($responseText, $result, $stdout, $stderr) = $this->captureWithKey( switchboard =>
		    sub {
		        no strict 'refs';
		        &${UI_FN}($fatwilly);
		        use strict 'refs';
		        $Foswiki::engine->finalize( $fatwilly->{response},
		            $fatwilly->{request} );
		    }
		);
	} catch Foswiki::OopsException with {
		my $e = shift;
		$responseText = $e->stringify();
	} catch Foswiki::EngineException with {
		my $e = shift;
		$responseText = $e->stringify();
	};
    $fatwilly->finish();

    $this->assert($responseText);

    # Remove CGI header
    my $CRLF = "\015\012";    # "\r\n" is not portable
    my ($header, $body);
    if ($responseText =~ /^(.*?)$CRLF$CRLF(.*)$/s) {
        $header = $1;      # untaint is OK, it's a test
        $body = $2;
    } else {
        $header = '';
        $body = $responseText;
    }

    my $status = 666;
    if ($header =~ /Status: (\d*)./) {
        $status = $1;
    }
    #aparently we allow the web server to add a 200 status thus risking that an error situation is marked as 200
    #$this->assert_num_not_equals(666, $status, "no response Status set in probably valid reply\nHEADER: $header\n");
    if ($status == 666) {
        $status = 200;
    }
    $this->assert_num_not_equals(500, $status, 'exception thrown');

    return ($status, $header, $body, $stdout, $stderr);
}

#TODO: work out why some 'Use of uninitialised vars' don't crash the test (see preview)
#this verifies that the code called by default 'runs' with ASSERTs on
#which would have been enough to pick up Item2342
#and that the switchboard still works.
sub verify_switchboard_function {
    my $this = shift;
    
    my ($status, $header, $result, $stdout, $stderr) =
      $this->call_UI_FN($this->{test_web}, $this->{test_topic});

    $this->assert_num_equals(
        $expected_status{$SCRIPT_NAME} || 200, $status,
        "GOT Status : $status\nHEADER: $header\n\nSTDERR: "
          .($stderr||'')."\n");
    if (!defined($expect_non_html{$SCRIPT_NAME})) {
        $this->assert_str_not_equals('', $header);
        if ($status != 302) {
            $this->assert_str_not_equals('', $result, "$status: $result");
        } else {
            #$this->assert_null($result);
        }
    }

}

#TODO: craft specific tests for each script
#TODO: including timing expectations... (imo statistics takes a long time in this test)


1;
