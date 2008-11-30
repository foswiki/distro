package Foswiki::UI::Test;

use strict;
use Storable qw(thaw freeze);

sub test {
    my $session = shift;
    if ( my $desired = $session->{request}->param('desired_test_response') ) {
        %{ $session->{response} } = %{ thaw($desired) };
    }
    else {
        $session->{response}->header(
            -type    => 'text/plain',
            -charset => 'utf8',
        );
        $session->{response}->print( freeze( $session->{request} ) );
    }
}

1;
