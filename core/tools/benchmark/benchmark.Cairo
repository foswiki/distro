#!/usr/bin/perl -w
use Benchmark qw(:all :hireswallclock);
use vars qw( $begin );
BEGIN { $begin = new Benchmark; }
END{ print STDERR "\nTotal " . timestr(timediff(new Benchmark, $begin))."\n"; }

BEGIN {
    # Set default current working directory (needed for mod_perl)
    if( $ENV{"SCRIPT_FILENAME"} && $ENV{"SCRIPT_FILENAME"} =~ /^(.+)\/[^\/]+$/ ) {
        chdir $1;
    }
    # Set library paths in @INC, at compile time
    unshift @INC, '.';
    require 'setlib.cfg';
}

use strict;
use CGI::Carp qw( fatalsToBrowser );
use CGI;

use Data::Dumper;

my $query;
my $thePathInfo;
my $theRemoteUser;
my $theUrl;
if( $ENV{'DOCUMENT_ROOT'} ) {
    # script is called by browser
    $query = new CGI;
    $thePathInfo = $query->path_info(); 
    $theRemoteUser = $query->remote_user();
    $theUrl = $query->url;

    open(OF,'>/tmp/twiki_bm.cgi') || die "Store failed";
    print OF Dumper(\$query, $thePathInfo, $theRemoteUser, $theUrl);
    close(OF);
    `chmod 777 /tmp/twiki_bm.cgi`
} else {
    open(IF, "</tmp/twiki_bm.cgi")  || die "Retrieve failed";
    undef $/;
    my $blah = <IF>;
    close(IF);
    my ( $VAR1, $VAR2, $VAR3, $VAR4 );
    eval $blah;
    ( $query, $thePathInfo, $theRemoteUser, $theUrl ) =
      ( $$VAR1, $VAR2, $VAR3, $VAR4 )
}

use TWiki::UI::View;

my $theTopic = $query->param( 'topic' );

my( $topic, $webName, $scriptUrlPath, $userName ) = 
  TWiki::initialize( $thePathInfo, $theRemoteUser,
                     $theTopic, $theUrl, $query );

TWiki::UI::View::view( $webName, $topic, $userName, $query );

