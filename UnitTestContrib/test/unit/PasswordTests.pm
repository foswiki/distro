package PasswordTests;
use strict;
use warnings;

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Assert;
use Config;
use Foswiki();
use Foswiki::Users();
use Foswiki::Users::HtPasswdUser();

my $SALTED = 1;

sub set_up {
    my $this = shift();

    $this->SUPER::set_up();

    $this->createNewFoswikiSession();
    $Foswiki::cfg{Htpasswd}{FileName} = "$Foswiki::cfg{TempfileDir}/junkpasswd";

    $this->{users1} = {
        alligator => { pass => 'hissss', emails => 'ally@masai.mara' },
        bat => { pass => 'ultrasonic squeal', emails => 'bat@belfry' },
        budgie => { pass => 'tweet',    emails => 'budgie@flock;budge@oz' },
        lion   => { pass => 'roar',     emails => 'lion@pride' },
        dodo   => { pass => '3zmVlgI9', emails => 'dodo@extinct' },
        tortise   => { pass => 'slowone', emails => 'turtle@soup' },
        mole   => { pass => '',         emails => 'mole@hill' }
    };

    $this->{users2} = {
        alligator =>
          { pass => 'gnu', emails => $this->{users1}->{alligator}->{emails} },
        bat => { pass => 'moth', emails => $this->{users1}->{bat}->{emails} },
        budgie =>
          { pass => 'millet', emails => $this->{users1}->{budgie}->{emails} },
        lion =>
          { pass => 'antelope', emails => $this->{users1}->{lion}->{emails} },
        dodo => { pass => 'b2rd', emails => $this->{users1}->{dodo}->{emails} },
        tortise   => { pass => 'slower', emails => $this->{users1}->{tortise}->{emails} },
        mole =>
          { pass => 'earthworm', emails => $this->{users1}->{mole}->{emails} },
    };

    return;
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig(@_);

    $Foswiki::cfg{Htpasswd}{FileName} = "$Foswiki::cfg{TempfileDir}/junkpasswd";
    unlink "$Foswiki::cfg{TempfileDir}/junkpasswd"
      if ( -e "$Foswiki::cfg{TempfileDir}/junkpasswd" );

    $Foswiki::cfg{Htpasswd}{DetectModification} = 1;
    $Foswiki::cfg{Htpasswd}{GlobalCache}        = 1;

}

sub tear_down {
    my $this = shift;
    unlink $Foswiki::cfg{Htpasswd}{FileName};
    $this->SUPER::tear_down();

    return;
}

sub doTests {
    my ( $this, $impl, $salted ) = @_;

    # add them all
    my %encrapted;
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        $this->assert( !$impl->fetchPass($user) );
        my $added =
          $impl->setPassword( $user, $this->{users1}->{$user}->{pass} );
        $this->assert_null( $impl->error() );
        $this->assert($added);
        $impl->setEmails( $user, $this->{users1}->{$user}->{emails} );
        $this->assert_null( $impl->error() );
        $encrapted{$user} = $impl->fetchPass($user);
        $this->assert_null( $impl->error() );
        $this->assert( $encrapted{$user} );
        $this->assert_str_equals(
            $encrapted{$user},
            $impl->encrypt( $user, $this->{users1}->{$user}->{pass} ),
            "fails for $user"
        );
        $this->assert_str_equals(
            $this->{users1}->{$user}->{emails},
            join( ";", $impl->getEmails($user) )
        );
    }
    # check it
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        $this->assert(
            $impl->checkPassword( $user, $this->{users1}->{$user}->{pass} ) );
        $this->assert_str_equals( $encrapted{$user},
            $impl->encrypt( $user, $this->{users1}->{$user}->{pass} ) );
    }

    # try changing with wrong pass
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        my $added = $impl->setPassword(
            $user,
            $this->{users1}->{$user}->{pass},
            $this->{users2}->{$user}->{pass}
        );
        $this->assert( !$added );
        $this->assert_not_null( $impl->error() );
    }
    if ($salted) {

        # re-add them with the same password, make sure encoding changed
        foreach my $user ( sort keys %{ $this->{users1} } ) {
            my $added = $impl->setPassword(
                $user,
                $this->{users1}->{$user}->{pass},
                $this->{users1}->{$user}->{pass},
                $encrapted{$user}
            );
            $this->assert_null( $impl->error() );
            $this->assert_str_not_equals( $encrapted{$user},
                $impl->fetchPass($user) );
            $this->assert_null( $impl->error() );
        }
    }

    # force-change them to users2 password
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        my $added = $impl->setPassword(
            $user,
            $this->{users2}->{$user}->{pass},
            $this->{users1}->{$user}->{pass}
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
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        if ( $user !~ /alligator/ ) {
            $this->assert(
                $impl->checkPassword( $user, $this->{users2}->{$user}->{pass} )
            );
        }
        else {
            $this->assert(
                !$impl->checkPassword(
                    $user, $this->{users2}->{$user}->{pass}
                )
            );
        }
    }

    # delete last
    $this->assert( $impl->removeUser('mole') );
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        if ( $user !~ /(alligator|mole)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $this->{users2}->{$user}->{pass} )
            );
        }
        else {
            $this->assert(
                !$impl->checkPassword(
                    $user, $this->{users2}->{$user}->{pass}
                )
            );
        }
    }

    # delete middle
    $this->assert( $impl->removeUser('budgie') );
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        if ( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $this->{users2}->{$user}->{pass} )
            );
        }
        else {
            $this->assert(
                !$impl->checkPassword(
                    $user, $this->{users2}->{$user}->{pass}
                )
            );
        }
    }

    return;
}

sub skip {
    my ( $this, $test ) = @_;

    return $this->SUPER::skip_test_if(
        $test,
        {
            condition => { without_dep => 'Digest::SHA' },
            tests     => {
                'PasswordTests::test_disabled_entry' => 'Missing Digest::SHA',
                'PasswordTests::test_htpasswd_sha1'  => 'Missing Digest::SHA',
                'PasswordTests::test_htpasswd_htdigest_preserves_email' =>
                  'Missing Digest::SHA',
                'PasswordTests::test_htpasswd_auto' => 'Missing Digest::SHA',
            }
        },
        {
            condition => { without_dep => 'Crypt::PasswdMD5' },
            tests     => {
                'PasswordTests::test_disabled_entry' =>
                  'Missing Crypt::PasswdMD5',
                'PasswordTests::test_htpasswd_apache_md5' =>
                  'Missing Crypt::PasswdMD5',
                'PasswordTests::test_htpasswd_auto' =>
                  'Missing Crypt::PasswdMD5',
                'PasswordTests::test_ApacheHtpasswdUser_md5' =>
                  'Missing Crypt::PasswdMD5',
                'PasswordTests::test_htpasswd_htdigest_preserves_email' =>
                  'Missing Crypt::PasswdMD5',
            }
        },
        {
            condition => { without_dep => 'Crypt::Eksblowfish::Bcrypt' },
            tests     => {
                'PasswordTests::test_htpasswd_bcrypt' =>
                  'Missing Crypt::Eksblowfish::Bcrypt',
                'PasswordTests::test_htpasswd_auto' =>
                  'Missing Crypt::Eksblowfish::Bcrypt',
           }
       },
       {
            condition => { without_dep => 'Apache::Htpasswd' },
            tests     => {
                'PasswordTests::test_ApacheHtpasswdUser_crypt' =>
                  'Missing Apache::Htpasswd',
           }
       }
    );
}

sub test_disabled_entry {
    my $this = shift;

    $Foswiki::cfg{AuthRealm} = 'MyNewRealmm';
    $Foswiki::cfg{Htpasswd}{AutoDetect} = 1;

    my %encrapted;
    my %encoded;
    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');

# The following lines were generated with the apache htdigest and htpasswd command
# Each one generated with an empty password.

    open( my $fh, '>', "$Foswiki::cfg{TempfileDir}/junkpasswd" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<'DONE';
alligator:Pfo62LcyAuTjA:crypt@example.com
bat:$apr1$RnkZeOAr$1hvvdLQLXWUMQJyCAxsXW.:apache-md5@example.com
budgie:{SHA}2jmj7l5rSw0yVb/vlWAYkK/YBwk=:sha1@example.com
lion:MyNewRealm:cb90fdb9780b69d08562744db4bfa07f:htdigest-md5@example.com
mole:$1$QC5tIZEi$0sLeg6YAc4I64Zn/4pPnU1:crypt-md5@example.com
DONE
    $this->assert( close($fh) );

    foreach my $user ( 'alligator', 'bat', 'budgie', 'lion', 'mole' ) {
        $this->assert( $impl->checkPassword( $user, '' ) );
    }

    # Verify that no algorithm will validate an empty password entry
    # Against a blank password.
    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );

    # Make sure file is detected as modified.
    sleep 2;

    open( $fh, '>', "$Foswiki::cfg{TempfileDir}/junkpasswd" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<'DONE';
crypt::crypt@example.com
apache-md5::apache-md5@example.com
sha1::sha1@example.com
htdigest-md5:MyNewRealm::htdigest-md5@example.com
crypt-md5::crypt-md5@example.com
DONE
    $this->assert( close($fh) );

    foreach
      my $algo ( 'apache-md5', 'htdigest-md5', 'crypt', 'sha1', 'crypt-md5' )
    {
        $Foswiki::cfg{Htpasswd}{Encoding} = $algo;
        $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );

        foreach my $user ( 'crypt', 'apache-md5', 'sha1', 'htdigest-md5',
            'crypt-md5' )
        {
            $this->assert( !$impl->checkPassword( $user, '' ) );
        }
    }

    # Verify that each algorithm can reset an empty password entry
    # But need to autodetect to not corrupt existing entries
    $Foswiki::cfg{Htpasswd}{AutoDetect} = 1;
    foreach
      my $user ( 'crypt', 'apache-md5', 'sha1', 'htdigest-md5', 'crypt-md5' )
    {
        $Foswiki::cfg{Htpasswd}{Encoding} = $user;
        $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );

        my $added = $impl->setPassword( $user, "pw$user", 1 );
        $this->assert_null( $impl->error() );
    }

    #dumpFile();

    # Verify that the passwords were reset
    $Foswiki::cfg{Htpasswd}{AutoDetect} = 1;
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    foreach my $user ( 'crypt', 'apache-md5', 'sha1', 'crypt-md5' ) {
        $this->assert( $impl->checkPassword( $user, "pw$user" ),
            "Failure for $user" );
    }

    return;
}

sub test_htpasswd_auto {
    my $this = shift;

    $Foswiki::cfg{AuthRealm} = 'MyNewRealmm';
    $Foswiki::cfg{Htpasswd}{AutoDetect} = 1;

    # Limited support to autodetect a plain text password.
    # It fails if the password is 13 characters long, since it could
    # also be a crypt password which is more likely.  Empty passwords
    # not supported for autodetect.
    $this->{users1}->{mole}->{pass} = 'plainpasswordx';

    my %encrapted;
    my %encoded;
    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');

# The following lines were generated with the apache htdigest and htpasswd command
# Used to verify the encode autodetect feature.

    open( my $fh, '>', "$Foswiki::cfg{TempfileDir}/junkpasswd" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<'DONE';
alligator:njQ4t57Dts41s
bat:$apr1$9/PfK37z$HrNORnyJefA2ex4nWLOoR1
budgie:{SHA}1pqeQCvCHCfCrnFA8mTGYna/DV0=
dodo:$1$pUXqkX97$zqxdNSnpusVmoB.B.aUhB/:dodo@extinct
lion:MyNewRealmm:3e60f5f16dc3b8658879d316882a3f00:lion@pride
mole:plainpasswordx:mole@hill
tortise:$2a$08$STPELUTxMRf2Y0v1J1nWaOXH1mdWf9VzPlGQ9NgIFU.9B/GCGpC8G:turtle@soup
DONE
    $this->assert( close($fh) );

    # First try - no emails in file
    # check it
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        $this->assert(
            $impl->checkPassword( $user, $this->{users1}->{$user}->{pass} ),
            "Failure for $user" );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        if ( $encrapted{$user} ) {
            $this->assert_str_equals(
                $encrapted{$user},
                $impl->encrypt(
                    $user, $this->{users1}->{$user}->{pass},
                    0,     $encoded{$user}
                ),
                "Failure for $user"
            );
        }
    }

    # Make sure the file timestamp has changed enough to be detected
    sleep 2;

    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );

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
tortise:$2a$08$STPELUTxMRf2Y0v1J1nWaOXH1mdWf9VzPlGQ9NgIFU.9B/GCGpC8G:turtle@soup
DONE
    $this->assert( close($fh) );

    # check it
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        $this->assert(
            $impl->checkPassword( $user, $this->{users1}->{$user}->{pass} ),
            "Failure for $user" );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        if ( $encrapted{$user} ) {
            $this->assert_str_equals(
                $encrapted{$user},
                $impl->encrypt(
                    $user, $this->{users1}->{$user}->{pass},
                    0,     $encoded{$user}
                ),
                "Failure for $user"
            );
        }
    }

    #dumpFile();

    # force-change them to users2 password,  Verify emails have survived.
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        my $added = $impl->setPassword(
            $user,
            $this->{users2}->{$user}->{pass},
            $this->{users1}->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        $this->assert_str_equals(
            $this->{users1}->{$user}->{emails},
            join( ";", $impl->getEmails($user) )
        );
    }

    $Foswiki::cfg{Htpasswd}{Encoding} = 'md5';
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );

    # force-change them to users2 password again,  Verify emails have survived.
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        my $added = $impl->setPassword(
            $user,
            $this->{users2}->{$user}->{pass},
            $this->{users2}->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        $this->assert_str_equals(
            $this->{users1}->{$user}->{emails},
            join( ";", $impl->getEmails($user) )
        );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        $this->assert_str_equals( 'md5', $encoded{$user}->{enc} );
    }

    #dumpFile();

    # Check and change passwords again, with a modified realm
    # And use new value for Encoding
    $Foswiki::cfg{Htpasswd}{Encoding} = 'htdigest-md5';
    $Foswiki::cfg{AuthRealm} = 'Another New Realm';
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );

    foreach my $user ( sort keys %{ $this->{users1} } ) {
        my $added = $impl->setPassword(
            $user,
            $this->{users2}->{$user}->{pass},
            $this->{users2}->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert(
            $impl->checkPassword( $user, $this->{users2}->{$user}->{pass} ),
            "For $user checkPassword" );

        #$this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
    }

    #dumpFile();

    $Foswiki::cfg{Htpasswd}{Encoding} = 'apache-md5';
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );

    # force-change them to users2 password again, migrating to apache_md5.
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        my $added = $impl->setPassword(
            $user,
            $this->{users2}->{$user}->{pass},
            $this->{users2}->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        $this->assert_str_equals(
            $this->{users1}->{$user}->{emails},
            join( ";", $impl->getEmails($user) )
        );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        $this->assert_str_equals( 'apache-md5', $encoded{$user}->{enc} );
    }

    $Foswiki::cfg{Htpasswd}{Encoding} = 'bcrypt';
    $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );

    # force-change them to users2 password again, migrating to bcrypt.
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        my $added = $impl->setPassword(
            $user,
            $this->{users2}->{$user}->{pass},
            $this->{users2}->{$user}->{pass}
        );
        $this->assert_null( $impl->error() );
        $this->assert_str_not_equals( $encrapted{$user},
            $impl->fetchPass($user) );
        $this->assert_null( $impl->error() );
        $this->assert_str_equals(
            $this->{users1}->{$user}->{emails},
            join( ";", $impl->getEmails($user) )
        );
        ( $encrapted{$user}, $encoded{$user} ) = $impl->fetchPass($user);
        $this->assert_str_equals( 'bcrypt', $encoded{$user}->{enc} );
    }

    #dumpFile();

    return;
}

sub dumpFile {
    open( my $IN_FILE, '<', "$Foswiki::cfg{TempfileDir}/junkpasswd" ) or die $!;
    my $line;
    while ( defined( $line = <$IN_FILE> ) ) {
        print STDERR $line . "\n";
    }
    ASSERT( close($IN_FILE) );

    return;
}

sub test_htpasswd_crypt_md5 {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'crypt-md5';
    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    $this->assert($impl);
    $this->doTests( $impl, $SALTED );

    return;
}

sub test_htpasswd_bcrypt {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'bcrypt';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $impl->ClearCache() if $impl->can('ClearCache');
    $this->doTests( $impl, $SALTED );

    #dumpFile();
}

sub test_htpasswd_crypt_crypt {
    my $this = shift;
    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'crypt';
    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    $this->assert($impl);
    $this->doTests( $impl, $SALTED );

    return;
}

sub test_htpasswd_sha1 {
    my $this = shift;

    #if ( !eval 'require Digest::SHA; 1;' ) {
    #    my $mess = $@;
    #    $mess =~ s/\(\@INC contains:.*$//s;
    #    $this->expect_failure();
    #    $this->annotate("CANNOT RUN SHA1 TESTS: $mess");
    #}

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'sha1';

    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    $this->assert($impl);
    $this->doTests($impl);

    return;
}

sub test_htpasswd_plain {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'plain';

    # User mole has empty password - not permitted when plain text passwords
    $this->{users1}->{mole}->{pass} = 'grub';
    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    $this->assert($impl);
    $this->doTests($impl);

    return;
}

sub test_htpasswd_md5 {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'md5';

    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    $this->assert($impl);
    $this->doTests($impl);

    return;
}

sub test_htpasswd_htdigest_md5 {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'htdigest-md5';

    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    $this->assert($impl);
    $this->doTests($impl);

    # Verify the passwords using deprecated md5, should be identical
    $Foswiki::cfg{Htpasswd}{Encoding} = 'md5';
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        if ( $user !~ /(?:alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $this->{users2}->{$user}->{pass} )
            );
        }
    }

    return;
}

sub test_htpasswd_htdigest_preserves_email {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 1;

    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');

    my @users = keys %{ $this->{users1} };
    foreach
      my $algo ( 'apache-md5', 'htdigest-md5', 'crypt', 'sha1', 'crypt-md5',
        'md5', 'bcrypt' )
    {
        my $user = pop @users;
        $Foswiki::cfg{Htpasswd}{Encoding} = $algo;
        $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
        my $added =
          $impl->setPassword( $user, $this->{users1}->{$user}->{pass} );
        $this->assert_null( $impl->error() );
        $impl->setEmails( $user, $this->{users1}->{$user}->{emails} );
        $this->assert_null( $impl->error() );
    }

    #dumpFile();

    $Foswiki::cfg{Htpasswd}{Encoding} = 'htdigest-md5';
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    foreach my $user ( keys %{ $this->{users1} } ) {
        $this->assert_str_equals(
            $this->{users1}->{$user}->{emails},
            join( ";", $impl->getEmails($user) )
        );
    }

    return;
}

sub test_htpasswd_apache_md5 {
    my $this = shift;

    if ( !eval 'require Crypt::PasswdMD5; 1;' ) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE MD5 TESTS: $mess");
    }

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'apache-md5';

    my $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    $this->assert($impl);
    $this->doTests( $impl, 0 );

    return;
}

sub test_ApacheHtpasswdUser_md5 {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'apache-md5';

    if ( !eval "require Apache::Htpasswd; 1;" ) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    if ( !eval "require Foswiki::Users::ApacheHtpasswdUser; 1;" ) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    my $impl = Foswiki::Users::ApacheHtpasswdUser->new( $this->{session} );

    # it should work the same as htpasswd (without salt)
    $this->doTests( $impl, $SALTED );

    # Verify the passwords using HdPaswdUser for compatibility
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        if ( $user !~ /(?:alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $this->{users2}->{$user}->{pass} )
            );
        }
    }

    return;
}

sub test_ApacheHtpasswdUser_crypt {
    my $this = shift;

    if ( $^O =~ /^MSWin/i ) {
        $this->expect_failure();
        $this->annotate("CANNOT RUN ApacheHtpasswdUser_crypt TESTS on Windows");
    }

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'crypt';

    if ( !eval "require Apache::Htpasswd; 1;" ) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    if ( !eval "require Foswiki::Users::ApacheHtpasswdUser; 1;" ) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    my $impl = Foswiki::Users::ApacheHtpasswdUser->new( $this->{session} );

    $this->doTests($impl);

    # Verify the passwords using HdPaswdUser for compatibility
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        if ( $user !~ /(?:alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $this->{users2}->{$user}->{pass} )
            );
        }
    }

    return;
}

# SMELL: Apache;:Htpasswd Version 1.8  doesn't appear to actually support writing
# plain text passwords.  So this test will fail.  The htpasswd file has
# encrypted passwords regardless of 'plain' setting.
sub DISABLE_test_ApacheHtpasswdUser_plain {
    my $this = shift;

    $Foswiki::cfg{Htpasswd}{AutoDetect} = 0;
    $Foswiki::cfg{Htpasswd}{Encoding}   = 'plain';

    if ( !eval "require Apache::Htpasswd; 1;" ) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    if ( !eval "require Foswiki::Users::ApacheHtpasswdUser; 1;" ) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    my $impl = Foswiki::Users::ApacheHtpasswdUser->new( $this->{session} );

    $this->doTests($impl);

    # Verify the passwords using HdPaswdUser for compatibility
    $impl = Foswiki::Users::HtPasswdUser->new( $this->{session} );
    $impl->ClearCache() if $impl->can('ClearCache');
    foreach my $user ( sort keys %{ $this->{users1} } ) {
        if ( $user !~ /(?:alligator|mole|budgie)/ ) {
            $this->assert(
                $impl->checkPassword( $user, $this->{users2}->{$user}->{pass} )
            );
        }
    }

    return;
}
1;
