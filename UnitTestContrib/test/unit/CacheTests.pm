package CacheTests;
use v5.14;
use utf8;

use Foswiki();
use File::Spec();
use Foswiki::OopsException();
use Foswiki::PageCache();
use Benchmark qw(:hireswallclock);

use Moo;
use namespace::clean;
extends qw(FoswikiFnTestCase);

has testAction => ( is => 'rw', );
has testUri => ( is => 'rw', clearer => 1, );
has testPathInfo =>
  ( is => 'rw', clearer => 1, lazy => 1, default => sub { $_[0]->testUri }, );
has oldDbiDsn   => ( is => 'rw', );
has oldCacheDsn => ( is => 'rw', );

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
    Foswiki::load_package('Foswiki::PageCache::DBI::SQLite');
    $Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::SQLite';
    $Foswiki::cfg{Cache}{DBI}{SQLite}{Filename} =
      "$Foswiki::cfg{WorkingDir}/${$}_sqlite.db";
    $Foswiki::cfg{Cache}{Enabled} = 1;
}

sub dbcheck_PostgreSQL {
    return dbcheckDBI( 'Pg', 'PostgreSQL' );
}

sub PostgreSQL {
    Foswiki::load_package('Foswiki::PageCache::DBI::PostgreSQL');
    $Foswiki::cfg{Cache}{Implementation} =
      'Foswiki::PageCache::DBI::PostgreSQL';
    $Foswiki::cfg{Cache}{Enabled} = 1;
}

sub dbcheck_MySQL {
    return dbcheckDBI( 'mysql', 'MySQL' );
}

sub MySQL {
    Foswiki::load_package('Foswiki::PageCache::DBI::MySQL');
    $Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::MySQL';
    $Foswiki::cfg{Cache}{Enabled}        = 1;
}

sub dbcheck_Generic {
    return dbcheck_SQLite();
}

sub Generic {
    $Foswiki::cfg{Cache}{DBI}{DSN} =
      "dbi:SQLite:dbname=$Foswiki::cfg{WorkingDir}/${$}_generic.db";
    Foswiki::load_package('Foswiki::PageCache::DBI::Generic');
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
    $this->testAction('view');
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

sub rest_handler {
    return '';
}

sub rest {
    my $this = shift;
    $this->testAction('rest');
    Foswiki::Func::registerRESTHandler(
        'trial', \&rest_handler,
        authenticate => 0,
        validate     => 0,
        http_allow   => 'GET',
    );
    $this->testPathInfo( '/' . __PACKAGE__ . '/trial' );
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

around set_up => sub {
    my $orig = shift;
    my $this = shift;
    $Foswiki::cfg{Cache}{Enabled} = 0;
    $orig->( $this, @_ );

    $Foswiki::cfg{HttpCompress} = 0;
    $Foswiki::cfg{Cache}{Compress} = 0;
    $this->oldDbiDsn( $Foswiki::cfg{Cache}{DBI}{DSN} );
    $this->oldCacheDsn( $Foswiki::cfg{Cache}{DSN} );
    delete $this->app->env->{FOSWIKI_TEST_PATH_INFO};
    delete $this->app->env->{FOSWIKI_TEST_ACTION};
    $this->clear_testUri;
    $this->clear_testPathInfo;
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;
    $Foswiki::cfg{Cache}{DBI}{DSN} = $this->oldDbiDsn;
    $Foswiki::cfg{Cache}{DSN} = $this->oldCacheDsn;
    $orig->($this);
    unlink("$Foswiki::cfg{WorkingDir}/${$}_sqlite.db");
    unlink("$Foswiki::cfg{WorkingDir}/${$}_generic.db");
};

sub _clearCache {
    my ( $this, $pathinfo ) = @_;

    $this->app->cfg->data->{Cache}{Debug} = 1;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                skin     => ['none'],
                action   => ['view'],
                endPoint => $this->testUri,
            },
        },
        engineParams => {
            simulate          => 'cgi',
            initialAttributes => {
                uri       => "/$Foswiki::cfg{SystemWebName}/FileAttribute",
                path_info => $this->testPathInfo,
                method    => 'GET',
                action    => $this->testAction,
            },
        },
        context => { $this->testAction => 1 },
        user    => $this->test_user_login,
    );

    return $this->app->handleRequest;
}

sub check {
    my ( $this, $pathinfo ) = @_;

    $this->app->cfg->data->{Cache}{Debug} = 1;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                skin     => ['none'],
                action   => [ $this->testAction ],
                endPoint => $this->testUri,
            },
        },
        engineParams => {
            simulate          => 'cgi',
            initialAttributes => {
                uri       => $this->testUri,
                path_info => $this->testPathInfo,
                method    => 'GET',
                action    => $this->testAction,
            },
        },
        context => { $this->testAction => 1 },
        user    => $this->test_user_login,
    );

    # This first request should *not* be satisfied from the cache, but
    # the cache should be populated with the result.
    my $p1start = Benchmark->new();
    my ( $one, $result, $stdout, $stderr ) = $this->capture(
        sub {
            return $this->app->handleRequest;
        }
    );
    my $p1end = Benchmark->new();

    print STDERR "P1: $stderr\n" if $stderr;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                skin     => ['none'],
                action   => [ $this->testAction ],
                endPoint => $this->testUri,
            },
        },
        engineParams => {
            simulate          => 'cgi',
            initialAttributes => {
                uri       => $this->testUri,
                path_info => $this->testPathInfo,
                method    => 'GET',
                action    => $this->testAction,
            },
        },
        context => { $this->testAction => 1, },
        user    => $this->test_user_login,
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
    $this->testUri('/');

    #$this->check;

    if ( $this->{param_refresh} ) {
        $this->check_refresh;
    }
    else {
        $this->check_timing;
    }
}

sub verify_topic {
    my $this = shift;
    $this->testUri("/$Foswiki::cfg{SystemWebName}/FileAttribute");
    $this->check;
}

sub verify_utf8_topic {
    my $this = shift;
    use utf8;
    my $web   = $this->test_web . "/Šňáĺľ";
    my $topic = 'ŠňáĺľŠťěř';
    Foswiki::Func::createWeb($web);
    my ($meta) = Foswiki::Func::readTopic( $web, $topic );
    $meta->text($topic);
    $meta->save();

    $this->testUri( Encode::encode_utf8("/$web/$topic") );
    $this->check;
}

1;
