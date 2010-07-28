package CacheTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Foswiki::Meta;
use Error qw( :try );
use Foswiki::OopsException;
use Foswiki::PageCache;
use Benchmark qw(:hireswallclock);

my $UI_FN;

sub fixture_groups {
    my $this = shift;
    my @page;
    foreach my $dir (@INC) {
        if ( opendir( D, "$dir/Foswiki/Cache" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ s/^(.*)\.pm$/$1/;
                next if defined &$alg;
                $ENV{PATH} =~ /^(.*)$/ms;
                $ENV{PATH} = $1;
                ($alg) = $alg =~ /^(.*)$/ms;
                eval "require Foswiki::Cache::$alg";
                if ($@ ) {
                    print STDERR "Cannot test Foswiki::Cache::$alg\nCompilation error when trying to 'require' it\n";
                } else {
                    no strict 'refs';
                    *$alg = sub {
                        my $this = shift;
                        $Foswiki::cfg{CacheManager} = 'Foswiki::Cache::'.$alg;
                    };
                    use strict 'refs';
                    push(@page, $alg);
                }
            }
            closedir(D);
        }
    }

    return ( \@page, [ 'DBFileMeta', 'BDBMeta' ], [ 'NoCompress', 'Compress' ] );
}

sub DBFileMeta {
    $Foswiki::cfg{MetaCacheManager} = 'Foswiki::Cache::DB_File';
}

sub BDBMeta {
    $Foswiki::cfg{MetaCacheManager} = 'Foswiki::Cache::BDB';
}

sub Compress {
    $Foswiki::cfg{HttpCompress} = 1;
    $Foswiki::cfg{Cache}{Compress} = 1;
}

sub NoCompress {
    $Foswiki::cfg{HttpCompress} = 0;
    $Foswiki::cfg{Cache}{Compress} = 0;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $Foswiki::cfg{Cache}{Enabled} = 0;
    $Foswiki::cfg{HttpCompress} = 0;
    $Foswiki::cfg{Cache}{Compress} = 0;
    $UI_FN ||= $this->getUIFn('view');
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub verify_view {
    my $this = shift;

    $UI_FN ||= $this->getUIFn('view');

    my $query = new Unit::Request(
        {
            skin      => ['none'],
        }
       );
    $query->path_info("/");
    $query->method('POST');

    my $fatwilly = new Foswiki( $this->{test_user_login}, $query );

    # This first request should *not* be satisfied from the cache, but
    # the cache should be populated with the result.
    my $p1start = new Benchmark();
    my ($one) = $this->capture(
        sub {
            no strict 'refs';
            &$UI_FN($fatwilly);
            use strict 'refs';
            $Foswiki::engine->finalize( $fatwilly->{response},
                                        $fatwilly->{request} );
        }
       );

    my $p1end = new Benchmark();
    print STDERR "R1 ".timestr(timediff($p1end, $p1start))."\n";
    $fatwilly->finish();

    $fatwilly = new Foswiki( $this->{test_user_login}, $query );

    # This second request should be satisfied from the cache
    my $p2start = new Benchmark();
    my ($two) = $this->capture(
        sub {
            no strict 'refs';
            &$UI_FN($fatwilly);
            use strict 'refs';
            $Foswiki::engine->finalize( $fatwilly->{response},
                                        $fatwilly->{request} );
        }
       );
    my $p2end = new Benchmark();
    print STDERR "R2 ".timestr(timediff($p2end, $p2start))."\n";
    $fatwilly->finish();


    # Massage the HTML for comparison
    $one =~ s/\r//g;
    $one =~ s/^.*?\n\n+//s;
    $one =~ s/value=['"]\??[a-fA-F0-9]{32}['"]/value=vkey/gs;
    $one =~ s/([?;&]t=)\d+/${1}0/g;
    $one =~ s/<meta[^>]*?foswiki\.SERVERTIME"[^>]*?>//gi;

    $two =~ s/\r//g;
    $two =~ s/^.*?\n\n+//s;
    $two =~ s/value=['"]\??[a-fA-F0-9]{32}['"]/value=vkey/gs;
    $two =~ s/([?;&]t=)\d+/${1}0/g;
    $two =~ s/<meta[^>]*?foswiki\.SERVERTIME"[^>]*?>//gi;

    $this->assert_html_equals($one, $two);
}

1;
