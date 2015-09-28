# See bottom of file for license and copyright information
package Parser;

use strict;
use warnings;
use FoswikiFnTestCase;
our @ISA = 'FoswikiFnTestCase';

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub loadExtraConfig {
    my $this = shift;

    $this->SUPER::loadExtraConfig();
}

sub test_EDITTABLE {
    my $this = shift;
    my $in   = <<INPUT;
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
INPUT
    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
EXPECTED
}

sub test_TABLE_table {
    my $this = shift;
    my $in   = <<INPUT;
%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| naff |
INPUT
    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| naff |
EXPECTED
}

# A %TABLE macro does not auto-create a following table, but it's absorbed
# by the table parser. So we need some way to remember that we had the
# macro, but without a table, so it gets deserialised. Special handling of
# a table with no EDITTABLE would appear to be a solution.
sub test_TABLE {
    my $this = shift;
    my $in   = <<INPUT;
%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
INPUT
    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%TABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
EXPECTED
}

sub test_TABLE_EDITTABLE {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
%TABLE{columnwidths="10,20"}%
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
EXPECTED
}

sub test_EDITTABLE_TABLE {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
EXPECTED
}

sub test_TABLE_EDITTABLE_table {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
%TABLE{columnwidths="10,20"}%
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| A | B |
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
| A | B |
EXPECTED
}

sub test_EDITTABLE_TABLE_table {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
| A | B |
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
| A | B |
EXPECTED
}

sub test_table_EDITTABLE_table_empty_table {
    my $this = shift;
    my $in   = <<INPUT;
| A | B |
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| C | D |

| E | F |
INPUT
    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
| A | B |
TABLE_1:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| C | D |
LL 
TABLE_2:
| E | F |
EXPECTED
}

sub test_table_EDITTABLE_TABLE_table {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
| A | B |
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
| C | D |
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
| A | B |
TABLE_1:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
| C | D |
EXPECTED
}

sub test_TABLEEDITTABLE_table {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
%TABLE{columnwidths="10,20"}%%EDITTABLE{ format="| text, 5, init | text, 20, init |" fool="cap"}%
| A | B |
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |" fool="cap"}%
%TABLE{columnwidths="10,20"}%
| A | B |
EXPECTED
}

sub test_EDITTABLETABLE_table {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
%EDITTABLE{ format="| text, 5, init | text, 20, init |" fool="cap"}%%TABLE{columnwidths="10,20"}%
| A | B |
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |" fool="cap"}%
%TABLE{columnwidths="10,20"}%
| A | B |
EXPECTED
}

sub test_table_empty_TABLE_EDITTABLE_table {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
| A | B |

%TABLE{columnwidths="10,20"}%
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| C | D |
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
| A | B |
LL 
TABLE_1:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
| C | D |
EXPECTED
}

sub test_table_TABLE_table_EDITTABLE_table {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<INPUT;
| A | B |
%TABLE{columnwidths="10,20"}%
| C | D |
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| E | F |
INPUT
    my $result = $parser->parse( $in, $this->{test_topicObject} );

    my $data = '';
    foreach my $r (@$result) {
        if ( ref($r) ) {
            $data .= $r->getID . ":\n" . $r->stringify();
        }
        else {
            $data .= "LL $r\n";
        }
    }
    $this->assert_equals( <<'EXPECTED', $data );
TABLE_0:
%TABLE{columnwidths="10,20"}%
| A | B |
| C | D |
TABLE_1:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| E | F |
EXPECTED
}

1;
