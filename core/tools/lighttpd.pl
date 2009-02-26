#!/usr/bin/perl

use strict;
use File::Basename;
use File::Spec;
use Cwd;

# defaults
my $PORT = 8080;

# calculate paths
my $foswiki_core = Cwd::abs_path( File::Spec->catdir( dirname(__FILE__), '..' ) );
chomp $foswiki_core;
my $conffile = $foswiki_core . '/working/tmp/lightpd.conf';

# write configuration file
open(CONF, '>', $conffile) or die("!! Cannot write configuration. Check write permissions to $conffile!");
print CONF "server.document-root = \"$foswiki_core\"\n";
print CONF  <<EOC
server.modules = (
   "mod_rewrite",
   "mod_cgi"
)
server.port = $PORT
include_shell "/usr/share/lighttpd/create-mime.assign.pl"
url.rewrite-repeat = ( "^/?(index.*)?\$" => "/bin/view/Main" )
\$HTTP["url"] =~ "^/bin" { cgi.assign = ( "" => "" ) }
EOC
;;
close(CONF);

# print banner
print "************************************************************\n";
print "Foswiki Development Server\n";
system('/usr/sbin/lighttpd -v 2>/dev/null');
print "Server root: $foswiki_core\n";
print "************************************************************\n";
print "Browse to http://localhost:$PORT/bin/configure to configure your Foswiki\n";
print "Browse to http://localhost:$PORT/bin/view to start testing your Foswiki checkout\n";
print "Hit Control-C at any time to stop\n";
print "************************************************************\n";


# execute lighttpd
system("/usr/sbin/lighttpd -f $conffile -D");

# finalize
system("rm -rf $conffile");
