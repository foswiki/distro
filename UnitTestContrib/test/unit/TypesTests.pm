# Tests for Foswiki::Types

package TypesTests;

use Assert;
use Try::Tiny;

use Foswiki::Class;
extends qw<FoswikiTestCase>;

sub test_ClassOption {
    my $this = shift;

    my $rc;

    $rc = eval <<TYPEDCLASS;
package __FCT::Typed;

use Foswiki::Class -types;
extends qw<Foswiki::Object>;

has attr => (
    is => 'rw',
    isa => Str,  
);

1;
TYPEDCLASS

    $this->assert( !$@, "Failed to import types into a test class: $@" );
    $this->assert( $rc, "Class code did not compile correctly" );

    my $obj = __FCT::Typed->new;

    try {
        $obj->attr(undef);
        $this->assert( 0,
            "Setting attribute must have raised typeee constraint exception" );
    }
    catch {
        $this->assert( $_->isa('Error::TypeTiny::Assertion'),
                "Invalid exception, expected Error::TypeTiny::Assertion, got "
              . ref($_)
              . ":\n{{{"
              . $_
              . "}}}" );
        $this->assert_matches( qr/Undef did not pass type constraint "Str"/,
            $_, "" );
    };

    # This will fail upon compile-tyime.
    $rc = eval <<UNTYPEDCLASS;
package __FCT::UnTypedClass;

use Foswiki::Class;
extends qw<Foswiki::Object>;

has attr => (
    is => 'rw',
    isa => Str,
);

1;
UNTYPEDCLASS

    $this->assert( !$rc, "Class compilation must have failed" );
    $this->assert_matches(
        qr/Bareword "Str" not allowed while "strict subs" in use/, $@ );
}

sub test_AnyOf {
    my $this = shift;

    my $rc = eval <<ANYCLASS;
package __FCT::AnyClass;

use Foswiki::Class -types;
extends qw<Foswiki::Object>;

has multiAttr => (
    is => 'rw',
    isa => AnyOf[Num, HashRef, InstanceOf['Foswiki::Object'], ],
);

1;
ANYCLASS

    $this->assert( $rc, "Class compilation failed: " . $@ );

    my $obj = __FCT::AnyClass->new;

    my $type;
    try {
        my %typeVals = (
            Num        => 3.1415926,
            HashRef    => { e => 2.71828, },
            InstanceOf => $obj,
        );

        foreach my $t ( keys %typeVals ) {
            $obj->multiAttr( $typeVals{ $type = $t } );
        }
    }
    catch {
        $this->assert( 0, "Unexpected failure on a valid type $type" );
    };

    try {
        $obj->multiAttr(undef);
    }
    catch {
        $this->assert(
            UNIVERSAL::isa( $_, "Error::TypeTiny::Assertion" ),
            "Bad exception class, excpected Error::TypeTiny::Assertion"
        );
        $this->assert_matches( qr/Undef did not pass type constraint "AnyOf\[/,
            $_->message );
    };
}

sub test_AllOf {
    my $this = shift;

    eval <<TSTROLE;
package __FCT::TstRole;

use Foswiki::Role;

TSTROLE

    eval <<TSTCLASS1;
package __FCT::TstClass1;

use Foswiki::Class;
extends qw<Foswiki::Object>;
with qw<__FCT::TstRole>;

sub mandatory {
    my \$this = shift;
    return 3.1415926;
}
TSTCLASS1

    eval <<TSTCLASS2;
package __FCT::TstClass2;

use Foswiki::Class;
extends qw<Foswiki::Object>;
with qw<__FCT::TstRole>;

TSTCLASS2

    eval <<TSTCLASS3;
package __FCT::TstClass3;

use Foswiki::Class;
extends qw<Foswiki::Object>;

sub mandatory {
    my \$this = shift;
    return 3.1415926;
}

TSTCLASS3

    my $rc = eval <<ALLOFCLASS;
package __FCT::AllOfClass;

use Foswiki::Class -types;
extends qw<Foswiki::Object>;

has objRef => (
    is => 'rw',
    isa => AllOf[
            InstanceOf['Foswiki::Object'],
            ConsumerOf['__FCT::TstRole'],
            HasMethods['mandatory']
    ],
);

1;
ALLOFCLASS

    $this->assert( $rc, "Compilation of test class failed: " . $@ );

    my $obj = __FCT::AllOfClass->new;

    try {
        $obj->objRef( __FCT::TstClass1->new );
    }
    catch {
        $this->assert( 0, "Unexpected failure on a valid object: " . $_ );
    };

    my %badClasses = (
        '__FCT::TstClass2' =>
qr/did not pass type constraint "AllOf\[.*The reference cannot "mandatory"/s,
        '__FCT::TstClass3' =>
qr/did not pass type constraint "AllOf\[.*The reference .*doesn't __FCT::TstRole/s,
    );
    foreach my $class ( keys %badClasses ) {

        try {
            $obj->objRef( $class->new );
            $this->assert( 0, "$class erroneously passed type constraint" );
        }
        catch {
            $this->assert(
                UNIVERSAL::isa( $_, "Error::TypeTiny::Assertion" ),
                "Bad exception class, excpected Error::TypeTiny::Assertion"
            );
            $this->assert_matches( $badClasses{$class}, $_ );
        };
    }

}

1;
