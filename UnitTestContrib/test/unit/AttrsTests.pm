use strict;

package AttrsTests;

use base qw(TWikiTestCase);

use TWiki::Attrs;

sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
}

sub test_isEmpty {
	my $this = shift;

	my $attrs = TWiki::Attrs->new(undef, 1);
	$this->assert($attrs->isEmpty());
	$attrs = TWiki::Attrs->new("", 1);
	$this->assert($attrs->isEmpty());
	$attrs = TWiki::Attrs->new(" \t  \n\t", 1);
	$this->assert($attrs->isEmpty());
}

sub test_boolean {
	my $this = shift;

	my $attrs = TWiki::Attrs->new("a", 1);
	$this->assert(!$attrs->isEmpty());
	$this->assert_not_null($attrs->{"a"});
	$this->assert_str_equals("1", $attrs->{"a"});

	$attrs = TWiki::Attrs->new("a12g b987", 1);
	$this->assert_not_null($attrs->remove("a12g"));
	$this->assert_null($attrs->{"a12g"});
	$this->assert_not_null($attrs->remove("b987"));
	$this->assert_null($attrs->{"b987"});
	$this->assert($attrs->isEmpty(), "Fail ".$attrs->stringify());

	$attrs = TWiki::Attrs->new("Acid AnhydrousCopperSulphate='white' X", 1);
	$this->assert_not_null($attrs->remove("Acid"));
	$this->assert_not_null($attrs->remove("X"));
	$this->assert_str_equals('white',$attrs->remove("AnhydrousCopperSulphate"));
	$this->assert($attrs->isEmpty(), "Fail ".$attrs->stringify());
}

sub test_default {
	my $this = shift;

	my $attrs = TWiki::Attrs->new("\"wibble\"", 1);
	$this->assert(!$attrs->isEmpty());
	$this->assert_str_equals("wibble", $attrs->remove("_DEFAULT"));
	$this->assert_null($attrs->{"_DEFAULT"});
	$this->assert($attrs->isEmpty());

	$attrs = TWiki::Attrs->new("\"wibble\" \"fleegle\"", 1);
	$this->assert_str_equals("wibble", $attrs->remove("_DEFAULT"));
	$this->assert($attrs->isEmpty());
}

sub test_unquoted {
	my $this = shift;

	my $attrs = TWiki::Attrs->new("var1=val1 var2= val2, var3 = 3 var4 =val4", 1);
	$this->assert_str_equals("val1", $attrs->remove("var1"));
	$this->assert_str_equals("val2", $attrs->remove("var2"));
	$this->assert_str_equals("3", $attrs->remove("var3"));
	$this->assert_str_equals("val4", $attrs->remove("var4"));
	$this->assert($attrs->isEmpty());
}

sub test_escapes {
	my $this = shift;

	my $attrs = TWiki::Attrs->new("var1=\\\"val1 var2= \\\'val2, var3 = 3 var4 =val4", 1);
	$this->assert_str_equals("\"val1", $attrs->remove("var1"));
	$this->assert_str_equals("\'val2", $attrs->remove("var2"));
	$this->assert_str_equals("3", $attrs->remove("var3"));
	$this->assert_str_equals("val4", $attrs->remove("var4"));
	$this->assert($attrs->isEmpty());
}

sub test_doubleQuoted {
	my $this = shift;

	my $attrs = TWiki::Attrs->new("var1 =\"val 1\", var2= \"val 2\" \" default \" var3 = \" val 3 \"", 1);
	$this->assert_str_equals("val 1", $attrs->remove("var1"));
	$this->assert_str_equals("val 2", $attrs->remove("var2"));
	$this->assert_str_equals(" val 3 ", $attrs->remove("var3"));
	$this->assert_str_equals(" default ", $attrs->remove("_DEFAULT"));
	$this->assert($attrs->isEmpty());
}

sub test_singleQuoted {
	my $this = shift;

	my $attrs = TWiki::Attrs->new("var1 ='val 1', var2= 'val 2' ' default ' var3 = ' val 3 '", 1);
	$this->assert_str_equals("val 1", $attrs->remove("var1"));
	$this->assert_str_equals("val 2", $attrs->remove("var2"));
	$this->assert_str_equals(" val 3 ", $attrs->remove("var3"));
	$this->assert_str_equals(" default ", $attrs->remove("_DEFAULT"));
	$this->assert($attrs->isEmpty());
}

sub test_mixedQuotes {
	my $this = shift;

	my $attrs = TWiki::Attrs->new("a ='\"', b=\"'\" \"'\"", 1);
	$this->assert_str_equals("\"", $attrs->remove("a"));
	$this->assert_str_equals("'", $attrs->remove("b"));
	$this->assert_str_equals("'", $attrs->remove("_DEFAULT"));
	$this->assert($attrs->isEmpty());
	$attrs = TWiki::Attrs->new("'\"'", 1);
	$this->assert_str_equals("\"", $attrs->remove("_DEFAULT"));
	$this->assert($attrs->isEmpty());
}

sub test_toString {
	my $this = shift;

	my $attrs = TWiki::Attrs->new("a ='\"', b=\"'\" \"'\"", 1);
	my $s = $attrs->stringify();
	$attrs = TWiki::Attrs->new($attrs->stringify(), 1);
	$this->assert_str_equals("\"", $attrs->remove("a"));
	$this->assert_str_equals("'", $attrs->remove("b"));
	$this->assert_str_equals("'", $attrs->remove("_DEFAULT"));
	$this->assert($attrs->isEmpty());
}

sub test_extractValue1 {
    my $this = shift;

    my $s = '"abc def="ghi" jkl" def="mno" pqr=" stu="vwx""';
    $this->assert_str_equals('abc def="ghi" jkl',
                             TWiki::Attrs::extractValue($s));
}

sub test_extractValue2{
    my $this = shift;

    my $s = '"abc def="ghi" jkl" def="mno" pqr=" stu="vwx""';
    $this->assert_str_equals('ghi',
                             TWiki::Attrs::extractValue($s, "def"));
}

sub test_extractValue3 {
    my $this = shift;

    my $s = '"abc def="ghi" jkl" def="mno" pqr=" stu="vwx""';
    $this->assert_str_equals('',
                             TWiki::Attrs::extractValue($s, "jkl"));
}

sub test_extractValue4 {
    my $this = shift;

    my $s = '"abc def="ghi" jkl" def="mno" pqr=" stu="vwx""';
    $this->assert_str_equals(' stu=',
                             TWiki::Attrs::extractValue($s, 'pqr'));
}

sub test_extractValue5 {
    my $this = shift;

    my $s = '"abc def="ghi" jkl" def="mno" pqr=" stu="vwx""';
    $this->assert_str_equals('vwx',
                             TWiki::Attrs::extractValue($s, 'stu'));
}

sub extractParameters {
    my( $str ) = @_;

    my %params = ();
    return %params unless defined $str;
    $str =~ s/\\\"/\\\0/g;  # escape \"

    if( $str =~ s/^\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/$2/ ) {
        # is: %VAR{ "value" }%
        # or: %VAR{ "value" param="etc" ... }%
        # Note: "value" may contain embedded double quotes
        $params{"_DEFAULT"} = $1 if defined $1;  # distinguish between "" and "0";
        if( $2 ) {
            while( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) {
                $params{"$1"} = $2 if defined $2;
            }
        }
    } elsif( ( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) && ( $1 ) ) {
        # is: %VAR{ name = "value" }%
        $params{"$1"} = $2 if defined $2;
        while( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) {
            $params{"$1"} = $2 if defined $2;
        }
    } elsif( $str =~ s/^\s*(.*?)\s*$// ) {
        # is: %VAR{ value }%
        $params{"_DEFAULT"} = $1 unless $1 eq "";
    }
    return map{ s/\\\0/\"/go; $_ } %params;
}

sub huey {
    my $params = shift;
    my $s = "";
    if(defined $params->{_DEFAULT}) {
        $s = "\"$params->{_DEFAULT}\"";
    }
    foreach my $k ( sort keys %$params ) {
        if( $k ne "_DEFAULT" ) {
            my $q = $params->{$k};
            $q =~ s/"/\\"/g;
            $s .= " $k=\"$q\"";
        }
    }
    return $s;
}

sub check_string {
    my( $this, $s ) = @_;

    my $new = new TWiki::Attrs($s,0);
    my %old = extractParameters($s);

    foreach my $key( keys %old  ) {
        $this->assert_str_equals($old{$key}, $new->{$key},
                                 "$key FAILED\n".$new->stringify()."\nOLD\n".huey(\%old));
    }
}

sub test_compatibility1 {
    my $this = shift;
    my $s = ' "abc\" def="ghi" jkl" def="mno" pqr=" stu="\"vwx""';
    $this->check_string( $s );
}

sub test_compatibility2 {
    my $this = shift;
    my $s = ' def="m\"no" pqr=" stu="vwx""';
    $this->check_string( $s );
}

sub test_compatibility3 {
    my $this = shift;
    my $s = " bloody \" hell ";
    $this->check_string( $s );
}

sub test_compatibility4 {
    my $this = shift;
    my $s = "  ";
    $this->check_string( $s );
}

sub test_compatibility5 {
    my $this = shift;
    my $s = "\nBarf";
    my $new = new TWiki::Attrs($s,0);
    $s = "Barf\n";
    $new = new TWiki::Attrs($s,0);
    $s = "\n";
    $new = new TWiki::Attrs($s,0);
    $s = "\"The\nCat\" format=\"Shat\nOn\nThe\nMat\"";
    $this->check_string( $s );
}

sub test_raw {
    my $this = shift;
    my $s = "   Barf";
    my $new = new TWiki::Attrs($s,0);
    $this->assert_str_equals($s, $new->{_RAW});
}

1;
