# This is a plugin stub used to support the DBIStoreContrib with Foswiki
# versions < 1.2 that lack the Foswiki::Store::Interfaces::Listener
# interface.

package Foswiki::Plugins::DBIStorePlugin;

use Foswiki::Contrib::DBIStoreContrib ();

our $VERSION           = $Foswiki::Plugins::DBIStoreContrib::VERSION;
our $RELEASE           = $Foswiki::Plugins::DBIStoreContrib::RELEASE;
our $NO_PREFS_IN_TOPIC = 1;

our $listener;

sub initPlugin {
    if ( defined &Foswiki::Store::tellListeners ) {

        # Will not enable this plugin if tellListeners is present
        return 0;
    }
    require Foswiki::Contrib::DBIStoreContrib::Listener;
    $listener = Foswiki::Contrib::DBIStoreContrib::Listener->new();
    die "Cannot create listener" unless $listener;

    # If the getField method is missing, then get it from the BruteForce
    # module that it was moved from.
    require Foswiki::Store::QueryAlgorithms::DBIStoreContrib;
    unless ( Foswiki::Store::QueryAlgorithms::DBIStoreContrib->can('getField') )
    {
        require Foswiki::Store::QueryAlgorithms::BruteForce;
        *Foswiki::Store::QueryAlgorithms::DBIStoreContrib::getField =
          \&Foswiki::Store::QueryAlgorithms::BruteForce::getField;
    }
    print STDERR "Constructed listener\n";
    return 1;
}

# Store operations that *should* call the relevant listener
# insert($meta)
# update($old, $new)
#    moveTopic
#    moveWeb
#    saveTopic (no $new)
#    repRev(no $new)
#    delRev (no $new)
# remove($old)
#    remove
# Some may not be called in the plugin, due to the inherent shittiness of
# the handler architecture.

# Required for most save operations
sub afterSaveHandler {

    # $text, $topic, $web, $error, $meta
    $listener->update( $_[4] );
}

# Required for a web or topic move
sub afterRenameHandler {

    # $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment
    my $old =
      new Foswiki::Meta( $Foswiki::Plugins::SESSION, $oldWeb, $oldTopic );
    my $new =
      new Foswiki::Meta( $Foswiki::Plugins::SESSION, $newWeb, $newTopic );
    $listener->update( $old, $new );
}

1;
