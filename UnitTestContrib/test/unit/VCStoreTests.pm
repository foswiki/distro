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

package VCStoreTests;
use strict;
use warnings;
use File::Remove;

use FoswikiStoreTestCase();
our @ISA = qw( FoswikiStoreTestCase );

use Foswiki();
use Foswiki::Func();

my $TEXT1 = <<'DONE';
Fit the first
DONE

my $TEXT2 = <<'DONE';
Second fit
DONE

my $TEXT3 = <<'DONE';
Fit for nothing
DONE

# Compare two dates
sub assert_nearly {
    my ( $this, $d1, $d2 ) = @_;

    # A 1-minute window for completion of the tests is generous
    $this->assert( abs( $d1 - $d2 ) < 60, "Times too far apart $d1 $d2" );
}

# Check version info structure against expected data. Defaults to
# version 1 and unknown user is $version, $author not given.
sub assert_version_info {
    my ( $this, $info, $time, $version, $author ) = @_;

    $version ||= 1;
    $author  ||= $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;

    $this->assert_num_equals( $version, $info->{version} );
    $this->assert_str_equals( $author, $info->{author} );
    $this->assert_nearly( $time, $info->{date} );
}

sub set_up_for_verify {
    my $this = shift;
    $this->createNewFoswikiSession();

    # Clean up here in case test was aborted
    File::Remove::remove( \1,
        "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}*" );

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

    # If it exists, the TOPICINFO should be re-populated appropriately.
    # (A store may only create it when the topic is saved)
    my $ti = $meta->get('TOPICINFO');
    if ($ti) {
        $this->assert_version_info( $ti, $date );
    }

    # 17
    my $info = $this->{session}->{store}->getVersionInfo($meta);

    $this->assert_version_info( $info, $date );

    # 5
    $this->assert_num_equals( 2,
        $this->{session}->{store}->getNextRevision($meta) );

    $meta->finish();

    return;
}

# Get revision info where there is no history
# Revision info is reported as follows:
#    * TOPICINFO: read from cache directly
#    * getVersionInfo, getRevisionHistory:  first reads the cache, then fall back to deeper inspection
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

    # The TOPICINFO should exist and should be re-populated appropriately
    my $ti = $meta->get('TOPICINFO');
    $this->assert($ti);

# this is expected to fail as the topic was created circumventing the normal api
# $this->assert_version_info( $ti, $date );

    # 5
    $this->assert_num_equals( 2,
        $this->{session}->{store}->getNextRevision($meta) );

    # 17
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    $this->assert_version_info( $info, $ti->{date}, $ti->{version},
        $ti->{author} );

    $meta->finish();

    return;
}

# Revision info must be consistent when retrieved from three places:
# TOPICINFO, getVersionInfo and getRevisionHistory
sub verify_InconsistentTopic_getRevisionInfo {
    my $this = shift;

    # Inconsistent cache with topicinfo
    my $date = $this->_createInconsistentTopic();
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # 4
    my $it = $this->{session}->{store}->getRevisionHistory($meta);
    $this->assert( $it->hasNext() );

# Inconsistent topic should declare 2 versions; one in history, and one not checked in yet
    $this->assert_num_equals( 2, $it->next() );

    # The next revision will be 2 for the pending a checkin
    # 6
    $this->assert_num_equals( 2,
        $this->{session}->{store}->getNextRevision($meta) );

    # The content should come from the mauled topic
    # 2
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*$/s, $meta->text() );

    # check TOPICINFO as fetched from the cache
    my $ti = $meta->get('TOPICINFO');
    $this->assert_num_equals( 77, $ti->{version} );
    $this->assert_str_equals( 'SpongeBobSquarePants', $ti->{author} );

    # force a save so that the inconsistencies get fixed
    $meta->save();

    # and must be consistent with getVersionInfo
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    $this->assert_num_equals( 3, $info->{version} )
      ;    # rev 2 was used to store the pending checkin

    # If we ignore the author in TOPICINFO, this will be unknownuser
    $this->assert_str_equals(
        $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID,
        $info->{author} );

    my $timeDiff = $info->{date} - $date;
    $this->assert( $timeDiff <= 1 )
      ; # a range of 1s is okay. sometimes fails when the system load is high otherwise
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

# Head of "history" will be 1, we've got one pending checkin, so latest revision
# is reporting 2, the next revision will be 2.
# and should contain $TEXT2
    my ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Save (but *don't* force) a new rev. Should always create a 2.
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
    $this->assert_equals( 3, $readMeta->getLatestRev() )
      ;    # rev 2 was used to check in pending changes
    $this->assert_matches( qr/^\s*\Q$TEXT3\E\s*/s, $readMeta->text() );

    # Check that getRevisionInfo says the right things. The author should be
    # retained, but the date and version number should change
    my $info = $readMeta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 3, $info->{version} );

    my $dateDiff = abs( $info->{date} - $date );

# Ensure the file timestamp is used for the revision date, allowing a 1-second fuzz factor
    $this->assert( ( $dateDiff <= 1 ) );

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

  # repRev degrades to a normal addRev when there's an implicit save triggered
  # by inconsistent topic data. so rev 1 is associated to the oob change and now
  # we are at rev 2.
    $this->assert_num_equals( 2, $info->{version} );
    $this->assert_str_equals(
        $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID,
        $info->{author} );

    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # meta topic info was added during repRev()
    $this->assert_matches( qr/\s*\Q$TEXT2\E\s*$/s, $meta->text );
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
    $this->assert_num_equals( 3, $info->{version} )
      ;    # rev 2 has been used for the oob changes
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
    $this->assert_equals( 2, $meta->getLatestRev() )
      ;    # because there's a pending checkin
    $meta->attach(
        name    => "testfile.txt",
        file    => "$Foswiki::cfg{TempfileDir}/testfile.txt",
        comment => "a comment"
    );

    $meta->finish();
    ($meta) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 3, $meta->getLatestRev() )
      ; # rev 2 has been used to check in pending changes, rev 3 holds the actual attachment
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*/s, $meta->text() );

    # Check that the new rev has the attachment meta-data
    my $attachment = $meta->get( 'FILEATTACHMENT', 'testfile.txt' );
    $this->assert_not_null($attachment);
    $this->assert_str_equals( $this->{session}->{user}, $attachment->{user} );
    $this->assert_equals( 1, $attachment->{version} );

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

