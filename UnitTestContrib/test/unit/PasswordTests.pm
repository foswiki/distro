use strict;

package PasswordTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Foswiki;
use Foswiki::Users;
use Foswiki::Users::HtPasswdUser;

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
    budgie => { pass => 'tweet', emails => 'budgie@flock;budge@oz' },
    lion   => { pass => 'roar',  emails => 'lion@pride' },
    mole   => { pass => '',      emails => 'mole@hill' }
};

my $users2 = {
    alligator => { pass => 'gnu',    emails => $users1->{alligator}->{emails} },
    bat       => { pass => 'moth',   emails => $users1->{bat}->{emails} },
    budgie    => { pass => 'millet', emails => $users1->{budgie}->{emails} },
    lion => { pass => 'antelope',  emails => $users1->{lion}->{emails} },
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
        $this->assert_str_equals( $encrapted{$user},
            $impl->encrypt( $user, $users1->{$user}->{pass} ) );
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

sub TODO_test_htpasswd_plain {
    my $this = shift;
    $Foswiki::cfg{Htpasswd}{Encoding} = 'plain';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests($impl);
}

sub test_htpasswd_crypt_md5 {
    my $this = shift;

    if ( $Foswiki::cfg{DetailedOS} eq 'darwin' ) {
        $this->expect_failure();
        $this->annotate("CANNOT RUN crypt-md5 TESTS on OSX");
    }
    if ( $Config{myuname} =~ /strawberry/i ) {
        $this->expect_failure();
        $this->annotate("CANNOT RUN crypt-md5 TESTS on strawberry perl");
    }
    $Foswiki::cfg{Htpasswd}{Encoding} = 'crypt-md5';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests( $impl, 1 );
}

sub test_htpasswd_crypt_crypt {
    my $this = shift;
    $Foswiki::cfg{Htpasswd}{Encoding} = 'crypt';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests( $impl, 1 );
}

sub test_htpasswd_sha1 {
    my $this = shift;

    eval 'use MIME::Base64';
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN SHA1 TESTS: $mess");
        return;
    }
    eval 'use Digest::SHA';
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN SHA1 TESTS: $mess");
        return;
    }

    $Foswiki::cfg{Htpasswd}{Encoding} = 'sha1';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests( $impl, 0 );
}

sub test_htpasswd_md5 {
    my $this = shift;
    eval 'use Digest::MD5';
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN MD5 TESTS: $mess");
        return;
    }

    $Foswiki::cfg{Htpasswd}{Encoding} = 'md5';
    my $impl = new Foswiki::Users::HtPasswdUser( $this->{session} );
    $this->assert($impl);
    $this->doTests( $impl, 0 );
}

sub test_htpasswd_apache {
    my $this = shift;

    eval "use Foswiki::Users::ApacheHtpasswdUser";
    if ($@) {
        my $mess = $@;
        $mess =~ s/\(\@INC contains:.*$//s;
        $this->expect_failure();
        $this->annotate("CANNOT RUN APACHE HTPASSWD TESTS: $mess");
    }

    my $impl = Foswiki::Users::ApacheHtpasswdUser->new( $this->{session} );

    # it should work the same as htpasswd (without salt)
    $this->doTests( $impl, 0 );
}

1;
