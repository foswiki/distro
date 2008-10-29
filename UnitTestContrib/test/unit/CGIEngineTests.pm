package CGIEngineTests;

# Still under development. This is an experiment about
# how to test engine-related code.

use base qw(Unit::TestCase);
use strict;
use warnings;

BEGIN {
    $TWiki::cfg{Engine} = 'TWiki::Engine::CGI';
}

use TWiki;
use TWiki::Response;
use TWiki::UI;

use File::Temp;
use Storable qw(freeze thaw);
use Data::Dumper;

$TWiki::cfg{SwitchBoard}{test} = [ 'TWiki::UI::Test', 'test', { test => 1 } ];

sub cgi_env {
    return (
        GATEWAY_INTERFACE => 'CGI/1.1',
        REMOTE_ADDR       => '127.0.0.1',
        REQUEST_METHOD    => 'GET',
        SCRIPT_NAME       => '/twiki/bin/test',
        SERVER_NAME       => 'CGIEngineTests',
        SERVER_PORT       => '80',
        SERVER_PROTOCOL   => 'HTTP/1.1',
        SERVER_SOFTWARE   => 'CGIEngineTests',
        HTTP_HOST         => 'localhost',
        PATH_INFO         => '/test/Web/Topic',
        QUERY_STRING      => 'foo=bar&a=b&c=d',
    );
}

sub test_bli {
    local %ENV;

    %ENV = cgi_env;
    my $res = new TWiki::Response();
    $res->header(-type => 'text/plain', charset => 'iso8859-1');
    $res->body("Teste!\n");
    $ENV{QUERY_STRING} = 'desired_test_response='.TWiki::urlEncode(freeze($res));
    my $out = '';
    open my $stdout, '>&', \*STDOUT;
    close STDOUT;
    open STDOUT, '>', \$out;
    $TWiki::engine->run();
    open STDOUT, '>&', $stdout;
    $out =~ /(?:\r?\n){2}(.*)/s;
    #print STDERR Dumper(thaw($1));
    print STDERR Dumper($out);
}

1;
