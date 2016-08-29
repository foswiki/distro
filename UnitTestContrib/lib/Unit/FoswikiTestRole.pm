# See bottom of file for license and copyright

=begin TML

---+ Role Unit::FoswikiTestRole

This role provide methods common to all high-level test case classes bound to
Foswiki API.

=cut

package Unit::FoswikiTestRole;

use Assert;
use Try::Tiny;
use File::Spec;
use Scalar::Util qw(blessed);
use Foswiki::Exception;

BEGIN {
    if (Unit::TestRunner::CHECKLEAK) {
        eval "use Devel::Leak::Object qw{ GLOBAL_bless };";
        die $@ if $@;
        $Devel::Leak::Object::TRACKSOURCELINES = 1;
        $Devel::Leak::Object::TRACKSTACK       = 1;
    }
}

# Use variable to let it be easily incorporated into a regex.
our $TEST_WEB_PREFIX = 'Temporary';

use Moo::Role;

our @mails;

=begin TML
---++ ObjectAttribute app

Test case application object.

=cut

has app => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    isa => Foswiki::Object::isaCLASS( 'app', 'Unit::TestApp', noUndef => 1, ),
    default => sub {
        if ( defined $Foswiki::app ) {
            return $Foswiki::app;
        }
        return Unit::TestApp->new( env => \%ENV );
    },
    handles => [qw(create)],
);

=begin TML
---++ ObjectAttribute test_web

Default test web name.

=cut

has test_web => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { return $_[0]->testWebName; },
);

=begin TML
---++ ObjectAttribute test_topic

Default test topic name.

=cut

has test_topic => (
    is      => 'rw',
    lazy    => 1,
    default => sub { return 'TestTopic' . $_[0]->testSuite; },
);

=begin TML
---++ ObjectAttribute test_topic

Default users web for test.

=cut

has users_web => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareUsersWeb',
);

has _holderStack => ( is => 'rw', lazy => 1, default => sub { [] }, );

# List of webs created with populateNewWeb method.
has _testWebs => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub { [] },
);

has __FoswikiSafe => ( is => 'rw', );
has __EnvSafe => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);

=begin TML

---++ ObjectAttribute __EnvReset

__EnvReset defines environment variables to be deleted or set to predefined
values. If a variable key has undefined value then it is deleted. Otherwise it
is set to the value defined.

=cut

has __EnvReset => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    @mails = ();
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    @mails = ();
    $this->app->net->setMailHandler( \&sentMail );

    $orig->( $this, @_ );
};

sub prepareUsersWeb {
    return $TEST_WEB_PREFIX . $_[0]->testSuite . 'UsersWeb';
}

=begin TML

---++ ObjectMethod registerUser($loginname, $forename, $surname, $email)

Can be used by subclasses to register test users.

=cut

sub registerUser {
    my ( $this, $loginname, $forename, $surname, $email ) = @_;

    my $cfgData = $this->app->cfg->data;

    $this->saveState;

    my $reqParams = {
        'TopicName'     => ['UserRegistration'],
        'Twk1Email'     => [$email],
        'Twk1WikiName'  => ["$forename$surname"],
        'Twk1Name'      => ["$forename $surname"],
        'Twk0Comment'   => [''],
        'Twk1FirstName' => [$forename],
        'Twk1LastName'  => [$surname],
        'action'        => ['register']
    };

    if ( $cfgData->{Register}{AllowLoginName} ) {
        $reqParams->{"Twk1LoginName"} = $loginname;
    }

    $this->createNewFoswikiApp(
        requestParams => { initializer => $reqParams, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                method    => 'POST',
                user      => $this->app->cfg->data->{AdminUserLogin},
                action    => 'register',
            },
        },
        callbacks => {

            # Get around the default application exception handling to stay in
            # control of failed registration without the need to analyze HTML
            # output of handleRequest() method.
            handleRequestException => sub {
                my $this = shift;
                my %args = @_;
                $args{params}{exception}->rethrow;
            },
        },
    );
    $this->assert(
        $this->app->store->topicExists(
            $this->test_web, $cfgData->{WebPrefsTopicName}
        )
    );

    $this->app->net->setMailHandler( \&sentMail );
    $this->app->cfg->data->{Validation}{Method} = 'none';
    try {
        $this->app->handleRequest;

        #my $uiRegister = $this->create('Foswiki::UI::Register');
        #$uiRegister->register_cgi;

       #$this->captureWithKey( register_cgi => sub { $uiRegister->register_cgi }
       #);
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( "register", $e->{template},
                $e->stringify() );
            $this->assert_str_equals( "thanks", $e->{def}, $e->stringify() );
        }
        elsif ( $e->isa('Foswiki::AccessControlException') ) {
            $this->assert( 0, $e->stringify );
        }
        elsif ( $e->isa('Foswiki::Exception') ) {
            $this->assert( 0, $e->stringify );
        }
        else {
            $this->assert( 0, "expected an oops redirect" );
        }
    };

    $this->restoreState;

    # Reset
    $this->app->users->mapping->invalidate;
}

=begin TML

---++ StaticMethod sentMail($net, $mess)

Default implementation for the callback used by Net.pm. Sent mails are
pushed onto a global variable @FoswikiFnTestCase::mails.

=cut

sub sentMail {
    my ( $net, $mess ) = @_;
    push( @mails, $mess );
    return undef;
}

=begin TML

---++ ObjectMethod saveState

Preserves current state of test object. This method is utilizing
=Foswiki::Aux::Localize= facilities.

=cut

sub saveState {
    my $this = shift;
    my %params;

    my $holderObj = $this->localize(@_);

    push @{ $this->_holderStack }, $holderObj;
}

=begin TML

---++ ObjectMethod restoreState

Restores last saved by =saveState= method object state. In addition to
functionality provided by =Foswiki::Aux::Localize= this method also restore the
application and config globals =$Foswiki::app= and =%Foswiki::cfg=,
correspondingly.

=cut

sub restoreState {
    my $this = shift;

    ASSERT( @{ $this->_holderStack } > 0, "Empty stack of holder objects" )
      if DEBUG;

    pop @{ $this->_holderStack };

    $Foswiki::app = $this->app;

    $this->app->cfg->assignGLOB;
    $this->_fixupAppObjects;
}

=begin TML
---++ ObjectMethod preserveEnvironment

Preserves current run environment including =%<nop>ENV= and config.

=cut

sub preserveEnvironment {
    my $this = shift;

    $this->_clear__EnvSafe;
    foreach my $sym ( keys %ENV ) {
        next unless defined($sym);
        $this->__EnvSafe->{$sym} = $ENV{$sym};
    }

    foreach my $sym ( keys %{ $this->__EnvReset } ) {
        if ( defined $this->__EnvReset->{$sym} ) {
            $ENV{$sym} = $this->__EnvReset->{$sym};
        }
        else {
            delete $ENV{$sym};
        }
    }

    $this->__FoswikiSafe(
        $this->app->cfg->_cloneData( $this->app->cfg->data, 'data' ) );
}

=begin TML
---++ ObjectMethod restoreEnvironment

Restores run environment preserved by =preserveEnvironment= method.

=cut

sub restoreEnvironment {
    my $this = shift;
    $this->app->cfg->data( $this->__FoswikiSafe );
    foreach my $sym ( keys %ENV ) {
        unless ( defined( $this->__EnvSafe->{$sym} ) ) {
            delete $ENV{$sym};
        }
        else {
            $ENV{$sym} = $this->__EnvSafe->{$sym};
        }
    }
}

=begin TML

---++ ObjectMethod setupPlugins

Disable/enable plugins so that only core extensions (those defined in
lib/MANIFEST) are enabled, but they are *all* enabled.

=cut

sub setupPlugins {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    # First disable all plugins
    foreach my $k ( keys %{ $cfgData->{Plugins} } ) {
        next unless ref( $cfgData->{Plugins}{$k} ) eq 'HASH';
        $cfgData->{Plugins}{$k}{Enabled} = 0;
    }

    # then reenable only those listed in MANIFEST
    my $home = $ENV{FOSWIKI_HOME} || '../..';
    $home = '../..' unless -e "$ENV{FOSWIKI_HOME}/lib/MANIFEST";
    open( F, "$home/lib/MANIFEST" ) || die $!;
    my @moreConfig;
    local $/ = "\n";
    while (<F>) {
        if (/^!include .*?([^\/]+)\/([^\/]+)$/) {
            my ( $subdir, $extension ) = ( $1, $2 );
            chomp $extension;

            # Don't enable EmptyPlugin - Disabled by default
            if ( $extension =~ m/Plugin$/ && $extension ne 'EmptyPlugin' ) {
                unless ( exists $cfgData->{Plugins}{$extension}{Module} ) {
                    $cfgData->{Plugins}{$extension}{Module} =
                      'Foswiki::Plugins::' . $extension;
                    print STDERR "WARNING: $extension has no module defined, "
                      . "it might not load!\n"
                      . "\tGuessed it to $cfgData->{Plugins}{$extension}{Module}\n";
                }
                $cfgData->{Plugins}{$extension}{Enabled} = 1;
            }

            # Is there a Config.spec?
            if (
                open( G, "<",
                    "../../lib/Foswiki/$subdir/$extension/Config.spec"
                )
              )
            {
                local $/ = undef;
                my $config = <G>;
                close(G);

                # Add the config unless already defined in LocalSite.cfg
                $config =~
s/((\$Foswiki::cfg\{.*?\})\s*=.*?;)(?:\n|$)/push(@moreConfig, $1) unless (eval "exists $2"); ''/ges;
            }
        }
    }
    close(F);

    # Additional config picked up from plugins Config.spec's
    if ( scalar @moreConfig ) {
        unshift( @moreConfig, 'my $FALSE = 0; my $TRUE = 1;' );
        my $cmd = join( "\n", @moreConfig );

        #print STDERR $cmd; # Additional config from enabled extensions
        eval $cmd;
        die $@ if $@;
    }

    # Take a look at installed contribs and see if they demand any
    # additional setup.
    if ( opendir( F, "$home/lib/Foswiki/Contrib" ) ) {
        foreach my $d ( grep { /^[A-Za-z]+Contrib$/ } readdir(F) ) {
            next unless -e "$home/lib/Foswiki/Contrib/$d/UnitTestSetup.pm";
            my $setup = "Foswiki::Contrib::$d" . '::UnitTestSetup';
            $setup =~ m/^(.*)$/;    # untaint
            Foswiki::load_package($setup);
            $setup->set_up();
        }
        closedir(F);
    }
}

=begin TML
---++ ObjectMethod setupDirs

Takes measures as to avoid polluting the base directory with test data and logs.

=cut

sub setupDirs {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $cfgData->{WorkingDir} = $this->tempDir;
    foreach my $subdir (qw(tmp registration_approvals work_areas requestTmp)) {
        my $newDir =
          File::Spec->catfile( $this->app->cfg->data->{WorkingDir}, $subdir );
        unless ( -d $newDir || mkdir($newDir) ) {
            Foswiki::Exception::FileOp->throw(
                file => $newDir,
                op   => "mkdir",
            );
        }
    }

    # Note this does not do much, except for some tests that use it directly.
    # The first call to File::Temp caches the temp directory name, so
    # this value won't get used for anything created by File::Temp
    $cfgData->{TempfileDir} = $cfgData->{WorkingDir} . "/requestTmp";

    # Move logging into a temporary directory
    my $logdir = Cwd::getcwd() . '/testlogs';
    $logdir =~ m/^(.*)$/;
    $logdir = $1;
    $cfgData->{Log}{Dir} = $logdir;
    mkdir($logdir) unless -d $logdir;
    my $logName = $this->testSuite;
    $cfgData->{Log}{Implementation} = 'Foswiki::Logger::Compatibility';
    $cfgData->{LogFileName}         = "$logdir/$logName.log";
    $cfgData->{WarningFileName}     = "$logdir/$logName.warn";
    $cfgData->{DebugFileName}       = "$logdir/$logName.debug";
}

=begin TML

#setupAdminUser
---++ ObjectMethod setupAdminUser(%userData)

Sets this test administrator user data. The =%userData= hash may have the
following keys:

|*Key*|*Description*|*Default*|
|=wikiname=|Admin's wiki name|_AdminUser_|
|=login=|Admin's login|_root_|
|=group=|Administrative group|_AdminGroup_|

=cut

sub setupAdminUser {
    my $this     = shift;
    my %userData = @_;
    my $cfgData  = $this->app->cfg->data;

    $cfgData->{AdminUserWikiName} = $userData{wikiname} || 'AdminUser';
    $cfgData->{AdminUserLogin}    = $userData{login}    || 'root';
    $cfgData->{SuperAdminGroup}   = $userData{group}    || 'AdminGroup';
}

=begin TML
---++ ObjectMethod setupUserRegistration

Configures components needed to register new users so as to avoid polluting the
base installation.

=cut

sub setupUserRegistration {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;

    $cfgData->{Register}{AllowLoginName} = 1;
    my $htFile = $cfgData->{Htpasswd}{FileName} =
      $cfgData->{WorkingDir} . "/htpasswd";
    $cfgData->{Htpasswd}{LockFileName} =
      $cfgData->{WorkingDir} . "/htpasswd.lock";
    unless ( -e $htFile ) {
        my $fh;
        open( $fh, ">:encoding(utf-8)", $htFile )
          || Foswiki::Exception::FileOp->throw(
            file => $htFile,
            op   => 'open',
          );
        close($fh) || Foswiki::Exception::FileOp->throw(
            file => $htFile,
            op   => 'close',
        );
    }
    $cfgData->{PasswordManager}       = 'Foswiki::Users::HtPasswdUser';
    $cfgData->{Htpasswd}{GlobalCache} = 0;
    $cfgData->{UserMappingManager}    = 'Foswiki::Users::TopicUserMapping';
    $cfgData->{LoginManager}          = 'Foswiki::LoginManager::TemplateLogin';
    $cfgData->{Register}{EnableNewUserRegistration} = 1;
    $cfgData->{RenderLoggedInButUnknownUsers} = 0;

    $cfgData->{Register}{NeedVerification} = 0;
    $cfgData->{MinPasswordLength}          = 0;
    $cfgData->{UsersWebName}               = $this->users_web;
}

=begin TML

---++ ObjectMethod createNewFoswikiApp(%params) -> ref to new Unit::TestApp obj

cleans up the existing Foswiki object, and creates a new one

=%params= are passed directly to the =Foswiki::App= constructor.

typically called to force a full re-initialisation either with new preferences, topics, users, groups or CFG

=cut

# Correct all Foswiki::AppObject to use currently active Foswiki::App object.
# SMELL Hacky but shall be transparent for any derived test case class.
sub _fixupAppObjects {
    my $this = shift;

    my $app = $this->app;

    foreach my $attr ( keys %$this ) {
        if (
               blessed( $this->{$attr} )
            && $this->$attr->isa('Foswiki::Object')
            && $this->$attr->can('_set_app')
            && ( !defined( $this->$attr->app )
                || ( $this->$attr->app != $app ) )
          )
        {
            $this->$attr->_set_app($app);
        }
    }
}

sub createNewFoswikiApp {
    my $this = shift;

    my $app    = $this->app;
    my %params = @_;

    $app->cfg->data->{Store}{Implementation} ||= 'Foswiki::Store::PlainFile';

    $params{env} //= $app->cloneEnv;
    my $newApp = Unit::TestApp->new( cfg => $app->cfg->clone, %params );

    $this->app($newApp);
    $this->_fixupAppObjects;

    # WorkDir is set to _tempDir but _tempDir might be cleaned up before $app
    # gets completely shutdown. This draws some app frameworks to fail upon
    # cleanup as they rely upon WorkDir. By storing the _tempDir object on app's
    # heap we let them shutdown cleanly.
    $newApp->heap->{TestCase_TempDir} = $this->_tempDir;

    return $newApp;
}

=begin TML
---++ ObjectMethod testWebName($baseName) -> $webName

Returns a standard test web name formed with test suite name and =$baseName=.
If =$baseName= is undef then it is set to the test suite name.

=cut

sub testWebName {
    my $this = shift;
    my ($baseName) = @_;

    $baseName //= $this->testSuite;

    return $TEST_WEB_PREFIX . $this->testSuite . 'TestWeb' . $baseName;
}

=begin TML

---++ ObjectMethod populateStandardWebs

Creates standard test webs defined by =test_web= and =users_web= attributes.

=cut

sub populateStandardWebs {
    my $this = shift;

    foreach my $web ( $this->test_web, $this->users_web ) {
        $this->populateNewWeb($web);
    }
}

=begin TML

---++ ObjectMethod cleanupTestWebs

Deletes all test webs recorded by =Unit::FoswikiTestRole= =populateNewWeb()=
method.

=cut

sub cleanupTestWebs {
    my $this = shift;

    if ( $this->_has_testWebs ) {
        foreach my $web ( @{ $this->_testWebs } ) {
            $this->removeTestWeb($web);
        }
        $this->_clear_testWebs;
    }
}

=begin TML

---++ ObjectMethod populateNewWeb($web, $template, $opts) => $webObject

Creates a new web. If the web already exists then deletes it first. Parameters
are the same as in =Foswiki::Meta= =populateNewWeb()= method.

The created web is then recorded internally. All recorded webs can be removed
using =cleanupTestWebs()= method.

Returns newly created =Foswiki::Meta= web object.

=cut

sub populateNewWeb {
    my $this = shift;
    my ( $web, $template, $opts ) = @_;

    if ( $this->app->store->webExists($web) ) {
        $this->removeTestWeb($web);
    }
    my $webObj = $this->create( 'Foswiki::Meta', web => $web );
    ASSERT( defined $webObj, "Failed to create new web `$web'" );
    $webObj->populateNewWeb( $template, $opts );
    push @{ $this->_testWebs }, $web;

    return $webObj;
}

=begin TML

---++ ObjectMethod removeTestWeb($web)

Remove a temporary web fixture (data and pub).

The web name will be checked for 'Temporary' prefix and exception will be thrown
if the prefix is not in place. This is to protect non-test webs from being
accidentally removed. If a test web doesn't have the prefix then it must be
removed manually. To generate names corresponding to the requirement use
=testWebName()= method.

=cut

sub removeTestWeb {
    my ( $this, $web ) = @_;

    unless ( $web =~ /^$TEST_WEB_PREFIX/ ) {
        Foswiki::Exception::Fatal->throw( text => "Cannot remove test web "
              . $web
              . " because it's name doesn't start with "
              . $TEST_WEB_PREFIX );
    }

    try {
        my $webObject = $this->create( 'Foswiki::Meta', web => $web );
        $webObject->removeFromStore();
    }
    catch {
        say STDERR "Unexpected exception while removing web $web";
        say STDERR Foswiki::Exception::errorStr($_);
    };
}

=begin TML

---++ ObjectMethod leakDetectCheckpoint

This method sets a checkpoint for =Devel::Leak= if =Unit::TestRunner::CHECKLEAK=
is true.

Use it with big care as it may mask out all leakages happened before this method
was called.

=cut

sub leakDetectCheckpoint {
    my $this = shift;
    my ($dumpName) = @_;

    return unless Unit::TestRunner::CHECKLEAK;

    $dumpName //= $this->testSuite;

    say STDERR "<<< LEAK CHECKPOINT FOR TEST ", $dumpName;

    return Devel::Leak::Object::checkpoint();
}

=begin TML

---++ ObjectMethod leakDetectDump( $dumpName )

Dumps current state of of leaked objects in memory using
=Devel::Leak::Object::status()= call. =$dumpName= is used to distinguish a
particular dump from other.

If module =Devel::MAT::Dumper= is present
then memory dump would be made into log dir into a _.pmat_ file named after
=$dumpName=.

Do nothing unless =Unit::TestRunner::CHECKLEAK= is true.

=cut

sub leakDetectDump {
    my $this = shift;
    my ($dumpName) = @_;

    return unless Unit::TestRunner::CHECKLEAK;

    $dumpName //= $this->testSuite;

    $dumpName =~ tr/:/_/;
    say STDERR ">>> LEAK DUMP FOR TEST ", $dumpName;
    Devel::Leak::Object::status();
    eval {
        require Devel::MAT::Dumper;
        my $pmatFile = File::Spec->catfile( $this->app->cfg->data->{Log}{Dir},
            $dumpName . ".pmat" );
        say STDERR "Dumping Devel::MAT data into $pmatFile";
        Devel::MAT::Dumper::dump($pmatFile);
    };
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
