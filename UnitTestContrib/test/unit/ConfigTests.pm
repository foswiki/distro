package ConfigTests;

use Foswiki;
use Try::Tiny;
use Data::Dumper;

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

    $this->app->cfg->specsMode;

    my $node = $this->app->cfg->getKeyNode('ConfigTests.SubKey1.Key2');

    $this->assert_equals( "This is key 2", $node->value );

    return;
}

sub test_triggerConfigMode {
    my $this = shift;

    $this->app->cfg->specsMode;
    $this->app->cfg->dataMode;

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

sub test_specRegister {
    my $this = shift;

    my $cfg    = $this->app->cfg;
    my $holder = $cfg->localize;
    $cfg->clear_data;

    $cfg->spec(
        source => __FILE__,
        specs  => [
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
                            -type => 'SELECT',

                            #-variants => [qw(one two three)],
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

                            #-expert  => 1,
                        },
                    ],
                ],
            ],
        ],
    );

    my $expectedData = {
        ANewKey => {
            NewSubKey => {
                Valid => undef,
                Text  => undef,
            },
        },
        Extensions => {
            TestExt => {
                Sample => undef,
                StrKey => undef,
            },
            SampleExt => {
                Option  => 0,
                Setting => undef,
                Sub     => {
                    Setting =>
                      { Deep => { Opt => { K1 => undef, K2 => undef, }, }, },
                },
                Param => 3.14,
                OneOf => { a => 1, b => 2, c => 3, },
            },
        },
    };

    $this->assert_deep_equals( $expectedData, $cfg->data,
        "Config structure mismatch with specs definition" );

    my $sec = $cfg->rootSection->sections->[0];
    $this->assert_equals( "Extensions",       $sec->name );
    $this->assert_equals( "Just extensions",  $sec->text );
    $this->assert_equals( "TestExt",          $sec->sections->[0]->name );
    $this->assert_equals( "Test extension",   $sec->sections->[0]->text );
    $this->assert_equals( "SampleExt",        $sec->sections->[1]->name );
    $this->assert_equals( "Sample extension", $sec->sections->[1]->text );

    return;
}

sub test_specOnLocalData {
    my $this = shift;

    Foswiki::load_class('Foswiki::Config::DataHash');

    my %data;

    my $dataObj = tie %data, 'Foswiki::Config::DataHash', app => $this->app;

    my $cfg = $this->app->cfg;

    my $section = $this->create( 'Foswiki::Config::Section', name => 'Root', );

    $cfg->spec(
        source  => __FILE__,
        data    => $dataObj,
        section => $section,
        specs   => [
            -section => Section => [
                'Test1.Key1' => [
                    -type    => 'TEXT',
                    -default => 'Default Key1',
                ],
                'Test2.Key2' => [
                    -type    => 'NUMBER',
                    -default => 3.1415926,
                ],
            ]
        ],
    );

    $this->assert_deep_equals(
        {
            Test1 => { Key1 => 'Default Key1', },
            Test2 => { Key2 => 3.1415926, },
        },
        \%data
    );
}

sub test_unknownKeyOption {
    my $this = shift;

    try {
        $this->app->cfg->spec(
            source => __FILE__,
            specs  => [
                -section => Section => [
                    'Test.Key' => [
                        -type      => 'NUMBER',
                        -badOption => 'Value matters not...',
                    ],
                ],
            ],
        );

        $this->assert( 0,
            "A bad option must raise an exception but it didn't" );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        if ( $e->isa('Foswiki::Exception::Config::BadSpecData') ) {
            $this->assert_matches(
"Unknown key option 'badOption' \\(key 'Test.Key' is part of section 'Section'\\)",
                $e
            );
        }
        else { $e->rethrow; }
    };
}

sub test_defaultValue {
    my $this = shift;

    my $cfg    = $this->app->cfg;
    my $holder = $cfg->localize;
    $cfg->clear_data;

    my $defStr = "This is default";

    $cfg->spec(
        source => __FILE__,
        specs  => [
            -section => Section => [
                TestKey => [
                    Key1 => [
                        -type    => 'TEXT',
                        -default => $defStr,
                    ],
                    Key2 => [
                        -type    => 'NUMBER',
                        -default => 3.1415926,
                    ],
                ],
            ],
        ],
    );

    my $cfgData = $cfg->data;

    my $keyNode = $cfg->getKeyNode('TestKey.Key1');

    $this->assert_equals( $defStr,   $cfgData->{TestKey}{Key1} );
    $this->assert_equals( $defStr,   $keyNode->default );
    $this->assert_equals( 3.1415926, $cfgData->{TestKey}{Key2} );

    $cfg->data->{TestKey}{Key1} = "This is changed";
    $this->assert_equals( "This is changed", $cfgData->{TestKey}{Key1} );

    $this->assert_equals( $defStr,           $keyNode->default );
    $this->assert_equals( "This is changed", $keyNode->value );

    $keyNode->clear_value;

    $this->assert_equals( $defStr, $cfgData->{TestKey}{Key1} );

    $cfg->dataMode;

    $this->assert_equals( $defStr, $cfg->data->{TestKey}{Key1},
"The value of TestKey.Key1 doesn't match spec's default after switching to data mode."
    );
    $this->assert_equals( 3.1415926, $cfg->data->{TestKey}{Key2},
"The value of TestKey.Key2 doesn't match spec's default after switching to data mode."
    );
}

my %keyStructs = (
    Straigt     => [ 'A' .. 'M' ],
    ComplexDeep => [
        undef, [ qw(A B), [ [ 'C', [], 'D', [ 'E' .. 'J', undef ] ], undef ] ],
        qw(K L M)
    ],
    StraightString      => [ join( '.', 'A' .. 'M' ) ],
    ComplexWithStrings1 => [
        'A' .. 'D', ['E.F.G'],
        [ undef, [ 'H.I', [ undef, ['J'], ], 'K', ['L'] ], undef ], 'M'
    ],
    ComplexWithStrings2 => [
        [
            'A' .. 'D',
            ['E.F.G'],
            [ undef, [ 'H.I', [ undef, ['J'], ], 'K', ['L'] ], undef ], 'M'
        ]
    ],
    SingleArrayElem => [ [ join( '.', 'A' .. 'M' ) ] ],
    HashString => [ '{' . join( '}{', 'A' .. 'M' ) . '}' ],
    MixedStrings =>
      [ '{' . join( '}{', 'A' .. 'D' ) . '}', join( '.', 'E' .. 'M' ) ],
    ComplexWithMixedStrings => [
        [
            'A' .. 'D',
            ['{E}{F}{G}'],
            [ undef, [ 'H.I', [ undef, ['{J}'], ], 'K', ['L'] ], undef ], 'M'
        ]
    ],
);

my %emptyVariants = (
    NoArgs      => [],
    EmptyList   => [ [] ],
    Undef       => [undef],
    EmptyString => [''],
    SingleDot   => ['.'],
);

my %badKeyArgs = (
    InvalidChars => {
        data   => ['A.B.C.$name.(name).na}me'],
        badKey => '$name',
    },
    HasRef => {
        data   => [ 'A.B.C', \%emptyVariants ],
        badKey => \%emptyVariants,
    },
);

sub test_keyParsing {
    my $this = shift;

    my @keys;
    while ( my ( $variant, $keyData ) = each %keyStructs ) {
        @keys = $this->app->cfg->parseKeys(@$keyData);
        $this->assert_deep_equals( [ 'A' .. 'M' ],
            \@keys, "Failed variant: $variant" );
    }

    # Test empty variants.
    while ( my ( $variant, $keyData ) = each %emptyVariants ) {
        @keys = $this->app->cfg->parseKeys(@$keyData);
        $this->assert_num_equals( 0, scalar(@keys),
                "parseKeys() for "
              . $variant
              . " variant must return empty array" );
    }
}

sub test_arg2keys {
    my $this = shift;

    my @keys;
    while ( my ( $variant, $keyData ) = each %keyStructs ) {
        @keys = $this->app->cfg->arg2keys(@$keyData);
        $this->assert_deep_equals( [ 'A' .. 'M' ],
            \@keys, "Failed variant: $variant" );
    }

    while ( my ( $variant, $keyData ) = each %emptyVariants ) {
        try {
            @keys = $this->app->cfg->arg2keys(@$keyData);
            $this->assert( 0, "Empty variant $variant should have failed" );
        }
        catch {
            my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
            $this->assert_equals(
                "No valid config keys found in the method arguments",
                $e->text,
"Expected fatal exception with particular error message but got: "
                  . $e
            );
        };
    }

    while ( my ( $variant, $keyData ) = each %badKeyArgs ) {
        try {
            @keys = $this->app->cfg->arg2keys( @{ $keyData->{data} } );
            $this->assert( 0, "Invalid variant $variant should have failed" );
        }
        catch {
            my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
            $this->assert(
                $e->isa('Foswiki::Exception::Config::InvalidKeyName'),
"Expected exception Foswiki::Exception::Config::InvalidKeyName, got "
                  . ref($e) . ":"
                  . $e
            );
            $this->assert_equals( $keyData->{badKey}, $e->keyName,
                    "Expected key to fail: "
                  . ( $keyData->{badKey} // '*undef*' )
                  . "; but got: "
                  . ( $e->keyName // '*undef*' ) );
        };
    }
}

sub test_specFilesAttribute {
    my $this = shift;

    my $sf = $this->app->cfg->specFiles;

    foreach my $sfile ( @{ $sf->list } ) {
        say STDERR $sfile->fmt, " -- ", $sfile->cacheFile->path;
    }

    return;
}

1;
