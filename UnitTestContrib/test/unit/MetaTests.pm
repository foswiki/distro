# Smoke tests for Foswiki::Meta

require 5.006;
use strict;

package MetaTests;

use base qw(FoswikiTestCase);

use Foswiki;
use Foswiki::Meta;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $args =
  {
   name => "a",
   value  => "1",
   aa     => "AA",
   yy     => "YY",
   xx     => "XX"
  };

my $args1 =
  {
   name => "a",
   value => "2"
  };

my $args2 =
  {
   name => "b",
   value => "3"
  };

my $web= "ZoopyDoopy";
my $topic = "NoTopic";
my $m1;
my $session;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{twiki} = new Foswiki();

    $m1 = Foswiki::Meta->new($this->{twiki}, $web, $topic);
    $m1->put( "TOPICINFO", $args );
    $m1->putKeyed( "FIELD", $args );
    $m1->putKeyed( "FIELD", $args2 );
}

sub tear_down {
    my $this = shift;
    File::Path::rmtree("$Foswiki::cfg{DataDir}/$web");
    File::Path::rmtree("$Foswiki::cfg{PubDir}/$web");
    $this->{twiki}->finish() if $this->{twiki};
    $this->SUPER::tear_down();
}

# Field that can only have one copy
sub test_single {
    my $this = shift;
    my $meta = Foswiki::Meta->new($this->{twiki}, $web, $topic);
    
    $meta->put( "TOPICINFO", $args );
    my $vals = $meta->get( "TOPICINFO" );
    $this->assert_str_equals( $vals->{"name"}, "a" );
    $this->assert_str_equals( $vals->{"value"}, "1" );
    $this->assert( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    $meta->put( "TOPICINFO", $args1 );
    my $vals1 = $meta->get( "TOPICINFO" );
    $this->assert_str_equals("a", $vals1->{"name"} );
    $this->assert_equals(2, $vals1->{"value"} );
    $this->assert_equals(1, $meta->count( "TOPICINFO" ), "Should be one item" );
}

sub test_multiple {
    my $this = shift;
    my $meta = Foswiki::Meta->new($this->{twiki}, $web, $topic);
    
    $meta->putKeyed( "FIELD", $args );
    my $vals = $meta->get( "FIELD", "a" );
    $this->assert_str_equals( $vals->{"name"}, "a" );
    $this->assert_str_equals( $vals->{"value"}, "1" );
    $this->assert( $meta->count( "FIELD" ) == 1, "Should be one item" );

    $meta->putKeyed( "FIELD", $args1 );
    my $vals1 = $meta->get( "FIELD", "a" );
    $this->assert_str_equals( $vals1->{"name"}, "a" );
    $this->assert_str_equals( $vals1->{"value"}, "2" );
    $this->assert( $meta->count( "FIELD" ) == 1, "Should be one item" );
    
    $meta->putKeyed( "FIELD", $args2 );
    $this->assert( $meta->count( "FIELD" ) == 2, "Should be two items" );
    my $vals2 = $meta->get( "FIELD", "b" );
    $this->assert_str_equals( $vals2->{"name"}, "b" );
    $this->assert_str_equals( $vals2->{"value"}, "3" );
}

sub test_removeSingle {
    my $this = shift;
    my $meta = Foswiki::Meta->new($this->{twiki}, $web, $topic);
    
    $meta->put( "TOPICINFO", $args );
    $this->assert( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    $meta->remove( "TOPICINFO" );
    $this->assert( $meta->count( "TOPICINFO" ) == 0, "Should be no items after remove" );
}

sub test_removeMultiple {
    my $this = shift;
    my $meta = Foswiki::Meta->new($this->{twiki}, $web, $topic);
    
    $meta->putKeyed( "FIELD", $args );
    $meta->putKeyed( "FIELD", $args2 );
    $meta->put( "TOPICINFO", $args );
    $this->assert( $meta->count( "FIELD" ) == 2, "Should be two items" );
    
    $meta->remove( "FIELD" );
    
    $this->assert( $meta->count( "FIELD" ) == 0, "Should be no FIELD items after remove" );
    $this->assert( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    
    $meta->putKeyed( "FIELD", $args );
    $meta->putKeyed( "FIELD", $args2 );
    $meta->remove( "FIELD", "b" );
    $this->assert( $meta->count( "FIELD" ) == 1, "Should be one FIELD items after partial remove" );
}

sub test_foreach {
    my $this = shift;
    my $meta = Foswiki::Meta->new($this->{twiki}, $web, $topic);

    $meta->putKeyed( "FIELD", { name => "a", value => "aval" } );
    $meta->putKeyed( "FIELD", { name => "b", value => "bval" } );
    $meta->put( "FINAGLE", { name => "a", value => "aval" } );
    $meta->put( "FINAGLE", { name => "b", value => "bval" } );

    my $fleegle;
    my $d = {};
    my $before = $meta->stringify();
    $meta->forEachSelectedValue
      (undef, undef, \&fleegle, $d);
    $this->assert($d->{collected} =~ s/FINAGLE.name:b;//);
    $this->assert($d->{collected} =~ s/FINAGLE.value:bval;//);
    $this->assert($d->{collected} =~ s/FIELD.name:a;//);
    $this->assert($d->{collected} =~ s/FIELD.value:aval;//);
    $this->assert($d->{collected} =~ s/FIELD.name:b;//);
    $this->assert($d->{collected} =~ s/FIELD.value:bval;//);
    $this->assert_str_equals("", $d->{collected});
    $this->assert_str_equals($before, $meta->stringify());

    $meta->forEachSelectedValue
      (qr/^FIELD$/, undef, \&fleegle, $d);
    $this->assert($d->{collected} =~ s/FIELD.name:a;//);
    $this->assert($d->{collected} =~ s/FIELD.value:aval;//);
    $this->assert($d->{collected} =~ s/FIELD.name:b;//);
    $this->assert($d->{collected} =~ s/FIELD.value:bval;//);
    $this->assert_str_equals("", $d->{collected});

    $meta->forEachSelectedValue
      (qr/^FIELD$/, qr/^value$/, \&fleegle, $d);
    $this->assert($d->{collected} =~ s/FIELD.value:aval;//);
    $this->assert($d->{collected} =~ s/FIELD.value:bval;//);
    $this->assert_str_equals("", $d->{collected});

    $meta->forEachSelectedValue
      (undef, qr/^name$/, \&fleegle, $d);
    $this->assert($d->{collected} =~ s/FINAGLE.name:b;//);
    $this->assert($d->{collected} =~ s/FIELD.name:a;//);
    $this->assert($d->{collected} =~ s/FIELD.name:b;//);
    $this->assert_str_equals("", $d->{collected});
}

sub fleegle {
    my( $t, $o ) = @_;
    $o->{collected} .= "$o->{_type}.$o->{_key}:$t;";
    return $t;
}

sub test_copyFrom {
    my $this = shift;
    my $meta = Foswiki::Meta->new($this->{twiki}, $web, $topic);

    $meta->putKeyed( "FIELD", { name => "a", value => "aval" } );
    $meta->putKeyed( "FIELD", { name => "b", value => "bval" } );
    $meta->putKeyed( "FIELD", { name => "c", value => "cval" } );
    $meta->put( "FINAGLE", { name => "a", value => "aval" } );

    my $new = new Foswiki::Meta( $this->{twiki}, $web, $topic );
    $new->copyFrom($meta);

    my $d = {};
    $new->forEachSelectedValue(qr/^F.*$/, qr/^value$/, \&fleegle, $d);
    $this->assert($d->{collected} =~ s/FIELD.value:aval;//);
    $this->assert($d->{collected} =~ s/FIELD.value:bval;//);
    $this->assert($d->{collected} =~ s/FIELD.value:cval;//);
    $this->assert($d->{collected} =~ s/FINAGLE.value:aval;//);
    $this->assert_str_equals("", $d->{collected});

    $new = new Foswiki::Meta( $this->{twiki}, $web, $topic );
    $new->copyFrom($meta, 'FIELD');

    $new->forEachSelectedValue(qr/^FIELD$/, qr/^value$/, \&fleegle, $d);
    $this->assert($d->{collected} =~ s/FIELD.value:aval;//);
    $this->assert($d->{collected} =~ s/FIELD.value:bval;//);
    $this->assert($d->{collected} =~ s/FIELD.value:cval;//);
    $this->assert_str_equals("", $d->{collected});

    $new = new Foswiki::Meta( $this->{twiki}, $web, $topic );
    $new->copyFrom($meta, 'FIELD', qr/^(a|b)$/);
    $new->forEachSelectedValue(qr/^FIELD$/, qr/^value$/, \&fleegle, $d);
    $this->assert($d->{collected} =~ s/FIELD.value:aval;//);
    $this->assert($d->{collected} =~ s/FIELD.value:bval;//);
    $this->assert_str_equals("", $d->{collected});
}

sub test_parent {
    my $this = shift;
    $this->{twiki}->{store}->createWeb(
        $this->{twiki}->{user}, $web);

    my $testTopic = "TestParent";
    for my $depth ( 1..5 ) {
        my $child = $testTopic . $depth;
        my $parent = $testTopic . ( $depth + 1 );
        my $text = "This is ancestor number $depth";
        my $meta = Foswiki::Meta->new($this->{twiki}, $web, $child );
        $meta->put( "TOPICPARENT", { name => $parent } );
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user}, $web, $child,
            $text, $meta );
    }
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $web, $testTopic . '6',
        "Final ancestor" );

    for my $depth ( 1..5 ) {
        my $child = $testTopic . $depth;
        my ( $meta, $text ) = $this->{twiki}->{store}->readTopic(
            $this->{twiki}->{user}, $web, $child );
        my $parent = $meta->getParent();
        $this->assert_str_equals( $parent, $testTopic . ( $depth + 1 ),
            "getParent failed at depth $depth" );

        $this->{twiki}->enterContext( 'can_render_meta', $meta );
        # Test basic parent
        my $str = $this->{twiki}->handleCommonTags(
            '%META{"parent"}%', $web, $child, $meta );
        $this->assert_str_equals( $str,
            join( " &gt; ", map { "[[$web.$testTopic$_][$testTopic$_]]" } reverse $depth+1 .. 6));

        # Test norecurse
        $str = $this->{twiki}->handleCommonTags(
            '%META{"parent" dontrecurse="on"}%', $web, $child, $meta );
        $this->assert_str_equals( $str, "[[$web.$parent][$parent]]" );

        # Test depth
        for my $subDepth ( 1 .. 5 - $depth  ) {
            $str = $this->{twiki}->handleCommonTags(
                '%META{"parent" depth="' . $subDepth . '"}%', $web, $child, $meta );
            my $parentDepth = $subDepth + $depth;
            $this->assert_str_equals( $str, "[[$web.${testTopic}$parentDepth][${testTopic}$parentDepth]]" );
        }

        # Test prefix and suffix
        $str = $this->{twiki}->handleCommonTags(
            '%META{"parent" prefix="Before" suffix="After"}%', $web, $child, $meta );
        $this->assert_str_equals( $str,
            "Before" .
            join( " &gt; ", map { "[[$web.$testTopic$_][$testTopic$_]]" } reverse $depth+1 .. 6)
            . "After");

        # Test format
        $str = $this->{twiki}->handleCommonTags(
            '%META{"parent" format="$web.$topic"}%', $web, $child, $meta );
        $this->assert_str_equals( $str,
            join( " &gt; ", map { "$web.$testTopic$_" } reverse $depth+1 .. 6));

        # Test separator
        $str = $this->{twiki}->handleCommonTags(
            '%META{"parent" separator=" << "}%', $web, $child, $meta );
        $this->assert_str_equals( $str,
            join( " << ", map { "[[$web.$testTopic$_][$testTopic$_]]" } reverse $depth+1 .. 6));

    }

    # Test nowebhome
    my ($text, $str);
    my $meta = Foswiki::Meta->new( $this->{twiki}, $web, $testTopic . '6' );
    $meta->put( "TOPICPARENT", { name => $Foswiki::cfg{HomeTopicName} } );
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $web, $testTopic . '6',
        "Final ancestor with WebHome as parent", $meta );
    ( $meta, $text ) = $this->{twiki}->{store}->readTopic(
        $this->{twiki}->{user}, $web, $testTopic . '1' );
    $this->{twiki}->enterContext( 'can_render_meta', $meta );
    $str = $this->{twiki}->handleCommonTags(
        '%META{"parent"}%', $web, $testTopic . '1', $meta );
    $this->assert_str_equals( $str,
        join( " &gt; ", map { "[[$web.$_][$_]]" }
        ( 'WebHome', map { "$testTopic$_" } reverse 2 .. 6)));
    $str = $this->{twiki}->handleCommonTags(
        '%META{"parent" nowebhome="on"}%', $web, $testTopic . '1' );
    $this->assert_str_equals( $str,
        join( " &gt; ", map { "[[$web.$testTopic$_][$testTopic$_]]" } reverse 2 .. 6));

}

1;
