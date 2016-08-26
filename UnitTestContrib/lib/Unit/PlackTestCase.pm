# See bottom of file for license and copyright information

=begin TML

---+ package Unit::PlackTestCase

Base class for all =Plack::Test= based tests.

=cut

package Unit::PlackTestCase;
use v5.14;

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

---++ ObjectAttribute testClientList : arrayref

List of hashrefs with test parameters.

Keys:

   * =app=
   * =appClass=
   * =appParams=
   * =client= - required, client sub
   * =init= – additional init sub for test
   * =adminUser= - hashref, {wikiname=>'AdminUserWikiName', login => 'admin', group => 'AdminGroup',}; see =Unit::FoswikiTestRole= =setupAdminUser= method.
   * =testWebs= – hash of test webs to be created for the test where each key is a hashref to topicName => "topic text",
   * =testUsers= - array of users to be registered for testing purposes. Each element is a hashref with keys =login=, =forename=, =surname=, =email=, =group=; see =Unit::FosdwikiTestRole= =registerUser()= method.

=cut 

has testClientList => (
    is      => 'rw',
    lazy    => 1,
    isa     => Foswiki::Object::isaARRAY( 'testList', noUndef => 1, ),
    builder => 'prepareTestClientList',
);
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

sub shutdownTest {
    my $this = shift;

    $this->_execPerTestStageCode( 'shutdownTest', @_ );

    $this->cleanupTestWebs;
    $this->_clear_tempDir;
    $this->restoreEnvironment;
}

sub initRequest {
    my $this = shift;

    $this->_execPerTestStageCode( 'initRequest', @_ );
}

sub shutdownRequest {
    my $this = shift;

    $this->_execPerTestStageCode( 'shutdownRequest', @_ );
}

around list_tests => sub {
    my $orig = shift;
    my $this = shift;

    my @tests;

    my $suite = $this->testSuite;
    foreach my $clientHash ( @{ $this->testClientList } ) {

        $this->assert_not_null( $clientHash->{name},
            "client test name undefined" );

        unless ( defined $clientHash->{appSub} ) {
            $clientHash->{appSub} = $this->_genDefaultAppSub($clientHash);
        }
        my $testSubName = "test_" . $clientHash->{name};
        unless ( $suite->can($testSubName) ) {
            no strict 'refs';
            *{"$suite\:\:$testSubName"} = sub {
                my $test = Plack::Test->create( $clientHash->{appSub} );
                $this->initTest(
                    testParams => $clientHash,
                    testObject => $test
                );
                $clientHash->{client}
                  ->( $this, testParams => $clientHash, testObject => $test, );
                $this->shutdownTest(
                    testParams => $clientHash,
                    testObject => $test
                );
            };
            use strict 'refs';
        }
        push @tests, $testSubName;
    }

    return @tests;
};

sub prepareTestClientList {
    my $this = shift;
    my @tests;
    my $suite = $this->testSuite;

    my $clz = new Devel::Symdump($suite);
    foreach my $method ( $clz->functions ) {
        next unless $method =~ /^$suite\:\:(client_(.+))$/;
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

    $this->saveState;
    $this->app($app);
    $this->initRequest( %args, testParams => $clientHash );
}

sub _cbPostHandleRequest {
    my $this       = shift;
    my $app        = shift;
    my $clientHash = shift;
    my %args       = @_;

    $this->shutdownRequest( %args, testParams => $clientHash, );
    $this->restoreState;
}

sub _genDefaultAppSub {
    my $this = shift;
    my ($clientHash) = @_;

    my %runArgs = %{ $clientHash->{appParams} // {} };

    my $appClass = $clientHash->{appClass} // $this->defaultAppClass;

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

        my $rc = $appClass->run(%runArgs);

        return $rc;
    };
}

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
<verbtaim>
$this->findHTMLTag(
    tag => 'a',
    class => qr//,
    text => 'Attach',
);
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
