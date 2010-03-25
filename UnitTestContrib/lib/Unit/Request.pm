package Unit::Request;
use Foswiki::Request;
our @ISA = qw( Foswiki::Request );

sub setUrl {
    my ( $this, $queryString ) = @_;

    #print STDERR "---- setUrl($queryString)\n";

    my $path      = $queryString;
    my $urlParams = '';
    if ( $queryString =~ /(.*)\?(.*)/ ) {
        $path      = $1;
        $urlParams = $2;
    }

    my @pairs = split /[&;]/, $urlParams;
    my ( $param, $value, %params, @plist );
    foreach (@pairs) {
        ( $param, $value ) =
          map { tr/+/ /; s/%([0-9a-fA-F]{2})/chr(hex($1))/oge; $_ }
          split '=', $_, 2;
        push @{ $params{$param} }, $value;
        push @plist, $param;
    }
    foreach my $param (@plist) {
        $this->queryParam( $param, $params{$param} );

        #print STDERR "\t setting $param, ".join(',', @{$params{$param}})."\n";
    }
    $this->path_info( Foswiki::Sandbox::untaintUnchecked($path) );

    #print STDERR "pathinfo = $path\n";
}

1;
