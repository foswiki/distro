# This is a plugin stub used to support the DBIStoreContrib with Foswiki
# versions < 1.2 that lack the Foswiki::Store::recordChange function.

package Foswiki::Plugins::DBIStorePlugin;

use Foswiki::Contrib::DBIStoreContrib ();

our $VERSION           = $Foswiki::Plugins::DBIStoreContrib::VERSION;
our $RELEASE           = $Foswiki::Plugins::DBIStoreContrib::RELEASE;
our $NO_PREFS_IN_TOPIC = 1;

our $shim;

sub initPlugin {
    if ( defined &Foswiki::Store::recordChange ) {

        # Will not enable this plugin if recordChange is present
        return 0;
    }

    require Foswiki::Contrib::DBIStoreContrib::DBIStore;
    $shim = Foswiki::Contrib::DBIStoreContrib::DBIStore->createShim();
    die "Cannot create store shim" unless $shim;

    # If the getField method is missing, then get it from the BruteForce
    # module that it was moved from.
    require Foswiki::Store::QueryAlgorithms::DBIStoreContrib;
    unless ( Foswiki::Store::QueryAlgorithms::DBIStoreContrib->can('getField') )
    {
        require Foswiki::Store::QueryAlgorithms::BruteForce;
        *Foswiki::Store::QueryAlgorithms::DBIStoreContrib::getField =
          \&Foswiki::Store::QueryAlgorithms::BruteForce::getField;
    }

    # Normally preloading only occurs when the DB first connects, which
    # only happens when a topic is moved or saved. To short-circuit this,
    # the plugin supports the "?dbistore_reset" parameter, which will
    # do that chore.
    if ( Foswiki::Func::getRequestObject->param('dbistore_reset')
        && Foswiki::Func::isAnAdmin() )
    {
        print STDERR "DBIStore resetting\n";
        $shim->reset($Foswiki::Plugins::SESSION);
    }

    return 1;
}

# Store operations that *should* call the relevant store shim functions
# Should call insert($meta):
#    -none-
# Should call update($old, $new):
#    moveTopic
#    moveWeb
#    saveTopic (no $new)
#    repRev(no $new)
#    delRev (no $new)
# Should call remove($old):
#    remove
# Some may not be called in the plugin, due to the inherent shittiness of
# the handler architecture.

# Required for most save operations
sub afterSaveHandler {

    # $text, $topic, $web, $error, $meta
    $shim->update( $_[4] );
}

# Required for a web or topic move
sub afterRenameHandler {

    # $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment
    my $old =
      new Foswiki::Meta( $Foswiki::Plugins::SESSION, $oldWeb, $oldTopic );
    my $new =
      new Foswiki::Meta( $Foswiki::Plugins::SESSION, $newWeb, $newTopic );
    $shim->update( $old, $new );
}

1;
