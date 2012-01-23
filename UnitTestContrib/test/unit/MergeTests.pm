# Copyright (C) 2005 Greg Abbas
# Copyright (C) 2006 Crawford Currie http://c-dot.co.uk
package MergeTests;
use strict;
use warnings;
require 5.006;

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Assert();
use Foswiki::Merge();
use Error qw( :try );

use vars qw( $info @mudge );

#-----------------------------------------------------------------------------
# helper methods

{

    package HackJob;

    sub new {
        return bless( {}, shift );
    }

    sub dispatch {
        my ( $this, $handler, $cc, $aa, $bb, $i ) = @_;
        die "OUCH $handler" unless $handler eq 'mergeHandler';
        $aa = 'undef' unless defined $aa;
        $bb = 'undef' unless defined $bb;
        die "$i.$MergeTests::info" unless $i eq $MergeTests::info;
        push( @MergeTests::mudge, "$cc#$aa#$bb" );
        return;
    }

    sub finish {
        return;
    }
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->createNewFoswikiSession();
    @mudge                    = ();
    $this->{session}{plugins} = HackJob->new();
    $info                     = { argle => "bargle" };

    return;
}

sub _merge3 {
    my ( $ia, $ib, $ic ) = @_;
    return Foswiki::Merge::merge3( 'a', $ia, 'b', $ib, 'c', $ic, ' ',
        $Foswiki::Plugins::SESSION, $info );
}

sub _merge2 {
    my ( $ia, $ib ) = @_;

    return Foswiki::Merge::merge2( 'a', $ia, 'b', $ib, ' ',
        $Foswiki::Plugins::SESSION, $info );
}

sub _readfile {
    my ($fn) = @_;
    open( my $ff, '<', $fn ) || die("could not open file $fn");
    my @data = <$ff>;
    ASSERT( close($ff) );
    return join( '', @data );
}

#-----------------------------------------------------------------------------
# tests

sub test_M3_shortStrings1 {
    my $this = shift;
    my ( $aa, $bb, $cc, $dd );
    $aa = "";
    $bb = "";
    $cc = "1 2 3 4 5 ";
    $dd = _merge3( $aa, $bb, $cc );
    $this->assert_str_equals( $cc, $dd );
    $this->assert_str_equals(
        ' ##: #1 #1 : ##: #2 #2 : ##: #3 #3 : ##: #4 #4 : ##: #5 #5 ',
        join( ':', @mudge ) );

    return;
}

sub test_M3_shortStrings2 {
    my $this = shift;
    my ( $aa, $bb, $cc, $dd );
    $aa = "1 2 3 4 5 ";
    $bb = "1 2 3 4 5 ";
    $cc = "";
    $dd = _merge3( $aa, $bb, $cc );
    $this->assert_str_equals( $cc, $dd );

    return;
}

sub test_M3_shortStrings3 {
    my $this = shift;
    my ( $aa, $bb, $cc, $dd );
    $aa = "1 2 3 4 5 ";
    $bb = "1 b 2 3 4 5 ";
    $cc = "1 2 3 4 c 5 ";
    $dd = _merge3( $aa, $bb, $cc );
    $this->assert_str_equals( "1 b 2 3 4 c 5 ", $dd );

    return;
}

sub test_M3_shortStrings4 {
    my $this = shift;
    my ( $aa, $bb, $cc, $dd );
    $aa = "1 2 3 4 5 ";
    $bb = "1 b 2 3 4 5 ";
    $cc = "1 c 2 3 4 c 5 ";
    $dd = _merge3( $aa, $bb, $cc ) . "\n";

    $this->assert_str_equals(
        <<'END',
1 <div class="foswikiConflict"><b>CONFLICT</b> version b:</div>
b <div class="foswikiConflict"><b>CONFLICT</b> version c:</div>
c <div class="foswikiConflict"><b>CONFLICT</b> end</div>
2 3 4 c 5 
END
        $dd
    );
    $this->assert_str_equals(
        ' ##: #1 #1 : ##:c#b #c : ##: #4 #4 : ##: #c #c : ##: #5 #5 ',
        join( ':', @mudge ) );

    return;
}

sub test_M3_shortStrings5 {
    my $this = shift;
    my ( $aa, $bb, $cc, $dd );
    $aa = "1 2 3 4 5 ";
    $bb = "1 3 4 5 6 ";
    $cc = "1 2 3 ";
    $dd = _merge3( $aa, $bb, $cc );
    $this->assert_str_equals( "1 3 6 ", $dd );

    return;
}

sub test_M3_shortStrings6 {
    my $this = shift;
    my ( $aa, $bb, $cc, $dd );
    $aa = "1 2 3 4 5 ";
    $bb = "1 2 4 5 ";
    $cc = $bb;
    $dd = _merge3( $aa, $bb, $cc );
    $this->assert_str_equals( "1 2 4 5 ", $dd );

    return;
}

sub test_M3_shortStrings7 {
    my $this = shift;
    my ( $aa, $bb, $cc, $dd );
    $aa = "1 2 3 4 5 ";
    $bb = "1 2 change 4 5 ";
    $cc = $bb;
    $dd = _merge3( $aa, $bb, $cc );
    $this->assert_str_equals( "1 2 change 4 5 ", $dd );

    return;
}

sub test_M3_shortStrings8 {
    my $this = shift;
    my ( $aa, $bb, $cc, $dd );
    $aa = "1 2 3 4 5 ";
    $bb = "1 2 change 4 5 ";
    $cc = "1 2 other 4 5 ";
    $dd = _merge3( $aa, $bb, $cc ) . "\n";
    $this->assert_str_equals(
        <<'END',
1 2 <div class="foswikiConflict"><b>CONFLICT</b> original a:</div>
3 <div class="foswikiConflict"><b>CONFLICT</b> version b:</div>
change <div class="foswikiConflict"><b>CONFLICT</b> version c:</div>
other <div class="foswikiConflict"><b>CONFLICT</b> end</div>
4 5 
END
        $dd
    );
    $this->assert_str_equals( ' ##: #1 #1 : ##: #2 #2 : ##:c#change #other ',
        join( ':', @mudge ) );

    return;
}

sub test_M3_text {

    my $this = shift;
    my ( $aa, $bb, $cc, $dd, $ee );

    $aa = <<"EOF";
Some text.<br>
The first version.<br>
Very nice.<br>
EOF

    $bb = <<"EOF";
Some text.<br>
The first version.<br>
New text in version "b".<br>
Very nice.<br>
EOF

    $cc = <<"EOF";
New first line in "c".<br>
The first version.<br>
Very nice.<br>
EOF

    $ee = <<"EOF";
New first line in "c".<br>
The first version.<br>
New text in version "b".<br>
Very nice.<br>
EOF

    $dd = Foswiki::Merge::merge3( "r1", $aa, "r2", $bb, "r3", $cc, '\n',
        $Foswiki::Plugins::SESSION, $info );
    $this->assert_str_equals( $ee, $dd );

    $cc = <<"EOF";
Some text.<br>
The first version.<br>
Alternatively, new text in version "c".<br>
Very nice.<br>
EOF

    $ee = <<"EOF";
Some text.<br>
The first version.<br>
<div class=\"foswikiConflict\"><b>CONFLICT</b> version r2:</div>
New text in version "b".<br>
<div class=\"foswikiConflict\"><b>CONFLICT</b> version r3:</div>
Alternatively, new text in version "c".<br>
<div class=\"foswikiConflict\"><b>CONFLICT</b> end</div>
Very nice.<br>
EOF

    $dd = Foswiki::Merge::merge3( "r1", $aa, "r2", $bb, "r3", $cc, '\n',
        $Foswiki::Plugins::SESSION, $info );
    $this->assert_str_equals( $ee, $dd );

    return;
}

sub test_M2_simple {
    my $this = shift;
    my $aa   = 'A B';
    my $bb   = 'B C';
    my $cc   = _merge2( $aa, $bb );
    my $dd   = 'A B C';
    $this->assert_str_equals( $dd, $cc );

    $this->assert_str_equals(
        ' #A#undef: # #undef: #B#undef: # #undef: #C#undef',
        join( ':', @mudge ) );

    return;
}

1;
