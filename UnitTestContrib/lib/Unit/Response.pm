package Unit::Response;
use strict;

use vars qw($res);

BEGIN {
    use Foswiki;
    use CGI;
    my ($release) = $Foswiki::RELEASE =~ /-(\d+)\.\d+\.\d+/;
    no warnings qw(redefine);
    if ( $release >= 2 ) {
        require Foswiki::Response;
        import Foswiki::Response;
        @Unit::Response::ISA = qw(Foswiki::Response);
        my $twiki_new = \&Foswiki::new;
        *Foswiki::new =
          sub { my $t = $twiki_new->(@_); $res = $t->{response}; return $t };
    }
    else {
        @Unit::Response::ISA = qw(CGI);
        *charset = sub { shift; CGI::charset(@_) };
        my $twiki_new = \&Foswiki::new;
        *Foswiki::new =
          sub { my $t = $twiki_new->(@_); $res = $t->{cgiQuery}; return $t };
    }
    my $twiki_finish = \&Foswiki::finish;
    *Foswiki::finish = sub { $twiki_finish->(@_); $res = undef; };
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
