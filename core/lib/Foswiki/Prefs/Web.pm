package Foswiki::Prefs::Web;
use strict;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my ($stack, $level) = @_;
    my $this  = {
        stack => $stack,
        level => $level,
    };
    return bless $this, $class;
}

sub finish {
    my $this = shift;
    $this->{stack}->finish();
    undef $this->{stack};
    undef $this->{level};
}

sub cloneStack {
    my ($this, $level) = @_;
    return $this->{stack}->clone($level);
}

sub get {
    my ($this, $key) = @_;
    $this->{stack}->getPreference( $key, $this->{level} );
}

1;
