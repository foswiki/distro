package Unit::Response;
use strict;

use vars qw($res);

BEGIN {
    use TWiki;
    use CGI;
    my ($release) = $TWiki::RELEASE =~ /-(\d+)\.\d+\.\d+/;
    no warnings qw(redefine);
    if ( $release >= 5 ) {
        require TWiki::Response;
        import TWiki::Response;
        @Unit::Response::ISA = qw(TWiki::Response);
        my $twiki_new = \&TWiki::new;
        *TWiki::new =
          sub { my $t = $twiki_new->(@_); $res = $t->{response}; return $t };
    }
    else {
        @Unit::Response::ISA = qw(CGI);
        *charset = sub { shift; CGI::charset(@_) };
        my $twiki_new = \&TWiki::new;
        *TWiki::new =
          sub { my $t = $twiki_new->(@_); $res = $t->{cgiQuery}; return $t };
    }
    my $twiki_finish = \&TWiki::finish;
    *TWiki::finish = sub { $twiki_finish->(@_); $res = undef; };
}

sub new {
    die "You must call Unit::Response::new() *after* TWiki::new()\n"
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
