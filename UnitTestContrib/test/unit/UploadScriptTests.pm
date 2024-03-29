package UploadScriptTests;
use strict;
use warnings;
use utf8;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Unit::Request();
use Foswiki::UI::Upload();
use Error qw( :try );
use File::Temp;

my $UI_FN;
my $FORM = { name => 'BogusForm' };
my @FIELDS = ( { name => 'Message', value => 'Abandon ship!' } );
my %FIELDShash = map { $_->{name} => $_ } @FIELDS;

sub new {
    my @args = @_;
    my $self = shift()->SUPER::new( "UploadScript", @args );
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $UI_FN ||= $this->getUIFn('upload');
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text("   * Set ATTACHFILESIZELIMIT = 511\n");
    $topicObject->putAll( 'FORM',  $FORM );
    $topicObject->putAll( 'FIELD', @FIELDS );
    $topicObject->save( forcenewrevision => 1 );
    $this->_assert_meta_stillgood(0);

    return;
}

sub skip {
    my ( $this, $test ) = @_;

    my %skip_tests;

    if ( Cwd::cwd() =~ m/[^\p{ASCII}]/ ) {

        %skip_tests = (
            'UploadScriptTests::test_unsupported_characters' =>
'Tests for iso-8859 character sets not supported: Path contains non-ASCII characters',
            'UploadScriptTests::test_supported_nonascii' =>
'Tests for iso-8859 character sets not supported: Path contains non-ASCII characters',
        );

        return $skip_tests{$test}
          if ( defined $test && defined $skip_tests{$test} );

    }

    return undef;

}

sub do_upload {
    my ( $this, $fn, $data, $cuid, @arga ) = @_;
    my %params = @arga;
    my %args   = (
        webName   => [ $this->{test_web} ],
        topicName => [ $this->{test_topic} ],
    );
    $cuid ||= $this->{test_user_login};
    while ( scalar(@arga) ) {
        my $k = shift(@arga);
        my $v = shift(@arga);
        $args{$k} = [$v];
    }

    my $query = Unit::Request->new( \%args );
    $query->method('POST');
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    my $fh      = File::Temp->new();
    my $tmpfile = $fh->filename;
    print $fh $data;
    seek( $fh, 0, 0 );
    $query->param( -name => 'filepath', -value => $fn );
    my %uploads = ();
    require Foswiki::Request::Upload;
    $uploads{$fn} = Foswiki::Request::Upload->new(
        headers => {},
        tmpname => $tmpfile
    );
    $query->uploads( \%uploads );

    my $stream = $query->upload($fn);
    $this->assert($stream);
    seek( $stream, 0, 0 );

    $this->createNewFoswikiSession( $cuid, $query );

    Foswiki::Func::setPreferencesValue( 'ATTACHEDFILELINKFORMAT',
        $params{linkformat} )
      if ( defined $params{linkformat} );

    my ($text) = $this->captureWithKey(
        'upload',
        sub {
            no strict 'refs';
            $UI_FN->( $this->{session} );
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
    local $/ = undef;
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        undef,
        hidefile         => 0,
        filecomment      => 'Elucidate the goose',
        createlink       => 0,
        changeproperties => 0,
    );
    $this->assert_matches( qr/^Status: 302/ms, $result );
    $this->assert(
        open(
            my $F,
            '<',
"$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/Flappadoodle.txt"
        )
    );
    $this->assert_str_equals( "BLAH", <$F> );
    $this->assert( close($F) );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Check the meta
    my $at = $meta->get( 'FILEATTACHMENT', 'Flappadoodle.txt' );
    $this->assert($at);
    $this->assert_str_equals( 'Elucidate the goose', $at->{comment} );

    return;
}

sub test_space_filename {
    my $this = shift;
    local $/ = undef;
    my $result;

    # Try the upload with ReplaceSpaces enabled (old Foswiki 1.x/2.0 behaviour)
    # It should oops. but will still attach the file.
    $Foswiki::cfg{AttachmentReplaceSpaces} = 1;
    try {
        $result = $this->do_upload(
            'Flappa doodle.txt',
            "BLAH",
            undef,
            hidefile         => 0,
            filecomment      => 'Elucidate the goose',
            createlink       => 0,
            changeproperties => 0,
        );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "upload_name_changed", $e->{def} );
    };

    # Try the upload again, without ReplaceSpaces enabled, (new behaviour)
    # It should work, without any oops.
    $Foswiki::cfg{AttachmentReplaceSpaces} = 0;
    $result = $this->do_upload(
        'Flappa doodle.txt',
        "BLAH",
        undef,
        hidefile         => 0,
        filecomment      => 'Stuff the goose',
        createlink       => 0,
        changeproperties => 0,
    );

    $this->assert_matches( qr/^Status: 302/ms, $result );
    $this->assert(
        open(
            my $F,
            '<',
"$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/Flappa doodle.txt"
        )
    );
    $this->assert_str_equals( "BLAH", <$F> );
    $this->assert( close($F) );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Check the meta
    my $at = $meta->get( 'FILEATTACHMENT', 'Flappa doodle.txt' );
    $this->assert($at);
    $this->assert_str_equals( 'Stuff the goose', $at->{comment} );

    $at = $meta->get( 'FILEATTACHMENT', 'Flappa_doodle.txt' );
    $this->assert($at);
    $this->assert_str_equals( 'Elucidate the goose', $at->{comment} );
    return;
}

sub test_noredirect_param {
    my $this = shift;
    local $/ = undef;
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
    $this->assert_matches( qr/^OK: Flappadoodle.txt uploaded/ms, $result );

    return;
}

sub test_redirectto_param {
    my $this = shift;
    $Foswiki::cfg{AllowRedirectUrl} = 1;
    local $/ = undef;
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
    local $/ = undef;
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
        qr#Location: https?://(.*?)$this->{test_web}/$this->{test_topic}#ms,
        $result );

    return;
}

sub test_oversized_upload {
    my $this = shift;
    local $/ = undef;
    my %args = (
        webName   => [ $this->{test_web} ],
        topicName => [ $this->{test_topic} ],
    );
    my $query = Unit::Request->new( \%args );
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
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

    return;
}

sub test_zerosized_upload {
    my $this = shift;
    local $/ = undef;
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

    return;
}

sub test_illegal_upload {
    my $this = shift;
    local $/ = undef;
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

sub test_unsupported_characters {
    my $this = shift;
    local $/ = undef;
    my $data = 'asdfasdf';
    $Foswiki::cfg{Store}{Encoding} = 'iso-8859-1';
    my $badfilename = 'AśčÁŠŤśěž.txt';
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
        $this->assert_str_equals( $badfilename,           $e->{params}[0] );
        $this->assert_str_equals( "unsupported_filename", $e->{def} );
    };

    return;
}

sub test_supported_nonascii {
    my $this = shift;
    local $/ = undef;
    my $data = 'asdfasdf';
    $Foswiki::cfg{Store}{Encoding} = 'iso-8859-1';
    my $filename = '¢£é.txt';
    my $isoname  = "\xa2\xa3\xe9.txt";
    my $result   = $this->do_upload(
        $filename,
        $data,
        undef,
        hidefile         => 0,
        filecomment      => 'Elucidate the goose',
        createlink       => 0,
        changeproperties => 0
    );
    $this->assert_matches( qr/^Status: 302/ms, $result );
    $this->assert(
        open(
            my $F,
            '<',
"$Foswiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/$isoname"
        )
    );
    $this->assert_str_equals( "asdfasdf", <$F> );
    $this->assert( close($F) );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Check the meta
    my $at = $meta->get( 'FILEATTACHMENT', $filename );
    $this->assert($at);
    $this->assert_str_equals( 'Elucidate the goose', $at->{comment} );

    return;
}

sub test_illegal_upload_Item13048 {
    my $this = shift;
    local $/ = undef;
    my $data = 'asdfasdf';
    my ( $goodfilename, $badfilename ) =
      Foswiki::Sandbox::sanitizeAttachmentName("\0.htaccess.");

#my $hex = '';
#foreach my $ch ( split ( //, "BAD: $badfilename  GOOD: $goodfilename" ) ) {
#    $hex .= ( $ch lt "\x20" || $ch gt "\x7e" ) ? "\'" . unpack("H2",$ch) . "\'" : $ch;
#    }
#print STDERR "$hex \n";

# Verify that the sanitize process:
#  - Removes the leading binary zero
#  - Converts the trailing (dot) to ..txt.  Windows silently strips trailing dot from filenames
    $this->assert_str_equals( '.htaccess..txt', $goodfilename );

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

    # Test that filter is not case sensitive.
    ( $goodfilename, $badfilename ) =
      Foswiki::Sandbox::sanitizeAttachmentName(".HTAccess");

  # Verify that the sanitize process detects .htaccess in a case insensitive way
    $this->assert_str_equals( '.HTAccess.txt', $goodfilename );

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

    return;
}

sub test_illegal_propschange {
    my $this = shift;
    local $/ = undef;
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

    return;
}

sub test_propschanges {
    my $this = shift;
    local $/ = undef;
    my $data = '';

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
    $this->assert_matches( qr/^Status: 302/ms, $result );
    $result = $this->do_upload(
        'Flappadoodle.txt',
        $data,
        undef,
        hidefile    => 1,
        filecomment => 'Educate the hedgehog',
        createlink  => 1,
        linkformat =>
          '\n   * [[$percentATTACHURL$percent/$fileurl][$filename]]: $comment',
        changeproperties => 1
    );
    $this->assert_matches( qr/^Status: 302/ms, $result );
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

    return;
}

sub test_linkformat {
    my $this = shift;
    local $/ = undef;
    my $data = '';

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
        $data,
        undef,
        hidefile    => 1,
        filecomment => 'Educate the hedgehog',
        createlink  => 1,
        linkformat =>
          '\n   * [[$percntATTACHURL$percnt/$fileurl][$filename]]: $comment',
        changeproperties => 1
    );
    $this->assert_matches( qr/^Status: 302/ms, $result );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # This tests the original default link format
    $this->assert_matches(
qr/^   \* \[\[%ATTACHURL%\/Flappadoodle\.txt\]\[Flappadoodle\.txt\]\]: Educate the hedgehog/ms,
        $text
    );
}

sub test_imagelink {
    my $this = shift;
    local $/ = undef;
    my $imageFile = $Foswiki::cfg{PubDir} . '/System/DocumentGraphics/bomb.png';
    $this->assert( open( my $FILE, '<', $imageFile ) );
    my $data = do { local $/ = undef; <$FILE> };
    $this->assert( close($FILE) );
    my $filename = 'bo:mb.png';
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
    $this->assert_matches( qr/^Status: 302/ms, $result );
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
    $this->assert_matches( qr/^Status: 302/ms, $result );
    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Check the link was created
    $this->assert_matches(
qr/<img src=\"%ATTACHURLPATH%\/bo:mb.png\" alt=\"bo:mb.png\" width=\'16\' height=\'16\' \/>/,
        $text
    );

    # Check the meta
    my $at = $meta->get( 'FILEATTACHMENT', 'bo:mb.png' );
    $this->assert($at);
    $this->assert_matches( qr/h/i, $at->{attr} );
    $this->assert_str_equals( 'Educate the hedgehog', $at->{comment} );

    return;
}

# Assert that we've still got good meta
sub _assert_meta_stillgood {
    my ( $this, $assert ) = @_;
    my ($topicObj) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    my $tFORM       = $topicObj->get('FORM');
    my @tFIELDS     = $topicObj->find('FIELD');
    my %tFIELDShash = map { $_->{name} => $_ } @tFIELDS;

    return unless $this->_assert_( $assert, $tFORM );
    return unless $this->_assert_( $assert, exists $tFORM->{name} );
    return unless $this->_assert_( $assert, $tFORM->{name} eq $FORM->{name} );
    return unless $this->_assert_( $assert, scalar(@tFIELDS) );
    return
      unless $this->_assert_( $assert, scalar(@tFIELDS) == scalar(@FIELDS) );
    foreach my $name ( keys %FIELDShash ) {
        return
          unless $this->_assert_(
            $assert,
            exists $tFIELDShash{$name},
"$this->{test_web}.$this->{test_topic} did not contain META:FIELD[name='$name']"
          );
        return
          unless $this->_assert_(
            $assert,
            exists $tFIELDShash{$name}->{value},
"$this->{test_web}.$this->{test_topic} did not contain a value key in META:FIELD[name='$name']"
          );
        return
          unless $this->_assert_(
            $assert,
            $tFIELDShash{$name}->{value} eq $FIELDShash{$name}->{value},
"'$this->{test_web}.$this->{test_topic}'/META:FIELD[name='$name'].value = '$tFIELDShash{$name}->{value}' but expected '$FIELDShash{$name}->{value}'"
          );
    }

    return;
}

# ->assert() from set_up crashes TestRunner if LocalLib has ASSERTS=1, so die
# differently inside set_up
sub _assert_ {
    my ( $this, $assert, $condition, $message ) = @_;

    if ( !defined $assert || $assert ) {
        $this->assert( $condition, $message );
    }
    elsif ( !$condition ) {
        print STDERR 'ASSERT FAILED during set_up: ' . ( $message || '' );
    }

    return $condition;
}

1;
