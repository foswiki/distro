# See bottom of file for license and copyright information

package Unit::PlackTestCase;
use v5.14;

=begin TML

---+ package Unit::PlackTestCase

Testing %WIKITOOLNAME% with =Plack::Test=.

---++ Concepts

This class providing framework for testing %WIKITOOLNAME% with
=[[CPAN:Plack::Test][Plack::Test]]=. It must be subclassed to create a test
case. In turn, it subclasses _Unit::TestCase_ and as such inherits most of its
functionality.

---+++ List of tests

A test within test case can be defined in two ways. The first one is similar to
=Unit::TestCase= behaviour of looking for functions with =test= prefix. Except
that a Plack test case function must be prefixed with =client=. The different
prefix is here to avoid messing up with =Unit::TestCase= because this
framework's tests are called with different parameters.

The other way is to override method
=[[#PrepareTestClientList][prepareTestClientList()]]= and define your own list
of tests. Each test in the list is defined by a hash of its properties. See
=[[#testClientList][testClientList]]= object attribute description to read about
them.

#InitDeinit
---+++ Initialization/deinitialization of tests

In addition to =Unit::TestCase= =set_up()= and =tear_down()= methods this
framework provide additional layers of initialization/deinitialization. Those
are =initTest/shutdownTest= and =initRequest/shutdownRequest=. Their use is
preferred because they provide better per-test support.

The reason for separate init/deinit methods lies in the fact =Plack::Test= actually
create a new application instance for each request being executed. This means different
run time environments for the test code and the application code processing the request.

=initTest/shutdownTest= are executed right before and after the client (test) function is called.

=initRequest= is executed as early as possible in =Foswiki::App= object
construction stage. Practically it means it's initiated using =postConfig=
callback which is raised right after LSC is being read (or bootstrapped) but
before any other =Foswiki::App= subsystem is initialized. This allows us to
patch the config in a way we require and have the effect we desire in simpliest
way possible.

=shutdownRequest= is executed right after the request has been processed and
before response is been returned.

Note that this approach let us have all temporary artefacts being shared across
both test and application environments creating semi-permanent sandbox which
simulates a real-life case of a session in action.

For each of the four init/deinit stages there is a key in test profile hash with
the same name. The key must be a code ref allowing easy adjustments being made
on a per-test level. In other words, instead of writing somethingl like this:

<verbatim>
around initRequest => sub {
    my $orig = shift;
    my $this = shift;
    my %args = @_;
    
    $orig->($this, @_);
    
    if ($args{testParams}{name} eq 'Test1') {
        ...; # Do something specific for Test1
    }
};
</verbatim>

we can have it this way:

<verbatim>
around prepareTestClientList => sub {
    my $orig = shift;
    my $this = shift;
      
    my $tests = $orig->($this, @_);
    
    push @$tests, (
        {
            name => 'Test1',
            client => \&_test1, # Actual test code
            initRequest => sub {
                ...; # Do something specific for this test
            },
        },
    );
    return $tests;
};

This way it is much easier to control all test-specific details.

</verbatim>

=cut

use Plack::Test;
use File::Spec;
use Assert;
use Try::Tiny;
use HTML::Parser;
require Unit::TestRunner;

use Foswiki::Class;
extends qw(Unit::TestCase);
with qw(Foswiki::Aux::Localize Unit::FoswikiTestRole);

=begin TML

#testClientList
---++ ObjectAttribute testClientList : arrayref

List of hashrefs with test parameters. Each hash ref may have the following keys:

Keys:

|*Key*|*Attributes*|*Description*|*Default*|
| =name= | _required_ | Test name. Must be a valid Perl identifier. | |
| =client= | _required_ | Reference to the test sub. | |
| =appClass= | | Defines class of application object. | =Unit::TestApp= |
| =appParams= | | Hash of application constructor parameters. See the application class documentation. | ={}= |
| =initTest= | | Coderef to test-specific init sub | |
| =shutdownTest= | | Coderef to test-specific deinitialize sub | |
| =initRequest= | | Coderef to test-specific request init sub | |
| =shutdownRequest= | | Coderef to test-specific request deinitialize sub | |
| =adminUser= | | Default admin user defined by a hashref of =wikiname=, =login=, =group= keys. | See =Unit::FoswikiTestRole= =setupAdminUser()= method. |
| =testWebs= | | Hash of webs to create for this test. Keys define web names. Values are hashes of ='TopicName' => "Topic Text"= pairs. | |
| =testUsers= | | List of users to create for this test. Elements are hashes with keys =login=, =forename=, =surname=, =email=, =group= describing each user. | |

*Example*

<verbatim>
around prepareTestClientList => sub {
    my $orig  = shift;
    my $this  = shift;
    my $tests = $orig->( $this, @_ );

    my $sameplTestWeb = $this->testWebName('SampleTest');
    push @$tests, (
        {
            name => sample_test,
            client => \&_sample_test,
            appParams => {
                requestParams => {
                    initializer => '',
                },
                engineParams => {
                    user => $this->app->cfg->{AdminUserLogin},
                    method => 'GET',
                    path => "/$sampleTestWeb/" . "SampleTestTopic1",
                },
            },
            initRequest => sub {
                my $this = shift;
                $this->app->cfg->data->{DisableAllPlugins} = 1;
            },
            adminUser => {
                wikiname => 'SampleAdmin',
                login => 'sadmin',
                group => 'SampleAdminGroup',
            },
            testWebs => {
                $sampleTestWeb => {
                    SampleTestTopic1 => "This is test topic 1.",
                    SampleTestTopic2 => "This is test topic 2.",
                },
                ThisWebNameIsNotGood => {
                    # This web name is not recommended for tests.
                    UselessTopic => "Text doesn't matter.",  
                },
                $this->testWebName("PreferableUse") => {
                    # This is how web names should be formed.
                    AnotherTopic => "This is a topic from web with recommended name",  
                },
            },
            testUsers => [
                {
                    login    => 'user1',
                    forename => 'User1',
                    surname  => 'SurUser1',
                    email    => 'user1@example.com',
                    group    => 'TestGroup',
                },
                {
                    login    => 'user2',
                    forename => 'User2',
                    surname  => 'SurUser2',
                    email    => 'user2@example.com',
                    group    => 'TestGroup',
                },
            ],
        },
    );
    
    return $tests;
};
</verbatim>

=cut 

has testClientList => (
    is      => 'rw',
    lazy    => 1,
    isa     => Foswiki::Object::isaARRAY( 'testList', noUndef => 1, ),
    builder => 'prepareTestClientList',
);

=begin TML
---++ ObjectAttribute defaultAppClass

Default name of the class to instantiate the application object.

*Important note* Because a lot of this class' functionality depends upon
=Unit::TestApp= provided services the replacement class must either subclass it
or mimic the behaviour. 

=cut

has defaultAppClass => (
    is      => 'rw',
    default => 'Unit::TestApp',
);

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $this->leakDetectCheckpoint( $this->testSuite );

    return $orig->( $this, @_ );
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    $this->leakDetectDump( $this->testSuite );

    return $orig->( $this, @_ );
};

# Executes coderefs defined by test parameters keys initTest, initRequest, shutdownTest, shutdownRequest.
sub _execPerTestStageCode {
    my $this      = shift;
    my $stageName = shift;
    my %args      = @_;

    if ( defined( $args{testParams}{$stageName} ) ) {
        my $stageSub = $args{testParams}{$stageName};
        $this->assert( ref($stageSub) eq 'CODE',
            "testParams $stageName key must be a coderef" );
        $stageSub->( $this, @_ );
    }
}

=begin TML

---++ ObjectMethod initTest(%args)

This methods gets called right before every individual test is been run.

=%args= contains following keys:

| *Key* | *Description* |
| =testParams= | Hash of parameters of the next test to be run. See =testClientList= attribute description. |
| =plackTestObj= | A instance of =Plack::Test= class. |

=cut

sub initTest {
    my $this = shift;
    my %args = @_;

    my $params = $args{testParams};

    $this->preserveEnvironment;

    $this->setupPlugins;
    $this->setupDirs;
    $this->setupUserRegistration;
    $this->setupAdminUser( %{ $params->{adminUser} // {} } );
    $this->populateStandardWebs;

    if ( defined $params->{testWebs} ) {
        $this->assert(
            ref( $params->{testWebs} ) eq 'HASH',
            "Test parameters testWebs key isn't a hashref"
        );

        foreach my $web ( keys %{ $params->{testWebs} } ) {
            $this->populateNewWeb($web);
            if ( defined $params->{testWebs}{$web} ) {
                my $topics = $params->{testWebs}{$web};
                ASSERT( ref($topics) eq 'HASH',
                    "Test web $web topics must be defined with a hashref" );
                foreach my $topic ( keys %{$topics} ) {
                    $this->writeTopic( $web, $topic, $topics->{$topic} );
                }
            }
        }
    }

    if ( defined $params->{testUsers} ) {
        $this->assert(
            ref( $params->{testUsers} ) eq 'ARRAY',
            "Test parameters testUsers key isn't an arrayref"
        );

        foreach my $user ( @{ $params->{testUsers} } ) {
            $this->assert(
                defined($user) && ( ref($user) eq 'HASH' ),
                "Non-hashref element of testUsers array"
            );
            my @registerKeys = qw(login forename surname email);
            $this->assert( defined $user->{$_},
                "Undefined key `$_' in user element of testUsers array" )
              foreach @registerKeys;
            $this->registerUser( @{$user}{@registerKeys} );
            if ( $user->{group} ) {
                unless ( $this->app->users->isGroup( $user->{group} ) ) {
                    $this->assert(
                        $this->app->addUserToGroup(
                            $this->app->user, $user->{group}, 1
                        )
                    );
                }
                $this->assert(
                    $this->app->addUserToGroup(
                        $user->{login}, $user->{group}
                    )
                );
            }
        }
    }

    $this->_execPerTestStageCode( 'initTest', @_ );
}

=begin TML

---++ ObjectMethod shutdownTest(%args)

This method is been called right after each individual test finishes. =%args=
keys are the same as in =initTest()=.

=cut

sub shutdownTest {
    my $this = shift;

    $this->_execPerTestStageCode( 'shutdownTest', @_ );

    $this->cleanupTestWebs;
    $this->_clear_tempDir;
    $this->restoreEnvironment;
}

=begin TML

---++ ObjectMethod initRquest( %args )

This method is called in server context upon every request. See the section
about [[#InitDeinit][initialization/deinitialization]].

=%args= contains following keys:

| *Key* | *Description* |
| =data= | Callback user supplied data. Because callbacks are registered using =Unit::TestApp= =registerCallbacks()= method this would be a hash with the only key =app= pointing to the server application object. |
| =params= | Callback caller suplpied parameters. =postConfig= doesn't provide any so this is gonna be undef but it may change is the future. |
| =serverApp= | Points to server application object. It duplicates data's =app= key but is here to code readability. |
| =testParams= | Hash of parameters of the next test to be run. See =testClientList= attribute description. |

Note that this method is called on the test case object and =$this->app= points
to test case's application instance which is different from =serverApp= key.

=cut

sub initRequest {
    my $this = shift;
    my %args = @_;

    my $params = $args{testParams};

    $this->setupPlugins;
    $this->setupDirs;
    $this->setupUserRegistration;
    $this->setupAdminUser( %{ $params->{adminUser} // {} } );

    $this->_execPerTestStageCode( 'initRequest', @_ );
}

=begin TML

---++ ObjectMethod shutdownRequest( %args )

This methods is called when request processing is finished right before sending
back a response.

=%args= is the same as for =initRequest()= method.

=cut

sub shutdownRequest {
    my $this = shift;

    $this->_execPerTestStageCode( 'shutdownRequest', @_ );
}

=begin TML

---++ ObjectMethod list_tests() => @tests

Completely overrides =list_tests()= from =Unit::TestCase=. Prepares tests using
=testClientList= attribute.

=cut

around list_tests => sub {
    my $orig = shift;
    my $this = shift;

    my @tests;

    my $suite = $this->testSuite;
    foreach my $clientHash ( @{ $this->testClientList } ) {

        # SMELL name must be checked to be a valid Perl identifier too.
        $this->assert_not_null( $clientHash->{name},
            "client test name is undefined" );
        $this->assert_not_null( $clientHash->{client},
            "client $clientHash->{name} code is undefined" );

        unless ( defined $clientHash->{appSub} ) {
            $clientHash->{appSub} = $this->_genDefaultAppSub($clientHash);
        }
        my $testSubName = "test_" . $clientHash->{name};
        unless ( $suite->can($testSubName) ) {
            no strict 'refs';
            *{"$suite\:\:$testSubName"} = sub {
                my $test = Plack::Test->create( $clientHash->{appSub} );
                $this->initTest(
                    testParams   => $clientHash,
                    plackTestObj => $test
                );
                $clientHash->{client}->(
                    $this,
                    testParams   => $clientHash,
                    plackTestObj => $test,
                );
                $this->shutdownTest(
                    testParams   => $clientHash,
                    plackTestObj => $test
                );
            };
            use strict 'refs';
        }
        push @tests, $testSubName;
    }

    return @tests;
};

=begin TML

#PrepareTestClientList
---++ ObjectMethod prepareTestClientList() => @testList

=testClientList= object attribute initializer.

Reads all subs with names prefixed by 'client' and builds a list of these tests.
For a test case to build a manual list of tests this methods must be overriden.

=cut

sub prepareTestClientList {
    my $this = shift;
    my @tests;
    my $suite = $this->testSuite;

    my $clz = new Devel::Symdump($suite);
    foreach my $method ( $clz->functions ) {
        next unless $method =~ /^$suite\:\:(client(.+))$/;
        my $subName   = $1;
        my $shortName = $2;
        push @tests, { name => $shortName, client => $suite->can($subName), };
    }
    return \@tests;
}

sub _cbPostConfig {
    my $this       = shift;
    my $app        = shift;
    my $clientHash = shift;
    my %args       = @_;

    $this->initRequest( %args, testParams => $clientHash, serverApp => $app, );
}

sub _cbPostHandleRequest {
    my $this       = shift;
    my $app        = shift;
    my $clientHash = shift;
    my %args       = @_;

    $this->shutdownRequest(
        %args,
        testParams => $clientHash,
        serverApp  => $app,
    );
}

sub _genDefaultAppSub {
    my $this = shift;
    my ($clientHash) = @_;

    my %runArgs = %{ $clientHash->{appParams} // {} };

    # Users must not use this callback.
    $runArgs{callbacks}{postConfig} = sub {
        my $app = shift;
        $this->_cbPostConfig( $app, $clientHash, @_ );
    };
    $runArgs{callbacks}{testPostHandleRequest} = sub {
        my $app = shift;
        $this->_cbPostHandleRequest( $app, $clientHash, @_ );
    };

    return sub {
        my $env = shift;

        $runArgs{env} = { ( %$env, %{ $clientHash->{appParams}{env} // {} } ) };

        my $appClass = $clientHash->{appClass} // $this->defaultAppClass;

        my $rc = $appClass->run(%runArgs);

        return $rc;
    };
}

=begin TML

---++ ObjectMethod writeTopic( $web, $topic, $text ) => $topicObject 

Simple shortcut for creating a topic defined by =$web= and =$topic= using
=$text=.

Returns initialized =Foswiki::Meta= object.

=cut

sub writeTopic {
    my $this = shift;
    my ( $web, $topic, $text ) = @_;

    my ($topicObj) = $this->app->readTopic( $web, $topic );
    ASSERT( defined $topicObj, "Failed to read or create topic `$topic'" );
    $topicObj->text($text);
    $topicObj->save;
    return $topicObj;
}

=begin TML

---++ ObjectMethod findHTMLTag( $html, %criteria ) => $matchedEntity

Simple search for a particular tag in HTML page in =$html= parameter.
=%criteria= hash must contain mandatory key =tag= which defines HTML entity to
look for ('a', 'input', 'form', etc.). Optionally it may have =text= key which
defines what text must exists between opening and closing tags of the entity.
All other keys are considered tag attributes.

Values of the criteria hash could be either simple text values or regexps defined
with =qr//= quote.

Text must not be a single entity and not split by any HTML tags. For example, if
we're looking for a word 'Attach' then the following example will fail to match:

<verbatim>
<span class="underscore">A</span>ttach
</verbatim>

When criteria hash doesn't have the =text= key the first matching entity will be
returned. Otherwise the one directly enclosing the text is returned.

Return a hash ref describing the matched entity. The hash contains keys =tag=, =attrs=
(entity attributes), =text=.

*Examples*

|*HTML*| <verbatim><div class="class1">...<form class="class1" id="formID">...<div class="class2">Test text</div>...</form>...</div></verbatim> |

---++++ Simple tag search

<verbatim>
$this->findHTMLTag(
    $html,
    tag => 'div',
);
</verbatim>

Returns: <verbatim>
{
    tag => 'div',
    attrs => { class => 'class1' },
}
</verbatim>

---++++ Search with text

<verbatim>
$this->findHTMLTag(
    $html,
    tag => 'div',
    text => qr/Test\s/,
);
</verbatim>

Returns: <verbatim>
{
    tag => 'div',
    attrs => { class => 'class2' },
    text => 'Test text',
}
</verbatim>

---++++ Attribute search with text

<verbatim>
$this->findHTMLTag(
    $html,
    tag => qr/./,
    class => 'class1',
    text => qr/Test\s/,
);
</verbatim>

Returns: <verbatim>
{
    tag => 'form',
    attrs => { class => 'class1', id => "formID", },
    text => 'Test text',
}
</verbatim>

=cut

sub _smartMatch {
    my $this = shift;
    my ( $text, $pattern ) = @_;

    if ( my $refType = ref($pattern) ) {
        if ( $refType eq 'Regexp' ) {
            return $text =~ $pattern;
        }
        elsif ( $refType eq 'CODE' ) {
            return $pattern->( $this, $text );
        }
        ASSERT( 0, "Cannot match against $refType reference" );
    }
    return $text eq $pattern;
}

sub findHTMLTag {
    my $this   = shift;
    my $html   = shift;
    my %params = @_;

    ASSERT( defined $params{tag}, "tag key required" );
    my $tagPat  = $params{tag};
    my $textPat = $params{text};

    $tagPat = lc($tagPat) unless ref($tagPat);

    delete @params{qw(tag text)};

    my $parser = HTML::Parser->new( api_version => 3, );

    my @entStack;
    my $lastCandidate;

    my $matchedEntity;

    $parser->handler(
        start => sub {
            my ( $tag, $attrs, $p ) = @_;
            return unless $this->_smartMatch( $tag, $tagPat );
            my $matches = 1;
            foreach my $attrName ( keys %params ) {
                $matches &&= defined( $attrs->{$attrName} )
                  && $this->_smartMatch( $attrs->{$attrName},
                    $params{$attrName} );
            }
            my $entity = {
                tag     => $tag,
                attrs   => $attrs,
                matches => $matches,
            };
            if ( $matches && !$textPat ) {

                # No text pattern defined, first matched entity is ok.
                $matchedEntity = $entity;
                $p->eof;
                return;
            }
            $lastCandidate = $entity if $matches;
            push @entStack, $entity;
        },
        "tagname,attr,self"
    );

    $parser->handler(
        end => sub {
            my ( $tag, $text, $p ) = @_;
            if ( $lastCandidate
                && ( !$textPat || $this->_smartMatch( $text, $textPat ) ) )
            {
                $matchedEntity = $lastCandidate;
                $matchedEntity->{text} = $text;
                $p->eof;
                return;
            }
            return unless $this->_smartMatch( $tag, $tagPat );
            my $lastEntity = pop @entStack;
            if ( $lastCandidate && $lastEntity eq $lastCandidate ) {
                undef $lastCandidate;
            }
        },
        "tagname,skipped_text,self"
    );

    $parser->parse($html);

    delete $matchedEntity->{matched};
    return $matchedEntity;
}

# Localization support
around setLocalizeFlags => sub {
    my $orig = shift;

    # Don't clean app on localizing as we might need it until the new one is
    # created.
    return $orig->(@_), clearAttributes => 0;
};

sub setLocalizableAttributes {
    return qw(app);
}

=begin TML

---++ See Also

=Foswiki::Aux::Localize=, =Unit::FoswikiTestRole=, =Plack::Test=,
=[[CPAN:HTTP::Request::Common][HTTP::Request::Common]]=.


=cut

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
