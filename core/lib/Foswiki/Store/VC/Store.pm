# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::VC::Store

Almost-complete implementation of =Foswiki::Store=. The methods
of this class implement the =Foswiki::Store= interface.

The store uses a "handler" class to handle all interactions with the
actual version control system (and via it with the actual file system).
A "handler" is created for each individual file in the file system, and
this handler then brokers all requests to open, read, write etc the file.
The handler object must implement the interface specified by
=Foswiki::Store::VC::Handler=.

The main additional responsibilities of _this_ class are to support storing
Foswiki meta-data in plain text files, and to ensure that the =Foswiki::Meta=
for a page is maintained in synchronisation with the files on disk.

All that is required to create a working store is to subclass this class
and override the 'new' method to specify the actual handler to use. See
Foswiki::Store::RcsWrap for an example subclass.

For readers who are familiar with Foswiki version 1.0, the functionality
in this class _previously_ resided in =Foswiki::Store=.

=cut

package Foswiki::Store::VC::Store;
use strict;

use Foswiki::Store ();
our @ISA = ('Foswiki::Store');

use Assert;
use Error qw( :try );

use Foswiki          ();
use Foswiki::Meta    ();
use Foswiki::Sandbox ();

BEGIN {
    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
}

# PACKAGE PRIVATE
# Get a handler for the given object in the store.
sub getHandler {
    #my ( $this, $web, $topic, $attachment ) = @_;
    ASSERT( 0, "Must be implemented by subclasses") if DEBUG;
}

# Documented in Foswiki::Store
sub readTopic {
    my ( $this, $topicObject, $version ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;

    my $handler = $this->getHandler( $topicObject );
    my $text;
    if ($version) {
        $text = $handler->getRevision($version);
    }
    else {
        $text = $handler->getLatestRevision();
    }
    $text =~ s/\r//g;    # Remove carriage returns
    $topicObject->setEmbeddedStoreForm($text);

    # Use the potentially more risky topic version number for speed
    my $gotRev;
    my $ri = $topicObject->get('TOPICINFO');
    if ( defined($ri) ) {
        $gotRev = $ri->{version};
    }
    else {

        # SMELL: Risky. In most cases, I reckon this is going to be OK.
        # Alt kick down to to the handler to get the real deal?
        # Sven reckons it is too slow. Synch the TOPICINFO version number
        # with the handler on save, so they can never get out of step?
        # C.
        $gotRev = $version;
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

            # test if the attachment filename would need sanitizing,
            # if so, ignore it.
            my ( $fileName, $origName ) =
              Foswiki::Sandbox::sanitizeAttachmentName(
                $foundAttachment->{name} );

            if ( $fileName ne $origName ) {
                print STDERR 'AutoAttachPubFiles ignoring '
                  . $origName . ' in '
                    . $topicObject->getPath()
                      . ' - not a valid Foswiki Attachment filename' ;
            }
            else {
                push @validAttachmentsFound, $foundAttachment;
            }
        }

        $topicObject->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
          if @validAttachmentsFound;
    }

    return Foswiki::Store::cleanUpRevID( $gotRev || 1 );
}

# Documented in Foswiki::Store
sub moveAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    my $handler =
      $this->getHandler( $oldTopicObject, $oldAttachment );
    if ( $handler->storedDataExists() ) {
        $handler->moveAttachment( $newTopicObject->web, $newTopicObject->topic,
            $newAttachment );
    }
}

# Documented in Foswiki::Store
sub attachmentExists {
    my ( $this, $topicObject, $att ) = @_;
    my $handler = $this->getHandler( $topicObject, $att );
    return $handler->storedDataExists();
}

# Documented in Foswiki::Store
sub moveTopic {
    my ( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $handler =
      $this->getHandler( $oldTopicObject, '' );
    my $rev = $handler->numRevisions();

    $handler->moveTopic( $newTopicObject->web, $newTopicObject->topic );

    if ( $newTopicObject->web ne $oldTopicObject->web ) {

        # Record that it was moved away
        $handler->recordChange( $cUID, $rev );
    }

    $handler = $this->getHandler( $newTopicObject, '' );
    $handler->recordChange( $cUID, $rev );
}

# Documented in Foswiki::Store
sub moveWeb {
    my ( $this, $oldWebObject, $newWebObject, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $oldWebObject );
    $handler->moveWeb( $newWebObject->web );
}

# Documented in Foswiki::Store
sub testAttachment {
    my ( $this, $topicObject, $attachment, $test ) = @_;
    my $handler = $this->getHandler( $topicObject, $attachment );
    return $handler->test($test);
}

# Documented in Foswiki::Store
sub openAttachment {
    my ( $this, $topicObject, $att, $mode, @opts ) = @_;

    my $handler = $this->getHandler( $topicObject, $att );
    return $handler->openStream( $mode, @opts );
}

# Documented in Foswiki::Store
sub getRevisionNumber {
    my ( $this, $topicObject, $attachment ) = @_;

    my $handler = $this->getHandler( $topicObject, $attachment );
    return $handler->numRevisions();
}

# Documented in Foswiki::Store
sub getRevisionDiff {
    my ( $this, $topicObject, $rev2, $contextLines ) = @_;
    ASSERT( defined($contextLines) ) if DEBUG;

    my $rcs = $this->getHandler( $topicObject );
    return $rcs->revisionDiff(
        $topicObject->getLoadedRev(),
        $rev2,
        $contextLines
    );
}

# Documented in Foswiki::Store
sub getAttachmentVersionInfo {
    my ( $this, $topicObject, $rev, $attachment ) = @_;
    my $handler = $this->getHandler( $topicObject, $attachment );
    return $handler->getInfo($rev || 0);
}

# Documented in Foswiki::Store
sub getVersionInfo {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler( $topicObject );
    return $handler->getInfo();
}

# Documented in Foswiki::Store
sub saveAttachment {
    my ( $this, $topicObject, $name, $stream, $author ) = @_;
    my $handler = $this->getHandler( $topicObject, $name );
    my $currentRev = $handler->numRevisions() || 0;
    my $nextRev = $currentRev + 1;
    $handler->addRevisionFromStream( $stream, 'save attachment', $author );
    return $nextRev;
}

# Documented in Foswiki::Store
sub saveTopic {
    my ( $this, $topicObject, $cUID, $options ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $topicObject );

    $handler->addRevisionFromText( $topicObject->getEmbeddedStoreForm(),
        'save topic', $cUID, $options->{forcedate} );

    # just in case they are not sequential
    my $nextRev = $handler->numRevisions();

    my $extra = $options->{minor} ? 'minor' : '';
    $handler->recordChange( $cUID, $nextRev, $extra );

    return $nextRev;
}

# Documented in Foswiki::Store
sub repRev {
    my ( $this, $topicObject, $cUID, %options ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $info = $topicObject->getRevisionInfo();
    my $handler = $this->getHandler( $topicObject );
    $handler->replaceRevision( $topicObject->getEmbeddedStoreForm(),
        'reprev', $info->{author}, $info->{date} );
}

# Documented in Foswiki::Store
sub delRev {
    my ( $this, $topicObject, $cUID ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $topicObject );
    my $rev = $handler->numRevisions();
    if ( $rev <= 1 ) {
        throw Error::Simple( 'Cannot delete initial revision of '
              . $topicObject->web . '.'
              . $topicObject->topic );
    }
    $handler->deleteRevision();

    # restore last topic from repository
    $handler->restoreLatestRevision($cUID);

    return $rev;
}

# Documented in Foswiki::Store
sub atomicLockInfo {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler( $topicObject );
    return $handler->isLocked();
}

# Documented in Foswiki::Store
# It would be nice to use flock to do this, but the API is unreliable
# (doesn't work on all platforms)
sub atomicLock {
    my ( $this, $topicObject, $cUID ) = @_;
    my $handler = $this->getHandler( $topicObject );
    $handler->setLock( 1, $cUID );
}

# Documented in Foswiki::Store
sub atomicUnlock {
    my ( $this, $topicObject, $cUID ) = @_;

    my $handler = $this->getHandler( $topicObject );
    $handler->setLock( 0, $cUID );
}

# Documented in Foswiki::Store
# A web _has_ to have a preferences topic to be a web.
sub webExists {
    my ( $this, $web ) = @_;

    return 0 unless defined $web;
    $web =~ s#\.#/#go;
    my $handler = $this->getHandler( $web, $Foswiki::cfg{WebPrefsTopicName} );
    return $handler->storedDataExists();
}

# Documented in Foswiki::Store
sub topicExists {
    my ( $this, $web, $topic ) = @_;

    return 0 unless defined $web && $web ne '';
    $web =~ s#\.#/#go;
    return 0 unless defined $topic && $topic ne '';

    my $handler = $this->getHandler( $web, $topic );
    return $handler->storedDataExists();
}

# Documented in Foswiki::Store
sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    my $handler = $this->getHandler( $web, $topic );
    return $handler->getLatestRevisionTime();
}

# Documented in Foswiki::Store
sub eachChange {
    my ( $this, $webObject, $time ) = @_;

    my $handler = $this->getHandler( $webObject );
    return $handler->eachChange($time);
}

# Documented in Foswiki::Store
sub eachAttachment {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler( $topicObject );
    my @list = $handler->getAttachmentList();
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

# Documented in Foswiki::Store
sub eachTopic {
    my ( $this, $webObject ) = @_;

    my $handler = $this->getHandler( $webObject );
    my @list    = $handler->getTopicNames();

    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

# Documented in Foswiki::Store
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

# Documented in Foswiki::Store
sub remove {
    my ( $this, $topicObject, $attachment ) = @_;
    ASSERT( $topicObject->web ) if DEBUG;

    my $handler =
      $this->getHandler( $topicObject, $attachment );
    $handler->remove();
}

# Documented in Foswiki::Store
sub searchInWebMetaData {
    my ( $this, $query, $web, $inputTopicSet, $session, $options ) = @_;
    ASSERT($query);
    ASSERT(  UNIVERSAL::isa( $query, 'Foswiki::Query::Node' )
          || UNIVERSAL::isa( $query, 'Foswiki::Search::Node' ) );

    my $handler = $this->getHandler($web);
    return $handler->searchInWebMetaData(
        $query, $web, $inputTopicSet, $session, $options );
}

# Documented in Foswiki::Store
sub searchInWebContent {
    my ( $this, $searchString, $web, $topics, $session, $options ) = @_;

    my $handler       = $this->getHandler($web);
    my $inputTopicSet = new Foswiki::ListIterator($topics);

    return $handler->searchInWebContent(
        $searchString, $web, $inputTopicSet, $session, $options );
}

# Documented in Foswiki::Store
sub getRevisionAtTime {
    my ( $this, $topicObject, $time ) = @_;

    my $handler = $this->getHandler( $topicObject );
    return $handler->getRevisionAtTime($time);
}

# Documented in Foswiki::Store
sub getLease {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler( $topicObject );
    my $lease = $handler->getLease();
    return $lease;
}

# Documented in Foswiki::Store
sub setLease {
    my ( $this, $topicObject, $lease ) = @_;

    my $handler = $this->getHandler( $topicObject );
    $handler->setLease($lease);
}

# Documented in Foswiki::Store
sub removeSpuriousLeases {
    my ( $this, $web ) = @_;
    my $handler = $this->getHandler($web);
    $handler->removeSpuriousLeases();
}

1;
__END__
Module of Foswiki Enterprise Collaboration Platform, http://Foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
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
