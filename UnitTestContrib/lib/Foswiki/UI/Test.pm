package Foswiki::UI::Test;

use strict;

#use Storable qw(thaw freeze); # unreliable

sub freeze {
    return Data::Dumper->Dump( [ $_[0] ] );
}

sub thaw {
    my $VAR1;
    eval $_[0] or die $@;
    return $VAR1;
}

sub test {
    my $session = shift;
    if ( my $desired = $session->{request}->param('desired_test_response') ) {
        %{ $session->{response} } = %{ thaw($desired) };
    }
    else {
        $session->{response}->header( -type => 'application/octet-stream' );
        my %response = ( request => $session->{request} );
        foreach ( keys %{ $session->{request}{uploads} } ) {
            my $fh = $session->{request}{uploads}{$_}->handle;
            local $/ = undef;
            $response{$_} = <$fh>;
        }
        if ( $session->{request}->method eq 'HEAD' ) {
            $session->{response}->pushHeader( 'X-Result' =>
                  Foswiki::urlEncode( freeze( $session->{request} ) ) );
        }
        $session->{response}->print( freeze( \%response ) );
    }
}

1;
