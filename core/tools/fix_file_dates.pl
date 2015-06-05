#
# Examine all .txt files in the directory structure under where the
# script is run from, and modify the file modified times to be the same
# as the time stored in the TOPICINFO in the topic. Also modifies the
# ,v file (if it exists) to slightly after the modified time (otherwise
# the RCS stores will assume the .txt has been modified since the ,v was
# saved)
#
# This script is designed to be used after a directory structure is copied
# or bulk modified, and all the file times are wrong. It's a generally
# useful thing, so is included in the tool set.
#
use strict;
use warnings;

# the -i option will show what the script *would* do, if you ran it
# without -i
my $info = ( $ARGV[0] && $ARGV[0] eq '-i' );

# Only interested in the first line of topics %META:TOPICINFO
$/ = "\n";

sub fix_time {
    my ( $path, $time ) = @_;

    my $mtime = ( stat($path) )[9];
    if ( $mtime > $time ) {
        if ($info) {
            print "$mtime -> $time, $path\n";
        }
        else {
            utime( $time, $time, $path );
        }
    }
}

sub process_topic {
    my $topic = shift;
    my $fh;

    if ( open( $fh, '<', $topic ) ) {
        my $fl = <$fh>;
        close($fh);
        return unless $fl && $fl =~ /^%META:TOPICINFO{.*date="(\d+)\".*}%/;
        my $time = $1;
        fix_time( $topic, $time );

        # Set a slightly later time on the corresponding ,v
        if ( -e "$topic,v" ) {
            fix_time( "$topic,v", $time + 1 );
        }
    }
}

sub process_dir {
    my $dir = shift;
    my $dh;

    if ( opendir( $dh, $dir ) ) {
        print "Scanning $dir\n";
        foreach my $f ( readdir $dh ) {
            next if $f =~ /^\./;
            $f = "$dir/$f";
            if ( -d $f ) {
                process_dir($f);
            }
            elsif ( $f =~ /\.txt$/ ) {
                process_topic($f);
            }
        }
    }
}

process_dir('.');
