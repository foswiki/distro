#
# Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2010 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Contrib::Build;

use strict;

=begin TML

#HistoryTarget
Updates the history in the plugin/contrib topic from the subversion checkin history.
   * Requires a line like | Change History:| NNNN: descr | in the topic, where NNN is an SVN rev no and descr is the description of the checkin.
   * Automatically changes ItemNNNN references to links to the bugs web.
   * Must be run in a subversion checkout area!
This target works in the current checkout area; it still requires a checkin of the updated plugin. Note that history items checked in against Item000 are *ignored* (not included in the history).

=cut

sub target_history {
    my $this = shift;

    my $f = $this->{basedir} . '/' . $this->{topic_root} . '.txt';

    my $cmd = "cd $this->{basedir} && svn status";
    warn "Checking status using $cmd\n";
    my $log = join( "\n", grep { !/^\?/ } split( /\n/, `$cmd` ) );
    warn "WARNING:\n$log\n" if $log;

    open( IN, '<', $f ) or die "Could not open $f: $!";

    # find the table
    my $in_history = 0;
    my @history;
    my $pre = '';
    my $post;
    local $/ = "\n";
    while ( my $line = <IN> ) {
        if ( $line =~
            /^\s*\|\s*Change(?:\s+|&nbsp;)History:.*?\|\s*(.*?)\s*\|\s*$/i )
        {
            $in_history = 1;
            push( @history, [ "?1'$1'", $1 ] ) if ( $1 && $1 !~ /^\s*$/ );
        }
        elsif ($in_history) {

            # | NNNN | desc |
            if ( $line =~ /^\s*\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*$/ ) {
                push( @history, [ $1, $2 ] );
            }

            # | date | desc |
            elsif ( $line =~
                /^\s*\|\s*(\d+[-\s\/]+\w+[-\s+\/]\d+)\s*\|\s*(.*?)\s*\|\s*$/ )
            {
                push( @history, [ $1, $2 ] );
            }

            # | verno | desc |
            elsif ( $line =~ /^\s*\|\s*([\d.]+)\s*\|\s*(.*?)\s*\|\s*$/ ) {
                push( @history, [ $1, $2 ] );
            }

            # | | date: desc |
            elsif (
                $line =~ /^\s*\|\s*\|\s*(\d+\s+\w+\s+\d+):\s*(.*?)\s*\|\s*$/ )
            {
                push( @history, [ $1 . $2 ] );
            }

            # | | verno: desc |
            elsif ( $line =~ /^\s*\|\s*\|\s*([\d.]+):\s*(.*?)\s*\|\s*$/ ) {
                push( @history, [ $1, $2 ] );
            }

            # | | desc |
            elsif ( $line =~ /^\s*\|\s*\|\s*(.*?)\s*\|\s*$/ ) {
                push( @history, [ "?" . $1 ] );
            }

            else {
                $post = $line;
                last;
            }
        }
        else {
            $pre .= $line;
        }
    }
    die "No | Change History: | ... | found" unless $in_history;
    $/ = undef;
    $post .= <IN>;
    close(IN);

    # Determine the most recent history item
    my $base = 0;
    if ( scalar(@history) && $history[0]->[0] =~ /^(\d+)$/ ) {
        $base = $1;
    }
    warn "Refreshing history since $base\n";
    $cmd = "cd $this->{basedir} && svn info -R";
    warn "Recovering version info using $cmd...\n";
    $log = `$cmd`;

    # find files with revs more recent than $base
    my $curpath;
    my @revs;
    foreach my $line ( split( /\n/, $log ) ) {
        if ( $line =~ /^Path: (.*)$/ ) {
            $curpath = $1;
        }
        elsif ( $line =~ /^Last Changed Rev: (.*)$/ ) {
            die unless $curpath;
            if ( $1 > $base ) {
                warn "$curpath $1 > $base\n";
                push( @revs, $curpath );
            }
            $curpath = undef;
        }
    }

    unless ( scalar(@revs) ) {
        warn "History is up to date with svn log\n";
        return;
    }

    # Update the history
    $cmd = "cd $this->{basedir} && svn log " . join( ' && svn log ', @revs );
    warn "Updating history using $cmd...\n";
    $log = `$cmd`;
    my %new;
    foreach my $line ( split( /^----+\s*/m, $log ) ) {
        if ( $line =~
            /^r(\d+)\s*\|\s*(\w+)\s*\|\s*.*?\((.+?)\)\s*\|.*?\n\s*(.+?)\s*$/ )
        {

            # Ignore the history item we already have
            next if $1 == $base;
            my $rev = $1;
            next if $rev <= $base;
            my $when = "$2 $3 ";
            my $mess = $4;

            # Ignore Item000: checkins
            next if $mess =~ /^Item0+:/;
            $mess =~ s/</&lt;/g;
            $mess =~ s/\|/!/g;
            $mess =~ s#(?<!Foswikitask:)\bItem(\d+):#Foswikitask:Item$1:#gm;
            $mess =~ s/\r?\n/ /g;
            $new{$rev} = [ $rev, $mess ];
        }
    }
    unshift( @history, map { $new{$_} } sort { $b <=> $a } keys(%new) );
    print "| Change&nbsp;History: | |\n";
    print join( "\n", map { "|  $_->[0] | $_->[1] |" } @history );
}

1;
