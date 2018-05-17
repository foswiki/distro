# Tests for Foswiki::Class functionality.

package ClassTests;

use Try::Tiny;

use Foswiki::Class -types;
extends qw<Unit::TestCase>;

sub _unexpectedExceptionMsg {
    my $this  = shift;
    my $excpt = shift;
    return
        "Unexpected exception of type "
      . ( ref($excpt) // 'SCALAR' ) . ": "
      . $excpt;
}

sub test_hasWithAssertOption {
    my $this = shift;

    local $Foswiki::Class::HAS_WITH_ASSERT = 1;

    $this->compilePackage(
        "__FCT::HasClassDebug",
        <<SHC
use Foswiki::Class -types;
extends qw<Foswiki::Object>;

has attr => (
    is => 'rw',
    assert => Num,
);

has [qw<a1 a2 a3>] => (
    is => 'rw',
    assert => Int,
);
SHC
    );

    my $obj = __FCT::HasClassDebug->new;

    foreach my $attr (qw<attr a1 a2 a3>) {
        try {
            $obj->$attr("abc");
            $this->assert( 0,
                "Must have failed due to type mismatch (attribute $attr)" );
        }
        catch {
            $this->assert( TypeException->check($_),
                $this->_unexpectedExceptionMsg($_) . " (attribute $attr)" );
        };
    }
}

sub test_hasWithoutAssertOption {
    my $this = shift;

    local $Foswiki::Class::HAS_WITH_ASSERT = 0;

    $this->compilePackage(
        "__FCT::HasClassNoDebug",
        <<SHC
use Foswiki::Class -types;
extends qw<Foswiki::Object>;

has attr => (
    is => 'rw',
    assert => Num,
);
SHC
    );

    my $obj = __FCT::HasClassNoDebug->new;

    try {
        $obj->attr("abc");
    }
    catch {
        $this->assert( !TypeException->check($_),
            "Type check failed though it should have passed" );
        $this->assert( $_, $this->_unexpectedExceptionMsg($_) );
    };
}

1;
