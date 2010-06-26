#
# Unit tests for handling of links
#

package TWikiLinkTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki::Func;

sub new {
    my $self = shift()->SUPER::new( "Link", @_ );
    return $self;
}

sub test_renamedMainTopic {
    my $this = shift;
    my $goodLink = Foswiki::Func::renderText('Main.SitePreferences');
    my $oldLink = Foswiki::Func::renderText('Main.TWikiPreferences');
    $this->assert_str_equals($goodLink, $oldLink);
}

sub test_renamedSystemTopic {
    my $this = shift;
    my $goodLink = Foswiki::Func::renderText('System.BeginnersStartHere');
    my $oldLink = Foswiki::Func::renderText('TWiki.ATasteOfTWiki');
    $this->assert_str_equals($goodLink, $oldLink);
}

sub test_renamedSystemTopicWithLinkText {
    my $this = shift;
    my $goodLink = Foswiki::Func::renderText('[[System.BeginnersStartHere][Link Text]]');
    my $oldLink = Foswiki::Func::renderText('[[TWiki.ATasteOfTWiki][Link Text]]');
    $this->assert_str_equals($goodLink, $oldLink);
}

1;
