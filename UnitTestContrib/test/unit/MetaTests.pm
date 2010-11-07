# Smoke tests for Foswiki::Meta

require 5.006;
use strict;

package MetaTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

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

my $web   = "TemporaryZoopyDoopy";
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
    $this->removeWebFixture( $this->{session}, $web )
      if $this->{session}->webExists($web);
    $this->SUPER::tear_down();
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

# Field with value 0 and value ''  This does not cover Item8738
sub test_zero_empty {
    my $this = shift;
    my $meta = Foswiki::Meta->new( $this->{session}, $web, $topic );

    my $args_zero = {
        name  => "a",
        value => "0"
    };
    
    my $args_empty = {
        name  => "b",
        value => ""
    };

    $meta->putKeyed( "FIELD", $args_zero );
    $meta->putKeyed( "FIELD", $args_empty );
    
    my $vals1 = $meta->get( "FIELD", "a" );
    $this->assert_str_equals( $vals1->{"name"},  "a" );
    $this->assert_str_equals( $vals1->{"value"}, "0" );

    my $vals2 = $meta->get( "FIELD", "b" );      
    $this->assert_str_equals( $vals2->{"name"},  "b" );
    $this->assert_str_equals( $vals2->{"value"}, "" );
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

sub test_parent {
    my $this = shift;
    my $webObject = Foswiki::Meta->new( $this->{session}, $web );
    $webObject->populateNewWeb();

    my $testTopic = "TestParent";
    for my $depth ( 1 .. 5 ) {
        my $child  = $testTopic . $depth;
        my $parent = $testTopic . ( $depth + 1 );
        my $text   = "This is ancestor number $depth";
        my $topicObject =
          Foswiki::Meta->new( $this->{session}, $web, $child, $text );
        $topicObject->put( "TOPICPARENT", { name => $parent } );
        $topicObject->save();
    }
    my $topicObject = Foswiki::Meta->new(
        $this->{session}, $web,
        $testTopic . '6',
        'Final ancestor'
    );
    $topicObject->save();

    for my $depth ( 1 .. 5 ) {
        my $child       = $testTopic . $depth;
        my $topicObject = Foswiki::Meta->load( $this->{session}, $web, $child );
        my $parent      = $topicObject->getParent();
        $this->assert_str_equals(
            $parent,
            $testTopic . ( $depth + 1 ),
            "getParent failed at depth $depth"
        );

        # Test basic parent
        my $str = $topicObject->expandMacros('%META{"parent"}%');
        $this->assert_str_equals(
            $str,
            join( " &gt; ",
                map { "[[$web.$testTopic$_][$testTopic$_]]" }
                  reverse $depth + 1 .. 6 )
        );

        # Test norecurse
        $str = $topicObject->expandMacros('%META{"parent" dontrecurse="on"}%');
        $this->assert_str_equals( $str, "[[$web.$parent][$parent]]" );

        # Test depth
        for my $subDepth ( 1 .. 5 - $depth ) {
            $str = $topicObject->expandMacros(
                '%META{"parent" depth="' . $subDepth . '"}%' );
            my $parentDepth = $subDepth + $depth;
            $this->assert_str_equals( $str,
                "[[$web.${testTopic}$parentDepth][${testTopic}$parentDepth]]" );
        }

        # Test prefix and suffix
        $str = $topicObject->expandMacros(
            '%META{"parent" prefix="Before" suffix="After"}%');
        $this->assert_str_equals(
            $str,
            "Before"
              . join( " &gt; ",
                map { "[[$web.$testTopic$_][$testTopic$_]]" }
                  reverse $depth + 1 .. 6 )
              . "After"
        );

        # Test format
        $str =
          $topicObject->expandMacros('%META{"parent" format="$web.$topic"}%');
        $this->assert_str_equals(
            $str,
            join( " &gt; ",
                map { "$web.$testTopic$_" } reverse $depth + 1 .. 6 )
        );

        # Test separator
        $str = $topicObject->expandMacros('%META{"parent" separator=" << "}%');
        $this->assert_str_equals(
            $str,
            join( " << ",
                map { "[[$web.$testTopic$_][$testTopic$_]]" }
                  reverse $depth + 1 .. 6 )
        );

    }

    # Test nowebhome
    $topicObject = Foswiki::Meta->new(
        $this->{session}, $web,
        $testTopic . '6',
        'Final ancestor with WebHome as parent'
    );
    $topicObject->put( "TOPICPARENT",
        { name => $web . '.' . $Foswiki::cfg{HomeTopicName} } );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->load( $this->{session}, $web, $testTopic . '1' );
    my $str = $topicObject->expandMacros('%META{"parent"}%');
    $this->assert_str_equals(
        $str,
        join( " &gt; ",
            map { "[[$web.$_][$_]]" }
              ( 'WebHome', map { "$testTopic$_" } reverse 2 .. 6 ) )
    );
    $str = $topicObject->expandMacros('%META{"parent" nowebhome="on"}%');
    $this->assert_str_equals(
        $str,
        join( " &gt; ",
            map { "[[$web.$testTopic$_][$testTopic$_]]" } reverse 2 .. 6 )
    );
}

# Note: for full coverage, there needs to be at least one plugin with
# a beforeUploadHandler (and one with a beforeAttachmentHandler) for
# each of the following three attachment modes. Therefore they are repeated
# during the store tests.
sub test_attach_stream {
    my $this = shift;

    my $temp = new File::Temp();
    print $temp 'eeza stream';
    # $fh->seek only in File::Temp 0.17 and later
    seek($temp,0,0);
    $this->{test_topicObject}->attach(
        name => 'dis.dat', stream => $temp);
    $this->assert(close($temp));

    my $fh = $this->{test_topicObject}->openAttachment('dis.dat', '<');
    my $x = <$fh>;
    close($fh);
    $this->assert_str_equals('eeza stream', $x);
}

sub test_attach_file {
    my $this = shift;

    my $temp = new File::Temp();
    print $temp 'eeza file';
    # $fh->seek only in File::Temp 0.17 and later
    seek($temp,0,0);
    $this->{test_topicObject}->attach(
        name => 'dis.dat', file => $temp->filename);
    $this->assert(close($temp));

    my $fh = $this->{test_topicObject}->openAttachment('dis.dat', '<');
    my $x = <$fh>;
    close($fh);
    $this->assert_str_equals('eeza file', $x);
}

sub test_attach_file_and_stream{
    my $this = shift;

    my $temp = new File::Temp();
    print $temp 'eeza file and a stream';
    # $fh->seek only in File::Temp 0.17 and later
    seek($temp,0,0);
    $this->{test_topicObject}->attach(
        name => 'dis.dat', stream => $temp, file => $temp->filename);
    $this->assert(close($temp));

    my $fh = $this->{test_topicObject}->openAttachment('dis.dat', '<');
    my $x = <$fh>;
    close($fh);
    $this->assert_str_equals('eeza file and a stream', $x);
}

sub test_attachmentStreams {
    my $this = shift;

    #--- Simple write and read
    my $fh = $this->{test_topicObject}->openAttachment('dis.dat', '>');
    $this->assert($fh);
    print $fh 'Twas brillig, and the slithy toves';
    close($fh);

    $fh = $this->{test_topicObject}->openAttachment('dis.dat', '<');
    $this->assert($fh);
    local $/;
    my $x = <$fh>;
    close($fh);
    $this->assert_str_equals('Twas brillig, and the slithy toves', $x);

    #--- Appending write
    $fh = $this->{test_topicObject}->openAttachment('dis.dat', '>>');
    $this->assert($fh);
    print $fh " did gyre and gimbal in the wabe";
    close($fh);

    $fh = $this->{test_topicObject}->openAttachment('dis.dat', '<');
    $x = <$fh>;
    close($fh);
    $this->assert_str_equals('Twas brillig, and the slithy toves did gyre and gimbal in the wabe', $x);

    #--- Reading older versions

    # Rev 1
    $fh = $this->{test_topicObject}->openAttachment('dis.dat', '<');
    $this->{test_topicObject}->attach(
        name => 'dat.dis',
        dontlog => 1,
        comment => "Shiver me timbers",
        hide => 0,
        stream => $fh);
    close($fh);

    # Rev 2
    $fh = $this->{test_topicObject}->openAttachment('dis.dat', '>');
    $this->assert($fh);
    print $fh "All mimsy were the borogroves";
    close($fh);

    $fh = $this->{test_topicObject}->openAttachment('dis.dat', '<');
    $this->{test_topicObject}->attach(
        name => 'dat.dis',
        dontlog => 1,
        comment => "Pieces of eight",
        hide => 0,
        stream => $fh);
    close($fh);
    $this->assert_equals(2, $this->{test_topicObject}->getLatestRev('dat.dis'));

    # Latest rev (rev 2)
    $fh = $this->{test_topicObject}->openAttachment( 'dat.dis', '<');
    $x = <$fh>;
    close($fh);
    $this->assert_str_equals('All mimsy were the borogroves', $x);

    $fh = $this->{test_topicObject}->openAttachment(
        'dat.dis', '<', version => 1);
    $x = <$fh>;
    close($fh);
    $this->assert_str_equals('Twas brillig, and the slithy toves did gyre and gimbal in the wabe', $x);

    $fh = $this->{test_topicObject}->openAttachment(
        'dat.dis', '<', version => 2);
    $x = <$fh>;
    close($fh);
    $this->assert_str_equals('All mimsy were the borogroves', $x);
}

sub test_testAttachment {
    my $this = shift;

    my $fh = $this->{test_topicObject}->openAttachment('dis.dat', '>');
    print $fh "No! Not the bore worms!";
    close($fh);

    $fh = $this->{test_topicObject}->openAttachment('dis.dat', '<');
    $this->{test_topicObject}->attach(
        name => 'dat.dis',
        dontlog => 1,
        comment => "Pieces of eight",
        hide => 0,
        stream => $fh);

    my $t = time;
    $this->assert($this->{test_topicObject}->hasAttachment('dat.dis'));

    $this->assert($this->{test_topicObject}->testAttachment('dat.dis', 'e'));
    $this->assert($this->{test_topicObject}->testAttachment('dat.dis', 'r'));
    $this->assert($this->{test_topicObject}->testAttachment('dat.dis', 'w'));
    $this->assert(!$this->{test_topicObject}->testAttachment('dat.dis', 'z'));
    $this->assert_equals(23, $this->{test_topicObject}->testAttachment('dat.dis', 's'));
    $this->assert($this->{test_topicObject}->testAttachment('dat.dis', 'T'));
    $this->assert(!$this->{test_topicObject}->testAttachment('dat.dis', 'B'));
    $this->assert($t, $this->{test_topicObject}->testAttachment('dat.dis', 'M'));
    $this->assert($t, $this->{test_topicObject}->testAttachment('dat.dis', 'A'));
}

# Make sure that badly-formed meta tags in text are validated on save
sub test_validateMetaTagsInText {
    my $this = shift;
    my $gunk = <<GUNK;
%META{"form"}%
%META{"formfield" name="bad"}%
%META{"attachments"}%
%META{"parent"}%
%META{"moved"}%
GUNK
    my $text = <<EVIL;
%META:TOPICINFO{bad="bad"}%
%META:TOPICPARENT{bad="bad"}%
%META:FORM{bad="bad"}%
%META:FIELD{bad="bad"}%
%META:FILEATTACHMENT{bad="bad"}%
%META:TOPICMOVED{bad="bad"}%
$gunk
EVIL
    my $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "BadMeta", $text );
    $topicObject->save();
    # All meta should have found its way into text
    $this->assert_equals($text, $topicObject->text()."\n");
    $topicObject->expandMacros($topicObject->text());
    $topicObject->expandNewTopic();
    $topicObject->renderTML($topicObject->text());
    $topicObject->renderFormForDisplay();
    $text = $topicObject->text();
    $this->assert_matches(qr/%META:TOPICINFO{bad="bad"}%/, $text);
    $this->assert_matches(qr/%META:TOPICPARENT{bad="bad"}%/, $text);
    $this->assert_matches(qr/%META:FORM{bad="bad"}%/, $text);
    $this->assert_matches(qr/%META:FIELD{bad="bad"}%/, $text);
    $this->assert_matches(qr/%META:FILEATTACHMENT{bad="bad"}%/, $text);
    $this->assert_matches(qr/%META:TOPICMOVED{bad="bad"}%/, $text);
    $this->assert_does_not_match(qr/%META:TOPICMOVED{}%/, $text);

    # Item2554
    $text = <<EVIL;
%META:TOPICPARENT{}%
EVIL
    $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "BadMeta", $text );
    $topicObject->save();
    $text = $topicObject->text();
    $this->assert_does_not_match(qr/%META:TOPICPARENT{}%/, $text);

    $text = <<GOOD;
%META:TOPICINFO{version="1" date="9876543210" author="AlbertCamus" format="1.1"}%
%META:TOPICPARENT{name="System.UserForm"}%
%META:FORM{name="System.UserForm"}%
%META:FIELD{name="Profession" value="Saint"}%
%META:FILEATTACHMENT{name="sausage.gif"}%
%META:TOPICMOVED{from="here" to="there" by="her" date="1234567890"}%
$gunk
GOOD
    $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "GoodMeta", $text );
    $topicObject->save();
    $this->assert_equals($gunk, $topicObject->text());
    $topicObject->expandMacros($topicObject->text());
    $topicObject->expandNewTopic();
    $topicObject->renderTML($topicObject->text());
    $topicObject->renderFormForDisplay();
}

sub test_registerMETA {
    my $this = shift;

    my $o = Foswiki::Meta->new( $this->{session} );

    # Check an unregistered tag
    $this->assert($o->isValidEmbedding(
        'TREE', { type => 'ash', height => '15' }));
    $this->assert($o->isValidEmbedding( 'TREE', { }));

    # required param
    Foswiki::Func::registerMETA('TREE', require => [ 'spread' ]);
    $this->assert(!$o->isValidEmbedding( 'TREE', { }));
    $this->assert(!$o->isValidEmbedding(
        'TREE', { type => 'ash', height => '15' }));
    $this->assert($o->isValidEmbedding(
        'TREE', { type => 'ash', height => '15', spread=>'5' }));

    # required param and allowed param
    Foswiki::Func::registerMETA('TREE', require => [ 'spread' ],
                     allow => [ 'height' ]);
    $this->assert(!$o->isValidEmbedding(
        'TREE', { type => 'ash', height => '15', spread=>'5' }));
    $this->assert($o->isValidEmbedding(
        'TREE', { spread => '5', height => '15' }));

    # Function and require.
    Foswiki::Func::registerMETA('TREE', require => [ 'height' ],
                               function => sub {
                                   my ($name, $args) = @_;
                                   $this->assert_equals('TREE', $name);
                                   return $args->{spread};
                               });
    $this->assert(!$o->isValidEmbedding(
        'TREE', { height=>10 }));

    # required param, allowed param and function
    Foswiki::Func::registerMETA('TREE', require => [ 'spread' ],
                               allow => [ 'height' ],
                               function => sub {
                                   my ($name, $args) = @_;
                                   $this->assert_equals('TREE', $name);
                                   $this->assert($args->{spread});
                                   $this->assert($args->{height});
                                   return 1;
                               });
    $this->assert($o->isValidEmbedding(
        'TREE', { spread=>15, height=>10 }), $Foswiki::Meta::reason);

    # allowed param only, function rewrites args
    Foswiki::Func::registerMETA('TREE', allow => [ 'height' ],
                               function => sub {
                                   my ($name, $args) = @_;
                                   $this->assert_equals('TREE', $name);
                                   delete $args->{spread};
                                   return 1;
                               });
    $this->assert(!$o->isValidEmbedding(
        'TREE', { type => 'elm', height => '15' }));
    $this->assert($o->isValidEmbedding(
        'TREE', { height => '15' }));
    $this->assert($o->isValidEmbedding(
        'TREE', { spread => '5', height => '15' }));
}

# Item9948
sub test_registerArrayMeta {
    my $this = shift;
    my $test = <<'TEST';
Properties: %QUERY{"META:SLPROPERTY.name"}%
A property: %QUERY{"slug[name='PreyOf'].values"}%
Values: %QUERY{"META:SLPROPERTYVALUE.value"}%
TEST
    my $text = <<'HERE';
%META:SLPROPERTYVALUE{name="System.SemanticIsPartOf__1" value="System.UserDocumentationCategory"}%
%META:SLPROPERTYVALUE{name="Example.Property__1" value="UserDocumentationCategory"}%
%META:SLPROPERTYVALUE{name="PreyOf__1" value="Snakes"}%
%META:SLPROPERTYVALUE{name="Eat__1" value="Mosquitos"}%
%META:SLPROPERTYVALUE{name="Eat__2" value="Flies"}%
%META:SLPROPERTYVALUE{name="IsPartOf__1" value="UserDocumentationCategory"}%
%META:SLPROPERTY{name="System.SemanticIsPartOf" values="System.UserDocumentationCategory"}%
%META:SLPROPERTY{name="Example.Property" values="UserDocumentationCategory"}%
%META:SLPROPERTY{name="PreyOf" values="Snakes"}%
%META:SLPROPERTY{name="Eat" values="Mosquitos,Flies"}%
%META:SLPROPERTY{name="IsPartOf" values="UserDocumentationCategory"}%
HERE
    Foswiki::Meta::registerMETA(
        'SLPROPERTY',
        many => 1,
	alias => 'slug',
        require => [qw(name values)],
    );
    Foswiki::Meta::registerMETA(
        'SLPROPERTYVALUE',
        many => 1,
        require => [qw(name value)],
    );
    my $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "registerArrayMetaTest", $text );
    $topicObject->save();
    # All meta should have found its way into text
    $this->assert_equals(<<'EXPECTED', $topicObject->expandMacros($test));
Properties: System.SemanticIsPartOf,Example.Property,PreyOf,Eat,IsPartOf
A property: Snakes
Values: System.UserDocumentationCategory,UserDocumentationCategory,Snakes,Mosquitos,Flies,UserDocumentationCategory
EXPECTED
}

# Item9948
sub test_registerScalarMeta {
    my $this = shift;
    my $test = <<'TEST';
Properties: %QUERY{"META:SLPROPERTY.name"}%
Alias: %QUERY{"slug.name"}%
Values: %QUERY{"META:SLPROPERTYVALUE.value"}%
TEST
    my $text = <<'HERE';
%META:SLPROPERTYVALUE{name="System.SemanticIsPartOf__1" value="System.UserDocumentationCategory"}%
%META:SLPROPERTYVALUE{name="Example.Property__1" value="UserDocumentationCategory"}%
%META:SLPROPERTYVALUE{name="PreyOf__1" value="Snakes"}%
%META:SLPROPERTYVALUE{name="Eat__1" value="Mosquitos"}%
%META:SLPROPERTYVALUE{name="Eat__2" value="Flies"}%
%META:SLPROPERTYVALUE{name="IsPartOf__1" value="UserDocumentationCategory"}%
%META:SLPROPERTY{name="System.SemanticIsPartOf" values="System.UserDocumentationCategory"}%
%META:SLPROPERTY{name="Example.Property" values="UserDocumentationCategory"}%
%META:SLPROPERTY{name="PreyOf" values="Snakes"}%
%META:SLPROPERTY{name="Eat" values="Mosquitos,Flies"}%
%META:SLPROPERTY{name="IsPartOf" values="UserDocumentationCategory"}%
HERE
    Foswiki::Meta::registerMETA(
        'SLPROPERTY',
	alias => 'slug',
        require => [qw(name values)],
    );
    Foswiki::Meta::registerMETA(
        'SLPROPERTYVALUE',
        require => [qw(name value)],
    );
    my $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "registerArrayMetaTest", $text );
    $topicObject->save();
    # All meta should have found its way into text
    $this->assert_equals(<<'EXPECTED', $topicObject->expandMacros($test));
Properties: System.SemanticIsPartOf
Alias: System.SemanticIsPartOf
Values: System.UserDocumentationCategory
EXPECTED
}

#lets see what happens when we use silly TOPICINFO
#http://foswiki.org/Tasks/Item2274
sub test_BadRevisionInfo {
    my $this = shift;
    
    my $in = '$Rev$';
    my $rev = Foswiki::Store::cleanUpRevID($in);
    $this->assert(defined($rev));
    $this->assert_equals(0, $rev);

    #svn attribute not set - still a valid topic.
    my $broken = '$'.'Rev'.'$'; #stop svn from filling in the number..
    $rev = Foswiki::Store::cleanUpRevID($broken);
    $this->assert(defined($rev));
    $this->assert_equals(0, $rev);

    #we recognise a txt file that has not been written by foswiki as rev=0
    $rev = Foswiki::Store::cleanUpRevID('');
    $this->assert(defined($rev));
    $this->assert_equals(0, $rev);

}

sub test_getRevisionHistory {
    my $this = shift;
    my $topicObject = Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, 'RevIt', "Rev 1" );
    $this->assert_equals(1, $topicObject->save());
    $topicObject =
      Foswiki::Meta->load($this->{session}, $this->{test_web}, 'RevIt' );
    my $revIt  = $topicObject->getRevisionHistory();
    $this->assert($revIt->hasNext());
    $this->assert_equals(1, $revIt->next());
    $this->assert(!$revIt->hasNext());

    $topicObject->text('Rev 2');
    $this->assert_equals(
        2, $topicObject->save(forcenewrevision => 1));
    $topicObject =
      Foswiki::Meta->load($this->{session}, $this->{test_web}, 'RevIt' );
    $revIt  = $topicObject->getRevisionHistory();
    $this->assert($revIt->hasNext());
    $this->assert_equals(2, $revIt->next());
    $this->assert($revIt->hasNext());
    $this->assert_equals(1, $revIt->next());
    $this->assert(!$revIt->hasNext());

    $topicObject->text('Rev 3');
    $this->assert_equals(
        3, $topicObject->save(forcenewrevision => 1));
    $topicObject =
      Foswiki::Meta->load($this->{session}, $this->{test_web}, 'RevIt' );
    $revIt  = $topicObject->getRevisionHistory();
    $this->assert($revIt->hasNext());
    $this->assert_equals(3, $revIt->next());
    $this->assert($revIt->hasNext());
    $this->assert_equals(2, $revIt->next());
    $this->assert($revIt->hasNext());
    $this->assert_equals(1, $revIt->next());
    $this->assert(!$revIt->hasNext());
}

# Disabled as XML functionnality has been removed from the core, see Foswikitask:Item1917
# sub testXML_topic {
#     my $this = shift;
# 
#     my $text = <<GOOD;
# %META:TOPICINFO{version="1.2" date="9876543210" author="AlbertCamus" format="1.1"}%
# %META:TOPICPARENT{name="System.UserForm"}%
# %META:FORM{name="System.UserForm"}%
# %META:FIELD{name="Profession" value="Saint"}%
# %META:FILEATTACHMENT{name="sausage.gif"}%
# %META:TOPICMOVED{from="here" to="there" by="her" date="1234567890"}%
# Green eggs and ham
# GOOD
#     my $expected = <<'XML';
# <topic name="GoodMeta" format="1.1" date="@REX(\d+)" version="1.2" rev="2" author="AlbertCamus">
#  <form name="System.UserForm">
#   <field value="Saint" name="Profession" />
#  </form>
#  <fileattachment name="sausage.gif" />
#  <topicmoved to="there" date="@REX(\d+)" from="here" by="her" />
#  <topicparent name="System.UserForm" />
#  <body>
#   <![CDATA[Green eggs and ham]]>
#  </body>
# </topic>
# XML
#     my $topicObject =
#       Foswiki::Meta->new(
#           $this->{session}, $this->{test_web}, "GoodMeta", $text );
#     my $xml = $topicObject->xml();
#     $this->assert_html_equals($expected, $xml);
# }
# 
# sub testXML_web {
#     my $this = shift;
#     my $webObject = Foswiki::Meta->new( $this->{session}, "$this->{test_web}/SubWeb" );
#     $webObject->populateNewWeb();
#     my $expected = <<'XML';
# <web name="SubWeb">
#  <topic name="WebPreferences" format="1.1" version="1.1" date="@REX(\d+)" rev="1" author="BaseUserMapping_666">
#   <body><![CDATA[Preferences]]>
#   </body>
#  </topic>
# </web>
# XML
#     my $xml = $webObject->xml();
#     $this->assert_html_equals($expected, $xml);
# 
#     $expected = <<'XML';
# <web name="TemporaryMetaTestsTestWebMetaTests">
#  <web name="SubWeb">
#   <topic name="WebPreferences" format="1.1" version="1.1" date="@REX(\d+)" rev="1" author="BaseUserMapping_666">
#    <body><![CDATA[Preferences]]>
#    </body>
#   </topic>
#  </web>
# </web>
# XML
#     $xml = $webObject->xml(1);
#     $this->assert_html_equals($expected, $xml);
# 
#     $expected = <<'XML';
# <web name="TemporaryMetaTestsTestWebMetaTests">
#  <topic name="TestTopicMetaTests" format="1.1" version="1.1" date="@REX(\d+)" rev="1" author="BaseUserMapping_666">
#   <body>
#    <![CDATA[BLEEGLE
# ]]>
#   </body>
#  </topic>
#  <topic name="WebPreferences" format="1.1" version="1.1" date="@REX(\d+)" rev="1" author="BaseUserMapping_666">
#   <body>
#    <![CDATA[Preferences]]>
#   </body>
#  </topic>
#  <web name="SubWeb">
#   <topic name="WebPreferences" format="1.1" version="1.1" date="@REX(\d+)" rev="1" author="BaseUserMapping_666">
#    <body><![CDATA[Preferences]]>
#    </body>
#   </topic>
#  </web>
# </web>
# XML
#     my $topicObject =
#       Foswiki::Meta->new( $this->{session}, $this->{test_web} );
#     $xml = $topicObject->xml();
#     $this->assert_html_equals($expected, $xml);
# }

1;
