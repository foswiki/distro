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

sub test_Item13352_unbalanced_verbatim {
    my $this = shift;
    my $in   = <<INPUT;
   * Set ENDCOLOR = </span></verbatim>
%RED%Some red text%ENDCOLOR%

| A | B |
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| A | B |

| A | B |
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
LL    * Set ENDCOLOR = </span></verbatim>
LL %RED%Some red text%ENDCOLOR%
LL 
TABLE_0:
| A | B |
TABLE_1:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
| A | B |
LL 
TABLE_2:
| A | B |
EXPECTED
}

sub test_FUCK {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<'INPUT';
The edit button is placed above the table and editing fails with this example. 

%EDITTABLE{format="|text,10|text,10|text,%ENCODE{"3"}%|text,15|text,15|text,3|text,3|text,3|text,3|text,3|text,3|text,10|label,0,$percntCALC{$quot$EVAL($T(R$ROW():C6) * $T(R$ROW():C$COLUMN(-1)))$quot}$percnt|text,5|" }%
%TABLE{columnwidths="%ENCODE{"80"}%,80,50,110,150,50,50,50,50,50,70,70,50" dataalign="left,left,center,left,left,center,center,center,center,center,center,right,right,center" headeralign="center" headerrows="1" footerrows="1" headerislabel="on"}%
| *Project* | *Customer* | *Pass* | *Type* | *Purpose* | *Qty* | *Radios* | *Controllers* | *Hubs* | *Tuners* | *Hybrid* | *Unit Cost (USD)* | *Total Cost (USD)* | *When (Q)* |
| Project A | Engineering | A | PK2 | Eng Test | 2 | 4 | | 2 | 2 | | 6214 | %CALC{"$EVAL($T(R$ROW():C6) * $T(R$ROW():C$COLUMN(-1)))"}% | Q1 |
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
LL 
LL 
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |"
fool="cap"
}%
%TABLE{columnwidths="10,20"}%
| A | B |
EXPECTED
}

sub test_EDITTABLETABLE_table_13715 {
    my $this = shift;

    require Foswiki::Plugins::EditRowPlugin::TableParser;
    $this->assert( !$@, $@ );
    my $parser = Foswiki::Plugins::EditRowPlugin::TableParser->new();

    my $in = <<'INPUT';
%EDITTABLE{format="|text,10|text,10|text,%ENCODE{"3"}%|text,15|text,15|text,3|text,3|text,3|text,3|text,3|text,3|text,10|label,0,$percntCALC{$quot$EVAL($T(R$ROW():C6) * $T(R$ROW():C$COLUMN(-1)))$quot}$percnt|text,5|" }%%TABLE{columnwidths="%ENCODE{"80"}%,80,50,110,150,50,50,50,50,50,70,70,50" dataalign="left,left,center,left,left,center,center,center,center,center,center,right,right,center" headeralign="center" headerrows="1" footerrows="1" headerislabel="on"}%
| *Project* | *Customer* | *Pass* | *Type* | *Purpose* | *Qty* | *Radios* | *Controllers* | *Hubs* | *Tuners* | *Hybrid* | *Unit Cost (USD)* | *Total Cost (USD)* | *When (Q)* |
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
LL %EDITTABLE{ format="| text, 5, init | text, 20, init |" fool="cap"}%%TABLE{columnwidths="10,20"}%
TABLE_0:
%EDITTABLE{ format="| text, 5, init | text, 20, init |" fool="cap"}%
%TABLE{columnwidths="10,20"}%
| A | B |
EXPECTED
}

1;
