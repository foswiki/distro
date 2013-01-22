package TableParserTests;

use strict;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

sub set_up {
    my $this = shift;
    require Foswiki::Tables::Parser;
    $this->SUPER::set_up();
    $this->{out}      = "";
    $this->{dispatch} = sub {
        my $event = shift;
        $this->$event(@_);
    };
}

sub skip {
    my ( $this, $test ) = @_;

    return $this->check_dependency('Foswiki,<,1.2')
      ? 'Foswiki 1.1 has no Foswiki::Tables'
      : undef;
}

sub early_line {
    my $this = shift;
    if ( $_[0] =~ /EARLY_LINE_TRAP/ ) {
        $this->{out} .= "EL $_[0]\n";
        return 1;
    }
    if ( $_[0] =~ s/EARLY_LINE_EXCISE// ) {
        $this->{out} .= "ELE\n";
    }
    return 0;
}

sub line {
    my $this = shift;
    $this->{out} .= "LL '$_[0]'\n";
}

sub open_table {
    my $this = shift;
    $this->{out} .= "<table>\n";
}

sub close_table {
    my $this = shift;
    $this->{out} .= "</table>\n";
}

sub open_tr {
    my $this = shift;
    $this->{out} .= "<tr pre='$_[0]' post='$_[1]'>\n";
}

sub close_tr {
    my $this = shift;
    $this->{out} .= "</tr>\n";
}

sub td {
    my $this = shift;
    $this->{out} .= "<td pre='$_[0]' post='$_[2]'>$_[1]</td>\n";
}

sub th {
    my $this = shift;
    $this->{out} .= "<th pre='$_[0]' post='$_[2]'>$_[1]</th>\n";
}

sub end_of_input {
    my $this = shift;
    $this->{out} .= "EOI\n";
}

sub test_simple_table {
    my $this = shift;

    my $in = <<IN;
| Simple | Table |
IN
    Foswiki::Tables::Parser::parse( $in, $this->{dispatch} );
    $this->assert_html_equals( <<EXPECTED, $this->{out} );
<table>
<tr pre='' post=''>
<td pre=' ' post=' '>Simple</td>
<td pre=' ' post=' '>Table</td>
</tr>
</table>
EOI
EXPECTED
}

sub test_headers_at_top {
    my $this = shift;

    my $in = <<IN;
| *Simple* | Table |
IN
    Foswiki::Tables::Parser::parse( $in, $this->{dispatch} );
    $this->assert_html_equals( <<EXPECTED, $this->{out} );
<table>
<tr pre='' post=''>
<th pre=' ' post=' '>Simple</th>
<td pre=' ' post=' '>Table</td>
</tr>
</table>
EOI
EXPECTED
}

sub test_cell_align {
    my $this = shift;

    my $in = <<IN;
|   *Simple* | Table   |
| *Dimple*   |   Cable |
|*Wimple* | Mabel|
| *Gimple*|Babel |
|*Horse*|Hair|
IN
    Foswiki::Tables::Parser::parse( $in, $this->{dispatch} );
    $this->assert_html_equals( <<EXPECTED, $this->{out} );
<table>
<tr pre='' post=''>
<th pre='   ' post=' '>Simple</th>
<td pre=' ' post='   '>Table</td>
</tr>
<tr pre='' post=''>
<th pre=' ' post='   '>Dimple</th>
<td pre='   ' post=' '>Cable</td>
</tr>
<tr pre='' post=''>
<th pre='' post=' '>Wimple</th>
<td pre=' ' post=''>Mabel</td>
</tr>
<tr pre='' post=''>
<th pre=' ' post=''>Gimple</th>
<td pre='' post=' '>Babel</td>
</tr>
<tr pre='' post=''>
<th pre='' post=''>Horse</th>
<td pre='' post=''>Hair</td>
</tr>
</table>
EOI
EXPECTED
}

sub test_multiline_table {
    my $this = shift;

    my $in = <<'IN';
| Simple | \
Table |
   |\
 Pimple\
\
 | Fa\
ble |   
IN
    Foswiki::Tables::Parser::parse( $in, $this->{dispatch} );
    $this->assert_html_equals( <<EXPECTED, $this->{out} );
<table>
<tr pre='' post=''>
<td pre=' ' post=' '>Simple</td>
<td pre=' ' post=' '>Table</td>
</tr>
<tr pre='   ' post='   '>
<td pre=' ' post=' '>Pimple</td>
<td pre=' ' post=' '>Fable</td>
</tr>
</table>
EOI
EXPECTED
}

sub test_verbatim_and_literal_blocks {
    my $this = shift;

    my $in = <<'IN';
<verbatim>
| Simple | Table |
</verbatim>
<literal>
| Simple | Table |
</literal>
<verbatim>
| Simple | Table |
</verbatim><verbatim>
| Simple | Table |
</verbatim>
<verbatim></verbatim>
| Simple | Table |
IN
    Foswiki::Tables::Parser::parse( $in, $this->{dispatch} );
    $this->assert_html_equals( <<EXPECTED, $this->{out} );
LL '<verbatim>'
LL '| Simple | Table |'
LL '</verbatim>'
LL '<literal>'
LL '| Simple | Table |'
LL '</literal>'
LL '<verbatim>'
LL '| Simple | Table |'
LL '</verbatim><verbatim>'
LL '| Simple | Table |'
LL '</verbatim>'
LL '<verbatim></verbatim>'
<table>
<tr pre='' post=''>
<td pre=' ' post=' '>Simple</td>
<td pre=' ' post=' '>Table</td>
</tr>
</table>
EOI
EXPECTED
}

sub test_early_line {
    my $this = shift;

    my $in = <<'IN';
Testing testing 1 2 3
Spot EARLY_LINE_TRAP the dog
Hugh EARLY_LINE_EXCISE Pugh
Barney McGrew
IN
    Foswiki::Tables::Parser::parse( $in, $this->{dispatch} );
    $this->assert_html_equals( <<EXPECTED, $this->{out} );
LL 'Testing testing 1 2 3'
EL Spot EARLY_LINE_TRAP the dog
ELE
LL 'Hugh  Pugh'
LL 'Barney McGrew'
EOI
EXPECTED
}

sub test_empty_cells {
    my $this = shift;

    my $in = <<'IN';
|
||
|||
| |
|  |
|   |
IN
    Foswiki::Tables::Parser::parse( $in, $this->{dispatch} );
    $this->assert_html_equals( <<EXPECTED, $this->{out} );
LL '|'
<table>
<tr pre='' post=''>
</tr>
<tr pre='' post=''>
<td pre='' post=''></td>
<td pre='' post=''></td>
</tr>
<tr pre='' post=''>
<td pre='' post=' '> </td>
</tr>
<tr pre='' post=''>
<td pre=' ' post=' '></td>
</tr>
<tr pre='' post=''>
<td pre=' ' post='  '></td>
</tr>
</table>
EOI
EXPECTED
}

sub test_balanced_percent {
    my $this = shift;

    my $in = <<'IN';
| A | B |
%EDITTABLE{ format="| text, 5, init |
 text, 20, init |"
spoon="egg" }%
| A | B |
IN
    Foswiki::Tables::Parser::parse( $in, $this->{dispatch} );
    $this->assert_html_equals( <<EXPECTED, $this->{out} );
<table>
<tr pre='' post=''>
<td pre=' ' post=' '>A</td>
<td pre=' ' post=' '>B</td>
</tr>
</table>
LL '%EDITTABLE{ format="| text, 5, init |
 text, 20, init |"
spoon="egg" }%'
<table>
<tr pre='' post=''>
<td pre=' ' post=' '>A</td>
<td pre=' ' post=' '>B</td>
</tr>
</table>
EOI
EXPECTED
}

1;
