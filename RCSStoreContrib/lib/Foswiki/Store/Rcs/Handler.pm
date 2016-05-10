# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::Rcs::Handler

This class is PACKAGE PRIVATE to Store::VC, and should never be
used from anywhere else. It is the base class of implementations of
individual file handler objects used with stores that manipulate
files stored in a version control system (phew!).

The general contract of the methods on this class and its subclasses
calls for errors to be signalled by Error::Simple exceptions.

There are a number of references to RCS below; however this class is
useful as a base class for handlers for all kinds of version control
systems which use files on disk.

A note on character encodings. The RCS handler classes treat
web, topic and attachment *names* coming from the caller as _character_
(i.e. UNICODE) data. *Content*, however, is always assumed to be bytes.
This is done so that the handlers can operate on text (topic) content
and binary (attachment) data using the same functions.

=cut

package Foswiki::Store::Rcs::Handler;

use strict;
use warnings;
use Assert;

use IO::File              ();
use File::Copy            ();
use File::Copy::Recursive ();
use File::Spec            ();
use File::Path            ();
use Unicode::Normalize;

use Fcntl qw( :DEFAULT :flock SEEK_SET );
use Encode ();
use JSON   ();
use Unicode::Normalize;

use Foswiki::Store                         ();
use Foswiki::Store::Rcs::Store             ();
use Foswiki::Sandbox                       ();
use Foswiki::Iterator::NumberRangeIterator ();
use Foswiki::Attrs                         ();

# Modules required for handling TOPICINFO cacheing
use Foswiki::Meta                   ();
use Foswiki::Serialise              ();
use Foswiki::Users::BaseUserMapping ();

# use the locale if required to ensure sort order is correct
BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    *_decode = \&Foswiki::Store::decode;
    *_encode = \&Foswiki::Store::encode;
    *_stat   = \&Foswiki::Store::Rcs::Store::_stat;
    *_unlink = \&Foswiki::Store::Rcs::Store::_unlink;
    *_e      = sub { -e _encode( $_[0], 1 ) };
    *_d      = sub { -d _encode( $_[0], 1 ) };
}

our $json = JSON->new->utf8(1)->pretty(0);

=begin TML

---++ ClassMethod new($store, $web, $topic, $attachment)

Constructor. There is one object per stored file.

$store is the Foswiki::Rcs::Store object that contains the cache for
objects of this type. A cache is used because at some point we'll be
smarter about the number of calls to RCS code we make.

Note that $web, $topic and $attachment must be untainted, and encoded
as utf-8 octets

=cut

sub new {
    my ( $class, $store, $web, $topic, $attachment ) = @_;

    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    ASSERT( !ref($web) );    # defunct usage

    # Reuse is good
    my $id = ( $web || 0 ) . '/' . ( $topic || 0 ) . '/' . ( $attachment || 0 );
    if ( $store->{handler_cache} && $store->{handler_cache}->{$id} ) {
        return $store->{handler_cache}->{$id};
    }

    # web, topic and attachment are all held unicode
    my $this = bless(
        {
            web        => $web,
            topic      => $topic,
            attachment => $attachment
        },
        $class
    );

    # Cache so we can re-use this object (it has no internal state
    # so can safely be reused)
    $store->{handler_cache}->{$id} = $this;

    if ( $this->{web} && $this->{topic} ) {
        my $rcsSubDir = ( $Foswiki::cfg{RCS}{useSubDir} ? '/RCS' : '' );

        ASSERT( UNTAINTED($web),   "web $web is tainted!" )     if DEBUG;
        ASSERT( UNTAINTED($topic), "topic $topic is tainted!" ) if DEBUG;
        if ($attachment) {
            ASSERT( UNTAINTED($attachment) ) if DEBUG;
            $this->{file} =
              "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}/$attachment";
            $this->{rcsFile} =
"$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}$rcsSubDir/$attachment,v";

        }
        else {
            $this->{file} =
              "$Foswiki::cfg{DataDir}/$this->{web}/$this->{topic}.txt";
            $this->{rcsFile} =
"$Foswiki::cfg{DataDir}/$this->{web}$rcsSubDir/$this->{topic}.txt,v";
        }
    }

    # Default to remembering changes for a month
    $Foswiki::cfg{Store}{RememberChangesFor} ||= 31 * 24 * 60 * 60;

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
    undef $this->{file};
    undef $this->{rcsFile};
    undef $this->{web};
    undef $this->{topic};
    undef $this->{attachment};
}

# Used in subclasses for late initialisation during object creation
# (after the object is blessed into the subclass)
sub init {
    my $this = shift;

    return unless $this->{topic};

    unless ( $this->storedDataExists() ) {
        if ( $this->{attachment} && !$this->isAsciiDefault() ) {
            $this->initBinary();
        }
        else {
            $this->initText();
        }
    }
}

# Make any missing paths on the way to this file
sub mkPathTo {

    my ( $this, $file ) = @_;

    $file = _encode( Foswiki::Sandbox::untaintUnchecked($file), 1 );

    ASSERT( File::Spec->file_name_is_absolute($file) ) if DEBUG;

    my ( $volume, $path, undef ) = File::Spec->splitpath($file);
    $path = File::Spec->catpath( $volume, $path, '' );

    eval {
        File::Path::mkpath( $path, 0, $Foswiki::cfg{Store}{dirPermission} );
    };
    if ($@) {
        throw Error::Simple("Rcs::Handler: failed to create ${path}: $!");
    }
}

sub _epochToRcsDateTime {
    my ($dateTime) = @_;

    # TODO: should this be gmtime or local time?
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday ) =
      gmtime($dateTime);
    $year += 1900 if ( $year > 99 );
    my $rcsDateTime = sprintf '%d.%02d.%02d.%02d.%02d.%02d',
      ( $year, $mon + 1, $mday, $hour, $min, $sec );
    return $rcsDateTime;
}

# filenames for lock and lease files
sub _controlFileName {
    my ( $this, $type ) = @_;

    my $fn = $this->{file} || '';
    $fn =~ s/txt$/$type/;
    return $fn;
}

=begin TML

---++ ObjectMethod getInfo($version) -> \%info

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return info about the latest revision.

Returns info where version is the number of the rev for which the info was recovered, date is the date of that rev (epoch s), user is the canonical user ID of the user who saved that rev, and comment is the comment associated with the rev.

Designed to be overridden by subclasses, which can call up to this method
if simple file-based rev info is required.

=cut

sub getInfo {
    my $this =
      shift;  # $version is not useful here, as we have no way to record history

  # We only arrive here if the implementation getInfo can't serve the info; this
  # will usually be because the ,v is missing or the topic cache is newer.

    # If there is a .txt file, grab the TOPICINFO from it.
    # Note that we only peek at the first line of the file,
    # which is where a "proper" save will have left the tag.
    my $info = {};
    if ( $this->noCheckinPending() ) {

        # TOPICINFO may be OK
        $this->_getTOPICINFO($info);
    }
    elsif ( $this->revisionHistoryExists() ) {

        # There is a checkin pending, and there is an rcs file.
        # Ignore TOPICINFO
        $info->{version} = $this->_numRevisions() + 1;
        $info->{comment} = "pending";
    }
    else {

        # There is a checkin pending, but no RCS file.
        $info->{version} = 1;
        $info->{comment} = "pending";
    }
    $info->{date}    = $this->getTimestamp() unless defined $info->{date};
    $info->{version} = 1                     unless defined $info->{version};
    $info->{comment} = ''                    unless defined $info->{comment};
    $info->{author} ||= $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;
    return $info;
}

# Try and read TOPICINFO
sub _getTOPICINFO {
    my ( $this, $info ) = @_;
    my $f;

    if ( open( $f, '<', $this->{file} ) ) {
        local $/ = "\n";
        my $ti = <$f>;
        close($f);
        if ( defined $ti && $ti =~ /^%META:TOPICINFO\{(.*)\}%/ ) {
            my $a = Foswiki::Attrs->new($1);

            # Default bad revs to 1, not 0, because this is coming from
            # a topic on disk, so we know it's a "real" rev.
            $info->{version} = Foswiki::Store::cleanUpRevID( $a->{version} )
              || 1;
            $info->{date}    = $a->{date};
            $info->{author}  = $a->{author};
            $info->{comment} = $a->{comment};
        }
    }
}

# Check to see if there is a newer non-,v file waiting to be checked in. If there is, then
# all rev numbers have to be incremented, as they will auto-increment when it is finally
# checked in (usually as the result of a save). This is also used to test the validity of
# TOPICINFO, as a pending checkin does not contain valid TOPICINFO.
sub noCheckinPending {
    my $this    = shift;
    my $isValid = 0;

    if ( !$this->storedDataExists() ) {
        $isValid = 1;    # Hmmmm......
    }
    else {
        if ( $this->revisionHistoryExists() ) {

# Check the time on the rcs file; is the .txt newer?
# Danger, Will Robinson! stat isn't reliable on all file systems, though [9] is claimed to be OK
# See perldoc perlport for more on this.
            local ${^WIN32_SLOPPY_STAT} =
              1;    # don't need to open the file on Win32
            my $rcsTime  = ( _stat( $this->{rcsFile} ) )[9];
            my $fileTime = ( _stat( $this->{file} ) )[9];
            $isValid =
              ( $fileTime - $rcsTime > 1 ) ? 0 : 1;    # grace period of one sec
        }
    }
    return $isValid;
}

# Must be implemented by subclasses
sub ci {
    die "Pure virtual method";
}

# Check that the object has a history and the .txt is consistent with that history.
# returns true when damage was saved, returns false when there's no checkin pending
sub savePendingCheckin {
    my $this = shift;
    return 0 if $this->noCheckinPending();

    # the version in the TOPICINFO may not be correct. We need
    # to check the change in and update the TOPICINFO accordingly
    my $t = $this->readFile( $this->{file} );

    # If this is a topic, adjust the TOPICINFO
    if ( defined $this->{topic} && !defined $this->{attachment} ) {
        my $rev =
          $this->revisionHistoryExists() ? $this->getLatestRevisionID() : 1;

        $t =~ s/^%META:TOPICINFO\{.*?\}%\n//m;
        $t =
            '%META:TOPICINFO{author="'
          . $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID
          . '" comment="autosave" date="'
          . time()
          . '" format="1.1" version="'
          . $rev . '"}%' . "\n$t";
    }
    $this->ci( 0, $t, 'autosave',
        $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID, time() );

    return 1;
}

# update the topicinfo cache
sub _cacheMetaInfo {
    my ( $this, $text, $comment, $user, $date, $rev ) = @_;

    $user = $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID
      unless defined $user;
    $date = time() unless defined $date;

    my $info;

    # remove the previous record
    if ( $text =~ s/^%META:TOPICINFO\{(.*)\}%\n//m ) {
        $info = Foswiki::Attrs->new($1);

    }
    else {
        $info = Foswiki::Attrs->new();
    }

    $info->{comment} = $comment if defined $comment && $comment ne '';
    $info->{author}  = $user;
    $info->{date}    = $date;
    $info->{version} = $rev if defined $rev;
    $info->{version} ||= 1;
    $info->{format} = '1.1';

    $text = "%META:TOPICINFO{" . $info->stringify . "}%\n" . $text;

    return $text;
}

=begin TML

---++ ObjectMethod addRevisionFromText($text, $comment, $cUID, $date)

Add new revision. Replace file with text.
   * =$text= of new revision
   * =$comment= checkin comment
   * =$cUID= is a cUID.
   * =$date= in epoch seconds; may be ignored

=cut

sub addRevisionFromText {
    my ( $this, $text, $comment, $user, $date ) = @_;
    $this->init();

    # Commit any out-of-band damage to .txt
    my $rev;

    # get a new rev id when we saved damage
    if ( $this->savePendingCheckin() ) {
        $rev = $this->getNextRevisionID();
    }
    $comment ||= '';
    $text = $this->_cacheMetaInfo( $text, $comment, $user, $date, $rev );

    $this->ci( 0, $text, $comment, $user, $date );
}

=begin TML

---++ ObjectMethod addRevisionFromStream($fh, $comment, $cUID, $date)

Add new revision. Replace file with contents of stream.
   * =$fh= filehandle for contents of new revision
   * =$cUID= is a cUID.
   * =$date= in epoch seconds; may be ignored

=cut

sub addRevisionFromStream {
    my ( $this, $stream, $comment, $user, $date ) = @_;
    $this->init();

    # Commit any out-of-band damage to .txt
    $this->savePendingCheckin();

    $this->ci( 1, $stream, $comment, $user, $date );
}

=begin TML

---++ ObjectMethod replaceRevision($text, $comment, $user, $date)

Replace the top revision.
   * =$text= is the new revision
   * =$date= is in epoch seconds.
   * =$user= is a cUID.
   * =$comment= is a string

=cut

sub replaceRevision {
    my ( $this, $text, $comment, $user, $date ) = @_;

    unless ( $this->noCheckinPending() ) {

# As this will check in a new revision, we dump the $date and use the current time.
# Otherwise rcs will barf at us when $date is older than the last release in the revision
# history.
        return $this->addRevisionFromText( $text, $comment, $user, time() );
    }

    my $rev = $this->getLatestRevisionID();
    $text = $this->_cacheMetaInfo( $text, $comment, $user, $date, $rev );

    $this->repRev( $text, $comment, $user, $date );
}

# Signature as for replaceRevision
sub repRev {
    die "Pure virtual method";
}

=begin TML

---++ ObjectMethod getRevisionHistory() -> $iterator

Get an iterator over the identifiers of revisions. Returns the most
recent revision first.

The default is to return an iterator from the current version number
down to 1.   Return rev 1 if the file exists without history. Return
an empty iterator if the file does not exist.

=cut

sub getRevisionHistory {
    my $this = shift;
    ASSERT( $this->{file} ) if DEBUG;
    unless ( $this->revisionHistoryExists() ) {
        require Foswiki::ListIterator;
        if ( $this->storedDataExists() ) {
            return Foswiki::ListIterator->new( [1] );
        }
        else {
            return Foswiki::ListIterator->new( [] );
        }
    }

    # SMELL: what happens with the working file?
    my $maxRev = $this->getLatestRevisionID();
    return Foswiki::Iterator::NumberRangeIterator->new( $maxRev, 1 );
}

=begin TML

---++ ObjectMethod getLatestRevisionID() -> $id

Get the ID of the most recent revision. This may return undef if there have
been no revisions committed to the store.

=cut

sub getLatestRevisionID {
    my $this = shift;
    return 0 unless $this->storedDataExists();

    my $info = {};
    my $rev;

    my $checkinPending = $this->noCheckinPending() ? 0 : 1;
    unless ($checkinPending) {
        $this->_getTOPICINFO($info);
        $rev = $info->{version};
    }

    unless ( defined $rev ) {
        $rev = $this->_numRevisions() || 1;
    }

    # If there is a pending pseudo-revision, need n+1, but only if there is
    # an existing history
    $rev++ if $checkinPending && $this->revisionHistoryExists();
    return $rev;
}

=begin TML

---++ ObjectMethod getNextRevisionID() -> $id

Get the ID of the next (as yet uncreated) revision. The handler is required
to implement this because the store has to be able to embed the revision
ID into TOPICINFO before the revision is actually created.

If the file exists without revisions, then rev 1 does exist, so next rev
should be rev 2, not rev 1, so the first change with missing history
doesn't get merged into rev 1.

=cut

sub getNextRevisionID {
    my $this = shift;

    my $rev = $this->getLatestRevisionID();
    return $rev + 1
      if $this->noCheckinPending() || !$this->revisionHistoryExists();
    return $rev;
}

=begin TML

---++ ObjectMethod getLatestRevisionTime() -> $text

Get the time of the most recent revision

=cut

sub getLatestRevisionTime {
    my @e = _stat( shift->{file} );
    return $e[9] || 0;
}

=begin TML

---++ ObjectMethod getTopicNames() -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicNames {
    my $this = shift;
    my $dh;
    opendir( $dh, _encode( "$Foswiki::cfg{DataDir}/$this->{web}", 1 ) )
      or return ();

    # the name filter is used to ensure we don't return filenames
    # that contain illegal characters as topic names.
    my @topicList =
      map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, NFKD($_) ] }
      map { /^(.*)\.txt$/; $1; }
      grep { !/$Foswiki::cfg{NameFilter}/ && /\.txt$/ }

      # Must _decode before applying the NameFilter and sort
      map( _decode($_), readdir($dh) );

    closedir($dh);
    return @topicList;
}

=begin TML

---++ ObjectMethod revisionExists($rev) -> $boolean

Determine if the identified revision actually exists in the object
history.

=cut

sub revisionExists {
    my ( $this, $rev ) = @_;

    # Rev numbers run from 1 to numRevisions
    my $numRevs;
    if ( $this->noCheckinPending() ) {

        # TOPICINFO may be OK
        my $info = {};
        $this->_getTOPICINFO($info);
        $numRevs = $info->{version} || 1;
    }
    else {
        $numRevs = $this->_numRevisions();
    }

    return $rev && $rev <= $numRevs;
}

=begin TML

---++ ObjectMethod getWebNames() -> @webs

Gets a list of names of subwebs in the current web

=cut

sub getWebNames {
    my $this = shift;
    my $dir  = $Foswiki::cfg{DataDir};
    $dir .= '/' . $this->{web} if defined $this->{web};
    my @tmpList;
    my $dh;
    my $webid = "$Foswiki::cfg{WebPrefsTopicName}.txt";
    my $edir = _encode( $dir, 1 );
    if ( opendir( $dh, $edir ) ) {
        @tmpList = map {
            Foswiki::Sandbox::untaint( _decode($_),
                \&Foswiki::Sandbox::validateWebName )
          }

          # The -e on the web preferences is used in preference to a
          # -d to avoid having to validate the web name each time. Since
          # the definition of a Web in this handler is "a directory with a
          # WebPreferences.txt in it", this works.
          grep { !/\./ && -e "$edir/$_/$webid" } readdir($dh);
        closedir($dh);
    }

    return @tmpList;
}

=begin TML

---++ ObjectMethod moveWeb(  $newWeb )

Move a web.

=cut

sub moveWeb {
    my ( $this, $newWeb ) = @_;
    $this->_moveFile(
        "$Foswiki::cfg{DataDir}/$this->{web}",
        "$Foswiki::cfg{DataDir}/$newWeb"
    );
    if ( _e "$Foswiki::cfg{PubDir}/$this->{web}" ) {
        $this->_moveFile(
            "$Foswiki::cfg{PubDir}/$this->{web}",
            "$Foswiki::cfg{PubDir}/$newWeb"
        );
    }
}

=begin TML

---++ ObjectMethod getRevision($version) -> ($text, $isLatest)

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return the latest revision.

Get the text of the given revision, and a flag indicating if this is the
most recent revision.

Designed to be overridden by subclasses, which can call up to this method
if the main file revision is required.

Note: does *not* handle the case where the latest does not exist but a history
does; that is regarded as a "non-topic".

=cut

sub getRevision {
    my ($this) = @_;
    if ( $this->storedDataExists() ) {
        return ( $this->readFile( $this->{file} ), 1 );
    }
    return ( undef, undef );
}

=begin TML

---++ ObjectMethod storedDataExists() -> $boolean

Establishes if there is stored data associated with this handler.

=cut

sub storedDataExists {
    my $this = shift;
    return 0 unless $this->{file};
    return _e $this->{file};
}

=begin TML

---++ ObjectMethod revisionHistoryExists() -> $boolean

Establishes if htere is history data associated with this handler.

=cut

sub revisionHistoryExists {
    my $this = shift;
    return 0 unless $this->{rcsFile};
    return _e $this->{rcsFile};
}

=begin TML

---++ ObjectMethod restoreLatestRevision( $cUID )

Restore the plaintext file from the revision at the head.

=cut

sub restoreLatestRevision {
    my ( $this, $cUID ) = @_;

    my $rev = $this->getLatestRevisionID();
    my ($text) = $this->getRevision($rev);

    # If there is no ,v, create it
    unless ( $this->revisionHistoryExists() ) {
        $this->addRevisionFromText( $text, "restored", $cUID, time() );
    }
    else {
        $this->saveFile( $this->{file}, $text );
    }
}

=begin TML

---++ ObjectMethod remove()

Destroy, utterly. Remove the data and attachments in the web.

Use with great care! No backup is taken!

=cut

sub remove {
    my $this = shift;

    if ( !$this->{topic} ) {

        # Web
        _rmtree( _encode( "$Foswiki::cfg{DataDir}/$this->{web}", 1 ) );
        _rmtree( _encode( "$Foswiki::cfg{PubDir}/$this->{web}",  1 ) );
    }
    else {

        # Topic or attachment
        _unlink( $this->{file} );
        _unlink( $this->{rcsFile} );
        if ( !$this->{attachment} ) {
            _rmtree(
                _encode(
                    "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}", 1
                )
            );
        }
    }
}

=begin TML

---++ ObjectMethod moveTopic( $store, $newWeb, $newTopic )

Move/rename a topic.

=cut

sub moveTopic {
    my ( $this, $store, $newWeb, $newTopic ) = @_;

    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    my $oldWeb   = $this->{web};
    my $oldTopic = $this->{topic};

    # Move data file
    my $new = $store->getHandler( $newWeb, $newTopic );
    $this->_moveFile( $this->{file}, $new->{file} );

    # Move history
    $this->mkPathTo( $new->{rcsFile} );
    if ( $this->revisionHistoryExists() ) {
        $this->_moveFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    # Move attachments
    my $from = "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}";
    if ( _e $from ) {
        my $to = "$Foswiki::cfg{PubDir}/$new->{web}/$new->{topic}";
        $this->_moveFile( $from, $to );
    }
}

=begin TML

---++ ObjectMethod copyTopic( $store, $newWeb, $newTopic )

Copy a topic.

=cut

sub copyTopic {
    my ( $this, $store, $newWeb, $newTopic ) = @_;

    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    my $oldWeb   = $this->{web};
    my $oldTopic = $this->{topic};

    my $new = $store->getHandler( $newWeb, $newTopic );

    $this->_copyFile( $this->{file}, $new->{file} );
    if ( $this->revisionHistoryExists() ) {
        $this->_copyFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    my $dh;
    if (
        opendir(
            $dh,
            _encode( "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}", 1 )
        )
      )
    {
        for my $att ( grep { !/^\./ } readdir $dh ) {
            $att = Foswiki::Sandbox::untaint( $att,
                \&Foswiki::Sandbox::validateAttachmentName );
            my $oldAtt =
              $store->getHandler( $this->{web}, $this->{topic}, $att );
            $oldAtt->copyAttachment( $store, $newWeb, $newTopic );
        }

        closedir $dh;
    }
}

=begin TML

---++ ObjectMethod moveAttachment( $store, $newWeb, $newTopic, $newAttachment )

Move an attachment from one topic to another. The name is retained.

=cut

sub moveAttachment {
    my ( $this, $store, $newWeb, $newTopic, $newAttachment ) = @_;

    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    # FIXME might want to delete old directories if empty
    my $new = $store->getHandler( $newWeb, $newTopic, $newAttachment );

    $this->_moveFile( $this->{file}, $new->{file} );

    if ( $this->revisionHistoryExists() ) {
        $this->_moveFile( $this->{rcsFile}, $new->{rcsFile} );
    }
}

=begin TML

---++ ObjectMethod copyAttachment( $store, $newWeb, $newTopic, $newAttachment )

Copy an attachment from one topic to another. The name is retained unless
$newAttachment is defined.

=cut

sub copyAttachment {
    my ( $this, $store, $newWeb, $newTopic, $attachment ) = @_;

    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    my $oldWeb   = $this->{web};
    my $oldTopic = $this->{topic};
    $attachment ||= $this->{attachment};

    my $new = $store->getHandler( $newWeb, $newTopic, $attachment );

    $this->_copyFile( $this->{file}, $new->{file} );

    if ( $this->revisionHistoryExists() ) {
        $this->_copyFile( $this->{rcsFile}, $new->{rcsFile} );
    }
}

=begin TML

---++ ObjectMethod isAsciiDefault (   ) -> $boolean

Check if this file type is known to be an ascii type file.

=cut

sub isAsciiDefault {
    my $this = shift;
    return ( $this->{attachment} =~ /$Foswiki::cfg{RCS}{asciiFileSuffixes}/ );
}

=begin TML

---++ ObjectMethod setLock($lock, $cUID)

Set a lock on the topic, if $lock, otherwise clear it.
$cUID is a cUID.

SMELL: there is a tremendous amount of potential for race
conditions using this locking approach.

It would be nice to use flock to do this, but the API is unreliable
(doesn't work on all platforms)

=cut

sub setLock {
    my ( $this, $lock, $cUID ) = @_;

    my $filename = $this->_controlFileName('lock');
    ASSERT($filename);
    if ($lock) {
        my $lockTime = time();
        ASSERT($filename);
        $this->saveFile( $filename, $cUID . "\n" . $lockTime );
    }
    elsif ( _e $filename ) {
        _unlink($filename)
          || throw Error::Simple(
            'Rcs::Handler: failed to delete ' . $filename . ': ' . $! );
    }
}

=begin TML

---++ ObjectMethod isLocked( ) -> ($cUID, $time)

See if a lock exists. Return the lock user and lock time if it does.

=cut

sub isLocked {
    my $this = shift;

    my $filename = $this->_controlFileName('lock');
    if ( _e $filename ) {
        my $t = $this->readFile($filename);
        return split( /\s+/, $t, 2 );
    }
    return ( undef, undef );
}

=begin TML

---++ ObjectMethod setLease( $lease )

   * =$lease= reference to lease hash, or undef if the existing lease is to be cleared.

Set an lease on the topic.

=cut

sub setLease {
    my ( $this, $lease ) = @_;

    my $filename = $this->_controlFileName('lease');
    if ($lease) {
        $this->saveFile( $filename, join( "\n", %$lease ) );
    }
    elsif ( _e $filename ) {
        _unlink($filename)
          || throw Error::Simple(
            'Rcs::Handler: failed to delete ' . $filename . ': ' . $! );
    }
}

=begin TML

---++ ObjectMethod getLease() -> $lease

Get the current lease on the topic.

=cut

sub getLease {
    my ($this) = @_;

    my $filename = $this->_controlFileName('lease');
    if ( _e $filename ) {

        my $t = $this->readFile($filename);
        my $lease = { split( /\r?\n/, $t ) };
        return $lease;
    }
    return;
}

=begin TML

---++ ObjectMethod removeSpuriousLeases( $web )

Remove leases that are not related to a topic. These can get left behind in
some store implementations when a topic is created, but never saved.

=cut

sub removeSpuriousLeases {
    my ($this) = @_;
    my $web = _encode( "$Foswiki::cfg{DataDir}/$this->{web}", 1 );
    if ( opendir( my $W, $web ) ) {
        foreach my $f ( readdir($W) ) {
            my $file = $web . '/' . $f;
            if ( $file =~ /^(.*)\.lease$/ ) {
                if ( !-e "$1.txt,v" ) {
                    unlink("$1.lease");
                }
            }
        }
        closedir($W);
    }
}

sub test {
    my ( $this, $test ) = @_;
    my $f = _encode( $this->{file}, 1 );
    return eval "-$test '$f'";
}

# Used by subclasses
sub saveStream {
    my ( $this, $fh ) = @_;

    ASSERT($fh) if DEBUG;

    $this->mkPathTo( $this->{file} );
    my $F;
    my $efile = _encode( $this->{file}, 1 );
    open( $F, '>', $efile )
      || throw Error::Simple(
        'Rcs::Handler: open ' . $this->{file} . ' failed: ' . $! );
    binmode($F)
      || throw Error::Simple(
        'Rcs::Handler: failed to binmode ' . $this->{file} . ': ' . $! );
    my $text;

    while ( read( $fh, $text, 1024 ) ) {
        print $F $text;
    }
    close($F)
      || throw Error::Simple(
        'Rcs::Handler: close ' . $this->{file} . ' failed: ' . $! );

    chmod( $Foswiki::cfg{Store}{filePermission}, $efile );
}

sub _copyFile {
    my ( $this, $from, $to ) = @_;

    $this->mkPathTo($to);
    unless ( File::Copy::copy( _encode( $from, 1 ), _encode( $to, 1 ) ) ) {
        throw Error::Simple(
            'Rcs::Handler: copy ' . $from . ' to ' . $to . ' failed: ' . $! );
    }
}

sub _moveFile {
    my ( $this, $from, $to ) = @_;
    ASSERT( _e $from ) if DEBUG;
    $this->mkPathTo($to);
    unless (
        File::Copy::Recursive::rmove( _encode( $from, 1 ), _encode( $to, 1 ) ) )
    {
        throw Error::Simple(
            'Rcs::Handler: move ' . $from . ' to ' . $to . ' failed: ' . $! );
    }
}

# Used by subclasses
sub saveFile {
    my ( $this, $name, $text ) = @_;
    $this->mkPathTo($name);
    my $fh;
    open( $fh, '>', _encode( $name, 1 ) )
      or throw Error::Simple(
        'Rcs::Handler: failed to create file ' . $name . ': ' . $! );
    flock( $fh, LOCK_EX )
      or throw Error::Simple(
        'Rcs::Handler: failed to lock file ' . $name . ': ' . $! );
    binmode($fh)
      or throw Error::Simple(
        'Rcs::Handler: failed to binmode ' . $name . ': ' . $! );
    print $fh $text
      or throw Error::Simple(
        'Rcs::Handler: failed to print into ' . $name . ': ' . $! );
    close($fh)
      or throw Error::Simple(
        'Rcs::Handler: failed to close file ' . $name . ': ' . $! );
    return;
}

# Used by subclasses
sub readFile {
    my ( $this, $name ) = @_;
    ASSERT($name) if DEBUG;
    my $data;
    my $IN_FILE;

    # Note: no IO layer; we want to trap encoding errors
    if ( open( $IN_FILE, '<', _encode( $name, 1 ) ) ) {
        binmode($IN_FILE);
        local $/ = undef;
        $data = <$IN_FILE>;
        close($IN_FILE);
    }
    return $data;
}

# Used by subclasses
sub mkTmpFilename {
    my $tmpdir = File::Spec->tmpdir();
    my $file = _mktemp( 'foswikiAttachmentXXXXXX', $tmpdir );
    return File::Spec->catfile( $tmpdir, _encode( $file, 1 ) );
}

# Adapted from CPAN - File::MkTemp
sub _mktemp {
    my ( $template, $dir, $ext, $keepgen, $lookup );
    my ( @template, @letters );

    ASSERT( @_ == 1 || @_ == 2 || @_ == 3 ) if DEBUG;

    ( $template, $dir, $ext ) = map { _encode( $_, 1 ) } @_;
    @template = split( //, $template );

    ASSERT( $template =~ /XXXXXX$/ ) if DEBUG;

    if ($dir) {
        ASSERT( -e $dir ) if DEBUG;
    }

    @letters =
      split( //, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ' );

    $keepgen = 1;

    while ($keepgen) {
        for ( my $i = $#template ; $i >= 0 && ( $template[$i] eq 'X' ) ; $i-- )
        {
            $template[$i] = $letters[ int( rand 52 ) ];
        }

        undef $template;

        $template = pack 'a' x @template, @template;

        $template = $template . $ext if ($ext);

        if ($dir) {
            $lookup = File::Spec->catfile( $dir, $template );
            $keepgen = 0 unless ( -e $lookup );
        }
        else {
            $keepgen = 0;
        }

        next if $keepgen == 0;
    }

    return ($template);
}

sub _fromcs {
    my $s = shift;
}

# remove a directory and all subdirectories
sub _rmtree {
    my $root = shift;
    my $D;

    if ( opendir( $D, $root ) ) {
        foreach my $entry ( grep { !/^\.+$/ } readdir($D) ) {
            $entry =~ /^(.*)$/;    # untaint
            $entry = $root . '/' . $1;

            if ( -d $entry ) {
                _rmtree($entry);
            }
            elsif ( !unlink($entry) && -e $entry ) {
                if ( $Foswiki::cfg{OS} ne 'WINDOWS' ) {
                    throw Error::Simple( 'Rcs::Handler: Failed to delete file '
                          . _decode($entry) . ': '
                          . $! );
                }
                else {

                    # Windows sometimes fails to delete files when
                    # subprocesses haven't exited yet, because the
                    # subprocess still has the file open. Live with it.
                    print STDERR 'WARNING: Failed to delete file ',
                      _decode($entry), ": $!\n";
                }
            }
        }
        closedir($D);

        if ( !rmdir($root) ) {
            if ( $Foswiki::cfg{OS} ne 'WINDOWS' ) {

                #print `ls -lR $root`;
                throw Error::Simple( 'Rcs::Handler: Failed to delete '
                      . _decode($root) . ': '
                      . $! );
            }
            else {
                print STDERR 'WARNING: Failed to delete '
                  . _decode($root) . ': '
                  . $!,
                  "\n";
            }
        }
    }
}

{

    # Package that ties a filehandle to a memory string for reading
    package Foswiki::Store::_MemoryFile;

    sub TIEHANDLE {
        my ( $class, $data ) = @_;
        return
          bless( { data => $data, size => length($data), ptr => 0 }, $class );
    }

    sub READ {
        my $this = shift;
        my ( undef, $len, $offset ) = @_;
        if ( $this->{size} - $this->{ptr} < $len ) {
            $len = $this->{size} - $this->{ptr};
        }
        return 0 unless $len;
        $_[0] = substr( $this->{data}, $this->{ptr}, $len );
        $this->{ptr} += $len;
        return $len;
    }

    sub READLINE {
        my $this = shift;
        return if $this->{ptr} == $this->{size};
        return substr( $this->{data}, $this->{ptr} ) if !defined $/;
        my $start = $this->{ptr};
        while ( $this->{ptr} < $this->{size}
            && substr( $this->{data}, $this->{ptr}, 1 ) ne $/ )
        {
            $this->{ptr}++;
        }
        $this->{ptr}++ if $this->{ptr} < $this->{size};
        return substr( $this->{data}, $start, $this->{ptr} - $start );
    }

    sub CLOSE {
        my $this = shift;
        $this->{data} = undef;
    }
}

=begin TML

---++ ObjectMethod openStream($mode, %opts) -> $fh

Opens a file handle onto the store. This method is primarily to
support virtual file systems.

=$mode= can be '&lt;', '&gt;' or '&gt;&gt;' for read, write, and append
respectively. %

=%opts= can take different settings depending on =$mode=.
   * =$mode='&lt;'=
      * =version= - revision of the object to open e.g. =version => 6=
        Default behaviour is to return the latest revision. Note that it is
        much more efficient to pass undef than to pass the number of the
        latest revision.
   * =$mode='&gt;'= or ='&gt;&gt;'
      * no options

=cut

sub openStream {
    my ( $this, $mode, %opts ) = @_;
    my $stream;
    if ( $mode eq '<' && $opts{version} ) {

        # Bulk load the revision and tie a filehandle
        require Symbol;
        $stream = Symbol::gensym;    # create an anonymous glob
        tie( *$stream, 'Foswiki::Store::_MemoryFile',
            $this->getRevision( $opts{version} ) );
    }
    else {
        if ( $mode =~ />/ ) {
            $this->mkPathTo( $this->{file} );
        }
        if ( _d $this->{file} ) {
            throw Error::Simple( 'Rcs::Handler: stream open '
                  . $this->{file}
                  . ' failed: '
                  . 'Read requested on directory.' );
        }
        unless ( open( $stream, $mode, _encode( $this->{file}, 1 ) ) ) {
            throw Error::Simple( 'Rcs::Handler: stream open '
                  . $this->{file}
                  . ' failed: '
                  . $! );
        }
        binmode $stream;
    }
    return $stream;
}

# as long as stat is defined, return an emulated set of attributes for that
# attachment.
sub _constructAttributesForAutoAttached {
    my ( $file, $stat ) = @_;

    my %pairs = (
        name    => $file,
        path    => $file,
        version => '1',
        size    => $stat->[7],
        date    => $stat->[9],

#        user    => 'UnknownUser',  #safer _not_ to default - Foswiki will fill it in when it needs to
        comment      => '',
        attr         => '',
        autoattached => '1'
    );

    if ( $#$stat > 0 ) {
        return \%pairs;
    }
    else {
        return;
    }
}

# ---++ ObjectMethod synchroniseAttachmentsList(\@old) -> @new
#
# PACKAGE PRIVATE
#
# Synchronise the attachment list from meta-data with what's actually
# stored in the DB. Returns an ARRAY of FILEATTACHMENTs. These can be
# put in the new tom.
#
# This function is only called when the {RCS}{AutoAttachPubFiles} configuration
# option is set.

# IDEA On Windows machines where the underlying filesystem can store arbitary
# meta data against files, this might replace/fulfil the COMMENT purpose
#
# TODO consider logging when things are added to metadata

sub synchroniseAttachmentsList {
    my ( $this, $attachmentsKnownInMeta ) = @_;

    my %filesListedInPub  = $this->_getAttachmentStats();
    my %filesListedInMeta = ();

    # You need the following lines if you want metadata to supplement
    # the filesystem
    if ( defined $attachmentsKnownInMeta ) {
        %filesListedInMeta =
          map { $_->{name} => $_ } @$attachmentsKnownInMeta;
    }

    foreach my $file ( keys %filesListedInPub ) {
        if (   $filesListedInMeta{$file}
            && $filesListedInMeta{$file}{date} !=
            $filesListedInPub{$file}{date} )
        {
            # File timestamp of existing file has changed.
            # Bring forward any missing yet wanted attributes
            foreach my $field (qw(comment attr user version)) {
                if ( $filesListedInMeta{$file}{$field} ) {
                    $filesListedInPub{$file}{$field} =
                      $filesListedInMeta{$file}{$field};
                    if ( $field eq 'version' ) {
                        $filesListedInPub{$file}{$field}++;
                    }
                }
            }
        }
        else {
            $filesListedInPub{$file} = $filesListedInMeta{$file}
              if ( $filesListedInMeta{$file} );
        }
    }

    # A comparison of the keys of the $filesListedInMeta and %filesListedInPub
    # would show files that were in Meta but have disappeared from Pub.

    # Do not change this from array to hash, you would lose the
    # proper attachment sequence
    my @deindexedBecauseMetaDoesnotIndexAttachments = values(%filesListedInPub);

    return @deindexedBecauseMetaDoesnotIndexAttachments;
}

=begin TML

---++ ObjectMethod getAttachmentList() -> @list

Get list of attachment names actually stored for topic.

=cut

sub getAttachmentList {
    my $this = shift;
    my $dir  = "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}";
    my $dh;
    my $ed = _encode( $dir, 1 );
    opendir( $dh, $ed ) || return ();
    my @files =
      map { _decode($_) }
      grep { !/^[.*_]/ && !/,v$/ && -f "$ed/$_" } readdir($dh);
    closedir($dh);
    return @files;
}

# returns {} of filename => { key => value, key2 => value }
# for any given web, topic
sub _getAttachmentStats {
    my $this           = shift;
    my %attachmentList = ();
    my $dir            = "$Foswiki::cfg{PubDir}/$this->{web}/$this->{topic}";
    foreach my $attachment ( $this->getAttachmentList() ) {
        my @stat = _stat( $dir . "/" . $attachment );
        $attachmentList{$attachment} =
          _constructAttributesForAutoAttached( $attachment, \@stat );
    }
    return %attachmentList;
}

sub _dirForTopicAttachments {
    my ( $web, $topic ) = @_;
}

=begin TML

---++ ObjectMethod stringify()

Generate string representation for debugging

=cut

sub stringify {
    my $this = shift;
    my @reply;
    foreach my $key (qw(web topic attachment file rcsFile)) {
        if ( defined $this->{$key} ) {
            push( @reply, "$key=$this->{$key}" );
        }
    }
    return join( ',', @reply );
}

# Chop out recognisable path components to prevent hacking based on error
# messages
sub hidePath {
    my ( $this, $erf ) = @_;
    $erf =~ s#.*(/\w+/\w+\.[\w,]*)$#...$1#;
    return $erf;
}

# ObjectMethod getTimestamp() -> $integer
# Get the timestamp of the file
# Returns 0 if no file, otherwise epoch seconds
# Used in subclasses

sub getTimestamp {
    my ($this) = @_;
    ASSERT( $this->{file} ) if DEBUG;

    my $date = 0;
    if ( $this->storedDataExists() ) {

        # If the stat fails, stamp it with some arbitrary static
        # time in the past (00:40:05 on 5th Jan 1989)
        $date = ( stat $this->{file} )[9] || 600000000;
    }
    return $date;
}

sub recordChange {
    my ( $this, %args ) = @_;
    if (DEBUG) {
        if ( $Foswiki::Store::STORE_FORMAT_VERSION < 1.2 ) {
            ASSERT( ( caller || 'undef' ) eq __PACKAGE__ );
        }
        else {
            ASSERT( ( caller || 'undef' ) ne __PACKAGE__ );
        }
        ASSERT( $args{verb} );
        ASSERT( $args{cuid} );
        ASSERT( $args{revision} );
        ASSERT( $args{path} );
        ASSERT( !defined $args{more} );
        ASSERT( !defined $args{user} );
    }

    #    my ( $meta, $cUID, $rev, $more ) = @_;
    #    $more ||= '';

    my $webpath = "$Foswiki::cfg{DataDir}/$this->{web}";

    # Can't log changes in a non-existent web
    return unless ( _d $webpath );

    my $text = '';
    my $t    = time;

    my @changes = $this->readChanges();
    my $cutoff  = $t - $Foswiki::cfg{Store}{RememberChangesFor};
    while ( scalar(@changes) && $changes[0]->{time} < $cutoff ) {
        shift(@changes);
    }

    # Add the new change to the end of the file
    $args{time} = time;
    push( @changes, \%args );

    if ( $Foswiki::cfg{RCS}{TabularChangeFormat} ) {
        $args{topic} ||= $this->{topic};
        foreach (@changes) {
            my $hash = $_;
            $_ = [
                $hash->{topic}       || '?',
                $hash->{cuid}        || '?',
                $hash->{time}        || '?',
                $hash->{revision}    || '?',
                $json->encode($hash) || '?'
            ];
        }

        $text = join( "\n", map { join( "\t", @$_ ) } @changes );
    }
    else {
        $text = $json->encode( \@changes );
    }
    my $file = "$Foswiki::cfg{DataDir}/$this->{web}/.changes";
    $this->saveFile( $file, $text );
}

sub readChanges {
    my ($this) = @_;

    my $file = "$Foswiki::cfg{DataDir}/$this->{web}/.changes";
    return () unless ( -r _encode( $file, 1 ) );

    my $all_lines =
      Foswiki::Sandbox::untaintUnchecked( $this->readFile($file) );

    # Look at the first line to deduce format
    if ( $all_lines =~ /^\[/s ) {
        my $changes;
        eval { $changes = $json->decode($all_lines); };
        print STDERR "Corrupt $file: $@\n" if ($@);

        foreach my $entry (@$changes) {
            if ( $entry->{path} && $entry->{path} =~ /^(.*)\.(.*)$/ ) {
                $entry->{topic} = $2;
            }
            elsif ( $entry->{oldpath} && $entry->{oldpath} =~ /^(.*)\.(.*)$/ ) {
                $entry->{topic} = $2;
            }
            $entry->{user} =
                $Foswiki::Plugins::SESSION
              ? $Foswiki::Plugins::SESSION->{users}
              ->getWikiName( $entry->{cuid} )
              : $entry->{cuid};
            $entry->{more} =
              ( $entry->{minor} ? 'minor ' : '' ) . ( $entry->{comment} || '' );
        }
        return @$changes;
    }

    # Decode the mess that was the old changes format
    my @changes;
    foreach my $line ( split( /[\r\n]+/, $all_lines ) ) {
        my @row = split( /\t/, $line );

        # Old (pre 1.2) format

        # Create a hash for this line
        my %row;

        $row{topic} = Foswiki::Sandbox::untaintUnchecked( shift(@row) ) || '?';
        $row{user}  = shift(@row)                                       || '?';
        $row{time}  = shift(@row)                                       || 0;
        $row{revision} = shift(@row) || 1;
        $row{more}     = shift(@row) || '';

        # Try and decode 'more', for compatibility mode
        my $ok = 0;
        if ( $row{more} ) {
            eval {
                my $decoded = $json->decode( $row{more} );
                while ( my ( $k, $v ) = each %$decoded ) {
                    $row{$k} = $v;
                }
                $ok = 1;
            };
        }
        if ( !$ok ) {

            # Couldn't decode more as JSON. Fill in 1.2 fields
            if ( $row{revision} > 1 ) {
                $row{verb} = 'update';
            }
            else {
                $row{verb} = 'insert';
            }
            $row{minor} = ( $row{more} =~ /minor/ );
            $row{cuid}  = $row{user};
            $row{path}  = $this->{web};
            $row{path} .= ".$row{topic}" if $row{topic};
            $row{comment} = $row{more};
            if ( $row{more} =~ /Moved from (\w+)/ ) {
                $row{oldpath} = $1;
            }
            if ( $row{more} =~ /Deleted attachment (\S+)/ ) {
                $row{attachment} = $1;
            }
        }
        push( @changes, \%row );
    }
    return @changes;
}

1;

__END__

Copyright (C) 2008-2015 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

Additional copyrights apply to some of the code in this file, as follows

Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
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

=begin TML

---++ ObjectMethod numRevisions() -> $integer

Must be provided by subclasses that do not implement:
   * revisionExists
Find out how many revisions there are. If there is a problem, such
as a nonexistent file, returns 0.

*Must not be called outside this class and subclasses*.
=cut

=begin TML

---++ ObjectMethod initBinary()

Must be provided by subclasses that do not implement
   * init
Initialise a binary file.

=cut

=begin TML

---++ ObjectMethod initText()

Must be provided by subclasses that do not implement
   * init
Initialise a text file.

=cut

=begin TML

---++ ObjectMethod deleteRevision()

Delete the last revision - do nothing if there is only one revision

*Virtual method* - must be implemented by subclasses

=cut to implementation

=begin TML

---++ ObjectMethod revisionDiff (   $rev1, $rev2, $contextLines  ) -> \@diffArray

rev2 newer than rev1.
Return reference to an array of [ diffType, $right, $left ]

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod getRevision($version) -> $text

Get the text for a given revision. The version number must be an integer.

*Virtual method* - must be implemented by subclasses

=cut

=begin TML

---++ ObjectMethod getRevisionAtTime($time) -> $rev

Get a single-digit version number for the rev that was alive at the
given epoch-secs time, or undef it none could be found.

*Virtual method* - must be implemented by subclasses

=cut

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
