#! /usr/bin/perl
use strict;
use warnings;

use Assert;

use Foswiki                         ();
use Foswiki::Users::BaseUserMapping ();

# Debug only
use Data::Dumper ();

sub bad_args {
    my $ess = shift;
    die "$ess\n" . <<USAGE;
Convert between Foswiki store implementations.

Usage: $0 <opts> <from> <to>

<from> is the source store implementation e.g. 'RcsLite'
<to> is the target store implementation e.g. 'PlainFile'
<opts> may include:

Selecting Webs and Topics

-w <webs>    Hierarchical pathname of a web to convert. Conversion of a web
             automatically implies conversion of all its subwebs. You can
	     have as many -w options as you want. If there are no -w options
	     then all webs will be converted.
-i <topic>   Name of a topic to convert. If there are no -i options, then
             all topics will be converted.
	     You can have as many -i options as you want.
-x <topic>   Name of a topic for which you only want to transfer the latest
             revision of that topic, ignoring the history. Only attachments
             present in the latest rev of the topic will be transferred.
             Simple topic name, does not support web specifiers.
	     You can have as many -x options as you want. NOTE: to avoid
	     excess working, you are recommended to =-x WebStatistics= (and
	     any other file that has many auto-generated versions that
             need not be kept)

Data directories

Some store implementations use data directories on disk that are pointed at
by $Foswiki::cfg{DataDir} and {PubDir}. These options let you control where
these directories are for the two stores.

-s <dir>     Root dir for source; must contain data and pub subdirs.
             Only applicable if source implementation stores files on disc.
             Defaults to $Foswiki::cfg{DataDir}/{PubDir} settings.
-sdata <dir> Like -s for the /data subdir. Must be paired with an earlier -s or
             -spub
-spub <dir>  Like -s for the /pub subdir. Must be paired with an earlier -s or
             -sdata
-autoattach  If the source store allows auto-attachment of files in =spub=
             (the {RCS}{AutoAttachPubFiles} option) then automatically
             attach these files and transfer them.

-t <dir>     Root dir for target; data and pub subdirs will be created.
             Only applicable if target format stores files on disc.
             Defaults to $Foswiki::cfg{DataDir}/{PubDir} settings.
-tdata <dir> Like -t for the /data subdir. Must be paired with an earlier -t or
             -tpub
-tpub <dir>  Like -t for the /pub subdir. Must be paired with an earlier -t or
             -tdata

Miscellaneous

-q           Run quietly, without printing progress messages
-v           Validate. Check the consistency of two previously synchronised
             stores, without performing any transfers. Used for testing.
USAGE
}

# Files-on-disc are pointed at by DataDir and PubDir. We can use this fact
# to target a different directory for the converted files.
my @datadir = ( $Foswiki::cfg{DataDir}, $Foswiki::cfg{DataDir} );
my @pubdir  = ( $Foswiki::cfg{PubDir},  $Foswiki::cfg{PubDir} );
my @uses_files = ( 1, 1 );

sub switch_dirs {
    $Foswiki::cfg{DataDir} = $datadir[ $_[0] ];
    $Foswiki::cfg{PubDir}  = $pubdir[ $_[0] ];
}

sub validate_info {
    my ( $sp, $source, $target ) = @_;

    return if ( !$source && !$target );

    unless ($source) {
        print STDERR "$sp: Source is null\n";
        return;
    }
    unless ($target) {
        print STDERR "$sp: Target is null\n";
        return;
    }
    print STDERR
      "$sp: Authors differ: $source->{author} and $target->{author}\n"
      unless $source->{author} eq $target->{author};
    print STDERR "$sp: Dates differ: $source->{date} and $target->{date}\n"
      unless $source->{date} == $target->{date};
}

my $session = new Foswiki();

# Class names of the source and destination store engines
my ( $source, $target );

# List of webs to transfer
my @webs;

# List of topic names for which we will ignore histories
my @ignore_history;

# List of the only topics to transfer
my @only_topics;

# Make a lot of noise?
my $verbose = 1;

# Validate only
my $validate = 0;

# Simulate {RCS}{AutoAttachPubFiles}
my $autopub = 0;

while ( my $arg = shift @ARGV ) {
    if ( $arg eq '-s' ) {
        my $root = shift @ARGV;
        $datadir[0] = "$root/data";
        $pubdir[0]  = "$root/pub";
    }
    elsif ( $arg eq '-sdata' ) {
        $datadir[0] = shift @ARGV;
    }
    elsif ( $arg eq '-spub' ) {
        $pubdir[0] = shift @ARGV;
    }
    elsif ( $arg eq '-autoattach' ) {
        $autopub = 1;
    }
    elsif ( $arg eq '-t' ) {
        my $root = shift @ARGV;
        $datadir[1] = "$root/data";
        $pubdir[1]  = "$root/pub";
    }
    elsif ( $arg eq '-tdata' ) {
        $datadir[1] = shift @ARGV;
    }
    elsif ( $arg eq '-tpub' ) {
        $pubdir[1] = shift @ARGV;
    }
    elsif ( $arg eq '-w' ) {
        push( @webs, shift @ARGV );
    }
    elsif ( $arg eq '-i' ) {
        push( @only_topics, shift @ARGV );
    }
    elsif ( $arg eq '-x' ) {
        push( @ignore_history, shift @ARGV );
    }
    elsif ( $arg eq '-q' ) {
        $verbose = 0;
    }
    elsif ( $arg eq '-v' ) {
        $validate = 1;
    }
    elsif ( $arg =~ /^-/ ) {
        bad_args "Unrecognised option '$arg'";
    }
    else {
        if ( defined $source ) {
            if ( defined $target ) {
                bad_args "Extra argument '$arg'";
            }
            $target = 'Foswiki::Store::' . $arg;
        }
        else {
            $source = 'Foswiki::Store::' . $arg;
        }
    }
}

bad_args 'Must specify source and target store implementations'
  unless $source && $target;

if (  !$validate
    && $datadir[0] eq $datadir[1]
    && $uses_files[0]
    && $uses_files[1] )
{
    bad_args
      "-td=$datadir[0] is the same as -sd; cannot overwrite the source store";
}

if (  !$validate
    && $pubdir[0] eq $pubdir[1]
    && $uses_files[0]
    && $uses_files[1] )
{
    bad_args
      "-tp=$pubdir[0] is the same as -sp; cannot overwrite the source store";
}

my $weblist = scalar @webs ? join( '|', map { ( $_, "$_/.*" ) } @webs ) : '.*';
my $toplist    = scalar @only_topics    ? join( '|', @only_topics )    : '.*';
my $no_history = scalar @ignore_history ? join( '|', @ignore_history ) : '';

eval "require $source";
die $@ if $@;
eval "require $target";
die $@ if $@;
print "Options:\n" if $verbose;
print <<INFO if $verbose && $uses_files[0];
-sd $datadir[0]
-sp $pubdir[0]
INFO

print <<INFO if $verbose && $uses_files[1];
-td $datadir[1]
-tp $pubdir[1]
INFO

# SMELL: do we really want to _LoadAndRegisterListeners?
switch_dirs(0);
my $source_store = $source->new();
switch_dirs(1);
my $target_store = $target->new();

switch_dirs(0);
my $wit = $source_store->eachWeb( '', 1 );
while ( $wit->hasNext() ) {
    my $web_name = $wit->next();
    next unless $web_name =~ /^($weblist)$/o;
    my $web_meta = new Foswiki::Meta( $session, $web_name );
    print "Scanning web $web_name\n" if $verbose;
    my $top_it = $source_store->eachTopic($web_meta);
    while ( $top_it->hasNext() ) {
        my $top_name = $top_it->next();
        next unless $top_name =~ /^($toplist)$/o;
        my $top_meta = new Foswiki::Meta( $session, $web_name, $top_name );

        my %att_tx = ();    # record of attachments transferred for this topic
        my @top_rev_list = $source_store->getRevisionHistory($top_meta)->all;
        if ( $top_name =~ /^$no_history$/ ) {

            # No history, only do most recent rev
            @top_rev_list = ( shift @top_rev_list );
        }
        foreach my $topic_version ( reverse @top_rev_list ) {

            # transfer the topic
            $source_store->readTopic( $top_meta, $topic_version );
            my $info = $top_meta->getRevisionInfo();

            if ($validate) {
                my $path = $top_meta->getPath() . ":$topic_version";

                # Ensure getVersionInfo and META:TOPICINFO are consistent
                my $source_topicinfo = ( $top_meta->find('TOPICINFO') )[0];
                my $source_info =
                  $source_store->getVersionInfo( $top_meta, $topic_version );
                $top_meta->unload();

                # Reread the meta from the target store
                switch_dirs(1);
                $target_store->readTopic( $top_meta, $topic_version );

                # Use getRevisionInfo to ensure the TOPICINFO is correct
                # before we access it using 'find'
                $top_meta->getRevisionInfo();
                my $target_topicinfo = ( $top_meta->find('TOPICINFO') )[0];
                my $target_info =
                  $target_store->getVersionInfo( $top_meta, $topic_version );
                switch_dirs(0);

                print "... validate $top_name:$topic_version\n" if $verbose;
                validate_info( "$path(T)", $source_topicinfo,
                    $target_topicinfo );
                validate_info( $path, $source_info, $target_info );

                $top_meta->unload();
                $source_store->readTopic( $top_meta, $topic_version );
            }
            else {

                print "... copy $top_name:$topic_version\n"
                  if $verbose;

                switch_dirs(1);
                $target_store->saveTopic(
                    $top_meta,
                    $info->{author},
                    {
                        forcenewrevision => 1,
                        forcedate        => $info->{date}
                    }
                );
                switch_dirs(0);
            }

            # Transfer attachments. This is hard, because the traditional
            # RCS store implementations survive a lot of abuse. The main
            # cases we have to be aware of are:
            #
            # 1. The files for an attachment, can be deleted
            #    from the file system, leaving META:FILEATTACHMENT still in
            #    older revs of the topic, but with no physical trace of the
            #    attachment.
            #
            # 2. META:FILEATTACHMENT might be missing for a file that exists
            #    on disc, in the expectation that it is implictly auto-attached
            #    in the store.
            #
            # 3. An attachment file might exist on disc but without history,
            #    or with a history that lacks the revision specified in the
            #    META:FILEATTACHMENT.
            #
            # We use eachAttachment rather than META:FILEATTACHMENT because
            # it iterates over all files in the pub dir in these file-based
            # stores.
            #
            my $att_it = $source_store->eachAttachment($top_meta);
            die $source_store unless defined $att_it;
            while ( $att_it->hasNext() ) {
                my $att_name = $att_it->next();
                my $att_info = $top_meta->get( 'FILEATTACHMENT', $att_name );

                unless ($att_info) {

                    # Case 2: There is no META:FILEATTACHMENT for this
                    # attachment in this rev of the topic
                    if ($autopub) {

                        # If -autoattach, fall through and make something
                        # up.
                        $att_info = {};
                    }
                    elsif ( \$topic_version == \$top_rev_list[0] ) {

                        # If the attachment is missing from the "top rev",
                        # report the file as it may be valuable.
                        print "NO META FOR ATTACHMENT: File not copied! "
                          if ($verbose);
                        print "$top_name/$att_name\n";
                        next;
                    }
                    else {
                        next;
                    }
                }

                my $att_version = $att_info->{version};
                my $att_user    = $att_info->{author};

                unless ( $att_user && $att_version ) {

                    # Something is missing from META:FILEATTACHMENT
                    # (or it's missing completely and -autoattach is on).
                    # Get missing info from the store. If $att_version
                    # is not set, we default to using the latest rev
                    # of the attachment. This could lead to an attachment
                    # having a revision date more recent than the topic
                    # revision it is attached to. Unfortunately the store
                    # does not support getRevisionAtTime for attachments.
                    my $info =
                      $source_store->getVersionInfo( $top_meta, $att_version,
                        $att_name );

                    $att_version ||= $info->{version};
                    $att_user ||= $info->{user}
                      || $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;
                }

                # avoid copying the same rev twice
                next if $att_tx{"$att_name:$att_version"};
                $att_tx{"$att_name:$att_version"} = 1;

                my $stream =
                  $source_store->openAttachment( $top_meta, $att_name, '<',
                    version => $att_version );

                if ($validate) {
                    my $path = $top_meta->getPath() . ":$topic_version";
                    $path .= "/$att_name:$att_version";

                    # Ensure getVersionInfo are consistent
                    my $source_info =
                      $source_store->getVersionInfo( $top_meta, $att_version,
                        $att_name );

                    switch_dirs(1);

                    # Reread the meta from the target store
                    my $target_info =
                      $target_store->getVersionInfo( $top_meta, $att_version,
                        $att_name );
                    switch_dirs(0);

                    # Case 3: The META:FILEATTACHMENT carries date and author
                    # fields. However these can drift from the history due
                    # to changes to attachments not reflected in the topic
                    # meta-data. So the only source we trust is
                    # getVersionInfo().
                    validate_info( $path, $source_info, $target_info );

                }
                else {
                    switch_dirs(1);

                    # Save attachment
                    print "... copy attachment $att_name rev $att_version"
                      . " as $att_user\n"
                      if $verbose;

                    # SMELL: there's no way to force the date of the
                    # copied attachment
                    $target_store->saveAttachment( $top_meta, $att_name,
                        $stream, $att_user );
                    switch_dirs(0);
                }
            }
        }
    }
}

1;
