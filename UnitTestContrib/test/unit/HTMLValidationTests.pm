use strict;

package HTMLValidationTests;

#this has been quickly copied from the UICompilation tests
#TODO: need to pick a list of topics, actions, opps's and add detection of installed skins

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );
use HTML::Tidy;

our $UI_FN;

sub new {
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $self = shift()->SUPER::new( "UIFnCompile", @_ );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

	$this->{tidy} = HTML::Tidy->new({
								#turn off warnings until we have fixed errors
								'show-warnings' => 1,
								'accessibility-check'	=> 0,
								'drop-empty-paras'	=> 0
									});
	print STDERR "HTML::Tidy Version: ".$HTML::Tidy::VERSION."\n";
	#print STDERR "libtidy Version: ".HTML::Tidy::libtidy_version()."\n";
    
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
    my ($status, $header, $text);
    try {
		($text) = $this->captureWithKey( switchboard =>
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
		$text = $e->stringify();
	} catch Foswiki::EngineException with {
		my $e = shift;
		$text = $e->stringify();
	};
    $fatwilly->finish();

    # Remove CGI header
    my $CRLF = "\015\012";    # "\r\n" is not portable
    $text =~ s/^(.*?)$CRLF$CRLF//s;
    $header = $1;      # untaint is OK, it's a test

    return ($status, $header, $text);
}

#TODO: work out why some 'Use of uninitialised vars' don't crash the test (see preview)
#this verifies that the code called by default 'runs' with ASSERTs on
#which would have been enough to pick up Item2342
#and that the switchboard still works.
sub verify_switchboard_function {
    my $this = shift;
    
    my ($status, $header, $text) = $this->call_UI_FN($this->{test_web}, 'WebHome');
#    $this->assert_equals(200, $status);
#    $this->assert_equals('', $header);
#    $this->assert_equals('', $text);

	#$this->assert($this->{tidy}->parse('something', $text));
	$this->assert_null($this->{tidy}->messages());
	my $output = join("\n", $this->{tidy}->messages());
	$this->assert_equals('', $output);
	$this->{tidy}->clear_messages();
}

#TODO: craft specific tests for each script
#TODO: including timing expectations... (imo statistics takes a long time in this test)


1;
