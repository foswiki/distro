# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store

This module hosts the generic storage backend. This module provides
the interface layer between the "real" store provider - which is hidden
behind a handler - and the rest of the system. it is responsible for
checking for topic existance, access permissions, and all the other
general admin tasks that are common to all store implementations.

This module knows nothing about how the data is actually _stored_ -
that knowledge is entirely encapsulated in the handlers.

The general contract for methods in the class requires that errors
are signalled using exceptions. Foswiki::AccessControlException is
used for access control exceptions, and Error::Simple for all other
types of error.

=cut

package Foswiki::Store;

use strict;
use Assert;
use Error qw( :try );

require Foswiki;
require Foswiki::Meta;
require Foswiki::Sandbox;
require Foswiki::AccessControlException;

use vars qw( $STORE_FORMAT_VERSION );

$STORE_FORMAT_VERSION = '1.1';

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new($session)

Construct a Store module, linking in the chosen sub-implementation.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    $this->{IMPL} = 'Foswiki::Store::' . $Foswiki::cfg{StoreImpl};
    eval 'require ' . $this->{IMPL};
    if ($@) {
        die "$this->{IMPL} compile failed $@";
    }

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{IMPL};
    undef $this->{session};
}

# PRIVATE
# Get the handler for the current store implementation.
# $web, $topic and $attachment _must_ be untainted.
sub _getHandler {
    my ( $this, $web, $topic, $attachment ) = @_;

    my $handler = $this->{IMPL}->new( $this->{session}, $web, $topic, $attachment );

    my $map = $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{WebSearchPath};
    if ($Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled}
        && defined ($topic)
        && defined ($map)
        && defined ($map->{$web})
        && !$handler->storedDataExists()
        ) {
        #try the other
        my $newhandler = $this->{IMPL}->new( $this->{session}, $map->{$web}, $topic, $attachment );
        if ($newhandler->storedDataExists()) {
            $handler = $newhandler;
        }
    }

    return $handler;
}

=begin TML

---++ ObjectMethod readTopic($user, $web, $topic, $version) -> ($metaObject, $text)

Reads the given version of a topic and it's meta-data. If the version
is undef, then read the most recent version. The version number must be
an integer, or undef for the latest version.

if $user is defined, view permission will be required for the topic
read to be successful.  Access control violations are flagged by a
Foswiki::AccessControlException. Permissions are checked for the user
name passed in.

If the topic contains a web specification (is of the form Web.Topic) the
web specification will override whatever is passed in $web.

The metadata and topic text are returned separately, with the metadata in a
Foswiki::Meta object.  (The topic text is, as usual, just a string.)

=cut

sub readTopic {
    my ( $this, $user, $web, $topic, $version ) = @_;
    $web =~ s#\.#/#go;

    if ( defined $version ) {
        $version = $this->cleanUpRevID($version);
    }

    # SMELL: assumes that the backend can't store meta outside the topic
    my $text = $this->readTopicRaw( $user, $web, $topic, $version );
    my $meta = new Foswiki::Meta( $this->{session}, $web, $topic, $text );

    # Override meta with that blended from pub.
    if (
           $Foswiki::cfg{AutoAttachPubFiles}
        && $web eq $this->{session}->{webName}
        &&    # only check the currently requested topic
        $topic eq $this->{session}->{topicName}
      )
    {

        my @knownAttachments = $meta->find('FILEATTACHMENT');
        my @attachmentsFoundInPub =
          _findAttachments( $this, $web, $topic, \@knownAttachments );
        my @validAttachmentsFound;
        foreach my $foundAttachment (@attachmentsFoundInPub) {
            my ( $fileName, $origName ) =
              Foswiki::Sandbox::sanitizeAttachmentName(
                $foundAttachment->{name} );

        #test if the attachment filenam would need sanitizing, if so, ignore it.
            if ( $fileName ne $origName ) {
                $this->{session}->logger->log('warning',
"AutoAttachPubFiles ignoring $origName, in $web.$topic - not a valid Attachment filename"
                );
            }
            else {
                push @validAttachmentsFound, $foundAttachment;
            }
        }

        $meta->putAll( 'FILEATTACHMENT', @validAttachmentsFound )
          if @validAttachmentsFound;
    }

    return ( $meta, $meta->text() );
}

=begin TML 

---++ ObjectMethod _findAttachments($session, $web, $topic, $knownAttachments) -> @attachmentsFoundInPub

Synchronise the attachment list with what's actually on disk Returns an ARRAY
of FILEATTACHMENTs. These can be put in the new meta using
meta->put('FILEATTACHMENTS', $tree) 

This function is only called when the AutoAttachPubFiles configuration option is set.

IDEA On Windows machines where the underlying filesystem can store arbitary
meta data against files, this might replace/fulfil the COMMENT purpose

TODO consider logging when things are added to metadata

=cut

sub _findAttachments {
    my ( $this, $web, $topic, $attachmentsKnownInMeta ) = @_;
    my $session = $this->{session};
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    my $store = $this;

    my %filesListedInPub = $store->getAttachmentList( $web, $topic );
    my %filesListedInMeta = ();

    # You need the following lines if you want metadata to supplement
    # the filesystem
    if ( defined $attachmentsKnownInMeta ) {
        %filesListedInMeta = map { $_->{name} => $_ } @$attachmentsKnownInMeta;
    }

    foreach my $file ( keys %filesListedInPub ) {
        if ( $filesListedInMeta{$file} ) {

     # Bring forward any missing yet wanted attributes
     #SMELL: this will over-write (empty) any meta data field not listed here :(
            foreach my $field qw(comment attr user version) {
                if ( $filesListedInMeta{$file}{$field} ) {
                    $filesListedInPub{$file}{$field} =
                      $filesListedInMeta{$file}{$field};
                }
            }

            # Develop:Bugs.Item452 - WHY IS USER STILL WRONG?
        }
    }

    # A comparison of the keys of the $filesListedInMeta and %filesListedInPub
    # would show files that were in Meta but have disappeared from Pub.

    # SMELL Meta really ought index its attachments in a hash by attachment
    # name but this is not the case
    #
    # SMELL: Do not change this from array to hash, you would lose the
    # proper attachment sequence
    #
    my @deindexedBecauseMetaDoesnotIndexAttachments = values(%filesListedInPub);

    return @deindexedBecauseMetaDoesnotIndexAttachments;
}

=begin TML

---++ ObjectMethod readTopicRaw( $user, $web, $topic, $version ) ->  $topicText

Reads the given version of a topic, without separating out any embedded
meta-data. If the version is undef, then read the most recent version.
The version number must be an integer or undef.

If $user is defined, view permission will be required for the topic
read to be successful.  Access control violations are flagged by a
Foswiki::AccessControlException. Permissions are checked for the user
name passed in.

If the topic contains a web specification (is of the form Web.Topic) the
web specification will override whatever is passed in $web.

SMELL: DO NOT CALL THIS METHOD UNLESS YOU HAVE NO CHOICE. This method breaks
encapsulation of the store, as it assumes meta is stored embedded in the text.
Other implementors of store will be forced to insert meta-data to ensure
correct operation of View raw=debug and the 'repRev' mode of Edit.

$web and $topic _must_ be untainted.

=cut

sub readTopicRaw {
    my ( $this, $user, $web, $topic, $version ) = @_;
    $web =~ s#\.#/#go;

    # test if topic contains a webName to override $web
    ( $web, $topic ) = $this->{session}->normalizeWebTopicName( $web, $topic );

    my $text;

    my $handler = _getHandler( $this, $web, $topic );
    unless ($version) {
        $text = $handler->getLatestRevision();
    }
    else {
        $text = $handler->getRevision($version);
    }

    # Note: passing undef as meta will cause extraction of the meta
    # from the (raw) text passed
    # SMELL: assumes that the backend can't store meta outside the topic
    if (
        $user
        && !$this->{session}->security->checkAccessPermission(
            'VIEW', $user, $text, undef, $topic, $web
        )
      )
    {
        my $users = $this->{session}->{users};
        throw Foswiki::AccessControlException( 'VIEW', $user, $web, $topic,
            $this->{session}->security->getReason() );
    }

    return $text;
}

=begin TML

---++ ObjectMethod moveAttachment( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment, $user  )

Move an attachment from one topic to another.

The caller to this routine should check that all topics are valid.

All parameters must be defined, and must be untainted.

=cut

sub moveAttachment {
    my ( $this, $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic,
        $newAttachment, $user )
      = @_;
    my $users = $this->{session}->{users};

    $this->lockTopic( $user, $oldWeb, $oldTopic );
    try {
        my ( $ometa, $otext ) = $this->readTopic( undef, $oldWeb, $oldTopic );
        if (
            $user
            && !$this->{session}->security->checkAccessPermission(
                'CHANGE', $user, $otext, $ometa, $oldTopic, $oldWeb
            )
          )
        {
            throw Foswiki::AccessControlException( 'CHANGE', $user, $oldWeb,
                $oldTopic, $this->{session}->security->getReason() );
        }

        my ( $nmeta, $ntext ) = $this->readTopic( undef, $newWeb, $newTopic );
        if (
            $user
            && !$this->{session}->security->checkAccessPermission(
                'CHANGE', $user, $ntext, $nmeta, $newTopic, $newWeb
            )
          )
        {
            throw Foswiki::AccessControlException( 'CHANGE', $user, $newWeb,
                $newTopic, $this->{session}->security->getReason() );
        }

        # Remove file attachment from old topic
        my $handler = _getHandler( $this, $oldWeb, $oldTopic, $oldAttachment );

        $handler->moveAttachment( $newWeb, $newTopic, $newAttachment );

        my $fileAttachment = $ometa->get( 'FILEATTACHMENT', $oldAttachment );
        $ometa->remove( 'FILEATTACHMENT', $oldAttachment );
        _noHandlersSave( $this, $user, $oldWeb, $oldTopic, $otext, $ometa,
            { notify => 0 } );

        # we move the attachment in the the old topic
        # so we need to remove the attachment in nmeta
        if ( $oldTopic eq $newTopic && $oldWeb eq $newWeb ) {
            $nmeta->remove( 'FILEATTACHMENT', $oldAttachment );
        }

        # Add file attachment to new topic
        $fileAttachment->{name} = $newAttachment;
        $fileAttachment->{movefrom} =
          $oldWeb . '.' . $oldTopic . '.' . $oldAttachment;
        $fileAttachment->{moveby} = $user;
        $fileAttachment->{movedto} =
          $newWeb . '.' . $newTopic . '.' . $newAttachment;
        $fileAttachment->{movedwhen} = time();
        $nmeta->putKeyed( 'FILEATTACHMENT', $fileAttachment );

        _noHandlersSave(
            $this, $user, $newWeb,
            $newTopic,
            $ntext, $nmeta,
            {
                dontlog => 1,
                notify  => 0,
                comment => 'moved'
            }
        );
        $this->{session}->logEvent(
            'move',
            $fileAttachment->{movefrom}
              . ' moved to '
              . $fileAttachment->{movedto},
            $users->webDotWikiName($user)
        );
    }
    finally {
        $this->unlockTopic( $user, $oldWeb, $oldTopic );
        $this->unlockTopic( $user, $newWeb, $newTopic );
    };

    # alert plugins of attachment move
    $this->{session}->{plugins}
      ->dispatch( 'afterRenameHandler', $oldWeb, $oldTopic, $oldAttachment,
        $newWeb, $newTopic, $newAttachment );
}

=begin TML

---++ ObjectMethod getAttachmentStream( $user, $web, $topic, $attName ) -> \*STREAM

   * =$user= - the user doing the reading, or undef if no access checks
   * =$web= - The web
   * =$topic= - The topic
   * =$attName= - Name of the attachment

Open a standard input stream from an attachment.

If $user is defined, view permission will be required for the topic
read to be successful.  Access control violations and errors will
cause exceptions to be thrown.

Permissions are checked for the user name passed in.

=cut

sub getAttachmentStream {
    my ( $this, $user, $web, $topic, $att ) = @_;

    if (
        $user
        && !$this->{session}->security->checkAccessPermission(
            'VIEW', $user, undef, undef, $topic, $web
        )
      )
    {
        my $users = $this->{session}->{users};
        throw Foswiki::AccessControlException( 'VIEW', $user, $web, $topic,
            $this->{session}->security->getReason() );
    }

    my $handler = _getHandler( $this, $web, $topic, $att );
    return $handler->getStream();
}

=begin TML

---++ ObjectMethod getAttachmentList($web, $topic)

returns @($attachmentName => [stat]) for any given web, topic

=cut

sub getAttachmentList {
    my ( $this, $web, $topic ) = @_;

    my $handler = _getHandler( $this, $web, $topic );
    return $handler->getAttachmentList( $web, $topic );
}

=begin TML

---++ ObjectMethod attachmentExists( $web, $topic, $att ) -> $boolean

Determine if the attachment already exists on the given topic

=cut

sub attachmentExists {
    my ( $this, $web, $topic, $att ) = @_;

    my $handler = _getHandler( $this, $web, $topic, $att );
    return $handler->storedDataExists();
}

=begin TML

---++ ObjectMethod _removeAutoAttachmentsFromMeta

This is where we are going to remove from meta any entry that is marked as an automatic attachment.

=cut

sub _removeAutoAttachmentsFromMeta {
    my ( $this, $meta ) = @_;

    #    use Data::Dumper;
    #    die "removeAutoAttachmentsFromMeta".Dumper($meta);
    return $meta;
}

=begin TML

---++ ObjectMethod moveTopic(  $oldWeb, $oldTopic, $newWeb, $newTopic, $user )

All parameters must be defined and must be untainted.

=cut

sub moveTopic {
    my ( $this, $oldWeb, $oldTopic, $newWeb, $newTopic, $user ) = @_;

    my $handler = _getHandler( $this, $oldWeb, $oldTopic, '' );
    my $rev     = $handler->numRevisions();
    my $users   = $this->{session}->{users};

    # will block
    $this->lockTopic( $user, $oldWeb, $oldTopic );

    # Clear outstanding leases. We assume that the caller has checked
    # that the lease is OK to kill.
    $this->clearLease( $oldWeb, $oldTopic )
      if $this->getLease( $oldWeb, $oldTopic );

    try {
        my $otext = $this->readTopicRaw( undef, $oldWeb, $oldTopic );

        # Note: undef $meta param will cause $otext to be parsed for meta
        if (
            $user
            && !$this->{session}->security->checkAccessPermission(
                'CHANGE', $user, $otext, undef, $oldTopic, $oldWeb
            )
          )
        {
            throw Foswiki::AccessControlException( 'CHANGE', $user, $oldWeb,
                $oldTopic, $this->{session}->security->getReason() );
        }

        my ( $nmeta, $ntext );
        if ( $this->topicExists( $newWeb, $newTopic ) ) {
            ( $nmeta, $ntext ) = $this->readTopic( undef, $newWeb, $newTopic );
        }
        if (
            $user
            && !$this->{session}->security->checkAccessPermission(
                'CHANGE', $user, $ntext, $nmeta, $newTopic, $newWeb
            )
          )
        {
            throw Foswiki::AccessControlException( 'CHANGE', $user, $newWeb,
                $newTopic, $this->{session}->security->getReason() );
        }

        $handler->moveTopic( $newWeb, $newTopic );
    }
    finally {
        $this->unlockTopic( $user, $oldWeb, $oldTopic );
    };

    if ( $newWeb ne $oldWeb ) {

        # Record that it was moved away
        $handler->recordChange( $user, $rev );
    }

    $handler = _getHandler( $this, $newWeb, $newTopic, '' );
    $handler->recordChange( $user, $rev );

    # Log rename
    if ( $Foswiki::cfg{Log}{rename} ) {
        my $old = $oldWeb . '.' . $oldTopic;
        my $new = $newWeb . '.' . $newTopic;
        $this->{session}->logEvent('rename', $old, "moved to $new", $user );
    }

    # alert plugins of topic move
    $this->{session}->{plugins}
      ->dispatch( 'afterRenameHandler', $oldWeb, $oldTopic, '', $newWeb,
        $newTopic, '' );
}

=begin TML

---++ ObjectMethod moveWeb( $oldWeb, $newWeb, $user )

Move a web.

All parrameters must be defined and must be untainted.

=cut

sub moveWeb {
    my ( $this, $oldWeb, $newWeb, $user ) = @_;

    $oldWeb =~ s/\./\//go;
    $newWeb =~ s/\./\//go;

    my (@webList) = $this->getListOfWebs( 'public', $oldWeb );
    unshift( @webList, $oldWeb );
    foreach my $webIter (@webList) {
        if ($webIter) {
            my @webTopicList = $this->getTopicNames($webIter);
            foreach my $webTopic (@webTopicList) {
                $this->lockTopic( $user, $webIter, $webTopic );
            }
        }
    }

    my @newParentPath = split( /\//, $newWeb );
    pop(@newParentPath);
    my $newParent = join( '/', @newParentPath );

    my $handler = _getHandler( $this, $oldWeb );
    $handler->moveWeb($newWeb);

    (@webList) = $this->getListOfWebs( 'public', $newWeb );
    unshift( @webList, $newWeb );
    foreach my $webIter (@webList) {
        if ($webIter) {
            my @webTopicList = $this->getTopicNames($webIter);
            foreach my $webTopic (@webTopicList) {
                $this->unlockTopic( $user, $webIter, $webTopic );
            }
        }
    }

    # Log rename
    if ( $Foswiki::cfg{Log}{rename} ) {
        $this->{session}
          ->logEvent('renameweb', $oldWeb, 'moved to ' . $newWeb, $user );
    }

    # alert plugins of web move
    $this->{session}->{plugins}
      ->dispatch( 'afterRenameHandler', $oldWeb, '', '', $newWeb, '', '' );
}

=begin TML

---++ ObjectMethod readAttachment( $user, $web, $topic, $attachment, $theRev  ) -> $text

Read the given version of an attachment, returning the content.

View permission on the topic is required for the
read to be successful.  Access control violations are flagged by a
Foswiki::AccessControlException. Permissions are checked for the user
passed in.

If $theRev is not given, the most recent rev is assumed.

=cut

sub readAttachment {
    my ( $this, $user, $web, $topic, $attachment, $theRev ) = @_;

    if (
        $user
        && !$this->{session}->security->checkAccessPermission(
            'VIEW', $user, undef, undef, $topic, $web
        )
      )
    {
        my $users = $this->{session}->{users};
        throw Foswiki::AccessControlException( 'VIEW', $user, $web, $topic,
            $this->{session}->security->getReason() );
    }

    my $handler = _getHandler( $this, $web, $topic, $attachment );
    return $handler->getRevision($theRev);
}

=begin TML

---++ ObjectMethod getRevisionNumber ( $web, $topic, $attachment  ) -> $integer

Get the revision number of the most recent revision. Returns
the integer revision number or '' if the topic doesn't exist.

WORKS FOR ATTACHMENTS AS WELL AS TOPICS

=cut

sub getRevisionNumber {
    my ( $this, $web, $topic, $attachment ) = @_;

    $attachment = '' unless $attachment;

    my $handler = _getHandler( $this, $web, $topic, $attachment );
    return $handler->numRevisions();
}

=begin TML

---+++ ObjectMethod getWorkArea( $key ) -> $directorypath

Gets a private directory uniquely identified by $key. The directory is
intended as a work area for plugins. The directory will exist.

=cut

sub getWorkArea {
    my ( $this, $key ) = @_;

    my $handler = _getHandler( $this, );
    return $handler->getWorkArea($key);
}

=begin TML

---++ ObjectMethod getRevisionDiff ( $user, $web, $topic, $rev1, $rev2, $contextLines  ) -> \@diffArray

Return reference to an array of [ diffType, $right, $left ]
   * =$user= - the user id, or undef to suppress access control checks
   * =$web= - the web
   * =$topic= - the topic
   * =$rev1= Integer revision number
   * =$rev2= Integer revision number
   * =$contextLines= - number of lines of context required

=cut

sub getRevisionDiff {
    my ( $this, $user, $web, $topic, $rev1, $rev2, $contextLines ) = @_;
    ASSERT( defined($contextLines) ) if DEBUG;
    if ($user) {
        my $r1;
        try {

            # Make sure both revs are readable.
            $r1 = $this->readTopicRaw( $user, $web, $topic, $rev1 );
        }
        catch Foswiki::AccessControlException with {
            $r1 = undef;
        };
        my $r2;
        try {
            $r2 = $this->readTopicRaw( $user, $web, $topic, $rev2 );
        }
        catch Foswiki::AccessControlException with {
            $r2 = undef;
        };
        my $rd;
        if ( !defined($r1) ) {
            $rd = [ [ '-', " *Revision $rev1 is unreadable* ", '' ] ];
            if ( !defined($r2) ) {
                push( @$rd, [ '+', '', " *Revision $rev2 is unreadable* " ] );
            }
            else {
                foreach ( split( /\r?\n/, $r2 ) ) {
                    push( @$rd, [ '+', '', $_ ] );
                }
            }
        }
        elsif ( !defined($r2) ) {
            $rd = [ [ '+', '', " *Revision $rev2 is unreadable* " ] ];
            foreach ( split( /\r?\n/, $r1 ) ) {
                push( @$rd, [ '-', $_, '' ] );
            }
        }
        return $rd if $rd;
    }

    my $rcs = _getHandler( $this, $web, $topic );
    return $rcs->revisionDiff( $rev1, $rev2, $contextLines );
}

=begin TML

---++ ObjectMethod getRevisionInfo($web, $topic, $rev, $attachment) -> ( $date, $user, $rev, $comment )

Get revision info of a topic.
   * =$web= Web name, optional, e.g. ='Main'=
   * =$topic= Topic name, required, e.g. ='TokyoOffice'=
   * =$rev= revision number. If 0, undef, or out-of-range, will get info about the most recent revision.
   * =$attachment= attachment filename; undef for a topic
Return list with: ( last update date, last user id, =
| $date | in epochSec |
| $user | user *object* |
| $rev | the revision number |
| $comment | WHAT COMMENT? |
e.g. =( 1234561, 'phoeny', 5, 'no comment' )

NOTE NOTE NOTE if you are working within the Foswiki code DO NOT USE THIS
FUNCTION FOR GETTING REVISION INFO OF TOPICS - use
Foswiki::Meta::getRevisionInfo instead. This is essential to allow clean
transition to a topic object model later, and avoids the risk of confusion
coming from meta and Store revision information being out of step.
(it's OK to use it for attachments)

=cut

sub getRevisionInfo {
    my ( $this, $web, $topic, $rev, $attachment ) = @_;

    $rev ||= 0;

    my $handler = _getHandler( $this, $web, $topic, $attachment );

    my ( $rrev, $date, $user, $comment ) = $handler->getRevisionInfo($rev);
    $rev = $rrev;

    return ( $date, $user, $rev, $comment );
}

=begin TML

---++ StaticMethod dataEncode( $uncoded ) -> $coded

Encode meta-data fields, escaping out selected characters. The encoding
is chosen to avoid problems with parsing the attribute values, while
minimising the number of characters encoded so searches can still work
(fairly) sensibly.

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataEncode {
    my $datum = shift;

    $datum =~ s/([%"\r\n{}])/'%'.sprintf('%02x',ord($1))/ge;
    return $datum;
}

=begin TML

---++ StaticMethod dataDecode( $encoded ) -> $decoded

Decode escapes in a string that was encoded using dataEncode

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataDecode {
    my $datum = shift;

    $datum =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    return $datum;
}

# STATIC Build a hash by parsing name=value comma separated pairs
# SMELL: duplication of Foswiki::Attrs, using a different
# system of escapes :-(
sub _readKeyValues {
    my ( $args, $format ) = @_;
    my $res = {};

    $format =~ s/[^\d\.]+//g if $format;
    my $oldStyle = ( !$format || $format =~ /[^\d.]/ || $format < 1.1 );

    # Format of data is name='value' name1='value1' [...]
    $args =~ s/\s*([^=]+)="([^"]*)"/_singleKey($1,$2,$res,$oldStyle)/ge;

    return $res;
}

sub _singleKey {
    my ( $key, $value, $res, $oldStyle ) = @_;

    if ($oldStyle) {

        # Old decoding retained for backward compatibility
        # (this encoding is badly broken)
        $value =~ s/%_N_%/\n/g;
        $value =~ s/%_Q_%/\"/g;
        $value =~ s/%_P_%/%/g;
    }
    else {
        $value = dataDecode($value);
    }

    $res->{$key} = $value;

    return '';
}

=begin TML

---++ ObjectMethod saveTopic( $user, $web, $topic, $text, $meta, $options  )

   * =$user= - user doing the saving (object)
   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$text= - topic text
   * =$meta= - topic meta-data
   * =$options= - Ref to hash of options
=$options= may include:
| =dontlog= | don't log this change in twiki log |
| =hide= | if the attachment is to be hidden in normal topic view |
| =comment= | comment for save |
| =file= | Temporary file name to upload |
| =minor= | True if this is a minor change (used in log) |
| =savecmd= | Save command |
| =forcedate= | grr |
| =unlock= | |

Save a new revision of the topic, calling plugins handlers as appropriate.

=cut

sub saveTopic {
    my ( $this, $user, $web, $topic, $text, $meta, $options ) = @_;
    ASSERT($user) if DEBUG;
    $web =~ s#\.#/#go;
    $meta = _removeAutoAttachmentsFromMeta( $this, $meta );
    my $users = $this->{session}->{users};

    $options = {} unless defined($options);
    if (
        $user
        && !$this->{session}->security->checkAccessPermission(
            'CHANGE', $user, undef, undef, $topic, $web
        )
      )
    {
        throw Foswiki::AccessControlException( 'CHANGE', $user, $web, $topic,
            $this->{session}->security->getReason() );
    }
    my $plugins = $this->{session}->{plugins};

    # Semantics inherited from Cairo. See
    # TWiki:Codev.BugBeforeSaveHandlerBroken
    if ( $plugins->haveHandlerFor('beforeSaveHandler') ) {
        my $before = '';
        if ($meta) {

            # write the meta into the topic text. Nasty compatibility
            # requirement.
            $meta->text($text);
            $text   = $meta->getEmbeddedStoreForm();
            $before = $meta->stringify();
        }
        $plugins->dispatch( 'beforeSaveHandler', $text, $topic, $web, $meta );

        # remove meta again
        my $after = new Foswiki::Meta( $this->{session}, $web, $topic, $text );
        $text = $after->text();

        # If there are no changes in the $meta object, take the meta
        # from the text. Nasty compatibility requirement.
        if ( !$meta || $meta->stringify() eq $before ) {
            $meta = $after;
        }
    }

    my $error;
    try {
        _noHandlersSave( $this, $user, $web, $topic, $text, $meta, $options );
    }
    catch Error::Simple with {
        $error = shift;
    };

    # Semantics inherited from Cairo. See
    # TWiki:Codev.BugBeforeSaveHandlerBroken
    if ( $plugins->haveHandlerFor('afterSaveHandler') ) {
        if ($meta) {
            $meta->text($text);
            $text = $meta->getEmbeddedStoreForm();
        }
        $plugins->dispatch( 'afterSaveHandler', $text, $topic, $web,
            $error ? $error->{-text} : '', $meta );
    }

    throw $error if $error;
}

=begin TML

---++ ObjectMethod saveAttachment ($web, $topic, $attachment, $user, $opts )

   * =$user= - user doing the saving
   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$attachment= - name of the attachment
   * =$opts= - Ref to hash of options
=$opts= may include:
| =dontlog= | don't log this change in twiki log |
| =comment= | comment for save |
| =hide= | if the attachment is to be hidden in normal topic view |
| =stream= | Stream of file to upload |
| =file= | Name of a file to use for the attachment data. ignored is stream is set. |
| =filepath= | Client path to file |
| =filesize= | Size of uploaded data |
| =filedate= | Date |
| =tmpFilename= | Pathname of the server file the stream is attached to. Required if stream is set. |

Saves a new revision of the attachment, invoking plugin handlers as
appropriate.

If file is not set, this is a properties-only save.

=cut

sub saveAttachment {
    my ( $this, $web, $topic, $attachment, $user, $opts ) = @_;
    ASSERT( defined($opts) ) if DEBUG;
    my $action;
    my $plugins = $this->{session}->{plugins};
    my $attrs;
    my $users = $this->{session}->{users};

    $this->lockTopic( $user, $web, $topic );

    try {

        # update topic
        my ( $meta, $text ) = $this->readTopic( undef, $web, $topic, undef );

        if (
            $user
            && !$this->{session}->security->checkAccessPermission(
                'CHANGE', $user, $text, $meta, $topic, $web
            )
          )
        {

            throw Foswiki::AccessControlException( 'CHANGE', $user, $web, $topic,
                $this->{session}->security->getReason() );
        }

        if ( $opts->{file} && !$opts->{stream} ) {
            open( $opts->{stream}, "<$opts->{file}" )
              || throw Error::Simple( 'Could not open ' . $opts->{file} );
            binmode( $opts->{stream} )
              || throw Error::Simple(
                $opts->{file} . ' binmode failed: ' . $! );
            $opts->{tmpFilename} = $opts->{file};
        }
        if ( $opts->{stream} ) {
            $action = 'upload';

            $attrs = {
                attachment  => $attachment,
                stream      => $opts->{stream},
                tmpFilename => $opts->{tmpFilename},
                user        => $user,
            };
            $attrs->{comment} = $opts->{comment}
              if ( defined( $opts->{comment} ) );

            my $handler = _getHandler( $this, $web, $topic, $attachment );

            my $tmpFile;

            if ( $plugins->haveHandlerFor('beforeAttachmentSaveHandler') ) {

                # We create an extra temporary copy of the uploaded file
                # It appears that under some circumstances the CGI deletes
                # the uploaded file when you close it even though the doco
                # says it is deleted when it goes out of scope.
                # The code below has proven to work for all. See Item5307

                use File::Temp;
                use Errno qw/EINTR/;

                my $fh;
                ( $fh, $tmpFile ) = File::Temp::tempfile();
                binmode($fh);

                # transfer 512KB blocks
                my $transfer;
                my $r;
                while ( $r = sysread( $opts->{stream}, $transfer, 0x80000 ) ) {
                    if( !defined $r ) {
                        next if $! == EINTR;
                        die "system read error: $!";
                    }
                my $offset = 0;
                    while( $r ) {
                        my $w = syswrite( $fh, $transfer, $r, $offset );
                        die "system write error: $!" unless defined $w;
                        $offset += $w;
                        $r -= $w;
                    }
                }

                select( (select($fh), $| = 1 )[0]);
                seek( $fh, 0, 0 ) or die "Can't seek temp: $!";
                $opts->{stream} = $fh;
                $attrs->{tmpFilename} = $tmpFile;
                $plugins->dispatch( 'beforeAttachmentSaveHandler',
                    $attrs, $topic, $web );
            }
            my $error;
            try {
                $handler->addRevisionFromStream( $opts->{stream},
                    $opts->{comment}, $user );
            }
            catch Error::Simple with {
                $error = shift;
            };

            unlink($tmpFile) if ( $tmpFile && -e $tmpFile );

            if ( $plugins->haveHandlerFor('afterAttachmentSaveHandler') ) {
                $plugins->dispatch( 'afterAttachmentSaveHandler', $attrs,
                    $topic, $web, $error ? $error->{-text} : '' );
            }
            throw $error if $error;

            $attrs->{name} ||= $attachment;
            my $fileVersion =
              $this->getRevisionNumber( $web, $topic, $attachment );
            $attrs->{version} = $fileVersion;
            $attrs->{path}    = $opts->{filepath}
              if ( defined( $opts->{filepath} ) );
            $attrs->{size} = $opts->{filesize}
              if ( defined( $opts->{filesize} ) );
            $attrs->{date} = $opts->{filedate}
              if ( defined( $opts->{filedate} ) );
        }
        else {

            # Property change
            $action           = 'save';
            $attrs            = $meta->get( 'FILEATTACHMENT', $attachment );
            $attrs->{name}    = $attachment;
            $attrs->{comment} = $opts->{comment}
              if ( defined( $opts->{comment} ) );
        }
        $attrs->{attr} = ( $opts->{hide} ) ? 'h' : '';
        $meta->putKeyed( 'FILEATTACHMENT', $attrs );

        if ( $opts->{createlink} ) {
            $text .=
              $this->{session}
              ->attach->getAttachmentLink( $user, $web, $topic, $attachment,
                $meta );
        }

        $this->saveTopic( $user, $web, $topic, $text, $meta, {} );

    }
    finally {
        $this->unlockTopic( $user, $web, $topic );
    };

    if ( ( !$opts->{dontlog} ) && ( $Foswiki::cfg{Log}{$action} ) ) {
        $this->{session}
          ->logEvent($action, $web . '.' . $topic, $attachment, $user );
    }
}

# Save a topic or attachment _without_ invoking plugin handlers.
# FIXME: does rev info from meta work if user saves a topic with no change?
sub _noHandlersSave {
    my ( $this, $user, $web, $topic, $text, $meta, $options ) = @_;

    $meta ||= new Foswiki::Meta( $this->{session}, $web, $topic );

    my $users      = $this->{session}->{users};
    my $handler    = _getHandler( $this, $web, $topic );
    my $currentRev = $handler->numRevisions() || 0;
    my $nextRev    = $currentRev + 1;

    if ( $currentRev && !$options->{forcenewrevision} ) {

        # See if we want to replace the existing top revision
        my $mtime1 = $handler->getTimestamp();
        my $mtime2 = time();

        if (
            abs( $mtime2 - $mtime1 ) < $Foswiki::cfg{ReplaceIfEditedAgainWithin} )
        {

            my ( $rev, $date, $revuser, $comment ) =
              $handler->getRevisionInfo($currentRev);

            # same user?
            if ( $revuser eq $user ) {
                $this->repRev( $user, $web, $topic, $text, $meta, $options );
                return;
            }
        }
    }

    if ($meta) {
        $meta->addTOPICINFO( $nextRev, time(), $user, 0,
            $STORE_FORMAT_VERSION );
        $meta->text($text);
        $text = $meta->getEmbeddedStoreForm();
    }

    # will block
    $this->lockTopic( $user, $web, $topic );

    try {
        $handler->addRevisionFromText( $text, $options->{comment}, $user );

        # just in case they are not sequential
        $nextRev = $handler->numRevisions();

        my $extra = $options->{minor} ? 'minor' : '';
        $handler->recordChange( $user, $nextRev, $extra );

        if ( ( $Foswiki::cfg{Log}{save} ) && !( $options->{dontlog} ) ) {
            $this->{session}
              ->logEvent('save', $web . '.' . $topic, $extra, $user );
        }
    }
    finally {
        $this->unlockTopic( $user, $web, $topic );
    };
}

=begin TML

---++ ObjectMethod repRev( $user, $web, $topic, $text, $meta, $options )

Replace last (top) revision with different text.

Parameters and return value as saveTopic, except
   * =$options= - as for saveTopic, with the extra option:
      * =timetravel= - if we want to force the deposited revision to look as much like the revision specified in =$rev= as possible.
      * =operation= - set to the name of the operation performing the save. This is used only in the log, and is normally =cmd= or =save=. It defaults to =save=.

Used to try to avoid the deposition of 'unecessary' revisions, for example
where a user quickly goes back and fixes a spelling error.

Also provided as a means for administrators to rewrite history (timetravel).

It is up to the store implementation if this is different
to a normal save or not.

=cut

sub repRev {
    my ( $this, $user, $web, $topic, $text, $meta, $options ) = @_;

    ASSERT( $meta && $meta->isa('Foswiki::Meta') ) if DEBUG;

    my ( $revdate, $revuser, $rev ) = $meta->getRevisionInfo();
    my $users = $this->{session}->{users};

    # RCS requires a newline for the last line,
    $text .= "\n" unless $text =~ /\n$/s;

    if ( $options->{timetravel} ) {

        # We are trying to force the rev to be saved with the same date
        # and user as the prior rev. However, exactly the same date may
        # cause some revision control systems to barf, so to avoid this we
        # add 1 minute to the rev time. Note that this mode of operation
        # will normally require sysadmin privilege, as it can result in
        # confused rev dates if abused.
        $revdate += 60;
    }
    else {

        # use defaults (current time, current user)
        $revdate = time();
        $revuser = $user;
    }
    $meta->addTOPICINFO( $rev, $revdate, $revuser, 1, $STORE_FORMAT_VERSION );
    $meta->text($text);
    $text = $meta->getEmbeddedStoreForm();

    $this->lockTopic( $user, $web, $topic );
    try {
        my $handler = _getHandler( $this, $web, $topic );
        $handler->replaceRevision( $text, $options->{comment}, $revuser,
            $revdate );
    }
    finally {
        $this->unlockTopic( $user, $web, $topic );
    };

    if ( ( $Foswiki::cfg{Log}{save} ) && !( $options->{dontlog} ) ) {

        # write log entry
        require Foswiki::Time;

        my $extra =
            "repRev $rev by " 
          . $revuser . ' '
          . Foswiki::Time::formatTime( $revdate, '$rcs', 'gmtime' );
        $extra .= ' minor' if ( $options->{minor} );
        $this->{session}->logEvent(
            $options->{operation} || 'save',
            $web . '.' . $topic,
            $extra, $user
        );
    }
}

=begin TML

---++ ObjectMethod delRev( $user, $web, $topic, $text, $meta, $options )

Parameters and return value as saveTopic.

Provided as a means for administrators to rewrite history.

Delete last entry in repository, restoring the previous
revision.

It is up to the store implementation whether this actually
does delete a revision or not; some implementations will
simply promote the previous revision up to the head.

=cut

sub delRev {
    my ( $this, $user, $web, $topic ) = @_;

    my $rev = $this->getRevisionNumber( $web, $topic );
    if ( $rev <= 1 ) {
        throw Error::Simple(
            'Cannot delete initial revision of ' . $web . '.' . $topic );
    }

    $this->lockTopic( $user, $web, $topic );
    try {
        my $handler = _getHandler( $this, $web, $topic );
        $handler->deleteRevision();

        # restore last topic from repository
        $handler->restoreLatestRevision($user);
    }
    finally {
        $this->unlockTopic( $user, $web, $topic );
    };

    # TODO: delete entry in .changes

    # write log entry
    $this->{session}->logEvent(
        'cmd',
        $web . '.' . $topic,
        'delRev by ' . $user . ": $rev", $user
    );
}

=begin TML

---++ ObjectMethod lockTopic( $web, $topic )

Grab a topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. A lock has a
maximum lifetime of 2 minutes, so operations on a locked topic
must be completed within that time. You cannot rely on the
lock timeout clearing the lock, though; that should always
be done by calling unlockTopic. The best thing to do is to guard
the locked section with a try..finally clause. See man Error for more info.

Topic locks are used to make store operations atomic. They are
_note_ the locks used when a topic is edited; those are Leases
(see =getLease=)

=cut

sub lockTopic {
    my ( $this, $locker, $web, $topic ) = @_;
    ASSERT( $web && $topic ) if DEBUG;

    my $handler = _getHandler( $this, $web, $topic );
    my $users = $this->{session}->{users};

    while (1) {
        my ( $user, $time ) = $handler->isLocked();
        last if ( !$user || $locker eq $user );
        $this->{session}->logger->log(
            'warning',
            "Lock on $web.$topic for " . $locker . " denied by $user" );

        # see how old the lock is. If it's older than 2 minutes,
        # break it anyway. Locks are atomic, and should never be
        # held that long, by _any_ process.
        if ( time() - $time > 2 * 60 ) {
            $this->{session}->logger->log(
                'warning', $locker . " broke ${user}s lock on $web.$topic" );
            $handler->setLock(0);
            last;
        }

        # wait a couple of seconds before trying again
        sleep(2);
    }

    $handler->setLock( 1, $locker );
}

=begin TML

---++ ObjectMethod unlockTopic( $user, $web, $topic )

Release the topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. It is important to
release a topic lock after a guard section is complete. This should
normally be done in a 'finally' block. See man Error for more info.

Topic locks are used to make store operations atomic. They are
_note_ the locks used when a topic is edited; those are Leases
(see =getLease=)

=cut

sub unlockTopic {
    my ( $this, $user, $web, $topic ) = @_;

    my $handler = _getHandler( $this, $web, $topic );
    $handler->setLock( 0, $user );
}

=begin TML

---++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

A web _has_ to have a preferences topic to be a web.

=cut

sub webExists {
    my ( $this, $web ) = @_;
    $web =~ s#\.#/#go;

    return 0 unless defined $web;
    
    # Foswiki ships with TWikiCompatibilityPlugin but if it is disabled we
    # do not want the TWiki web to appear as a valid web to anyone.
    if ( $web eq 'TWiki' ) {
        unless ( defined ( $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} )
                 && $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} == 1 ) {
            return 0;
        }
    }

    my $handler = _getHandler( $this, $web, $Foswiki::cfg{WebPrefsTopicName} );
    return $handler->storedDataExists();
}

=begin TML

---++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

 Warning: topicExists does not call
     ( $web, $topic ) =
       $this->{session}->normalizeWebTopicName( $web, $topic );
 for you (it'd make Foswiki even slower) so make sure you do so.
 
=cut

sub topicExists {
    my ( $this, $web, $topic ) = @_;
    $web =~ s#\.#/#go;
    ASSERT( defined($topic) ) if DEBUG;
    # This test is invalid. This intent is good, but this function may
    # be called with a deliberately undef web or topic.
    #if (DEBUG) {
    #    my ( $webTest, $topicTest ) =
    #      $this->{session}->normalizeWebTopicName( $web, $topic );
    #    ASSERT( $topic eq $topicTest );
    #    ASSERT( $web   eq $webTest );
    #}
    return 0 unless $topic;

    my $handler = _getHandler( $this, $web, $topic );
    return $handler->storedDataExists();
}

# Expect meta data at top of file, but willing to accept it anywhere.
# If we have an old file format without meta data, then convert.
#
# If autoattachments is on then get this from the filestore rather
# than meta data
#
# SMELL: Calls to this method from outside of Store
# should be avoided at all costs, as it exports the assumption that
# meta-data is embedded in text.
#
sub extractMetaData {
    my ( $this, $meta, $text ) = @_;

    my $users = $this->{session}->{users};

    my $format = $STORE_FORMAT_VERSION;

    # head meta-data
    $text =~ s(^%META:TOPICINFO{(.*)}%\r?\n)
      ($meta->put( 'TOPICINFO', _readKeyValues( $1 ));'')gem;

    my $ti = $meta->get('TOPICINFO');
    if ($ti) {
        $format = $ti->{format} || $STORE_FORMAT_VERSION;

        # Make sure we update the topic format
        $ti->{format} = $STORE_FORMAT_VERSION;

        #add the rev derived from version=''
        $ti->{version} =~ /\d*\.(\d*)/;
        $ti->{rev} = $1;
    }

    my $endMeta = 0;

    $text =~ s(^%META:([^{]+){(.*)}%\r?\n)
      (
          $endMeta = 1;
          my $keys = _readKeyValues( $2, $format );
          if (defined($keys->{name})) {
              # don't attempt to save it keyed unless it has a name
              $meta->putKeyed( $1, $keys);
          } else {
              $meta->put( $1, $keys);
	  }
          '';
         )gem;

    # eat the extra newline put in to separate text from tail meta-data
    $text =~ s/\n$//s if $endMeta;

    # If there is no meta data then convert from old format
    if ( !$meta->count('TOPICINFO') ) {
        if ( $text =~ /<!--TWikiAttachment-->/ ) {
            require Foswiki::Compatibility;
            $text = Foswiki::Compatibility::migrateToFileAttachmentMacro(
                $this->{session}, $meta, $text );
        }

        if ( $text =~ /<!--TWikiCat-->/ ) {
            require Foswiki::Compatibility;
            $text =
              Foswiki::Compatibility::upgradeCategoryTable( $this->{session},
                $meta->web(), $meta->topic(), $meta, $text );
        }
    }
    elsif ( $format eq '1.0beta' ) {
        require Foswiki::Compatibility;

        # This format used live at DrKW for a few months
        if ( $text =~ /<!--TWikiCat-->/ ) {
            $text =
              Foswiki::Compatibility::upgradeCategoryTable( $this->{session},
                $meta->web(), $meta->topic(), $meta, $text );
        }
        Foswiki::Compatibility::upgradeFrom1v0beta( $this->{session}, $meta );
        if ( $meta->count('TOPICMOVED') ) {
            my $moved = $meta->get('TOPICMOVED');
            $meta->put( 'TOPICMOVED', $moved );
        }
    }

    $format =~ s/[^\d\.]//g;
    if ( $format && $format < 1.1 ) {

        # compatibility; topics version 1.0 and earlier equivalenced tab
        # with three spaces. Respect that.
        $text =~ s/\t/   /g;
    }

    $meta->{_text} = $text;

    return $meta;
}

=begin TML

---++ ObjectMethod getTopicParent (  $web, $topic  ) -> $string

Get the name of the topic parent. Needs to be fast because
of use by Render.pm.

=cut

# SMELL: does not honour access controls

sub getTopicParent {
    my ( $this, $web, $topic ) = @_;
    ASSERT( defined($web) )   if DEBUG;
    ASSERT( defined($topic) ) if DEBUG;

    return undef unless $this->topicExists( $web, $topic );

    my $handler = _getHandler( $this, $web, $topic );

    my $strm = $handler->getStream();
    my $data = '';
    while ( ( my $line = <$strm> ) ) {
        if ( $line !~ /^%META:/ ) {
            last;
        }
        else {
            $data .= $line;
        }
    }
    close($strm);

    my $meta = new Foswiki::Meta( $this->{session}, $web, $topic, $data );
    my $parentMeta = $meta->get('TOPICPARENT');
    return $parentMeta->{name} if $parentMeta;
    return undef;
}

=begin TML

---++ ObjectMethod getTopicLatestRevTime (  $web, $topic  ) -> $epochSecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

=cut

sub getTopicLatestRevTime {
    my ( $this, $web, $topic ) = @_;
    $web =~ s#\.#/#go;

    my $handler = _getHandler( $this, $web, $topic );
    return $handler->getLatestRevisionTime();
}

=begin TML

---++ ObjectMethod eachChange( $web, $time ) -> $iterator

Get an iterator over the list of all the changes in the given web between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now - 
{Store}{RememberChangesFor}). Changes are returned in most-recent-first
order.

=cut

sub eachChange {
    my ( $this, $web, $time ) = @_;
    $web =~ s#\.#/#go;

    my $handler = _getHandler( $this, $web );
    return $handler->eachChange($time);
}

=begin TML

---++ ObjectMethod getTopicNames( $web ) -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicNames {
    my ( $this, $web ) = @_;

    $web =~ s#\.#/#go;

    my $handler = _getHandler( $this, $web );
    return $handler->getTopicNames();
}

=begin TML

---++ ObjectMethod getListOfWebs( $filter ) -> @webNames

Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs)
$filter may also contain the word 'public' which will further filter
webs on whether NOSEARCHALL is specified for them or not.
'allowed' filters out webs that the user is denied access to by a *WEBVIEW.

If $Foswiki::cfg{EnableHierarchicalWebs} is set, will also list
sub-webs recursively.

=cut

sub getListOfWebs {
    my ( $this, $filter, $web ) = @_;
    $filter ||= '';
    $web    ||= '';
    $web =~ s#\.#/#g;

    my @webList = _getSubWebs( $this, $web );

    if ( $filter =~ /\buser\b/ ) {
        @webList = grep { !/(?:^_|\/_)/, } @webList;
    }
    elsif ( $filter =~ /\btemplate\b/ ) {
        @webList = grep { /(?:^_|\/_)/, } @webList;
    }

    my $user = $this->{session}->{user};
    if ( $filter =~ /\bpublic\b/
        && !$this->{session}->{users}->isAdmin($user) )
    {
        my $prefs = $this->{session}->{prefs};
        my $wn    = $this->{session}->{webName};
        @webList =
          grep {
            $_ eq $wn
              || !$prefs->getWebPreferencesValue( 'NOSEARCHALL', $_ )
          } @webList;
    }

    if ( $filter =~ /\ballowed\b/ ) {
        my $security = $this->{session}->security;
        @webList =
          grep {
            $security->checkAccessPermission( 'VIEW', $user, undef, undef,
                undef, $_ )
          } @webList;
    }

    # Only return webs that really exist
    return sort grep { $this->webExists($_) } @webList;
}

# get a list of directories within the named web directory. If hierarchical
# webs are enabled, returns a deep list e.g. web, web/subweb,
# web/subweb/subsubweb
sub _getSubWebs {
    my ( $this, $web ) = @_;

    my $handler = _getHandler( $this, $web );
    my @webList = $handler->getWebNames();
    if ($web) {

        # sub-web, add hierarchical path
        foreach (@webList) {
            $_ = "$web/$_";
        }
    }

    if ( $Foswiki::cfg{EnableHierarchicalWebs} ) {
        my @subWebList = ();
        foreach my $subWeb (@webList) {
            push( @subWebList, _getSubWebs( $this, $subWeb ) );
        }
        push( @webList, @subWebList );
    }

    return @webList;
}

=begin TML

---++ ObjectMethod createWeb( $user, $newWeb, $baseWeb, $opts )

$newWeb is the name of the new web.

$baseWeb is the name of an existing web (a template web). If the
base web is a system web, all topics in it
will be copied into the new web. If it is a normal web, only topics starting
with 'Web' will be copied. If no base web is specified, an empty web
(with no topics) will be created. If it is specified but does not exist,
an error will be thrown.

$opts is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

=cut

sub createWeb {
    my ( $this, $user, $newWeb, $baseWeb, $opts ) = @_;

    unless ($baseWeb) {

        # For a web to be a web, it has to have at least one topic
        my $meta =
          new Foswiki::Meta( $this->{session}, $newWeb,
            $Foswiki::cfg{WebPrefsTopicName} );
        $this->saveTopic( $user, $newWeb, $Foswiki::cfg{WebPrefsTopicName},
            "Preferences", $meta );
        return;
    }

    unless ( $this->webExists($baseWeb) ) {
        throw Error::Simple( 'Base web ' . $baseWeb . ' does not exist' );
    }

    $newWeb =~ s#\.#/#go;
    $baseWeb =~ s#\.#/#go if $baseWeb;

    # copy topics from base web
    my @topicList = $this->getTopicNames($baseWeb);

    unless ( $baseWeb =~ /^_/ ) {

        # not a system web, so filter for only Web* topics
        @topicList = grep { /^Web/ } @topicList;
    }

    foreach my $topic (@topicList) {
        if ($topic eq $Foswiki::cfg{WebPrefsTopicName} && $opts) {
            # patch WebPreferences in new web
            my ( $meta, $text ) = $this->readTopic(
                undef, $baseWeb, $topic, undef );
            foreach my $key (keys %$opts) {
                $text =~
                  s/($Foswiki::regex{setRegex}$key\s*=).*?$/$1 $opts->{$key}/gm
                    if defined $opts->{$key};
            }
            $this->saveTopic( $user, $newWeb, $topic, $text, $meta );
        } else {
            $this->copyTopic( $user, $baseWeb, $topic, $newWeb, $topic );
        }
    }
}

=begin TML

---++ ObjectMethod removeWeb( $user, $web )

   * =$user= - user doing the removing (for the history)
   * =$web= - web being removed

Destroy a web, utterly. Removed the data and attachments in the web.

Use with great care!

The web must be a known web to be removed this way.

=cut

sub removeWeb {
    my ( $this, $user, $web ) = @_;
    ASSERT($web) if DEBUG;
    $web =~ s#\.#/#go;

    unless ( $this->webExists($web) ) {
        throw Error::Simple( 'No such web ' . $web );
    }

    my $handler = _getHandler( $this, $web );
    $handler->removeWeb();
}

=begin TML

---++ ObjectMethod getDebugText($meta, $text) -> $text

Generate a debug text form of the text/meta, for use in debug displays,
by annotating the text with meta informtion.

=cut

sub getDebugText {
    my ( $this, $meta, $text ) = @_;

    $meta->text($text);
    return $meta->getEmbeddedStoreForm();
}

=begin TML

---++ ObjectMethod cleanUpRevID( $rev ) -> $integer

Cleans up (maps) a user-supplied revision ID and converts it to an integer
number that can be incremented to create a new revision number.

This method should be used to sanitise user-provided revision IDs.

=cut

sub cleanUpRevID {
    my ( $this, $rev ) = @_;

    return 0 unless $rev;

    return Foswiki::Sandbox::untaint(
        $rev,
        sub {
            my $rev = shift;
            $rev =~ s/^r(ev)?//i;
            $rev =~ s/^\d+\.//;     # clean up RCS rev number
            $rev =~ s/[^\d]//g;     # digits only
            return $rev;
        });
}

=begin TML

---++ ObjectMethod copyTopic($user, $fromweb, $fromtopic, $toweb, $totopic)

Copy a topic and all it's attendant data from one web to another.

SMELL: Does not fix up meta-data!

=cut

sub copyTopic {
    my ( $this, $user, $fromWeb, $fromTopic, $toWeb, $toTopic ) = @_;
    $fromWeb =~ s#\.#/#go;
    $toWeb   =~ s#\.#/#go;

    my $handler = _getHandler( $this, $fromWeb, $fromTopic );
    $handler->copyTopic( $toWeb, $toTopic );
}

=begin TML

---++ ObjectMethod searchMetaData($params) -> $text

Search meta-data associated with topics. Parameters are passed in the $params hash,
which may contain:
| =type= | =topicmoved=, =parent= or =field= |
| =topic= | topic to search for, for =topicmoved= and =parent= |
| =name= | form field to search, for =field= type searches. May be a regex. |
| =value= | form field value. May be a regex. |
| =title= | Title prepended to the returned search results |
| =default= | defualt value if there are no results |
| =web= | web to search in, default is all webs |
| =format= | string for custom formatting results |
The idea is that people can search for meta-data values without having to be
aware of how or where meta-data is stored.

SMELL: should be replaced with a proper SQL-like search, c.f. Plugins.DBCacheContrib.

=cut

sub searchMetaData {
    my ( $this, $params ) = @_;

    my $attrType  = $params->{type}  || 'FIELD';
    my $attrWeb   = $params->{web}   || $this->{session}->{webName};
    my $attrTopic = $params->{topic} || $this->{session}->{topicName};

    my $searchVal = 'XXX';

    if ( $attrType eq 'parent' ) {
        $searchVal =
          "%META:TOPICPARENT[{].*name=\\\"($attrWeb\\.)?$attrTopic\\\".*[}]%";
    }
    elsif ( $attrType eq 'topicmoved' ) {
        $searchVal =
          "%META:TOPICMOVED[{].*from=\\\"$attrWeb\.$attrTopic\\\".*[}]%";
    }
    else {
        $searchVal = "%META:" . uc($attrType) . "[{].*";
        $searchVal .= "name=\\\"$params->{name}\\\".*"
          if ( defined $params->{name} );
        $searchVal .= "value=\\\"$params->{value}\\\".*"
          if ( defined $params->{value} );
        $searchVal .= "[}]%";
    }

    my $text = '';
    if ( $params->{format} ) {
        $text = $this->{session}->search->searchWeb(
            format    => $params->{format},
            search    => $searchVal,
            web       => $attrWeb,
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            template  => 'searchmeta',
            inline    => 1,
        );
    }
    else {
        $this->{session}->search->searchWeb(
            _callback => \&_collate,
            _cbdata   => \$text,
            ,
            search    => $searchVal,
            web       => $attrWeb,
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            template  => 'searchmeta',
            inline    => 1,
        );
    }
    my $attrTitle = $params->{title} || '';
    if ($text) {
        $text = $attrTitle . $text;
    }
    else {
        my $attrDefault = $params->{default} || '';
        $text = $attrTitle . $attrDefault;
    }

    return $text;
}

=begin TML

---++ ObjectMethod searchInWebMetaData($query, $web, \@topics) -> \%matches

Search for a meta-data expression in the content of a web. =$query= must be a =Foswiki::Query= object.

Returns a reference to a hash that maps the names of topics that all matched
to the result of the query expression (e.g. if the query expression is
'TOPICPARENT.name' then you will get back a hash that maps topic names
to their parent.

=cut

sub searchInWebMetaData {
    my ( $this, $query, $web, $topics ) = @_;
    ASSERT($query);
    ASSERT( $query->isa('Foswiki::Query::Node') );
    $web =~ s#\.#/#go;

    my $handler = _getHandler( $this, $web );
    return $handler->searchInWebMetaData( $query, $topics );
}

# callback for search function to collate
# results
sub _collate {
    my $ref = shift;

    $$ref .= join( ' ', @_ );
}

=begin TML

---++ ObjectMethod searchInWebContent($searchString, $web, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use searchMetaData instead).

   * =$searchString= - the search string, in egrep format if regex
   * =$web= - The web to search in
   * =\@topics= - reference to a list of topics to search
   * =\%options= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (defaulkt true)
   * =files_without_match= - true to return files only (default false)

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If =files_without_match= is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

=cut

sub searchInWebContent {
    my ( $this, $searchString, $web, $topics, $options ) = @_;
    $web =~ s#\.#/#go;

    my $handler = _getHandler( $this, $web );
    return $handler->searchInWebContent( $searchString, $topics, $options );
}

=begin TML

---++ ObjectMethod getRevisionAtTime( $web, $topic, $time ) -> $rev

   * =$web= - web for topic
   * =$topic= - topic
   * =$time= - time (in epoch secs) for the rev

Get the revision number of a topic at a specific time.
Returns a single-digit rev number or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

sub getRevisionAtTime {
    my ( $this, $web, $topic, $time ) = @_;

    my $handler = _getHandler( $this, $web, $topic );
    return $handler->getRevisionAtTime($time);
}

=begin TML

---++ ObjectMethod getLease( $web, $topic ) -> $lease

   * =$web= - web for topic
   * =$topic= - topic

If there is an lease on the topic, return the lease, otherwise undef.
A lease is a block of meta-information about a topic that can be
recovered (this is a hash containing =user=, =taken= and =expires=).
Leases are taken out when a topic is edited. Only one lease
can be active on a topic at a time. Leases are used to warn if
another user is already editing a topic.

=cut

sub getLease {
    my ( $this, $web, $topic ) = @_;

    my $handler = _getHandler( $this, $web, $topic );
    my $lease = $handler->getLease();
    return $lease;
}

=begin TML

---++ ObjectMethod setLease( $web, $topic, $user, $length )

Take out an lease on the given topic for this user for $length seconds.

See =getLease= for more details about Leases.

=cut

sub setLease {
    my ( $this, $web, $topic, $user, $length ) = @_;

    my $handler = _getHandler( $this, $web, $topic );
    my $lease;
    if ($user) {
        my $t = time();
        $lease = {
            user    => $user,
            expires => $t + $length,
            taken   => $t
        };
    }

    $handler->setLease($lease);
}

=begin TML

---++ ObjectMethod clearLease( $web, $topic )

Cancel the current lease.

See =getLease= for more details about Leases.

=cut

sub clearLease {
    my ( $this, $web, $topic ) = @_;

    my $handler = _getHandler( $this, $web, $topic );
    $handler->setLease(undef);
}

=begin TML

---++ ObjectMethod removeSpuriousLeases( $web )

Remove leases that are not related to a topic. These can get left behind in
some store implementations when a topic is created, but never saved.

=cut

sub removeSpuriousLeases {
    my ( $this, $web ) = @_;
    my $handler = _getHandler( $this, $web );
    $handler->removeSpuriousLeases();
}

1;

__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
