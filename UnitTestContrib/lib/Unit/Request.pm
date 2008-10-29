package Unit::Request;
use strict;

BEGIN {
    use TWiki;
    use CGI;
    my ($release) = $TWiki::RELEASE =~ /-(\d+)\.\d+\.\d+/;
    if ( $release >= 5 ) {
        require TWiki::Request;
        import TWiki::Request;
        @Unit::Request::ISA = 'TWiki::Request';
    }
    else {
        @Unit::Request::ISA = 'CGI';
    }
}


1;
