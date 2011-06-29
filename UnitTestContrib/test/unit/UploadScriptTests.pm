use strict;

package UploadScriptTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use Foswiki;
use Unit::Request;
use Foswiki::UI::Upload;
use CGI;
use Error qw( :try );
my $UI_FN;
my $FORM = { name => 'BogusForm' };
my @FIELDS = ( { name => 'Message', value => 'Abandon ship!' } );
my %FIELDShash = map { $_->{name} => $_ } @FIELDS;

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
    $topicObject->put( 'FORM', $FORM );
    $topicObject->putAll( 'FIELD', @FIELDS );
    $topicObject->save( forcenewrevision => 1 );
    $this->_assert_meta_stillgood();
}

sub do_upload {
    my $this   = shift;
    my $fn     = shift;
    my $data   = shift;
    my $cuid   = shift || $this->{test_user_login};
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
    $this->{session} = new Foswiki( $cuid, $query );

    my ($text) = $this->captureWithKey(
        'upload',
        sub {
            no strict 'refs';
            &$UI_FN( $this->{session} );
            use strict 'refs';
            $Foswiki::engine->finalize( $this->{session}->{response},
                $this->{session}->{request} );
            $this->_assert_meta_stillgood();
        },
        $this->{session}
    );
    return $text;
}

sub test_simple_upload {
    my $this = shift;
    local $/;
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        undef,
        hidefile         => 0,
        filecomment      => 'Elucidate the goose',
        createlink       => 0,
        changeproperties => 0,
    );
    $this->assert_matches( qr/^Status: 302/, $result );
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

sub test_noredirect_param {
    my $this = shift;
    local $/;
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        undef,
        hidefile         => 0,
        filecomment      => 'Elucidate the goose',
        createlink       => 0,
        noredirect       => 1,
        changeproperties => 0,
    );
    $this->assert_matches( qr/^OK Flappadoodle.txt uploaded/ms, $result );
}

sub test_redirectto_param {
    my $this = shift;
    $Foswiki::cfg{AllowRedirectUrl} = 1;
    local $/;
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        undef,
        hidefile         => 0,
        filecomment      => 'Elucidate the goose',
        createlink       => 0,
        redirectto       => 'http://blah.com/',
        changeproperties => 0,
    );
    $this->assert_matches( qr#^Location: http://blah.com/#ms, $result );

    $Foswiki::cfg{AllowRedirectUrl} = 0;
    local $/;
    $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        undef,
        hidefile         => 0,
        filecomment      => 'Elucidate the goose',
        createlink       => 0,
        redirectto       => 'http://blah.com/',
        changeproperties => 0,
    );
    $this->assert_matches(
        qr#Location: http://(.*?)$this->{test_web}/$this->{test_topic}#ms,
        $result );
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
            undef,
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
            undef,
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

sub test_illegal_upload {
    my $this = shift;
    local $/;
    my $data = 'asdfasdf';
    my ( $goodfilename, $badfilename ) =
      Foswiki::Sandbox::sanitizeAttachmentName('F$%^&&**()_ .php');
    try {
        $this->do_upload(
            $badfilename,
            $data,
            undef,
            hidefile         => 0,
            filecomment      => 'Elucidate the goose',
            createlink       => 0,
            changeproperties => 0
        );
        $this->assert(0);
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( $goodfilename,         $e->{params}[1] );
        $this->assert_str_equals( "upload_name_changed", $e->{def} );
    };
}

sub test_illegal_propschange {
    my $this = shift;
    local $/;
    my $data = 'asdfasdf';
    my ( $goodfilename, $badfilename ) =
      Foswiki::Sandbox::sanitizeAttachmentName('F$%^&&**()_ .php');
    try {
        $this->do_upload(
            $badfilename,
            $data,
            undef,
            hidefile         => 0,
            filecomment      => 'Elucidate the goose',
            createlink       => 0,
            changeproperties => 0
        );
        $this->assert(0);
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( $goodfilename,         $e->{params}[1] );
        $this->assert_str_equals( "upload_name_changed", $e->{def} );
    };
    try {
        $this->do_upload(
            $badfilename,
            $data,
            undef,
            hidefile         => 1,
            filecomment      => 'Educate the goose',
            createlink       => 1,
            changeproperties => 1
        );
        $this->assert(0);
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( $goodfilename,         $e->{params}[1] );
        $this->assert_str_equals( "upload_name_changed", $e->{def} );
    };
}

sub test_propschanges {
    my $this = shift;
    local $/;
    my $data   = '';
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        undef,
        hidefile         => 0,
        filecomment      => 'Grease the stoat',
        createlink       => 0,
        changeproperties => 0,
    );
    $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        'AdminUser',
        filecomment      => 'Grease the stoat.',
        changeproperties => 1,
    );
    $this->assert_matches( qr/^Status: 302/, $result );
    $result = $this->do_upload(
        'Flappadoodle.txt',
        $data,
        undef,
        hidefile         => 1,
        filecomment      => 'Educate the hedgehog',
        createlink       => 1,
        changeproperties => 1
    );
    $this->assert_matches( qr/^Status: 302/, $result );
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

sub test_imagelink {
    my $this = shift;
    local $/;
    my $imageFile = $Foswiki::cfg{PubDir} . '/System/DocumentGraphics/bomb.png';
    open FILE, '<', $imageFile;
    my $data = do { local $/; <FILE> };
    my $filename = 'bomb.png';
    $filename = Assert::TAINT($filename);
    my $result = $this->do_upload(
        $filename,
        $data,
        undef,
        hidefile         => 0,
        filecomment      => 'Grease the stoat',
        createlink       => 0,
        changeproperties => 0,
    );
    $this->assert_matches( qr/^Status: 302/, $result );
    $filename = Assert::TAINT($filename);
    $result   = $this->do_upload(
        $filename,
        $data,
        undef,
        hidefile         => 1,
        filecomment      => 'Educate the hedgehog',
        createlink       => 1,
        changeproperties => 1
    );
    $this->assert_matches( qr/^Status: 302/, $result );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Check the link was created
    $this->assert_matches(
qr/<img src=\"%ATTACHURLPATH%\/bomb.png\" alt=\"bomb.png\" width=\'16\' height=\'16\' \/>/,
        $text
    );

    # Check the meta
    my $at = $meta->get( 'FILEATTACHMENT', 'bomb.png' );
    $this->assert($at);
    $this->assert_matches( qr/h/i, $at->{attr} );
    $this->assert_str_equals( 'Educate the hedgehog', $at->{comment} );
}

# Assert that we've still got good meta
sub _assert_meta_stillgood {
    my ($this) = @_;
    my ($topicObj) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $tFORM       = $topicObj->get('FORM');
    my @tFIELDS     = $topicObj->find('FIELD');
    my %tFIELDShash = map { $_->{name} => $_ } @tFIELDS;

    $this->assert($tFORM);
    $this->assert( exists $tFORM->{name} );
    $this->assert( $tFORM->{name} eq $FORM->{name} );
    $this->assert( scalar(@tFIELDS) );
    $this->assert( scalar(@tFIELDS) == scalar(@FIELDS) );
    foreach my $name ( keys %FIELDShash ) {
        $this->assert(
            exists $tFIELDShash{$name},
"$this->{test_web}.$this->{test_topic} did not contain META:FIELD[name='$name']"
        );
        $this->assert(
            exists $tFIELDShash{$name}->{value},
"$this->{test_web}.$this->{test_topic} did not contain a value key in META:FIELD[name='$name']"
        );
        $this->assert(
            $tFIELDShash{$name}->{value} eq $FIELDShash{$name}->{value},
"'$this->{test_web}.$this->{test_topic}'/META:FIELD[name='$name'].value = '$tFIELDShash{$name}->{value}' but expected '$FIELDShash{$name}->{value}'"
        );
    }
}

1;
