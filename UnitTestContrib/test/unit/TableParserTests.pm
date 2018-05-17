package TableParserTests;

use Foswiki::Class;
extends qw( FoswikiFnTestCase );

has out      => ( is => 'rw', );
has dispatch => ( is => 'rw', );

around set_up => sub {
    my $orig = shift;
    my $this = shift;
    require Foswiki::Tables::Parser;
    $orig->($this);
    $this->out("");
    $this->dispatch(
        sub {
            my $event = shift;
            $this->$event(@_);
        }
    );
};

sub skip {
    my ( $this, $test ) = @_;

    return $this->check_dependency('Foswiki,<,1.2')
      ? 'Foswiki 1.1 has no Foswiki::Tables'
      : undef;
}

sub addToOut {
    my $this = shift;
    my ($text) = @_;
    return $this->out( $this->out . $text );
}

sub early_line {
    my $this = shift;
    if ( $_[0] =~ s/CREATE_A_TABLE// ) {
        $this->addToOut("EL $_[0]\n");
        return 1;
    }
    if ( $_[0] =~ s/NO_TABLE// ) {
        $this->addToOut("ELE\n");
        return -1;
    }
    return 0;
}

sub end_of_input {
    my $this = shift;
    $this->addToOut("EOF\n");
}

sub line {
    my $this = shift;
    $this->addToOut("LL '$_[0]'\n");
}

sub open_table {
    my $this = shift;
    $this->addToOut("<table>\n");
}

sub close_table {
    my $this = shift;
    $this->addToOut("</table>\n");
}

sub open_tr {
    my $this = shift;
    $this->addToOut("<tr pre='$_[0]' post='$_[1]'>\n");
}

sub close_tr {
    my $this = shift;
    $this->addToOut("</tr>\n");
}

sub td {
    my $this = shift;
    $this->addToOut("<td pre='$_[0]' post='$_[2]'>$_[1]</td>\n");
}

sub th {
    my $this = shift;
    $this->addToOut("<th pre='$_[0]' post='$_[2]'>$_[1]</th>\n");
}

sub test_simple_table {
    my $this = shift;

    my $in = <<IN;
| Simple | Table |
IN
    Foswiki::Tables::Parser::parse( $in, $this->dispatch );
    $this->assert_html_equals( <<EXPECTED, $this->out );
<table>
<tr pre='' post=''>
<td pre=' ' post=' '>Simple</td>
<td pre=' ' post=' '>Table</td>
</tr>
</table>
EOF
EXPECTED
}

sub test_headers_at_top {
    my $this = shift;

    my $in = <<IN;
| *Simple* | Table |
IN
    Foswiki::Tables::Parser::parse( $in, $this->dispatch );
    $this->assert_html_equals( <<EXPECTED, $this->out );
<table>
<tr pre='' post=''>
<th pre=' ' post=' '>Simple</th>
<td pre=' ' post=' '>Table</td>
</tr>
</table>
EOF
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
    Foswiki::Tables::Parser::parse( $in, $this->dispatch );
    $this->assert_html_equals( <<EXPECTED, $this->out );
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
EOF
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
    Foswiki::Tables::Parser::parse( $in, $this->dispatch );
    $this->assert_html_equals( <<EXPECTED, $this->out );
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
EOF
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
    Foswiki::Tables::Parser::parse( $in, $this->dispatch );
    $this->assert_html_equals( <<EXPECTED, $this->out );
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
EOF
EXPECTED
}

sub test_early_line {
    my $this = shift;

    my $in = <<'IN';
Testing testing 1 2 3
Spot CREATE_A_TABLE the dog
Hugh NO_TABLE Pugh
Barney McGrew
IN
    Foswiki::Tables::Parser::parse( $in, $this->dispatch );
    $this->assert_html_equals( <<EXPECTED, $this->out );
LL 'Testing testing 1 2 3'
EL Spot  the dog
<table>
LL 'Spot  the dog'
ELE
</table>
LL 'Hugh  Pugh'
LL 'Barney McGrew'
EOF
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
    Foswiki::Tables::Parser::parse( $in, $this->dispatch );
    $this->assert_html_equals( <<EXPECTED, $this->out );
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
EOF
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
    Foswiki::Tables::Parser::parse( $in, $this->dispatch );
    $this->assert_html_equals( <<EXPECTED, $this->out );
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
EOF
EXPECTED
}

1;
