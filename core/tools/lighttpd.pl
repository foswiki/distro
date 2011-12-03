#!/usr/bin/perl

use strict;
use File::Basename;
use File::Spec;
use Cwd;
use Getopt::Long;
use Pod::Usage;

# defaults
my $__fastcgi = undef;
my $__help    = undef;
my $__port    = 8080;

GetOptions(
    'fastcgi|f' => \$__fastcgi,
    'help|h'    => \$__help,
    'port|p=i'  => \$__port,
);
pod2usage(1) if $__help;

# calculate paths
my $foswiki_core =
  Cwd::abs_path( File::Spec->catdir( dirname(__FILE__), '..' ) );
chomp $foswiki_core;
my $conffile = $foswiki_core . '/working/tmp/lighttpd.conf';

my $mime_mapping = q(include_shell "/usr/share/lighttpd/create-mime.assign.pl");
if ( !-e "/usr/share/lighttpd/create-mime.assign.pl" ) {
    $mime_mapping = q(mimetype.assign             = \(
  ".rpm"          =>      "application/x-rpm",
  ".pdf"          =>      "application/pdf",
  ".sig"          =>      "application/pgp-signature",
  ".spl"          =>      "application/futuresplash",
  ".class"        =>      "application/octet-stream",
  ".ps"           =>      "application/postscript",
  ".torrent"      =>      "application/x-bittorrent",
  ".dvi"          =>      "application/x-dvi",
  ".gz"           =>      "application/x-gzip",
  ".pac"          =>      "application/x-ns-proxy-autoconfig",
  ".swf"          =>      "application/x-shockwave-flash",
  ".tar.gz"       =>      "application/x-tgz",
  ".tgz"          =>      "application/x-tgz",
  ".tar"          =>      "application/x-tar",
  ".zip"          =>      "application/zip",
  ".mp3"          =>      "audio/mpeg",
  ".m3u"          =>      "audio/x-mpegurl",
  ".wma"          =>      "audio/x-ms-wma",
  ".wax"          =>      "audio/x-ms-wax",
  ".ogg"          =>      "application/ogg",
  ".wav"          =>      "audio/x-wav",
  ".gif"          =>      "image/gif",
  ".jar"          =>      "application/x-java-archive",
  ".jpg"          =>      "image/jpeg",
  ".jpeg"         =>      "image/jpeg",
  ".png"          =>      "image/png",
  ".xbm"          =>      "image/x-xbitmap",
  ".xpm"          =>      "image/x-xpixmap",
  ".xwd"          =>      "image/x-xwindowdump",
  ".css"          =>      "text/css",
  ".html"         =>      "text/html",
  ".htm"          =>      "text/html",
  ".js"           =>      "text/javascript",
  ".asc"          =>      "text/plain",
  ".c"            =>      "text/plain",
  ".cpp"          =>      "text/plain",
  ".log"          =>      "text/plain",
  ".conf"         =>      "text/plain",
  ".text"         =>      "text/plain",
  ".txt"          =>      "text/plain",
  ".dtd"          =>      "text/xml",
  ".xml"          =>      "text/xml",
  ".mpeg"         =>      "video/mpeg",
  ".mpg"          =>      "video/mpeg",
  ".mov"          =>      "video/quicktime",
  ".qt"           =>      "video/quicktime",
  ".avi"          =>      "video/x-msvideo",
  ".asf"          =>      "video/x-ms-asf",
  ".asx"          =>      "video/x-ms-asf",
  ".wmv"          =>      "video/x-ms-wmv",
  ".bz2"          =>      "application/x-bzip",
  ".tbz"          =>      "application/x-bzip-compressed-tar",
  ".tar.bz2"      =>      "application/x-bzip-compressed-tar",
  # default mime type
  ""              =>      "application/octet-stream",
  \));
}

# write configuration file
open( CONF, '>', $conffile )
  or
  die("!! Cannot write configuration. Check write permissions to $conffile!");
print CONF "server.document-root = \"$foswiki_core\"\n";
print CONF <<EOC
server.modules = (
   "mod_rewrite",
   "mod_alias",
   "mod_cgi",
   "mod_fastcgi"
)
server.port = $__port

# ipv6 support
\$SERVER["socket"] == "[::]:$__port" { }

server.errorlog = "$foswiki_core/working/tmp/error.log"

# mimetype mapping
$mime_mapping

url.rewrite-repeat = ( "^/?(index.*)?\$" => "/bin/view/Main" )
EOC
  ;

if ($__fastcgi) {
    print CONF "
\$HTTP[\"url\"] =~ \"^/bin/\" {
    alias.url += ( \"/bin\" => \"$foswiki_core/bin/foswiki.fcgi\" )
    fastcgi.server = ( \".fcgi\" => (
         (
            \"socket\"    => \"$foswiki_core/working/tmp/foswiki.sock\",
            \"bin-path\"  => \"$foswiki_core/bin/foswiki.fcgi\",
            \"max-procs\" => 1
         ),
      )
    )
}
  ";

    # the configure script must always be run as CGI
    print CONF "
\$HTTP[\"url\"] =~ \"^/bin/configure\" {
    alias.url += ( \"/bin/configure\" => \"$foswiki_core/bin/configure\" )
    cgi.assign = ( \"\" => \"\" )
}
  ";
}
else {
    print CONF '$HTTP["url"] =~ "^/bin" { cgi.assign = ( "" => "" ) }', "\n";
}

close(CONF);

# print banner
print "************************************************************\n";
print "Foswiki Development Server\n";
system('lighttpd -v 2>/dev/null');
print "Server root: $foswiki_core\n";
print "************************************************************\n";
print
"Browse to http://localhost:$__port/bin/configure to configure your Foswiki\n";
print
"Browse to http://localhost:$__port/bin/view to start testing your Foswiki checkout\n";
print "Hit Control-C at any time to stop\n";
print "************************************************************\n";

# execute lighttpd
system("lighttpd -f $conffile -D");

# finalize
system("rm -rf $conffile");

__END__

=head1 SYNOPSIS

lightpd.pl [options]

    Runs Foswiki with lighttpd.

    Options:
        -f --fastcgi               Use FastCGI instead of plain CGI
        -h --help                  Displays this help and exits
        -p PORT, --port PORT       Runs the server in the given port.
                                   (default: 8080)

