# Example test case; use this as a basis to build your own

package EmptyTests;
use v5.14;

use Foswiki;
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiTestCase );

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    # You can now safely modify $Foswiki::cfg

    my $topicquery = Unit::Request->new( initializer => '' );
    $topicquery->path_info('/TestCases/WebHome');
    try {
        $this->createNewFoswikiSession( 'AdminUser' || '' );
        my $user = $this->session->user;

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
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::AccessControlException') ) {
            $this->assert( 0, $e->stringify() );
        }
        elsif ( $e->isa('Error::Simple') ) {
            $this->assert( 0, $e->stringify() || '' );
        }
        else {
            $e->throw;
        }
    };

    return;
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    # Remove fixture webs; warning, if one of these
    # dies, you may end up with spurious test webs
    $this->removeWebFixture( $this->session, "Temporarytestweb1" );
    $this->removeWebFixture( $this->session, "Temporarysystemweb" );

    # Always do this, and always do it last
    $orig->($this);

    return;
};

#================================================================================
#================================================================================

sub test_ {
    my $this = shift;

    return;
}

#================================================================================

1;
