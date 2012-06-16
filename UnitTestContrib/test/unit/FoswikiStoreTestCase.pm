package FoswikiStoreTestCase;
use strict;
use warnings;

# Specialisation of FoswikiFnTestCase used to perform tests over all
# viable store implementations.
#
# Subclasses are expected to implement set_up_for_verify()
#
use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );
use File::Spec();

# Determine if RCS is installed. used in tests for RCS functionality.
our $rcs_installed;

sub rcs_is_installed {
    if ( !defined($rcs_installed) ) {
        $ENV{PATH} =~ /^(.*)$/ms;
        local $ENV{PATH} = $1;    # untaint
        if ( eval { `co -V`; 1; } )    # Check to see if we have co
        {
            $rcs_installed = 1;
        }
        else {
            $rcs_installed = 0;
            print STDERR
              "*** CANNOT RUN RcsWrap TESTS - NO COMPATIBLE co: $@\n";
        }
    }
    return $rcs_installed;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    return;
}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();

    return;
}

sub set_up_for_verify {
    die "ABSTRACT BASE CLASS";
}

sub fixture_groups {
    my $this = shift;
    my @groups;

    foreach my $dir (@INC) {
        my ( $volume, $directories ) = File::Spec->splitpath( $dir, 1 );

        $directories = File::Spec->catdir( File::Spec->splitdir($directories),
            qw(Foswiki Store) );
        if (
            opendir( my $D, File::Spec->catpath( $volume, $directories, '' ) ) )
        {
            foreach my $alg ( readdir $D ) {
                next unless $alg =~ s/^(.*)\.pm$/$1/;
                next if $alg =~ /RcsWrap/ && !rcs_is_installed();
                ($alg) = $alg =~ /^(.*)$/ms;    # untaint
                $this->assert( eval "require Foswiki::Store::$alg; 1;" );
                my $algname = ref($this) . '_' . $alg;
                next if defined &{$algname};
                no strict 'refs';
                *{$algname} = sub {
                    my $self = shift;
                    $Foswiki::cfg{Store}{Implementation} =
                      'Foswiki::Store::' . $alg;
                    $self->set_up_for_verify();
                };
                use strict 'refs';
                push( @groups, $algname );
            }
            closedir($D);
        }
    }

    # Uncomment below to test one store in isolation
    #    return [ ref($this) . '_PlainFile' ];
    #    return [ ref($this) . '_RcsWrap' ];
    #    return [ ref($this) . '_RcsLite' ];
    return \@groups;
}

1;
