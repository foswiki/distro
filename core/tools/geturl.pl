#!/usr/bin/perl -w
#
# Simple utility to fetch an HTML page from a server
# (Utility for Foswiki - The Free and Open Source Wiki, http://foswiki.org/)
#
# Copyright (C) 1999 Jon Udell, BYTE
# Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
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

use Socket;

if( ! $ARGV[1] ) {
    print "Usage:    geturl <host> <path> [<port> [<header>]]\n";
    print "Example:  geturl some.domain /some/dir/file.html 80\n";
    print "will get: http://some.domain:80/some/dir/file.html\n";
    exit 1;
}
my $host   = $ARGV[0];
my $url    = $ARGV[1];
my $port   = $ARGV[2] || "80";
my $header = $ARGV[3] || "Host: $host";
print getUrl( $host, $port, $url, $header );

# =========================
sub getUrl
{
    my ( $theHost, $thePort, $theUrl, $theHeader ) = @_;
    my $result = '';
    my $req = "GET $theUrl HTTP/1.0\r\n$theHeader\r\nUser-Agent: TWikigeturl.pl\r\n\r\n"; 
    my ( $iaddr, $paddr, $proto );
    $iaddr   = inet_aton( $theHost );
    $paddr   = sockaddr_in( $thePort, $iaddr );
    $proto   = getprotobyname( 'tcp' );
    socket( SOCK, PF_INET, SOCK_STREAM, $proto )  or die "socket: $!";
    connect( SOCK, $paddr ) or die "connect: $!";
    select SOCK; $| = 1;
    print SOCK $req;
    while( <SOCK> ) { $result .= $_; }
    close( SOCK )  or die "close: $!";
    select STDOUT;
    return $result;
}
