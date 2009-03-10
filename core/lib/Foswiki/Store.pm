# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store

This class is a pure virtual base class that specifies the interface
layer between the "real" store provider - which is hidden behind a handler -
and the rest of the Foswiki system. Subclasses of this class are
responsible for checking for topic existance, access permissions, and
all the other general admin tasks that are common to all store
implementations.

This class knows *nothing* about how the data is actually _stored_ -
that knowledge is entirely encapsulated in the handlers.

The general contract for methods in the class requires that errors
are signalled using exceptions. Foswiki::AccessControlException is
used for access control exceptions, and Error::Simple for all other
types of error.

Reference implementations of this base class are =Foswiki::Store::RcsWrap=
and =Foswiki::Store::RcsLite=.

Methods of this class and all subclasses should *only* be called from
=Foswiki= and =Foswiki::Meta=. All other system components must delegate
store interactions via =Foswiki::Meta=.

For readers who are familiar with Foswiki version 1.0.0, this class
_describes_ the interface to the old =Foswiki::Store= without actually
_implementing_ it.

=cut

package Foswiki::Store;

use strict;

use Error qw( :try );
use Assert;

use Foswiki                         ();
use Foswiki::Meta                   ();
use Foswiki::Sandbox                ();
use Foswiki::AccessControlException ();

require UNIVERSAL::require;

our $STORE_FORMAT_VERSION = '1.1';

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod createNewStore($session, $impl)

Factory method. Construct a Store module, using the chosen
implementation class.
=$impl= is the class name of the actual store implementation.

=cut

sub createNewStore {
    my ( $session, $impl ) = @_;

    $impl->require();
    ASSERT( !$@, $@ ) if DEBUG;

    return new $impl($session);
}

=begin TML

---++ ClassMethod new($session)

Construct a Store module.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );
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
    undef $this->{session};
}

=begin TML

---++ StaticMethod cleanUpRevID( $rev ) -> $integer

Cleans up (maps) a user-supplied revision ID and converts it to an integer
number that can be incremented to create a new revision number.

This method should be used to sanitise user-provided revision IDs.

=cut

sub cleanUpRevID {
    my $rev = shift;

    return 0 unless $rev;

    $rev =~ s/^r(ev)?//i;
    $rev =~ s/^\d+\.//;     # clean up RCS rev number
    $rev =~ s/[^\d]//g;     # digits only

    return Foswiki::Sandbox::untaintUnchecked($rev);
}

1;
__END__
# Comment out the above two lines (1; __DATA__) during development of a
# new store backend.
# The rest of the methods in this file are abstract, so we stop compilation
# here.

=begin TML

---++ ObjectMethod readTopic($topicObject, $version) -> $rev
   * =$topicObject= - Foswiki::Meta object
   * =$version= - integer, or undef
Reads the given version of a topic, and populates the $topicObject. If the version
is undef, then reads the most recent version. The version number must be
an integer, or undef for the latest version. If the version number is higher
than the most recent version, then the most recent version will be read.

Returns the version of the topic that was actually read.

=cut

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
access is permitted.

=cut

sub moveAttachment {
    my( $this, $oldTopicObject, $oldAttachment, $newTopicObject, $newAttachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getAttachmentStream( $topicObject, $attName ) -> \*STREAM
   * =$topicObject= - The topic
   * =$attName= - Name of the attachment (required)

Open a standard input stream from an attachment.

=cut

sub getAttachmentStream {
    my ( $this, $topicObject, $att ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod attachmentExists( $web, $topic, $att ) -> $boolean

Determine if the attachment already exists on the given topic

=cut

sub attachmentExists {
    my( $this, $web, $topic, $att ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod moveTopic(  $oldTopicObject, $newTopicObject, $cUID )

All parameters must be defined and must be untainted.

=cut

sub moveTopic {
    my( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod moveWeb( $oldWebObject, $newWebObject, $cUID )

Move a web.

=cut

sub moveWeb {
    my( $this, $oldWebObject, $newWebObject ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod readAttachment( $topicObject, $attachment, $rev  ) -> $text

Read the given version of an attachment, returning the content.

If $rev is not given, the most recent rev is assumed.

=cut

sub readAttachment {
    my ( $this, $topicObject, $attachment, $rev ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getRevisionNumber ( $topicObject, $attachment  ) -> $integer
   * =$topicObject= - Foswiki::Meta for the topic
   * =$attachment= - name of an attachment (optional)
Get the revision number of the most recent revision of the topic (or attachment). Returns
the integer revision number or '' if the topic doesn't exist.

MUST WORK FOR ATTACHMENTS AS WELL AS TOPICS

=cut

sub getRevisionNumber {
    my( $this, $topicObject, $attachment ) = @_;
    die "Abstract base class";
}

=begin TML

---+++ StaticMethod getWorkArea( $key ) -> $directorypath

Gets a private directory uniquely identified by $key. The directory is
intended as a work area for plugins. The directory will exist.

=cut

sub getWorkArea {
    my( $this, $key ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getRevisionDiff ( $topicObject, $rev1, $rev2, $contextLines  ) -> \@diffArray

Return reference to an array of [ diffType, $right, $left ]
   * =$topicObject= - the topic
   * =$rev1= Integer revision number
   * =$rev2= Integer revision number
   * =$contextLines= - number of lines of context required

=cut

sub getRevisionDiff {
    my( $this, $topicObject1, $topicObject2, $contextLines ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod getRevisionInfo($topicObject, $rev, $attachment) -> \%info

Get revision info of a topic or attachment.
   * =$topicObject= Topic object, required
   * =$rev= revision number. If 0, undef, or out-of-range, will get info about the most recent revision.
   * =$attachment= (optional) attachment filename; undef for a topic
Return %info with at least:
| date | in epochSec |
| user | user *object* |
| version | the revision number |
| comment | comment in the VC system, may or may not be the same as the comment in embedded meta-data |

=cut

sub getRevisionInfo {
    my( $this, $topicObject, $rev, $attachment ) = @_;
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

sub saveAttachment {
    my( $this, $topicObject, $name, $stream, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod saveTopic( $topicObject, $cUID, $options  ) -> $integer

Save a topic or attachment _without_ invoking plugin handlers.
   * =$topicObject= - Foswiki::Meta for the topic
   * =$cUID= - cUID of user doing the saving
   * =$options= - Ref to hash of options
=$options= may include:
   * =forcenewrevision=
   * =minor= - True if this is a minor change (used in log)
   * =author= - cUID of author of the change

Returns the new revision number

=cut

sub saveTopic {
    my( $this, $topicObject, $options ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod repRev( $topicObject, $cUID, %options )
   * =$topicObject= - Foswiki::Meta topic object
Replace last (top) revision of a topic with different content. The different
content is taken from the content currently loaded in $topicObject.

Parameters and return value as saveTopic, except
   * =%options= - as for saveTopic, with the extra options:
      * =timetravel= - if we want to force the deposited revision
        to look as much like the revision specified in =$rev= as possible.
      * =operation= - set to the name of the operation performing the save.
        This is used only in the log, and is normally =cmd= or =save=. It
        defaults to =save=.

Used to try to avoid the deposition of 'unecessary' revisions, for example
where a user quickly goes back and fixes a spelling error.

Also provided as a means for administrators to rewrite history (timetravel).

It is up to the store implementation if this is different
to a normal save or not.

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

=cut

sub delRev {
    my( $this, $topicObject, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod lockTopic( $topicObject, $cUID )

   * =$topicObject= - Foswiki::Meta topic object
   * =$cUID= cUID of user doing the locking
Grab a topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. A lock has a
maximum lifetime of 2 minutes, so operations on a locked topic
must be completed within that time. You cannot rely on the
lock timeout clearing the lock, though; that should always
be done by calling unlockTopic. The best thing to do is to guard
the locked section with a try..finally clause. See man Error for more info.

Topic locks are used to make store operations atomic. They are
_not_ the locks used when a topic is edited; those are Leases
(see =getLease=)

=cut

sub lockTopic {
    my ( $this, $topicObject, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod unlockTopic( $topicObject, $cUID )

   * =$topicObject= - Foswiki::Meta topic object
Release the topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. It is important to
release a topic lock after a guard section is complete. This should
normally be done in a 'finally' block. See man Error for more info.

Topic locks are used to make store operations atomic. They are
_note_ the locks used when a topic is edited; those are Leases
(see =getLease=)

=cut

sub unlockTopic {
    my ( $this, $topicObject, $cUID ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

A web _has_ to have a preferences topic to be a web.

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

---++ ObjectMethod eachTopic( $web ) -> $iterator

Get list of all topics in a web as an iterator
   * =$web= - Web name, required, e.g. ='Sandbox'=

=cut

sub eachTopic {
    my( $this, $web ) = @_ ;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod eachWeb($web, $all ) -> $iterator

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

---++ ObjectMethod remove( $om, $attachment )
   * =$om= - thing being removed (web or topic)
   * =$attachment= - optional attachment being removed

Destroy a thing, utterly.

=cut

sub remove {
    my( $this, $topicObject, $attachment ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod copyTopic( $fromWeb, $fromTopic, $toWeb, $toTopic)

Fast-copy a topic and all its attendant data from one place to another.

=cut

sub copyTopic {
    my ( $this, $fromWeb, $fromTopic, $toWeb, $toTopic ) = @_;
    die "Abstract base class";
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
    my( $this, $query, $web, $topics ) = @_;
    die "Abstract base class";
}

=begin TML

---++ ObjectMethod searchInWebContent($searchString, $web, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use queries instead).

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
    my( $this, $searchString, $web, $topics, $options ) = @_;
    die "Abstract base class";
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
    my( $this, $web ) = @_;
    die "Abstract base class";
}

1;
__END__
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
# and TWiki Contributors. All Rights Reserved.
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
