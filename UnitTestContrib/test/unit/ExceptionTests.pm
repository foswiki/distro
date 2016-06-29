package ExceptionTests;
use v5.14;

use Try::Tiny;
use Foswiki::OopsException();
use Foswiki::AccessControlException();

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

# Check an OopsException with one non-array parameter
sub test_simpleOopsException {
    my $this = shift;
    try {
        Foswiki::OopsException->throw(
            app      => $this->app,
            template => 'templatename',
            web      => 'webname',
            topic    => 'topicname',
            def      => 'defname',
            keep     => 1,
            params   => 'phlegm'
        );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( 'webname',   $e->web );
            $this->assert_str_equals( 'topicname', $e->topic );
            $this->assert_str_equals( 'defname',   $e->def );
            $this->assert_equals( 1, $e->keep );
            $this->assert_str_equals( 'templatename', $e->template );
            $this->assert_str_equals( 'phlegm', join( ',', @{ $e->params } ) );
            $this->assert_matches(
qr/^OopsException\(templatename\/defname web=>webname topic=>topicname keep=>1 params=>\[phlegm\]\)/,
                $e->stringify()
            );
        }
        else {
            $e->rethrow;
        }
    };

    return;
}

# Check an oops exception with several parameters, including illegal HTML
sub test_multiparamOopsException {
    my $this = shift;
    try {
        Foswiki::OopsException->throw(
            app      => $this->app,
            template => 'templatename',
            web      => 'webname',
            topic    => 'topicname',
            params   => [ 'phlegm', '<pus>' ]
        );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( 'webname',      $e->web );
            $this->assert_str_equals( 'topicname',    $e->topic );
            $this->assert_str_equals( 'templatename', $e->template );
            $this->assert_str_equals( 'phlegm,<pus>',
                join( ',', @{ $e->params } ) );
            $this->assert_matches(
qr/^OopsException\(templatename web=>webname topic=>topicname params=>\[phlegm,<pus>\]\)/,
                $e->stringify()
            );
        }
        else {
            $e->rethrow;
        }
    };

    return;
}

sub upchuck {
    my $this = shift;
    my $e    = Foswiki::OopsException->create(
        template => 'templatename',
        web      => 'webname',
        topic    => 'topicname',
        params   => [ 'phlegm', '<pus>' ]
    );
    $e->redirect;

    return;
}

# Test for DEPRECATED redirect
sub deprecated_test_redirectOopsException {
    my $this = shift;
    $this->createNewFoswikiApp;
    my ($output) = $this->capture( \&upchuck );
    $this->assert_matches( qr/^Status: 302.*$/m, $output );
    $this->assert_matches(
qr#^Location: http.*/oops/webname/topicname?template=oopstemplatename;param1=phlegm;param2=%26%2360%3bpus%26%2362%3b$#m,
        $output
    );

    return;
}

sub test_AccessControlException {
    my $this = shift;
    my $ace  = Foswiki::AccessControlException->new(
        mode   => 'FRY',
        user   => 'burger',
        web    => 'Spiders',
        topic  => 'FlumpNuts',
        reason => 'Because it was there.'
    );
    $this->assert_str_contains(
"AccessControlException: Access to FRY Spiders.FlumpNuts for burger is denied. Because it was there.",
        $ace->stringify()
    );

    return;
}

sub test_oopsScript {
    my $this      = shift;
    my $oopsWeb   = "Flum";
    my $oopsTopic = "DeDum";
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                skin     => 'none',
                template => 'oopsgeneric',
                def      => 'message',
                param1   => 'heading',
                param2   => '<pus>',
                param3   => 'snot@dot.dat',
                param4   => 'phlegm',
                param5   => "the cat\nsat on\nthe rat",
            },
        },
        engineParams => {
            simulate          => 'cgi',
            initialAttributes => {
                path_info => "/$oopsWeb/$oopsTopic",
                uri       => $this->app->cfg->getScriptUrl(
                    0, 'oops', $oopsWeb, $oopsTopic
                ),
                action => 'oops',
            },
        },
    );
    my ($output) = $this->capture(
        sub {
            $this->app->handleRequest;
        }
    );
    $this->assert_matches( qr/^phlegm$/m,           $output );
    $this->assert_matches( qr/^&#60;pus&#62;$/m,    $output );
    $this->assert_matches( qr/^snot&#64;dot.dat$/m, $output );
    $this->assert_matches( qr/^the cat$/m,          $output );
    $this->assert_matches( qr/^sat on$/m,           $output );
    $this->assert_matches( qr/^the rat$/m,          $output );
    $this->assert_matches( qr/^phlegm$/m,           $output );

    return;
}

1;
