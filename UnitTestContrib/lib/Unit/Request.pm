package Unit::Request;
use strict;

BEGIN {
    use Foswiki;
    use CGI;
    my ($release) = $Foswiki::RELEASE =~ /-(\d+)\.\d+\.\d+/;
    if ( $release >= 2 ) {
        require Foswiki::Request;
        import Foswiki::Request;
        @Unit::Request::ISA = 'Foswiki::Request';
    }
    else {
        @Unit::Request::ISA = 'CGI';
    }
}


1;
