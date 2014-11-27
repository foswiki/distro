# This is a plugin stub used to support the DBIStoreContrib with Foswiki
# versions < 1.2 that lack the Foswiki::Store::recordChange function.

package Foswiki::Plugins::DBIStorePlugin;

use strict;
use warnings;

use Foswiki::Contrib::DBIStoreContrib ();
use Foswiki::Store                    ();
use Foswiki::Func                     ();

our $VERSION           = $Foswiki::Contrib::DBIStoreContrib::VERSION;
our $RELEASE           = $Foswiki::Contrib::DBIStoreContrib::RELEASE;
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION =
'Use DBI to implement searching using an SQL database. Supports SQL queries over Form data.';

use constant TRACE => 0;

sub initPlugin {
    if ( $Foswiki::Plugins::SESSION->{store}->can('recordChange') ) {

        # Will not enable this plugin if recordChange is present,
        # as this is Foswiki >=1.2
        Foswiki::Func::writeDebug(
            "DBIStorePlugin not required; can recordChange")
          if TRACE;
        return 0;
    }

    # If the getField method is missing, then get it from the BruteForce
    # module that it was moved from.
    require Foswiki::Store::QueryAlgorithms::DBIStoreContrib;
    unless ( Foswiki::Store::QueryAlgorithms::DBIStoreContrib->can('getField') )
    {
        require Foswiki::Store::QueryAlgorithms::BruteForce;
        *Foswiki::Store::QueryAlgorithms::DBIStoreContrib::getField =
          \&Foswiki::Store::QueryAlgorithms::BruteForce::getField;
    }

    return 1;
}

sub commonTagsHandler {

    # Normally preloading only occurs when the DB first connects, which
    # only happens when a topic is moved or saved. To short-circuit this,
    # the plugin supports the "?dbistore_reset" parameter, which will
    # do that chore. Only admins can call it. It's done this late in
    # the pipeline to ensure plugins have had a chance to register META
    # requirements.
    if ( Foswiki::Func::getRequestObject->param('dbistore_reset')
        && Foswiki::Func::isAnAdmin() )
    {
        Foswiki::Func::writeDebug('DBIStorePlugin: Resetting') if TRACE;
        Foswiki::Func::getRequestObject->delete('dbistore_reset');
        Foswiki::Contrib::DBIStoreContrib::reset($Foswiki::Plugins::SESSION);
    }
    elsif ( Foswiki::Func::getRequestObject->param('dbistore_update') ) {
        my ( $text, $topic, $web, $included, $meta ) = @_;
        Foswiki::Func::getRequestObject->delete('dbistore_update');
        Foswiki::Func::writeDebug(
            'DBIStorePlugin: Update ' . $meta->getPath() )
          if TRACE;
        Foswiki::Contrib::DBIStoreContrib::start();
        Foswiki::Contrib::DBIStoreContrib::remove($meta);
        Foswiki::Contrib::DBIStoreContrib::insert($meta);
        Foswiki::Contrib::DBIStoreContrib::commit();
    }
}

# Store operations that *should* call the relevant store functions
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
    my $meta = $_[4];
    Foswiki::Func::writeDebug(
        "DBIStorePlugin::afterSaveHandler " . $meta->getPath() )
      if TRACE;
    Foswiki::Contrib::DBIStoreContrib::start();
    Foswiki::Contrib::DBIStoreContrib::remove($meta);
    Foswiki::Contrib::DBIStoreContrib::insert($meta);
    Foswiki::Contrib::DBIStoreContrib::commit();
}

# Required for a web or topic move
sub afterRenameHandler {
    my ( $oldWeb, $oldTopic, $olda, $newWeb, $newTopic, $newa ) = @_;

    Foswiki::Func::writeDebug( "DBIStorePlugin::afterRenameHandler $oldWeb."
          . ( $oldTopic || '' ) . ':'
          . ($olda)
          . " to $newWeb."
          . ( $newTopic || '' ) . ':'
          . ( $newa || '' ) )
      if TRACE;
    my $oldo =
      new Foswiki::Meta( $Foswiki::Plugins::SESSION, $oldWeb, $oldTopic );
    my $newo =
      new Foswiki::Meta( $Foswiki::Plugins::SESSION, $newWeb, $newTopic );
    Foswiki::Contrib::DBIStoreContrib::start();
    Foswiki::Contrib::DBIStoreContrib::remove($oldo);    #, $olda );
    Foswiki::Contrib::DBIStoreContrib::insert($newo);    #, $newa );
    Foswiki::Contrib::DBIStoreContrib::commit();
}

# Required for an upload
sub afterUploadHandler {
    my ( $attrs, $meta ) = @_;
    Foswiki::Func::writeDebug( "DBIStorePlugin::afterUploadHandler "
          . $meta->getPath() . ':'
          . $attrs->{attachment} )
      if TRACE;
    Foswiki::Contrib::DBIStoreContrib::start();
    Foswiki::Contrib::DBIStoreContrib::remove( $meta, $attrs->{attachment} );

    # The topic is saved too, but without invoking the afterSaveHandler :-(
    Foswiki::Contrib::DBIStoreContrib::remove($meta);
    Foswiki::Contrib::DBIStoreContrib::insert($meta);
    Foswiki::Contrib::DBIStoreContrib::insert( $meta, $attrs->{attachment} );
    Foswiki::Contrib::DBIStoreContrib::commit();
}

1;
