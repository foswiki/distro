#!/usr/bin/perl
# Principally intended for converting between RCS and PlainFileStore, this
# script should also work with any other pair of filestore inmplementations.
use strict;
use warnings;

use Foswiki;

sub bad_args {
    my $ess = shift;
    die "$ess\n" . <<USAGE;
Usage: $0 <opts> <from> <to>
<from> is the source store implementation e.g. 'RcsLite'
<to> is the target store implementation e.g. 'PlainFile'
<opts> may include:
-w <webs>    Hierarchical pathname of a web to convert. Conversion of a web
             automatically implies conversion of all its subwebs. You can
	     have as many -w options as you want. If there are no -w options
	     then all webs will be converted.
-i <topic>   Name of a topic to convert. If there are no -i options, then
             all topics will be converted.
	     You can have as many -i options as you want.
-x <topic>   Specifies a topic name that will cause the script to transfer
             only the latest rev of that topic, ignoring the history. Only
	     attachments present in the latest rev of the topic will be
	     transferrer. Simple topic name, does not support web specifiers.
	     You can have as many -x options as you want. NOTE: to avoid
	     excess working, you are recommended to =-x WebStatistics= (and
	     any other file that has many auto-generated versions that don't
             really need to be kept)
-s <dir>     Root dir for source; must contain data and pub subdirs.
             Only applicable if source implementation stores files on disc.
             Defaults to $Foswiki::cfg{DataDir}/{PubDir} settings.
-t <dir>     Root dir for target; data and pub subdirs will be created.
             Only applicable if target format stores files on disc.
             Defaults to $Foswiki::cfg{DataDir}/{PubDir} settings.
-sdata <dir> Like -s for the /data subdir. Must be paired with an earlier -s or
             -spub
-spub <dir>  Like -s for the /pub subdir. Must be paired with an earlier -s or
             -sdata
-tdata <dir> Like -t for the /data subdir. Must be paired with an earlier -t or
             -tpub
-tpub <dir>  Like -t for the /pub subdir. Must be paired with an earlier -t or
             -tdata
-q           Run quietly, without printing progress messages
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

my $session = new Foswiki();

# Class names of the source and destination store engines
my ( $source, $target );
my @webs;
my @ignore_history;
my @only_topics;
my $verbose = 1;

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
bad_args 'Target format must differ from source format' if $source eq $target;

if ( $datadir[0] eq $datadir[1] && $uses_files[0] && $uses_files[1] ) {
    bad_args
      "-td=$datadir[0] is the same as -sd; cannot overwrite the source store";
}

if ( $pubdir[0] eq $pubdir[1] && $uses_files[0] && $uses_files[1] ) {
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
my $wit = $source_store->eachWeb('');
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
        my $i            = $source_store->getRevisionHistory($top_meta);
        my @top_rev_list = $source_store->getRevisionHistory($top_meta)->all;
        if ( $top_name =~ /^$no_history$/ ) {

            # No history, only do most recent rev
            @top_rev_list = ( shift @top_rev_list );
        }
        foreach my $tri ( reverse @top_rev_list ) {

            # transfer the topic
            print "... copy $top_name rev $tri\n" if $verbose;
            $source_store->readTopic( $top_meta, $tri );
            switch_dirs(1);

            # Save topic
            my $info = $top_meta->getRevisionInfo();

            # Don't forget to force the file date
            $target_store->saveTopic(
                $top_meta,
                $info->{author},
                {
                    forcenewrevision => 1,
                    forcedate        => $info->{date}
                }
            );
            switch_dirs(0);

            # transfer attachments. We use eachAttachment because it
            # won't stumble over deleted attachments which may still
            # have META:FILEATTACHMENT in the topic.
            my $att_it = $source_store->eachAttachment($top_meta);
            die $source_store unless defined $att_it;
            while ( $att_it->hasNext() ) {
                my $att_name = $att_it->next();
                my $att_info = $top_meta->get( 'FILEATTACHMENT', $att_name );

                # Is there info about this attachment in this rev of the
                # topic? If not, we can't do anything useful.
                next unless $att_info;
                my $att_version = $att_info->{version} || 1;

                # avoid copying the same rev twice
                next if $att_tx{"$att_name:$att_version"};
                $att_tx{"$att_name:$att_version"} = 1;

                print "... copy attachment $att_name rev $att_version\n"
                  if $verbose;
                my $stream =
                  $source_store->openAttachment( $top_meta, $att_name, '<',
                    version => $att_version );

                switch_dirs(1);

                # Save attachment
                # SMELL: there's no way to set the date of the
                # copied attachment
                $target_store->saveAttachment( $top_meta, $att_name, $stream,
                    $att_info->{user} );
                switch_dirs(0);
            }
        }
    }
}

1;
