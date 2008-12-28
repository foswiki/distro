use strict;

package ViewFileScriptTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );

my $twiki;

sub new {
    #$Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI' ;
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    my $self = shift()->SUPER::new("ViewFileScript", @_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $twiki = $this->{twiki};
    my $topic = 'TestTopic1';
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, $topic,
        'topci1 text', undef );
    $this->sneakAttachmentsToTopic($this->{test_web}, $topic, ('one.txt', 'two.txt', 'inc/file.txt'));

    $topic = 'SecureTopic';
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, $topic,
        "SecureTopic text\n   * Set ALLOWTOPICVIEW=NoOneReal", undef );
    $this->sneakAttachmentsToTopic($this->{test_web}, $topic, ('one.txt', 'two.txt', 'inc/file.txt'));

    #set up nested web $this->{test_web}/Nest
    $this->{test_subweb} = $this->{test_web}.'/Nest';
    $topic = 'TestTopic1';

    try {
        $this->{twiki} = new Foswiki('AdminUser');

        $this->{twiki}->{store}->createWeb( $this->{twiki}->{user}, $this->{test_subweb} );
        $this->assert( $this->{twiki}->{store}->webExists( $this->{test_subweb} ) );
        $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user},
                                    $this->{test_subweb},
                                    $Foswiki::cfg{HomeTopicName},
                                    "SMELL" );
        $this->assert( $this->{twiki}->{store}->topicExists(
            $this->{test_subweb}, $Foswiki::cfg{HomeTopicName} ) );

    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_subweb}, $topic,
        'nested topci1 text', undef );
    $this->sneakAttachmentsToTopic($this->{test_subweb}, $topic, ('one.txt', 'two.txt', 'inc/file.txt'));

    $topic = 'SecureTopic';
    $twiki->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_subweb}, $topic,
        "SecureTopic text\n   * Set ALLOWTOPICVIEW=NoOneReal", undef );
    $this->sneakAttachmentsToTopic($this->{test_subweb}, $topic, ('one.txt', 'two.txt', 'inc/file.txt'));
}

sub touchFile {
    my ($dir, $file) = @_;
    my $filename = "$dir/$file";
    if (open( my $FILE, '>', $filename )) {
        print $FILE "Test attachment $file\n";
        close($FILE);
    } else {
        die "failed ($!) to write to $filename\n";
    }
}
sub sneakAttachmentsToTopic {
    my $this = shift;
    my ($web, $topic, @filenames) = @_;
    my $dir = $Foswiki::cfg{PubDir};
    $dir = "$dir/$web/$topic";
    {
        my @dirs = split(/\//, $dir);
        my $path = '';
        foreach my $adir (@dirs) {
            $path .= '/'.$adir;
            mkdir($path) unless (-e $path);
        }
    }
    #print STDERR "DEBUG: dir=$dir\n";

    foreach my $file (@filenames) {
        if ($file =~ /\//) {
            my @dirs = split(/\//, $file);
            pop(@dirs);
            my $path = $dir;
            foreach my $adir (@dirs) {
                $path .= '/'.$adir;
                mkdir($path);
            }
        }
        touchFile($dir, $file);
    }
}

sub viewfile {
    my ( $this, $url ) = @_;
    my $query = new Unit::Request({});
    $query->setUrl( $url );
    $query->method('GET');
    $twiki = new Foswiki( $this->{test_user_login}, $query );
    $this->{request}  = $query;
    $this->{response} = new Unit::Response();
    my ($text, $result) = $this->capture(
        sub {
            try {
                Foswiki::UI::View::viewfile( $twiki);
            } catch Error with {
                $twiki->{response}->print(shift->stringify());
            }
            $Foswiki::engine->finalize(
                $twiki->{response},
                $twiki->{request});
        });

#print STDERR "HUH $twiki->{response}->{body}\n>$text<>$result<\n";
    $twiki->finish();

    return $result;
}

sub test_simpleUrl {
    my $this = shift;

#simple topic, direct path
    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/inc/file.txt"));

    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1//one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_web}//TestTopic1/two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/inc//file.txt"));

#simple topic, filename param
    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1?filename=one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1?filename=two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1?filename=inc/file.txt"));

    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1/?filename=inc/file.txt"));

    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1?filename=/one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1?filename=/two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_web}/TestTopic1?filename=/inc/file.txt"));

#nested web, simple topic, direct path
    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/inc/file.txt"));

    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1//one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_subweb}//TestTopic1/two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/inc//file.txt"));
#nested web, simple topic, filename param
    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=inc/file.txt"));

    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1/?filename=inc/file.txt"));

    $this->assert_equals("Test attachment one.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=/one.txt"));
    $this->assert_equals("Test attachment two.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=/two.txt"));
    $this->assert_equals("Test attachment inc/file.txt\n", $this->viewfile("/$this->{test_subweb}/TestTopic1?filename=/inc/file.txt"));

#simple web, secured topic, direct path
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic/one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic/two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic/inc/file.txt"));

    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic//one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}//SecureTopic/two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic/inc//file.txt"));

#simple web, secured topic, filename param
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic?filename=one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic?filename=two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic?filename=inc/file.txt"));

    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic/?filename=inc/file.txt"));

    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic?filename=/one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic?filename=/two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW TemporaryViewFileScriptTestWebViewFileScript.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_web}/SecureTopic?filename=/inc/file.txt"));

#nested web, secured topic, direct path
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic/one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic/two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic/inc/file.txt"));

    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic//one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}//SecureTopic/two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic/inc//file.txt"));

#nested web, secured topic, filename param
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=inc/file.txt"));

    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic/?filename=inc/file.txt"));

    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=/one.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=/two.txt"));
    $this->assert_equals('AccessControlException: Access to VIEW '.$this->{test_subweb}.'.SecureTopic for scum is denied. access not allowed on topic',
                            $this->viewfile("/$this->{test_subweb}/SecureTopic?filename=/inc/file.txt"));

#illegal requests - use .. and funny chars and shell tricks to get access to files outside of life.
    #$this->assert_equals("relative path in filename ../SecureTopic/one.txt at /data/home/www/nextwiki/trunk/core/lib/Foswiki/Sandbox.pm line 136.\n",
    #                    $this->viewfile("/$this->{test_subweb}/TestTopic1/../SecureTopic/one.txt"));
#TODO: add more nasty tricks
}

sub test_MIME_types {
    my $this = shift;

    $this->assert_equals(
        'application/vnd.adobe.air-application-installer-package+zip',
        Foswiki::UI::View::_suffixToMimeType('blah.air'));
    $this->assert_equals(
        'text/h323',
        Foswiki::UI::View::_suffixToMimeType('blah.323'));
    $this->assert_equals(
        'application/octet-stream',
        Foswiki::UI::View::_suffixToMimeType('blah.w02'));
    $this->assert_equals(
        'text/plain',
        Foswiki::UI::View::_suffixToMimeType('blah.wibble'));
}

1;
