package Unit::CGIEngine;

use Unit::TestCase;
our @ISA = qw( Unit::TestCase );
use strict;
use warnings;

BEGIN {
    $Foswiki::cfg{Engine} = 'Foswiki::Engine::CGI';
    $Foswiki::cfg{SwitchBoard}{test} = [ 'Foswiki::UI::Test', 'test', {} ];
}

use Foswiki;
use Foswiki::UI;
use Foswiki::Request;
use Storable qw(freeze thaw);
use IO::Handle ();

my $CRLF = "\015\012";

sub _req2cgi {
    my $req = shift;
    my $in  = '';
    my %env = (
        GATEWAY_INTERFACE => 'CGI/1.1',
        SCRIPT_NAME       => '/bin/test',
        SERVER_NAME       => 'EngineTests',
        SERVER_PORT       => '80',
        SERVER_PROTOCOL   => 'HTTP/1.1',
        SERVER_SOFTWARE   => 'Foswiki',
    );
    $env{REQUEST_METHOD} = $req->method();
    if ( $req->method eq 'POST' ) {
        use bytes;
        if ( keys %{ $req->{uploads} } ) {
            my @chars = ( 0 .. 9, 'a' .. 'z', 'A' .. 'Z' );
            my $boundary = '-' x 18;
            for ( my $i = 0 ; $i < 25 ; $i++ ) {
                $boundary .= $chars[ int( rand( scalar @chars ) ) ];
            }
            $env{CONTENT_TYPE} = "multipart/form-data; boundary=$boundary";
            $boundary = '--' . $boundary;
            foreach my $p ( $req->param ) {
                foreach my $v ( $req->param($p) ) {
                    $in .= $boundary . $CRLF;
                    $in .= qq{Content-Disposition: form-data; name="$p"};
                    if ( my $fh = $req->upload($p) ) {
                        $in .= qq(; filename="$v");
                        $in .=
                          $CRLF . $_ . ': ' . $req->{uploads}{$v}{headers}{$_}
                          foreach keys %{ $req->{uploads}{$v}->{headers} };
                        local $/ = undef;
                        $v = <$fh>;
                    }
                    $in .= $CRLF . $CRLF . $v . $CRLF;
                }
            }
            $in .= $boundary . "--" . $CRLF;
        }
        else {
            $in = $req->query_string;
            $env{CONTENT_TYPE} = 'application/x-www-form-urlencoded';
        }
        $env{CONTENT_LENGTH} = length($in);
    }
    else {
        $env{QUERY_STRING} = $req->query_string;
    }
    foreach my $h ( $req->header ) {
        next if $h =~ /^(?:Cookie|Content-Length|User-Agent)$/i;
        my $v = $req->header($h);
        $h =~ tr/-/_/;
        $env{ 'HTTP_' . uc($h) } = $v;
    }
    $env{HTTP_COOKIE} = join(
        '; ',
        map {
                Foswiki::urlEncode($_) . '='
              . Foswiki::urlEncode( $req->cookies->{$_}->value )
          } keys %{ $req->cookies }
    ) if scalar %{ $req->cookies };
    $env{REMOTE_ADDR} = $req->remote_addr || '127.0.0.1';
    if ( $req->remote_user ) {
        $env{REMOTE_USER} = $req->remote_user;
        $env{AUTH_TYPE}   = 'Basic';
    }
    $env{PATH_INFO} = $req->path_info if $req->path_info;
    my $ua = $req->userAgent() || $req->header('User-Agent');
    $env{'HTTP_USER_AGENT'} = $ua if defined $ua;
    return \%env, \$in;
}

sub _http2cgi {
    my $http = shift;
    my $in   = '';
    my %env  = (
        GATEWAY_INTERFACE => 'CGI/1.1',
        SCRIPT_NAME       => '/bin/test',
        SERVER_NAME       => 'EngineTests',
        SERVER_PORT       => '80',
        SERVER_PROTOCOL   => 'HTTP/1.1',
        SERVER_SOFTWARE   => 'Foswiki',
    );
    $env{REQUEST_METHOD} = $http->method();
    if ( $http->method eq 'POST' ) {
        $in                  = $http->content;
        $env{CONTENT_TYPE}   = $http->header('Content-Type');
        $env{CONTENT_LENGTH} = $http->header('Content-Length');
    }
    else {
        $env{QUERY_STRING} = $http->uri->query;
    }
    foreach my $h ( $http->header_field_names ) {
        next if $h =~ /^Content-Length$/i;
        my $v = $http->header($h);
        $h =~ tr/-/_/;
        $env{ 'HTTP_' . uc($h) } = $v;
    }
    $env{REMOTE_ADDR} = '127.0.0.1';

    # This implementation supports neither REMOTE_USER nor PATH_INFO.
    return \%env, \$in;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
}

sub _perform_request {
    my ( $env, $in ) = @_;

    CGI::initialize_globals();
    untie(*STDIN);
    untie(*STDOUT);

    # Saving STDIN
    open my $stdin, '<&=', \*STDIN or die "Can't dup STDIN: $!";
    close STDIN;

    # Redirecting STDIN to the CGI input
    open STDIN, '<', $in or die "Can't redirect STDIN to \$in: $!";

    # Saving STDOUT
    open my $stdout, '>&=', \*STDOUT or die "Can't dup STDOUT: $!";
    close STDOUT;
    my $out = '';

    # Redirecting STDOUT to $out to grap the CGI output
    open STDOUT, '>', \$out or die "Can't redirect STDOUT to \$out: $!";
    local %ENV = %$env;
    eval {
        $ENV{FOSWIKI_ACTION} = 'test';
        $Foswiki::engine->run();
    };

    # Restoring STDIN
    open STDIN, '<&=', $stdin or die "Can't restore STDIN: $!";
    close $stdin;

    # Restoring STDOUT
    open STDOUT, '>&=', $stdout or die "Can't restore STDOUT: $!";
    close $stdout;
    return HTTP::Message->parse($out);
}

sub make_request {
    my ( $this, $req ) = @_;
    return _perform_request( _req2cgi($req) );
}

sub make_bare_request {
    my ( $this, $http ) = @_;
    return _perform_request( _http2cgi($http) );
}

1;
