# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store

This class is a pure virtual base class that specifies the interface
between the actual store implementation and the rest of the Foswiki
system.

Subclasses of this class (known as "store implementations") are
responsible for checking for topic existance, access permissions, and
all the other general admin tasks required of a store.

This class knows *nothing* about how the data is actually _stored_ -
that knowledge is entirely encapsulated in the implementation.

The general contract for methods in the class requires that errors
are signalled using exceptions. Foswiki::AccessControlException is
used for access control exceptions, and Error::Simple for all other
types of error.

The reference implementations of this base class
=Foswiki::Store::PlainFileStore=,
which can be obtained from PlainFileStoreContrib.

Methods of this class and all subclasses should *only* be called from
=Foswiki= and =Foswiki::Meta=. All other system components must delegate
store interactions via =Foswiki::Meta=.

For readers who are familiar with Foswiki version 1.0.0, this class
_describes_ the interface to the old =Foswiki::Store= without actually
_implementing_ it.

Note that most methods are passed a Foswiki::Meta object. This pattern is
employed to reinforce the encapsulation of a "path" in a meta object, and
also to allow the store to modify META fields in the object, something it
would be unable to do if passed $web, $topic.

Version numbers are required to be positive, non-zero integers. When
passing in version numbers to the methods of a store implementation, 0, 
undef and '' are treated as referring to the *latest* (most recent)
revision of the object. Version numbers are required to increase (later
version numbers are greater than earlier) but are *not* required to be
sequential.

*IMPORTANT:* the store must be able to handle unicode topic and
attachment names, and unicode topic content. The store is expected
to do any necessary encoding/decoding from/to unicode.

=cut

package Foswiki::Store;

use strict;
use warnings;

use Error qw( :try );
use Assert;

use Foswiki          ();
use Foswiki::Sandbox ();
use HTML::Entities   ();
use Unicode::Normalize qw(NFC);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Version number of the store API
our $STORE_FORMAT_VERSION = '1.2';

=begin TML

---++ ClassMethod new()

Construct a Store module.

=cut

sub new {
    my $class = shift;

    my $this = bless( {}, $class );
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
}

=begin TML

---++ StaticMethod cleanUpRevID( $rev ) -> $integer

Cleans up (maps) a user-supplied revision ID and converts it to an integer
number that can be incremented to create a new revision number.

This method should be used to sanitise user-provided revision IDs.

Returns 0 if it was unable to determine a valid rev number from the
string passed.

Works with RCS format (e.g. 1.2) rev IDs and plain integer numbers.

=cut

sub cleanUpRevID {
    my $rev = shift;

    # RCS format: 1.2, or plain integer: 2
    if ( defined $rev && $rev =~ m/^(?:\d+\.)?(\d+)$/ ) {
        return $1;
    }

    return 0;
}

=begin TML

---+++ ObjectMethod getWorkArea( $key ) -> $directorypath

Gets a private directory uniquely identified by $key. The directory is
intended as a work area for plugins.

The standard is a directory named the same as "key" under
$Foswiki::cfg{WorkingDir}/work_areas

=cut

sub getWorkArea {
    my ( $this, $key ) = @_;

    # untaint and detect nasties. The rules are the same as for
    # attachment names.
    $key = Foswiki::Sandbox::untaint( $key,
        \&Foswiki::Sandbox::validateAttachmentName );
    throw Error::Simple("Bad work area name $key") unless ($key);

    my $dir = "$Foswiki::cfg{WorkingDir}/work_areas/$key";

    unless ( -d $dir ) {
        mkdir($dir) || throw Error::Simple(<<ERROR);
Failed to create $key work area. Check your setting of {WorkingDir}
in =configure=.
ERROR
    }
    return $dir;
}

=begin TML

---++ ObjectMethod getAttachmentURL( $web, $topic, $attachment, %options ) -> $url

Get a URL that points at an attachment. The URL may be absolute, or
relative to the the page being rendered (if that makes sense for the
store implementation).
   * =$session - the current Foswiki session
   * =$web= - name of the web for the URL
   * =$topic= - name of the topic
   * =$attachment= - name of the attachment, defaults to no attachment
   * %options - parameters to be attached to the URL

Supported %options are:
   * =topic_version= - version of topic to retrieve attachment from
   * =attachment_version= - version of attachment to retrieve
   * =absolute= - if the returned URL must be absolute, rather than relative

If =$web= is not given, =$topic= and =$attachment= are ignored/
If =$topic= is not given, =$attachment= is ignored.

If =topic_version= is not given, the most recent revision of the topic
should be linked. Similarly if attachment_version= is not given, the most recent
revision of the attachment will be assumed. If =topic_version= is specified
but =attachment_version= is not (or the specified =attachment_version= is not
present), then the most recent version of the attachment in that topic version
will be linked. Stores may not support =topic_version= and =attachment_version=.

The default implementation is suitable for use with stores that put
attachments in a web-visible directory, pointed at by
$Foswiki::cfg{PubUrlPath}. As such it may also be used as a
fallback for distributed topics (such as those in System) when content is not
held in the store itself (e.g. if the store doesn't recognise the web it
can call SUPER::getAttachmentURL)

As required by RFC3986, the returned URL may only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getAttachmentURL {
    my ( $this, $session, $web, $topic, $attachment, %options ) = @_;
    my $url = $Foswiki::cfg{PubUrlPath} || '';

    if ($topic) {
        ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $web, $topic );
    }

    if ($web) {
        $url .= '/' . Foswiki::urlEncode($web);
        if ($topic) {
            if ( defined $options{topic_version} ) {

                # TODO: check that the given topic version exists
            }
            $url .= '/' . Foswiki::urlEncode($topic);
            if ($attachment) {
                if ( defined $options{attachment_version} ) {

                    # TODO: check that this attachment version actually
                    # exists on the requested topic version
                }

                # TODO: check that the attachment actually exists on the
                # topic at this revision
                $url .= '/' . Foswiki::urlEncode($attachment);
            }
        }
    }

    if ( $options{absolute} && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = "$session->{urlHost}$url";
    }

    return $url;
}

=begin TML

---++ StaticMethod decode($octets) -> $unicode

Utility function to decode a binary string of octets read from
the store and known known to be encoded using the
currently selected {Store}{Encoding} (or UTF-8 if none is set)
into perl characters (unicode). May die if $octets contains
an invalid byte sequence for the encoding.

This utility function should not be used to decode topic text.
For performance reasons, we don't need to NFC normalize file contents,
only the filenames themselves.

=cut

sub decode {
    return $_[0] unless defined $_[0];
    my $s = $_[0];
    my $decoded = Encode::decode( $Foswiki::cfg{Store}{Encoding} || 'utf-8',
        $s, Encode::FB_CROAK );
    return ( $Foswiki::cfg{NFCNormalizeFilenames} ) ? NFC($decoded) : $decoded;
}

=begin TML

---++ StaticMethod encode($unicode, CROAK) -> $octets

Utility function to encode a perl character string into
a string of octets encoded using the currently selected
{Store}{Encoding} (or UTF-8 if none is set).

If CROAK is true, it will die if =$unicode= cannot be
represented in the {Store}{Encoding}.  Set this for filename
encoding.   Leave false for content encoding.

If CROAK is false, then characters that cannot be represented
will be converted to named entities if possible, otherwise
numeric entities.

=cut

sub encode {
    return $_[0] unless defined $_[0];
    my $s = $_[0];
    if ( $_[1] ) {
        return Encode::encode( $Foswiki::cfg{Store}{Encoding} || 'utf-8',
            $s, Encode::FB_CROAK );
    }
    else {
        return Encode::encode( $Foswiki::cfg{Store}{Encoding} || 'utf-8',
            $s, sub { HTML::Entities::encode_entities( chr(shift) ) } );
    }
}

1;
__END__
# Comment out the above two lines (1; __END__) during development of a
# new store backend.
# The rest of the methods in this file are abstract, so we stop compilation
# here.

=begin TML

---++ ObjectMethod readTopic($topicObject, $version) -> ($rev, $isLatest)
   * =$topicObject= - Foswiki::Meta object
   * =$version= - revision identifier, or undef
Reads the given version of a topic, and populates the =$topicObject=.
If the =$version= is =undef=, or there is no revision numbered =$version=, then
reads the most recent version.

Returns the version identifier of the topic that was actually read. If
the topic does not exist in the store, then =$rev= is =undef=. =$isLatest=
will  be set to true if the version loaded (or not loaded) is the
latest available version.

Note: Implementations of this method *must* call
=Foswiki::Meta::setLoadStatus($rev, $isLatest)=
to set the load status of the meta object.

=cut

# SMELL: there is no way for a consumer of Store to determine if
# a specific revision exists or not.
sub readTopic {
    my( $this, $topicObject, $version ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod moveAttachment( $oldTopicObject, $oldAttachment, $newTopicObject, $newAttachment  )
   * =$oldTopicObject, $oldAttachment= - spec of attachment to move
   * $newTopicObject, $newAttachment= - where to move to
Move an attachment from one topic to another.

The caller to this routine should check that all topics are valid, and
access is permitted. $oldAttachment and $newAttachment must be given and
may not be perl false.

=cut

sub moveAttachment {
    my( $this, $oldTopicObject, $oldAttachment, $newTopicObject, $newAttachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod copyAttachment( $oldTopicObject, $oldAttachment, $newTopicObject, $newAttachment  )
   * =$oldTopicObject, $oldAttachment= - spec of attachment to copy
   * $newTopicObject, $newAttachment= - where to move to
Copy an attachment from one topic to another.

The caller to this routine should check that all topics are valid, and
access is permitted. $oldAttachment and $newAttachment must be given and
may not be perl false.

=cut

sub copyAttachment {
    my( $this, $oldTopicObject, $oldAttachment, $newTopicObject, $newAttachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod attachmentExists( $topicObject, $att ) -> $boolean

Determine if the attachment already exists on the given topic

=cut

sub attachmentExists {
    my( $this, $topicObject, $att ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod moveTopic(  $oldTopicObject, $newTopicObject, $cUID )

All parameters must be defined and must be untainted.

Implementation must invoke 'update' on event listeners.

=cut

sub moveTopic {
    my( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod moveWeb( $oldWebObject, $newWebObject, $cUID )

Move a web.

Implementation must invoke 'update' on event listeners.

=cut

sub moveWeb {
    my( $this, $oldWebObject, $newWebObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod testAttachment( $topicObject, $attachment, $test ) -> $value

Performs a type test on the given attachment file.
    * =$attachment= - name of the attachment to test e.g =lolcat.gif=
    * =$test= - the test to perform e.g. ='r'=

The return value is the value that would be returned by the standard
perl file operations, as indicated by $type

    * r File is readable by current user
    * w File is writable by current user
    * e File exists.
    * z File has zero size.
    * s File has nonzero size (returns size).
    * T File is an ASCII text file (heuristic guess).
    * B File is a "binary" file (opposite of T).
    * M Last modification time (epoch seconds).
    * A Last access time (epoch seconds).

Note that all these types should behave as the equivalent standard perl
operator behaves, except M and A which are independent of the script start
time (see perldoc -f -X for more information)

Other standard Perl file tests may also be supported on some store
implementations, but cannot be relied on.

Errors will be signalled by an Error::Simple exception.

=cut

sub testAttachment {
    my ($this, $attachment, $test) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod openAttachment( $topicObject, $attachment, $mode, %opts  ) -> $text

Opens a stream onto the attachment. This method is primarily to
support virtual file systems, and as such access controls are *not*
checked, plugin handlers are *not* called, and it does *not* update the
meta-data in the topicObject.

=$mode= can be '&lt;', '&gt;' or '&gt;&gt;' for read, write, and append
respectively. %

=%opts= can take different settings depending on =$mode=.
   * =$mode='&lt;'=
      * =version= - revision of the object to open e.g. =version => 6=
   * =$mode='&gt;'= or ='&gt;&gt;'
      * no options
Errors will be signalled by an =Error= exception.

=cut

sub openAttachment {
    my ( $this, $topicObject, $attachment, $mode, %opts ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getRevisionHistory ( $topicObject [, $attachment]  ) -> $iterator
   * =$topicObject= - Foswiki::Meta for the topic
   * =$attachment= - name of an attachment (optional)
Get an iterator over the list of revisions of the object. The iterator returns
the revision identifiers (which will usually be numbers) starting with the most
recent revision.

MUST WORK FOR ATTACHMENTS AS WELL AS TOPICS

If the object does not exist, returns an empty iterator ($iterator->hasNext() will be
false).

=cut

sub getRevisionHistory {
    my( $this, $topicObject, $attachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getNextRevision ( $topicObject  ) -> $revision
   * =$topicObject= - Foswiki::Meta for the topic
Get the ientifier for the next revision of the topic. That is, the identifier
for the revision that we will create when we next save.

=cut

# SMELL: There's an inherent race condition with doing this, but it's always
# been there so I guess we can live with it.
sub getNextRevision{
    my( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getRevisionDiff ( $topicObject, $rev2, $contextLines  ) -> \@diffArray

Get difference between two versions of the same topic. The differences are
computed over the embedded store form.

Return reference to an array of differences
   * =$topicObject= - topic, first revision loaded
   * =$rev2= - second revision
   * =$contextLines= - number of lines of context required

Each difference is of the form [ $type, $right, $left ] where
| *type* | *Means* |
| =+= | Added |
| =-= | Deleted |
| =c= | Changed |
| =u= | Unchanged |
| =l= | Line Number |

=cut

sub getRevisionDiff {
    my( $this, $topicObject, $rev2, $contextLines ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getVersionInfo($topicObject, $rev, $attachment) -> \%info

Get revision info for a topic or attachment.
   * =$topicObject= Topic object, required
   * =$rev= revision number. If 0, undef, or out-of-range, will get info
     about the most recent revision.
   * =$attachment= (optional) attachment filename; undef for a topic
Return %info with at least:
| date | in epochSec |
| user | user *object* |
| version | the revision number |
| comment | comment in the store system, may or may not be the same as the comment in embedded meta-data |

If =$attachment= and =$rev= are both given, then =$rev= applies to the
attachment, not the topic.

=cut

# Formerly know as getRevisionInfo.
sub getVersionInfo {
    my( $this, $topicObject, $rev, $attachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod saveAttachment( $topicObject, $attachment, $stream, $cUID, \%options ) -> $revNum
Save a new revision of an attachment, the content of which will come
from an input stream =$stream=.
   * =$topicObject= - Foswiki::Meta for the topic
   * =$attachment= - name of the attachment
   * =$stream= - input stream delivering attachment data
   * =$cUID= - user doing the save
   * =\%options= - Ref to hash of options
=\%options= may include:
   * =forcedate= - force the revision date to be this (epoch secs) *X* =forcedate= must be equal to or later than the date of the most recent revision already stored for the topic.
   * =minor= - True if this is a minor change (used in log)
   * =comment= - a comment associated with the save
Returns the number of the revision saved.

Note: =\%options= was added in Foswiki 2.0

=cut

sub saveAttachment {
    my( $this, $topicObject, $name, $stream, $cUID, $options ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod saveTopic( $topicObject, $cUID, $options  ) -> $integer

Save a topic or attachment _without_ invoking plugin handlers.
   * =$topicObject= - Foswiki::Meta for the topic
   * =$cUID= - cUID of user doing the saving
   * =$options= - Ref to hash of options
=$options= may include:
   * =forcenewrevision= - force a new revision even if one isn't needed
   * =forcedate= - force the revision date to be this (epoch secs)
    *X* =forcedate= must be equal to or later than the date of the most
    recent revision already stored for the topic.
   * =minor= - True if this is a minor change (used in log)
   * =comment= - a comment associated with the save

Returns the new revision identifier.

Implementation must invoke 'update' on event listeners.

=cut

sub saveTopic {
    my( $this, $topicObject, $options ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod repRev( $topicObject, $cUID, %options ) -> $rev
   * =$topicObject= - Foswiki::Meta topic object
Replace last (top) revision of a topic with different content. The different
content is taken from the content currently loaded in $topicObject.

Parameters and return value as saveTopic, except
   * =%options= - as for saveTopic, with the extra options:
      * =operation= - set to the name of the operation performing the save.
        This is used only in the log, and is normally =cmd= or =save=. It
        defaults to =save=.

Used to try to avoid the deposition of 'unecessary' revisions, for example
where a user quickly goes back and fixes a spelling error.

Also provided as a means for administrators to rewrite history (forcedate).

It is up to the store implementation if this is different
to a normal save or not.

Returns the id of the latest revision.

Implementation must invoke 'update' on event listeners.

=cut

sub repRev {
    my( $this, $topicObject, $cUID, %options ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod delRev( $topicObject, $cUID ) -> $rev
   * =$topicObject= - Foswiki::Meta topic object
   * =$cUID= - cUID of user doing the deleting

Parameters and return value as saveTopic.

Provided as a means for administrators to rewrite history.

Delete last entry in repository, restoring the previous
revision.

It is up to the store implementation whether this actually
does delete a revision or not; some implementations will
simply promote the previous revision up to the head.

Implementation must invoke 'update' on event listeners.

=cut

sub delRev {
    my( $this, $topicObject, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod atomicLockInfo( $topicObject ) -> ($cUID, $time)
If there is a lock on the topic, return it.

=cut

sub atomicLockInfo {
    my ( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod atomicLock( $topicObject, $cUID )

   * =$topicObject= - Foswiki::Meta topic object
   * =$cUID= cUID of user doing the locking
Grab a topic lock on the given topic.

=cut

sub atomicLock {
    my ( $this, $topicObject, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod atomicUnlock( $topicObject )

   * =$topicObject= - Foswiki::Meta topic object
Release the topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. It is important to
release a topic lock after a guard section is complete. This should
normally be done in a 'finally' block. See man Error for more info.

Topic locks are used to make store operations atomic. They are
_note_ the locks used when a topic is edited; those are Leases
(see =getLease=)

=cut

sub atomicUnlock {
    my ( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

=cut

sub webExists {
    my( $this, $web ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

=cut

sub topicExists {
    my( $this, $web, $topic ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getApproxRevTime (  $web, $topic  ) -> $epochSecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

=cut

sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod eachChange( $meta, $time ) -> $iterator

Get an iterator over the list of all the changes between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now -
{Store}{RememberChangesFor}). Changes are returned in most-recent-first
order.

=$meta= may be a web or a topic. If it's a web, then all changes for all
topics within that web will be iterated. If it's a topic, only changes
for that topic (since the topic name was first used) will be iterated.
Each change is returned as a reference to a hash containing the fields
documented for =recordChange()=.

Store implementors should note that if compatibility with Foswiki < 2 is
required, the following additional fields must be returned:
   * =topic= - name of the topic the change occurred to
   * =user= - wikiname of the changing user
   * =more= - formatted string indicating if the change was minor or not

=cut

sub eachChange {
    my ( $this, $web, $time ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod recordChange(%args)
Record that the store item changed, and who changed it, and why

   * =verb= - the action - one of
      * =update= - a web, topic or attachment has been modified
      * =insert= - a web, topic or attachment is being inserted
      * =remove= - a topic or attachment is being removed
   * =cuid= - who is making the change
   * =revision= - the revision of the topic that the change appears in
   * =path= - canonical web.topic path for the affected object
   * =attachment= - attachment name (optional)
   * =oldpath= - canonical web.topic path for the origin of a move/rename
   * =oldattachment= - origin of move
   * =minor= - boolean true if this change is flagged as minor
   * =comment= - descriptive text

=cut

sub recordChange {
    my ( $this, %args ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod eachAttachment( $topicObject ) -> \$iterator

Return an iterator over the list of attachments stored for the given
topic. This will get a list of the attachments actually stored for the
topic, which may be a longer list than the list that comes from the
topic meta-data, which only lists the attachments that are normally
visible to the user.

The iterator iterates over attachment names.

=cut

sub eachAttachment {
    my( $this, $topicObject ) = @_ ;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod eachTopic( $webObject ) -> $iterator

Get list of all topics in a web as an iterator

=cut

sub eachTopic {
    my( $this, $webObject ) = @_ ;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod eachWeb($webObject, $all ) -> $iterator

Return an iterator over each subweb. If $all is set, will return a list of all
web names *under* $web. The iterator returns web pathnames relative to $web.

The list of web names is sorted alphabetically by full path name e.g.
   * AWeb
   * AWeb/SubWeb
   * AWeb/XWeb
   * BWeb

=cut

sub eachWeb {
    my( $this, $web, $all ) = @_ ;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod remove( $cUID, $om, $attachment )
   * =$cUID= who is doing the removing
   * =$om= - thing being removed (web or topic)
   * =$attachment= - optional attachment being removed

Destroy a thing, utterly.

Implementation must invoke 'remove' on event listeners.

=cut

sub remove {
    my( $this, $cUID, $topicObject, $attachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod query($query, $inputTopicSet, $session, \%options) -> $outputTopicSet

Search for data in the store (not web based).
   * =$query= either a =Foswiki::Search::Node= or a =Foswiki::Query::Node=.
   * =$inputTopicSet= is a reference to an iterator containing a list
     of topic paths. If set to undef, the search/query algo will
     create a new iterator using eachWeb()/eachTopic() 
     and the topic and excludetopics options

Returns a =Foswiki::Search::InfoCache= iterator

=cut

sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getRevisionAtTime( $topicObject, $time ) -> $rev

   * =$topicObject= - topic
   * =$time= - time (in epoch secs) for the rev

Get the revision identifier of a topic at a specific time.
Returns a single-digit rev number or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

sub getRevisionAtTime {
    my ( $this, $topicObject, $time ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getLease( $topicObject ) -> $lease

   * =$topicObject= - topic

If there is an lease on the topic, return the lease, otherwise undef.
A lease is a block of meta-information about a topic that can be
recovered (this is a hash containing =user=, =taken= and =expires=).
Leases are taken out when a topic is edited. Only one lease
can be active on a topic at a time. Leases are used to warn if
another user is already editing a topic.

=cut

sub getLease {
    my( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod setLease( $topicObject, $length )

   * =$topicObject= - Foswiki::Meta topic object
Take out an lease on the given topic for this user for $length seconds.

See =getLease= for more details about Leases.

=cut

sub setLease {
    my( $this, $topicObject, $lease ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod removeSpuriousLeases( $web )

Remove leases that are not related to a topic. These can get left behind in
some store implementations when a topic is created, but never saved.

=cut

sub removeSpuriousLeases {
    #my( $this, $web ) = @_;
    # default is a no-op
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
