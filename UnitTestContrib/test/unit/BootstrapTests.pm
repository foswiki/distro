# See the bottom of the file for description, copyright and license information
package BootstrapTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Error (':try');
use Data::Dumper;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    my @root = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@root);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @root, 'x' );
    chop $root;
    $root =~ s|\\|/|g;
    $this->{rootdir} = $root;

    $this->SUPER::set_up();

}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub fixture_groups {

    return (
        [ 'Suffix', 'Nosuffix', ],
        [ 'FullURLs', 'ShortURLs', 'MinimumURLs' ],
        [ 'HTTP',     'HTTPS', ],
        [ 'Apache',    'ApacheNoRewrite', 'Lighttpd', 'Nginx', 'WinApache' ],
        [ 'EngineCGI', 'EngineFastCGI', ],
    );
}

sub skip {
    my ( $this, $test ) = @_;

    my %skip_tests = (
'BootstrapTests::verify_Test_Bootstrap_Suffix_FullURLs_HTTP_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Core_Bootstrap_Suffix_FullURLs_HTTP_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Test_Bootstrap_Suffix_FullURLs_HTTPS_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Core_Bootstrap_Suffix_FullURLs_HTTPS_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Test_Bootstrap_Suffix_ShortURLs_HTTP_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Core_Bootstrap_Suffix_ShortURLs_HTTP_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Test_Bootstrap_Suffix_ShortURLs_HTTPS_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Core_Bootstrap_Suffix_ShortURLs_HTTPS_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Test_Bootstrap_Suffix_MinimumURLs_HTTP_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Core_Bootstrap_Suffix_MinimumURLs_HTTP_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Test_Bootstrap_Suffix_MinimumURLs_HTTPS_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Core_Bootstrap_Suffix_MinimumURLs_HTTPS_Nginx_EngineFastCGI'
          => 'Nginx / FCGI does not support script suffixes',
'BootstrapTests::verify_Test_Bootstrap_Suffix_FullURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Suffix_FullURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Suffix_FullURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Suffix_FullURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Suffix_ShortURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Suffix_ShortURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Suffix_ShortURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Suffix_ShortURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Suffix_MinimumURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Suffix_MinimumURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Suffix_MinimumURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Suffix_MinimumURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Nosuffix_FullURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Nosuffix_FullURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Nosuffix_FullURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Nosuffix_FullURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Nosuffix_ShortURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Nosuffix_ShortURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Nosuffix_ShortURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Nosuffix_ShortURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Nosuffix_MinimumURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Nosuffix_MinimumURLs_HTTP_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Test_Bootstrap_Nosuffix_MinimumURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
'BootstrapTests::verify_Core_Bootstrap_Nosuffix_MinimumURLs_HTTPS_Nginx_EngineCGI'
          => 'Nginx does not support plain CGI',
    );

    return $skip_tests{$test}
      if ( defined $test && defined $skip_tests{$test} );

    return undef;
}

sub EngineCGI {
    my $this = shift;
    $this->{engine}    = 'Foswiki::Engine::CGI';
    $this->{binscript} = 'view';
    return;
}

sub EngineFastCGI {
    my $this = shift;
    $this->{engine}           = 'Foswiki::Engine::FastCGI';
    $this->{binscript}        = 'foswiki.fcgi';
    $this->{ENV}{SCRIPT_NAME} = $this->{prefix};
    $this->{ENV}{REQUEST_URI} =
      $this->{prefix} . $this->{script} . $this->{pathinfo};
    $this->{ENV}{PATH_INFO} = $this->{pathinfo};

    return;
}

sub FullURLs {
    my $this = shift;

    $this->{url}    = "full";
    $this->{host}   = "mysite.com";
    $this->{prefix} = "/foswiki/bin";

    #    $this->{script}   = $this->{prefix} . "/view" . $this->{suffix};
    $this->{script}   = "/view";
    $this->{testURL}  = "/foswiki/bin/view$this->{suffix}/Main/WebHome";
    $this->{pathinfo} = "/Main/WebHome";
    $this->{pubURL}   = "/foswiki/pub/System/Somefile.txt";

    $this->{PubUrlPath}        = '/foswiki/pub';
    $this->{ScriptUrlPath}     = '/foswiki/bin';
    $this->{ViewScriptUrlPath} = '/foswiki/bin/view';

    return;
}

sub ShortURLs {
    my $this = shift;
    $this->{url}      = "short";
    $this->{host}     = "mysite.com";
    $this->{prefix}   = "/foswiki";
    $this->{script}   = '';
    $this->{testURL}  = "/foswiki/Main/WebHome";
    $this->{pathinfo} = "/Main/WebHome";
    $this->{pubURL}   = "/foswiki/pub/System/Somefile.txt";

    $this->{PubUrlPath}        = '/foswiki/pub';
    $this->{ScriptUrlPath}     = '/foswiki/bin';
    $this->{ViewScriptUrlPath} = '/foswiki';

    return;
}

sub MinimumURLs {
    my $this = shift;
    $this->{url}        = "minimum";
    $this->{host}       = "mysite.com";
    $this->{testURL}    = "/Main/WebHome";
    $this->{prefix}     = "";
    $this->{script}     = $this->{prefix};
    $this->{pathinfo}   = "/Main/WebHome";
    $this->{pubURL}     = "/pub/System/Somefile.txt";
    $this->{PubUrlPath} = '/pub';

    $this->{ScriptUrlPath}     = '/bin';
    $this->{ViewScriptUrlPath} = '';

    return;
}

sub HTTP {
    my $this = shift;
    $this->{protocol} = "http://";
    $this->{https}    = undef;

    return;
}

sub HTTPS {
    my $this = shift;
    $this->{protocol} = "https://";
    $this->{https}    = 1;

    return;
}

sub Suffix {
    my $this = shift;

    $this->{suffix} = '.pl';

    return;
}

sub Nosuffix {
    my $this = shift;

    $this->{suffix} = '';

    return;
}

sub Apache {
    my $this = shift;

    $this->{ENV} = {
        HTTP_HOST   => $this->{host},
        PATH_INFO   => $this->{testURL},
        REQUEST_URI => $this->{testURL},
        SCRIPT_URI  => $this->{protocol} . $this->{host} . $this->{testURL},
        SCRIPT_URL  => $this->{testURL},
        SCRIPT_NAME => $this->{script},
        PATH_INFO   => $this->{pathinfo},
        HTTPS       => $this->{https},
    };
    return;
}

sub ApacheNoRewrite {
    my $this = shift;

    $this->{ENV} = {
        HTTP_HOST   => $this->{host},
        PATH_INFO   => $this->{testURL},
        REQUEST_URI => $this->{testURL},
        SCRIPT_URL  => $this->{testURL},
        SCRIPT_NAME => $this->{script},
        PATH_INFO   => $this->{pathinfo},
        HTTPS       => $this->{https},
    };
    return;
}

sub Lighttpd {
    my $this = shift;

    $this->{ENV} = {
        HTTP_HOST   => $this->{host},
        PATH_INFO   => $this->{testURL},
        REQUEST_URI => $this->{testURL},
        SCRIPT_URI  => $this->{protocol} . $this->{host} . $this->{testURL},
        SCRIPT_URL  => $this->{testURL},
        SCRIPT_NAME => '/bin/view',  # Script name is always present in Lighttpd
        PATH_INFO => $this->{pathinfo},
        HTTPS     => $this->{https},
    };

    return;
}

sub Nginx {
    my $this = shift;

    $this->{ENV} = {
        HTTP_HOST   => $this->{host},
        PATH_INFO   => $this->{testURL},
        REQUEST_URI => $this->{testURL},
        SCRIPT_URI  => $this->{protocol} . $this->{host} . $this->{testURL},
        SCRIPT_URL  => $this->{testURL},
        SCRIPT_NAME => 'view',
        PATH_INFO   => $this->{pathinfo},
        HTTPS       => $this->{https},
    };

    return;
}

sub WinApache {
    my $this = shift;

    $this->{ENV} = {
        HTTP_HOST   => $this->{host},
        PATH_INFO   => $this->{testURL},
        REQUEST_URI => $this->{testURL},
        SCRIPT_URI  => $this->{protocol} . $this->{host} . $this->{testURL},
        SCRIPT_URL  => $this->{testURL},
        SCRIPT_NAME => '/foswiki/bin',
        PATH_INFO   => $this->{pathinfo},
        HTTPS       => $this->{https},
    };

    return;
}

sub disable_verify_Test_Bootstrap {
    my $this = shift;
    my $msg;
    my $boot_cfg;
    my $resp;

    ( $msg, $boot_cfg ) = $this->_runBootstrap(0);

    #print STDERR "BOOTSTRAP RETURNS:\n $msg\n";
    #print STDERR Data::Dumper::Dumper( \$boot_cfg );

    $this->_validate($boot_cfg);

    return;
}

sub verify_Core_Bootstrap {
    my $this = shift;
    my $msg;
    my $boot_cfg;
    my $resp;

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    #print STDERR "BOOTSTRAP RETURNS:\n $msg\n";
    #print STDERR Data::Dumper::Dumper( \$boot_cfg );

    $this->_validate($boot_cfg);

    return;
}

sub _validate {
    my ( $this, $boot_cfg ) = @_;

    $this->assert_str_equals( $this->{PubUrlPath}, $boot_cfg->{PubUrlPath} );
    $this->assert_str_equals( $this->{ScriptUrlPath},
        $boot_cfg->{ScriptUrlPath} );
    my $suffix = ( $this->{url} eq 'full' ) ? $this->{suffix} : '';
    $this->assert_str_equals(
        $this->{ViewScriptUrlPath} . $suffix,
        $boot_cfg->{ScriptUrlPaths}{view}
    );
}

sub test_DefaultHostUrl {
    my $this = shift;

    $this->{binscript} = 'view';
    $this->{engine}    = 'Foswiki::Engine::CGI';
    $this->{suffix}    = '';
    $this->{ENV}       = {
        HTTP_HOST   => 'foobar.com',
        REQUEST_URI => '',
        SCRIPT_URL  => '',
        PATH_INFO   => '',
    };

    my $msg;
    my $boot_cfg;
    my $resp;

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_matches(
        qr{AUTOCONFIG: Set \(http://foobar.com\) from detected},

        $msg
    );
    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'http://foobar.com' );

    $this->{ENV} = {
        SERVER_NAME => 'foobar.com',
        REQUEST_URI => '',
        SCRIPT_URL  => '',
        PATH_INFO   => '',
    };
    $msg = '';

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_matches(
        qr{AUTOCONFIG: Set \(http://foobar.com\) from detected}, $msg );
    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'http://foobar.com' );

    $this->{ENV} = {
        SCRIPT_URI  => 'https://foobar.com/foswiki/bin/view/Main/WebHome',
        REQUEST_URI => '',
        SCRIPT_URL  => '',
        PATH_INFO   => '',
    };
    $msg = '';

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_matches(
        qr{AUTOCONFIG: Set \(https://foobar.com\) from detected}, $msg );
    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'https://foobar.com' );

    $this->{ENV} = {
        SCRIPT_URI  => '',
        REQUEST_URI => '',
        SCRIPT_URL  => '',
        PATH_INFO   => '',
    };
    $msg = '';

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost}, 'http://localhost' );

    return;
}

sub _runBootstrap {
    my $this     = shift;
    my $coreTest = shift;

    local %ENV;
    %ENV = %{ $this->{ENV} };

    local *STDERR;
    my $log;
    open STDERR, '>', \$log;

    my ( $boot_cfg, $resp ) = $this->_bootstrapConfig($coreTest);
    close STDERR;
    my $msg .= $resp . "\n\n";
    $msg .= $log;

    return ( $msg, $boot_cfg );
}

# Overrides FindBin::again to prevent refreshing of the results.
sub _again { return; }

sub _bootstrapConfig {
    my $this     = shift;
    my $coreTest = shift;

    local %Foswiki::cfg = ( Engine => $this->{engine} );
    my $msg;

    no warnings 'redefine';
    require FindBin;
    *FindBin::again = \&_again;
    use warnings 'redefine';
    $FindBin::Bin    = $this->{rootdir} . 'bin';
    $FindBin::Script = $this->{binscript} . $this->{suffix};

    require Foswiki::Configure::Bootstrap;

    if ( $coreTest && Foswiki::Configure::Load->can('bootstrapConfig') ) {
        $msg = Foswiki::Configure::Load::bootstrapConfig();
        $msg .= Foswiki::Configure::Load::bootstrapWebSettings('view');
    }
    elsif ( $coreTest && Foswiki::Configure::Bootstrap->can('bootstrapConfig') )
    {
        $msg = Foswiki::Configure::Bootstrap::bootstrapConfig();
        $msg .= Foswiki::Configure::Bootstrap::bootstrapWebSettings('view');
    }
    else {
        die "Not supported";
    }

    $msg .= "\n\n";
    foreach my $ek ( sort keys %ENV ) {
        $msg .= "\$ENV{$ek} = $ENV{$ek} \n" if ( defined $ENV{$ek} );
    }

    return ( \%Foswiki::cfg, $msg );
}

sub test_proxyConfigs {
    my $this = shift;

    $this->{binscript} = 'view';
    $this->{engine}    = 'Foswiki::Engine::CGI';
    $this->{suffix}    = '';
    $this->{ENV}       = {
        HTTP_HOST             => 'foobar.com',
        REQUEST_URI           => '',
        SCRIPT_URL            => '',
        PATH_INFO             => '',
        HTTP_X_FORWARDED_HOST => 'wazoo.com',
        HTTP_X_FORWARDED_FOR  => '192.168.1.1,10.1.1.1',
    };

    my $msg;
    my $boot_cfg;
    my $resp;

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_matches(
qr{\QAUTOCONFIG: Engine detected:  client (192.168.1.1) proto (http) host (wazoo.com) port (80) proxy (1)\E},
        $msg
    );

    $this->assert_matches(
        qr{AUTOCONFIG: Set \(http://wazoo.com\) from detected},

        $msg
    );
    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'http://wazoo.com', "Wrong Fowrarded-Host" );

    #$this->{binscript} = 'view';
    #$this->{engine}    = 'Foswiki::Engine::CGI';
    #$this->{suffix}    = '';
    $this->{ENV} = {
        HTTP_HOST             => 'foobar.com',
        REQUEST_URI           => '',
        SCRIPT_URL            => '',
        PATH_INFO             => '',
        HTTP_X_FORWARDED_HOST => 'wazoo.com,proxy1.com,proxy2',
    };

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_matches(
        qr{AUTOCONFIG: Set \(http://wazoo.com\) from detected},

        $msg
    );
    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'http://wazoo.com', "Wrong Fowrarded-Host" );

    # Port 8080 from Forwarded-port header

    $this->{ENV} = {
        HTTP_HOST             => 'foobar.com',
        REQUEST_URI           => '',
        SCRIPT_URL            => '',
        PATH_INFO             => '',
        HTTP_X_FORWARDED_HOST => 'wazoo.com,proxy1.com,proxy2',
        HTTP_X_FORWARDED_PORT => '8080,999',
    };

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'http://wazoo.com:8080',
        "Wrong Fowrarded-Host or port - should be 8080" );

    # Port 80 provided from Forwarded-Port header shoud be ignored

    $this->{ENV} = {
        HTTP_HOST             => 'foobar.com',
        REQUEST_URI           => '',
        SCRIPT_URL            => '',
        PATH_INFO             => '',
        HTTP_X_FORWARDED_HOST => 'wazoo.com,proxy1.com,proxy2',
        HTTP_X_FORWARDED_PORT => '80,999',
    };

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'http://wazoo.com',
        "Wrong Fowrarded-Host or port, port 80 should not be used." );

    # Port number provided on the Forwarded-host header

    $this->{ENV} = {
        HTTP_HOST             => 'foobar.com',
        REQUEST_URI           => '',
        SCRIPT_URL            => '',
        PATH_INFO             => '',
        HTTP_X_FORWARDED_HOST => 'wazoo.com:9001,proxy1.com,proxy2',
    };

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'http://wazoo.com:9001',
        "Wrong Fowrarded-Host or port from Forwarded-host" );

    # Port 80 provided from Forwarded-Port header shoud be ignored

    $this->{ENV} = {
        HTTP_HOST             => 'foobar.com',
        REQUEST_URI           => '',
        SCRIPT_URL            => '',
        PATH_INFO             => '',
        HTTP_X_FORWARDED_HOST => 'wazoo.com,proxy1.com,proxy2',

        #HTTP_X_FORWARDED_PORT => '80,999',
        HTTP_X_FORWARDED_PROTO => 'https',
    };

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'https://wazoo.com', "Wrong Fowrarded-Proto." );

    # https on an alternate port

    $this->{ENV} = {
        HTTP_HOST              => 'foobar.com',
        REQUEST_URI            => '',
        SCRIPT_URL             => '',
        PATH_INFO              => '',
        HTTP_X_FORWARDED_HOST  => 'wazoo.com,proxy1.com,proxy2',
        HTTP_X_FORWARDED_PORT  => '8443 , 999',
        HTTP_X_FORWARDED_PROTO => 'https,http',
    };

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'https://wazoo.com:8443', "Wrong protocol or port." );

    # SSL=1 query param override

    $this->{ENV} = {
        QUERY_STRING           => '?SSL=1',
        HTTP_HOST              => 'foobar.com',
        REQUEST_URI            => '',
        SCRIPT_URL             => '',
        PATH_INFO              => '',
        HTTP_X_FORWARDED_HOST  => 'wazoo.com,proxy1.com,proxy2',
        HTTP_X_FORWARDED_PROTO => 'http,http',
    };

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'https://wazoo.com', "Wrong protocol or port." );

    # Referrer override

    $this->{ENV} = {
        HTTP_REFERER           => 'https://wazoo.com/blah',
        HTTP_HOST              => 'foobar.com',
        REQUEST_URI            => '',
        SCRIPT_URL             => '',
        PATH_INFO              => '',
        HTTP_X_FORWARDED_HOST  => 'wazoo.com,proxy1.com,proxy2',
        HTTP_X_FORWARDED_PROTO => 'http,http',
    };

    ( $msg, $boot_cfg ) = $this->_runBootstrap(1);

    $this->assert_str_equals( $boot_cfg->{DefaultUrlHost},
        'https://wazoo.com', "Wrong protocol or port." );

}
1;

#   # lighttpd bin/configure
#HTTP_HOST  lf117.fenachrone.com
#REQUEST_URI    /bin/configure
#SCRIPT_FILENAME    /var/www/servers/Foswiki-1.1.7/bin/configure
#SCRIPT_NAME    /bin/configure
#SERVER_NAME    lf117.fenachrone.com
#SERVER_PORT    80

#   # Apache bin/configure
#HTTP_HOST  f119.fenachrone.com
#REQUEST_URI    /bin/configure
#SCRIPT_FILENAME    /var/www/data/Foswiki-1.1.9/bin/configure
#SCRIPT_NAME    /bin/configure
#SCRIPT_URI http://f119.fenachrone.com/bin/configure
#SCRIPT_URL /bin/configure
#SERVER_ADDR    127.0.0.1
#SERVER_ADMIN   webmaster@fenachrone.com
#SERVER_NAME    f119.fenachrone.com
#SERVER_PORT    80

#    # Apache /bin/view    Full URLs
#$ENV{HTTP_HOST} = foswiki.fenachrone.com
#$ENV{HTTP_USER_AGENT} = Mozilla/5.0 (X11; Linux i686; rv:24.0) Gecko/20100101 Firefox/24.0
#$ENV{PATH} = /usr/local/bin:/usr/bin:/bin
#$ENV{PATH_INFO} = /System/TestBootstrapPlugin
#$ENV{PATH_TRANSLATED} = /var/www/foswiki/distro/core/System/TestBootstrapPlugin
#$ENV{QUERY_STRING} = validation_key=97ea6202eda01850bf86544236b10c75
#$ENV{REMOTE_ADDR} = 127.0.0.1
#$ENV{REMOTE_PORT} = 47007
#$ENV{REQUEST_METHOD} = GET
#$ENV{REQUEST_URI} = /bin/view/System/TestBootstrapPlugin?validation_key=97ea6202eda01850bf86544236b10c75
#$ENV{SCRIPT_FILENAME} = /var/www/foswiki/distro/core/bin/view
#$ENV{SCRIPT_NAME} = /bin/view
#$ENV{SCRIPT_URI} = http://foswiki.fenachrone.com/bin/view/System/TestBootstrapPlugin
#$ENV{SCRIPT_URL} = /bin/view/System/TestBootstrapPlugin
#$ENV{SERVER_ADDR} = 127.0.0.1
#$ENV{SERVER_ADMIN} = webmaster@foswiki.fenachrone.com
#$ENV{SERVER_NAME} = foswiki.fenachrone.com
#$ENV{SERVER_PORT} = 80

#    # Apache   foswiki/System/Test...    Short URLs with prefix
# $ENV{HTTP_HOST} = foswiki.fenachrone.com
# $ENV{HTTP_USER_AGENT} = Mozilla/5.0 (X11; Linux i686; rv:24.0) Gecko/20100101 Firefox/24.0
# $ENV{PATH} = /usr/local/bin:/usr/bin:/bin
# $ENV{PATH_INFO} = /System/TestBootstrapPlugin
# $ENV{PATH_TRANSLATED} = /var/www/foswiki/distro/core/System/TestBootstrapPlugin
# $ENV{QUERY_STRING} = validation_key=97ea6202eda01850bf86544236b10c75
# $ENV{REMOTE_ADDR} = 127.0.0.1
# $ENV{REMOTE_PORT} = 47015
# $ENV{REQUEST_METHOD} = GET
# $ENV{REQUEST_URI} = /foswiki/System/TestBootstrapPlugin?validation_key=97ea6202eda01850bf86544236b10c75
# $ENV{SCRIPT_FILENAME} = /var/www/foswiki/distro/core/bin/view
# $ENV{SCRIPT_NAME} = /foswiki
# $ENV{SCRIPT_URI} = http://foswiki.fenachrone.com/foswiki/System/TestBootstrapPlugin
# $ENV{SCRIPT_URL} = /foswiki/System/TestBootstrapPlugin
# $ENV{SERVER_ADDR} = 127.0.0.1
# $ENV{SERVER_ADMIN} = webmaster@foswiki.fenachrone.com
# $ENV{SERVER_NAME} = foswiki.fenachrone.com
# $ENV{SERVER_PORT} = 80

#   # lighttpd bin/view   Short URLs
#HTTP_HOST = lf117.fenachrone.com
#PATH_INFO = /System/TestBootstrapPlugin
#REQUEST_URI = /System/TestBootstrapPlugin
#SCRIPT_FILENAME = /var/www/servers/Foswiki-1.1.7/bin/view
#SCRIPT_NAME = /bin/view
#SERVER_ADDR = 0.0.0.0
#SERVER_NAME = lf117.fenachrone.com
#SERVER_PORT = 80
#SERVER_PROTOCOL = HTTP/1.1

#    # Apache /bin/view    Full URLs
#$ENV{HTTP_HOST} = foswiki.fenachrone.com
#$ENV{HTTP_USER_AGENT} = Mozilla/5.0 (X11; Linux i686; rv:24.0) Gecko/20100101 Firefox/24.0
#$ENV{PATH} = /usr/local/bin:/usr/bin:/bin
#$ENV{PATH_INFO} = /System/TestBootstrapPlugin
#$ENV{PATH_TRANSLATED} = /var/www/foswiki/distro/core/System/TestBootstrapPlugin
#$ENV{QUERY_STRING} = validation_key=97ea6202eda01850bf86544236b10c75
#$ENV{REMOTE_ADDR} = 127.0.0.1
#$ENV{REMOTE_PORT} = 47007
#$ENV{REQUEST_METHOD} = GET
#$ENV{REQUEST_URI} = /bin/view/System/TestBootstrapPlugin?validation_key=97ea6202eda01850bf86544236b10c75
#$ENV{SCRIPT_FILENAME} = /var/www/foswiki/distro/core/bin/view
#$ENV{SCRIPT_NAME} = /bin/view
#$ENV{SCRIPT_URI} = http://foswiki.fenachrone.com/bin/view/System/TestBootstrapPlugin
#$ENV{SCRIPT_URL} = /bin/view/System/TestBootstrapPlugin
#$ENV{SERVER_ADDR} = 127.0.0.1
#$ENV{SERVER_ADMIN} = webmaster@foswiki.fenachrone.com
#$ENV{SERVER_NAME} = foswiki.fenachrone.com
#$ENV{SERVER_PORT} = 80

__END__

Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014-2020 George Clark and Foswiki Contributors.
All Rights Reserved. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

For licensing info read LICENSE file in the Foswiki root.

Author: George Clark
