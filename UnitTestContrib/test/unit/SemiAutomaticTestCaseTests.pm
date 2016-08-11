package SemiAutomaticTestCaseTests;
use v5.14;

use Foswiki;
use Try::Tiny;

use Foswiki::Class;
use namespace::clean;
extends qw( FoswikiFnTestCase );

my $VIEW_UI_FN;

# Some data used only by TestCaseAutoSearchOrder
my @test_comma_v = (
    <<'T1',
head	1.1;
access;
symbols;
locks; strict;
comment	@# @;
expand	@o@;


1.1
date	2005.12.14.21.56.33;	author KennethLavrsen;	state Exp;
branches;
next	;


desc
@none
@


1.1
log
@none
@
text
@%META:TOPICINFO{author="KennethLavrsen" date="1134597393" format="1.1" version="1.1"}%

%META:FORM{name="SearchWebForm"}%
%META:FIELD{name="TextItem" title="Text Item" value="Value_1"}%
%META:FIELD{name="NumberItem" title="Number Item" value="3"}%
@
T1

    <<'T2',
head	1.2;
access;
symbols;
locks; strict;
comment	@# @;
expand	@o@;


1.2
date	2005.12.14.22.23.23;	author KennethLavrsen;	state Exp;
branches;
next	1.1;

1.1
date	2005.12.14.21.58.17;	author KennethLavrsen;	state Exp;
branches;
next	;


desc
@none
@


1.2
log
@none
@
text
@%META:TOPICINFO{author="KennethLavrsen" date="1134599003" format="1.1" version="1.2"}%

%META:FORM{name="SearchWebForm"}%
%META:FIELD{name="TextItem" title="Text Item" value="Value_2"}%
%META:FIELD{name="NumberItem" title="Number Item" value="2"}%
@


1.1
log
@none
@
text
@d1 1
a1 1
%META:TOPICINFO{author="KennethLavrsen" date="1134597497" format="1.1" version="1.1"}%
@
T2

    <<'T3');
head	1.1;
access;
symbols;
locks; strict;
comment	@# @;
expand	@o@;


1.1
date	2005.12.14.21.59.27;	author KennethLavrsen;	state Exp;
branches;
next	;


desc
@none
@


1.1
log
@none
@
text
@%META:TOPICINFO{author="KennethLavrsen" date="1134597567" format="1.1" version="1.1"}%

%META:FORM{name="SearchWebForm"}%
%META:FIELD{name="TextItem" title="Text Item" value="Value_3"}%
%META:FIELD{name="NumberItem" title="Number Item" value="1"}%
@
T3

around set_up => sub {
    my $orig = shift;
    my $this = shift;
    $orig->( $this, @_ );

    # Testcases are written using good anchors
    $this->app->cfg->data->{RequireCompatibleAnchors} = 0;

    # Test using an RCS store, fo which we have some bogus topics.
    $this->app->cfg->data->{Store}{Implementation} = 'Foswiki::Store::RcsLite';
    for ( my $i = 1 ; $i <= scalar @test_comma_v ; $i++ ) {
        my $f = $this->app->cfg->data->{DataDir}
          . "/TestCases/SearchTestTopic$i.txt,v";
        unlink $f if -e $f;
        open( F, '>', $f ) || die $!;
        print F $test_comma_v[ $i - 1 ];
        close(F);
    }

    #$VIEW_UI_FN ||= $this->getUIFn('view');

    # This user is used in some testcases. All we need to do is make sure
    # their topic exists in the test users web
    if (
        !$this->app->store->topicExists(
            $this->app->cfg->data->{UsersWebName}, 'WikiGuest'
        )
      )
    {
        my ($to) =
          $this->app->readTopic( $this->app->cfg->data->{UsersWebName},
            'WikiGuest' );
        $to->text('This user is used in some testcases');
        $to->save;
        undef $to;
    }
    if (
        !$this->app->store->topicExists(
            $this->app->cfg->data->{UsersWebName},
            'UnknownUser'
        )
      )
    {
        my ($to) = $this->app->readTopic( $this->app->cfg->data->{UsersWebName},
            'UnknownUser' );
        $to->text('This user is used in some testcases');
        $to->save;
    }
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;
    for ( my $i = 1 ; $i <= scalar @test_comma_v ; $i++ ) {
        my $f = $this->app->cfg->data->{DataDir}
          . "/TestCases/SearchTestTopic$i.txt,v";
        unlink $f if -e $f;
    }
    $orig->($this);
};

around list_tests => sub {
    my $orig = shift;
    my ( $this, $suite ) = @_;
    my @set = $orig->( $this, @_ );

    $this->createNewFoswikiApp;
    unless ( $this->app->store->webExists('TestCases') ) {
        print STDERR
          "Cannot run semi-automatic test cases; TestCases web not found";
        return;
    }

    if ( !eval "require Foswiki::Plugins::TestFixturePlugin; 1;" ) {
        print STDERR
"Cannot run semi-automatic test cases; could not find TestFixturePlugin";
        return;
    }
    foreach my $case ( $this->app->getTopicList('TestCases') ) {
        next unless $case =~ m/^TestCaseAuto/;
        my $test = 'SemiAutomaticTestCaseTests::test_' . $case;
        no strict 'refs';
        *{$test} = sub { shift->run_testcase($case) };
        use strict 'refs';
        push( @set, $test );
    }
    $this->createNewFoswikiApp;
    return @set;
};

sub run_testcase {
    my ( $this, $testcase ) = @_;
    $this->app->cfg->data->{INCLUDE}{AllowURLs} = 1;
    $this->app->cfg->data->{Plugins}{TestFixturePlugin}{Enabled} = 1;
    $this->app->cfg->data->{Plugins}{TestFixturePlugin}{Module} =
      'Foswiki::Plugins::TestFixturePlugin';
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                test => 'compare',
                debugenableplugins =>
                  'TestFixturePlugin,SpreadSheetPlugin,InterwikiPlugin',
                skin => 'pattern'
            }
        },
        engineParams => {
            initialAttributes => {
                path_info => "/TestCases/$testcase",
                user      => $this->test_user_login,
                action    => 'view',
            },
        },
    );
    my ($topicObject) =
      $this->app->readTopic( $this->users_web, 'ProjectContributor' );
    $topicObject->text('none');
    $topicObject->save;
    undef $topicObject;
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                test => 'compare',
                debugenableplugins =>
                  'TestFixturePlugin,SpreadSheetPlugin,InterwikiPlugin',
                skin => 'pattern'
            }
        },
        engineParams => {
            initialAttributes => {
                path_info => "/TestCases/$testcase",
                user      => $this->test_user_login,
                action    => 'view',
            },
        },
    );
    my ($text) = $this->capture( sub { $this->app->handleRequest } );

    unless ( $text =~ m#<font color="green">ALL TESTS PASSED</font># ) {
        $this->assert(
            open( my $F, '>:encoding(utf8)', "${testcase}_run.html" ) );
        print $F $text;
        $this->assert( close $F );
        $this->createNewFoswikiApp(
            requestParams => {
                initializer => {
                    debugenableplugins =>
                      'TestFixturePlugin,SpreadSheetPlugin,InterwikiPlugin',
                    skin => 'pattern'
                }
            },
            engineParams => {
                initialAttributes => {
                    path_info => "/TestCases/$testcase",
                    user      => $this->test_user_login,
                    action    => 'view',
                },
            },
        );
        ($text) = $this->capture( sub { $this->app->handleRequest } );
        $this->assert( open( $F, '>:encoding(utf8)', "${testcase}.html" ) );
        print $F $text;
        $this->assert( close $F );
        $this->assert( 0,
"$testcase FAILED - output in ${testcase}.html and ${testcase}_run.html"
        );
    }

    return;
}

sub test_suppresswarning {
    return;
}

1;
