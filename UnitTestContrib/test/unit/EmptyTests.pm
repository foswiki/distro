# Example test case; use this as a basis to build your own

package EmptyTests;
use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Foswiki;
use Error qw( :try );

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    # You can now safely modify $Foswiki::cfg

    my $topicquery = Unit::Request->new('');
    $topicquery->path_info('/TestCases/WebHome');
    try {
        $this->createNewFoswikiSession( 'AdminUser' || '' );
        my $user = $this->{session}->{user};

        # You can create webs here; don't forget to tear them down

        # Create a web like this:
        my $webObject =
          $this->populateNewWeb( "Temporarytestweb1", "_default" );
        $webObject->finish();

        # Copy a system web like this:
        $webObject = $this->populateNewWeb( "Temporarysystemweb", "System" );
        $webObject->finish();

        # Create a topic like this:

        # Note: if you are going to manipulate users, you need
        # to make sure you fixture protects things like .htpasswd

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        die "???" unless $e;
        $this->assert( 0, $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };

    return;
}

sub tear_down {
    my $this = shift;

    # Remove fixture webs; warning, if one of these
    # dies, you may end up with spurious test webs
    $this->removeWebFixture( $this->{session}, "Temporarytestweb1" );
    $this->removeWebFixture( $this->{session}, "Temporarysystemweb" );

    # Always do this, and always do it last
    $this->SUPER::tear_down();

    return;
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

#================================================================================
#================================================================================

sub test_ {
    my $this = shift;

    return;
}

#================================================================================

1;
