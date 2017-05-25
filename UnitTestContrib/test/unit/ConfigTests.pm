package ConfigTests;

use Foswiki;
use Try::Tiny;
use Data::Dumper;

use Foswiki::Class;
extends qw( FoswikiTestCase );

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    say STDERR "My attrs: ",
      join( ", ", Foswiki::Class::getClassAttributes( ref($this) ) );

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

    my $data    = $cfg->makeSpecsHash;
    my $dataObj = tied %$data;
    my $rootSection =
      $this->create( 'Foswiki::Config::Section', name => 'Root', );

    $cfg->spec(
        source    => __FILE__,
        dataObj   => $dataObj,
        localData => 1,
        section   => $rootSection,
        specs     => [
            -section => Extensions => [
                -text    => "Just extensions",
                -section => TestExt => [
                    -text      => "Test extension",
                    -modprefix => 'Foswiki::Extension::TestExt',
                    -expert,
                    'ANewKey.NewSubKey' => [
                        Valid => [ -type => 'BOOLEAN', ],
                        Text  => [ -type => 'STRING', ],
                    ],
                    'Extensions.TestExt' => [
                        Sample => [ -type => 'NUMBER', ],
                        StrKey => [ -type => 'STRING(32)', ],
                    ],
                ],
                -section => SampleExt => [
                    -text                  => "Sample extension",
                    -modprefix             => 'Foswiki::Extension::SampleExt',
                    'Extensions.SampleExt' => [
                        Option => [
                            -type    => 'BOOLEAN',
                            -default => 0,
                        ],
                        Setting => SELECT =>
                          [ -expert, -select_from => [qw(one two three)], ],
                        'Sub.Setting.Deep' => [
                            'Opt.K1' => [ -type => 'STRING', ],
                            'Opt.K2' => [ -type => 'NUMBER', ],
                        ],
                    ],
                    -modprefix             => 'Foswiki::Extension::OtherExt',
                    'Extensions.SampleExt' => [
                        Param => [
                            -type    => 'NUMBER',
                            -default => 3.14,
                        ],
                        OneOf => [
                            -type    => 'PERL',
                            -default => { a => 1, b => 2, c => 3, },
                        ],
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

    $this->assert_deep_equals( $expectedData, $data,
        "Config structure mismatch with specs definition" );

    my $sec = $rootSection->sections->[0];
    $this->assert_equals( "Extensions",      $sec->name );
    $this->assert_equals( "Just extensions", $sec->getOpt('text') );
    $this->assert_equals( "TestExt",         $sec->sections->[0]->name );
    $this->assert_equals( "Test extension",
        $sec->sections->[0]->getOpt('text') );
    $this->assert_equals( "SampleExt", $sec->sections->[1]->name );
    $this->assert_equals( "Sample extension",
        $sec->sections->[1]->getOpt('text') );

    my $strKey =
      $dataObj->getKeyObject(qw(Extensions TestExt))->nodes->{StrKey};

    $this->assert_equals( "STRING", $strKey->getOpt('type') );
    $this->assert_equals( 32,       $strKey->getOpt('size') );

    my $expertKey =
      $dataObj->getKeyObject(qw(Extensions SampleExt))->nodes->{Setting};

    $this->assert( $expertKey->getOpt('expert'),
        "Extensions.SampleExt.Setting must have 'expert' option set" );
    $this->assert_equals( "SELECT", $expertKey->getOpt('type') );
    $this->assert_deep_equals( [qw(one two three)],
        $expertKey->getOpt('select_from') );

    return;
}

sub test_specOnLocalData {
    my $this = shift;

    my $data = $this->app->cfg->makeSpecsHash;

    my $dataObj = tied %$data;

    my $cfg = $this->app->cfg;

    my $section = $this->create( 'Foswiki::Config::Section', name => 'Root', );

    $cfg->spec(
        source  => __FILE__,
        dataObj => $dataObj,
        section => $section,
        specs   => [
            -section => Section => [
                'Test1.Key1' => [
                    -type    => 'STRING',
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
        $data
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
"Don't know how to handle key option 'badOption' of key Test.Key \\(defined in section 'Section'\\)",
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
                        -type    => 'STRING',
                        -default => $defStr,
                    ],
                    Key1a => STRING => [ -default => $defStr, ],
                    Key2  => [
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

sub test_expandable {
    my $this = shift;

    my $data = $this->app->cfg->makeSpecsHash;

    my $dataObj = tied %$data;

    my $cfg = $this->app->cfg;

    my $section = $this->create( 'Foswiki::Config::Section', name => 'Root', );

    $cfg->spec(
        source  => __FILE__,
        dataObj => $dataObj,
        section => $section,
        specs   => [
            -expandable => sub {
                return (
                    -section => Section => [
                        'Test1.Key1' => [
                            -type    => 'STRING',
                            -default => 'Default Key1',
                        ],
                        'Test2.Key2' => [
                            -type    => 'NUMBER',
                            -default => 3.1415926,
                        ],
                    ]
                );
            },
        ],
    );

    $this->assert_deep_equals(
        {
            Test1 => { Key1 => 'Default Key1', },
            Test2 => { Key2 => 3.1415926, },
        },
        $data
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
        badKey => 'na}me',
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

sub test_legacyParse {
    my $this = shift;

    my $cfg = $this->app->cfg;
    my ($specFile) =
      ( grep { $_->path =~ /UnitTestContrib/ } @{ $cfg->specFiles->list } );

    my $parser = $cfg->getSpecParser( $specFile->fmt );

    my @specs = $parser->parse($specFile);

    return;
}

sub test_enhancing {
    my $this = shift;

    my $cfg = $this->app->cfg;

    my $defText   = "This is base text.";
    my $addedText = "And some more text\nto be added.";

    $cfg->spec(
        source => __FILE__,
        specs  => [
            -section => "ConfigTests test section" => [
                Test => [
                    KeyForEnhance => STRING =>
                      [ -text => $defText, -default => "default value", ],
                ],
            ],
        ],
    );

    $cfg->spec(
        source => __FILE__,
        specs  => [
            -section => "ConfigTests test section 2" => [
                Test =>
                  [ KeyForEnhance => [ -enhance, -text => $addedText, ], ],
            ],
        ],
    );

    my $keyNode = $cfg->getKeyNode("Test.KeyForEnhance");

    $this->assert_equals( "$defText\n\n$addedText", $keyNode->getOpt('text') );

    try {
        $cfg->spec(
            source => __FILE__,
            specs  => [
                -section => "Completely different section" => [
                    Test => [
                        KeyForEnhance => NUMBER => [
                            -enhance,
                            -text => "And changing the type to NUMBER",
                        ],
                    ],
                ],
            ],
        );
        $this->assert( 0, "Change of a key type must have failed." );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        if ( $e->isa('Foswiki::Exception::Config::BadSpecData') ) {
            $this->assert_matches(
"Key type 'NUMBER' is different from the previously declared 'STRING'",
                $e->text
            );
        }
        else {
            $e->rethrow;
        }
    };

}

sub test_enhanceNonExisting {
    my $this = shift;

    my $cfg = $this->app->cfg;

    try {
        Foswiki::Exception::Fatal->throw(
            text => "Unexpectedly found a key ThisKey.DoesNot.Exists." )
          if exists $cfg->data->{ThisKey}{DoesNot}{Exists};

        $cfg->spec(
            source => __FILE__,
            specs  => [
                -section => "Test enhancing" => [
                    "ThisKey.DoesNot.Exists" =>
                      [ -enhance, -text => "Irrelevant", ],
                ],
            ],
        );

        $this->assert( 0,
            "Must have failed while enhancing a key which doesn't exists" );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        if ( $e->isa('Foswiki::Exception::Config::BadSpecData') ) {
            $this->assert_matches( "Cannot enhance key, no original found",
                $e->text );
        }
        else {
            $e->rethrow;
        }
    };

    my $data    = $cfg->makeSpecsHash;
    my $dataObj = tied %$data;
    my $section = $this->create( 'Foswiki::Config::Section', name => 'Root', );

    # This call must just pass.
    $cfg->spec(
        source  => __FILE__,
        dataObj => $dataObj,
        section => $section,
        specs   => [
            -section => "Test enhancing" => [
                "ThisKey.DoesNot.Exists" =>
                  [ -enhance, -text => "Irrelevant", ],
            ],
        ],
    );
}

sub test_expand {
    my $this = shift;

    my $cfg     = $this->app->cfg;
    my $cfgData = $cfg->data;

    $cfgData->{ExpTest} = {
        Key1 => {
            SubKey   => "{subkey}",
            TestKeys => {
                Test1 => "{test1}",
                Test2 => '{test2 and ${ExpTest.Key1.TestKeys.Test1}}',
            },
            UndefKey => undef,
        },
        Key2 => {
            Key2_1 => '{expanding ${ExpTest.Key1.SubKey}}',
            Key2_2 => '{ref to undef ${ExpTest.Key1.UndefKey}}',
        },

        Exps => {
            Exp1     => 'Expanding ExpTest.Key2.Key2_1: ${ExpTest.Key2.Key2_1}',
            NoExp1   => 'Must not expand ${$}{ExpTest.Key2.Key2_1}',
            NoExp2   => 'Must not expand too: ${ExpTest.Key2.Key2_1${}} -',
            ExpUndef => 'Undef: "${ExpTest.Key2.Key2_2}"',
        },
    };

    my $estr = $cfg->expandStr( str => 'str:${ExpTest.Exps.Exp1}', );
    $this->assert_equals(
        "str:Expanding ExpTest.Key2.Key2_1: {expanding {subkey}}", $estr );

    my @estrs = $cfg->expandStr(
        str => [ 'str1:${ExpTest.Exps.Exp1}', 'str2:${ExpTest.Exps.NoExp1}', ],
    );
    $this->assert_deep_equals(
        [
            "str1:Expanding ExpTest.Key2.Key2_1: {expanding {subkey}}",
            'str2:Must not expand ${ExpTest.Key2.Key2_1}'
        ],
        \@estrs,
        "Multi-valued str key"
    );

    $estr = $cfg->expandStr(
        str => [ 'str1:${ExpTest.Exps.Exp1}', 'str2:${ExpTest.Exps.NoExp1}', ],
    );
    $this->assert_deep_equals(
        [
            "str1:Expanding ExpTest.Key2.Key2_1: {expanding {subkey}}",
            'str2:Must not expand ${ExpTest.Key2.Key2_1}'
        ],
        $estr,
        "Multi-valued str key in scalar context"
    );

    @estrs = $cfg->expandStr(
        str => 'str1:${ExpTest.Exps.Exp1}',
        key => 'ExpTest.Exps.NoExp1',
    );
    $this->assert_deep_equals(
        [
            "str1:Expanding ExpTest.Key2.Key2_1: {expanding {subkey}}",
            'Must not expand ${ExpTest.Key2.Key2_1}'
        ],
        \@estrs,
        "Single-valued str and key"
    );

    @estrs = $cfg->expandStr( key => 'ExpTest.Exps.NoExp2', );
    $this->assert_deep_equals(
        ['Must not expand too: ${ExpTest.Key2.Key2_1} -'],
        \@estrs, "Quoted finishing } must prevent expanding" );

    @estrs =
      $cfg->expandStr( key => [ 'ExpTest.Exps.Exp1', 'ExpTest.Exps.NoExp1', ],
      );
    $this->assert_deep_equals(
        [
            "Expanding ExpTest.Key2.Key2_1: {expanding {subkey}}",
            'Must not expand ${ExpTest.Key2.Key2_1}'
        ],
        \@estrs,
        "Multi-valued key"
    );

    $estr = $cfg->expandStr( key => 'ExpTest.Exps.Exp1' );
    $this->assert_equals( "Expanding ExpTest.Key2.Key2_1: {expanding {subkey}}",
        $estr );

    $estr = $cfg->expandStr( key => 'ExpTest.Exps.NoExp1' );
    $this->assert_equals( 'Must not expand ${ExpTest.Key2.Key2_1}', $estr );

    $estr =
      $cfg->expandStr( key => 'ExpTest.Exps.ExpUndef', undef => '*undef*', );
    $this->assert_equals( 'Undef: "{ref to undef *undef*}"', $estr );

    $estr = $cfg->expandStr( key => 'ExpTest.Exps.ExpUndef', undef => undef, );
    $this->assert_equals( undef, $estr );

    try {
        $estr =
          $cfg->expandStr( key => 'ExpTest.Exps.ExpUndef', undefFail => 1, );
        Foswiki::Exception::Fatal->throw(
            text => "Expansion of an undef value must have failed" );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        $this->assert_matches(
qr/Failed to expand string '.*?': key ExpTest.Key1.UndefKey value is undefined/,
            $e->text
        );
    };
}

sub test_expandAll {
    my $this = shift;

    my $data = {
        IntKey  => 0,
        SomeVal => "!!!",
        Undef   => undef,
        List    => [
            'This is with IntKey=${IntKey}.',
            {
                A => 'A complex structure${SomeVal}',
                U => 'With ${Undef} value',
            },
        ],
    };

    $this->app->cfg->expandAll( data => $data, );

    $this->assert_deep_equals(
        {
            'IntKey' => 0,
            'List'   => [
                'This is with IntKey=0.',
                {
                    'A' => 'A complex structure!!!',
                    'U' => 'With undef value'
                }
            ],
            'Undef'   => undef,
            'SomeVal' => '!!!'
        },
        $data,
        "Expanded structure doesn't match"
    );
}

sub test_ReadWriteLSC {
    my $this = shift;

    $this->app->cfg->data->{ThisKey}{Is}{Not}{From}{Specs} =
      "But we will have it in the LSC";
    $this->app->cfg->data->{Extensions}{DBConfigExtension}{Connection}{Table} =
      "LSC_TEST";

    my $lscFile = "./TestLocalSite.cfg";
    $this->app->cfg->writeLSC( lscFile => $lscFile, );
    my %data;
    $this->app->cfg->readLSC( lscFile => $lscFile, data => \%data, );

    #unlink $lscFile;
    return;
}

1;
