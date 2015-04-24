#! /usr/bin/env perl
# See bottom of file for license and copyright information
#
# Simple utility to fetch an HTML page from a server
use strict;
use warnings;

use Socket;

if ( !$ARGV[1] ) {
    print "Usage:    geturl [POST] <host> <path> [<port> [<header>]]\n";
    print "Example:  geturl some.domain /some/dir/file.html 80\n";
    print "will get: http://some.domain:80/some/dir/file.html\n\n";
    print
"Example:  geturl POST some.domain /bin/statistics?webs=Sandbox\\&subwebs=1\n";
    print
"will post to the statistics script, requesting a statistics run for Sandbox and all subwebs\n";
    exit 1;
}
my $method = 'GET';
if ( $ARGV[0] eq 'POST' ) {
    $method = shift;
}
my $host    = $ARGV[0];
my $url     = $ARGV[1];
my $content = '';
if ( $method eq 'POST' ) {
    ( $url, $content ) = split( /\?/, $ARGV[1] );
}
$content ||= '';
my $port   = $ARGV[2] || "80";
my $header = $ARGV[3] || "Host: $host";

if ($content) {
    $header .= "\r\nContent-Type: application/x-www-form-urlencoded";
    $header .= "\r\nContent-Length: " . length($content);
}

print getUrl( $host, $port, $url, $header, $content );

# =========================
sub getUrl {
    my ( $theHost, $thePort, $theUrl, $theHeader, $content ) = @_;
    my $result = '';
    my $req =
        "$method $theUrl HTTP/1.0\r\n"
      . "$theHeader\r\n"
      . "User-Agent: Foswiki/geturl.pl\r\n\r\n$content\r\n";
    my ( $iaddr, $paddr, $proto );
    $iaddr = inet_aton($theHost);
    $paddr = sockaddr_in( $thePort, $iaddr );
    $proto = getprotobyname('tcp');
    socket( SOCK, PF_INET, SOCK_STREAM, $proto ) or die "socket: $!";
    connect( SOCK, $paddr ) or die "connect: $!";
    select SOCK;
    $| = 1;
    print SOCK $req;
    while (<SOCK>) { $result .= $_; }
    close(SOCK) or die "close: $!";
    select STDOUT;
    return $result;
}
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999 Jon Udell, BYTE
Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
