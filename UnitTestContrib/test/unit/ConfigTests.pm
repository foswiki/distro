package ConfigTests;
use v5.14;

use Foswiki;
use Try::Tiny;

use Foswiki::Class;
extends qw( FoswikiTestCase );

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    # You can now safely modify $Foswiki::cfg

    try {
        $this->createNewFoswikiApp(
            requestParams => { initializer => '', },
            engineParams =>
              { initialAttributes => { path_info => '/TestCases/WebHome', }, },
            user => 'AdminUser',
        );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::AccessControlException') ) {
            $this->assert( 0, $e->stringify );
        }
        else {
            $e->rethrow;
        }
    };

    my $cfgData = $this->app->cfg->data;
    $cfgData->{ConfigTests}{SubKey1}{Key1}    = "This is key 1";
    $cfgData->{ConfigTests}{SubKey1}{Key2}    = "This is key 2";
    $cfgData->{ConfigTests}{SubKey1}{Key3}    = [qw(This is key 3)];
    $cfgData->{ConfigTests}{SubKey2}{HashKey} = {
        a => 3,
        b => 2,
        c => 1,
    };

    return;
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    # Always do this, and always do it last
    $orig->($this);

    return;
};

sub test_getNode {
    my $this = shift;

    $this->app->cfg->tieData;

    my $node = $this->app->cfg->getKeyNode('ConfigTests.SubKey1.Key2');

    $this->assert_equals( "This is key 2", $node->value );

    return;
}

sub test_TieUntie {
    my $this = shift;

    $this->app->cfg->tieData;
    $this->app->cfg->untieData;

    my $cfgData = $this->app->cfg->data;
    $this->assert( !tied %$cfgData, "Config data must not be tied." );
    $this->assert(
        !tied %{ $cfgData->{ConfigTests} },
        "First level LSC keys must not be tied"
    );
    $this->assert(
        !tied %{ $cfgData->{ConfigTests}{SubKey1} },
        "Second level LSC keys must not be tied"
    );
}

sub test_specSimple {
    my $this = shift;

    $this->app->cfg->spec(
        __FILE__,
        -section => Extensions => -text => "Just extensions" => [
            -section => TestExt => -text => "Test extension" => [
                -modprefix          => 'Foswiki::Extension::TestExt',
                'ANewKey.NewSubKey' => [
                    Valid => { -type => 'BOOL', },
                    Text  => { -type => 'TEXT', },
                ],
                'Extensions.TestExt' => {
                    Sample => { -type => 'INTEGER', },
                    StrKey => { -type => 'TEXT(32)', }
                },
            ],
            -section => SampleExt => -text => "Sample extension" => [
                -modprefix             => 'Foswiki::Extension::SampleExt',
                'Extensions.SampleExt' => [
                    Option => {
                        -type    => 'BOOL',
                        -default => 0,
                    },
                    Setting => {
                        -type     => 'SELECT',
                        -variants => [qw(one two three)],
                    },
                    'Sub.Setting.Deep' => [
                        'Opt.K1' => { -type => 'TEXT', },
                        'Opt.K2' => { -type => 'NUMBER', },
                    ],
                ],
                -modprefix             => 'Foswiki::Extension::OtherExt',
                'Extensions.SampleExt' => [
                    Param => {
                        -type    => 'NUMBER',
                        -default => 3.14,
                    },
                    OneOf => {
                        -type    => 'PERL',
                        -default => { a => 1, b => 2, c => 3, },
                        -expert  => 1,
                    },
                ],
            ],
        ],
    );

    my $cfgData = $this->app->cfg->data;

    return;
}

1;
