# Example test case; use this as a basis to build your own

package FeatureSetTests;

use Foswiki;
use Foswiki::FeatureSet qw(:all);
use Try::Tiny;
use Data::Dumper;

use Foswiki::Class;
extends qw( FoswikiTestCase );

sub str2ver(@);
sub ver2str($);

has tst_version => (
    is     => 'rw',
    coerce => sub { ( str2ver $_[0] )[0] },
);
has tst_verKey => ( is => 'rw', );
has tst_callProfile => (
    is      => 'rw',
    clearer => 1,
);
has ver2features => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);
has tst_namespaces => (
    is      => 'rw',
    clearer => 1,
    lazy    => 1,
    default => sub { [undef] },
);
has comply_map => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);
has context_map => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);
has _preserveFoswikiVersion => ( is => 'rw', );

my @group_versions = str2ver qw(1.1 2.1 2.1.2 2.99 2.99.1 3.0 3.2 3.99 4.0 4.1);

my %group_features = (
    FEATURE_00 => [ undef, undef, undef, -active => [@group_versions], ],
    FEATURE_01 => [ undef, undef, 2.99,  -active => [qw(1.1 2.1 2.1.2)], ],
    FEATURE_02 => [
        undef, 2.0, 2.99,
        -active     => [qw(1.1 2.1 2.1.2)],
        -deprecated => [qw(2.1 2.1.2)],
    ],
    FEATURE_03 => [
        2.99, 3.99, 4.0,
        -active     => [qw(2.99 2.99.1 3.0 3.2 3.99)],
        -deprecated => [qw(3.99)],
    ],
    FEATURE_04 => [
        2.0, 2.99, undef,
        -active     => [qw(2.1 2.1.2 2.99 2.99.1 3.0 3.2 3.99 4.0 4.1)],
        -deprecated => [qw(2.99 2.99.1 3.0 3.2 3.99 4.0 4.1)],
    ],
    FEATURE_05 => [
        2.0, undef, undef,
        -active => [qw(2.1 2.1.2 2.99 2.99.1 3.0 3.2 3.99 4.0 4.1)],
    ],
    FEATURE_06 =>
      [ 2.0, undef, 4.0, -active => [qw(2.1 2.1.2 2.99 2.99.1 3.0 3.2 3.99)], ],
    FEATURE_07 => [
        undef, 3.2, undef,
        -active     => [@group_versions],
        -deprecated => [qw(3.2 3.99 4.0 4.1)],
    ],
    FEATURE_08 => [ 5.0,   undef, undef, ],
    FEATURE_09 => [ undef, undef, 1.0, ],
    FEATURE_10 => [
        undef, 1.0, undef,
        -active     => [@group_versions],
        -deprecated => [@group_versions],
    ],
);

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    $this->clear_tst_namespaces;
    $this->clear_tst_callProfile;
    $this->clear_comply_map;
    $this->clear_context_map;

    # Some tests will play with this variable. We shall restore it in tear_down.
    $this->_preserveFoswikiVersion($Foswiki::VERSION);

    # For test purposes we override what is declared by an application.
    cleanupFeatures;

    return;
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    $Foswiki::VERSION = $this->_preserveFoswikiVersion;

    # Always do this, and always do it last
    $orig->($this);

    return;
};

sub str2ver (@) {
    my @v = map {
        $_
          ? ( UNIVERSAL::isa( $_, 'version' ) ? $_ : version->declare($_) )
          ->normal
          : undef
    } @_;
    return ( wantarray ? @v : ( @v > 1 ? \@v : $v[0] ) );
}

# Returns version string in normalized form.
sub ver2str ($) {
    my $version = shift;

    $version = version->declare($version)
      unless UNIVERSAL::isa( $version, 'version' );

    return $version->normal;
}

sub _isTrue {
    return $_[0] ? 1 : 0;
}

sub fixture_groups {
    my $this = shift;

    my @subList;
    foreach my $ver (@group_versions) {
        ( my $verKey = $ver ) =~ s/\./_/g;
        my $subName = "ver_$verKey";

        my $line_pragma = "#line " . ( __LINE__ + 3 ) . ' "' . __FILE__ . '"';
        eval <<SUB;
$line_pragma
sub $subName {
    my \$this = shift;
    \$this->tst_version( q/$ver/ );
    \$this->tst_verKey( "$verKey" );
}
SUB
        Foswiki::Exception::Fatal->throw(
            text => "Cannot generate sub $subName: $@" )
          if $@;

        push @subList, $subName;
    }

    return [@subList], [qw(callProfileWithVersion callProfileWithoutVersion)],
      [qw(NSDefault NSSingle NSBoth)];
}

sub callProfile {
    my $this    = shift;
    my %profile = @_;

    $this->tst_callProfile( \%profile );
}

sub callProfileWithVersion {
    my $this = shift;

    $this->callProfile( -version => $this->tst_version, );
}

sub callProfileWithoutVersion {
    my $this = shift;

    $Foswiki::VERSION = str2ver $this->tst_version;

    $this->callProfile;
}

sub prepare_featureset {
    my $this = shift;

    foreach my $ns ( @{ $this->tst_namespaces } ) {
        my @options;
        my $fPrefix = '';
        if ($ns) {
            push @options, -namespace => $ns;
            $fPrefix = $ns . "_";
        }
        my %regFeatures;
        foreach my $f ( keys %group_features ) {
            my $fName = "$fPrefix$f";
            $regFeatures{$fName} = [ @{ $group_features{$f} } ];
            @{ $regFeatures{$fName} }[ 0 .. 2 ] =
              str2ver @{ $regFeatures{$fName} }[ 0 .. 2 ];

            my $i = 3;
            my ( @map_options, %active_map );
            while ( $i < @{ $regFeatures{$fName} } ) {
                if ( $regFeatures{$fName}[ $i++ ] =~
                    /^(-(?:active|deprecated))$/ )
                {
                    my $status    = $1;
                    my $statusKey = "${status}_map";

                    $regFeatures{$fName}[$i] =
                      [ str2ver @{ $regFeatures{$fName}[$i] } ];
                    my %status_map =
                      map { ver2str($_) => 1 } @{ $regFeatures{$fName}[$i] };
                    push @map_options, $statusKey, \%status_map;

                    # Record this feature for all versions it comply to.
                    if ( $status eq '-active' ) {
                        %active_map = %status_map;
                    }
                }
                $i++;
            }
            push @{ $regFeatures{$fName} }, @map_options;

            # Fill in comply_map to define correspondance between versions and
            # features complying to them.
            # Note that if there no -active defined for a feature it is expected
            # to not comply to any version.
            foreach my $v (@group_versions) {
                my $vstr = ver2str $v;
                $this->comply_map->{ Foswiki::FeatureSet::_nsFromParam(
                        -namespace => $ns ) }{
                    $active_map{$vstr}
                    ? "yes"
                    : "no"
                        }{$vstr}{$fName} = 1;

                # Set context_map too.
                if ( $active_map{$vstr} ) {
                    my $contextName =
                      ( $ns ? "$ns\::" : "" ) . 'SUPPORTS_' . $fName;
                    $this->context_map->{$vstr}{$contextName} = 1;
                }
            }
        }
        features_provided @options, %regFeatures;
    }
}

sub NSDefault {
    my $this = shift;

    $this->clear_tst_namespaces;

    $this->prepare_featureset;
}

sub NSSingle {
    my $this = shift;

    $this->tst_namespaces( ['Single'] );
    $this->prepare_featureset;
}

sub NSBoth {
    my $this = shift;

    $this->clear_tst_namespaces;
    push @{ $this->tst_namespaces }, 'Secondary';
    $this->prepare_featureset;
}

sub _registerStandardCORE {
    my $this = shift;

    features_provided
      TWIKI_COMPATIBILITY => [ str2ver( undef, 2.99, 3.0 ) ],
      PARA_INDENT => [ undef, undef, undef, -desc => "Paragraph indentation", ],
      MOO         => [
        str2ver( 2.99, undef, undef ),
        -desc     => "OO with Moo",
        -proposal => 'Development.ImproveOOModel',
        -doc      => 'Documentation.Foswiki3CodingStyle',
      ],
      EXTENSIONS_1 => [
        str2ver( undef, undef, 2.99 ),
        -desc => "Old-style plguins and contribs",
      ],
      EXTENSIONS_1_3 => [
        str2ver( 2.99, 2.99, 4.0 ),
        -desc => "Old-style plguins and contribs adapted for Foswiki 3.0",
      ],
      EXTENSIONS_3 => [
        str2ver( 2.99, undef, undef ),
        -desc => "New and powerful OO extensions",
        -doc  => 'Foswiki::ExtManager'
      ],
      ;
}

sub test_register {
    my $this = shift;

    $this->_registerStandardCORE;

    my @fsList = getNSFeatures;

    $this->assert_deep_equals(
        [
            qw(EXTENSIONS_1 EXTENSIONS_1_3 EXTENSIONS_3 MOO PARA_INDENT TWIKI_COMPATIBILITY)
        ],
        [ sort @fsList ],
    );

    return;
}

sub test_feature_data {
    my $this = shift;

    $this->_registerStandardCORE;

    my ( $desc, $doc, $prop ) = (
        "This is description",
        "Documentation.IsThis",    # Yoda-style. ;)
        "Development.FeatureSet",
    );

    features_provided
      FEATURE_WITH_META => [
        undef, undef, undef,
        -desc          => $desc,
        -proposal      => $prop,
        -documentation => $doc,
      ],
      -namespace        => 'Test::NS',
      FEATURE_WITH_META => [
        str2ver( 0.1, 0.2, 0.3 ),
        -desc => $desc,
        -doc  => $doc,
      ];

    my $meta = featureMeta('FEATURE_WITH_META');

    $this->assert_deep_equals(
        {
            -description   => $desc,
            -proposal      => $prop,
            -documentation => $doc,
        },
        $meta,
        "Incorrect meta for FEATURE_WITH_META from the default namespace"
    );

    my $versions = featureVersions('FEATURE_WITH_META');

    $this->assert_deep_equals(
        [ undef, undef, undef ],
        $versions,
"Expected versions don't match those returned for FEATURE_WITH_META from the default namespace",
    );

    $meta = featureMeta( 'FEATURE_WITH_META', -namespace => 'Test::NS' );

    $this->assert_deep_equals(
        {
            -description   => $desc,
            -documentation => $doc,
        },
        $meta,
        "Incorrect meta for FEATURE_WITH_META from Test::NS namespace"
    );

    $versions =
      featureVersions( 'FEATURE_WITH_META', -namespace => 'Test::NS' );

    $this->assert_deep_equals(
        [ str2ver 0.1, 0.2, 0.3 ],
        $versions,
"Expected versions don't match those returned for FEATURE_WITH_META from Test::NS namespace",
    );
}

sub test_namespace_features {
    my $this = shift;

    $this->_registerStandardCORE;

    features_provided
      -namespace => 'Test::NS1',
      FEATURE1   => [ str2ver( 0.1, 0.2, 0.3 ), ],
      FEATURE2   => [ str2ver( 0.4, 0.5, 0.6 ), ],
      #
      -namespace => 'Test::NS2',
      FEATURE3   => [ undef, undef, undef, ],
      FEATURE4   => [ str2ver( 1.1, 1.2, 1.3 ), ],
      #
      -namespace   => undef,
      TEST_FEATURE => [ undef, undef, undef ],
      ;

    my @nsList = getFSNamespaces;

    $this->assert_deep_equals( [qw(Test::NS1 Test::NS2)], [ sort @nsList ], );
}

sub test_badVersion {
    my $this = shift;

    try {
        features_provided BAD_FEATURE => [ '1.a', undef, undef, ];
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        $this->assert(
            $e->isa('Foswiki::Exception::Fatal'),
            "Unexpected exception " . ref($e) . ":\n" . $e
        );
        $this->assert_matches( "Invalid version string", $e->text );
    };
}

sub test_duplicate_feature {
    my $this = shift;

    $this->prepare_featureset;

    try {
        features_provided
          FEATURE_00 => [ undef, undef, undef ],
          ;
        $this->assert( 0,
"FEATURE_00 has been successfully registered eventhough it's a duplicate."
        );
    }
    catch {
        $this->assert( $_->isa('Foswiki::Exception::Fatal'),
            "Unknown exception " . $_ );
        $this->assert_matches( "Duplicated feature FEATURE_00 detected", $_ );
    };

}

sub test_duplicate_NS_feature {
    my $this = shift;

    $this->tst_namespaces( ['NS::Dup'] );
    $this->prepare_featureset;

    # Will pass because prepare_featureset will register in NS::Dup only.
    features_provided
      FEATURE_00 => [ undef, undef, undef ],
      ;

    try {
        features_provided
          -namespace           => 'NS::Dup',
          'NS::Dup_FEATURE_00' => [ undef, undef, undef ],
          ;
        $this->assert( 0,
"FEATURE_00 has been successfully registered eventhough it's a duplicate."
        );
    }
    catch {
        $this->assert( $_->isa('Foswiki::Exception::Fatal'),
            "Unknown exception " . $_ );
        $this->assert_matches( "Duplicated feature NS::Dup_FEATURE_00 detected",
            $_ );
    };

}

sub check_ver_status {
    my $this    = shift;
    my %profile = @_;

    my $vTriplet = [ str2ver @{ $profile{triplet} } ];

    my $succeed = $profile{sub}->( $vTriplet, $profile{version} );
    $succeed = !$succeed if $profile{mustFail};
    $this->assert( $succeed, $profile{message} );
}

sub test_isActiveVersion {
    my $this = shift;

    my $activeVer = version->declare(2.1);
    my %profile   = (
        version => $activeVer,
        sub     => \&Foswiki::FeatureSet::isActiveVersion,
    );
    $this->check_ver_status(
        triplet => [ undef, undef, undef ],
        %profile,
        message => "All undef version triplet must not fail",
    );
    $this->check_ver_status(
        triplet => [ 1.1, undef, undef ],
        %profile,
        message => "Active since 1.1 must not fail for " . $activeVer,
    );
    $this->check_ver_status(
        triplet => [ 2.1, undef, undef ],
        %profile,
        message => "Active since 2.1 must not fail for " . $activeVer,
    );
    $this->check_ver_status(
        triplet => [ 2.2, undef, undef ],
        %profile,
        mustFail => 1,
        message  => "Active since 2.2 must fail for " . $activeVer,
    );
    $this->check_ver_status(
        triplet => [ undef, undef, 2.1 ],
        %profile,
        mustFail => 1,
        message  => "Active until 2.1 must fail for " . $activeVer,
    );
    $this->check_ver_status(
        triplet => [ undef, undef, 3.0 ],
        %profile,
        message => "Active until 3.0 must not fail for " . $activeVer,
    );
    $this->check_ver_status(
        triplet => [ undef, undef, 2.0 ],
        %profile,
        mustFail => 1,
        message  => "Active until 2.0 must fail for " . $activeVer,
    );
    $this->check_ver_status(
        triplet => [ 1.1, undef, 3.0 ],
        %profile,
        message => "Active from 1.1 until 3.0 must not fail for " . $activeVer,
    );
    $this->check_ver_status(
        triplet => [ 2.2, undef, 3.0 ],
        %profile,
        mustFail => 1,
        message  => "Active from 2.2 until 3.0 must fail for " . $activeVer,
    );
    $this->check_ver_status(
        triplet => [ 1.1, undef, 2.0 ],
        %profile,
        mustFail => 1,
        message  => "Active from 1.1 until 2.0 must fail for " . $activeVer,
    );
}

sub test_isDeprecatedVersion {
    my $this = shift;

    my $activeVer = version->declare(2.1);
    my %profile   = (
        version => $activeVer,
        sub     => \&Foswiki::FeatureSet::isDeprecatedVersion,
    );
    $this->check_ver_status(
        %profile,
        triplet  => [ undef, undef, undef ],
        mustFail => 1,
        message => "All undef versions must fail – no deprecation defined.",
    );
    $this->check_ver_status(
        %profile,
        triplet  => [ undef, 2.99, undef ],
        mustFail => 1,
        message => "Deprecation since 2.99 must fail for " . $activeVer,
    );
    $this->check_ver_status(
        %profile,
        triplet => [ undef, 2.0, undef ],
        message => "Deprecation since 2.0 must not fail for " . $activeVer,
    );
    $this->check_ver_status(
        %profile,
        triplet => [ undef, 2.0, 3.0 ],
        message => "Deprecation since 2.0 until 3.0 must not fail for "
          . $activeVer,
    );
    $this->check_ver_status(
        %profile,
        triplet  => [ undef, 1.99, 2.0 ],
        mustFail => 1,
        message => "Deprecation since 1.99 until 2.0 must fail for "
          . $activeVer,
    );
    $this->check_ver_status(
        %profile,
        triplet  => [ undef, 2.0, 2.1 ],
        mustFail => 1,
        message  => "Deprecation since 2.0 until 2.1 must fail for "
          . $activeVer,
    );
    $activeVer = version->declare(2.99.1);
    $profile{version} = $activeVer;
    $this->check_ver_status(
        %profile,
        triplet  => [ undef, 2.0, 2.99 ],
        mustFail => 1,
        message => "Deprecation since 2.0 until 2.99 must fail for "
          . $activeVer,
    );
}

sub check_fs_status {
    my $this    = shift;
    my %profile = @_;

    foreach my $ns ( @{ $this->tst_namespaces } ) {
        my %fs_map =
          map { $_ => 1 }
          $profile{sub}
          ->( $this->tst_callProfile->{-version}, -namespace => $ns, );

        my $ver = ver2str( $this->tst_version );
        my @allFeatures = getNSFeatures( -namespace => $ns );

        foreach my $feature (@allFeatures) {
            my $expected_status =
              featureMeta( $feature, -namespace => $ns )
              ->{"-$profile{status}_map"}{$ver};
            $this->assert(
                _isTrue( $fs_map{$feature} ) == _isTrue($expected_status),
                "Feature "
                  . $feature . " is "
                  . ( $expected_status ? "" : "not " )
                  . "expected to be "
                  . $profile{status}
            );
        }
    }

}

sub verify_active {
    my $this = shift;

    $this->check_fs_status(
        sub    => \&Foswiki::FeatureSet::activeFeatures,
        status => 'active',
    );
}

sub verify_deprecated {
    my $this = shift;

    $this->check_fs_status(
        sub    => \&Foswiki::FeatureSet::deprecatedFeatures,
        status => 'deprecated',
    );
}

sub verify_comply {
    my $this = shift;

    my $vstr = ver2str $this->tst_version;

    foreach my $ns ( keys %{ $this->comply_map } ) {
        my $compNsMap      = $this->comply_map->{$ns};
        my @allComplyFs    = keys %{ $compNsMap->{yes}{$vstr} };
        my @allNonComplyFs = keys %{ $compNsMap->{no}{$vstr} };

        my $complyCnt = int( @allComplyFs / 3 );

        my @comply = @allComplyFs[ 0 .. $complyCnt ];
        my @noncomply = ( @comply, $allNonComplyFs[0] );

        $this->assert(
            featuresComply(
                %{ $this->tst_callProfile },
                -features  => \@comply,
                -namespace => $ns,
            ),
            "The set ("
              . join( ", ", @comply )
              . ") must comply to version "
              . $this->tst_version
        );
        $this->assert(
            !featuresComply(
                %{ $this->tst_callProfile },
                -features  => \@noncomply,
                -namespace => $ns,
            ),
            "The set ("
              . join( ", ", @noncomply )
              . ") must not comply to version "
              . $this->tst_version
        );
        $this->assert(
            !featuresComply(
                %{ $this->tst_callProfile },
                -features  => [ @comply, 'THIS_FEATURE_DOESNT_EXISTS' ],
                -namespace => $ns,
            ),
            "A set with non-existing feature must not comply to version "
              . $this->tst_version
        );
    }
}

sub verify_fs2context {
    my $this = shift;

    my %context = features2Context( %{ $this->tst_callProfile } );

    $this->assert_deep_equals(
        $this->context_map->{ ver2str $this->tst_version },
        \%context, "Generated context doesn't match expected" );
}

1;
