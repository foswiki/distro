package Unit::Response;
use base 'Foswiki::Response';
use strict;

use vars qw($res);

BEGIN {
    use Foswiki;
    use CGI;
    no warnings qw(redefine);
    my $_new = \&Foswiki::new;
    *Foswiki::new =
      sub { my $t = $_new->(@_); $res = $t->{response}; return $t };
    my $_finish = \&Foswiki::finish;
    *Foswiki::finish = sub { $_finish->(@_); $res = undef; };
}

sub new {
    die "You must call Unit::Response::new() *after* Foswiki::new()\n"
      unless defined $res;
    bless $res, __PACKAGE__ unless $res->isa(__PACKAGE__);
    return $res;
}

sub DESTROY {
    my $this = shift;
    $res = undef;
    bless $this, $Unit::Response::ISA[0];
}

1;
