#! /usr/bin/perl
#
# Author: Crawford Currie http://c-dot.co.uk
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
# any two local Foswiki installations.
#
# The script forks itself to operate as two processes; the "sender", which
# is the source of the topics, and the "receiver", which is the target.
# The processes communicate with eachother through anonymous pipes, using
# JSON encoded messages.
#
# The API used for manipulation is the Foswiki::Meta API. This API
# shelters the script from the details of the store implementation.
#
use strict;
use warnings;

use Getopt::Long ();
use Pod::Usage   ();
use File::Spec   ();
use JSON         ();
use Encode       ();

use version;
our $VERSION = version->declare("v1.0");

our $json = JSON->new->allow_nonref->convert_blessed(1);
our $session;

our %control = (
    iweb       => [], # List of webs to include (empty implies all webs)
    xweb       => [], # List of webs to exclude
    itopic     => [], # List of topics to include (empty implies all topics)
    xtopic     => [], # List of topics to exclude
    latest     => [], # List of topics for which only the latest is to be copied
    quiet      => 0,  # shhhh
    check_only => 0   # If true, don't copy, just check
);

#######################################################################
# Sender

sub announce {
    print shift . "\n"
      unless $control{quiet};
}

# RPC call to a function in the receiver. Scalar parameters are
# unencoded from the site charset. Other parameters are left
# untouched.
sub call {
    my @p = map {
        ref($_)
          ? $_
          : Encode::decode( $Foswiki::cfg{Site}{CharSet} || 'iso-8859-1', $_ )
    } @_;
    my $json_text = $json->encode( \@p );
    print TO_B $json_text . "\n";
    $/ = "\n";
    my $response = <FROM_B>;
    return $json->decode($response);
}

# Copy all matched webs. This is all webs in the install, filtered
# by the command-line options.
sub copy_webs {
    my $rootMO = Foswiki::Meta->new($session);
    my $wit    = $rootMO->eachWeb(1);
    while ( $wit->hasNext() ) {
        my $web = $wit->next();

        # Are we skipping this web?
        if ( grep( /^$web$/, @{ $control{xweb} } ) ) {
            announce "- Skipping xweb $web";
            next;
        }
        my $forced = scalar( @{ $control{iweb} } );
        if ( $forced && !grep( /^$web$/, @{ $control{iweb} } ) ) {
            announce "- Skipping not-iweb $web";
            next;
        }
        my $exists = call( "webExists", $web );
        if ($exists) {
            announce "- Web '$web' already exists in target";
            if ( !$forced ) {
                announce "\t- skipped";
                next;
            }
            announce "\t- will copy missing topics";
        }
        copy_web($web);
    }
}

# Copy all the topics in a web.
sub copy_web {
    my ($web) = @_;

    # Copy the web
    announce "Copying $web";
    my $webMO = Foswiki::Meta->new( $session, $web );

    # saveWeb returns the name of the WebPreferences topic,
    # iff it was created
    my $wpt = call( 'saveWeb', $web );
    my $tit = $webMO->eachTopic();
    while ( $tit->hasNext() ) {
        my $topic = $tit->next();
        if ( grep( /^$topic$/, @{ $control{xtopic} } ) ) {
            announce "- Skipping xtopic $web.$topic";
            next;
        }

        # Always copy WebPreferences topic, if it was just created.
        if ( $topic ne $wpt ) {
            my $forced = scalar( @{ $control{itopic} } );
            if ( $forced
                && !grep( /^$topic$/, @{ $control{itopic} } ) )
            {
                announce "- Skipping not-itopic $web.$topic";
                next;
            }
            my $exists = call( "topicExists", $web, $topic );
            if ($exists) {
                announce "- Topic $web.$topic already exists in target";
                announce "\t- skipped";
                next;
            }
        }
        copy_topic( $web, $topic );
    }
}

# Copy a single topic and all it's attachments.
sub copy_topic {
    my ( $web, $topic ) = @_;

    announce "Copying $web.$topic";
    my $topicMO = Foswiki::Meta->new( $session, $web, $topic );
    my @rev_list = $topicMO->getRevisionHistory()->all();
    if ( grep( /^$topic$/, @{ $control{latest} } ) ) {

        # Only do latest rev
        @rev_list = ( shift @rev_list );
    }
    my %att_tx;

    # Replay history
    while ( my $tv = pop @rev_list ) {

        $topicMO->unload();

        # Work around a bug in 1.1.x RCS stores that causes the head of
        # the history to be loaded for the most recent rev number when
        # an explicit rev number is passed, when in fact we want the
        # (possibly edited) .txt
        $topicMO->loadVersion( scalar(@rev_list) ? $tv : undef );

        # Again this is working around the fact that the RCS stores
        # don't clean up META:TOPICINFO unless it's explicitly asked for
        my $info = $topicMO->getRevisionInfo();
        announce "\tVersion $tv by $info->{author} at "
          . Foswiki::Time::formatTime( $info->{date} );

        # Serialise it
        my $data = $topicMO->getEmbeddedStoreForm();

        #announce "SAVE $data\n";

        # NOTE: this 'trusts' the TOPICINFO that the store
        # embeds in $data, which may not be wise.
        call( 'saveTopicRev', $web, $topic, $data );

        # Transfer attachments. We use eachAttachment rather than
        # META:FILEATTACHMENT because it won't stumble over deleted
        # attachments. An attachment, and its history, can be
        # completely removed from some stores, leaving
        # META:FILEATTACHMENT still in older revs of the topic.
        my $tri;
        my $att_it = $topicMO->eachAttachment();
        while ( $att_it->hasNext() ) {
            my $att_name = $att_it->next();
            my $att_info = $topicMO->get( 'FILEATTACHMENT', $att_name );

            # Is there info about this attachment in this rev of the
            # topic? If not, we can't do anything useful.
            next unless $att_info;
            my $att_version = $att_info->{version};
            unless ( $att_info->{version} ) {
                announce
"- $web.$topic\[$tv\]:$att_name has corrupt FILEATTACHMENT meta-data - cannot copy";
                next;
            }
            next if $att_tx{"$att_name:$att_info->{version}"};
            $att_tx{"$att_name:$att_version"} = 1;
            unless ( $att_info->{author} ) {
                unless ($tri) {
                    $tri = $topicMO->getRevisionInfo();
                }
                $att_info->{author} = $tri->{user};
            }
            my $fh =
              $topicMO->openAttachment( $att_name, '<',
                version => $att_info->{version} );

            # TODO: chunked transfer
            local $/ = undef;
            my $att_data = <$fh>;

            announce "\t\tAttach $att_name\[$att_info->{version}\]";
            call( 'saveAttachmentRev',
                $web, $topic, $att_name, $att_info, \$att_data );
        }
    }
}

#######################################################################
# Receiver

# Dispatch a function call in the receiver
sub dispatch {
    my $json_text = shift;
    my $data      = $json->decode($json_text);

    return 0 unless $data;
    my $fn = shift(@$data);
    my @p  = map {
        ref($_)
          ? $_
          : Encode::encode( $Foswiki::cfg{Site}{CharSet} || 'iso-8859-1',
            $_, Encode::FB_HTMLCREF )
    } @$data;
    no strict 'refs';
    my $response = &$fn(@p);
    use strict 'refs';
    $response = 0 unless defined $response;

    #print STDERR "$fn(".join(',', @$data).") -> $response\n";
    print TO_A $json->encode($response) . "\n";
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

# Create a new web iff it doesn't already exist. If it is created, return
# the name of the WebPreferences topic (this is used by some stores to
# identify a web)
sub saveWeb {
    my $web = shift;
    return '' if $session->webExists($web);
    my $mo = Foswiki::Meta->new( $session, $web );
    return 0 if $control{check};
    $mo->populateNewWeb();

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

#announce "SAVE $web.$topic author $info->{author} rev $info->{version}\n$data\n";
    return 0 if $control{check};

    # When saving over existing revs of a topic, must make sure we
    # fully delete the existing data
    if ( $session->topicExists( $web, $topic ) ) {
        my $demo = Foswiki::Meta->new( $session, $web, $topic );
        $demo->removeFromStore();

        $mo = Foswiki::Meta->new( $session, $web, $topic );
        $mo->setEmbeddedStoreForm($data);

        $info = $mo->get('TOPICINFO');
    }

    $mo->save(
        author           => $info->{author},
        forcenewrevision => 1,
        forcedate        => $info->{date},
        dontlog          => 1,
        minor            => 1,

        # Don't call handlers (1.2+ only)
        nohandlers => 1
    );
}

# Given revision info and data for the attachment
# save this rev.
sub saveAttachmentRev {
    my ( $web, $topic, $attachment, $info, $data ) = @_;
    my $mo = Foswiki::Meta->new( $session, $web, $topic );
    my $fh;
    open( $fh, '<', $data );    # Open string for input
    return 0 if $control{check};
    $mo->attach(
        name          => $attachment,
        dontlog       => 1,
        notopicchange => 1,
        author        => _encode( $info->{author} ),
        filedate      => $info->{date},
        forcedate     => $info->{date},
        stream        => $fh,

        # Don't call handlers (1.2+ only)
        nohandlers => 1
    );
}

#######################################################################
# Main Program

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
    'iweb=s@'   => $control{iweb},
    'xweb=s@'   => $control{xweb},
    'itopic=s@' => $control{itopic},
    'xtopic=s@' => $control{xtopic},
    'latest=s@' => $control{latest},
    'quietly'   => sub { $control{quiet} = 1 },
    'check'     => sub { $control{check_only} = 1 },
    'help'      => sub {
        Pod::Usage::pod2usage( -exitstatus => 0, -verbose => 2 );
    },
    'version' => sub {
        print $VERSION;
        exit 0;
    }
);

announce "iweb: " . join( ',', @{ $control{iweb} } )
  if ( scalar( @{ $control{iweb} } ) );
announce "xweb: " . join( ',', @{ $control{xweb} } )
  if ( scalar( @{ $control{xweb} } ) );
announce "itopic: " . join( ',', @{ $control{itopic} } )
  if ( scalar( @{ $control{itopic} } ) );
announce "xtopic: " . join( ',', @{ $control{xtopic} } )
  if ( scalar( @{ $control{xtopic} } ) );
announce "latest: " . join( ',', @{ $control{latest} } )
  if ( scalar( @{ $control{latest} } ) );

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

    announce
      "Copying from $Foswiki::VERSION ($Foswiki::cfg{Store}{Implementation})";

    $session = Foswiki->new();

    copy_webs();

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

    announce
      "Copying to $Foswiki::VERSION ($Foswiki::cfg{Store}{Implementation})";

    $session = Foswiki->new();

    $/ = "\n";
    while ( my $message = <FROM_A> ) {
        last unless dispatch($message);
        $/ = "\n";
    }

    close FROM_A;
    close TO_A;
    exit;
}

1;
__END__

=head1 tools/bulk_copy.pl

Shell script to copy all content (topics and attachments), complete with
histories, from one local installation to another local installation.

It is assumed that:

=over

=item B<1.> Both installations are fully
    configured Foswiki installs - though they don't need to be web-accessible
    while copying

=item B<2.> You have backed up and protected both installs from
    writing by users and/or cron jobs.

=item B<3.> The user running the script has the access permissions
    necessary for reading/writing data to both installs (recommended that you
    run it as the web user e.g. www-data)

=item B<4.> If the target installation is older than 1.2, then any plugins
    that implement before- or after Save/Edit handlers have been disabled.

=back

The script is a literal copy of topics, attachments and their histories
from one installation to another. No attempt is made to map users (it is
assumed that the same set of users exists in both stores), and there is
no mapping of URLs or other modification of content. The two installations
may use different store implementations (in fact, this is one of the main
motivators for this script!)

=head1 SYNOPSIS

    perl tools/bulk_copy.pl [options] from-bin to-bin

=over

=item B<from-bin>

path to the bin directory for the source installation.
The bin/LocalLib.cfg file is used to locate all other components of the
installation.

=item B<to-bin>

path to the bin directory for the target installation.

=back

By default all webs, topics and attachments will be copied. Where a
topic or attachment already exists in the target installation, it will
be reported but not copied.

=head1 OPTIONS

=head2 Selecting Webs and Topics

=item B<--iweb> web

=item B<--xweb> web

    --iweb lets you specify name of a web to copy. Copying a web
    automatically implies copying all its subwebs. If there are no
    --iweb options, then all webs will be copied.

    Alternatively you can use --xweb to specify a web that is *not*
    to be copied.

    You can have as many B<--web> and B<--xweb> options as you want.

=item B<--itopic> topic

=item B<--xtopic> topic

    --itopic lets you specify the name of a topic within all selected
    webs to copy. Copying a topic automatically implies copying all it's
    attachments. If there are no --topic options, then all topics
    will be copied.

    Alternatively you can use --xtopic to specify a topic
    that is *not* to be copied.

    You can have as many --topic and --xtopic options as you want.

=item B<--latest> topic

    Specifies a topic name that will cause the script to transfer
    only the latest rev of that topic, ignoring the history. Only
    attachments present in the latest rev of the topic will be
    transferred. Simple topic name, does not support web specifiers.
    You can have as many -latest options as you want. NOTE: to avoid
    excess working, you are recommended to -latest WebStatistics (and
    any other file that has many auto-generated versions that don't
    really need to be kept)

=head2 Miscellaneous

=item B<--quietly>

    Run quietly, without printing progress messages

=item B<--check>

    Disables the copy operations and simply runs through the two
    installations looking for cases where a topic or attachment already
    exists in both.

=item B<--help>

    Outputs this information.

=item B<--version>

    Outputs the version number of this script.

=back
