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

    try {
        $this->createNewFoswikiApp(
            requestParams => { initializer => '', },
            engineParams =>
              { initialAttributes => { path_info => '/TestCases/WebHome', }, },
            user => 'AdminUser',
        );
        my $user = $this->app->user;

        # You can create webs here; don't forget to tear them down

        # Create a web like this:
        my $webObject =
          $this->populateNewWeb( "Temporarytestweb1", "_default" );
        undef $webObject;

        # Copy a system web like this:
        $webObject = $this->populateNewWeb( "Temporarysystemweb", "System" );
        undef $webObject;

        # Create a topic like this:

        # Note: if you are going to manipulate users, you need
        # to make sure you fixture protects things like .htpasswd

    }
    catch {
        if ( $_->isa('Foswiki::AccessControlException') ) {
            $this->assert( 0, $_->stringify() );
        }
        else {
            Foswiki::Exception::Fatal->rethrow($_);
        }
    };

    return;
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    # Remove fixture webs; warning, if one of these
    # dies, you may end up with spurious test webs
    $this->removeWebFixture("Temporarytestweb1");
    $this->removeWebFixture("Temporarysystemweb");

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
