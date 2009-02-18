package Unit::CGIEngine;

use base qw(Unit::TestCase);
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
        next if $h =~ /^Cookie|Content-Length$/i;
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
    return \%env, \$in;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    CGI::initialize_globals();
}

sub make_request {
    my ( $this, $req ) = @_;

    my ( $env, $in ) = _req2cgi($req);

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

1;
