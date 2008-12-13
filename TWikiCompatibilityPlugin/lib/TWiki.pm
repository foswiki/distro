#package TWiki;

use Foswiki;

sub TWiki::new {
    shift;
    my $fatwilly = new Foswiki(@_);
    require TWiki::Sandbox;
    $fatwilly->{sandbox} = new TWiki::Sandbox();
    return $fatwilly;
}

%TWiki::regex = %Foswiki::regex;

1;
