package ExceptionTests;
use base 'FoswikiFnTestCase';

use strict;

use Error qw( :try );
use Foswiki::OopsException;
use Foswiki::AccessControlException;

my $UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('oops');
}

# Check an OopsException with one non-array parameter
sub test_simpleOopsException {
    my $this = shift;
    try {
        throw Foswiki::OopsException(
            'templatename',
            web    => 'webname',
            topic  => 'topicname',
            def    => 'defname',
            keep   => 1,
            params => 'phlegm'
        );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert( $e->isa('Foswiki::OopsException') );
        $this->assert_str_equals( 'webname',   $e->{web} );
        $this->assert_str_equals( 'topicname', $e->{topic} );
        $this->assert_str_equals( 'defname',   $e->{def} );
        $this->assert_equals( 1, $e->{keep} );
        $this->assert_str_equals( 'templatename', $e->{template} );
        $this->assert_str_equals( 'phlegm', join( ',', @{ $e->{params} } ) );
        $this->assert_str_equals(
'OopsException(templatename/defname web=>webname topic=>topicname keep=>1 params=>[phlegm])',
            $e->stringify()
        );
    };
}

# Check an oops exception with several parameters, including illegal HTML
sub test_multiparamOopsException {
    my $this = shift;
    try {
        throw Foswiki::OopsException(
            'templatename',
            web    => 'webname',
            topic  => 'topicname',
            params => [ 'phlegm', '<pus>' ]
        );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert( $e->isa('Foswiki::OopsException') );
        $this->assert_str_equals( 'webname',      $e->{web} );
        $this->assert_str_equals( 'topicname',    $e->{topic} );
        $this->assert_str_equals( 'templatename', $e->{template} );
        $this->assert_str_equals( 'phlegm,<pus>',
            join( ',', @{ $e->{params} } ) );
        $this->assert_str_equals(
'OopsException(templatename web=>webname topic=>topicname params=>[phlegm,<pus>])',
            $e->stringify()
        );
    };
}

sub upchuck {
    my $session = shift;
    my $e       = new Foswiki::OopsException(
        'templatename',
        web    => 'webname',
        topic  => 'topicname',
        params => [ 'phlegm', '<pus>' ]
    );
    $e->redirect($session);
}

# Test for DEPRECATED redirect
sub test_redirectOopsException {
    my $this = shift;
    my $t    = new Foswiki();
    my ( $output, $result ) = $this->capture( \&upchuck, $t );
    $t->finish();
    $this->assert_matches( qr/^Status: 302.*$/m, $output );
    $this->assert_matches(
qr#^Location: http.*/oops/webname/topicname?template=oopstemplatename;param1=phlegm;param2=%26%2360%3bpus%26%2362%3b$#m,
        $output
    );
}

sub test_AccessControlException {
    my $this = shift;
    my $ace  = new Foswiki::AccessControlException( 'FRY', 'burger', 'Spiders',
        'FlumpNuts', 'Because it was there.' );
    $this->assert_str_equals(
"AccessControlException: Access to FRY Spiders.FlumpNuts for burger is denied. Because it was there.",
        $ace->stringify()
    );

}

sub test_oopsScript {
    my $this  = shift;
    my $query = new Unit::Request(
        {
            skin     => 'none',
            template => 'oopsgeneric',
            def      => 'message',
            param1   => 'heading',
            param2   => '<pus>',
            param3   => 'snot@dot.dat',
            param4   => 'phlegm',
            param5   => "the cat\nsat on\nthe rat"
        }
    );
    my $session = new Foswiki( undef, $query );
    my ( $output, $result ) =
      $this->capture( \&$UI_FN, $session, "Flum", "DeDum", $query, 0 );
    $this->assert_matches( qr/^phlegm$/m,           $output );
    $this->assert_matches( qr/^&#60;pus&#62;$/m,    $output );
    $this->assert_matches( qr/^snot&#64;dot.dat$/m, $output );
    $this->assert_matches( qr/^the cat$/m,          $output );
    $this->assert_matches( qr/^sat on$/m,           $output );
    $this->assert_matches( qr/^the rat$/m,          $output );
    $this->assert_matches( qr/^phlegm$/m,           $output );
}

1;
