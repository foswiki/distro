# Tests for the Reader class of Foswiki::Tables, which generates a table model.
package TableReaderTests;

use strict;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

sub skip {
    my ( $this, $test ) = @_;

    return $this->check_dependency('Foswiki,<,1.2')
      ? 'Foswiki 1.1 has no Foswiki::Tables'
      : undef;
}

sub test_reader {
    my $this = shift;
    require Foswiki::Tables::Reader;
    my $in = <<INPUT;
| A | B |
%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| C | D |

| E | F |
INPUT
    $this->assert( !$@, $@ );
    my $r = Foswiki::Tables::Reader->new();
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $meta->text($in);
    my $result = $r->parse( $meta->text, $meta );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID() . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
LL %TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
TABLE_0:
%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| A | B |
| C | D |
LL 
TABLE_1:
| E | F |
EXPECTED
}

sub test_reader_pathological {
    my $this = shift;
    require Foswiki::Tables::Reader;
    my $in = <<INPUT;
rubbish%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%junk
| A | B |
tripe%TABLE%garbage
tommyrot
INPUT
    $this->assert( !$@, $@ );
    my $r = Foswiki::Tables::Reader->new();
    my $meta =
      Foswiki::Meta->load( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $meta->text($in);
    my $result = $r->parse( $meta->text, $meta );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID() . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }

    # SMELL: it would be better if we didn't reorder tripe and garbage
    # before the first table, but it's a limitation of the parser that
    # the early_line handler can't rewrite the input stream. The best we
    # can do is make sure nothing is lost.
    $this->assert_equals( <<'EXPECTED', $data );
LL rubbish%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%junk
TABLE_0:
%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE%
| A | B |
LL tripe%TABLE%garbage
LL tommyrot
EXPECTED
}

1;
