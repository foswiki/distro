package CacheTests;
use strict;
use warnings;
use utf8;

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
                next if $alg eq 'Generic';
                next if ( grep { $_ eq $alg } @page );

                my $dbcheckfn = "dbcheck_$alg";
                no strict 'refs';
                if ( defined &{$dbcheckfn} ) {
                    next unless &$dbcheckfn();
                }
                use strict 'refs';

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

    return (
        \@page,
        [ 'view',       'rest' ],
        [ 'NoCompress', 'Compress' ],
        [
            'refresh_all', 'refresh_cache', 'refresh_fire', 'refresh_on',
            'timing'
        ],
    );
}

sub dbcheckDBI {
    my ( $dbn, $cfg ) = @_;
    my $dbh;
    eval {
        require DBI;
        my $dsn =
            "dbi:$dbn:database="
          . ( $Foswiki::cfg{Cache}{DBI}{$cfg}{Database} || 'foswiki' )
          . ';host='
          . ( $Foswiki::cfg{Cache}{DBI}{$cfg}{Host} || 'localhost' )
          . (
            $Foswiki::cfg{Cache}{DBI}{$cfg}{Port}
            ? ';port=' . $Foswiki::cfg{Cache}{DBI}{$cfg}{Port}
            : ''
          );

        $dbh = DBI->connect(
            $dsn,
            $Foswiki::cfg{Cache}{DBI}{$cfg}{Username},
            $Foswiki::cfg{Cache}{DBI}{$cfg}{Password},
            {
                PrintError => 0,
                RaiseError => 1
            }
        );
        $dbh->disconnect() if $dbh;
    };
    if ($@) {
        print STDERR
"**** Could not use $cfg; is the database installed and configured?\n";
    }
    return ( $dbh && !$@ ) ? 1 : 0;
}

sub dbcheck_SQLite {
    $Foswiki::cfg{Cache}{DSN} = "dbi:SQLite:dbname=generic.db";
    return dbcheckDBI( 'SQLite', 'SQLite' );
}

sub SQLite {
    require Foswiki::PageCache::DBI::SQLite;
    die $@ if $@;
    $Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::SQLite';
    $Foswiki::cfg{Cache}{DBI}{SQLite}{Filename} =
      "$Foswiki::cfg{WorkingDir}/${$}_sqlite.db";
    $Foswiki::cfg{Cache}{Enabled} = 1;
}

sub dbcheck_PostgreSQL {
    return dbcheckDBI( 'Pg', 'PostgreSQL' );
}

sub PostgreSQL {
    require Foswiki::PageCache::DBI::PostgreSQL;
    die $@ if $@;
    $Foswiki::cfg{Cache}{Implementation} =
      'Foswiki::PageCache::DBI::PostgreSQL';
    $Foswiki::cfg{Cache}{Enabled} = 1;
}

sub dbcheck_MySQL {
    return dbcheckDBI( 'mysql', 'MySQL' );
}

sub MySQL {
    require Foswiki::PageCache::DBI::MySQL;
    $Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::MySQL';
    $Foswiki::cfg{Cache}{Enabled}        = 1;
}

sub dbcheck_MariaDB {
    return dbcheckDBI( 'MariaDB', 'MariaDB' );
}

sub MariaDB {
    require Foswiki::PageCache::DBI::MariaDB;
    $Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::MariaDB';
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
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    unlink("$Foswiki::cfg{WorkingDir}/${$}_sqlite.db");
    unlink("$Foswiki::cfg{WorkingDir}/${$}_generic.db");
}

sub clearCache {
    my $this = shift;

    my $query = Unit::Request->new( { skin => ['none'], refresh => 'all', } );
    $query->path_info("/System/WebHome");
    $query->method('GET');

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin},
        $query, { view => 1 } );

    my ( $resp, $result, $stdout, $stderr ) = $this->capture(
        sub {
            try {
                no strict 'refs';
                &{$UI_FN}( $this->{session} );
                use strict 'refs';
                $Foswiki::engine->finalize( $this->{session}{response},
                    $this->{session}{request} );
            }
            catch Foswiki::OopsException with {
                my $e = shift;
                $this->assert( 0, "Incorrect exception: " . $e->stringify() );
            };

        }
    );

}

sub check {
    my ( $this, $pathinfo ) = @_;

    $this->clearCache();

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

    #print STDERR "P1: $stderr\n" if $stderr;

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

    #print STDERR "P2: $stderr\n" if $stderr;

    $this->assert( $one =~ s/\r//g,          'Failed to remove \r' );
    $this->assert( $one =~ s/^(.*?)\n\n+//s, 'Failed to remove HTTP headers' );
    my $one_head = $1;
    $this->assert_does_not_match( qr/X-Foswiki-Pagecache/i, $one_head );

    $this->assert( $two =~ s/\r//g,          'Failed to remove \r' );
    $this->assert( $two =~ s/^(.*?)\n\n+//s, 'Failed to remove HTTP headers' );
    my $two_heads = $1;
    $this->assert_matches( qr/X-Foswiki-Pagecache: 1/i, $two_heads );

    print STDERR "To cache:   "
      . timestr( timediff( $p1end, $p1start ) ) . "\n";
    print STDERR "From cache: "
      . timestr( timediff( $p2end, $p2start ) ) . "\n";

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

sub check_refresh {

    my $this     = shift;
    my $pathinfo = shift;
    my $refresh  = shift;

    $this->clearCache();

    my $user =
      ( $refresh eq 'all' )
      ? $Foswiki::cfg{AdminUserLogin}
      : $this->{test_user_login};

    $UI_FN ||= $this->getUIFn( $this->{uifn} );
    $Foswiki::cfg{Cache}{Debug} = 1;
    my $query = Unit::Request->new( { skin => ['none'], } );
    $query->path_info($pathinfo);
    $query->method('GET');

    $this->createNewFoswikiSession( $user, $query, { $this->{uifn} => 1 } );

    # This first request should *not* be satisfied from the cache, but
    # the cache should be populated with the result.
    my ( $one, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    $this->createNewFoswikiSession( $user, $query, { $this->{uifn} => 1 } );

    # This second request should be satisfied from the cache
    # How do we know it was?
    ( my $two, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    $query = Unit::Request->new( { skin => ['none'], refresh => $refresh, } );
    $query->path_info($pathinfo);
    $query->method('GET');
    $this->createNewFoswikiSession( $user, $query, { $this->{uifn} => 1 } );

    # This third request with refresh should not be satisfied from the cache
    # How do we know it was?
    ( my $three, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );
    $this->assert( $one =~ s/\r//g,          'Failed to remove \r' );
    $this->assert( $one =~ s/^(.*?)\n\n+//s, 'Failed to remove HTTP headers' );
    my $one_head = $1;
    $this->assert_does_not_match( qr/X-Foswiki-Pagecache/i, $one_head );

    $this->assert( $two =~ s/\r//g,          'Failed to remove \r' );
    $this->assert( $two =~ s/^(.*?)\n\n+//s, 'Failed to remove HTTP headers' );
    my $two_heads = $1;
    $this->assert_matches( qr/X-Foswiki-Pagecache: 1/i, $two_heads );

    $this->assert( $three =~ s/\r//g, 'Failed to remove \r' );
    $this->assert( $three =~ s/^(.*?)\n\n+//s,
        'Failed to remove HTTP headers' );
    my $three_heads = $1;

    if ($refresh) {
        $this->assert_does_not_match( qr/X-Foswiki-Pagecache: 1/i,
            $three_heads );
    }
    else {
        $this->assert_matches( qr/X-Foswiki-Pagecache: 1/i, $three_heads );
    }

    return;
}

sub refresh_all {
    my $this = shift;
    $this->{refresh} = 'all';
}

sub refresh_on {
    my $this = shift;
    $this->{refresh} = 'on';
}

sub refresh_cache {
    my $this = shift;
    $this->{refresh} = 'cache';
}

sub refresh_fire {
    my $this = shift;
    $this->{refresh} = 'fire';
}

sub timing {
    my $this = shift;
    $this->{refresh} = undef;
}

sub verify_simple {
    my $this = shift;

    if ( $this->{refresh} ) {
        $this->check_refresh( '/', $this->{refresh} );
    }
    else {
        $this->check('/');
    }
}

sub verify_topic {
    my $this = shift;
    if ( $this->{refresh} ) {
        $this->check_refresh( "/$Foswiki::cfg{SystemWebName}/FileAttribute",
            $this->{refresh} );
    }
    else {
        $this->check("/$Foswiki::cfg{SystemWebName}/FileAttribute");
    }
}

sub verify_utf8_topic {
    my $this = shift;
    use utf8;
    my $web   = "$this->{test_web}/Šňáĺľ";
    my $topic = 'ŠňáĺľŠťěř';
    Foswiki::Func::createWeb($web);
    my ($meta) = Foswiki::Func::readTopic( $web, $topic );
    $meta->text($topic);
    $meta->save();

    if ( $this->{refresh} ) {
        $this->check_refresh( Encode::encode_utf8("/$web/$topic"),
            $this->{refresh} );
    }
    else {
        $this->check( Encode::encode_utf8("/$web/$topic") );
    }
}

#  Make sure that only admin users can issue refresh_all
sub test_refresh_all {
    my $this = shift;

    SQLite();    # Initialized the cache
    $Foswiki::cfg{Cache}{Enabled} = 1;

    my $pathinfo = "/System/FileAttribute";

    $UI_FN ||= $this->getUIFn("view");
    $Foswiki::cfg{Cache}{Debug} = 1;

    # First, make sure the topic is in the cache.

    my $query = Unit::Request->new( { skin => ['none'] } );
    $query->path_info($pathinfo);
    $query->method('GET');

    $this->createNewFoswikiSession( $this->{test_user_login},
        $query, { view => 1 } );

    my ( $junk, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    # Now attempt a refresh=all, from a non-admin user
    # it should fail with an oops exception

    $query = Unit::Request->new( { skin => ['none'], refresh => 'all', } );
    $query->path_info($pathinfo);
    $query->method('GET');

    #$this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin},
    $this->createNewFoswikiSession( $this->{test_user_login},
        $query, { view => 1 } );

    ( my $one, $result, $stdout, $stderr ) = $this->capture(
        sub {
            try {
                no strict 'refs';
                &{$UI_FN}( $this->{session} );
                use strict 'refs';
                $Foswiki::engine->finalize( $this->{session}{response},
                    $this->{session}{request} );
                $this->assert( 0, "refresh=all allowed by a non-admin user!" );
            }
            catch Foswiki::OopsException with {
                my $e = shift;
                $this->assert_str_equals( "cache_refresh", $e->{def},
                    $e->stringify() );
                $this->assert_str_equals( "accessdenied", $e->{template},
                    $e->stringify() );
            }
        }
    );

    # Make sure that the page is still cached,  that it wasn't removed
    # during the oops processing

    $query = Unit::Request->new( { skin => ['none'], } );
    $query->path_info($pathinfo);
    $query->method('GET');

    $this->createNewFoswikiSession( $this->{test_user_login},
        $query, { view => 1 } );

    ( my $two, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    $this->assert( $two =~ s/\r//g,          'Failed to remove \r' );
    $this->assert( $two =~ s/^(.*?)\n\n+//s, 'Failed to remove HTTP headers' );
    my $two_heads = $1;
    $this->assert_matches( qr/X-Foswiki-Pagecache: 1/i, $two_heads );

    # Now refresh the cache as an admin

    $query = Unit::Request->new( { skin => ['none'], refresh => 'all', } );
    $query->path_info($pathinfo);
    $query->method('GET');

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin},
        $query, { view => 1 } );

    ( my $three, $result, $stdout, $stderr ) = $this->capture(
        sub {
            try {
                no strict 'refs';
                &{$UI_FN}( $this->{session} );
                use strict 'refs';
                $Foswiki::engine->finalize( $this->{session}{response},
                    $this->{session}{request} );
            }
            catch Foswiki::OopsException with {
                my $e = shift;
                $this->assert( 0, "Incorrect exception: " . $e->stringify() );
            };

        }
    );

    $this->assert( $three =~ s/\r//g, 'Failed to remove \r' );
    $this->assert( $three =~ s/^(.*?)\n\n+//s,
        'Failed to remove HTTP headers' );
    my $three_heads = $1;
    $this->assert_does_not_match( qr/X-Foswiki-Pagecache: 1/i, $three_heads );

    # Make sure that the page is not cached

    $query = Unit::Request->new( { skin => ['none'], } );
    $query->path_info($pathinfo);
    $query->method('GET');

    $this->createNewFoswikiSession( $this->{test_user_login},
        $query, { view => 1 } );

    ( my $four, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    $this->assert( $four =~ s/\r//g,          'Failed to remove \r' );
    $this->assert( $four =~ s/^(.*?)\n\n+//s, 'Failed to remove HTTP headers' );
    my $four_heads = $1;
    $this->assert_does_not_match( qr/X-Foswiki-Pagecache: 1/i, $four_heads );

}

1;
