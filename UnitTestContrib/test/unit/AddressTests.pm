package AddressTests;
use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Assert;
use Data::Dumper;
use Benchmark qw(:hireswallclock);
use Foswiki::Address();
use constant TRACE => 0;

my $FoswikiSESSION;
my $test_web  = 'Temporary' . __PACKAGE__ . 'TestWeb';
my %testrange = (
    webs => [
        [$test_web],
        [ 'Missing' . $test_web ],
        [ $test_web,             'SubWeb' ],
        [ $test_web,             'MissingSubWeb' ],
        [ 'Missing' . $test_web, 'MissingSubWeb' ],
        [ $test_web,             'SubWeb',        'SubSubWeb' ],
        [ $test_web,             'SubWeb',        'MissingSubSubWeb' ],
        [ $test_web,             'MissingSubWeb', 'MissingSubSubWeb' ],
        [ 'Missing' . $test_web, 'MissingSubWeb', 'MissingSubSubWeb' ]
    ],
    topics      => [ undef, 'Topic', 'MissingTopic' ],
    attachments => [
        undef,               'Attachment',
        'Attach.ent',        'Atta.h.ent',
        'MissingAttachment', 'MissingAttach.ent',
        'MissingAtta.h.ent'
    ],
    revs            => [ undef, 2 ],
    webseparators   => [ '/',   '.' ],
    topicseparators => [ '/',   '.' ]
);
my %testitems;
my $done_init;

sub new {
    my ( $class, @args ) = @_;
    my $this = $class->SUPER::new(@args);

    $this->{test_web}   = $test_web;
    $this->{test_topic} = 'TestTopic' . $class;
    $this->gen_test_fns();

    return $this;
}

sub set_up {
    my ($this) = @_;

    # We don't want the overhead of creating a new session for each tests
    if ( not $done_init ) {
        my $query = Unit::Request->new("");
        $this->SUPER::set_up();
        $query->path_info("/$this->{test_web}/$this->{test_topic}");

        #$this->{session}->finish();
        $this->{session} =
          Foswiki->new( $Foswiki::cfg{AdminUserLogin}, $query );

        # SMELL: Why do I need to set this? I don't get our unit tests...
        #$this->{session}->{webName} = $this->{test_web};

        $this->{test_topicObject} = Foswiki::Meta->new(
            $this->{session},    $this->{test_web},
            $this->{test_topic}, "BLEEGLE\n"
        );

        $this->gendata( \%testrange );
        $Foswiki::Plugins::SESSION = $this->{session};
        $FoswikiSESSION            = $this->{session};
        $done_init                 = 1;
    }
    else {
        $this->{session} = $FoswikiSESSION;

        #$Foswiki::Plugins::SESSION = $this->{session};
    }

    return;
}

# We don't want the overhead of creating a new session for each tests, so this
# does nothing.
sub tear_down {
    return;
}

sub gendata {
    my ( $this, $range ) = @_;
    my %created;

    foreach my $webpath ( @{ $range->{webs} } ) {
        if ($webpath) {
            my $web = join( '/', @{$webpath} );

            if ( $web and not $created{webs}{$web} and not $web =~ /Missing/ ) {
                print "gendata(): web $web\n" if TRACE;
                Foswiki::Func::createWeb($web);
                $this->gentopics( $web, $range );
                $created{webs}{$web} = 1;
            }
        }
    }

    return;
}

sub gentopics {
    my ( $this, $web, $range ) = @_;
    my $tmpdir = Foswiki::Func::getWorkArea('UnitTestContrib');

    print "gentopics(): Working on web $web\n" if TRACE;
    foreach my $topic ( @{ $range->{topics} } ) {
        if ( $topic and not $topic =~ /^Missing/ ) {
            my $filedata = "This is file: $web.$topic";

            print "gentopics(): \tWorking on topic $topic\n" if TRACE;
            foreach my $rev ( @{ $range->{revs} } ) {
                if ( defined $rev ) {
                    print "gentopics(): \t\tWorking on rev $rev\n" if TRACE;
                    Foswiki::Func::saveTopic( $web, $topic, undef,
                        <<"HERE", { forcenewrevision => 1 } );
This is topic: $web.$topic @ $rev
HERE
                    foreach my $attachment ( @{ $range->{attachments} } ) {
                        if ( defined $attachment
                            and not $attachment =~ /^Missing/ )
                        {
                            my $filepath =
                              File::Spec->catfile(
                                File::Spec->splitdir($tmpdir), $attachment )
                              or die $!;

                            open( my $fh, '>', $filepath )
                              or die "Couldn't open $filepath, '$filedata': $!";
                            print $fh "$filedata/$attachment @ $rev";
                            close($fh);
                            open( $fh, '<', $filepath );
                            print "gentopics(): \t\tattachment $attachment\n"
                              if TRACE;
                            Foswiki::Func::saveAttachment( $web, $topic,
                                $attachment, { stream => $fh } );
                            close($fh);
                        }
                    }
                }
            }
        }
    }

    return;
}

sub test_nothing {
    my ($this) = @_;

    return;
}

sub gen_test_fns {
    my ($this) = @_;

    if ( not scalar( keys %testitems ) ) {
        %testitems = $this->gen_tests( \%testrange );
    }
    while ( my ( $testname, $testitem ) = each %testitems ) {
        my $fn = __PACKAGE__ . '::test_' . $testname;
        my %extraopts;

        no strict 'refs';
        *{$fn} = sub {
            my $parsedObjAddr = Foswiki::Address->new(
                string => $testitem->{objAddr}->stringify(),
                %extraopts
            );

            ASSERT( $parsedObjAddr->equiv( $testitem->{objAddr} ) );

            return;
        };
        use strict 'refs';
    }

    return;
}

sub list_tests {
    my ( $this, $suite ) = @_;
    my @testnames;

    if ( not scalar( keys %testitems ) ) {
        %testitems = $this->gen_tests( \%testrange );
    }
    foreach my $testname ( keys %testitems ) {
        push( @testnames, __PACKAGE__ . '::test_' . $testname );
    }

    return @testnames, $this->SUPER::list_tests($suite);
}

sub gen_tests {
    my ( $this, $range ) = @_;
    my %tests;

    foreach my $webseparator ( @{ $range->{webseparators} } ) {
        foreach my $topicseparator ( @{ $range->{topicseparators} } ) {
            foreach my $webs ( @{ $range->{webs} } ) {
                foreach my $topic ( @{ $range->{topics} } ) {
                    foreach my $attachment ( @{ $range->{attachments} } ) {
                        foreach my $rev ( @{ $range->{revs} } ) {
                            if (
                                $webs
                                and ( not defined $attachment and defined $topic
                                    or defined $topic )
                              )
                            {
                                my $objAddr = Foswiki::Address->new(
                                    webseparator   => $webseparator,
                                    topicseparator => $topicseparator,
                                    webs           => $webs,
                                    topic          => $topic,
                                    attachment     => $attachment,
                                    rev            => $rev
                                );
                                my $name = 'range_' . $objAddr->stringify();

                                $name =~ s/\//_sl_/g;
                                $name =~ s/\./_dt_/g;
                                $name =~ s/\@/_at_/g;
                                $tests{$name} = { objAddr => $objAddr };
                            }
                        }
                    }
                }
            }
        }
    }

    return %tests;
}

sub test_meta1 {
    my ($this) = @_;
    my $objAddr = Foswiki::Address->new(
        webs          => [ $test_web, 'SubWeb' ],
        topic         => 'Topic',
        rev           => '2',
        meta          => 'FIELD',
        metamember    => 'Colour',
        metamemberkey => 'name',
        metakey       => 'value'
    );
    my $parsedObjAddr = Foswiki::Address->new(
        string  => $objAddr->stringify(),
        existAs => [qw(attachment meta topic)]
    );

    ASSERT( $parsedObjAddr->equiv($objAddr) );

    return;
}

sub test_meta2 {
    my ($this) = @_;
    my $objAddr = Foswiki::Address->new(
        webs       => [ $test_web, 'SubWeb' ],
        topic      => 'Topic',
        rev        => '2',
        meta       => 'FIELD',
        metamember => 2,
        metakey    => 'value'
    );
    my $parsedObjAddr = Foswiki::Address->new(
        string  => $objAddr->stringify(),
        existAs => [qw(attachment meta topic)]
    );

    ASSERT( $parsedObjAddr->equiv($objAddr) );
    ASSERT( $parsedObjAddr->type() eq 'metakey' );
    $parsedObjAddr->metakey(undef);
    ASSERT( $parsedObjAddr->type() eq 'metamember' );
    $parsedObjAddr->metamember(undef);
    ASSERT( $parsedObjAddr->type() eq 'meta' );
    $parsedObjAddr->meta(undef);
    ASSERT( $parsedObjAddr->type() eq 'topic' );

    return;
}

sub test_meta3 {
    my ($this) = @_;
    my $objAddr = Foswiki::Address->new(
        webs          => [ $test_web, 'SubWeb' ],
        topic         => 'Topic',
        rev           => '2',
        meta          => 'FIELD',
        metamember    => 'Colour',
        metamemberkey => 'name',
        metakey       => 'value'
    );
    my $parsedObjAddr = Foswiki::Address->new(
        string  => "'$test_web/SubWeb.Topic\@2'/fields[name='Colour'].value",
        existAs => [qw(attachment meta topic)]
    );

    ASSERT( $parsedObjAddr->equiv($objAddr) );
    ASSERT( $parsedObjAddr->type() eq 'metakey' );

    return;
}

sub test_meta4 {
    my ($this) = @_;
    my $objAddr = Foswiki::Address->new(
        webs          => [ $test_web, 'SubWeb' ],
        topic         => 'Topic',
        rev           => '2',
        meta          => 'FIELD',
        metamember    => 'Colour',
        metamemberkey => 'name',
        metakey       => 'value'
    );
    my $parsedObjAddr = Foswiki::Address->new(
        string  => "'$test_web/SubWeb.Topic\@2'/Colour",
        existAs => [qw(attachment meta topic)]
    );

    ASSERT( $parsedObjAddr->equiv($objAddr) );
    ASSERT( $parsedObjAddr->type() eq 'metakey' );

    return;
}

sub test_timing_normaliseWebTopicName {
    my ($this) = @_;
    my $web;
    my $topic;
    my $benchmark = timeit(
        15000,
        sub {
            ( $web, $topic ) =
              Foswiki::Func::normalizeWebTopicName( '', 'Web/SubWeb.Topic' );
        }
    );

    print timestr($benchmark) . "\n";

    return;
}

sub test_timing_normaliseWebTopicName_default {
    my ($this) = @_;
    my $web;
    my $topic;
    my $benchmark = timeit(
        20000,
        sub {
            ( $web, $topic ) =
              Foswiki::Func::normalizeWebTopicName( 'Web/SubWeb', 'Topic' );
        }
    );

    print timestr($benchmark) . "\n";

    return;
}

sub test_timing_normaliseWebTopicName_equiv {
    my ($this) = @_;
    my $addr;
    my $benchmark = timeit(
        10000,
        sub {
            $addr = Foswiki::Address->new(
                string => 'Web/SubWeb.Topic',
                isA    => 'topic'
            );
        }
    );

    print timestr($benchmark) . "\n";

    return;
}

sub test_timing_normaliseWebTopicName_equiv_default {
    my ($this) = @_;
    my $addr;
    my $benchmark = timeit(
        10000,
        sub {
            $addr = Foswiki::Address->new(
                string => 'Topic',
                isA    => 'topic',
                web    => 'Web/SubWeb'
            );
        }
    );

    print timestr($benchmark) . "\n";

    return;
}

sub test_timing_creation {
    my ($this) = @_;
    my $addr;
    my $benchmark = timeit(
        100000,
        sub {
            $addr = Foswiki::Address->new(
                webs       => [qw(Web SubWeb)],
                topic      => 'Topic',
                attachment => 'Attachment.pdf',
                rev        => 3
            );
        }
    );

    print timestr($benchmark) . "\n";

    return;
}

sub test_timing_hashref_creation {
    my ($this) = @_;
    my $addr;
    my $benchmark = timeit(
        200000,
        sub {
            $addr = {
                webs       => [qw(Web SubWeb)],
                topic      => 'Topic',
                attachment => 'Attachment.pdf',
                rev        => 3
            };
        }
    );

    print timestr($benchmark) . "\n";

    return;
}

sub test_timing_reparse_default {
    my ($this) = @_;
    my $addr =
      Foswiki::Address->new( topic => 'Topic', webs => [qw(Web SubWeb)] );
    my $benchmark = timeit(
        15000,
        sub {
            $addr->parse(
                'AnotherTopic',
                isA  => 'topic',
                webs => [qw(OtherWeb OtherSubWeb)]
            );
        }
    );

    print timestr($benchmark) . "\n";

    return;
}

sub test_timing_reparse {
    my ($this) = @_;
    my $addr =
      Foswiki::Address->new( topic => 'Topic', webs => [qw(Web SubWeb)] );
    my $benchmark = timeit(
        15000,
        sub {
            $addr->parse(
                'AnotherWeb/AnotherSubWeb.AnotherTopic',
                isA  => 'topic',
            );
        }
    );

    print timestr($benchmark) . "\n";

    return;
}

1;
