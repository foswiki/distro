# Tests for low-level RCS handler code. Store::VC::Store creates a
# transitory handler object for each store item. The handler
# behaviour is only exposed to Store::VC::Store, which is in turn tested
# in VCStoreTests.

package RCSHandlerTests;

use strict;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use Foswiki;
use Foswiki::Store;
use Foswiki::Store::VC::RcsLiteHandler;
use Foswiki::Store::VC::RcsWrapHandler;
use File::Path;
use FoswikiStoreTestCase ();

my $testWeb = "TestRcsWebTests";
my $user    = "TestUser1";

my $rTopic = "TestTopic";
my $class;

my $time           = time();
my @historyItem945 = (
    # rcsType, text,                       comment,   user,     date
    [ "Wrap", "old\nwrap\n",                 "one", "iron",     $time ],
    [ "Wrap", "old\nwrap\nnew\n",            "two", "tin",      $time + 1 ],
    [ "Lite", "new\nwrap\nnew\n\nlite\n",    "tre", "zinc",     $time + 2 ],
    [ "Lite", "new\nlite text\n",            "for", "gold",     $time + 3 ],
    [ "Wrap", "new\nlite text\n+\@wrap\@\n", "fiv", "titanium", $time + 4 ],
);
my @rcsTypes = qw/Lite Wrap/;    # SMELL: can't skip if no RCS installed

sub RcsLite {
    my $this = shift;
    $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite';
    $class = 'Foswiki::Store::VC::RcsLiteHandler';
}

sub RcsWrap {
    my $this = shift;
    $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsWrap';
    $class = 'Foswiki::Store::VC::RcsWrapHandler';
}

sub fixture_groups {
    my $this = shift;
    my $groups = ['RcsLite'];

    push( @$groups, 'RcsWrap' ) if (FoswikiStoreTestCase::rcs_is_installed());
    
    return ($groups);
}

{
    package StoreStub;
    our @ISA = qw(Foswiki::Store);
    sub new {
        return bless({}, $_[0]);
    }
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    die unless ( defined $Foswiki::cfg{PubUrlPath} );
    die unless ( defined $Foswiki::cfg{ScriptSuffix} );
    $Foswiki::cfg{Register}{AllowLoginName} = 1;

    # Switch off pipes to maximise debug opportunities
    # The following setting is for debugging and disabled
    # since it makes so much noise that normal tests drown
    # Note enabling these makes later test cases fail when
    # run as FoswikiSuite
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 0;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 0;

    $Foswiki::cfg{WarningFileName} = "$Foswiki::cfg{TempfileDir}/junk";
    File::Path::mkpath("$Foswiki::cfg{DataDir}/$testWeb");
    File::Path::mkpath("$Foswiki::cfg{PubDir}/$testWeb");
    $this->assert( open( F, ">$Foswiki::cfg{TempfileDir}/itme3122" ), $! );
    print F "old";
    $this->assert( close(F), $! );
    require Foswiki::Users::BaseUserMapping;#
}

sub tear_down {
    my $this = shift;
    # Restore the PIPE settings in Sandbox
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 1;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 1;
    unlink $Foswiki::cfg{WarningFileName};
    unlink "$Foswiki::cfg{TempfileDir}/itme3122";
    File::Path::rmtree("$Foswiki::cfg{DataDir}/$testWeb");
    File::Path::rmtree("$Foswiki::cfg{PubDir}/$testWeb");
    $this->SUPER::tear_down();
}

# Tests temp file creation in RcsFile
sub test_mktmp {

    # this is only used on WINDOWS so needs a special test
    my $this    = shift;
    my $tmpfile = Foswiki::Store::VC::Handler::mkTmpFilename();
    $this->assert( !-e $tmpfile );
}

# Tests reprev, for both Wrap and Lite
sub verify_RepRev {
    my ($this) = @_;
    my $topic = "RcsRepRev";

    my $rcs = $class->new( new StoreStub, $testWeb, $topic, "" );
    $rcs->addRevisionFromText( "there was a man\n\n",
        "in once", "JohnTalintyre" );
    my ($text) = $rcs->getRevision(1);
    $this->assert_equals( "there was a man\n\n", $text );
    $this->assert_equals( 1,                     $rcs->_numRevisions() );

    $rcs->replaceRevision( "there was a cat\n",
        "1st replace", "NotJohnTalintyre", time() );
    $this->assert_equals( 1,                   $rcs->_numRevisions() );
    ($text) = $rcs->getRevision(1);
    $this->assert_equals( "there was a cat\n", $text );
    $rcs->addRevisionFromText( "and now this\n\n\n", "2nd entry", "J1" );
    $this->assert_equals( 2,                    $rcs->_numRevisions() );
    ($text) = $rcs->getRevision(1);
    $this->assert_equals( "there was a cat\n",  $text );
    ($text) = $rcs->getRevision(2);
    $this->assert_equals( "and now this\n\n\n", $text );

    $rcs->replaceRevision( "then this", "2nd replace", "J2", time() );
    $this->assert_equals( 2,                   $rcs->_numRevisions );
    ($text) = $rcs->getRevision(1);
    $this->assert_equals( "there was a cat\n", $text );
    ($text) = $rcs->getRevision(2);
    $this->assert_equals( "then this",         $text );
}

sub verify_RepRev2839 {
    my ($this) = @_;
    my $topic = "RcsRepRev";

    my $rcs = $class->new( new StoreStub, $testWeb, $topic, "" );
    $rcs->addRevisionFromText( "there was a man", "in once", "JohnTalintyre" );
    my ($text) = $rcs->getRevision(1);
    $this->assert_equals( "there was a man", $text );
    $this->assert_equals( 1,                 $rcs->_numRevisions() );

    $rcs->replaceRevision( "there was a cat",
        "1st replace", "NotJohnTalintyre", time() );
    $this->assert_equals( 1,                 $rcs->_numRevisions() );
    ($text) = $rcs->getRevision(1);
    $this->assert_equals( "there was a cat", $text );
    $rcs->addRevisionFromText( "and now this", "2nd entry", "J1" );
    $this->assert_equals( 2,                 $rcs->_numRevisions() );
    ($text) = $rcs->getRevision(1);
    $this->assert_equals( "there was a cat", $text );
    ($text) = $rcs->getRevision(2);
    $this->assert_equals( "and now this",    $text );

    $rcs->replaceRevision( "then this", "2nd replace", "J2", time() );
    $this->assert_equals( 2,                 $rcs->_numRevisions );
    ($text) = $rcs->getRevision(1);
    $this->assert_equals( "there was a cat", $text );
    ($text) = $rcs->getRevision(2);
    $this->assert_equals( "then this",       $text );
}

# Tests locking - Wrap only
sub verify_RcsWrapOnly_ciLocked {

    return unless $class =~ /RcsWrap/;

    my $this  = shift;
    my $topic = "CiTestLockedTempDeleteMeItsOk";

    # create the fixture
    my $rcs =
      Foswiki::Store::VC::RcsWrapHandler->new( new StoreStub, $testWeb, $topic, "" );
    $rcs->addRevisionFromText( "Shooby Dooby", "original", "BungditDin" );

    # hack the lock
    my $vfile = $rcs->{file} . ",v";
    `co -f -q -l $vfile`;    # Only if we have co
    unlink("$topic.txt");

    # file is now locked by blocker_socker, save some new text
    $rcs->saveFile( $rcs->{file}, "Shimmy Dimmy" );

    # check it in
    $rcs->_ci( "Gotcha", "SheikAlot" );
    my $txt = $rcs->readFile($vfile);
    $this->assert_matches( qr/Gotcha/s,      $txt );
    $this->assert_matches( qr/BungditDin/s,  $txt );
    $this->assert_matches( qr/Shimmy Dimmy/, $txt );
    $this->assert_matches( qr/Shooby Dooby/, $txt );
    $this->assert_matches( qr/SheikAlot/s,   $txt );
}

sub verify_simple1 {
    my $this = shift;
    $this->checkGetRevision( [ "a", "b\n", "c\n" ] );
}

sub verify_simple2 {
    my $this = shift;
    $this->checkGetRevision( [ "a", "b", "a\n", "b", "a", "b\n", "a\nb\n" ] );
}

sub verify_simple3 {
    my $this = shift;
    $this->checkGetRevision( [ "a\n", "b" ] );
}

sub verify_simple4 {
    my $this = shift;
    $this->checkGetRevision( [""] );
}

sub verify_simple5 {
    my $this = shift;
    $this->checkGetRevision( [ "", "a" ] );
}

sub verify_simple6 {
    my $this = shift;
    $this->checkGetRevision( [ "", "a", "a\n", "a\n\n", "a\n\n\n" ] );
}

sub verify_simple7 {
    my $this = shift;
    $this->checkGetRevision( [ "", "a", "a\n", "a\nb" ] );
}

sub verify_simple8 {
    my $this = shift;
    $this->checkGetRevision( [ "", "a", "a\n", "a\nb", "a\nb\n" ] );
}

sub verify_simple9 {
    my $this = shift;
    $this->checkGetRevision(
        [ "", "\n", "\n\n", "a", "a\n", "a\n\n", "\na", "\n\na", "" ] );
}

# coMustCopy should only affect RcsWrap, but test them both anyway
sub verify_simple10a {
    my $this = shift;
    $Fowiki::cfg{RCS}{coMustCopy} = 0;
    $this->checkGetRevision(
        [ "a", "b", "a\n", "b", "a", "b\n", "a\nb\n", "a\nc\n" ] );
}

sub verify_simple10b {
    my $this = shift;
    $Fowiki::cfg{RCS}{coMustCopy} = 1;
    $this->checkGetRevision(
        [ "a", "b", "a\n", "b", "a", "b\n", "a\nb\n", "a\nc\n" ] );
}

sub verify_simple11 {
    my $this = shift;
    $this->checkGetRevision(
        [ "one\n", "1\n2\n", "one\nthree\n4\n", "one\ntwo\nthree\n" ] );
}

sub verify_simple12 {
    my $this = shift;
    $this->checkGetRevision( [ "three\nfour\n", "one\ntwo\nthree\n" ] );
}

sub verify_simple13 {
    my $this = shift;
    $this->checkGetRevision( [ '@expand@\n', "strict;\n", "head 1.99;\n" ] );
}

sub verify_simple14 {
    my $this = shift;
    $this->checkGetRevision( [ '@expand@', "strict;\n", "head 1.99;\n" ] );
}

sub verify_simple15 {
    my $this = shift;
    $this->checkGetRevision( [ "a" . chr(0xFF), "b" . chr(0xFF) ] );
}

sub verify_simple16 {
    my $this = shift;
    $this->checkDifferences( [ "1\n", "2\n" ] );
}

sub verify_simple17 {
    my $this = shift;
    $this->checkDifferences( [ "\n", "1\n" ] );
}

sub verify_simple18 {
    my $this = shift;
    $this->checkDifferences( [ "1\n", "2\n" ] );
}

sub verify_simple19 {
    my $this = shift;
    $this->checkDifferences( [ "2\n", "1\n" ] );
}

sub verify_simple20 {
    my $this = shift;
    $this->checkDifferences( [ "1\n2\n3\n", "a\n1\n2\n3\nb\n" ] );
}

sub verify_simple21 {
    my $this = shift;
    $this->checkDifferences( [ "a\n1\n2\n3\nb\n", "1\n2\n3\n" ] );
}

sub verify_simple22 {
    my $this = shift;
    $this->checkDifferences( [ "1\n2\n3\n", "a\nb\n1\n2\n3\nb\nb\n" ] );
}

sub verify_simple23 {
    my $this = shift;
    $this->checkDifferences( [ "a\nb\n1\n2\n3\nb\nb\n", "1\n2\n3\n" ] );
}

sub verify_simple24 {
    my $this = shift;
    $this->checkDifferences(
        [
            "1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n",
            "A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n"
        ]
    );
}

sub verify_simple25 {
    my $this = shift;
    $this->checkDifferences(
        [
            "A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n",
            "1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n"
        ]
    );
}

sub verify_simple26 {
    my $this = shift;
    $this->checkDifferences(
        [ "one\ntwo\nthree\nfour\nfive\nsix\n", "one\nA\ntwo\nB\nC\nfive\n" ] );
}

sub verify_simple27 {
    my $this = shift;
    $this->checkDifferences( [ "A\nB\n", "A\nC\n\nB\n" ] );
}

sub checkGetRevision {
    my ( $this, $revs ) = @_;
    my $topic = "TestRcsTopic";

    my $rcs = $class->new( new StoreStub, $testWeb, $topic );

    for ( my $i = 0 ; $i < scalar(@$revs) ; $i++ ) {
        my $text = $revs->[$i];
        $rcs->addRevisionFromText(
            $text,
            "rev" . ( $i + 1 ),
            "UserForRev" . ( $i + 1 )
        );
    }

    $rcs = $class->new( new StoreStub, $testWeb, $topic );

    $this->assert_equals( scalar(@$revs), $rcs->_numRevisions() );
    for ( my $i = 1 ; $i <= scalar(@$revs) ; $i++ ) {
        my ($text) = $rcs->getRevision($i);
        $this->assert_str_equals( $revs->[ $i - 1 ],
            $text, "rev " . $i . ": expected '$revs->[$i-1]', got '$text'" );
    }
}

sub verify_GetBinaryRevision {
    my ( $this, $revs ) = @_;
    my $topic = "TestRcsTopic";

    my $atttext1   = "\000123\003\n";
    my $atttext2   = "\003test test test\000\n";
    my $attachment = "file.binary";
    my $rcs        = $class->new( new StoreStub, $testWeb, $topic, $attachment );
    my $fn = "$Foswiki::cfg{WorkingDir}/tmp/tmp.tmp";
    $rcs->saveFile( $fn, $atttext1 ) && die;
    my $fh;
    $this->assert(open($fh, "<", $fn), $!);
    $rcs->addRevisionFromStream( $fh, "comment attachment", "UserForRev" );
    close($fh);
    unlink($fn);
    $rcs->saveFile( $fn, $atttext2 ) && die;
    $this->assert(open($fh, "<", $fn), $!);
    $rcs->addRevisionFromStream( $fh, "comment attachment", "UserForRev" );
    close($fh);
    unlink($fn);

    $rcs = $class->new( new StoreStub, $testWeb, $topic, $attachment );

    my ($text) = $rcs->getRevision(1);
    $this->assert_str_equals( $atttext1, $text );
    ($text) = $rcs->getRevision(2);
    $this->assert_str_equals( $atttext2, $text );
}

# ensure RCS keywords are not expanded in the checked-out version
sub verify_Keywords {
    my ($this) = @_;
    my $topic = "TestRcsTopic";
    my $check =
'$Author$ $Date$ $Header$ $Id$ $Locker$ $Log$ $Name$ $RCSfile$ $Revision$ $Source$ $State$';
    my $rcs = $class->new( new StoreStub, $testWeb, $topic, undef );
    $rcs->addRevisionFromText( $check, "comment", "UserForRev0" );
    open( F, "<$rcs->{file}" ) || die "Failed to open $rcs->{file}";
    local $/ = undef;
    $this->assert_str_equals( $check, <F> );
    close(F);
}

sub checkDifferences {
    my ( $this, $set ) = @_;
    my ( $from, $to )  = @$set;
    my $topic = "RcsDiffTest";
    my $rcs = $class->new( new StoreStub, $testWeb, $topic, "" );

    $rcs->addRevisionFromText( $from, "num 0", "RcsWrapper" );
    $rcs->addRevisionFromText( $to,   "num 1", "RcsWrapper" );

    $rcs = $class->new( new StoreStub, $testWeb, $topic, "" );

    my $diff = $rcs->revisionDiff( 1, 2 );

    # apply the differences to the text of topic 1
    my $data = Foswiki::Store::VC::RcsLiteHandler::_split($from);
    my $l    = 0;

    #print "\nStart: ",join('\n',@$data),"\n";
    foreach my $e (@$diff) {

        #print STDERR "    $e->[0] $l: ";
        if ( $e->[0] eq 'u' ) {
            $l++;
        }
        elsif ( $e->[0] eq 'c' ) {
            $this->assert_str_equals( $data->[$l], $e->[1] );
            $data->[$l] = $e->[2];
            $l++;
        }
        elsif ( $e->[0] eq '-' ) {
            $this->assert_str_equals( $data->[$l], $e->[1] );
            splice( @$data, $l, 1 );
        }
        elsif ( $e->[0] eq '+' ) {
            splice( @$data, $l, 0, $e->[2] );
            $l++;
        }
        elsif ( $e->[0] eq 'l' ) {
            $l = $e->[2] - 1;
        }
        else {
            $this->assert( 0, $e->[0] );
        }

        #for my $i (0..$#$data) {
        #    print STDERR '^' if $i == $l;
        #    print STDERR $data->[$i];
        #    print STDERR '\n' unless($i == $#$data);
        #}
        #print STDERR " -> $l\n";
    }
    $this->assert_str_equals( $to, join( "\n", @$data ) );
}

sub verify_RevAtTime {
    my ($this) = @_;

    my $rcs = $class->new( new StoreStub, $testWeb, 'AtTime', "" );
    $rcs->addRevisionFromText( "Rev0\n", '', "RcsWrapper", 0 );
    $rcs->addRevisionFromText( "Rev1\n", '', "RcsWrapper", 1000 );
    $rcs->addRevisionFromText( "Rev2\n", '', "RcsWrapper", 2000 );
    $rcs = $class->new( new StoreStub, $testWeb, 'AtTime', "" );

    my ($r) = $rcs->getRevisionAtTime(500);
    $this->assert_equals( 1, $r );
    $r = $rcs->getRevisionAtTime(1500);
    $this->assert_equals( 2, $r );
    $r = $rcs->getRevisionAtTime(2500);
    $this->assert_equals( 3, $r );
}

sub verify_RevInfo {
    my ($this) = @_;

    my $rcs = $class->new( new StoreStub, $testWeb, 'RevInfo', "" );

    $rcs->addRevisionFromText( "Rev1\n", 'FirstComment',  "FirstUser",  0 );
    $rcs->addRevisionFromText( "Rev2\n", 'SecondComment', "SecondUser", 1000 );
    $rcs->addRevisionFromText( "Rev3\n", 'ThirdComment',  "ThirdUser",  2000 );

    $rcs = $class->new( new StoreStub, $testWeb, 'RevInfo', "" );

    my $info = $rcs->getInfo(1);
    $this->assert_equals( 1, $info->{version} );
    $this->assert_equals( 0, $info->{date} );
    $this->assert_str_equals( 'FirstUser',    $info->{author} );
    $this->assert_str_equals( 'FirstComment', $info->{comment} );

    $info = $rcs->getInfo(2);
    $this->assert_equals( 2,    $info->{version} );
    $this->assert_equals( 1000, $info->{date} );
    $this->assert_str_equals( 'SecondUser',    $info->{author} );
    $this->assert_str_equals( 'SecondComment', $info->{comment} );

    $info = $rcs->getInfo(3);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );

    $info = $rcs->getInfo(0);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );

    $info = $rcs->getInfo(4);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );

    unlink( $rcs->{rcsFile} );

    $rcs = $class->new( new StoreStub, $testWeb, 'RevInfo', "" );
    $info = $rcs->getInfo(3);
    $this->assert_equals( 1, $info->{version} );

    $this->assert_str_equals(
        $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID,
        $info->{author}
    );
    $this->assert_str_equals( 'pending', $info->{comment} );
}

sub verify_OutOfDate_RevInfo {
    my ($this) = @_;

    my $rcs = $class->new( new StoreStub, $testWeb, 'RevInfo', "" );

    $rcs->addRevisionFromText( "Rev1\n", 'FirstComment',  "FirstUser",  0 );
    $rcs->addRevisionFromText( "Rev2\n", 'SecondComment', "SecondUser", 1000 );
    $rcs->addRevisionFromText( "Rev3\n", 'ThirdComment',  "ThirdUser",  2000 );

    $rcs = $class->new( new StoreStub, $testWeb, 'RevInfo', "" );

    my $info = $rcs->getInfo(1);
    $this->assert_equals( 1, $info->{version} );
    $this->assert_equals( 0, $info->{date} );
    $this->assert_str_equals( 'FirstUser',    $info->{author} );
    $this->assert_str_equals( 'FirstComment', $info->{comment} );

    $info = $rcs->getInfo(2);
    $this->assert_equals( 2,    $info->{version} );
    $this->assert_equals( 1000, $info->{date} );
    $this->assert_str_equals( 'SecondUser',    $info->{author} );
    $this->assert_str_equals( 'SecondComment', $info->{comment} );

    $info = $rcs->getInfo(3);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );

    $info = $rcs->getInfo(0);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );

    $info = $rcs->getInfo(4);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );


    sleep 5;
    open( FH, '>>', "$rcs->{file}" );
    print FH "Modified";
    close FH;

    $info = $rcs->getInfo(0);
    my $time1 = "$info->{date}\n";
    sleep 5;
    $info = $rcs->getInfo(0);
    my $time2 = "$info->{date}\n";

    $this->assert_equals( $time1, $time2 );

    $info = $rcs->getInfo(1);
    $this->assert_equals( 1, $info->{version} );
    $this->assert_equals( 0, $info->{date} );
    $this->assert_str_equals( 'FirstUser',    $info->{author} );
    $this->assert_str_equals( 'FirstComment', $info->{comment} );

    $info = $rcs->getInfo(2);
    $this->assert_equals( 2,    $info->{version} );
    $this->assert_equals( 1000, $info->{date} );
    $this->assert_str_equals( 'SecondUser',    $info->{author} );
    $this->assert_str_equals( 'SecondComment', $info->{comment} );

    $info = $rcs->getInfo(3);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );

    $info = $rcs->getInfo(0);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );

    $info = $rcs->getInfo(4);
    $this->assert_equals( 3,    $info->{version} );
    $this->assert_equals( 2000, $info->{date} );
    $this->assert_str_equals( 'ThirdUser',    $info->{author} );
    $this->assert_str_equals( 'ThirdComment', $info->{comment} );

}

# If a .txt file exists with no ,v and we perform an op on that
# file, a ,v must be created for rev 1 before the op is completed.
sub verify_MissingVrestoreRev {
    my ($this) = @_;

    my $file = "$Foswiki::cfg{DataDir}/$testWeb/MissingV.txt";

    open( F, ">$file" ) || die;
    print F "Rev 1\n";
    close(F);

    my $rcs = $class->new( new StoreStub, $testWeb, 'MissingV', "" );
    my $info = $rcs->getInfo(3);
    $this->assert_equals( 1, $info->{version} );
    $this->assert_equals( 1, $rcs->_numRevisions() );

    my ($text) = $rcs->getRevision(0);
    $this->assert_matches( qr/^Rev 1/, $text );

    ($text) = $rcs->getRevision(1);
    $this->assert_matches( qr/^Rev 1/, $text );

    $rcs->restoreLatestRevision("ArtForger");

    $this->assert( -e "$file,v" );

    ($text) = $rcs->getRevision(0);
    $this->assert_matches( qr/^Rev 1/, $text );

    unlink($file);
    unlink("$file,v");
}

# If a .txt file exists with no ,v and we perform an op on that
# file, a ,v must be created for rev 1 before the op is completed.
sub verify_MissingVrepRev {
    my ($this) = @_;

    my $file = "$Foswiki::cfg{DataDir}/$testWeb/MissingV.txt";

    open( F, ">$file" ) || die;
    print F "Rev 1\n";
    close(F);

    my $rcs = $class->new( new StoreStub, $testWeb, 'MissingV', "" );
    my $info = $rcs->getInfo(3);
    $this->assert_equals( 1, $info->{version} );
    $this->assert_equals( 1, $rcs->_numRevisions() );

    my ($text) = $rcs->getRevision(0);
    $this->assert_matches( qr/^Rev 1/, $text );

    ($text) = $rcs->getRevision(1);
    $this->assert_matches( qr/^Rev 1/, $text );

    $rcs->replaceRevision( "2", "no way", "me", time() );

    $this->assert( -e "$file,v" );

    ($text) = $rcs->getRevision(0);
    $this->assert_matches( qr/^2/, $text );

    unlink($file);
    unlink("$file,v");
}

sub verify_MissingVdelRev {
    my ($this) = @_;

    my $file = "$Foswiki::cfg{DataDir}/$testWeb/MissingV.txt";

    open( F, ">$file" ) || die;
    print F "Rev 1";
    close(F);

    my $rcs = $class->new( new StoreStub, $testWeb, 'MissingV', "" );
    my $info = $rcs->getInfo(3);
    $this->assert_equals( 1, $info->{version} );
    $this->assert_equals( 1, $rcs->_numRevisions() );

    my ($text) = $rcs->getRevision(0);
    $this->assert_matches( qr/^Rev 1/, $text );

    ($text) = $rcs->getRevision(1);
    $this->assert_matches( qr/^Rev 1/, $text );

    ($text) = $rcs->getRevision(2);
    $this->assert_matches( qr/^Rev 1/, $text );

    $rcs->addRevisionFromText( "Rev 2", "more", "idiot", time() );
    $this->assert( -e "$file,v" );

    ($text) = $rcs->getRevision(1);
    $this->assert_matches( qr/^Rev 1/, $text );

    ($text) = $rcs->getRevision(2);
    $this->assert_matches( qr/^Rev 2/, $text );

    ($text) = $rcs->getRevision(0);
    $this->assert_matches( qr/^Rev 2/, $text );

    $rcs->deleteRevision();

    $this->assert( -e "$file,v" );

    ($text) = $rcs->getRevision(0);
    $this->assert_matches( qr/^Rev 1/, $text );

    ($text) = $rcs->getRevision(1);
    $this->assert_matches( qr/^Rev 1/, $text );

    ($text) = $rcs->getRevision(2);
    $this->assert_matches( qr/^Rev 1/, $text );

    unlink($file);
    unlink("$file,v");
}

sub verify_Item2957 {
    my ($this) = @_;
    my $rev1 = <<HERE;
A
C


E
B
HERE
    my $rev2 = <<HERE;
A
C

F

D
B
HERE
    my $rev3 = <<HERE;
A
F
B
HERE
    my $file = "$Foswiki::cfg{DataDir}/$testWeb/Item2957.txt";
    open( F, ">$file" ) || die;
    print F $rev1;
    close(F);

    my $rcs = $class->new( new StoreStub, $testWeb, 'Item2957', '' );
    $rcs->addRevisionFromText( $rev2, "more", "idiot", time() );
    $rcs = $class->new( new StoreStub, $testWeb, 'Item2957', '' );
    $rcs->addRevisionFromText( $rev3, "more", "idiot", time() );

    $rcs = $class->new( new StoreStub, $testWeb, 'Item2957', '' );
    my ($text) = $rcs->getRevision(1);
    if ( $Foswiki::cfg{OS} eq 'WINDOWS' ) {
        $text =~ s/\r\n/\n/sg;
    }
    $this->assert_equals( $rev1, $text );
    $rcs = $class->new( new StoreStub, $testWeb, 'Item2957', '' );
    ($text) = $rcs->getRevision(2);
    $this->assert_equals( $rev2, $text );
    $rcs = $class->new( new StoreStub, $testWeb, 'Item2957', '' );
    ($text) = $rcs->getRevision(3);
    $this->assert_equals( $rev3, $text );
}

sub verify_Item3122 {
    my ($this) = @_;

    my $rcs = $class->new( new StoreStub, $testWeb, 'Item3122', 'itme3122' );
    $rcs->addRevisionFromText( "new", "more", "idiot", time() );
    my ($text) = $rcs->getRevision(1);
    $this->assert_equals( "new", $text );
    $rcs = $class->new( new StoreStub, $testWeb, 'Item3122', 'itme3122' );
    my $fh;
    $this->assert( open( $fh, "<$Foswiki::cfg{TempfileDir}/itme3122" ), $! );
    $rcs->addRevisionFromStream( $fh, "more", "idiot", time() );
    close($fh);
    ($text) = $rcs->getRevision(1);
    $this->assert_equals( "new", $text );
    ($text) = $rcs->getRevision(2);
    $this->assert_equals( "old", $text );
}

# Verify data compatibility between RcsLite and RcsWrap
sub test_Item945 {
    my ($this) = @_;
    
    if (!FoswikiStoreTestCase::rcs_is_installed()) {
        $this->expect_failure();
        $this->annotate("rcs not installed");
    }
    
    my $testTopic = "TestItem945";
    for my $depth ( 0 .. $#historyItem945 ) {
        my ( $rcsType, @params ) = @{ $historyItem945[$depth] };
        my $class = "Foswiki::Store::VC::Rcs${rcsType}Handler";
        my $rcs = $class->new( new StoreStub, $testWeb, $testTopic );
        $rcs->addRevisionFromText(@params);
        $rcs->finish();
        $this->item945_checkHistory( $depth + 1, $testWeb,
            $testTopic );
    }
}

sub item945_checkHistory {
    my ( $this, $depth, $testWeb, $testTopic ) = @_;
    for my $rcsType (@rcsTypes) {
        my $rcs = "Foswiki::Store::VC::Rcs${rcsType}Handler"
          ->new( new StoreStub, $testWeb, $testTopic );
        $this->item945_checkHistoryRcs( $rcs, $depth );
        $rcs->finish();
    }
}

sub item945_checkHistoryRcs {
    my ( $this, $rcs, $depth ) = @_;
    $this->assert_equals( $depth, $rcs->_numRevisions() );
    for my $digger ( 1 .. $depth ) {
        my $info  = $historyItem945[ $digger - 1 ];
        my $rinfo = $rcs->getInfo($digger);
        $this->assert_deep_equals(
            {
                version => $digger,
                date    => $info->[4],
                author  => $info->[3],
                comment => $info->[2]
            },
            $rinfo
        );
    }

}

sub item945_fillTopic {
    my ( $this, $rcs, $time, $testWeb, $testTopic ) = @_;
    
    for my $depth ( 0 .. $#historyItem945 ) {
        my ( undef, @params ) = @{ $historyItem945[$depth] };
        $rcs->addRevisionFromText(@params);
        $this->item945_checkHistory( $depth + 1, $testWeb,
            $testTopic );
    }
}

sub test_Item945_diff {
    my ($this) = @_;

    if (!FoswikiStoreTestCase::rcs_is_installed()) {
        $this->expect_failure();
        $this->annotate("rcs not installed");
    }

    my %content;
    my $testTopic = "TestItem945";
    for my $rcsType (@rcsTypes) {
        my $rcs = "Foswiki::Store::VC::Rcs${rcsType}Handler"
          ->new( new StoreStub, $testWeb, $testTopic . "Rcs$rcsType" );
        $this->item945_fillTopic( $rcs, $time, $testWeb,
            $testTopic . "Rcs$rcsType" );
        $rcs->finish();

        my $file =
          "$Foswiki::cfg{DataDir}/$testWeb/${testTopic}Rcs$rcsType.txt,v";
        open my $fh, '<', $file
          or die "Can't open $file: $!";
        {
            local $/;
            $content{$rcsType} = <$fh>;
        }
    }

    $this->assert_equals( $content{@rcsTypes} );
}

1;
