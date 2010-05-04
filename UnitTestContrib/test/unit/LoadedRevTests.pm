# Tests that specifically target the ticklish area of rev number management.
# These tests acknowledge the possibility that loading a topic may not
# return the true revision number of the topic, but some cached number
# that may or may not be correct. They also verify that if
# the topic is *force loaded* with a specific revision (which may or may
# not be in the range of known revisions) that a "true" revision
# will be loaded.
#
# These tests are conducted at the Foswiki::Meta object level, so need
# to be run for each different store implementation.
#
package LoadedRevTests;

use strict;

use FoswikiFnTestCase;
our @ISA = ('FoswikiFnTestCase');

use Foswiki;
use Foswiki::Meta;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Topic has not been saved. Loaded rev should be undef *even after
# a reload*
sub test_phantom_topic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "PhantomTopic");
    $this->assert_equals(undef, $topicObject->getLoadedRev());
    $topicObject->reload();
    $this->assert_equals(undef, $topicObject->getLoadedRev());
    $topicObject->reload(1);
    $this->assert_equals(undef, $topicObject->getLoadedRev());

    $topicObject =
      Foswiki::Meta->load(
          $this->{session}, $this->{test_web}, "PhantomTopic");
    $this->assert_equals(undef, $topicObject->getLoadedRev());
}

# Topic has been saved. Loaded rev should be defined after a reload,
# and if an out-of-range rev is loaded, it should be reigned back
# to the valid range.
sub test_good_topic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "GoodTopic",
          'Let there be light');

    # We haven't loaded a rev yet, so the loaded rev should be undef
    $this->assert_equals(undef, $topicObject->getLoadedRev());

    # Now save. The loaded rev should be set.
    $this->assert_equals(1, $topicObject->save());
    $this->assert_equals(1, $topicObject->getLoadedRev());

    # Create a new unloaded object for what we just saved
    $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "GoodTopic");
    $this->assert_equals(undef, $topicObject->getLoadedRev());

    $topicObject->reload();
    $this->assert_equals(1, $topicObject->getLoadedRev());

    $topicObject =
      Foswiki::Meta->load(
          $this->{session}, $this->{test_web}, "GoodTopic", 0);
    $this->assert_equals(1, $topicObject->getLoadedRev());

    $topicObject =
      Foswiki::Meta->load(
          $this->{session}, $this->{test_web}, "GoodTopic", 1);
    $this->assert_equals(1, $topicObject->getLoadedRev());
    $topicObject =
      Foswiki::Meta->load(
          $this->{session}, $this->{test_web}, "GoodTopic", 2);
    $this->assert_equals(1, $topicObject->getLoadedRev());
}

# Save a topic with borked TOPICINFO. The TOPICINFO should be corrected
# during the save.
sub test_borked_TOPICINFO_save {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "BorkedTOPICINFO", <<SICK);
%META:TOPICINFO{version="3"}%
Houston, we may have a problem here
SICK

    # We haven't loaded a rev yet, so the loaded rev should be undef
    $this->assert_equals(undef, $topicObject->getLoadedRev());

    $topicObject->save(forcenewrevision=>1);
    # Now we *have* saved, and the rev should have been force-corrected
    $this->assert_equals(1, $topicObject->getLoadedRev());

    # Load it again to make sure
    $topicObject =
      Foswiki::Meta->load(
          $this->{session}, $this->{test_web}, "BorkedTOPICINFO");
    $this->assert_equals(1, $topicObject->getLoadedRev());
}

sub test_no_comma_v {
    my $this = shift;

    my $f;
    open($f, '>',
         "$Foswiki::cfg{DataDir}/$this->{test_web}/NoCommaV.txt")
      || return;
    print $f <<WHEE;
%META:TOPICINFO{version="1.3"}%
Blue. No, Green!
WHEE
    close($f);
    my $topicObject =
      Foswiki::Meta->load(
          $this->{session}, $this->{test_web}, "NoCommaV");
    $this->assert_equals(3, $topicObject->getLoadedRev());

    $topicObject->reload(3);
    # We asked for an out-of-range version; even though that's the rev no
    # in the topic, it deosn't exist as a version so the loaded rev
    # should rewind to the "true" version.
    $this->assert_equals(1, $topicObject->getLoadedRev());

    # Reload out-of-range
    $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, "NoCommaV");
    $topicObject->reload(4);
    $this->assert_equals(1, $topicObject->getLoadedRev());

    # Reload undef
    $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, "NoCommaV");
    $topicObject->reload();
    $this->assert_equals(3, $topicObject->getLoadedRev());

    # Reload 0
    $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, "NoCommaV");
    $topicObject->reload(0);
    $this->assert_equals(1, $topicObject->getLoadedRev());
}

# Topic exists on disk, but the topic cache was saved by an external
# process and META:TOPICINFO is behind the latest topic in the DB.
# This case is specifically aimed at stores that decouple
# the revision history from the topic text.
# When the topic is first loaded, the version number will be imaginary.
sub test_borked_TOPICINFO_load_behind {
    my $this = shift;

    # Start by creating a topic with a valid rev no (1)
    my $topicObject =
      Foswiki::Meta->new(
          $this->{session}, $this->{test_web}, "BorkedTOPICINFO", <<SICK);
Your grandmother smells of elderberries
SICK
    $topicObject->save();
    $this->assert_equals(1, $topicObject->getLoadedRev());

    $topicObject->text('ere, Dennis, there some lovely muck over ere');
    $topicObject->save(forcenewrevision => 1);
    $this->assert_equals(2, $topicObject->getLoadedRev());

    # Stomp the cache
    my $f;
    open($f, '>',
         "$Foswiki::cfg{DataDir}/$this->{test_web}/BorkedTOPICINFO.txt")
      || return;
    print $f <<SICK;
%META:TOPICINFO{version="1"}%
We are the knights who say Ni!
SICK
    close($f);

    # The load shouldn't access the history
    $topicObject = Foswiki::Meta->load(
        $this->{session}, $this->{test_web}, "BorkedTOPICINFO");
    $this->assert_equals(1, $topicObject->getLoadedRev());
    $this->assert_matches(qr/knights who say Ni/, $topicObject->text());

    # Now if we reload the latest, we will see a rev number of
    # 1, but if we load any other rev we should see a correct rev
    # number

    # Reload explicit number
    $topicObject->reload(1);
    $this->assert_equals(1, $topicObject->getLoadedRev());
    $this->assert_matches(qr/elderberries/, $topicObject->text());

    $topicObject->reload(2);
    $this->assert_equals(2, $topicObject->getLoadedRev());
    $this->assert_matches(qr/lovely muck/, $topicObject->text());

    $topicObject->reload(3); # reload latest rev
    $this->assert_equals(2, $topicObject->getLoadedRev());
    $this->assert_matches(qr/lovely muck/, $topicObject->text());

    $topicObject = Foswiki::Meta->load(
        $this->{session}, $this->{test_web}, "BorkedTOPICINFO", 0);
    # Should ignore the TOPICINFO and return the "true" revision
    $this->assert_equals(2, $topicObject->getLoadedRev());

    # If we now save it, we should be back to corrected rev nos
    $topicObject->save(forcenewrevision => 1);
        $topicObject = Foswiki::Meta->load(
        $this->{session}, $this->{test_web}, "BorkedTOPICINFO", 0);
    $this->assert_equals(3, $topicObject->getLoadedRev());
}

1;
