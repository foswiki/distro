# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::DBI::PostgreSQLWrapHandler
CHANGE　RcsWrapHanlder -> PostgreSQL and VC -> DBI

This class implements the pure methods of the Foswiki::Store::DBI::Handler
superclass. See the superclass for detailed documentation of the methods.

Wrapper around the RCS commands required by Foswiki.
An object of this class is created for each file stored under RCS.

For readers who are familiar with Foswiki version 1.0, this class
is analagous to the old =Foswiki::Store::RcsWrap=.

=cut

package Foswiki::Store::DBI::PostgreSQLWrapHandler;
use strict;
use warnings;

use Foswiki::Store::DBI::Handler ();
our @ISA = ('Foswiki::Store::DBI::Handler');

use Foswiki::Sandbox ();

sub new {
    return shift->SUPER::new(@_);
}

=begin TML

---++ ObjectMethod readTopic($topicObject, $version) -> ($rev, $isLatest)
   * =$topicObject= - Foswiki::Meta object
   * =$version= - revision identifier, or undef
Reads the given version of a topic, and populates the $topicObject.
If the =$version= is undef, then reads the most recent version. 

Returns the version identifier of the topic that was actually read. If
the topic does not exist in the store, or $version refers to a version
that does not exist, then $rev is undef. $isLatest should be set to
perl true if the version loaded (or not loaded) is the latest available
version.

=cut

sub readTopic {
    my ( $this, $topicObject, $version ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod moveAttachment( $oldTopicObject, $oldAttachment, $newTopicObject, $newAttachment  )
   * =$oldTopicObject, $oldAttachment= - spec of attachment to move
   * $newTopicObject, $newAttachment= - where to move to
Move an attachment from one topic to another.

The caller to this routine should check that all topics are valid, and
access is permitted.

=cut

sub moveAttachment {
    my (
        $this,           $oldTopicObject, $oldAttachment,
        $newTopicObject, $newAttachment
    ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod copyAttachment( $oldTopicObject, $oldAttachment, $newTopicObject, $newAttachment  )
   * =$oldTopicObject, $oldAttachment= - spec of attachment to copy
   * $newTopicObject, $newAttachment= - where to move to
Copy an attachment from one topic to another.

The caller to this routine should check that all topics are valid, and
access is permitted.

=cut

sub copyAttachment {
    my (
        $this,           $oldTopicObject, $oldAttachment,
        $newTopicObject, $newAttachment
    ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod attachmentExists( $topicObject, $att ) -> $boolean

Determine if the attachment already exists on the given topic

=cut

sub attachmentExists {
    my ( $this, $topicObject, $att ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod moveTopic(  $oldTopicObject, $newTopicObject, $cUID )

All parameters must be defined and must be untainted.

=cut

sub moveTopic {
    my ( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod moveWeb( $oldWebObject, $newWebObject, $cUID )

Move a web.

=cut

sub moveWeb {
    my ( $this, $oldWebObject, $newWebObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod testAttachment( $topicObject, $attachment, $test ) -> $value

Performs a type test on the given attachment file.
    * =$attachment= - name of the attachment to test e.g =lolcat.gif=
    * =$test= - the test to perform e.g. ='r'=

The return value is the value that would be returned by the standard
perl file operations, as indicated by $type

    * r File is readable by current user (tests Foswiki permissions)
    * w File is writable by current user (tests Foswiki permissions)
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
    my ( $this, $attachment, $test ) = @_;
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

---++ ObjectMethod getNextRevision ( $topicObject  ) -> $revision
   * =$topicObject= - Foswiki::Meta for the topic
Get the ientifier for the next revision of the topic. That is, the identifier
for the revision that we will create when we next save.

=cut

# SMELL: There's an inherent race condition with doing this, but it's always
# been there so I guess we can live with it.
sub getNextRevision {
    my ( $this, $topicObject ) = @_;
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
    my ( $this, $topicObject, $rev2, $contextLines ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getVersionInfo($topicObject, $rev, $attachment) -> \%info

Get revision info of a topic or attachment.
   * =$topicObject= Topic object, required
   * =$rev= revision number. If 0, undef, or out-of-range, will get info
     about the most recent revision.
   * =$attachment= (optional) attachment filename; undef for a topic
Return %info with at least:
| date | in epochSec |
| user | user *object* |
| version | the revision number |
| comment | comment in the VC system, may or may not be the same as the comment in embedded meta-data |

=cut

# Formerly know as getRevisionInfo.
sub getVersionInfo {
    my ( $this, $topicObject, $rev, $attachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod saveAttachment( $topicObject, $attachment, $stream, $cUID ) -> $revNum
   * =$topicObject= - Foswiki::Meta for the topic
   * =$attachment= - name of the attachment
   * =$stream= - input stream delivering attachment data
   * =$cUID= - user doing the save
Save a new revision of an attachment, the content of which will come
from an input stream =$stream=.

Returns the number of the revision saved.

=cut

# SMELL: should support the same options as saveTopic
sub saveAttachment {
    my ( $this, $topicObject, $name, $stream, $cUID ) = @_;
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
   * =minor= - True if this is a minor change (used in log)
   * =author= - cUID of author of the change

Returns the new revision identifier.

=cut

sub saveTopic {
    my ( $this, $topicObject, $options ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod repRev( $topicObject, $cUID, %options ) -> $rev
   * =$topicObject= - Foswiki::Meta topic object
Replace last (top) revision of a topic with different content. The different
content is taken from the content currently loaded in $topicObject.

Parameters and return value as saveTopic, except
   * =%options= - as for saveTopic, with the extra options:
      * =forcedate= - if we want to force the deposited revision
        to look as much like the revision specified in =$rev= as possible by
        reusing the original checkin date.
      * =operation= - set to the name of the operation performing the save.
        This is used only in the log, and is normally =cmd= or =save=. It
        defaults to =save=.

Used to try to avoid the deposition of 'unecessary' revisions, for example
where a user quickly goes back and fixes a spelling error.

Also provided as a means for administrators to rewrite history (forcedate).

It is up to the store implementation if this is different
to a normal save or not.

Returns the id of the latest revision.

=cut

sub repRev {
    my ( $this, $topicObject, $cUID, %options ) = @_;
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

=cut

sub delRev {
    my ( $this, $topicObject, $cUID ) = @_;
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
    my ( $this, $web ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

=cut

sub topicExists {
    my ( $this, $web, $topic ) = @_;
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

---++ ObjectMethod eachChange( $web, $time ) -> $iterator

Get an iterator over the list of all the changes in the given web between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now -
{Store}{RememberChangesFor}). Changes are returned in most-recent-first
order.

=cut

sub eachChange {
    my ( $this, $web, $time ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod eachAttachment( $topicObject ) -> \$iterator

Return an iterator over the list of attachments stored for the given
topic. This will get a list of the attachments actually stored for the
topic, which may be a longer list than the list that comes from the
topic meta-data, which only lists the attachments that are normally
visible to the user.

the iterator iterates over attachment names.

=cut

sub eachAttachment {
    my ( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod eachTopic( $webObject ) -> $iterator

Get list of all topics in a web as an iterator

=cut

sub eachTopic {
    my ( $this, $webObject ) = @_;
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
    my ( $this, $web, $all ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod remove( $cUID, $om, $attachment )
   * =$cUID= who is doing the removing
   * =$om= - thing being removed (web or topic)
   * =$attachment= - optional attachment being removed

Destroy a thing, utterly.

=cut

sub remove {
    my ( $this, $cUID, $topicObject, $attachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod query($query, $inputTopicSet, $session, \%options) -> $outputTopicSet

Search for data in the store (not web based). =$query= must
be a =Foswiki::*::Node= object.

    my $query = $Foswiki::Plugins::SESSION->search->parseSearch($searchString, $options);
    #where $options->{type} is the type specifier as per SEARCH

   * $inputTopicSet is a reference to an iterator containing a list of topic in this web,
     if set to undef, the search/query algo will create a new iterator using eachTopic() 
     and the topic and excludetopics options

Returns an Foswiki::Search::InfoCache iterator

This will become a 'query engine' factory that will allow us to plug in different
query 'types' (Sven has code for 'tag' and 'attachment' waiting for this)

=cut

sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod searchInWebMetaData($query, $web, $inputTopicSet, $session, \%options) -> $outputTopicSet

Search for a meta-data expression in the content of a web. =$query= must be a =Foswiki::Query= object.

Returns an Foswiki::Search::InfoCache iterator

DEPRECATED: this is the old way to search, and should not be used in new code.
instead, use query() - using the topicSet iterator interface allows optimistations

=cut

sub searchInWebMetaData {
    my ( $this, $query, $web, $inputTopicSet, $session, $options ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod searchInWebContent($searchString, $web, \@topics, $session, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use queries instead).

   * =$searchString= - the search string, in egrep format if regex
   * =$web= - The web to search in
   * =\@topics= - reference to a list of topics to search
   * =$session= - the session object that provides the context of this
     search.
   * =\%options= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (default true)
   * =files_without_match= - true to return files only (default false)
   * =wordboundaries= - true to limit the ends of the match to word boundaries
The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If =files_without_match= is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

DEPRECATED: this is the old way to search, and should not be used in new code.
instead, use query() - using the topicSet iterator interface allows optimistations

=cut

sub searchInWebContent {
    my ( $this, $searchString, $web, $topics, $session, $options ) = @_;
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
    my ( $this, $topicObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod setLease( $topicObject, $length )

   * =$topicObject= - Foswiki::Meta topic object
Take out an lease on the given topic for this user for $length seconds.

See =getLease= for more details about Leases.

=cut

sub setLease {
    my ( $this, $topicObject, $lease ) = @_;
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

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
