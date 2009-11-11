use strict;

package UIFnCompileTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );

our $UI_FN;

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
		($text) = $this->capture(
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
    $text =~ s/\r//g;
    $text =~ s/^(.*?)\n\n+//s;    # remove CGI header
    $header = $1;
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
}

#TODO: craft specific tests for each script
#TODO: including timing expectations... (imo statistics takes a long time in this test)


1;
