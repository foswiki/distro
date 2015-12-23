# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::Rcs::Store

Almost-complete implementation of =Foswiki::Store=. The methods
of this class implement the =Foswiki::Store= interface.

The store uses a "handler" class to handle all interactions with the
actual version control system (and via it with the actual file system).
A "handler" is created for each individual file in the file system, and
this handler then brokers all requests to open, read, write etc the file.
The handler object must implement the interface specified by
=Foswiki::Store::Rcs::Handler=.

The main additional responsibilities of _this_ class are to support storing
Foswiki meta-data in plain text files, and to ensure that the =Foswiki::Meta=
for a page is maintained in synchronisation with the files on disk.

All that is required to create a working store is to subclass this class
and override the 'new' method to specify the actual handler to use. See
Foswiki::Store::RcsWrap for an example subclass.

For readers who are familiar with Foswiki version 1.0, the functionality
in this class _previously_ resided in =Foswiki::Store=.

These methods are documented in the Foswiki:Store abstract base class

=cut

package Foswiki::Store::Rcs::Store;
use strict;
use warnings;

use Foswiki::Store ();
our @ISA = ('Foswiki::Store');

use Assert;
use Error qw( :try );
use Encode;

use Foswiki          ();
use Foswiki::Meta    ();
use Foswiki::Sandbox ();
use Foswiki::Serialise();

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    # The RCS Handler code works on bytes, so we have to mediate
    if ($Foswiki::UNICODE) {
        require Encode;

        *_decode = \&Foswiki::Store::decode;
        *_encode = \&Foswiki::Store::encode;
        *_stat   = sub { stat( _encode( $_[0], 1 ) ); };
        *_unlink = sub { unlink( _encode( $_[0], 1 ) ); };
    }
    else {
        *_decode = sub { return $_[0] };
        *_encode = sub { return $_[0] };
        *_stat   = \&stat;
        *_unlink = \&unlink;
    }
}

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{searchFn};
}

# SMELL: this module does not respect $Foswiki::inUnitTestMode; tests
# just sit on top of the store which is configured in the current $Foswiki::cfg.
# Most of the time this is ok, as store listeners will be told that
# the store is in test mode, so caches should be unaffected. However
# it's very untidy, potentially risky, and causes grief when unit tests
# don't clean up after themselves.

# PACKAGE PRIVATE
# Get a handler for the given object in the store.
sub getHandler {

    #my ( $this, $web, $topic, $attachment ) = @_;
    ASSERT( 0, "Must be implemented by subclasses" ) if DEBUG;
}

sub readTopic {
    my ( $this, $topicObject, $version ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $isLatest = 0;

    # check that the requested revision actually exists
    if ( defined $version && $version =~ /^\d+$/ ) {
        if ( $version == 0 || !$handler->revisionExists($version) ) {
            $version = $handler->getLatestRevisionID();
        }
    }
    else {
        undef $version;  # if it's a non-numeric string, we need to return undef
    }

    return ( undef, undef ) unless $handler->storedDataExists();

    ( my $text, $isLatest ) = $handler->getRevision($version);
    $text = '' unless defined $text;

    # Use Encode::decode directly. Don't NFC normalize the topic text.
    # Only need to normalize filenames.
    $text = Encode::decode(
        $Foswiki::cfg{Store}{Encoding} || 'utf-8',
        $text,

        #Encode::FB_CROAK # DEBUG
        Encode::FB_PERLQQ
    );
    $text =~ s/\r//g;    # Remove carriage returns
    Foswiki::Serialise::deserialise( $text, 'Embedded', $topicObject );

    #   Item11983 - switched off for performance reasons
    #   unless ( $handler->noCheckinPending() ) {
    #
    #        # If a checkin is pending, fix the TOPICINFO
    #        my $ri    = $topicObject->get('TOPICINFO');
    #        my $truth = $handler->getInfo($version);
    #        for my $i (qw(author version date)) {
    #            $ri->{$i} = $truth->{$i};
    #        }
    #    }

    # downgrade to first revision when there's no history
    unless ( $handler->revisionHistoryExists() ) {
        $version = 1;
    }

    my $gotRev = $version;
    unless ( defined $gotRev ) {

        # First try the just-loaded for the revision.
        my $ri = $topicObject->get('TOPICINFO');
        $gotRev = $ri->{version} if defined $ri;
    }
    if ( !defined $gotRev ) {

        # No revision from any other source; must be latest
        $gotRev = $handler->getLatestRevisionID();
        ASSERT( defined $gotRev ) if DEBUG;
    }

    # Add attachments that are new from reading the pub directory.
    # Only check the currently requested topic.
    if (   $Foswiki::cfg{RCS}{AutoAttachPubFiles}
        && $topicObject->isSessionTopic() )
    {
        my @knownAttachments = $topicObject->find('FILEATTACHMENT');
        my @attachmentsFoundInPub =
          $handler->synchroniseAttachmentsList( \@knownAttachments );
        my @validAttachmentsFound;
        foreach my $foundAttachment (@attachmentsFoundInPub) {

            # test if the attachment filename is valid without having to
            # be sanitized. If not, ignore it.
            my $validated = Foswiki::Sandbox::validateAttachmentName(
                $foundAttachment->{name} );
            unless ( defined $validated
                && $validated eq $foundAttachment->{name} )
            {

                print STDERR 'AutoAttachPubFiles ignoring '
                  . $foundAttachment->{name} . ' in '
                  . $topicObject->getPath()
                  . ' - not a valid Foswiki Attachment filename';
            }
            else {
                push @validAttachmentsFound, $foundAttachment;

                # SMELL: how do we tell Meta what happened?
            }
        }

        $topicObject->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
          if @validAttachmentsFound;
    }

    $gotRev ||= 1;    # anything going out here must be > 0

    $topicObject->setLoadStatus( $gotRev, $isLatest );
    return ( $gotRev, $isLatest );
}

sub moveAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    ASSERT($oldAttachment) if DEBUG;
    ASSERT($newAttachment) if DEBUG;

    my $handler =
      $this->getHandler( $oldTopicObject->web, $oldTopicObject->topic,
        $oldAttachment );
    if ( $handler->storedDataExists() ) {
        $handler->moveAttachment( $this, $newTopicObject->web,
            $newTopicObject->topic, $newAttachment );
    }
}

sub copyAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    ASSERT($oldAttachment) if DEBUG;
    ASSERT($newAttachment) if DEBUG;

    my $handler =
      $this->getHandler( $oldTopicObject->web, $oldTopicObject->topic,
        $oldAttachment );
    return undef unless $handler->storedDataExists();

    my $rev =
      $handler->copyAttachment( $this, $newTopicObject->web,
        $newTopicObject->topic, $newAttachment );
    return $rev;
}

sub attachmentExists {
    my ( $this, $topicObject, $att ) = @_;
    ASSERT($att) if DEBUG;
    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $att );
    return $handler->storedDataExists();
}

sub moveTopic {
    my ( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $handler =
      $this->getHandler( $oldTopicObject->web, $oldTopicObject->topic );
    my $rev = $handler->getLatestRevisionID();

    $handler->moveTopic( $this, $newTopicObject->web, $newTopicObject->topic );
}

sub moveWeb {
    my ( $this, $oldWebObject, $newWebObject, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $oldWebObject->web );
    $handler->moveWeb( $newWebObject->web );
}

sub testAttachment {
    my ( $this, $topicObject, $attachment, $test ) = @_;
    ASSERT($attachment) if DEBUG;
    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $attachment );
    return $handler->test($test);
}

sub openAttachment {
    my ( $this, $topicObject, $att, $mode, @opts ) = @_;
    ASSERT($att) if DEBUG;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $att );
    return $handler->openStream( $mode, @opts );
}

sub getRevisionHistory {
    my ( $this, $topicObject, $attachment ) = @_;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $attachment );
    return $handler->getRevisionHistory();
}

sub getNextRevision {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    return $handler->getNextRevisionID();
}

sub getRevisionDiff {
    my ( $this, $topicObject, $rev2, $contextLines ) = @_;
    ASSERT( defined($contextLines) ) if DEBUG;

    my $rcs = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $diffs =
      $rcs->revisionDiff( $topicObject->getLoadedRev(), $rev2, $contextLines );
    foreach my $d (@$diffs) {
        foreach my $i ( 1, 2 ) {
            $d->[$i] = _decode( $d->[$i] );
        }
    }
    return $diffs;
}

sub _getAttachmentVersionInfo {
    my ( $this, $topicObject, $rev, $attachment ) = @_;
    ASSERT($attachment) if DEBUG;

    my $info;

    if ( !defined($rev) ) {
        my $attachInfo = $topicObject->get('FILEATTACHMENT');

        # rewrite to info format similar to TOPICINFO
        if ( defined $attachInfo ) {
            $info->{date} =
                 $attachInfo->{date}
              || $attachInfo->{movedwhen}
              || time();

            $info->{author} =
                 $attachInfo->{user}
              || $attachInfo->{moveby}
              || $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;

            $info->{version} = 1
              unless defined $attachInfo->{version};

            $info->{comment} = $attachInfo->{comment}
              if defined $attachInfo->{comment};
        }
    }

    if ( !defined($info) ) {
        my $handler =
          $this->getHandler( $topicObject->web, $topicObject->topic,
            $attachment );
        $info = $handler->getInfo( $rev || 0 );
        $info->{author} = _decode( $info->{author} );
        $info->{comment} = _decode( $info->{comment} );
    }

    return $info;
}

sub getVersionInfo {
    my ( $this, $topicObject, $rev, $attachment ) = @_;
    my $info;

    return $this->_getAttachmentVersionInfo( $topicObject, $rev, $attachment )
      if ($attachment);

    my $loadedRev = $topicObject->getLoadedRev();

    # loadedRev may be undef even after a successful topic load in
    # META:TOPICINFO is missing from the topic.
    if ( !defined($rev) || $loadedRev eq $rev ) {
        if ( $topicObject->latestIsLoaded() ) {
            $info = $topicObject->get('TOPICINFO');
        }
        else {
            # Load into a new object to avoid blowing away the object we
            # were passed; then selectively get the bits we want.
            my $dummy = Foswiki::Meta->new($topicObject);
            $dummy->loadVersion();
            $info = $dummy->get('TOPICINFO');
            $topicObject->put( 'TOPICINFO', $info );
            $dummy->finish();
        }
    }

    if ( not defined $info ) {
        my $handler =
          $this->getHandler( $topicObject->web, $topicObject->topic );
        $info = $handler->getInfo($rev);
        $info->{author} = _decode( $info->{author} );
        $info->{comment} = _decode( $info->{comment} );
    }

    # make sure there's at least author, date and version
    $info->{author} = $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID
      unless defined $info->{author};
    $info->{date}    = time() unless defined $info->{date};
    $info->{version} = 1      unless defined $info->{version};

    return $info;
}

sub saveAttachment {
    my ( $this, $topicObject, $name, $stream, $cUID, $options ) = @_;
    ASSERT($name) if DEBUG;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $name );
    my $verb = ( $topicObject->hasAttachment($name) ) ? 'update' : 'insert';
    my $comment = $options->{comment} || '';

    $comment = _encode($comment);
    $cUID    = _encode($cUID);

    $handler->addRevisionFromStream( $stream, $comment, $cUID,
        $options->{forcedate} );

    my $rev = $handler->getLatestRevisionID();

    return $rev;
}

sub saveTopic {
    my ( $this, $topicObject, $cUID, $options ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $verb = ( $topicObject->existsInStore() ) ? 'update' : 'insert';

    # just in case they are not sequential
    my $nextRev = $handler->getNextRevisionID();
    my $ti      = $topicObject->get('TOPICINFO');

    if ( defined $ti ) {
        $ti->{version} = $nextRev;
        $ti->{author}  = $cUID;
    }
    else {
        $topicObject->setRevisionInfo(
            version => $nextRev,
            author  => $cUID,
        );
    }
    my $comment = $options->{comment} || '';

    my $text = Foswiki::Serialise::serialise( $topicObject, 'Embedded' );
    $text    = _encode($text);
    $cUID    = _encode($cUID);
    $comment = _encode($comment);
    $handler->addRevisionFromText( $text, $comment, $cUID,
        $options->{forcedate} );

    # reload the topic object
    $topicObject->unload();
    $topicObject->loadVersion();

    return $nextRev;
}

sub repRev {
    my ( $this, $topicObject, $cUID, %options ) = @_;

    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;
    my $info    = $topicObject->getRevisionInfo();
    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $text    = Foswiki::Serialise::serialise( $topicObject, 'Embedded' );
    $text = _encode($text);

    $handler->replaceRevision( $text, 'reprev', $cUID,
        defined $options{forcedate} ? $options{forcedate} : $info->{date} );

    my $rev = $handler->getLatestRevisionID();

    # reload the topic object
    $topicObject->unload();
    $topicObject->loadVersion();

    return $rev;
}

sub delRev {
    my ( $this, $topicObject, $cUID ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $rev = $handler->getLatestRevisionID();
    if ( $rev <= 1 ) {
        throw Error::Simple( 'Cannot delete initial revision of '
              . $topicObject->web . '.'
              . $topicObject->topic );
    }
    $handler->deleteRevision();

    # restore last topic from repository
    $handler->restoreLatestRevision($cUID);

    # reload the topic object
    $topicObject->unload();
    $topicObject->loadVersion();

    return $rev;
}

sub atomicLockInfo {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    return $handler->isLocked();
}

# It would be nice to use flock to do this, but the API is unreliable
# (doesn't work on all platforms)
sub atomicLock {
    my ( $this, $topicObject, $cUID ) = @_;
    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    $handler->setLock( 1, $cUID );
}

sub atomicUnlock {
    my ( $this, $topicObject, $cUID ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    $handler->setLock( 0, $cUID );
}

# A web _has_ to have a preferences topic to be a web.
sub webExists {
    my ( $this, $web ) = @_;

    return 0 unless defined $web;
    $web =~ s#\.#/#go;

    # Foswiki ships with TWikiCompatibilityPlugin but if it is disabled we
    # do not want the TWiki web to appear as a valid web to anyone.
    if ( $web eq 'TWiki' ) {
        unless ( exists $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
            && defined $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled}
            && $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} == 1 )
        {
            return 0;
        }
    }
    my $handler = $this->getHandler( $web, $Foswiki::cfg{WebPrefsTopicName} );
    return $handler->storedDataExists();
}

sub topicExists {
    my ( $this, $web, $topic ) = @_;

    return 0 unless defined $web && $web ne '';
    $web =~ s#\.#/#go;
    return 0 unless defined $topic && $topic ne '';

    my $handler = $this->getHandler( $web, $topic );
    return $handler->storedDataExists();
}

# Record a change in the web history
sub recordChange {
    my $this = shift;
    my %args = @_;

    my $web = $args{path};

    # Support for Foswiki < 2
    my $topic = '.';
    if ( $web =~ /\./ ) {
        ( $web, $topic ) = Foswiki->normalizeWebTopicName( undef, $web );
    }

    my $handler = $this->getHandler($web);
    $handler->recordChange(%args);
}

# Implement Foswiki::Store
sub eachChange {
    my ( $this, $meta, $since ) = @_;

    my $handler = $this->getHandler( $meta->web );
    require Foswiki::ListIterator;

    my @changes;
    @changes = reverse grep { $_->{time} >= $since } $handler->readChanges();
    return Foswiki::ListIterator->new( \@changes );
}

sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    my $handler = $this->getHandler( $web, $topic );
    return $handler->getLatestRevisionTime();
}

sub eachAttachment {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my @list = $handler->getAttachmentList();
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

sub eachTopic {
    my ( $this, $webObject ) = @_;

    my $handler = $this->getHandler( $webObject->web );
    my @list    = $handler->getTopicNames();

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

sub eachWeb {
    my ( $this, $webObject, $all ) = @_;

    # Undocumented; this fn actually accepts a web name as well. This is
    # to make the recursion more efficient.
    my $web = ref($webObject) ? $webObject->web : $webObject;

    my $handler = $this->getHandler($web);
    my @list    = $handler->getWebNames();
    if ($all) {
        my $root = $web ? "$web/" : '';
        my @expandedList;
        while ( my $wp = shift(@list) ) {
            push( @expandedList, $wp );
            my $it = $this->eachWeb( $root . $wp, $all );
            push( @expandedList, map { "$wp/$_" } $it->all() );
        }
        @list = @expandedList;
    }
    @list = sort(@list);
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

sub remove {
    my ( $this, $cUID, $topicObject, $attachment ) = @_;
    ASSERT( $topicObject->web ) if DEBUG;

    my $handler =
      $this->getHandler( $topicObject->web, $topicObject->topic, $attachment );
    $handler->remove();

    my $more = 'Deleted ' . $topicObject->web;
    if ( my $topic = $topicObject->topic ) {
        $more .= '.' . $topic;
    }
    if ($attachment) {
        $more .= ': ' . $attachment;
    }
}

sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;

    my $engine;
    if ( $query->isa('Foswiki::Query::Node') ) {
        unless ( $this->{queryObj} ) {
            my $module = $Foswiki::cfg{Store}{QueryAlgorithm};
            eval "require $module";
            die
"Bad {Store}{QueryAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{queryObj} = $module->new();
        }
        $engine = $this->{queryObj};
    }
    else {
        ASSERT( $query->isa('Foswiki::Search::Node') ) if DEBUG;
        unless ( $this->{searchQueryObj} ) {
            my $module = $Foswiki::cfg{Store}{SearchAlgorithm};
            eval "require $module";
            die
"Bad {Store}{SearchAlgorithm}; suggest you run configure and select a different algorithm\n$@"
              if $@;
            $this->{searchQueryObj} = $module->new();
        }
        $engine = $this->{searchQueryObj};
    }

    no strict 'refs';
    return $engine->query( $query, $inputTopicSet, $session, $options );
    use strict 'refs';
}

sub getRevisionAtTime {
    my ( $this, $topicObject, $time ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    return $handler->getRevisionAtTime($time);
}

sub getLease {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    my $lease = $handler->getLease();
    return $lease;
}

sub setLease {
    my ( $this, $topicObject, $lease ) = @_;

    my $handler = $this->getHandler( $topicObject->web, $topicObject->topic );
    $handler->setLease($lease);
}

sub removeSpuriousLeases {
    my ( $this, $web ) = @_;
    my $handler = $this->getHandler($web);
    $handler->removeSpuriousLeases();
}

1;
__END__
Module of Foswiki Enterprise Collaboration Platform, http://Foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some of the code in this file, as follows

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2001-2008 TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
