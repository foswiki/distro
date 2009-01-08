#package TWiki;

use Foswiki;

sub TWiki::new {
    my ( $this, $loginName, $query, $initialContext ) = @_;
    if( ! $Foswiki::Plugins::SESSION && UNIVERSAL::isa( $query, 'CGI' ) ) {
        # Compatibility: User gave a CGI object
        # This probably means we're inside a script
        $query = undef;
    }
    my $fatwilly = new Foswiki( $loginName, $query, $initialContext );
    require TWiki::Sandbox;
    $fatwilly->{sandbox} = new TWiki::Sandbox();
    return $fatwilly;
}

*TWiki::regex = \%Foswiki::regex;
*TWiki::cfg   = \%Foswiki::cfg;

1;
