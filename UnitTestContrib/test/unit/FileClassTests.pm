package FileClassTests;

use Foswiki;
use Try::Tiny;

use Foswiki::File;

use File::Temp qw(tempfile);

use Foswiki::Class;
extends qw(FoswikiTestCase);

has tempFile => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareTempFile',
);

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    $this->clear_tempFile;
};

sub prepareTempFile {
    my $this = shift;

    my ( $fh, $fname ) = tempfile( DIR => $this->tempDir );

    print $fh "This is a test content";

    $fh->close;
    return $fname;
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

1;
