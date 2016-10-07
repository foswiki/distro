package ViewFileScriptTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Assert;
use Foswiki();
use Foswiki::UI();
use Foswiki::UI::Viewfile();
use Unit::Request();
use Unit::Request::Attachment();
use Error qw( :try );
use File::Path qw(mkpath);

my $UI_FN;

sub new {
    my ( $class, @args ) = @_;

    #$Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI' ;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    return $class->SUPER::new( "ViewFileScript", @args );
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $topic = 'TestTopic1';
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $topicObject->text('topci1 text');
    $topicObject->save();
    $topicObject->finish();
    $this->sneakAttachmentsToTopic( $this->{test_web}, $topic,
        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );

    $topic = 'SecureTopic';
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $topicObject->text("SecureTopic text\n   * Set ALLOWTOPICVIEW=NoOneReal");
    $topicObject->save();
    $topicObject->finish();
    $this->sneakAttachmentsToTopic( $this->{test_web}, $topic,
        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );

    #set up nested web $this->{test_web}/Nest
    $this->{test_subweb} = $this->{test_web} . '/Nest';
    $topic = 'TestTopic1';

    try {
        $this->createNewFoswikiSession('AdminUser');

        my $webObject = $this->populateNewWeb( $this->{test_subweb} );
        $webObject->finish();
        $this->assert( $this->{session}->webExists( $this->{test_subweb} ) );
        ($topicObject) =
          Foswiki::Func::readTopic( $this->{test_subweb},
            $Foswiki::cfg{HomeTopicName} );
        $topicObject->text("SMELL");
        $topicObject->save();
        $topicObject->finish();
        $this->assert(
            $this->{session}->topicExists(
                $this->{test_subweb}, $Foswiki::cfg{HomeTopicName}
            )
        );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_subweb}, $topic );
    $topicObject->text('nested topci1 text');
    $topicObject->save();
    $topicObject->finish();
    $this->sneakAttachmentsToTopic( $this->{test_subweb}, $topic,
        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );

    $topic = 'SecureTopic';
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_subweb}, $topic );
    $topicObject->text("SecureTopic text\n   * Set ALLOWTOPICVIEW=NoOneReal");
    $topicObject->save();
    $topicObject->finish();
    $this->sneakAttachmentsToTopic( $this->{test_subweb}, $topic,
        ( 'one.txt', 'two.txt', 'inc/file.txt' ) );

    $topic = 'BinaryTopic';
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $topicObject->text('BinaryTopic Text');
    $topicObject->save();
    $topicObject->finish();
    $this->sneakAttachmentsToTopic( $this->{test_web}, $topic,
        ('binaryfile.bin') );

    $topic = 'CasePreservingTopic';
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topic );
    $topicObject->text('CasePreserving Text');
    $topicObject->save();
    $topicObject->finish();
    $this->sneakAttachmentsToTopic( $this->{test_web}, $topic,
        ('CasePreserved.bin') );

    return;
}

sub touchFile {
    my ( $dir, $file ) = @_;
    my $filename = "$dir/$file";
    if ( open( my $FILE, '>', $filename ) ) {
        binmode $FILE;
        if ( $file eq 'binaryfile.bin' || $file eq 'CasePreserved.bin' ) {
            print $FILE "Test\nAttach\rment\r\nEmbed\cZEOF\r\n$file\n";
        }
        else {
            print $FILE "Test attachment $file\n";
        }
        ASSERT( close($FILE) );
    }
    else {
        die "failed ($!) to write to $filename\n";
    }

    return;
}

sub sneakAttachmentsToTopic {
    my ( $this, $web, $topic, @filenames ) = @_;
    my $path = $Foswiki::cfg{PubDir} . "/$web/$topic";
    mkpath($path);

    #print STDERR "DEBUG: dir=$path\n";

    foreach my $file (@filenames) {
        if ( $file =~ m/\// ) {
            my @dirs = split( /\//, $file );
            pop(@dirs);
            foreach my $adir (@dirs) {
                my $lpath = $path . '/' . $adir;
                mkdir($lpath);
            }
        }
        touchFile( $path, $file );
    }

    return;
}

sub viewfile {
    my ( $this, $url, $wantHdrs ) = @_;
    my $query = Unit::Request::Attachment->new( {} );
    $query->setUrl($url);
    $query->method('GET');
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $UI_FN ||= $this->getUIFn('viewfile');
    $this->{request}  = $query;
    $this->{response} = Unit::Response->new();
    my ($text) = $this->capture(
        sub {
            try {
                no strict 'refs';
                &{$UI_FN}( $this->{session} );
                use strict 'refs';
            }
            catch Error with {
                $this->{session}{response}->print( shift->stringify() );
            }
            $Foswiki::engine->finalize( $this->{session}{response},
                $this->{session}{request} );
        }
    );

    ( my $headers, $text ) = $text =~ m/^(.*?)\x0d\x0a\x0d\x0a(.*)/s;

    return ($wantHdrs) ? ( $headers, $text ) : $text;
}

sub test_simpleUrl {
    my $this = shift;

# Note 1: If we decide that trailing / after a topic name and no subweb exists with this name = go for topic name instead
# then we can re-activate these tests marked with Note1. See Foswikitask:Item598

    #simple topic, direct path
    #
    $this->assert_str_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1/one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1/inc/file.txt") );

    return;
}

sub test_oddities {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1//one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_web}//TestTopic1/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1/inc//file.txt") );

    return;
}

sub test_simple_topic_filename_param {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=inc/file.txt")
    );

#Note1 $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=one.txt"));
#Note1 $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=two.txt"));
#Note1 $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=inc/file.txt"));

    return;
}

sub test_nasty_attachment_names {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=/one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_web}/TestTopic1?filename=/inc/file.txt")
    );

    return;
}

sub test_nested_web_simple_topic_direct_path {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1/one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1/inc/file.txt") );

    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1//one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_subweb}//TestTopic1/two.txt") );
    $this->assert_equals( "Test attachment inc/file.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1/inc//file.txt") );

    return;
}

sub test_nested_web_simple_topic_filename_param {
    my $this = shift;
    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=two.txt") );
    $this->assert_equals(
        "Test attachment inc/file.txt\n",
        $this->viewfile(
            "/$this->{test_subweb}/TestTopic1?filename=inc/file.txt")
    );

#Note1 $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=one.txt"));
#Note1 $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=two.txt"));
#Note1 $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=inc/file.txt"));

    $this->assert_equals( "Test attachment one.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=/one.txt") );
    $this->assert_equals( "Test attachment two.txt\n",
        $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=/two.txt") );
    $this->assert_equals(
        "Test attachment inc/file.txt\n",
        $this->viewfile(
            "/$this->{test_subweb}/TestTopic1?filename=/inc/file.txt")
    );

    return;
}

sub test_simple_web_secured_topic_direct_path {
    my $this = shift;

    my $expectedError =
        'AccessControlException: Access to VIEW '
      . $this->{test_web}
      . '.SecureTopic for scum is denied. access not allowed on topic';

    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic/one.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic/two.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic/inc/file.txt") );

    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic//one.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}//SecureTopic/two.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic/inc//file.txt") );

    return;
}

sub test_simple_web_secured_topic_filename_param {
    my $this = shift;

    my $expectedError =
        'AccessControlException: Access to VIEW '
      . $this->{test_web}
      . '.SecureTopic for scum is denied. access not allowed on topic';

    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=one.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=two.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=inc/file.txt")
    );

#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=one.txt"));
#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=two.txt"));
#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>TemporaryViewFileScriptTestWebViewFileScript topic=>SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=inc/file.txt"));

    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=/one.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_web}/SecureTopic?filename=/two.txt") );
    $this->assert_equals(
        $expectedError,
        $this->viewfile(
            "/$this->{test_web}/SecureTopic?filename=/inc/file.txt")
    );

    return;
}

sub test_nested_web_secured_topic_direct_path {
    my $this = shift;

    my $expectedError =
        'AccessControlException: Access to VIEW '
      . $this->{test_subweb}
      . '.SecureTopic for scum is denied. access not allowed on topic';

    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic/one.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic/two.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic/inc/file.txt") );

    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic//one.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}//SecureTopic/two.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic/inc//file.txt") );

    return;
}

sub test_nested_web_secured_topic_filename_param {
    my $this = shift;

    my $expectedError =
        'AccessControlException: Access to VIEW '
      . $this->{test_subweb}
      . '.SecureTopic for scum is denied. access not allowed on topic';

    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=one.txt") );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=two.txt") );
    $this->assert_equals(
        $expectedError,
        $this->viewfile(
            "/$this->{test_subweb}/SecureTopic?filename=inc/file.txt")
    );

#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>'.$this->{test_subweb} topic=>'.SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=one.txt"));
#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>'.$this->{test_subweb} topic=>'.SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=two.txt"));
#Note1 $this->assert_equals('OopsException(accessdenied/topic_access web=>'.$this->{test_subweb} topic=>'.SecureTopic params=>[VIEW,access not allowed on topic])',
#                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=inc/file.txt"));

    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=/one.txt")
    );
    $this->assert_equals( $expectedError,
        $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=/two.txt")
    );
    $this->assert_equals(
        $expectedError,
        $this->viewfile(
            "/$this->{test_subweb}/SecureTopic?filename=/inc/file.txt")
    );

#illegal requests - use .. and funny chars and shell tricks to get access to files outside of life.
#$this->assert_equals("relative path in filename ../SecureTopic/one.txt at /data/home/www/foswiki/trunk/core/lib/Foswiki/Sandbox.pm line 136.\n",
#                    $this->viewfile("/$this->{test_subweb}/TestTopic1/../SecureTopic/one.txt"));
#TODO: add more nasty tricks

    return;
}

sub test_MIME_types {
    my $this = shift;

    $this->assert_equals(
        'application/vnd.adobe.air-application-installer-package+zip',
        Foswiki::UI::Viewfile::_suffixToMimeType('blah.air')
    );
    $this->assert_equals( 'text/h323',
        Foswiki::UI::Viewfile::_suffixToMimeType('blah.323') );
    $this->assert_equals( 'application/octet-stream',
        Foswiki::UI::Viewfile::_suffixToMimeType('blah.w02') );
    $this->assert_equals( 'text/plain',
        Foswiki::UI::Viewfile::_suffixToMimeType('blah.wibble') );

    return;
}

sub test_binary_contents {
    my $this = shift;

    $this->assert_equals(
        "Test\nAttach\rment\r\nEmbed\cZEOF\r\nbinaryfile.bin\n",
        $this->viewfile(
            "/$this->{test_web}/BinaryTopic?filename=/binaryfile.bin")
    );

    return;
}

sub test_simple_textfile {
    my $this = shift;

    # Call viewfile with flag to also return headers

    my ( $headers, $text ) =
      $this->viewfile( "/$this->{test_web}/TestTopic1/one.txt", 1 );

    $this->assert_equals( "Test attachment one.txt\n", $text );
    $this->assert_matches( qr/Content-Type: text\/plain; charset=utf-8/i,
        $headers );
    $this->assert_matches( 'Content-Disposition: inline; filename="one.txt"',
        $headers );

    return;
}

sub test_case_sensitivity {
    my $this = shift;

    # Call viewfile with flag to also return headers

    my ( $headers, $text ) = $this->viewfile(
        "/$this->{test_web}/CasePreservingTopic?filename=/CasePreserved.bin",
        1 );

    $this->assert_equals(
        "Test\nAttach\rment\r\nEmbed\cZEOF\r\nCasePreserved.bin\n", $text );
    $this->assert_matches( "Content-Type: application/octet-stream", $headers );
    $this->assert_matches(
        'Content-Disposition: inline; filename="CasePreserved.bin"', $headers );

    return;
}
1;
