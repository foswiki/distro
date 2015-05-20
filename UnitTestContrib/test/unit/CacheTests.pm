package CacheTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use File::Spec();
use Foswiki::OopsException();
use Foswiki::PageCache();
use Error qw( :try );
use Benchmark qw(:hireswallclock);

my $UI_FN;

sub fixture_groups {
    my $this = shift;
    my @page;

    foreach my $dir (@INC) {
        my $d = File::Spec->catdir( $dir, 'Foswiki', 'PageCache', 'DBI' );
        if ( opendir( my $D, $d ) ) {
            foreach my $alg ( readdir $D ) {
                next if $alg =~ /^\./;
                next unless $alg =~ /^(.*)\.pm$/;
                $alg = $1;
                next if ( grep { $_ eq $alg } @page );
                if ( defined &{$alg} ) {
                    push( @page, $alg );
                    next;
                }

                if ( eval "require Foswiki::PageCache::DBI::$alg; 1;" ) {
                    no strict 'refs';
                    *{$alg} = sub {
                        my $this = shift;
                        $Foswiki::cfg{CacheManager} =
                          'Foswiki::PageCache::' . $alg;
                    };
                    use strict 'refs';
                    push( @page, $alg );
                }
                else {
                    print STDERR
"Cannot test Foswiki::PageCache::$alg\nCompilation error when trying to 'require' it\n $@";
                }
            }
            closedir($D);
        }
    }

    return ( \@page, [ 'view', 'rest' ], [ 'NoCompress', 'Compress' ] );
}

sub SQLite {
    require Foswiki::PageCache::DBI::SQLite;
    die $@ if $@;
    $Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::SQLite';
    $Foswiki::cfg{Cache}{DBI}{SQLite}{Filename} =
      "$Foswiki::cfg{WorkingDir}/${$}_sqlite.db";
    $Foswiki::cfg{Cache}{Enabled} = 1;
}

sub PostgreSQL {
    require Foswiki::PageCache::DBI::PostgreSQL;
    die $@ if $@;
    $Foswiki::cfg{Cache}{Implementation} =
      'Foswiki::PageCache::DBI::PostgreSQL';
    $Foswiki::cfg{Cache}{Enabled} = 1;
}

sub MySQL {
    require Foswiki::PageCache::DBI::MySQL;
    $Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::MySQL';
    $Foswiki::cfg{Cache}{Enabled}        = 1;
}

sub Generic {
    $Foswiki::cfg{Cache}{DSN} =
      "dbi:SQLite:dbname=$Foswiki::cfg{WorkingDir}/${$}_generic.db";
    require Foswiki::PageCache::DBI::Generic;
    $Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::Generic';
    $Foswiki::cfg{Cache}{Enabled}        = 1;
}

sub Compress {
    $Foswiki::cfg{HttpCompress} = 1;
    $Foswiki::cfg{Cache}{Compress} = 1;

    return;
}

sub NoCompress {
    $Foswiki::cfg{HttpCompress} = 0;
    $Foswiki::cfg{Cache}{Compress} = 0;

    return;
}

sub view {
    my $this = shift;
    $this->{uifn} = 'view';
}

sub rest {
    my $this = shift;
    $this->{uifn} = 'rest';
}

my %twistyIDs;

# Convert the random IDs into sequential ones, so that we have some hope of
# writing repeatable tests.
sub _mangleID {
    my ($id) = @_;
    my $mangledID = $twistyIDs{$id};

    if ( not defined $mangledID ) {
        $mangledID = scalar( keys(%twistyIDs) ) + 1;
        $twistyIDs{$id} = $mangledID;
    }

    return $mangledID;
}

sub set_up {
    my $this = shift;
    $Foswiki::cfg{Cache}{Enabled} = 0;
    $this->SUPER::set_up();

    $Foswiki::cfg{HttpCompress} = 0;
    $Foswiki::cfg{Cache}{Compress} = 0;
    $UI_FN ||= $this->getUIFn('view');

    return;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    unlink("$Foswiki::cfg{WorkingDir}/${$}_sqlite.db");
    unlink("$Foswiki::cfg{WorkingDir}/${$}_generic.db");
}

sub check {
    my ( $this, $pathinfo ) = @_;

    $UI_FN ||= $this->getUIFn( $this->{uifn} );
    $Foswiki::cfg{Cache}{Debug} = 1;
    my $query = Unit::Request->new( { skin => ['none'], } );
    $query->path_info($pathinfo);
    $query->method('GET');

    $this->createNewFoswikiSession( $this->{test_user_login},
        $query, { $this->{uifn} => 1 } );

    # This first request should *not* be satisfied from the cache, but
    # the cache should be populated with the result.
    my $p1start = Benchmark->new();
    my ( $one, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    my $p1end = Benchmark->new();
    print STDERR "R1 " . timestr( timediff( $p1end, $p1start ) ) . "\n";
    print STDERR "$stderr\n";

    $this->createNewFoswikiSession( $this->{test_user_login},
        $query, { $this->{uifn} => 1 } );

    # This second request should be satisfied from the cache
    # How do we know it was?
    my $p2start = Benchmark->new();
    ( my $two, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );
    my $p2end = Benchmark->new();
    print STDERR "R2 " . timestr( timediff( $p2end, $p2start ) ) . "\n";
    print STDERR "$stderr\n";

    for ( $one, $two ) {
        $this->assert( s/\r//g,        'Failed to remove \r' );
        $this->assert( s/^.*?\n\n+//s, 'Failed to remove HTTP headers' );
    }
    return if $one eq $two;

    for ( $one, $two ) {
        $this->assert(
            s/value=['"]\??[a-fA-F0-9]{32}['"]/value=vkey/gs,
            'Failed to replace all value=key with dummy key "vkey"'
        );
        $this->assert( s/([?;&]t=)\d+/${1}0/g,
            'Failed to replace timestamp in page URL with dummy (0)' );

        # Do *not* assert the removal of SERVERTIME; it is only present
        # if the JQueryPlugin::FOSWIKI plugin is installed and enabled.
        s/<meta[^>]*?foswiki\.SERVERTIME"[^>]*?>//gi;

        # There may not be TWISTY usage; so no need to assert, but IDs need
        # to be sequential and not random
        %twistyIDs = ();
s/<(span|div)([^>]*?)(\d+?)(show|hide|toggle)([^>]*?)>/'<'.$1.$2._mangleID($3).$4.$5.'>'/ge;

        # the two times are rarely different, but if they bridge a clock
        # tick...
        s/(<input[^>]*\bname="t"[^>]*\bvalue=")\d+("[^>]*>)/$1$2/is;
        s/(<input[^>]*\bvalue=")\d+("[^>]*\bname="t"[^>]*>)/$1$2/is;
    }

    $this->assert_html_equals( $one, $two );

    return;
}

sub verify_simple {
    my $this = shift;
    $this->check('/');
}

sub verify_topic {
    my $this = shift;
    $this->check("/$Foswiki::cfg{SystemWebName}/FileAttribute");
}

sub verify_utf8_topic {
    my $this = shift;
    $this->check("/TestCases/Šňáĺľ/ŠňáĺľŠťěř");
}

1;
