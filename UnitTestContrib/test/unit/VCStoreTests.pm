# Copyright (C) 2011 Foswiki Contributors. All rights reserved.
#
# Tests specific to VC stores, where the history is decoupled from
# the latest rev of the topic. At present that means RCS stores.
# These tests enhance those in StoreTests.pm, but do not replace them.
#
# A VC-controlled file may be in one of four possible states:
#
#    "up to date" means the .txt and .txt,v both exist, and are consistent
#    "inconsistent" means the .txt is newer than the .txt,v
#    "no history" means the .txt exists but there is no .txt,v
#
# Tests for the store in "up to date" state are covered in StoreTests and
# do not need to be repeated here. The tests here are specific to the
# "inconsistent" and "no history" states.

# Coverage:
#  readTopic no history            - verify_NoHistory_getRevisionInfo
#  readTopic inconsistent          - verify_InconsistentTopic_getRevisionInfo
#  getRevisionHistory no history   - verify_NoHistory_getRevisionInfo
#  getRevisionHistory inconsistent - verify_InconsistentTopic_getRevisionInfo
#  getNextRevision no history      - verify_NoHistory_getRevisionInfo
#  getNextRevision inconsistent    - verify_InconsistentTopic_getRevisionInfo
#  saveTopic no history            - verify_NoHistory_implicitSave
#  saveTopic inconsistent          - verify_Inconsistent_implicitSave
#  repRev no history               - verify_NoHistory_repRev
#  repRev inconsistent             - verify_Inconsistent_repRev
#  getVersionInfo no history       - verify_NoHistory_getRevisionInfo
#  getVersionInfo inconsistent     - verify_InconsistentTopic_getRevisionInfo
#  getRevisionAtTime no history    - verify_NoHistory_getRevisionAtTime
#  getRevisionAtTime inconsistent  - verify_Inconsistent_getRevisionAtTime
#  saveAttachment no history
#  saveAttachment inconsistent
#  getRevisionDiff no history
#  getRevisionDiff inconsistent
#
# Note that the NoHistory behaviour has a special case where the topic is sourced
# from the System web. in this case the TOPICINFO is used.

package VCStoreTests;
use strict;
use warnings;

use FoswikiStoreTestCase();
our @ISA = qw( FoswikiStoreTestCase );

use Foswiki();
use Foswiki::Func();

my $TEXT1 = <<'DONE';
He had bought a large map representing the sea,
Without the least vestige of land:
And the crew were much pleased when they found it to be
A map they could all understand.
DONE

my $TEXT2 = <<'DONE';
They sought it with thimbles, they sought it with care;
They pursued it with forks and hope;
They threatened its life with a railway-share;
They charmed it with smiles and soap. 
DONE

my $TEXT3 = <<'DONE';
Erect and sublime, for one moment of time.
In the next, that wild figure they saw
(As if stung by a spasm) plunge into a chasm,
While they waited and listened in awe. 
DONE

sub set_up_for_verify {
    my $this = shift;
    $this->createNewFoswikiSession();

    # Clean up here in case test was aborted
    unlink "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt";
    unlink "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt,v";
    unlink "$Foswiki::cfg{TempfileDir}/testfile.txt";

    return;
}

# private; create a topic with no ,v
sub _createNoHistoryTopic {
    my ( $this, $withTOPICINFO ) = @_;

    $this->{test_topic} .= "NoHistory"
      unless $this->{test_topic} =~ /NoHistory/;

    open( my $fh, '>',
        "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt" )
      || die "Unable to open \n $! \n\n ";
    if ($withTOPICINFO) {
        print $fh <<'JUNK'
%META:TOPICINFO{author="LewisCarroll" date="9876543210" format="1.1" version="99"}%
JUNK
    }
    print $fh <<"CRUD";
$TEXT1
%META:FIELD{name="SnarkBait" title="SnarkBait" value="Bellman"}%
CRUD
    close $fh;

    return (
        stat(
            "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt")
    )[9];
}

# private; create a topic with .txt,v (rev 1, or 99), and a mauled .txt
sub _createInconsistentTopic {
    my ( $this, $withForm ) = @_;

    $this->{test_topic} .= "Inconsistent"
      unless $this->{test_topic} =~ /Inconsistent/;

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $meta->text($TEXT1);
    $meta->save()
      ;    # we should have a history now, with topic 1 as the latest rev
    $meta->finish();

    # Wait for the clock to tick
    my $x = time;
    while ( time == $x ) {
        sleep 1;
    }

    # create the mauled content
    open( my $fh, '>',
        "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<"CRUD";
%META:TOPICINFO{author="SpongeBobSquarePants" date="1234567890" format="1.1" version="77"}%
$TEXT2
%META:FIELD{name="SnarkBait" title="SnarkBait" value="Beaver"}%
CRUD
    close $fh;

    # The .txt has been mauled, so getLatestRev should return 2

    return (
        stat(
            "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt")
    )[9];
}

# Get revision info where there is no history (,v file)
sub verify_NoHistory_NoTOPICINFO_getRevisionInfo {
    my $this = shift;

    # Create nohistory topic with no META:TOPICINFO
    my $date = $this->_createNoHistoryTopic(0);

    # A topic without history should be rev 1
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # 3
    my $it = $this->{session}->{store}->getRevisionHistory($meta);
    $this->assert( $it->hasNext() );
    $this->assert_num_equals( 1, $it->next() );

    # 1
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*$/s, $meta->text() );

    # The TOPICINFO should be re-populated approrpiately - if it exists (it may
    # only be created when the topic is saved)
    my $ti = $meta->get('TOPICINFO');
    if ($ti) {
        $this->assert_num_equals( 1, $ti->{version} );
        $this->assert_str_equals( 'LewisCarroll', $ti->{author} );
        $this->assert_num_equals( 9876543210, $ti->{date} );
    }

    # 5
    $this->assert_num_equals( 2,
        $this->{session}->{store}->getNextRevision($meta) );

    # 17
    my $info = $this->{session}->{store}->getVersionInfo($meta);

# the TOPICINFO{version} should be ignored if the ,v does not exist, and the rev
# number reverted to 1
    $this->assert_num_equals( 1, $info->{version} );

    # the author will be reverted to the unknown user
    $this->assert_str_equals(
        $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID,
        $info->{author} );

    # date should be the filestamp of the .txt file
    $this->assert_num_equals( $date, $info->{date} );
    $meta->finish();

    return;
}

# Get revision info where there is no history (,v file)
sub verify_NoHistory_TOPICINFO_getRevisionInfo {
    my $this = shift;

    # Create nohistory topic with META:TOPICINFO
    my $date = $this->_createNoHistoryTopic(1);

    # A topic without history should be rev 1
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # 3
    my $it = $this->{session}->{store}->getRevisionHistory($meta);
    $this->assert( $it->hasNext() );
    $this->assert_num_equals( 1, $it->next() );

    # 1
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*$/s, $meta->text() );

    # The TOPICINFO should be re-populated approrpiately
    my $ti = $meta->get('TOPICINFO');
    if ($ti) {
        $this->assert_num_equals( 1, $ti->{version} );
        $this->assert_str_equals( 'LewisCarroll', $ti->{author} );
        $this->assert_num_equals( 9876543210, $ti->{date} );
    }

    # 5
    $this->assert_num_equals( 2,
        $this->{session}->{store}->getNextRevision($meta) );

    # 17
    my $info = $this->{session}->{store}->getVersionInfo($meta);

# the TOPICINFO{version} should be ignored if the ,v does not exist, and the rev
# number reverted to 1
    $this->assert_num_equals( 1,          $info->{version} );
    $this->assert_num_equals( 9876543210, $info->{date} );

    # the author will be reverted to the unknown user
    $this->assert_str_equals( "LewisCarroll", $info->{author} );
    $meta->finish();

    return;
}

sub verify_InconsistentTopic_getRevisionInfo {
    my $this = shift;

    # Inconsistent cache with topicinfo
    my $date = $this->_createInconsistentTopic();
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # 4
    my $it = $this->{session}->{store}->getRevisionHistory($meta);
    $this->assert( $it->hasNext() );
    $this->assert_num_equals( 2, $it->next() );

    # 6
    $this->assert_num_equals( 3,
        $this->{session}->{store}->getNextRevision($meta) );

    # The content should come from the mauled topic
    # 2
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*$/s, $meta->text() );

# The TOPICINFO *will be wrong* in this case, because it is read from the not-yet-checked-in file. We can't
# force-checkin when simply doing a getVersionInfo, as that would result in inconsistent topics always
# getting checked in, which is very, very expensive.
#    my $ti = $meta->get('TOPICINFO');
#    $this->assert_num_equals(2, $ti->{version});
#    $this->assert_str_equals($Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID, $ti->{author});
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    $this->assert_num_equals( 2, $info->{version} );
    $this->assert_str_equals(
        $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID,
        $info->{author} );
    $this->assert_num_equals( $date, $info->{date} );
    $meta->finish();

    return;
}

# A history should be created if none yet exists
sub verify_NoHistory_implicitSave {
    my $this = shift;

    my $date = $this->_createNoHistoryTopic();

    # There's no history, but the current .txt is implicit rev 1
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $it = $this->{session}->{store}->getRevisionHistory($meta);
    $this->assert( $it->hasNext() );
    $this->assert_num_equals( 1, $it->next() );

    # Save (but *don't* force) a new rev.
    $meta->text($TEXT2);
    my $checkSave = $this->{session}->{store}->saveTopic(
        $meta,
        $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID,
        { comment => "unit test" }
    );

    # Save of a file without an existing history should never modify Rev 1,
    # but should instead create the first revision, so rev 1 represents
    # the original file before history started.

    $meta->finish();
    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 2, $readMeta->getLatestRev() );
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*/s, $readMeta->text() );

    # Check that getRevisionInfo says the right things. The author should be
    # retained, but the date and version number should change
    my $info = $readMeta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 2, $info->{version} );

    # Ensure the file timestamp is used for the revision date
    $date = (
        stat(
            "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt")
    )[9];
    $this->assert_num_equals( $date, $info->{date} );

    # Make sure that rev 1 exists and has the original text pre-history.
    $readMeta->finish();
    ($readMeta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}, 1 );
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*$/s, $readMeta->text() );
    $readMeta->finish();
    $meta->finish();

    return;
}

# Save without force revision should create a new rev due to missing history
sub verify_Inconsistent_implicitSave {
    my $this = shift;

    my $date = $this->_createInconsistentTopic();

    # Head of "history" will be 2, and should contain $TEXT2
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Save (but *don't* force) a new rev. Should always create a 3.
    $meta->text($TEXT3);
    my $checkSave = $this->{session}->{store}->saveTopic(
        $meta,
        $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID,
        { comment => "unit test" }
    );
    $meta->finish();

    # Save of a file without an existing history should never modify Rev 1,
    # but should instead create the first revision, so rev 1 represents
    # the original file before history started.

    my ($readMeta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 3, $readMeta->getLatestRev() );
    $this->assert_matches( qr/^\s*\Q$TEXT3\E\s*/s, $readMeta->text() );

    # Check that getRevisionInfo says the right things. The author should be
    # retained, but the date and version number should change
    my $info = $readMeta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 3, $info->{version} );

    # Ensure the file timestamp is used for the revision date
    $this->assert_num_equals( $date, $info->{date} );

    # Make sure that previous revs exist and have the right content
    $readMeta->finish();
    ($readMeta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}, 1 );
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*/s, $readMeta->text() );
    $readMeta->finish();
    ($readMeta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}, 2 );
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*/s, $readMeta->text() );
    $readMeta->finish();
    ($readMeta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}, 3 );
    $this->assert_matches( qr/^\s*\Q$TEXT3\E\s*/s, $readMeta->text() );
    $readMeta->finish();

    return;
}

# repRev a topic that has no existing history. The information passed in the repRev call
# will be used to populate the TOPICINFO of the 'new' revision.
sub verify_NoHistory_repRev {
    my $this = shift;

    my $date = $this->_createNoHistoryTopic();

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $meta->text($TEXT2);

    # save using a different user (implicit save is done by UNKNOWN user)
    $this->{session}->{store}
      ->repRev( $meta, $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID );
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    $this->assert_num_equals( 1, $info->{version} );
    $this->assert_str_equals(
        $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID,
        $info->{author} );
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*$/s, $meta->text );
    $meta->finish();

    return;
}

sub verify_Inconsistent_repRev {
    my $this = shift;

    my $date = $this->_createInconsistentTopic();

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $meta->text($TEXT3);

    # save using a different user (implicit save is done by UNKNOWN user)
    $this->{session}->{store}
      ->repRev( $meta, $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID );
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    $this->assert_num_equals( 2, $info->{version} );
    $this->assert_str_equals(
        $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID,
        $info->{author} );
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_matches( qr/^\s*\Q$TEXT3\E\s*$/s, $meta->text );
    $meta->finish();

    return;
}

sub verify_NoHistory_getRevisionAtTime {
    my $this = shift;

    my $then = time;
    my $date = $this->_createNoHistoryTopic();
    my $now  = time;

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_num_equals( 1,
        $this->{session}->{store}->getRevisionAtTime( $meta, $now ) );
    $this->assert_null(
        $this->{session}->{store}->getRevisionAtTime( $meta, $then - 1 ) );
    $meta->finish();

    return;
}

# A pending checkin is assumed to have been created at the file modification time of the
# .txt file.
sub verify_Inconsistent_getRevisionAtTime {
    my $this = shift;

    my $then = time;
    my $date = $this->_createInconsistentTopic();

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_num_equals( 2,
        $this->{session}->{store}->getRevisionAtTime( $meta, time ) );
    $this->assert_num_equals( 1,
        $this->{session}->{store}->getRevisionAtTime( $meta, $then ) );
    $this->assert_null(
        $this->{session}->{store}->getRevisionAtTime( $meta, $then - 1 ) );
    $meta->finish();

    return;
}

# Note this test uses Foswiki::Meta because it is that module that handles the
# decoration of the topic text with meta-data. Less than ideal, but there you go, this
# is really just a sanity check.
sub verify_NoHistory_saveAttachment {
    my $this = shift;

    my $date = $this->_createNoHistoryTopic();

    $this->assert(
        open( my $FILE, ">", "$Foswiki::cfg{TempfileDir}/testfile.txt" ) );
    print $FILE "one two three";
    $this->assert( close($FILE) );

    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $meta->attach(
        name    => "testfile.txt",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.txt",
        comment => "a comment"
    );

    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 2, $meta->getLatestRev() );
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*/s, $meta->text() );
    $this->assert_not_null( $meta->get( 'FILEATTACHMENT', 'testfile.txt' ) );

    # Check that the new rev has the attachment meta-data
    my $info = $meta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 2, $info->{version} );

    # Make sure that rev 1 exists, has the right text
    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}, 1 );
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*$/s, $meta->text() );
    $meta->finish();

    return;
}

sub verify_Inconsistent_saveAttachment {
    my $this = shift;

    my $date = $this->_createInconsistentTopic();

    $this->assert(
        open( my $FILE, ">", "$Foswiki::cfg{TempfileDir}/testfile.txt" ) );
    print $FILE "one two three";
    $this->assert( close($FILE) );

# Note: we use Meta->new rather than Meta->load to simulate the scenario described in
# Item10961, where attachment would blow away content if the meta object was not loaded with
# the latest content.
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $meta->attach(
        name    => "testfile.txt",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.txt",
        comment => "a comment"
    );

    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 3, $meta->getLatestRev() );
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*/s, $meta->text() );
    $this->assert_not_null( $meta->get( 'FILEATTACHMENT', 'testfile.txt' ) );

    # Check that the new rev has the attachment meta-data
    my $info = $meta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 3, $info->{version} );
    $meta->finish();

    return;
}

# verify that the value of a FORMFIELD is taken from the text and not the head
sub verify_Inconsistent_Item10993_FORMFIELD_from_text {
    my $this = shift;
    my $date = $this->_createInconsistentTopic();

    $this->assert_str_equals(
        "Beaver=Beaver",
        Foswiki::Func::expandCommonVariables(
            '%FORMFIELD{"SnarkBait"}%=%QUERY{"SnarkBait"}%',
            $this->{test_topic},
            $this->{test_web}
        )
    );

    return;
}

1;

