package RequestCacheTests;

use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use utf8;
use Foswiki::Request;
use Foswiki::Request::Cache;
use File::Temp;
my %tempFileOptions = ( UNLINK => 0 );
if ( $^O eq 'MSWin32' ) {

    #on windows, don't make a big old mess of c:\

    $ENV{TEMP} =~ m/(.*)/;
    $tempFileOptions{DIR} = $1;
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Test that simple parameters are cached
# SMELL:  Item8937:   This test is failing because action has been deleted
# from the cache.  Need someone else to verify that the fix to Item8937 is correct
# before removing action from the unit test.
sub test_simpleparams {
    my $this = shift;
    my %init = (
        simple      => 's1',
        simple2     => ['s2'],
        multi       => [qw(m1 m2)],
        'undef'     => undef,
        multi_undef => [],
    );
    my $req = new Foswiki::Request( \%init );
    $req->method("BURP");
    $req->path_info("/bad/wolf");
    $req->action("puke");
    my $cache = new Foswiki::Request::Cache();
    my $uid   = $cache->save($req);
    $this->assert($uid);
    $req = new Foswiki::Request('');
    $cache->load( $uid, $req );
    my @values = $req->multi_param('multi');
    $this->assert_str_equals( 2,    scalar @values, 'Wrong number of values' );
    $this->assert_str_equals( 'm1', $values[0],     'Wrong parameter value' );
    $this->assert_str_equals( 'm2', $values[1],     'Wrong parameter value' );

    # Item12956: undef parameters are written out as "empty".
    $this->assert_str_equals(
        '',
        scalar $req->param('undef'),
        'Wrong parameter value'
    );
    @values = $req->multi_param('multi_undef');
    $this->assert_str_equals( 0, scalar @values, 'Wrong parameter value' );
    $this->assert_str_equals( "BURP",      $req->method() );
    $this->assert_str_equals( "/bad/wolf", $req->path_info() );
    $this->assert_str_equals( "puke",      $req->action() );
}

# Test that utf8 parameters are cached
sub test_simpleparams_utf8 {
    my $this = shift;
    my %init = (
        'posvětit'  => 'vústěnív',
        'vústění' => ['měnívat'],
        multi        => [qw(vú mě)],
        'undef'      => undef,
        multi_undef  => [],
    );

    #my $pathinfo = Foswiki::urlEncode("/vústění/posvětit");
    my $pathinfo = Encode::encode_utf8("/vústění/posvětit");
    my $req      = new Foswiki::Request( \%init );
    $req->method("BURP");
    $req->path_info($pathinfo);
    $req->action("puke");
    my $cache = new Foswiki::Request::Cache();
    my $uid   = $cache->save($req);
    $this->assert($uid);
    $req = new Foswiki::Request('');
    $cache->load( $uid, $req );
    my @values = $req->multi_param('multi');
    $this->assert_str_equals( 2,     scalar @values, 'Wrong number of values' );
    $this->assert_str_equals( 'vú', $values[0],     'Wrong parameter value' );
    $this->assert_str_equals( 'mě', $values[1],     'Wrong parameter value' );

    # Item12956: undef parameters are written out as "empty".
    $this->assert_str_equals(
        '',
        scalar $req->param('undef'),
        'Wrong parameter value'
    );
    @values = $req->multi_param('multi_undef');
    $this->assert_str_equals( 0, scalar @values, 'Wrong parameter value' );
    $this->assert_str_equals( "BURP",    $req->method() );
    $this->assert_str_equals( $pathinfo, $req->path_info() );
    $this->assert_str_equals( "puke",    $req->action() );
}

# Test that file uploads are cached
# Item12367: make sure that a filename containing RFC 3986 reserved characters
# works ('%' must be reserved by all implementations of percent encoding,
# obviously)
sub test_upload {
    my $this = shift;
    my $req  = new Foswiki::Request("");

    my $tmp = File::Temp->new(%tempFileOptions);
    print $tmp "XXX";
    $tmp->close();
    my ( %uploads, %headers ) = ();
    %headers = (
        'Content-Type'        => 'text/plain',
        'Content-Disposition' => 'form-data; name="file"; filename="Temp%.txt"'
    );
    $req->param( file => "Temp%.txt" );
    $uploads{"Temp%.txt"} = new Foswiki::Request::Upload(
        headers => {%headers},
        tmpname => $tmp->filename,
    );
    $req->uploads( \%uploads );

    my $cache = new Foswiki::Request::Cache();
    my $uid   = $cache->save($req);
    $this->assert($uid);
    $req = new Foswiki::Request('');
    $cache->load( $uid, $req );

    my $uploads = $req->uploads();
    $this->assert_equals( 1, scalar keys %$uploads );
    open( F, '<', $tmp->filename );
    local $/;
    my $data = <F>;
    $this->assert_str_equals( "XXX", $data );
    close(F);
}

sub test_expire {
    my $this = shift;
    my %init = (
        simple      => 's1',
        simple2     => ['s2'],
        multi       => [qw(m1 m2)],
        'undef'     => undef,
        multi_undef => [],
    );
    my $req = new Foswiki::Request( \%init );
    my $tmp = File::Temp->new(%tempFileOptions);
    print $tmp "XXX";
    $tmp->close();
    my ( %uploads, %headers ) = ();
    %headers = (
        'Content-Type'        => 'text/plain',
        'Content-Disposition' => 'form-data; name="file"; filename="Temp.txt"'
    );
    $req->param( file => "Temp.txt" );
    $uploads{"Temp.txt"} = new Foswiki::Request::Upload(
        headers => {%headers},
        tmpname => $tmp->filename,
    );
    $req->uploads( \%uploads );
    my $cache = new Foswiki::Request::Cache();
    my $uid   = $cache->save($req);

    $this->assert( -e "$Foswiki::cfg{WorkingDir}/tmp/passthru_${uid}" );
    $this->assert(
        -e "$Foswiki::cfg{WorkingDir}/tmp/passthru_${uid}_info_Temp.txt" );
    $this->assert(
        -e "$Foswiki::cfg{WorkingDir}/tmp/passthru_${uid}_data_Temp.txt" );
    sleep(2);

    # expire
    Foswiki::Request::Cache::cleanup(1);

    $this->assert( !-e "$Foswiki::cfg{WorkingDir}/tmp/passthru_${uid}" );
    $this->assert(
        !-e "$Foswiki::cfg{WorkingDir}/tmp/passthru_${uid}_info_Temp.txt" );
    $this->assert(
        !-e "$Foswiki::cfg{WorkingDir}/tmp/passthru_${uid}_data_Temp.txt" );

}

1;
