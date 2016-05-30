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

# Global configuration
#
#  $this->{param_refresh} - value for referesh= param
#  $this->{param_topic}   - value for topic= param
#  $this->{param_load}    - value for load= param, used by the /JQueryPlugin/tmpl rest handler
#  $this->{path_info}     - path_info for the query
#  $this->{query}         - Query object

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

sub skip {
    my ( $this, $test ) = @_;

    return "simple test not compatible with rest transactions"
      if ( defined $test && $test =~ m/verify_simple/ && $test =~ m/_rest_/ );

    return undef;
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
    return dbcheckDBI( 'SQLite', 'Generic' );
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

sub dbcheck_Generic {
    return dbcheck_SQLite();
}

sub Generic {
    $Foswiki::cfg{Cache}{DBI}{DSN} =
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
    $this->{uifn}  = 'view';
    $UI_FN         = $this->getUIFn( $this->{uifn} );
    $this->{query} = Unit::Request->new( { skin => ['none'], } );
    $this->{query}->method('GET');

    $this->{path_info} = '/$Foswiki::cfg{SystemWebName}/FileAttribute';
}

sub rest {
    my $this = shift;
    $this->{uifn} = 'rest';
    $UI_FN = $this->getUIFn( $this->{uifn} );
    require Unit::Request::Rest;
    $this->{query} = Unit::Request::Rest->new( { skin => ['none'], } );

    # SMELL: Only GET requests are cached.  Also, the choice of REST handler
    # is important.  Handlers that generate their own output rather than using
    # the Foswiki page handler are not cached.

    $this->{query}->method('GET');
    $this->{path_info} = '/JQueryPlugin/tmpl';

    $this->{param_topic} = "$Foswiki::cfg{SystemWebName}.FileAttribute";

# SMELL: Name of template to load - generates a not found error, but it's cached.
    $this->{param_load} = 'Foo';
}

sub refresh_all {
    my $this = shift;
    $this->{param_refresh} = 'all';
}

sub refresh_on {
    my $this = shift;
    $this->{param_refresh} = 'on';
}

sub refresh_cache {
    my $this = shift;
    $this->{param_refresh} = 'cache';
}

sub refresh_fire {
    my $this = shift;
    $this->{param_refresh} = 'fire';
}

sub timing {
    my $this = shift;
    $this->{param_refresh} = '';
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
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    unlink("$Foswiki::cfg{WorkingDir}/${$}_sqlite.db");
    unlink("$Foswiki::cfg{WorkingDir}/${$}_generic.db");
}

sub _clearCache {
    my $this = shift;

    my $clear = Unit::Request->new( { skin => ['none'], refresh => 'all', } );
    $clear->path_info("/System/WebHome");
    $clear->method('GET');

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin},
        $clear, { view => 1 } );

    my $_clrUI_FN = $this->getUIFn("view");

    my ( $resp, $result, $stdout, $stderr ) = $this->capture(
        sub {
            try {
                no strict 'refs';
                &{$_clrUI_FN}( $this->{session} );
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

# Check timing and general cache operation.
sub check_timing {
    my ($this) = @_;

    $Foswiki::cfg{Cache}{Debug} = 1;
    $this->_clearCache();

    # This first request should *not* be satisfied from the cache, but
    # the cache should be populated with the result.
    my $p1start = Benchmark->new();
    my $one     = $this->_runQuery();
    my $p1end   = Benchmark->new();

    my $p2start = Benchmark->new();
    my $two     = $this->_runQuery();
    my $p2end   = Benchmark->new();

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

# Run a query using the global settings established by the variations.
sub _runQuery {
    my $this    = shift;
    my $refresh = shift;

    $this->{uifn} ||= 'view';

    my $user =
      ( $this->{param_refresh} eq 'all' )
      ? $Foswiki::cfg{AdminUserLogin}
      : $this->{test_user_login};

    $this->{query}->path_info( $this->{path_info} );
    $this->{query}->param( 'topic', $this->{param_topic} )
      if defined $this->{param_topic};
    $this->{query}->param( 'load', $this->{param_load} )
      if defined $this->{param_load};

    if ($refresh) {
        $this->{query}->param( 'refresh', $refresh );
    }
    else {
        $this->{query}->delete('refresh');
    }

    $this->createNewFoswikiSession( $user, $this->{query},
        { $this->{uifn} => 1 } );

    my ( $resp, $result, $stdout, $stderr ) = $this->capture(
        sub {
            no strict 'refs';
            &{$UI_FN}( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );
    return $resp;
}

sub check_refresh {

    my $this = shift;

    $this->_clearCache();

    my $user =
      ( $this->{param_refresh} eq 'all' )
      ? $Foswiki::cfg{AdminUserLogin}
      : $this->{test_user_login};

    $Foswiki::cfg{Cache}{Debug} = 1;

    $this->_runQuery();

    # This first request should prime the cache
    my $one = $this->_runQuery( $this->{param_refresh} );

    # This second request should be satisfied from the cache
    my $two = $this->_runQuery();

    # This third request with refresh should not be satisfied from the cache

    my $three = $this->_runQuery( $this->{param_refresh} );

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

    if ( $this->{param_refresh} ) {
        $this->assert_does_not_match( qr/X-Foswiki-Pagecache: 1/i,
            $three_heads );
    }
    else {
        $this->assert_matches( qr/X-Foswiki-Pagecache: 1/i, $three_heads );
    }

    return;
}

sub verify_simple {
    my $this = shift;

    $this->{path_info}   = "/";
    $this->{param_topic} = undef;
    $this->{param_load}  = undef;

    if ( $this->{param_refresh} ) {
        $this->check_refresh();
    }
    else {
        $this->check_timing();
    }
}

sub verify_topic {
    my $this = shift;

    if ( $this->{uifn} eq 'rest' ) {
        $this->{path_info}   = '/JQueryPlugin/tmpl';
        $this->{param_topic} = "$Foswiki::cfg{SystemWebName}.FileAttribute";
        $this->{param_load}  = 'Foo';
    }
    else {
        $this->{path_info}   = "/$Foswiki::cfg{SystemWebName}/FileAttribute";
        $this->{param_topic} = undef;
        $this->{param_load}  = undef;
    }
    if ( $this->{param_refresh} ) {
        $this->check_refresh();
    }
    else {
        $this->check_timing();
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

    if ( $this->{uifn} eq 'rest' ) {
        $this->{path_info}   = '/JQueryPlugin/tmpl';
        $this->{param_topic} = "$web.$topic";
        $this->{param_load}  = 'Foo';
    }
    else {
        $this->{path_info}   = Foswiki::encode_utf8("/$web/$topic");
        $this->{param_topic} = undef;
        $this->{param_load}  = undef;
    }
    if ( $this->{param_refresh} ) {
        $this->check_refresh();
    }
    else {
        $this->check_timing();
    }
}

#  Make sure that only admin users can issue refresh_all
sub test_refresh_all {
    my $this = shift;

    SQLite();    # Initialized the cache
    $Foswiki::cfg{Cache}{Enabled} = 1;

    $this->{path_info} = "/System/FileAttribute";

    $UI_FN ||= $this->getUIFn("view");
    $Foswiki::cfg{Cache}{Debug} = 1;

    # First, make sure the topic is in the cache.

    $this->{query} = Unit::Request->new( { skin => ['none'] } );
    $this->{query}->path_info( $this->{path_info} );
    $this->{query}->method('GET');

    $this->createNewFoswikiSession( $this->{test_user_login},
        $this->{query}, { view => 1 } );

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

    $this->{query} =
      Unit::Request->new( { skin => ['none'], refresh => 'all', } );
    $this->{query}->path_info( $this->{path_info} );
    $this->{query}->method('GET');

    #$this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin},
    $this->createNewFoswikiSession( $this->{test_user_login},
        $this->{query}, { view => 1 } );

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

    $this->{query} = Unit::Request->new( { skin => ['none'], } );
    $this->{query}->path_info( $this->{path_info} );
    $this->{query}->method('GET');

    $this->createNewFoswikiSession( $this->{test_user_login},
        $this->{query}, { view => 1 } );

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

    $this->{query} =
      Unit::Request->new( { skin => ['none'], refresh => 'all', } );
    $this->{query}->path_info( $this->{path_info} );
    $this->{query}->method('GET');

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin},
        $this->{query}, { view => 1 } );

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

    $this->{query} = Unit::Request->new( { skin => ['none'], } );
    $this->{query}->path_info( $this->{path_info} );
    $this->{query}->method('GET');

    $this->createNewFoswikiSession( $this->{test_user_login},
        $this->{query}, { view => 1 } );

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
