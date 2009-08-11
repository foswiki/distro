use strict;

package UploadScriptTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Unit::Request;
use Foswiki::UI::Upload;
use CGI;
use Error qw( :try );
my $UI_FN;

sub new {
    my $self = shift()->SUPER::new( "UploadScript", @_ );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('upload');
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, "   * Set ATTACHFILESIZELIMIT = 511\n", undef );
    $topicObject->save();
}

sub do_upload {
    my $this   = shift;
    my $fn     = shift;
    my $data   = shift;
    my %params = @_;
    my %args   = (
        webName   => [ $this->{test_web} ],
        topicName => [ $this->{test_topic} ],
    );
    while ( scalar(@_) ) {
        my $k = shift(@_);
        my $v = shift(@_);
        $args{$k} = [$v];
    }
    my $query = new Unit::Request( \%args );
    $query->method('POST');
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    my $tmpfile = new CGITempFile(0)
      ; #<-- returns undef on OSX with 3.15 version of CGI module (works on 3.42)
    my $fh = Fh->new( $fn, $tmpfile->as_string, 0 );
    print $fh $data;
    seek( $fh, 0, 0 );
    $query->param( -name => 'filepath', -value => $fn );
    my %uploads = ();
    require Foswiki::Request::Upload;
    $uploads{$fh} = new Foswiki::Request::Upload(
        headers => {},
        tmpname => $tmpfile->as_string
    );
    $query->uploads( \%uploads );

    my $stream = $query->upload('filepath');
    $this->assert($stream);
    seek( $stream, 0, 0 );

    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );

    my ($text) = $this->capture(
        sub {
            no strict 'refs';
            &$UI_FN( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}->{response},
                $this->{session}->{request} );
        }
    );
    return $text;
}

sub test_simple_upload {
    my $this = shift;
    local $/;
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        hidefile         => 0,
        filecomment      => 'Elucidate the goose',
        createlink       => 0,
        changeproperties => 0,
    );
    $this->assert( $result =~ /^OK/, $result );
    $this->assert(
        open( F,
"<$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/Flappadoodle.txt"
        )
    );
    $this->assert_str_equals( "BLAH", <F> );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Check the meta
    my $at = $meta->get( 'FILEATTACHMENT', 'Flappadoodle.txt' );
    $this->assert($at);
    $this->assert_str_equals( 'Elucidate the goose', $at->{comment} );
}

sub test_oversized_upload {
    my $this = shift;
    local $/;
    my %args = (
        webName   => [ $this->{test_web} ],
        topicName => [ $this->{test_topic} ],
    );
    my $query = new Unit::Request( \%args );
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->{session}->finish();
    $this->{session} = new Foswiki( $this->{test_user_login}, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
    my $data = '00000000000000000000000000000000000000';
    my $sz   = Foswiki::Func::getPreferencesValue('ATTACHFILESIZELIMIT') * 1024;
    $data .= $data while length($data) <= $sz;
    try {
        $this->do_upload(
            'Flappadoodle.txt',
            $data,
            hidefile         => 0,
            filecomment      => 'Elucidate the goose',
            createlink       => 0,
            changeproperties => 0
        );
        $this->assert(0);
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "oversized_upload", $e->{def} );
    };
}

sub test_zerosized_upload {
    my $this = shift;
    local $/;
    my $data = '';
    try {
        $this->do_upload(
            'Flappadoodle.txt',
            $data,
            hidefile         => 0,
            filecomment      => 'Elucidate the goose',
            createlink       => 0,
            changeproperties => 0
        );
        $this->assert(0);
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "zero_size_upload", $e->{def} );
    };
}

sub test_propschanges {
    my $this = shift;
    local $/;
    my $data   = '';
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        hidefile         => 0,
        filecomment      => 'Grease the stoat',
        createlink       => 0,
        changeproperties => 0,
    );
    $this->assert( $result =~ /^OK/, $result );
    $result = $this->do_upload(
        'Flappadoodle.txt',
        $data,
        hidefile         => 1,
        filecomment      => 'Educate the hedgehog',
        createlink       => 1,
        changeproperties => 1
    );
    $this->assert( $result =~ /^OK/, $result );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Check the link was created
    $this->assert_matches(
qr/\[\[%ATTACHURL%\/Flappadoodle\.txt\]\[Flappadoodle\.txt\]\]: Educate the hedgehog/,
        $text
    );

    # Check the meta
    my $at = $meta->get( 'FILEATTACHMENT', 'Flappadoodle.txt' );
    $this->assert($at);
    $this->assert_matches( qr/h/i, $at->{attr} );
    $this->assert_str_equals( 'Educate the hedgehog', $at->{comment} );
}

1;
