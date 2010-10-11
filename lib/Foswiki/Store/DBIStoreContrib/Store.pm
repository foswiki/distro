# See bottom of file for license and copyright information

package Foswiki::Store::DBIStoreContrib::Store;
use strict;
use warnings;

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

sub new {
    my ($class) = @_;
    my $this = $class->SUPER::new();

    # At the moment there will only ever be one event listener, viz the
    # cache. Making this array in case there is ever more than one.
    $this->{event_listeners} = [];

    # This appears more complex than it needs to be, but we need to
    # be able to plug in different implementations because different
    # database engines use different dialects of SQL.
    # TODO: refactor this to make registering a DBCache simpler, and
    # abstracted away from the store implementation.
    if ( defined $Foswiki::cfg{Store}{DBCache}{Implementation}
        && $Foswiki::cfg{Store}{DBCache}{Implementation} ne 'none' )
    {
        eval "require $Foswiki::cfg{Store}{DBCache}{Implementation}";
        die $@ if $@;
        push(
            @{ $this->{event_listeners} },
            $Foswiki::cfg{Store}{DBCache}{Implementation}->new()
        );
    }
    return $this;
}

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{searchFn};
}

# PACKAGE PRIVATE
# Get a handler for the given object in the store.
sub getHandler {

    #my ( $this, $web, $topic, $attachment ) = @_;
    ASSERT( 0, "Must be implemented by subclasses" ) if DEBUG;
}

sub readTopic {
    my ( $this, $topicObject, $version ) = @_;

    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    my $handler  = $this->getHandler($topicObject);
    my $isLatest = 0;

    my $topic_name = $topicObject->topic();
    my $web_name   = $topicObject->web();

    # get the topic data from Topics
    my %topic_row =
      $handler->returnTopicRow( $topic_name, $web_name, $version );

    # since topics are UUID based, get the topic key
    my $topic_key = $topic_row{key};
    return ( undef, $isLatest ) unless defined $topic_key;

    # set the topicObject data
    $topicObject->text( $topic_row{'topic_content'} );

    # Part 2: Get the form data
    ## this code only works if there is only 1 form attached per topic
#$meta->put( 'FIELD', { name => 'MaxAge', title => 'Max Age', value =>'103' } );
#$meta->put( 'FORM', { name => 'PatientForm' } );
    my %form_data = $handler->readFormData($topic_key);
    foreach my $form_name_key ( keys %form_data ) {
        foreach my $field_name_key ( keys %{ $form_data{$form_name_key} } ) {
            my $temp_field_name = $field_name_key;
            my $temp_field_title =
              $form_data{$form_name_key}{$field_name_key}{title};
            my $temp_field_value =
              $form_data{$form_name_key}{$field_name_key}{value};
            $topicObject->put(
                'FIELD',
                {
                    name  => $temp_field_name,
                    title => $temp_field_title,
                    value => $temp_field_value
                }
            );
        }
        $topicObject->put( 'FORM', { name => $form_name_key } );
    }

    # Part 3: Attachments

    # Part 4: Meta Preferences
    my $gotRev = 1;
    $gotRev   = $version if $version;
    $isLatest = 1        if !$version;
    return ( $gotRev, $isLatest );
}

sub moveAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    my $handler = $this->getHandler( $oldTopicObject, $oldAttachment );

    $handler->$handler->moveAttachment( $this, $newTopicObject->web,
        $newTopicObject->topic, $newAttachment, $cUID );

}

sub copyAttachment {
    my ( $this, $oldTopicObject, $oldAttachment, $newTopicObject,
        $newAttachment, $cUID )
      = @_;

    my $handler = $this->getHandler( $oldTopicObject, $oldAttachment );

    $handler->$handler->copyAttachment( $this, $newTopicObject->web,
        $newTopicObject->topic, $newAttachment, $cUID );
}

sub attachmentExists {
    my ( $this, $topicObject, $att ) = @_;
    my $handler    = $this->getHandler( $topicObject, $att );
    my $web_name   = $topicObject->web();
    my $topic_name = $topicObject->topic();

    # returns UUID if true, 0 if false
    return $handler->attachmentGuidHunter_byfile_name( $att, $topic_name,
        $web_name );
}

sub moveTopic {
    my ( $this, $oldTopicObject, $newTopicObject, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler( $oldTopicObject, '' );

    # this function handles all of the dirty work (returns true if successful)
    $handler->moveTopic( $this, $newTopicObject->web, $newTopicObject->topic,
        $cUID );

}

sub moveWeb {
    my ( $this, $oldWebObject, $newWebObject, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler($oldWebObject);

    # handles all of the dirty work.  return 0 if unsuccessful
    $handler->moveWeb( $newWebObject->web );
}

sub testAttachment {
    my ( $this, $topicObject, $attachment, $test ) = @_;
    my $handler = $this->getHandler( $topicObject, $attachment );

    # this implementation is questionable
    return $handler->test($test);
}

sub openAttachment {
    my ( $this, $topicObject, $att, $mode, @opts ) = @_;

    my $handler = $this->getHandler( $topicObject, $att );
    return $handler->openStream( $mode, @opts );
}

sub getRevisionHistory {
    my ( $this, $topicObject, $attachment ) = @_;

    my $handler = $this->getHandler( $topicObject, $attachment );

    # not sure about this implementation either
    return $handler->getRevisionHistory();
}

sub getNextRevision {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler($topicObject);

    #return $handler->getNextRevisionID();
}

sub getRevisionDiff {
    my ( $this, $topicObject, $rev2, $contextLines ) = @_;
    ASSERT( defined($contextLines) ) if DEBUG;

    my $rcs = $this->getHandler($topicObject);

    #return $rcs->revisionDiff( $topicObject->getLoadedRev(), $rev2,
    #   $contextLines );
}

sub getAttachmentVersionInfo {
    my ( $this, $topicObject, $rev, $attachment ) = @_;
    my $handler = $this->getHandler( $topicObject, $attachment );

    #return $handler->getInfo( $rev || 0 );
}

sub getVersionInfo {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler($topicObject);

    #return $handler->getInfo( $topicObject->getLoadedRev() );
}

sub saveAttachment {
    my ( $this, $topicObject, $name, $stream, $cUID ) = @_;
    my $handler    = $this->getHandler( $topicObject, $name );
    my $currentRev = $handler->getLatestRevisionID();
    my $nextRev    = $currentRev + 1;

    #$handler->addRevisionFromStream( $stream, 'save attachment', $cUID );
    #$handler->recordChange( $cUID, $nextRev );
    return $nextRev;
}

sub saveTopic {
    my ( $this, $topicObject, $cUID, $options ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

    my $handler = $this->getHandler($topicObject);

}

sub repRev {
    my ( $this, $topicObject, $cUID, %options ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

}

sub delRev {
    my ( $this, $topicObject, $cUID ) = @_;
    ASSERT( $topicObject->isa('Foswiki::Meta') ) if DEBUG;
    ASSERT($cUID) if DEBUG;

}

sub atomicLockInfo {
    my ( $this, $topicObject ) = @_;
    my $handler = $this->getHandler($topicObject);
    return $handler->isLocked();
}

# It would be nice to use flock to do this, but the API is unreliable
# (doesn't work on all platforms)
sub atomicLock {
    my ( $this, $topicObject, $cUID ) = @_;
    my $handler = $this->getHandler($topicObject);
    $handler->setLock( 1, $cUID );
}

sub atomicUnlock {
    my ( $this, $topicObject, $cUID ) = @_;

    my $handler = $this->getHandler($topicObject);
    $handler->setLock( 0, $cUID );
}

# A web _has_ to have a preferences topic to be a web.
sub webExists {
    my ( $this, $web ) = @_;

    return 0 unless defined $web;
    $web =~ s#\.#/#go;
    my $handler = $this->getHandler( $web, $Foswiki::cfg{WebPrefsTopicName} );
    return $handler->webGuidHunter($web);
}

sub topicExists {
    my ( $this, $web, $topic ) = @_;

    return 0 unless defined $web && $web ne '';
    $web =~ s#\.#/#go;
    return 0 unless defined $topic && $topic ne '';

    my $handler = $this->getHandler( $this->{web}, $this->{topic} );

    # Do SQL magic in the handler, search for the key.
    # TODO: get site_name variable
    return $handler->topicGuidHunter( $topic, $web )
      ;    # returns topic_key if true, 0 if false
}

sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    my $handler = $this->getHandler( $web, $topic );

    # return $handler->getLatestRevisionTime();
}

sub eachChange {
    my ( $this, $webObject, $time ) = @_;

    my $handler = $this->getHandler($webObject);

    #  return $handler->eachChange($time);
}

sub eachAttachment {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler($topicObject);
    my @list    = $handler->getAttachmentList();
    require Foswiki::ListIterator;

#this function is done! (but does not check if the files actually exist, only db query)
    return new Foswiki::ListIterator( \@list );
}

sub eachTopic {
    my ( $this, $webObject ) = @_;

    my $handler = $this->getHandler($webObject);
    my @list    = $handler->getTopicNames();

    # a db query is run to get the list of topics
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
    require Foswiki::ListIterator;
    return new Foswiki::ListIterator( \@list );
}

sub remove {
    my ( $this, $cUID, $topicObject, $attachment ) = @_;
    ASSERT( $topicObject->web ) if DEBUG;

    my $handler = $this->getHandler( $topicObject, $attachment );
    $handler->remove();
    my $newAttachment = $attachment;

    # the attachment is moved to the "Trash Web" "TrashAttachment topic page"
    $handler->$handler->moveAttachment( $this, "Trash", "TrashAttachment",
        $newAttachment, $cUID );

}

#also deprecated. (use Foswiki::Meta::query)
sub searchInWebMetaData {
    my ( $this, $query, $webs, $inputTopicSet, $session, $options ) = @_;
    ASSERT($query);
    ASSERT(  UNIVERSAL::isa( $query, 'Foswiki::Query::Node' )
          || UNIVERSAL::isa( $query, 'Foswiki::Search::Node' ) );

    $options->{web} = $webs;

    #return $this->query( $query, $inputTopicSet, $session, $options );
}

#also deprecated. (use Foswiki::Meta::query)
#yes, this code is identical to Foswiki::Func::searchInWebContent
sub searchInWebContent {
    my ( $this, $searchString, $webs, $topics, $session, $options ) = @_;

    # no clue

}

sub query {
    my ( $this, $query, $inputTopicSet, $session, $options ) = @_;

    # no clue
}

sub getRevisionAtTime {
    my ( $this, $topicObject, $time ) = @_;

    my $handler = $this->getHandler($topicObject);

    # uses db query max(rev)
    return $handler->getRevisionAtTime($time);
}

sub getLease {
    my ( $this, $topicObject ) = @_;

    my $handler = $this->getHandler($topicObject);
    my $lease   = $handler->getLease();
    return $lease;
}

sub setLease {
    my ( $this, $topicObject, $lease ) = @_;

    my $handler = $this->getHandler($topicObject);
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
