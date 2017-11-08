package ExceptionTests;
use v5.14;

use Try::Tiny;
use Foswiki::OopsException();
use Foswiki::AccessControlException();
use Scalar::Util qw<blessed>;

use Foswiki::Class;
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

package Foswiki::Exception::TestException {
    use Foswiki::Class;
    extends qw<Foswiki::Exception>;
    with qw<Foswiki::Exception::Deadly>;

    has attr1 => ( is => 'rw', );
}

our $expectedLine;

sub simpleProblem {
    my $this   = shift;
    my @params = @_;

    $expectedLine = __LINE__ + 1;
    $this->Throw( 'TestException', "A test problem", @params );
}

sub callTheProblem {
    my $this = shift;

    $this->simpleProblem(@_);
}

sub test_ObjectThrow {
    my $this = shift;

    try {
        $this->callTheProblem( attr1 => 3.1415926, );
    }
    catch {
        my $e = $_;

        $this->assert( blessed($e), "unblessed exception object" );
        $this->assert_str_equals( 'Foswiki::Exception::TestException',
            ref($e), "incorrect exception class " . ref($e) );
        $this->assert_equals( 3.1415926, $e->attr1, "Attribute value is lost" );

        $this->assert_equals( $e->text, "A test problem" );
        $this->assert_matches( qr/\bExceptionTests.pm/, $e->file );
        $this->assert_equals( $expectedLine, $e->line );
        $this->assert( blessed( $e->object ),
            "Exception object attribute is not blessed" );
        $this->assert_str_equals( __PACKAGE__,
            ref( $e->object ),
            "Exception object class must not be " . ref( $e->object )
        );
    };
}

sub test_ObjectThrowWithAttrs {
    my $this = shift;

    try {
        # Make it absurdly high line number
        $this->callTheProblem( line => 31415926, file => "AnotherFile", );
    }
    catch {
        my $e = $_;

        $this->assert_equals( 31415926, $e->line );
        $this->assert_str_equals( "AnotherFile", $e->file );
    };
}

package Foswiki::Exception::TestFatal {
    use Foswiki::Class;
    extends qw<Foswiki::Exception::Fatal>;

    has attr2 => ( is => 'rw', );
}

sub test_ObjectTransmute {
    my $this = shift;

    my $srcExcpt = Foswiki::Exception::TestFatal->new(
        text  => "Source exception",
        attr2 => 3.1415926,
    );

    $this->assert_equals( undef, $srcExcpt->object );

    # 1. Transmute into base class, unenforced
    my $destExcpt = $this->Transmute( 'Fatal', $srcExcpt );
    $this->assert( blessed($destExcpt), "Transmuted exception is not blessed" );
    $this->assert_str_equals( 'Foswiki::Exception::TestFatal',
        ref($destExcpt) );
    $this->assert_equals( undef, $destExcpt->object );

    # 2. Transmute into base class, enforced
    $destExcpt = $this->Transmute( 'Fatal', $srcExcpt, 1 );
    $this->assert( blessed($destExcpt), "Transmuted exception is not blessed" );
    $this->assert_str_equals( 'Foswiki::Exception::TestFatal',
        ref($destExcpt) );

    # Exception is not transmuted even when enforced if $srcExcpt descendant of
    # the destination exception class.
    $this->assert_equals( undef, $destExcpt->object );

    # 3. Transmute into a non-base class, unenforced.
    $destExcpt =
      $this->Transmute( 'TestException', $srcExcpt, 0, attr1 => 2.71828, );
    $this->assert( blessed($destExcpt), "Transmuted exception is not blessed" );
    $this->assert_str_equals( 'Foswiki::Exception::TestFatal',
        ref($destExcpt) );
    $this->assert_equals( undef, $destExcpt->object );

    # 4. Transmute into a non-base class, enforced.
    $expectedLine = __LINE__ + 1;
    $destExcpt =
      $this->Transmute( 'TestException', $srcExcpt, 1, attr1 => 2.71828, );
    $this->assert( blessed($destExcpt), "Transmuted exception is not blessed" );
    $this->assert_str_equals( 'Foswiki::Exception::TestException',
        ref($destExcpt) );
    $this->assert_equals( 2.71828, $destExcpt->attr1 );
    $this->assert( !exists $destExcpt->{attr2},
        "attr2 cannot exists on " . ref($destExcpt) );
    $this->assert_equals( $this, $destExcpt->object,
"Exception object attribute is not the one called the Transmute() method"
    );
    $this->assert_equals( $expectedLine, $destExcpt->line,
        "Exception source line is different from expected" );

    # 5. Transmute simple error text, unenforced
    $expectedLine = __LINE__ + 1;
    $destExcpt    = $this->Transmute( 'TestException', "Some error message",
        0, attr1 => 3.1415926, );
    $this->assert( blessed($destExcpt), "Transmuted exception is not blessed" );
    $this->assert_str_equals( 'Foswiki::Exception::TestException',
        ref($destExcpt) );
    $this->assert_equals( 3.1415926, $destExcpt->attr1 );
    $this->assert_equals( $expectedLine, $destExcpt->line,
        "Exception source line is different from expected" );
}

sub test_ObjectRethrow {
    my $this = shift;

    my $rsub = sub {
        try {
            $this->callTheProblem( attr1 => 1234.3456, );
        }
        catch {
            $this->Rethrow( 'TestFatal', $_, attr2 => 9876.7654, );
        };
    };

    my $e;
    try {
        $rsub->();
    }
    catch {
        $e = $_;
    };

    $this->assert( blessed($e), "Unblessed exception caught" );
    $this->assert_str_equals( 'Foswiki::Exception::TestException', ref($e) );
    $this->assert_equals( 1234.3456, $e->attr1,
        "Unexpected value " . $e->attr1 . " in attr1" );
    $this->assert_equals( $this, $e->object,
"Exception object attribute is not the one called the Transmute() method"
    );

    $rsub = sub {
        try {
            # Prevent system-level handler from converting text into
            # Foswiki::Exception::Fatal.
            local $SIG{__DIE__};
            die "simple die message";
        }
        catch {
            $this->Rethrow( "TestFatal", $_, attr2 => 4321.6543, );
        };
    };

    try {
        $rsub->();
    }
    catch {
        $e = $_;
    };

    $this->assert( blessed($e), "Unblessed exception caught" );
    $this->assert_str_equals( 'Foswiki::Exception::TestFatal', ref($e) );
    $this->assert_equals( 4321.6543, $e->attr2,
        "Unexpected value " . $e->attr2 . " in attr1" );
    $this->assert_equals( $this, $e->object,
"Exception object attribute is not the one called the Transmute() method"
    );
}

sub test_ObjectRethrowAs {
    my $this = shift;

    my $rsub = sub {
        try {
            $this->callTheProblem( attr1 => 1234.3456, );
        }
        catch {
            $this->RethrowAs( 'TestFatal', $_, attr2 => 9876.7654, );
        };
    };

    my $e;
    try {
        $rsub->();
    }
    catch {
        $e = $_;
    };

    $this->assert( blessed($e), "Unblessed exception caught" );
    $this->assert_str_equals( 'Foswiki::Exception::TestFatal', ref($e) );
    $this->assert_equals( 9876.7654, $e->attr2,
        "Unexpected value " . $e->attr2 . " in attr1" );
    $this->assert_equals( $this, $e->object,
"Exception object attribute is not the one called the Transmute() method"
    );
}

1;
