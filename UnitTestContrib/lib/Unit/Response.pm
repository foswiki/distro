package Unit::Response;
use Foswiki::Response;
our @ISA = qw( Foswiki::Response );
use strict;

our $response;    # for proper finalization

BEGIN {
    use Foswiki;
    use CGI;
    my $_new = \&Foswiki::new;
    no warnings 'redefine';
    *Foswiki::new = sub {
        my $t = $_new->(@_);
        $response = $t->{response};
        return $t;
    };
    my $_finish = \&Foswiki::finish;
    *Foswiki::finish = sub {
        $_finish->(@_);
        undef $response;
    };
    use warnings 'redefine';
}

sub new {
    die "You must call Unit::Response::new() *after* Foswiki::new()\n"
      unless defined $response;
    bless( $response, __PACKAGE__ ) unless $response->isa(__PACKAGE__);
    return $response;
}

sub DESTROY {
    my $this = shift;
    undef $response;
    bless( $this, $Unit::Response::ISA[0] );
}

1;
