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

my $args = {
    name  => "a",
    value => "1",
    aa    => "AA",
    yy    => "YY",
    xx    => "XX"
};

my $args1 = {
    name  => "a",
    value => "2"
};

my $args2 = {
    name  => "b",
    value => "3"
};

my $web   = "ZoopyDoopy";
my $topic = "NoTopic";
my $m1;
my $session;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{session} = new Foswiki();

    $m1 = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $m1->put( "TOPICINFO", $args );
    $m1->putKeyed( "FIELD", $args );
    $m1->putKeyed( "FIELD", $args2 );
}

sub tear_down {
    my $this = shift;
    $this->{session}->finish() if $this->{session};
}

# Field that can only have one copy
sub test_single {
    my $this = shift;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );

    $meta->put( "TOPICINFO", $args );
    my $vals = $meta->get("TOPICINFO");
    $this->assert_str_equals( $vals->{"name"},  "a" );
    $this->assert_str_equals( $vals->{"value"}, "1" );
    $this->assert( $meta->count("TOPICINFO") == 1, "Should be one item" );
    $meta->put( "TOPICINFO", $args1 );
    my $vals1 = $meta->get("TOPICINFO");
    $this->assert_str_equals( "a", $vals1->{"name"} );
    $this->assert_equals( 2, $vals1->{"value"} );
    $this->assert_equals( 1, $meta->count("TOPICINFO"), "Should be one item" );
}

sub test_multiple {
    my $this = shift;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );

    $meta->putKeyed( "FIELD", $args );
    my $vals = $meta->get( "FIELD", "a" );
    $this->assert_str_equals( $vals->{"name"},  "a" );
    $this->assert_str_equals( $vals->{"value"}, "1" );
    $this->assert( $meta->count("FIELD") == 1, "Should be one item" );

    $meta->putKeyed( "FIELD", $args1 );
    my $vals1 = $meta->get( "FIELD", "a" );
    $this->assert_str_equals( $vals1->{"name"},  "a" );
    $this->assert_str_equals( $vals1->{"value"}, "2" );
    $this->assert( $meta->count("FIELD") == 1, "Should be one item" );

    $meta->putKeyed( "FIELD", $args2 );
    $this->assert( $meta->count("FIELD") == 2, "Should be two items" );
    my $vals2 = $meta->get( "FIELD", "b" );
    $this->assert_str_equals( $vals2->{"name"},  "b" );
    $this->assert_str_equals( $vals2->{"value"}, "3" );
}

sub test_removeSingle {
    my $this = shift;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );

    $meta->put( "TOPICINFO", $args );
    $this->assert( $meta->count("TOPICINFO") == 1, "Should be one item" );
    $meta->remove("TOPICINFO");
    $this->assert( $meta->count("TOPICINFO") == 0,
        "Should be no items after remove" );
}

sub test_removeMultiple {
    my $this = shift;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );

    $meta->putKeyed( "FIELD", $args );
    $meta->putKeyed( "FIELD", $args2 );
    $meta->put( "TOPICINFO", $args );
    $this->assert( $meta->count("FIELD") == 2, "Should be two items" );

    $meta->remove("FIELD");

    $this->assert( $meta->count("FIELD") == 0,
        "Should be no FIELD items after remove" );
    $this->assert( $meta->count("TOPICINFO") == 1, "Should be one item" );

    $meta->putKeyed( "FIELD", $args );
    $meta->putKeyed( "FIELD", $args2 );
    $meta->remove( "FIELD", "b" );
    $this->assert( $meta->count("FIELD") == 1,
        "Should be one FIELD items after partial remove" );
}

sub test_foreach {
    my $this = shift;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );

    $meta->putKeyed( "FIELD", { name => "a", value => "aval" } );
    $meta->putKeyed( "FIELD", { name => "b", value => "bval" } );
    $meta->put( "FINAGLE", { name => "a", value => "aval" } );
    $meta->put( "FINAGLE", { name => "b", value => "bval" } );

    my $fleegle;
    my $d      = {};
    my $before = $meta->stringify();
    $meta->forEachSelectedValue( undef, undef, \&fleegle, $d );
    $this->assert( $d->{collected} =~ s/FINAGLE.name:b;// );
    $this->assert( $d->{collected} =~ s/FINAGLE.value:bval;// );
    $this->assert( $d->{collected} =~ s/FIELD.name:a;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:aval;// );
    $this->assert( $d->{collected} =~ s/FIELD.name:b;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:bval;// );
    $this->assert_str_equals( "",      $d->{collected} );
    $this->assert_str_equals( $before, $meta->stringify() );

    $meta->forEachSelectedValue( qr/^FIELD$/, undef, \&fleegle, $d );
    $this->assert( $d->{collected} =~ s/FIELD.name:a;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:aval;// );
    $this->assert( $d->{collected} =~ s/FIELD.name:b;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:bval;// );
    $this->assert_str_equals( "", $d->{collected} );

    $meta->forEachSelectedValue( qr/^FIELD$/, qr/^value$/, \&fleegle, $d );
    $this->assert( $d->{collected} =~ s/FIELD.value:aval;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:bval;// );
    $this->assert_str_equals( "", $d->{collected} );

    $meta->forEachSelectedValue( undef, qr/^name$/, \&fleegle, $d );
    $this->assert( $d->{collected} =~ s/FINAGLE.name:b;// );
    $this->assert( $d->{collected} =~ s/FIELD.name:a;// );
    $this->assert( $d->{collected} =~ s/FIELD.name:b;// );
    $this->assert_str_equals( "", $d->{collected} );
}

sub fleegle {
    my ( $t, $o ) = @_;
    $o->{collected} .= "$o->{_type}.$o->{_key}:$t;";
    return $t;
}

sub test_copyFrom {
    my $this = shift;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );

    $meta->putKeyed( "FIELD", { name => "a", value => "aval" } );
    $meta->putKeyed( "FIELD", { name => "b", value => "bval" } );
    $meta->putKeyed( "FIELD", { name => "c", value => "cval" } );
    $meta->put( "FINAGLE", { name => "a", value => "aval" } );

    my $new = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $new->copyFrom($meta);

    my $d = {};
    $new->forEachSelectedValue( qr/^F.*$/, qr/^value$/, \&fleegle, $d );
    $this->assert( $d->{collected} =~ s/FIELD.value:aval;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:bval;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:cval;// );
    $this->assert( $d->{collected} =~ s/FINAGLE.value:aval;// );
    $this->assert_str_equals( "", $d->{collected} );

    $new = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $new->copyFrom( $meta, 'FIELD' );

    $new->forEachSelectedValue( qr/^FIELD$/, qr/^value$/, \&fleegle, $d );
    $this->assert( $d->{collected} =~ s/FIELD.value:aval;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:bval;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:cval;// );
    $this->assert_str_equals( "", $d->{collected} );

    $new = Foswiki::Meta->new( $this->{session}, $web, $topic );
    $new->copyFrom( $meta, 'FIELD', qr/^(a|b)$/ );
    $new->forEachSelectedValue( qr/^FIELD$/, qr/^value$/, \&fleegle, $d );
    $this->assert( $d->{collected} =~ s/FIELD.value:aval;// );
    $this->assert( $d->{collected} =~ s/FIELD.value:bval;// );
    $this->assert_str_equals( "", $d->{collected} );
}

1;
