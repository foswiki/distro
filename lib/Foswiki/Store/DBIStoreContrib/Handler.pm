# See bottom of file for license and copyright information

package Foswiki::Store::DBIStoreContrib::Handler;

use strict;
use warnings;
use Assert;

# SMELL: Algorithm::Diff is a standard Foswiki CPAN module; who not use it?
# Note for Flavio: always use () with use'd modules, so code readers can
# easily see where functions are defined
#use Text::Diff ();
#use Text::Patch ();

use IO::File   ();
use DBI        ();
use File::Copy ();
use File::Spec ();
use File::Path ();
use Fcntl qw( :DEFAULT :flock SEEK_SET );

use Foswiki::Store                         ();
use Foswiki::Sandbox                       ();
use Foswiki::Iterator::NumberRangeIterator ();

sub new {
    my ( $class, $store, $web, $topic, $attachment ) = @_;

    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    if ( UNIVERSAL::isa( $web, 'Foswiki::Meta' ) ) {

        # $web refers to a meta object
        $attachment = $topic;
        $topic      = $web->topic();
        $web        = $web->web();
    }

    # Reuse is good
    my $id = ( $web || 0 ) . '/' . ( $topic || 0 ) . '/' . ( $attachment || 0 );
    if ( $store->{handler_cache} && $store->{handler_cache}->{$id} ) {
        return $store->{handler_cache}->{$id};
    }

# Setup all off of db_connections
#  Note: dbconnection_read is for doing SELECT queries only, while dbconnection_write is for doing transactions
    my $DB_name = $Foswiki::cfg{Store}{DBI}{database_name};
    my $DB_host = $Foswiki::cfg{Store}{DBI}{database_host};
    my $DB_user = $Foswiki::cfg{Store}{DBI}{database_user};
    my $DB_pwd  = $Foswiki::cfg{Store}{DBI}{database_password};

    my $dbconnection_read =
      DBI->connect( "dbi:Pg:dbname=$DB_name;host=$DB_host",
        $DB_user, $DB_pwd, { 'RaiseError' => 1 } )
      or return "DB Death!";
    my $dbconnection_write =
      DBI->connect( "dbi:Pg:dbname=$DB_name;host=$DB_host",
        $DB_user, $DB_pwd, { 'RaiseError' => 1 } )
      or return "DB Death!";
    $dbconnection_write->{AutoCommit} = 0;    # enable transactions, if possible

    my $site_name = $Foswiki::cfg{Store}{DBI}{site_name};
    my $this      = bless(
        {
            web                 => $web,
            topic               => $topic,
            attachment          => $attachment,
            database_connection => {
                db_reader => $dbconnection_read,
                db_writer => $dbconnection_write
            },
            database_tables => {
                Topics        => "\"$Foswiki::cfg{Store}{DBI}{Topics}\"",
                Topic_History => "\"$Foswiki::cfg{Store}{DBI}{Topic_History}\"",
                Attachments   => "\"$Foswiki::cfg{Store}{DBI}{Attachments}\"",
                Attachment_History =>
                  "\"$Foswiki::cfg{Store}{DBI}{Attachment_History}\"",
                Dataform_Data => "\"$Foswiki::cfg{Store}{DBI}{Dataform_Data}\"",
                Dataform_Definition =>
                  "\"$Foswiki::cfg{Store}{DBI}{Dataform_Definition}\"",
                Dataform_History =>
                  "\"$Foswiki::cfg{Store}{DBI}{Dataform_History}\"",
                Group_User_Membership =>
                  "\"$Foswiki::cfg{Store}{DBI}{Group_User_Membership}\"",
                Groups => "\"" . $site_name . "_Groups\"",
                Users  => "\"$Foswiki::cfg{Store}{DBI}{Users}\"",
                Webs   => "\"$Foswiki::cfg{Store}{DBI}{Webs}\"",
                Meta_Preferences =>
                  "\"$Foswiki::cfg{Store}{DBI}{Meta_Preferences}\""
            }
        },

        $class
    );

    # Cache so we can re-use this object (it has no internal state
    # so can safely be reused)
    $store->{handler_cache}->{$id} = $this;

    # Default to remembering changes for a month
    $Foswiki::cfg{Store}{RememberChangesFor} ||= 31 * 24 * 60 * 60;

    return $this;
}

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->{database_connection}->{db_reader}->disconnect();
    $this->{database_connection}->{db_writer}->disconnect();
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

    unless ( -e $this->{file} ) {
        if ( $this->{attachment} && !$this->isAsciiDefault() ) {
            $this->initBinary();
        }
        else {
            $this->initText();
        }
    }
}

sub userGuidHunter {

    my ( $this, $user_name ) = @_;

    # For hunting for UUID's with user_name
    my $Users = $this->{database_tables}->{Users};

    my $user_hunter_statement = "SELECT $Users.\"key\" FROM $Users ";
    $user_hunter_statement .= " WHERE $Users.login_name = ? ";
    my $user_hunter_handle =
      $this->{database_connection}->{db_reader}
      ->prepare($user_hunter_statement);

    my ($user_key);
    ## setup the before_hash
    $user_hunter_handle->execute($user_name);
    while ( my @row = $user_hunter_handle->fetchrow_array ) {
        $user_key = $row[0];
    }
    my $num_rows = $user_hunter_handle->rows;
    return undef unless $num_rows;    # if num_rows is zero, kill it
    return $user_key;

}

# webGuidHunter($web_name) -> $topic_key or 0
sub webGuidHunter {
    my ( $this, $web_name ) = @_;

    # For hunting for UUID's with web_name
    my $Webs                 = $this->{database_tables}->{Webs};
    my $web_hunter_statement = "SELECT $Webs.\"key\" ";
    $web_hunter_statement .= "FROM $Webs ";
    $web_hunter_statement .= " WHERE $Webs.web_name = ?";
    my $web_hunter_handle =
      $this->{database_connection}->{db_reader}->prepare($web_hunter_statement);

    my $web_key;
    ## setup the before_hash
    $web_hunter_handle->execute($web_name);
    while ( my @row = $web_hunter_handle->fetchrow_array ) {
        $web_key = $row[0];
    }
    return $web_key || 0;
}

# topicGuidHunter($topic_name,$web_name) -> $topic_key or 0
sub topicGuidHunter {
    my ( $this, $topic_name, $web_name ) = @_;

    # Name all of the database tables
    my $Topics = $this->{database_tables}->{Topics};
    my $Webs   = $this->{database_tables}->{Webs};

    # For hunting for UUID's with topic_name
    my $topic_hunter_statement = "SELECT $Topics.\"key\" ";
    $topic_hunter_statement .= "FROM $Webs, $Topics ";
    $topic_hunter_statement .=
"WHERE $Topics.web_key = $Webs.\"key\" AND $Topics.topic_name = ? AND $Webs.web_name = ?";

    # need to input ( $site_name, $topic_name, $web_name)
    my $topic_hunter_handle =
      $this->{database_connection}->{db_reader}
      ->prepare($topic_hunter_statement);

    my $topic_key;
    ## setup the before_hash
    $topic_hunter_handle->execute( $topic_name, $web_name );
    while ( my @row = $topic_hunter_handle->fetchrow_array ) {
        $topic_key = $row[0];
    }
    return $topic_key || 0;
}

# attachmentGuidHunter_byfile_name($file_name,$topic_name,$web_name) -> $topic_key or 0
sub attachmentGuidHunter_byfile_name {
    my ( $this, $file_name, $topic_name, $web_name ) = @_;

    # Name all of the database tables
    my $Attachments = $this->{database_tables}->{Attachments};
    my $Topics      = $this->{database_tables}->{Topics};
    my $Webs        = $this->{database_tables}->{Webs};

    # Need to fill 3 input ($old_file_name, $old_topic_name, $old_web_name)
    my $selectStatement_A =
"SELECT $Attachments.\"key\" FROM $Attachments, $Topics, $Webs WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\"";
    $selectStatement_A .=
" AND $Attachments.file_name = ? AND $Topics.topic_name = ? AND $Webs.web_name = ?";
    my $selectHandler_A =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_A);
    $selectHandler_A->{RaiseError} = 1;

    my $attachment_key;
    ## setup the before_hash
    $selectHandler_A->execute( $file_name, $topic_name, $web_name );
    while ( my @row = $selectHandler_A->fetchrow_array ) {
        $attachment_key = $row[0];
    }
    return $attachment_key || 0;
}

# returnTopicRow($topic_name,$web_name) -> %topic_row_hash with all fields returned
sub returnTopicRow {
    my ( $this, $topic_name, $web_name, $version ) = @_;

    # Name all of the database tables
    my $Topics        = $this->{database_tables}->{Topics};
    my $Webs          = $this->{database_tables}->{Webs};
    my $Topic_History = $this->{database_tables}->{Topic_History};

    ###  Part 1 Get the topic row
    my $topic_hunter_statement = "SELECT $Topics.* ";
    $topic_hunter_statement .= "FROM $Webs, $Topics ";
    $topic_hunter_statement .=
      "WHERE $Topics.web_key = $Webs.\"key\" AND  $Topics.topic_name = ? AND ";
    $topic_hunter_statement .= "$Webs.web_name = ? ";
    my $topic_hunter_handle =
      $this->{database_connection}->{db_reader}
      ->prepare($topic_hunter_statement);
    my ($topic_key);

    # fetch the row from Topics
    $topic_hunter_handle->execute( $topic_name, $web_name );
    my (%topic_hash);
    while ( my $row = $topic_hunter_handle->fetchrow_hashref() ) {
        %topic_hash = %$row;
        $topic_key  = $topic_hash{'key'};
        return %topic_hash if $topic_key && !$version;
        return undef if !$topic_key;
    }

    # Only continue if $version exists
    ###  Part 2 Get the edit row for $version
    # Have to get the Topic_History row for the given $version
    my $topic_history_statement =
      "SELECT $Topic_History.* FROM $Topic_History ";
    $topic_history_statement .=
      "WHERE $Topic_History.topic_key = ? AND $Topic_History.revision = ?";
    $topic_history_statement .= "ORDER BY $Topic_History.revision DESC ";
    my $topic_history_handle =
      $this->{database_connection}->{db_reader}
      ->prepare($topic_history_statement);

    # get $version of the topic from Topic_History
    $topic_history_handle->execute( $topic_key, $version );
    my (%oldest_edit_hash);
    while ( my $row2 = $topic_history_handle->fetchrow_hashref() ) {
        %oldest_edit_hash = %$row2;
        my $edit_key = $oldest_edit_hash{'key'};
        return undef if !$edit_key;
    }

    # setup the topic content variable starting with the oldest revision
    my $diff_tc_oldest = $oldest_edit_hash{'diff_topic_content'};
    my $topic_content  = $topic_hash{'topic_content'};

    ### Part 3 Get all of the diffs between $version < rev < Max(rev)
    # since we already have $edit_row($version), we can skip that row
    my $tc_diff_statement = "SELECT $Topic_History.revision, ";
    $tc_diff_statement .=
      " $Topic_History.diff_topic_content FROM $Topic_History ";
    $tc_diff_statement .=
      "WHERE $Topic_History.topic_key = ? AND $Topic_History.revision > ?";
    $tc_diff_statement .= "ORDER BY $Topic_History.revision DESC ";
    my $tc_diff_handle =
      $this->{database_connection}->{db_reader}->prepare($tc_diff_statement);

    # fetch the rows
    $tc_diff_handle->execute( $topic_key, $version );
    my (%rev_diffs)
      ; # between rev and the last edit diff  http://search.cpan.org/dist/Text-Patch/Patch.pm
    while ( my $row3 = $tc_diff_handle->fetchrow_hashref() ) {

        my $diff = $row3->{'diff_topic_content'};
        $topic_content = patch( $topic_content, $diff, { STYLE => 'Unified' } )
          if $diff;
        my $rev_num = $row3->{'revision'};
        $rev_diffs{$rev_num} = $row3->{'diff_topic_content'}
          if $diff && $rev_num;
    }

    #this should yield the original topic_content for the revision
    $topic_content =
      patch( $topic_content, $diff_tc_oldest, { STYLE => 'Unified' } );

    $topic_hash{'topic_name'} = $oldest_edit_hash{'diff_topic_name'};
    $topic_hash{'web_key'}    = $oldest_edit_hash{'diff_web_key'};
    $topic_hash{'parent_topic_key'} =
      $oldest_edit_hash{'diff_parent_topic_key'};
    $topic_hash{'dataform_data'} = $oldest_edit_hash{'diff_dataform_data'};
    $topic_hash{'authorization_topic_allow_view'} =
      $oldest_edit_hash{'diff_topic_allow_view'};
    $topic_hash{'authorization_topic_allow_change'} =
      $oldest_edit_hash{'diff_topic_allow_change'};
    $topic_hash{'authorization_topic_allow_rename'} =
      $oldest_edit_hash{'diff_topic_allow_rename'};
    $topic_hash{'authorization_topic_deny_view'} =
      $oldest_edit_hash{'diff_topic_deny_view'};
    $topic_hash{'authorization_topic_deny_change'} =
      $oldest_edit_hash{'diff_topic_deny_change'};
    $topic_hash{'authorization_topic_deny_rename'} =
      $oldest_edit_hash{'diff_topic_deny_rename'};
    $topic_hash{'timestamp_epoch'} =
      $oldest_edit_hash{'diff_topic_deny_rename'};
    $topic_hash{'user_key'} = $oldest_edit_hash{'user_key'};

    $topic_hash{'topic_content'} = $topic_content;

    return %topic_hash;

}

# Getting Topic data for readTopic()  #######################################

sub readFormData {

    # Select statement to get Topics JOIN Topic_History data
    my ( $this, $topic_key, $version ) = @_;

    # Name all of the database tables
    my $Topics              = $this->{database_tables}->{Topics};
    my $Dataform_Data       = $this->{database_tables}->{Dataform_Data};
    my $Dataform_Definition = $this->{database_tables}->{Dataform_Definition};

    # get the Form data and Form definition
    my $selectStatement_DF =
"SELECT $Topics.topic_name, $Dataform_Data.value_hash, $Dataform_Definition.\"Name\", $Dataform_Definition.\"Title\" ";
    $selectStatement_DF .= " FROM $Topics,$Dataform_Data,$Dataform_Definition ";
    $selectStatement_DF .=
" WHERE $Dataform_Data.dataform_definition_key = $Dataform_Definition.\"key\" AND $Dataform_Data.topic_key =? ";
    my $selectHandler_DF =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_DF);

    # Get the Form data
    $selectHandler_DF->execute($topic_key);
    my (%form_hash);
    while ( my @row = $selectHandler_DF->fetchrow_array ) {
        my $form_name         = $row[0];
        my $value_hash_temp   = $row[1];
        my $field_names_temp  = $row[2];
        my $field_titles_temp = $row[3];

        my %name_value_hash =
          parseValueHash($value_hash_temp);   # parse the name/value pair string
        my @field_name_array  = parseCommaList($field_names_temp);
        my @field_title_array = parseCommaList($field_titles_temp);
        my $max               = scalar @field_name_array;

        for ( my $i = 0 ; $i = $max - 1 ; $i++ ) {
            $form_hash{$form_name}{ $field_name_array[$i] }{title} =
              $field_title_array[$i];
            $form_hash{$form_name}{ $field_name_array[$i] }{value} =
              $name_value_hash{ $field_name_array[$i] };
        }

    }

    return %form_hash;
}

# Input String ( "name1"=>"value1","name2"=>"value2",...) -> Output %hash name=> value
sub parseValueHash {
    my ($value_hash) =
      shift;    # value_hash ( "name1"=>"value1","name2"=>"value2",...)
    my %return_hash;

    chop($value_hash);    # strips the last quote off the end of the string
    $value_hash =
      substr( $value_hash, 1 );    # strips the first quote off the string

    my @list_vh = split( "\",\"", $value_hash );    # value_hash name1"=>"value1

    foreach my $list_ref (@list_vh) {
        my @name_value_pair = split( "\"=>\"", $list_ref );
        $return_hash{ $name_value_pair[0] } =
          $name_value_pair[1];                      # name = value
    }
    return %return_hash;

}

# Input String ( "fieldname1","fieldname2","fieldname3",...) -> Output @array value
sub parseCommaList {
    my ($value_array) =
      shift;    # value_hash ( "fieldname1","fieldname2","fieldname3",...)
    my @return_array;

    chop($value_array);

    $value_array =
      substr( $value_array, 1 );    # strips the first quote off the string

    my @list_va = split( "\",\"", $value_array );   # value_hash "name1","name2"

    foreach my $list_ref (@list_va) {
        push( @return_array, $list_ref )
          ;    # adds a field element to the return array
    }
    return @return_array;

}

# moveWeb
sub moveWeb {
    my ( $this, $newWeb ) = @_;
    my $oldWeb = $this->{web};

    # Name all of the database tables
    my $Webs = $this->{database_tables}->{Webs};

    # need to update 1 field (new_web_name)
    my $updateStatement_webs = "UPDATE $Webs SET web_name=?  WHERE \"key\"=?";
    my $updateHandler_webs =
      $this->{database_connection}->{db_writer}->prepare($updateStatement_webs);
    $updateHandler_webs->{RaiseError} = 1;

    my $web_key = $this->webGuidHunter($oldWeb);

    eval {
        $updateHandler_webs->{db_writer}->execute( $newWeb, $web_key );
        $this->{database_connection}->{db_writer}->commit;
    };

    if ($@) {

        #warn "Transaction aborted because $@";
        # now rollback to undo the incomplete changes
        # but do it in an eval{} as it may also fail
        eval { $this->{database_connection}->{db_writer}->rollback };

        # add other application on-error-clean-up code here
        return 0;
    }
    return 1;

}

# moveTopic    change the topic name or web name
sub moveTopic {
    my ( $this, $store, $newWeb, $newTopic, $cUID ) = @_;
    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    # Name all of the database tables
    my $Topics        = $this->{database_tables}->{Topics};
    my $Webs          = $this->{database_tables}->{Webs};
    my $Topic_History = $this->{database_tables}->{Topic_History};

# need to input 6 fields (key, topic_key, old_topic_name, user_key, old_web_key, timestamp)
    my $insertStatement_edithist =
"INSERT INTO $Topic_History (\"key\",topic_key,diff_topic_name, user_key, ";
    $insertStatement_edithist .=
      " diff_web_key, timestamp_epoch)  VALUES (?,?,?,?,?,?)";
    my $insertHandler_edithist =
      $this->{database_connection}->{db_writer}
      ->prepare($insertStatement_edithist);
    $insertHandler_edithist->{RaiseError} = 1;

    # need to update 3 fields (new_web_key, new_topic_name,topic_key)
    my $updateStatement_topic =
      "UPDATE $Topics SET web_key=?, topic_name=?  WHERE \"key\"=?";
    my $updateHandler_topic =
      $this->{database_connection}->{db_writer}
      ->prepare($updateStatement_topic);
    $updateHandler_topic->{RaiseError} = 1;

    my $oldWeb   = $this->{web};
    my $oldTopic = $this->{topic};

    # get the  topic key in order to update both Topic_History and Topics
    my $topic_key = $this->topicGuidHunter( $oldTopic, $oldWeb );

 # if the newWeb and oldWeb are different, then the webkey has to change as well
    my ( $oldWeb_key, $newWeb_key );
    if ( $oldWeb ne $newWeb ) {
        $oldWeb_key = $this->webGuidHunter($oldWeb);
        $newWeb_key = $this->webGuidHunter($newWeb);
    }

    # make a UUID for the Topic_History_key
    my $ug               = Data::UUID->new();
    my $uuid             = $ug->create();
    my $edit_history_key = $ug->to_string($uuid);

    # get a time stamp epoch
    my $timestamp = time();

    # get the user key
    my $user_key = $this->userGuidHunter($cUID);

    eval {

        #(key, topic_key, old_topic_name, user_key, old_web_key, timestamp)
        $insertHandler_edithist->execute( $edit_history_key, $topic_key,
            $oldTopic, $user_key, $oldWeb_key, $timestamp );

        #(key, new_web_key, new_topic_name)
        $updateHandler_topic->execute( $newWeb_key, $newTopic, $topic_key );

        # commit the transaction
        $this->{database_connection}->{db_writer}->commit;
    };
    if ($@) {

        #warn "Transaction aborted because $@";
        # now rollback to undo the incomplete changes
        # but do it in an eval{} as it may also fail
        eval { $this->{database_connection}->{db_writer}->rollback };

        # add other application on-error-clean-up code here
        return 0;
    }
    return 1;

}

sub getAttachmentList {
    my $this = shift;

    my ( $web_name, $topic_name ) = ( $this->{web}, $this->{topic} );

    # Name all of the database tables
    my $Topics             = $this->{database_tables}->{Topics};
    my $Webs               = $this->{database_tables}->{Webs};
    my $Attachments        = $this->{database_tables}->{Attachments};
    my $Attachment_History = $this->{database_tables}->{Attachment_History};

    # Need to fill 2 input ($topic_name, $web_name)
    my $selectStatement_A =
"SELECT $Attachments.file_name FROM $Attachments, $Topics, $Webs WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\"";
    $selectStatement_A .= " AND $Topics.topic_name = ? AND $Webs.web_name = ?";
    my $selectHandler_A =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_A);
    $selectHandler_A->{RaiseError} = 1;

    $selectHandler_A->execute( $topic_name, $web_name );

    my @files;

    while ( my $row = $selectHandler_A->fetchrow_array ) {
        push( @files, @$row[0] );
    }
    return @files;

}

sub getTopicNames {

    my $this = shift;

    my $web_name = $this->{web};

    # Name all of the database tables
    my $Topics = $this->{database_tables}->{Topics};
    my $Webs   = $this->{database_tables}->{Webs};

    # Need to fill 1 input ($web_name)
    my $selectStatement_T =
"SELECT $Topics.topic_name FROM $Topics,$Webs WHERE $Topics.web_key = $Webs.\"key\" ";
    $selectStatement_T .= " AND $Webs.web_name = ?";
    my $selectHandler_T =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_T);
    $selectHandler_T->{RaiseError} = 1;

    $selectHandler_T->execute($web_name);

    my @list_of_topics;

    while ( my $row = $selectHandler_T->fetchrow_array ) {
        push( @list_of_topics, $row );
    }
    return @list_of_topics;
}

sub getWebNames {

    my $this = shift;

    my $web_name = $this->{web};

    # Name all of the database tables
    my $Webs = $this->{database_tables}->{Webs};

    # Need to fill 1 input ($web_name)
    my $selectStatement_W = "SELECT $Webs.web_name FROM $Webs ";
    my $selectHandler_W =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_W);
    $selectHandler_W->{RaiseError} = 1;

    $selectHandler_W->execute();

    my @list_of_webs;

    while ( my $row = $selectHandler_W->fetchrow_array ) {
        push( @list_of_webs, $row );
    }
    return @list_of_webs;
}

# ObjectMethod getRevisionAtTime($time) -> $rev
sub getRevisionAtTime {
    my ( $this, $time ) = @_;

    my ( $topic_name, $web_name ) = ( $this->topic(), $this->web() );

    # Name all of the database tables
    my $Topics        = $this->{database_tables}->{Topics};
    my $Topic_History = $this->{database_tables}->{Topic_History};
    my $Webs          = $this->{database_tables}->{Webs};

    # Need to fill 1 input ($web_name,$topic_name,$time)
    my $selectStatement_T =
      "SELECT Max($Topic_History.revision) FROM $Topic_History,$Topics,$Webs ";
    $selectStatement_T .= " WHERE $Topics.web_key = $Webs.\"key\" ";
    $selectStatement_T .=
" AND $Webs.web_name = ? AND $Topics.topic_name=? AND $Topic_History.timestamp_epoch<?";
    my $selectHandler_T =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_T);
    $selectHandler_T->{RaiseError} = 1;

    $selectHandler_T->execute($web_name);

    my $max_rev = 0;

    while ( my $row = $selectHandler_T->fetchrow_array ) {
        $max_rev = @$row[0];
    }
    return $max_rev || 0;

}

# moveAttachment -> true if successful, false if there is an exception
sub moveAttachment {

    my ( $this, $store, $newWeb, $newTopic, $newAttachment, $cUID ) = @_;

    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    # FIXME might want to delete old directories if empty
    my $new = $store->getHandler( $newWeb, $newTopic, $newAttachment );

    # Get the user_key
    my $user_key = userGuidHunter($cUID);

    # Name all of the database tables
    my $Topics             = $this->{database_tables}->{Topics};
    my $Webs               = $this->{database_tables}->{Webs};
    my $Attachments        = $this->{database_tables}->{Attachments};
    my $Attachment_History = $this->{database_tables}->{Attachment_History};

    my ( $old_web_name, $old_topic_name, $old_file_name ) =
      ( $this->{web}, $this->{topic}, $this->{file} );
    my ( $new_web_name, $new_topic_name, $new_file_name ) =
      ( $new->{web}, $new->{topic}, $new->{file} );

    # Need to fill 3 input ($old_file_name, $old_topic_name, $old_web_name)
    my $selectStatement_A =
"SELECT $Attachments.* FROM $Attachments, $Topics, $Webs WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\"";
    $selectStatement_A .=
" AND $Attachments.file_name = ? AND $Topics.topic_name = ? AND $Webs.web_name = ?";
    my $selectHandler_A =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_A);
    $selectHandler_A->{RaiseError} = 1;

# Need to fill 6 for Update of Attachments ($new_file_key,$new_file_name,$new_topic_name,$new_web_name, $old_file_name, $old_topic_name, $old_web_name)
    my $subSelect_old =
"SELECT $Topics.key FROM $Topics,$Webs WHERE $Topics.web_key = $Webs.\"key\" AND $Topics.topic_name=? AND $Webs.web_name=?";
    my $subSelect_new =
"SELECT $Topics.key FROM $Topics,$Webs WHERE $Topics.web_key = $Webs.\"key\" AND $Topics.topic_name=? AND $Webs.web_name=?"
      ;    #same as old (done not to be confusing)

    my $updateStatement_A =
      "UPDATE $Attachments SET (file_name,topic_key) = (?,($subSelect_new))";
    $updateStatement_A .= " WHERE file_name=? topic_key=($subSelect_old)";
    my $updateHandler_A =
      $this->{database_connection}->{db_writer}->prepare($updateStatement_A);
    $updateHandler_A->{RaiseError} = 1;

# Need to fill 3 for Insert into Attachment_History ($old_topic_name,$old_web_name, $user_key)   (using the old file name, so no need to input that)
    my $subSelect_oldAttach =
"SELECT $Attachments.file_key, $Attachments.topic_key,$Attachments.key,$Attachments.upload_time,$Attachments.description,$Attachments.file_size,$Attachments.file_stream,";
    $subSelect_oldAttach .=
"$Attachments.\"tmp_Filename\",$Attachments.file_name, $Attachments.file_attachment, $Attachments.file_attr ";
    $subSelect_oldAttach .= " FROM $Topics,$Attachments,$Webs";
    $subSelect_oldAttach .=
" WHERE $Attachments.topic_key = $Topics.key AND $Topics.web_key = $Webs.key ";
    $subSelect_oldAttach .= "$Topics.topic_name=? AND $Webs.web_name=?";

    my $insertStatement_A_H =
"INSERT INTO Attachment_History (\"key\",  topic_key, user_key,  attachment_key, upload_time , description, file_size,";
    $insertStatement_A_H .=
"file_stream, \"tmp_Filename\", file_name, file_attachment,  file_attr, user_key) "
      ;    #\"version\" not included because it auto-increments
    $insertStatement_A_H .= " (($subSelect_oldAttach),?) ";
    my $insertHandler_A_H =
      $this->{database_connection}->{db_writer}->prepare($insertStatement_A_H);
    $insertHandler_A_H->{RaiseError} = 1;

    eval {

        #($old_topic_name,$old_web_name, $user_key)
        $insertHandler_A_H->execute( $old_topic_name, $old_web_name,
            $user_key );

#($new_file_name,$new_topic_name,$new_web_name, $old_file_name, $old_topic_name, $old_web_name)
        $updateHandler_A->execute(
            $new_file_name, $new_topic_name, $new_web_name,
            $old_file_name, $old_topic_name, $old_web_name
        );

        # commit the transaction
        $this->{database_connection}->{db_writer}->commit;
    };
    if ($@) {
        warn "Move Attachment aborted because $@";

        # now rollback to undo the incomplete changes
        # but do it in an eval{} as it may also fail
        eval { $this->{database_connection}->{db_writer}->rollback };

        # add other application on-error-clean-up code here
        return 0;
    }
    return 1;

}

# copyAttachment -> true if successful, false if there is an exception
sub copyAttachment {

    my ( $this, $store, $newWeb, $newTopic, $newAttachment, $cUID ) = @_;

    ASSERT( $store->isa('Foswiki::Store') ) if DEBUG;

    # FIXME might want to delete old directories if empty
    my $new = $store->getHandler( $newWeb, $newTopic, $newAttachment );

    # Get the user_key
    my $user_key = userGuidHunter($cUID);

    # Name all of the database tables
    my $Topics             = $this->{database_tables}->{Topics};
    my $Webs               = $this->{database_tables}->{Webs};
    my $Attachments        = $this->{database_tables}->{Attachments};
    my $Attachment_History = $this->{database_tables}->{Attachment_History};

    my ( $old_web_name, $old_topic_name, $old_file_name ) =
      ( $this->{web}, $this->{topic}, $this->{file} );
    my ( $new_web_name, $new_topic_name, $new_file_name ) =
      ( $new->{web}, $new->{topic}, $new->{file} );

    # Need to fill 3 input ($old_file_name, $old_topic_name, $old_web_name)
    my $selectStatement_A =
"SELECT $Attachments.\"key\" $Attachments.file_key FROM $Attachments, $Topics, $Webs WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\"";
    $selectStatement_A .=
" AND $Attachments.file_name = ? AND $Topics.topic_name = ? AND $Webs.web_name = ?";
    my $selectHandler_A =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_A);
    $selectHandler_A->{RaiseError} = 1;

# Need to fill 6 for Update of Attachments ($new_file_key,$new_file_name,$new_topic_name,$new_web_name, $old_file_name, $old_topic_name, $old_web_name)
    my $subSelect_old =
"SELECT $Topics.\"key\" FROM $Topics,$Webs WHERE $Topics.web_key = $Webs.\"key\" AND $Topics.topic_name=? AND $Webs.web_name=?";
    my $subSelect_new =
"SELECT $Topics.\"key\" FROM $Topics,$Webs WHERE $Topics.web_key = $Webs.\"key\" AND $Topics.topic_name=? AND $Webs.web_name=?"
      ;    #same as old (done not to be confusing)

    my $updateStatement_A =
"UPDATE $Attachments SET (file_key,file_name,topic_key) = (?,?,($subSelect_new))";
    $updateStatement_A .= " WHERE file_name=? topic_key=($subSelect_old)";
    my $updateHandler_A =
      $this->{database_connection}->{db_writer}->prepare($updateStatement_A);
    $updateHandler_A->{RaiseError} = 1;

# Need to fill 3 for Insert into Attachment_History ($old_topic_name,$old_web_name, $user_key)   (using the old file name, so no need to input that)
    my $subSelect_oldAttach =
"SELECT $Attachments.file_key, $Attachments.topic_key,$Attachments.\"key\",$Attachments.upload_time,$Attachments.description,$Attachments.file_size,$Attachments.file_stream,";
    $subSelect_oldAttach .=
"$Attachments.\"tmp_Filename\",$Attachments.file_name, $Attachments.file_attachment, $Attachments.file_attr ";
    $subSelect_oldAttach .= " FROM $Topics,$Attachments,$Webs";
    $subSelect_oldAttach .=
" WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\" ";
    $subSelect_oldAttach .= "$Topics.topic_name=? AND $Webs.web_name=?";

    my $insertStatement_A_H =
"INSERT INTO Attachment_History (\"key\",  topic_key, user_key,  attachment_key, upload_time , description, file_size,";
    $insertStatement_A_H .=
"file_stream, \"tmp_Filename\", file_name, file_attachment,  file_attr, user_key) "
      ;    #\"version\" not included because it auto-increments
    $insertStatement_A_H .= " (($subSelect_oldAttach),?) ";
    my $insertHandler_A_H =
      $this->{database_connection}->{db_writer}->prepare($insertStatement_A_H);
    $insertHandler_A_H->{RaiseError} = 1;

    ## Prepare for file copy
    # Get the attachment file key
    $selectHandler_A->execute( $old_file_name, $old_topic_name, $old_web_name );
    my $selectReturn_A_ref = $selectHandler_A->fetchall_arrayref;
    my $old_file_key       = "";
    foreach my $attachments_row ( @{$selectReturn_A_ref} ) {
        $old_file_key =
          @$attachments_row[0];    # (0-> attachment key; 1-> file key)
    }
    my $file_path_i = $Foswiki::cfg{PubDir} . '/Guid/' . $old_file_key;

    # we need to make a new file key for the new file path
    # make a UUID for the Topic_History_key
    my $ug           = Data::UUID->new();
    my $uuid         = $ug->create();
    my $new_file_key = $ug->to_string($uuid);
    my $file_path_f  = $Foswiki::cfg{PubDir} . '/Guid/' . $new_file_key;

    require File::Copy;
    eval {

        #($old_topic_name,$old_web_name, $user_key)
        $insertHandler_A_H->execute( $old_topic_name, $old_web_name,
            $user_key );

#($new_file_name,$new_topic_name,$new_web_name, $old_file_name, $old_topic_name, $old_web_name)
        $updateHandler_A->execute(
            $new_file_key, $new_file_name, $new_topic_name,
            $new_web_name, $old_file_name, $old_topic_name,
            $old_web_name
        );
        File::Copy::copy( $file_path_i, $file_path_f )
          or $this->{database_connection}->{db_writer}->rollback;

        # commit the transaction
        $this->{database_connection}->{db_writer}->commit;
    };
    if ($@) {
        warn "Move Attachment aborted because $@";

        # now rollback to undo the incomplete changes
        # but do it in an eval{} as it may also fail
        eval { $this->{database_connection}->{db_writer}->rollback };

        # add other application on-error-clean-up code here
        return 0;
    }
    return 1;

}

sub openStream {
    my ( $this, $mode, %opts ) = @_;
    my $stream;

# Need the $topic_name, $web_name, and the $file_name and possibly the $version_num
    my $topic_name = $this->{topic};
    my $web_name   = $this->{web};
    my $file_name  = $this->{file};
    my $file_key   = "";
    my $file_path  = "";

    # First, need to get the UUID from the attachment table
    # Name all of the database tables
    my $Topics             = $this->{database_tables}->{Topics};
    my $Webs               = $this->{database_tables}->{Webs};
    my $Attachments        = $this->{database_tables}->{Attachments};
    my $Attachment_History = $this->{database_tables}->{Attachment_History};

    if ( $mode eq '<' && $opts{version} ) {

        my $version = $opts{version};

 # if a version number is given      ($topic_name,$web_name,$version,$file_name)
        my $selectStatement_A_beta =
"SELECT $Attachment_History.\"key\" FROM $Webs, $Topics, $Attachments, $Attachment_History ";
        $selectStatement_A_beta .=
" WHERE $Topics.web_key = $Webs.\"key\" AND $Attachments.topic_key = $Topics.\"key\" AND ";
        $selectStatement_A_beta .=
"$Attachment_History.attachment_key = $Attachments.\"key\" AND $Topics.topic_name = ? AND ";
        $selectStatement_A_beta .=
"$Webs.web_name = ? AND $Attachments.\"version\" = ? AND $Attachments.file_name = ? ";
        my $selectHandler_A_beta =
          $this->{database_connection}->{db_reader}
          ->prepare($selectStatement_A_beta);
        $selectHandler_A_beta->execute( $topic_name, $web_name, $version,
            $file_name );

        # get the file key from Attachments
        my $selectReturn_A_beta_ref = $selectHandler_A_beta->fetchall_arrayref;
        foreach my $attachments_row ( @{$selectReturn_A_beta_ref} ) {
            $file_key = $attachments_row
              ;    # only one field is returned, so no need for an array
        }
        $file_path = $Foswiki::cfg{PubDir} . '/Guid/' . $file_key;

        # Bulk load the revision and tie a filehandle
        require Symbol;
        $stream = Symbol::gensym;    # create an anonymous glob

        tie( *$stream, 'Foswiki::Store::_MemoryFile', $file_path );
    }
    else {

        # if no version number is given     ($topic_name,$web_name,$file_name)
        my $selectStatement_A_alpha = "SELECT $Attachments.file_key ";
        $selectStatement_A_alpha .= " FROM $Topics,$Webs,$Attachments";
        $selectStatement_A_alpha .=
" WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\" AND ";
        $selectStatement_A_alpha .=
"$Topics.topic_name=? AND $Webs.web_name=? AND $Attachments.file_name=?";
        my $selectHandler_A_alpha =
          $this->{database_connection}->{db_reader}
          ->prepare($selectStatement_A_alpha);
        $selectHandler_A_alpha->execute( $topic_name, $web_name, $file_name );

        # get the file key from Attachments
        my $selectReturn_A_alpha_ref =
          $selectHandler_A_alpha->fetchall_arrayref;
        foreach my $attachments_row ( @{$selectReturn_A_alpha_ref} ) {
            $file_key = $attachments_row
              ;    # only one field is returned, so no need for an array
        }
        $file_path = $Foswiki::cfg{PubDir} . '/Guid/' . $file_key;

        unless ( open( $stream, $mode, $file_path ) ) {
            throw Error::Simple(
                'DBI::Handler: stream open ' . $file_name . ' failed: ' . $! );
        }
    }
    return $stream;
}

sub test {
    my ( $this, $test ) = @_;

    # get the attachment key
    my $Attachments = $this->{database_tables}->{Attachments};
    my $Topics      = $this->{database_tables}->{Topics};
    my $Webs        = $this->{database_tables}->{Webs};

    # Need to fill 3 input ($old_file_name, $old_topic_name, $old_web_name)
    my $selectStatement_A =
"SELECT $Attachments.file_key FROM $Attachments, $Topics, $Webs WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\"";
    $selectStatement_A .=
" AND $Attachments.file_name = ? AND $Topics.topic_name = ? AND $Webs.web_name = ?";
    my $selectHandler_A =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_A);
    $selectHandler_A->{RaiseError} = 1;

    my $file_key;
    ## setup the before_hash
    my $file_name = $this->{file};  # file name?  file path?  assuming file name
    $selectHandler_A->execute( $file_name, $this->topic(), $this->web() );

    while ( my $row = $selectHandler_A->fetchrow_array ) {
        $file_key = @$row[0];
    }
    my $file_path = $Foswiki::cfg{PubDir} . '/Guid/' . $file_key;

    return eval "-$test '$file_path'";
}

sub getRevisionHistory {
    my $this = shift;

    #ASSERT( $this->{file} ) if DEBUG;

    # get the attachment key
    my $Attachment_History = $this->{database_tables}->{Attachment_History};
    my $Attachments        = $this->{database_tables}->{Attachments};
    my $Topics             = $this->{database_tables}->{Topics};
    my $Webs               = $this->{database_tables}->{Webs};

    # Need to fill 3 input ($file_name, $topic_name, $web_name)
    my $subStatement_A =
"SELECT $Attachments.\"key\" FROM $Attachments, $Topics, $Webs WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\"";
    $subStatement_A .=
" AND $Attachments.file_name = ? AND $Topics.topic_name = ? AND $Webs.web_name = ?";

    my $selectStatement_A_H =
"SELECT MAX($Attachment_History.\"version\") FROM $Attachment_History WHERE $Attachment_History.attachment_key = ($subStatement_A)";
    my $selectHandler_A_H =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_A_H);

    my ( $file_name, $topic_name, $web_name ) =
      ( $this->{file}, $this->{topic}, $this->{web} );
    $selectHandler_A_H->execute( $file_name, $topic_name, $web_name );

    # get the max rev, then add 1;
    my $max_rev = 0;
    while ( my $row = $selectHandler_A_H->fetchrow_array ) {
        $max_rev = @$row[0];
    }
    $max_rev += $max_rev;    # the current file is not included in file history

    return new Foswiki::Iterator::NumberRangeIterator( $max_rev, 1 );
}

sub getLatestRevisionID {
    my $this = shift;
    ASSERT( $this->{file} ) if DEBUG;

    # get the attachment key
    my $Attachment_History = $this->{database_tables}->{Attachment_History};
    my $Attachments        = $this->{database_tables}->{Attachments};
    my $Topics             = $this->{database_tables}->{Topics};
    my $Webs               = $this->{database_tables}->{Webs};

    # Need to fill 3 input ($file_name, $topic_name, $web_name)
    my $subStatement_A =
"SELECT $Attachments.\"key\" FROM $Attachments, $Topics, $Webs WHERE $Attachments.topic_key = $Topics.\"key\" AND $Topics.web_key = $Webs.\"key\"";
    $subStatement_A .=
" AND $Attachments.file_name = ? AND $Topics.topic_name = ? AND $Webs.web_name = ?";

    my $selectStatement_A_H =
"SELECT MAX($Attachment_History.\"version\") FROM $Attachment_History WHERE $Attachment_History.attachment_key = ($subStatement_A)";
    my $selectHandler_A_H =
      $this->{database_connection}->{db_reader}->prepare($selectStatement_A_H);

    my ( $file_name, $topic_name, $web_name ) =
      ( $this->{file}, $this->topic(), $this->web() );
    $selectHandler_A_H->execute( $file_name, $topic_name, $web_name );

    my $max_rev;
    while ( my $row = $selectHandler_A_H->fetchrow_array ) {
        $max_rev = @$row[0];
    }
    return $max_rev || 1;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
