package Unit::ExternalEngine;

use strict;
use warnings;
use base qw(Unit::TestCase);

use Foswiki;
use Storable qw(freeze thaw);

my $CRLF = "\015\012";

# *************************************************************************** #
# This class is used to do live Foswiki engines tests. UnitTestContrib must be
# installed, the web server should be configured with the engine to be tested
# and lib/LocalSite.cfg must contain:
#
# $Foswiki::cfg{SwitchBoard}{test} = [ 'Foswiki::UI::Test', 'test', {} ];
#
# Adjust FOSWIKI_SERVER, FOSWIKI_PORT and FOSWIKI_PATH environment variables:
#
#     FOSWIKI_SERVER is the address of the server to test. MUST be set.
#     FOSWIKI_PORT   is the port to use. 80 is used as default.
#     FOSWIKI_PATH   is the {ScriptUrlPath} to access Foswiki. '/bin' is used
#                    as default
# *************************************************************************** #

sub list_tests {
    my $this = shift;
    eval 'use LWP; use HTTP::Message; use HTTP::Request; use HTTP::Headers; 1;';
    if ($@) {
        print STDERR 'Install libwww-perl in order to run EngineTests', "\n";
        return ();
    }
    return $this->SUPER::list_tests(@_);
}

sub _req2http {
    my $req = shift;

    my $http = new HTTP::Request( $req->method );
    my $uri =
      $ENV{FOSWIKI_PORT} && $ENV{FOSWIKI_PORT} == 443 ? 'https://' : 'http://';
    $uri .= $ENV{FOSWIKI_SERVER};
    $uri .= ':' . $ENV{FOSWIKI_PORT}
      if $ENV{FOSWIKI_PORT} && $ENV{FOSWIKI_PORT} !~ /^(?:80|443)$/;
    $uri .= $ENV{FOSWIKI_PATH} || '/bin';
    $uri .= '/test';
    $uri .= $req->path_info();
    if ( $req->method eq 'POST' ) {
        use bytes;
        if ( keys %{ $req->{uploads} } ) {
            my @chars = ( 0 .. 9, 'a' .. 'z', 'A' .. 'Z' );
            my $boundary = '-' x 18;
            for ( my $i = 0 ; $i < 25 ; $i++ ) {
                $boundary .= $chars[ int( rand( scalar @chars ) ) ];
            }
            $http->content_type("multipart/form-data; boundary=$boundary");
            $boundary = '--' . $boundary;
            foreach my $p ( $req->param ) {
                foreach my $v ( $req->param($p) ) {
                    $http->add_content( $boundary . $CRLF );
                    $http->add_content(
                        qq{Content-Disposition: form-data; name="$p"});
                    if ( my $fh = $req->upload($p) ) {
                        $http->add_content(qq(; filename="$v"));
                        $http->add_content( $CRLF 
                              . $_ . ': '
                              . $req->{uploads}{$v}{headers}{$_} )
                          foreach keys %{ $req->{uploads}{$v}->{headers} };
                        local $/ = undef;
                        $v = <$fh>;
                    }
                    $http->add_content( $CRLF . $CRLF . $v . $CRLF );
                }
            }
            $http->add_content( $boundary . "--" . $CRLF );
        }
        else {
            $http->content( $req->query_string );
            $http->content_type('application/x-www-form-urlencoded');
        }
    }
    else {
        $uri .= '?' . $req->query_string;
    }
    $http->uri($uri);
    foreach my $h ( $req->header ) {
        next if $h =~ /^(?:Cookie|Content-Length|User-Agent)$/i;
        my @v = $req->header($h);
        $http->header( $h => \@v );
    }
    $http->header(
        'Cookie' => join(
            '; ',
            map {
                    Foswiki::urlEncode($_) . '='
                  . Foswiki::urlEncode( $req->cookies->{$_}->value )
              } keys %{ $req->cookies }
        )
    ) if scalar %{ $req->cookies };
    $http->header(
        'User-Agent' => ( $req->userAgent || $req->header('User-Agent') ) );
    $http->protocol('HTTP/1.1');
    return $http;
}

sub make_request {
    my ( $this, $req ) = @_;

    my $http = _req2http($req);
    my $ua = new LWP::UserAgent( timeout => 5, agent => '' );
    my $response = $ua->request($http);
    die 'Error performing request: ' . $response->message . "\n"
      unless $response->is_success;
    return $response;
}

sub make_bare_request {
    my ( $this, $http ) = @_;

    my $ua = new LWP::UserAgent( timeout => 5, agent => '' );
    my $response = $ua->request($http);
    die 'Error performing request: ' . $response->message . "\n"
      unless $response->is_success;
    return $response;
}

1;
