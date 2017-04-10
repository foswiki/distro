#! /usr/bin/env perl
#
# Author: Crawford Currie http://c-dot.co.uk
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2014-2017 Foswiki Contributors. Foswiki Contributors
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

#
# Script for bulk copying of topics, complete with histories, between
# any two *local* Foswiki installations (hosted on the same machine)
#
# The script forks itself to operate as two processes; the "sender", which
# is the source of the topics, and the "receiver", which is the target.
# The processes communicate with each other through anonymous pipes, using
# utf-8 JSON encoded messages.
#
# The APIs used for manipulation are Foswiki::Meta and (to a minimal
# extent) Foswiki::Store. Use of these APIs shelters the script from
# the details of the store implementation.
#
use strict;
use warnings;

use Getopt::Long ();
use Pod::Usage   ();
use File::Spec   ();
use JSON         ();
use Encode       ();
use Error;

$Error::Debug = 1;    # verbose stack traces, please

use version;
our $VERSION = version->declare("v2.0");

# JSON is used for communication between two peer processes, sender
# and receiver.
our $json = JSON->new->utf8(1)->allow_nonref->convert_blessed(1);
our $session;

# Trace constants
use constant {
    ERROR   => 0,
    WEBSCAN => 1,
    TOPSCAN => 2,
    VERSCAN => 4,
    COPY    => 8,
    ALL     => 15
};

our @arg_iweb;      # List of webs to include (empty implies all webs)
our @arg_xweb;      # List of webs to exclude
our @arg_mapweb;    # List of webs to rename
our @arg_itopic;    # List of topics to include (empty implies all topics)
our @arg_xtopic;    # List of topics to exclude
our @arg_latest;    # List of topics for which only the latest is to be copied
our $arg_trace = 0; # shhhh
our $arg_check = 0; # If true, don't copy, just check
our $arg_deep  = 1; # If true, recurse into existing webs/topics to check

our %map_web;

# All comms between sender and receiver are done using unicode. For
# Foswiki versions >= 2 (indicated by $Foswiki::UNICODE), this is a
# no-brainer as unicode is used internally so no encoding is
# required. But for a sender/receiver using an older version of
# Foswiki, strings have to be transformed between unicode and the
# {Site}{CharSet}.  This function recurses into arrays and hashes.
# $item - the thing to encode/decode
# \&action - address of a function to do the encoding/decoding
sub _convert {
    my ( $item, $action ) = @_;

    my $res;
    if ( ref($item) eq 'HASH' ) {
        $res = {};
        while ( my ( $k, $v ) = each %$item ) {
            $res->{ _convert( $k, $action ) } = _convert( $v, $action );
        }
    }
    elsif ( ref($item) eq 'ARRAY' ) {
        $res = [];
        foreach my $e (@$item) {
            push( @$res, _convert( $e, $action ) );
        }
    }
    elsif ( ref($item) ) {
        die "Don't know how to convert a " . ref($item);
    }
    else {
        $res = &$action($item);
    }
    return $res;
}

#use Devel::Cycle;

sub cleanup_meta {
    my $mo = shift;

    #    undef $mo->{_session};
    #    find_cycle($mo);
    $mo->finish();
}

#######################################################################
# Sender

our $indent = 0;

sub announce {
    my $level = shift;
    if ( $level == ERROR ) {
        print STDERR @_, "\n";
    }
    elsif ( ( $level & $arg_trace ) != 0 ) {
        print( ' ' x $indent ) if $level && $level < ALL;
        print @_, "\n";
    }
}

# RPC to a function in the receiver. Parameters are automatically
# encoded unless they are passed as SCALAR refs.
sub call {
    my $act = shift;
    my @p = ( $act, map { ref($_) eq 'SCALAR' ? $$_ : site2unicode($_) } @_ );

    # Encode to utf8-encoded JSON
    my $json_text = $json->encode( \@p );

    print TO_B "$json_text\n";

    $/ = "\n";
    my $response = <FROM_B>;
    die "Bad response from peer" unless defined $response;
    ( my $status, $response ) = split( ':', $response, 2 );
    die "Bad response from peer" unless $status =~ /^\d+$/;

    # Response is utf8-encoded JSON
    $response = $json->decode($response);

    # Convert response to {Site}{CharSet}, if necessary
    unicode2site($response);

    die $response if $status;

    return $response;
}

# Copy all matched webs. This is all webs in the install, filtered
# by the command-line options.
sub copy_webs {
    my $rootMO = Foswiki::Meta->new($session);
    my $wit    = $rootMO->eachWeb(1);

    if (   !grep( $Foswiki::cfg{SystemWebName} =~ /^$_([\/.]|$)/, @arg_iweb )
        && !grep( $Foswiki::cfg{SystemWebName} =~ /^$_([\/.]|$)/, @arg_xweb ) )
    {
        announce( ALL,
            "Adding $Foswiki::cfg{SystemWebName} to list of excluded webs" );
        push @arg_xweb, $Foswiki::cfg{SystemWebName};
    }
    while ( $wit->hasNext() ) {
        my $web    = $wit->next();
        my $forced = scalar(@arg_iweb);
        if ( $forced && !grep( $web =~ /^$_([\/.]|$)/, @arg_iweb ) ) {
            announce( WEBSCAN, 'Skipping not-iweb ', $web );
            next;
        }

        # Are we skipping this web?
        if ( grep( $web =~ /^$_([\/.]|$)/, @arg_xweb ) ) {
            announce( WEBSCAN, 'Skipping xweb ', $web );
            next;
        }

        if ( !$arg_deep && call( "webExists", $web ) ) {
            announce( WEBSCAN, 'Web ', $web, ' already exists in target' );
            next;
        }

        announce( ERROR,
"*** CAUTION *** Copying $Foswiki::cfg{SystemWebName} web - this is NOT recommended."
        ) if ( $web eq $Foswiki::cfg{SystemWebName} );
        copy_web($web);
    }
    cleanup_meta($rootMO);
}

# Copy all the topics in a web.
sub copy_web {
    my ($web) = @_;

    # Copy the web
    announce WEBSCAN, "Web $web";
    my $webMO = Foswiki::Meta->new( $session, $web );

    # saveWeb returns the name of the WebPreferences topic,
    # iff it needed to be created
    my $toweb = $map_web{$web} // $web;
    my $wpt = call( 'saveWeb', $toweb );
    announce( COPY, "Copied web ", $webMO->getPath(), " to ", $toweb )
      if $wpt;
    my $tit = $webMO->eachTopic();
    $indent++;
    while ( $tit->hasNext() ) {
        my $topic = $tit->next();
        if ( grep { $topic =~ /(^|[\/.])$_$/ } @arg_xtopic ) {
            announce TOPSCAN, "Skipping xtopic $web.$topic";
            next;
        }

        # Always copy WebPreferences topic, if it was just created.
        if ( $topic ne $wpt ) {
            my $forced = scalar(@arg_itopic);
            if ( $forced
                && !grep { $topic =~ /(^|[\/.])$_$/ } @arg_itopic )
            {
                announce TOPSCAN, "Skipping not-itopic $web.$topic";
                next;
            }
            if ( !$arg_deep && call( "topicExists", $toweb, $topic ) ) {
                announce TOPSCAN,
                  "Topic $toweb.$topic already exists in target";
                next;
            }
        }
        copy_topic( $web, $toweb, $topic );
    }
    cleanup_meta($webMO);
    $indent--;
}

# Copy a single topic and all it's attachments.
# Transferring attachments is trickier than it should be, because
# the way attachments are stored and managed in RCS means that
# there isn't a 1:1 correspondence between attachment versions
# mentioned in the META:FILEATTACHMENT and the attachments actually
# present in the history. So we establish the maximum rev number
# for each attachment as and when we encounter it in the topic history.
# At that time we also interrogate the store to determine the maximum
# number of revs of the attachment that are available in the attachment
# history. Then as we replay the history from the oldest topic version
# forwards, we are able to run the attachment version up to the version
# encountered in the topic.
#
# There are a number of ways revision histories of attachments can
# get mangled.
# 1. The topic can reference a revision that doesn't exist in the
#    attachment history.
# 2. The topic can reference a revision that is *newer* than the
#    revision in a newer version of the topic e.g.
#    Topic rev 1 references attachment rev 2
#    Topic rev 2 reference attachment rev 1
# 3. Attachments may not be referenced in topics at all.
sub copy_topic {
    my ( $web, $toweb, $topic ) = @_;

    announce TOPSCAN, "Topic $web.$topic";
    my $topicMO = Foswiki::Meta->new( $session, $web, $topic );

    # Revision list is sorted starting with the most recent revision
    my @rev_list = $topicMO->getRevisionHistory()->all();

    # See if topic is in the "only latest" list
    if ( grep { "$web.$topic" =~ /^$_$/ } @arg_latest ) {
        announce TOPSCAN, " - only latest";

        # Only do latest rev
        @rev_list = ( shift @rev_list );
    }

    # Get version info from the receiver. This tells us the already-copied
    # topic and attachment versions.
    my $info = call( 'getVersionInfo', $toweb, $topic );

    $indent++;
    announce( VERSCAN, "Versions 1..$info->{topic} already copied" )
      if ( $info->{topic} > 0 );

    # Replay history, *oldest* rev first
    while ( my $tv = pop @rev_list ) {

        # < rather than <= because We do the load for the max_rev even
        # if it's already transferred, just in case it was interrupted
        # in the middle of txing attachments
        next if ( $tv < $info->{topic} );

        $topicMO->unload();

        # Work around a bug in 1.1.x RCS stores that causes the head of
        # the history to be loaded for the most recent rev number when
        # an explicit rev number is passed, when in fact we want the
        # (possibly edited) .txt
        $topicMO->loadVersion( scalar(@rev_list) ? $tv : undef );

        # Again this is working around the fact that the RCS stores
        # don't clean up META:TOPICINFO unless it's explicitly asked for.
        # The getRevisionInfo call will side-effect a cleanup.
        my $ri = $topicMO->getRevisionInfo();

        # If this is the max rev transferred so far, we only tx
        # attachments. The topic text is already transferred but
        # we can't be sure we got all the attachments.
        my $spoken = 0;
        unless ( $tv == $info->{topic} ) {

            # Serialise it
            my $data = $topicMO->getEmbeddedStoreForm();

            # NOTE: this 'trusts' the TOPICINFO that the store
            # embeds in $data, which may not be wise.
            my $sas = call( 'saveTopicRev', $toweb, $topic, $data );
            announce( COPY, 'Copied ', $topicMO->getPath(), ' @', $tv,
                ' as version ', $sas );
            $spoken = 1;
        }

        # Transfer attachments.

        my $att_it = $topicMO->eachAttachment();
        $indent++;
        while ( $att_it->hasNext() ) {
            my $att_name = $att_it->next();
            $info->{att}->{$att_name} //= 0;

            # Is there info about this attachment in this rev of the
            # topic? If not, we can't do anything useful here. It'll
            # be cleaned up in the hidden attachment handling.
            my $att_info = $topicMO->get( 'FILEATTACHMENT', $att_name );
            next unless ($att_info);

            unless ($spoken) {
                announce TOPSCAN, "Attachments for $topic v$tv";
                $spoken = 1;
            }

            $info->{have_meta}->{$att_name} = 1;

            my $att_version = $att_info->{version};
            unless ($att_version) {
                announce ERROR,
                  "Attachment $web.$topic:$att_name has corrupt meta-data";
                next;
            }

            # Check if the attachment history is already there
            if ( $att_version <= $info->{att}->{$att_name} ) {
                announce TOPSCAN, "Attachment $att_name is up to date";
                next;
            }

            announce TOPSCAN, "Attachment $att_name";
            announce VERSCAN,
              "Versions 1..$info->{att}->{$att_name} have already been copied"
              if ( $info->{att}->{$att_name} );

            unless ( $att_info->{user} ) {
                require Foswiki::Users::BaseUserMapping;
                $att_info->{user} =
                  $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;
            }

            # Copy hidden intermediates up to and including the version
            # referenced.
            while ( $info->{att}->{$att_name} < $att_version ) {
                $info->{att}->{$att_name}++;
                $att_info->{version} = $info->{att}->{$att_name};
                copy_attachment_version( $topicMO, $toweb, $att_info );
            }
        }
        $indent--;
    }

    # Any attachments that are seen by the store but haven't been
    # copied have no FILEATTACHMENT in any topic version. Copy all
    # their revs.
    while ( my ( $att_name, $rev ) = each %{ $info->{att} } ) {
        next if $info->{have_meta}->{$att_name};
        require Foswiki::Users::BaseUserMapping;
        my %att_info = (
            name => $att_name,
            user => $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID,
            date => 0
        );
        my @revs = $topicMO->getRevisionHistory($att_name)->all();
        $info->{att}->{$att_name} //= 0;
        if ( $revs[$#revs] <= $info->{att}->{$att_name} ) {
            announce TOPSCAN, "Hidden attachment $att_name is up to date";
            next;
        }
        announce TOPSCAN, "Hidden attachment $att_name";
        announce VERSCAN,
          "Versions 1..$info->{att}->{$att_name} have already been copied"
          if ( $info->{att}->{$att_name} );

        while ( my $rev = pop(@revs) ) {
            next if ( $rev <= $info->{att}->{$att_name} );

            $att_info{version} = $rev;
            copy_attachment_version( $topicMO, $toweb, \%att_info );
        }
    }
    cleanup_meta($topicMO);
    $indent--;
}

sub copy_attachment_version {
    my ( $meta, $toweb, $att_info ) = @_;
    my $att_name = $att_info->{name};
    my $att_ver  = $att_info->{version};

    my $fh = $meta->openAttachment( $att_name, '<', version => $att_ver );

    # Write data into temp file
    my $tfh = File::Temp->new( UNLINK => 0, SUFFIX => '.dat' );

    # Temp file will be unlinked in receiver
    binmode $tfh;
    local $/ = undef;
    my $data = <$fh>;
    if ( length($data) ) {
        print $tfh $data;
    }
    else {
        # Empty attachments can't be saved
        announce( ERROR, $meta->getPath(), ':', $att_name,
            ' @', $att_info->{version}, ' is empty' );
    }
    close($tfh);
    my $tfn = $tfh->filename();

    my $sas =
      call( 'saveAttachmentRev', $toweb, $meta->topic, $att_info, \$tfn );
    announce( COPY, 'Copied ', $meta->getPath(), ':', $att_name,
        ' @', $att_info->{version}, ' as version ', $sas );
}

#######################################################################
# Receiver

# Dispatch a function call in the receiver
sub dispatch {
    my $message = shift;    # a utf8-encoded JSON string

    $message =~ /^(.*)$/;   # untaint
    my $data = $json->decode($1);

    # $data is a structure containing unicode strings
    return 0 unless $data;

    # Convert to {Site}{Charset}, if necessary
    unicode2site($data);

    return 0 unless $data;

    my $fn = shift(@$data);    # function name

    my $response;
    eval {
        no strict 'refs';
        $response = &$fn(@$data);
        use strict 'refs';
    };
    my $status = 0;
    if ($@) {
        $status   = 1;
        $response = $@;
    }

    # Convert response to unicode (if necessary)
    site2unicode($response);

    $response = $json->encode($response);

    # JSON encode and print
    print TO_A "$status:$response\n";

    return 1;
}

# The following functions are all callable through the call() RPC interface

# Check if the given web exists
sub webExists {
    my $web = shift;
    return $session->webExists($web);
}

# Check if the given topic exists
sub topicExists {
    my $web   = shift;
    my $topic = shift;
    return $session->topicExists( $web, $topic );
}

# Get version information for the given topic. This consists of the
# max rev of the topic and a hash of attachments with the max rev of each
sub getVersionInfo {
    my ( $web, $topic ) = @_;
    unless ( $session->topicExists( $web, $topic ) ) {
        return { topic => 0, att => {} };
    }
    my $mo   = Foswiki::Meta->new( $session, $web, $topic );
    my $ri   = $mo->getRevisionInfo();
    my $info = { topic => $ri->{version}, att => {} };

    # Attachments in the *current version*
    my $att_it = $mo->eachAttachment();
    while ( $att_it->hasNext() ) {
        my $att_name = $att_it->next();

        # First try meta for attachment info
        my $att_info = $mo->get( 'FILEATTACHMENT', $att_name );

        # If not in META, ask the store directly
        $att_info = $mo->getAttachmentRevisionInfo($att_name)
          unless $att_info;
        next unless $att_info;
        $info->{att}->{$att_name} = $att_info->{version};
    }
    cleanup_meta($mo);
    return $info;
}

# Create a new web iff it doesn't already exist. If it is created, return
# the name of the WebPreferences topic (this is used by some stores to
# identify a web)
sub saveWeb {
    my $web = shift;
    return '' if ( $arg_check || $session->webExists($web) );
    my $mo = Foswiki::Meta->new( $session, $web );
    $mo->populateNewWeb();
    cleanup_meta($mo);

    # Return the name of the web preferences topic, as it was just created
    return $Foswiki::cfg{WebPrefsTopicName};
}

# Given data for the topic in the form of topic text with embedded meta-data,
# save this rev of the topic.
sub saveTopicRev {
    my ( $web, $topic, $data ) = @_;

    my $mo = Foswiki::Meta->new( $session, $web, $topic );
    $mo->setEmbeddedStoreForm($data);

    my $info = $mo->get('TOPICINFO');

    my $res = -1;
    unless ($arg_check) {
        $res = $mo->save(
            author           => $info->{author},
            forcenewrevision => 1,
            forcedate        => $info->{date},
            dontlog          => 1,
            minor            => 1,

            # Don't call handlers (works on 2+ only)
            nohandlers => 1
        );
    }
    cleanup_meta($mo);
    return $res;
}

# Given revision info and data for the attachment
# save this rev.
sub saveAttachmentRev {
    my ( $web, $topic, $info, $fname ) = @_;
    my $mo = Foswiki::Meta->new( $session, $web, $topic );
    my $rev = -1;
    unless ($arg_check) {

        # Can't use $mo->attach because it updates the FILEATTACHMENT
        # metadata, and we've already written that when transferring
        # the topic. So we have to kick under it to the
        # Store::saveAttachment method - which is OK because it's part
        # of the (relatively stable) store API.
        my $fh;
        open( $fh, '<', $fname ) || die "Failed to open $fname";
        $rev = $mo->session->{store}->saveAttachment(
            $mo,
            $info->{name},
            $fh,
            $info->{user},
            {    # Only works for Foswiki 2.0
                forcedate => $info->{date},
                comment   => $info->{comment}
            }
        );
        close($fh);
    }
    unlink($fname);
    cleanup_meta($mo);
    return $rev;
}

#######################################################################
# Main Program

# convert * and ? to regex, and quotemeta other re chars in an array
# of strings
sub wildcard2regex {
    my $a = shift;
    foreach (@$a) {
        s/(\[\]\.\{\}\|\(\)\^\$)/\\$1/g;
        s/\./\\./g;
        s/\*/.*/g;
        s/\?/./g;
    }
}

sub set_up_unicode {

    announce( ALL,
        $_[0],
        ' is ',
        $Foswiki::VERSION,
        ' Store ',
        $Foswiki::cfg{Store}{Implementation},
        defined $Foswiki::cfg{Store}{Encoding}
        ? " encoding $Foswiki::cfg{Store}{Encoding}"
        : ''
    );

    binmode( STDOUT, ':utf8' );
    binmode( STDERR, ':utf8' );

    # NOOP
    *site2unicode = sub { return $_[0] };
    *unicode2site = sub { return $_[0] };
}

sub set_up_site_charset {

    # Conversion required
    my $site_charset = $Foswiki::cfg{Site}{CharSet} || 'iso-8859-1';

    announce ALL,
"$_[0] is $Foswiki::VERSION, $site_charset, Store $Foswiki::cfg{Store}{Implementation}";

    require Encode;
    *site2unicode = sub {

        # Encoding in a site charset that may not support the
        # source character. Map to HTML entities, as that is the
        # most appropriate for .txt
        $_[0] = _convert(
            $_[0],
            sub {
                return Encode::encode( $site_charset, $_[0],
                    Encode::FB_HTMLCREF );
            }
        );
    };
    *unicode2site = sub {
        $_[0] = _convert(
            $_[0],
            sub {
                return Encode::decode( $site_charset, $_[0], Encode::FB_CROAK );
            }
        );
    };
}

my $to   = pop(@ARGV);
my $from = pop(@ARGV);

unless ( $from && $to ) {
    Pod::Usage::pod2usage( -exitstatus => 0, -verbose => 2 );
}

my ( $volume, $binDir, $dir ) = File::Spec->splitpath($to);
my $to_setlib =
  File::Spec->catpath( $volume, File::Spec->catdir( $binDir, $dir ),
    'setlib.cfg' );

( $volume, $binDir, $dir ) = File::Spec->splitpath($from);
my $from_setlib =
  File::Spec->catpath( $volume, File::Spec->catdir( $binDir, $dir ),
    'setlib.cfg' );

unless ( -e $from_setlib ) {
    print STDERR
      "$from_setlib does not specify a valid Foswiki bin directory\n";
    exit 1;
}

unless ( -e $to_setlib ) {
    print STDERR "$to does not specify a valid Foswiki bin directory\n";
    Pod::Usage::pod2usage( -exitstatus => 0, -verbose => 2 );
}

Getopt::Long::GetOptions(
    'iweb=s@'   => \@arg_iweb,
    'xweb=s@'   => \@arg_xweb,
    'mapweb=s@' => \@arg_mapweb,
    'itopic=s@' => \@arg_itopic,
    'xtopic=s@' => \@arg_xtopic,
    'latest=s@' => \@arg_latest,
    'quietly'   => sub { $arg_trace = 0; },
    'trace=o'   => \$arg_trace,
    'deep'      => \$arg_deep,
    'check'     => \$arg_check,
    'help'      => sub {
        Pod::Usage::pod2usage( -exitstatus => 0, -verbose => 2 );
    },
    'version' => sub {
        print $VERSION;
        exit 0;
    }
);

%map_web = map { $_ =~ /^(.*?)=(.*)$/; ( $1 => $2 ) } @arg_mapweb;

announce( ALL, "Running in check mode, no data will be copied" )
  if ($arg_check);
announce( ALL, "iweb: ",   join( ',', @arg_iweb ) )   if scalar(@arg_iweb);
announce( ALL, "xweb: ",   join( ',', @arg_xweb ) )   if scalar(@arg_xweb);
announce( ALL, "itopic: ", join( ',', @arg_itopic ) ) if scalar(@arg_itopic);
announce( ALL, "xtopic: ", join( ',', @arg_xtopic ) ) if scalar(@arg_xtopic);
announce( ALL, "latest: ", join( ',', @arg_latest ) ) if scalar(@arg_latest);
announce( ALL, "mapweb: ",
    join( ',', map { "$_ to $map_web{$_}" } keys %map_web ) )
  if scalar(@arg_mapweb);

# Convert wildcards to regexes
wildcard2regex( \@arg_latest );
wildcard2regex( \@arg_iweb );
wildcard2regex( \@arg_xweb );

pipe( FROM_A, TO_B ) or die "pipe: $!";
pipe( FROM_B, TO_A ) or die "pipe: $!";

# Select autoflush
my $cfh = select(TO_A);
$| = 1;
select(TO_B);
$| = 1;
select($cfh);

if ( my $pid = fork() ) {

    # This is process A, the sender
    close FROM_A;
    close TO_A;

    unshift( @INC, $from );
    require $from_setlib;

    # setlib.cfg declares package Foswiki, so the next line won't fail
    $Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI';
    require Foswiki;
    die $@ if $@;

    if ($Foswiki::UNICODE) {
        set_up_unicode('Sender');
    }
    else {
        set_up_site_charset('Sender');
    }

    $session = Foswiki->new();

    copy_webs();

    $session->finish();

    print TO_B "0\n";

    close FROM_B;
    close TO_B;
    waitpid( $pid, 0 );
}
else {
    # This is process B, the receiver
    die "cannot fork: $!" unless defined $pid;
    close FROM_B;
    close TO_B;

    unshift( @INC, $to );
    require $to_setlib;

    # setlib.cfg declares package Foswiki, so the next line won't fail
    $Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI';
    require Foswiki;

    if ($Foswiki::UNICODE) {
        set_up_unicode('Receiver');
    }
    else {
        set_up_site_charset('Receiver');
    }

    # SMELL: RcsWrap is unable to copy WebPreferences topics.  This
    # topic gets created when the target web is created. RCS "ci"
    # prevents the copy of the actual topic because it would set the
    # timestamp into the past.
    # Error: "..  Date 2010/08/22 12:24:39 precedes 2015/11/10
    # 18:55:55 in revision 1.1"

    if ( $Foswiki::cfg{Store}{Implementation} =~ m/RcsWrap$/ ) {
        announce ALL, "Overriding target Store Implementation to 'RcsLite'";
        $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite';
    }

    $session = Foswiki->new();

    $/ = "\n";
    while ( my $message = <FROM_A> ) {
        last unless dispatch($message);
        $/ = "\n";
    }

    $session->finish();

    close FROM_A;
    close TO_A;
    exit;
}

1;
__END__

=pod

=head1 tools/bulk_copy.pl

Copies all content (topics and attachments), complete with histories,
from one Foswiki installation to another Foswiki installation on the
same machine. The main purpose is to transfer Foswiki database
contents between different store implementations.

It is assumed that:

=over

=item B<1.> Both installations are fully configured Foswiki installs -
    though they don't need to be web-accessible while copying

=item B<2.> You have backed up and protected both installs from
    writing by users and/or cron jobs.

=item B<3.> The user running the script has the access permissions
    necessary for reading/writing data to both installs (recommended
    that you run it as the web user e.g. www-data)

=item B<4.> If the target installation is older than Foswiki 2, then
    any plugins that implement before- or after- Save/Edit handlers
    have been disabled.

=back

The script is a literal copy of topics, attachments and their
histories from one installation to another. No attempt is made to map
users (it is assumed that the same set of users exists in both
stores), and there is no mapping of URLs or other modification of
content.

The script is re-entrant - in the event of it failing to complete you
can restart and it should pick up where it left off.

Note that if the destination store uses a smaller character set than
the the source store (for example, you are trying to copy from a utf-8
store to an iso-8859-1 store) then characters that cannot be
represented in the destination character set will be converted to HTML
entities.

See 'CHANGING STORES' below for more detailed information.

=head1 SYNOPSIS

    perl tools/bulk_copy.pl [options] from-bin to-bin

=over

=item B<from-bin>

path to the bin directory for the source installation.  The
bin/LocalLib.cfg file is used to locate all other components of the
installation.

=item B<to-bin>

path to the bin directory for the target installation.

=back

By default all webs, topics and attachments will be copied.

Note that while all attachments are copied, only attachment revisions
that are explicitly listed in topic revisions are copied. Intermediate
attachment versions that are invisible to Foswiki are not copied. This
may result in the source and destination having different version
histories for attachments.

=head1 OPTIONS

=head2 Selecting Webs and Topics

=over

=item B<--iweb> web

=item B<--xweb> web

    --iweb lets you specify name of a web to copy. Copying a web
    automatically implies copying all its subwebs. If there are no
    --iweb options, then all webs will be copied.

    Alternatively you can use --xweb to specify a web that is *not*
    to be copied.

    You can have as many --iweb and --xweb options as you want,
    and the options support wildcards e.g. --iweb 'Projects/*' will
    process all subwebs of "Projects".

=item B<--itopic> topic

=item B<--xtopic> topic

    --itopic lets you specify the name of a topic within all selected
    webs to copy. Copying a topic automatically implies copying all
    it's attachments. If there are no --topic options, then all topics
    will be copied.

    Alternatively you can use --xtopic to specify a topic
    that is *not* to be copied.

    You can have as many --itopic and --xtopic options as you want,
    and the options support wildcards e.g. --xtopic 'Web*' will skip
    all topics with a name starting with "Web".

=item B<--latest> topic

    Specifies a topic name that will cause the script to transfer
    B<only> the latest rev of that topic, ignoring the history. Only
    attachments present in the latest rev of the topic will be
    transferred. Specify a Web.Topic name - you can use the standard
    file wildcards '*' and '?'.

    You can have as many -latest options as you want. NOTE: to avoid
    excess working, you are recommended to -latest '*.WebStatistics'
    (and any other file that has many auto-generated versions that
    don't really need to be kept.)

=item B<--mapweb> oldweb=newweb

    Copy oldweb to a new web called newweb in the target. This feature
    can be used (for example) to clone a web within a single
    installation.  Note that newweb simply receives the content from
    oldweb. Any pre-existing content in newweb is preserved.

=back

=head2 Miscellaneous

=over

=item B<--check>

    Disables the copy operations and simply runs through the two
    installations looking for cases where a copy is needed.

=item B<--no-deep>

    If no-deep, checks if a web or topic already exists on the target.
    If it does, then the topics in the web, or versions and
    attachments for the topic, will be skipped. This options can
    significantly speed the script up, but is inherently dangerous as
    it risks leaving versions uncopied.

=item B<--trace> bitmask

    Turn on tracing/progress options. Set different bits to enable
    traces:
    bit 0 (1) for web scans,
    bit 1 (2) for topic scans, but not individual versions
    bit 2 (4) for version scans
    bit 3 (8) for copy actions

    thus --trace 9 will trace web scans and copy actions

=item B<--help>

    Outputs this information.

=item B<--version>

    Outputs the version number of this script.

=back

=head1 CHANGING STORES

The main purpose of this script is to support transferring Foswiki
database content between different store implementations. You might
use it when when transferring from an existing RCS-based store to a
new PlainFile based store, for example. We will use the example of
upgrading an existing Foswiki-1.1.9 installation (which uses an RCS
store) to a new Foswiki-2.0.0 installation (which uses PlainFile).

First, set up your two installations, so that they do not share any
data areas. You don't have to make them web-accessible. Let's say they
are in '/var/www/foswiki/Foswiki-1.1.9/bin' and
'/var/www/foswiki/Foswiki-2.0.0/bin'.

Now, decide what webs need to be transferred. As a general guide, you
should *not* copy the System web, otherwise you may overwrite topics
that are shipped with the release. If the System web is not explicitly
listed in the --iwebs option, it will be added to the --xwebs list by
default to avoid possible damage.

You should also add a --latest option to exclude statistics topics.

perl bulk_copy.pl --xweb System --latest '*.WebStatistics' 

Note that only topics and attachments that do not exist in the
destination system can be copied this way. If you want to merge
revisions in different installations together, you will have to do
that manually.

Note that this tool *only* copies topics and attachments that are
visible to the Foswiki Store API. Subdirectories of attachments,
commonly used in the System directory for JavaScript, CSS, and some
image caches, will NOT be copied. If the System web is copied, you may
be left with a non-operational system.
