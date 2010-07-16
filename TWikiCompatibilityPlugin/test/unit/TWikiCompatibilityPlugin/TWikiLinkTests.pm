#
# Unit tests for handling of links
#

package TWikiLinkTests;

use strict;
use warnings;

use Foswiki::Func;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

sub new {
    my $self = shift()->SUPER::new( "Link", @_ );
    return $self;
}

sub compareTWikiAndFoswikiLinks {
    my ( $this, $tlink, $flink ) = @_;

    # Discard removed topics
    if ( $flink eq 'System._remove_' ) {
        $flink = $tlink;
    }

    # When target are not WikiWords, we have to patch them
    if ( $flink =~ /\.([A-Z][a-z0-9]*)$/ ) {
        $flink = "[[$flink][$1]]";
    }
    my $oldLink = Foswiki::Func::renderText($tlink);
    my $newLink = Foswiki::Func::renderText($flink);
    $this->assert_str_equals(
        $newLink, $oldLink,
        sprintf(
            "%4siki link for %s: %s\n%4siki link for %s: %s",
            TW => $tlink,
            $oldLink,
            Fosw => $flink,
            $newLink
        )
    );
}

sub test_renamedMainTopic {
    my $this = shift;
    while (
        my ( $tlink, $flink ) = each %{
            $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
              {MainWebTopicNameConversion}
        }
      )
    {
        $this->compareTWikiAndFoswikiLinks( "Main.$tlink" => "Main.$flink" );
    }
}

sub test_renamedSystemTopic {
    my $this = shift;
    while (
        my ( $tlink, $flink ) = each %{
            $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
              {TWikiWebTopicNameConversion}
        }
      )
    {
        $this->compareTWikiAndFoswikiLinks( "TWiki.$tlink" => "System.$flink" );
    }
}

sub test_renamedSystemTopicWithLinkText {
    my $this = shift;
    $this->compareTWikiAndFoswikiLinks(
        '[[System.BeginnersStartHere][Link Text]]' =>
          '[[TWiki.ATasteOfTWiki][Link Text]]' );
}

1;
