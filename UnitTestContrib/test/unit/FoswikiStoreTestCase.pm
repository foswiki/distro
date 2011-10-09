package FoswikiStoreTestCase;

# Specialisation of FoswikiFnTestCase used to perform tests over all
# viable store implementations.
#
# Subclasses are expected to implement set_up_for_verify()
#
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

# Determine if RCS is installed. used in tests for RCS functionality.
our $rcs_installed;

sub rcs_is_installed {
    if ( !defined($rcs_installed) ) {
	$ENV{PATH} =~ /^(.*)$/ms; $ENV{PATH} = $1; # untaint
        eval {
            `co -V`;    # Check to see if we have co
        };
        if ( $@ || $? ) {
            $rcs_installed = 0;
            print STDERR
              "*** CANNOT RUN RcsWrap TESTS - NO COMPATIBLE co: $@\n";
        }
        else {
            $rcs_installed = 1;
        }
    }
    return $rcs_installed;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();
}

sub set_up_for_verify {
    die "ABSTRACT BASE CLASS";
}

sub fixture_groups {
    my $this = shift;
    my @groups;

    foreach my $dir (@INC) {
        if ( opendir( D, "$dir/Foswiki/Store" ) ) {
            foreach my $alg ( readdir D ) {
                next unless $alg =~ s/^(.*)\.pm$/$1/;
                next if $alg =~ /RcsWrap/ && !rcs_is_installed();
                ($alg) = $alg =~ /^(.*)$/ms; # untaint
		eval "require Foswiki::Store::$alg";
		die $@ if $@;
		my $algname = ref($this).'_'.$alg;
                next if defined &$algname;
		no strict 'refs';
		*$algname = sub {
		    my $this = shift;
		    $Foswiki::cfg{Store}{Implementation} =
			'Foswiki::Store::'.$alg;
		    $this->set_up_for_verify();
		};
		use strict 'refs';
                push(@groups, $algname);
		$seen{$alg} = 1;
            }
            closedir(D);
        }
    }
    return \@groups;
}

1;
