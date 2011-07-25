use strict;

package PasswordTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Foswiki;
use Foswiki::Users;
use Foswiki::Users::HtPasswdUser;

my $SALTED = 1;

use Config;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift();

    $this->SUPER::set_up();

    $this->{session} = new Foswiki();
    $Foswiki::cfg{Htpasswd}{FileName} = "$Foswiki::cfg{TempfileDir}/junkpasswd";
}

sub tear_down {
    my $this = shift;
    unlink $Foswiki::cfg{Htpasswd}{FileName};
    $this->{session}->finish();
    $this->SUPER::tear_down();
}

my $users1 = {
    alligator => { pass => 'hissss',            emails => 'ally@masai.mara' },
    bat       => { pass => 'ultrasonic squeal', emails => 'bat@belfry' },
    budgie => { pass => 'tweet',    emails => 'budgie@flock;budge@oz' },
    lion   => { pass => 'roar',     emails => 'lion@pride' },
    dodo   => { pass => '3zmVlgI9', emails => 'dodo@extinct' },
    mole   => { pass => '',         emails => 'mole@hill' }
};

my $users2 = {
    alligator => { pass => 'gnu',    emails => $users1->{alligator}->{emails} },
    bat       => { pass => 'moth',   emails => $users1->{bat}->{emails} },
    budgie    => { pass => 'millet', emails => $users1->{budgie}->{emails} },
    lion => { pass => 'antelope',  emails => $users1->{lion}->{emails} },
    dodo => { pass => 'b2rd',      emails => $users1->{dodo}->{emails} },
    mole => { pass => 'earthworm', emails => $users1->{mole}->{emails} },
};

sub doTests {
    my ( $this, $impl, $salted ) = @_;

    # add them all
    my %encrapted;
    foreach my $user ( sort keys %$users1 ) {
        $this->assert( !$impl->fetchPass($user) );
        my $added = $impl->setPassword( $user, $users1->{$user}->{pass} );
        $this->assert_null( $impl->error() );
        $this->assert($added);
        $impl->setEmails( $user, $users1->{$user}->{emails} );
        $this->assert_null( $impl->error() );
        $encrapted{$user} = $impl->fetchPass($user);
        $this->assert_null( $impl->error() );
        $this->assert( $encrapted{$user} );
        $this->assert_str_equals(
            $encrapted{$user},
            $impl->encrypt( $user, $users1->{$user}->{pass} ),
            "fails for $user"
        );
        $this->assert_str_equals( $users1->{$user}->{emails},
            join( ";", $impl->getEmails($user) ) );
    }

    # check it
    foreach my $user ( sort keys %$users1 ) {
        $this->assert(
            $impl->checkPassword( $user, $users1->{$user}->{pass} ) );
        $this->assert_str_equals( $encrapted{$user},
            $impl->encrypt( $user, $users1->{$user}->{pass} ) );
    }

    # try changing with wrong pass
    foreach my $user ( sort keys %$users1 ) {
        my $added = $impl->setPassword(
            $user,
            $users1->{$user}->{pass},
            $users2->{$user}->{pass}
        );
        $this->assert( !$added );
        $this->assert_not_null( $impl->error() );
    }
    if ($salted) {

        # re-add them with the same password, make sure encoding changed
        foreach my $user ( sort keys %$users1 ) {
            my $added = $impl->setPassword(
                $user,
                $users1->{$user}->{pass},
                $users1->{$user}->{pass},
                $encrapted{$user}
            );
            $this->assert_null( $impl->error() );
            $this->assert_str_not_equals( $encrapted{$user},
                $impl->fetchPass($user) );
            $this->assert_null( $impl->error() );
        }
    }

    # force-change them to users2 password
    foreach my $user ( sort keys %$users1 ) {
        my $added = $impl->setPassword(
            $user,
            $users2->{$user}->{pass},
            $users1->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
    }
    $this->assert( !$impl->removeUser('notauser') );
    $this->assert_not_null( $impl->error() );

    # delete first
    $this->assert( $impl->removeUser('alligator') );
    $this->assert_null( $impl->error() );
    foreach my $user ( sort keys %$users1 ) {
        if ( $user !~ /alligator/ ) {
            $this->assert(
                $impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
        else {
            $this->assert(
                !$impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
    }

    # delete last
    $this->assert( $impl->removeUser('mole') );
    foreach my $user ( sort keys %$users1 ) {
        if ( $user !~ /(alligator|mole)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
        else {
            $this->assert(
                !$impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
    }

    # delete middle
    $this->assert( $impl->removeUser('budgie') );
    foreach my $user ( sort keys %$users1 ) {
        if ( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
        else {
            $this->assert(
                !$impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
    }
}

sub test_htpasswd_auto {
    my $this = shift;

    foreach my $m (qw( Digest::SHA Crypt::PasswdMD5 )) {
        eval "use $m";
        if ($@) {
            my $mess = $@;
            $mess =~ s/\(\@INC contains:.*$//s;
            $this->expect_failure();
            $this->annotate("AUTO TESTS WILL FAIL: missing $m");
        }
    }

    $Foswiki::cfg{AuthRealm} = 'MyNewRealmm';
    $Foswiki::cfg{Htpasswd}{AutoDetect} = 1;

    my %encrapted;
    my %encoded;
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );

# The following lines were generated with the apache htdigest and htpasswd command
# Used to verify the encode autodetect feature.

    open( my $fh, '>', "$Foswiki::cfg{TempfileDir}/junkpasswd" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<'DONE';
alligator:njQ4t57Dts41s
bat:$apr1$9/PfK37z$HrNORnyJefA2ex4nWLOoR1
budgie:{SHA}1pqeQCvCHCfCrnFA8mTGYna/DV0=
dodo:$1$pUXqkX97$zqxdNSnpusVmoB.B.aUhB/:dodo@extinct
lion:MyNewRealmm:3e60f5f16dc3b8658879d316882a3f00
mole::
DONE
    close($fh);

    # First try - no emails in file
    # check it
    foreach my $user ( sort keys %$users1 ) {
        $this->assert( $impl->checkPassword( $user, $users1->{$user}->{pass} ),
            "Failure for $user" );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        if ( $encrapted{$user} ) {
            $this->assert_str_equals(
                $encrapted{$user},
                $impl->encrypt(
                    $user, $users1->{$user}->{pass},
                    0, $encoded{$user}
                ),
                "Failure for $user"
            );
        }
    }

    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );

    # Test again with email addresses present
    open( $fh, '>', "$Foswiki::cfg{TempfileDir}/junkpasswd" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<'DONE';
alligator:njQ4t57Dts41s:ally@masai.mara
bat:$apr1$9/PfK37z$HrNORnyJefA2ex4nWLOoR1:bat@belfry
budgie:{SHA}1pqeQCvCHCfCrnFA8mTGYna/DV0=:budgie@flock;budge@oz
dodo:$1$pUXqkX97$zqxdNSnpusVmoB.B.aUhB/:dodo@extinct
lion:MyNewRealmm:3e60f5f16dc3b8658879d316882a3f00:lion@pride
mole:plainpasswordx:mole@hill
DONE
    close($fh);

    # Limited support to autodetect a plain text password.
    # It fails if the password is 13 characters long, since it could
    # also be a crypt password which is more likely.
    $users1->{mole}->{pass} = 'plainpasswordx';

    # check it
    foreach my $user ( sort keys %$users1 ) {
        $this->assert( $impl->checkPassword( $user, $users1->{$user}->{pass} ),
            "Failure for $user" );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        if ( $encrapted{$user} ) {
            $this->assert_str_equals(
                $encrapted{$user},
                $impl->encrypt(
                    $user, $users1->{$user}->{pass},
                    0, $encoded{$user}
                ),
                "Failure for $user"
            );
        }
    }

    #dumpFile();

    # force-change them to users2 password,  Verify emails have survived.
    foreach my $user ( sort keys %$users1 ) {
        my $added = $impl->setPassword(
            $user,
            $users2->{$user}->{pass},
            $users1->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        $this->assert_str_equals( $users1->{$user}->{emails},
            join( ";", $impl->getEmails($user) ) );
    }

    $Foswiki::cfg{Htpasswd}{Encoding} = 'md5';
    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );

    # force-change them to users2 password again,  Verify emails have survived.
    foreach my $user ( sort keys %$users1 ) {
        my $added = $impl->setPassword(
            $user,
            $users2->{$user}->{pass},
            $users2->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        $this->assert_str_equals( $users1->{$user}->{emails},
            join( ";", $impl->getEmails($user) ) );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        $this->assert_str_equals( 'md5', $encoded{$user}->{enc} );
    }

    #dumpFile();

    # Check and change passwords again, with a modified realm
    # And use new value for Encoding
    $Foswiki::cfg{Htpasswd}{Encoding} = 'htdigest-md5';
    $Foswiki::cfg{AuthRealm} = 'Another New Realm';
    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );

    foreach my $user ( sort keys %$users1 ) {
        my $added = $impl->setPassword(
            $user,
            $users2->{$user}->{pass},
            $users2->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert( $impl->checkPassword( $user, $users2->{$user}->{pass} ),
            "For $user checkPassword" );

        #$this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
    }

    #dumpFile();

    $Foswiki::cfg{Htpasswd}{Encoding} = 'apache-md5';
    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );

    # force-change them to users2 password again, migrating to apache_md5.
    foreach my $user ( sort keys %$users1 ) {
        my $added = $impl->setPassword(
            $user,
            $users2->{$user}->{pass},
            $users2->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        $this->assert_str_equals( $users1->{$user}->{emails},
            join( ";", $impl->getEmails($user) ) );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        $this->assert_str_equals( 'apache-md5', $encoded{$user}->{enc} );
    }

    #dumpFile();
}

sub dumpFile {
    my $IN_FILE;
    open( $IN_FILE, '<', "$Foswiki::cfg{TempfileDir}/junkpasswd" );
    my $line;
    while ( defined( $line = <$IN_FILE> ) ) {
        print STDERR $line . "\n";
    }
}

sub test_htpasswd_crypt_md5 {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{Encoding} = 'crypt-md5';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests( $impl, $SALTED );

}

sub test_htpasswd_crypt_crypt {
    my $this = shift;
    $Foswiki::cfg{Htpasswd}{Encoding} = 'crypt';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests( $impl, $SALTED );
}

sub test_htpasswd_sha1 {
    my $this = shift;

    eval 'use Digest::SHA';
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN SHA1 TESTS: $mess");
    }

    $Foswiki::cfg{Htpasswd}{Encoding} = 'sha1';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests($impl);
}

sub test_htpasswd_plain {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{Encoding} = 'plain';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests($impl);

}

sub test_htpasswd_md5 {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{Encoding} = 'md5';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests($impl);

}

sub test_htpasswd_htdigest_md5 {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{Encoding} = 'htdigest-md5';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests($impl);

    # Verify the passwords using deprecated md5, should be identical
    $Foswiki::cfg{Htpasswd}{Encoding} = 'md5';
    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    foreach my $user ( sort keys %$users1 ) {
        if ( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
    }
}

sub test_htpasswd_apache_md5 {
    my $this = shift;
    eval 'use Crypt::PasswdMD5';
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE MD5 TESTS: $mess");
    }

    $Foswiki::cfg{Htpasswd}{Encoding} = 'apache-md5';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests( $impl, 0 );
}

sub test_ApacheHtpasswdUser_md5 {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'apache-md5';
    eval "use Apache::Htpasswd";
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    eval "use Foswiki::Users::ApacheHtpasswdUser";
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    my $impl = Foswiki::Users::ApacheHtpasswdUser->new( $this->{session} );

    # it should work the same as htpasswd (without salt)
    $this->doTests( $impl, $SALTED );

    # Verify the passwords using HdPaswdUser for compatibility
    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    foreach my $user ( sort keys %$users1 ) {
        if ( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
    }
}

sub test_ApacheHtpasswdUser_crypt {
    my $this = shift;

    if ( $^O =~ /^MSWin/i ) {
        $this->expect_failure();
        $this->annotate("CANNOT RUN ApacheHtpasswdUser_crypt TESTS on Windows");
    }

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'crypt';
    eval "use Apache::Htpasswd";
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    eval "use Foswiki::Users::ApacheHtpasswdUser";
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    my $impl = Foswiki::Users::ApacheHtpasswdUser->new( $this->{session} );

    $this->doTests($impl);

    # Verify the passwords using HdPaswdUser for compatibility
    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    foreach my $user ( sort keys %$users1 ) {
        if ( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
    }
}

# SMELL: Apache;:Htpasswd Version 1.8  doesn't appear to actually support writing
# plain text passwords.  So this test will fail.  The htpasswd file has
# encrypted passwords regardless of 'plain' setting.
sub DISABLE_test_ApacheHtpasswdUser_plain {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'plain';
    eval "use Apache::Htpasswd";
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    eval "use Foswiki::Users::ApacheHtpasswdUser";
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    my $impl = Foswiki::Users::ApacheHtpasswdUser->new( $this->{session} );

    $this->doTests($impl);

    # Verify the passwords using HdPaswdUser for compatibility
    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    foreach my $user ( sort keys %$users1 ) {
        if ( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $users2->{$user}->{pass} ) );
        }
    }
}
1;
