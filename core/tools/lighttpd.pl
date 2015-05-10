#! /usr/bin/env perl

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
my $__server  = 'lighttpd';

GetOptions(
    'fastcgi|f'  => \$__fastcgi,
    'help|h'     => \$__help,
    'port|p=i'   => \$__port,
    'server|s=s' => \$__server,
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

use Data::Dumper;
print STDERR Data::Dumper::Dumper( \%ENV );

# write configuration file
open( CONF, '>', $conffile )
  or
  die("!! Cannot write configuration. Check write permissions to $conffile!");
print CONF "server.document-root = \"$foswiki_core\"\n";
print CONF <<EOC
server.modules = (
   "mod_rewrite",
   "mod_alias",
   "mod_setenv",
   "mod_cgi",
   "mod_fastcgi"
)
server.port = $__port

# ipv6 support
\$SERVER["socket"] == "[::]:$__port" { }

server.errorlog = "$foswiki_core/working/logs/lighttpd.error.log"

# mimetype mapping
$mime_mapping

# SMELL: lighttpd on case insensitive file systems converts PATH_INFO to Lower Case!
server.force-lowercase-filenames = "disable"

# Set the ENV variable for the path.
setenv.add-environment = ("PATH" => env.PATH )

# request debugging - UNCOMMENT TO ENABLE
#debug.log-request-handling = "enable"

# default landing page
 url.rewrite-once = ( "^/?(index.*)?\$" => "/bin/view/Main/WebHome" )

# short urls
 url.rewrite-once += ( "^/([A-Z_].*)" => "/bin/view/\$1" )

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
}
else {
    print CONF '$HTTP["url"] =~ "^/bin" { cgi.assign = ( "" => "' . $^X
      . '" ) }', "\n";
}

close(CONF);

# print banner
print "************************************************************\n";
print "Foswiki Development Server\n";
system("$__server -v 2>/dev/null");
if ( $? == -1 ) {
    print "failed to execute: $!\n";
    exit;
}
elsif ( $? & 127 ) {
    printf "child died with signal %d, %s coredump\n",
      ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
    exit;
}
else {
    my $ex = $? >> 8;
    unless ( $ex == 0 ) {
        printf "lighttpd exited with value %d\n", $ex;
        print
"Is lighttpd on the path.  Use -s option to specify lighttpd location.\n";
        pod2usage(1);
        exit;
    }
}
print "Server root: $foswiki_core\n";
print "************************************************************\n";
print
"Browse to http://localhost:$__port/ to start testing your Foswiki checkout\n";
print "Hit Control-C at any time to stop\n";
print "************************************************************\n";
print " - Config file $conffile\n";

# execute lighttpd
system("$__server -f $conffile -D");
if ( $? == -1 ) {
    print "failed to execute: $!\n";
    exit;
}
elsif ( $? & 127 ) {
    printf "child died with signal %d, %s coredump\n",
      ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
    exit;
}
else {
    my $ex = $? >> 8;
    printf "lighttpd exited with value %d\n", $ex;
    print "Is the FastCGIEngineContrib installed?\n"
      if ( $ex == 255 );
}

# finalize
print "Removing config file $conffile\n";
system("rm -rf $conffile");

__END__

=head1 SYNOPSIS

lightpd.pl [options]

    Runs Foswiki with lighttpd.

    Options:
        -f --fastcgi                 Use FastCGI instead of plain CGI
        -h --help                    Displays this help and exits
        -p PORT, --port PORT         Runs the server in the given port.
                                     (default: 8080)
        -s /path/to/lighttpd ,
        --server /path/to/lighttpd   Location to lighttpd if not on path
                                     (default: lighttpd)

    If lighttpd is not found on the default path, provide the complete path
    to the server   eg.
        lighttpd.pl --fastcgi --server /usr/sbin/lighttpd
