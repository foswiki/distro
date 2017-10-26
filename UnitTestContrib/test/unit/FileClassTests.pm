package FileClassTests;

use Foswiki;
use Try::Tiny;

use Foswiki::File;

use File::Temp qw(tempfile tempdir);

use Foswiki::Class;
extends qw(FoswikiTestCase);

has tempFile => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareTempFile',
);

# tempSubDir allows for a temporary subdir in tempDir where it would be
# guaranteed that it is empty.
has tempSubDir => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareTempSubDir',
);

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    $this->clear_tempFile;
    $this->clear_tempSubDir;
};

sub prepareTempFile {
    my $this = shift;

    my ( $fh, $fname ) = tempfile( DIR => $this->tempDir );

    print $fh "This is a test content";

    $fh->close;
    return $fname;
}

sub prepareTempSubDir {
    my $this = shift;

    my $tmpSubDir = File::Temp->newdir(
        DIR      => $this->tempDir,
        TEMPLATE => $this->testSuite . '.XXXXXX',
    );

    return $tmpSubDir;
}

sub test_read {
    my $this = shift;

    my $fobj = $this->create( 'Foswiki::File', path => $this->tempFile );

    $this->assert_equals( "This is a test content", $fobj->content );

    open my $fh, ">:encoding(utf8)", $this->tempFile;
    print $fh "А це у нас юнікод";
    close $fh;

    $fobj->clear_content;
    $this->assert_equals( "А це у нас юнікод", $fobj->content );
}

sub test_write {
    my $this = shift;

    my $fobj = $this->create(
        'Foswiki::File',
        path      => $this->tempFile,
        autoWrite => 1,
    );

    my $testContent = <<EOT;
This is test content
І щоб двічи не вставати – із юнікодом
та багаторядковою структурою.
EOT

    $fobj->content($testContent);

    $fobj->clear_content;

    $this->assert_equals( $testContent, $fobj->content );

    $fobj->autoWrite(0);
    $fobj->content("This content won't be stored.");

    $fobj->clear_content;

    $this->assert_equals( $testContent, $fobj->content );
}

sub test_autoCreate {
    my $this = shift;

    my $newFileName = File::Spec->catfile( $this->tempSubDir, "ANewFile" );

    my $fobj = $this->create(
        'Foswiki::File',
        path       => $newFileName,
        autoCreate => 1,
    );

    $this->assert_equals( $fobj->stat, undef, "" );

    $fobj->content("Anything");
    $fobj->flush;

    $this->assert( defined $fobj->stat,
        "stat attribute must be defined after flush" );

    $this->assert( -e $newFileName, "can't find auto-created file" );
}

sub test_statOnUnreadable {
    my $this = shift;

    my $oldMask = umask(0477);

    my $unreadFile = File::Spec->catfile( $this->tempSubDir, "UnreadableFile" );

    $this->assert(
        open( my $fh, ">", $unreadFile ),
        "can't create " . $unreadFile . ": " . $!
    );
    close $fh;

    umask($oldMask);

    try {
        $this->assert(
            !-r $unreadFile,
            "test code failed: cannot create unreadable file in " . $unreadFile
        );

        my $fobj = $this->create( "Foswiki::File", path => $unreadFile, );
        $fobj->stat;

        $this->assert( 0,
            "File object has been created instead of raising an exception" );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        $this->assert( $e->isa('Foswiki::Exception::FileOp'),
                "wrong exception "
              . ref($e)
              . ": Foswiki::Exception::FileOp is excepted" );
        $this->assert_matches( 'Failed to stat .*: don\'t have read access to ',
            $e->stringify, "wrong exception text" );
    };
}

1;
