use strict;

# Example test case; use this as a basis to build your own

package EmptyTests;

use base qw( FoswikiTestCase );

use Foswiki;
use Error qw( :try );

my $topicquery;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    # You can now safely modify $Foswiki::cfg

    $topicquery = new Unit::Request('');
    $topicquery->path_info('/TestCases/WebHome');
    try {
        $this->{session} = new Foswiki( 'AdminUser' || '' );
        my $user = $this->{session}->{user};

        # You can create webs here; don't forget to tear them down

        # Create a web like this:
        my $webObject =
          Foswiki::Meta->new( $this->{session}, "Temporarytestweb1" );
        $webObject->populateNewWeb("_default");

        # Copy a system web like this:
        $webObject =
          Foswiki::Meta->new( $this->{session}, "Temporarysystemweb" );
        $webObject->populateNewWeb("System");

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
}

sub tear_down {
    my $this = shift;

    # Remove fixture webs; warning, if one of these
    # dies, you may end up with spurious test webs
    $this->removeWebFixture( $this->{session}, "Temporarytestweb1" );
    $this->removeWebFixture( $this->{session}, "Temporarysystemweb" );
    $this->{session}->finish() if $this->{session};

    # Always do this, and always do it last
    $this->SUPER::tear_down();
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

#================================================================================
#================================================================================

sub test_ {
    my $this = shift;
}

#================================================================================

1;
