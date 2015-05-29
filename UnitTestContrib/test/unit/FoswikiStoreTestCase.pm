package FoswikiStoreTestCase;
use strict;
use warnings;
use utf8;

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
        $ENV{PATH} =~ m/^(.*)$/ms;
        local $ENV{PATH} = $1;    # untaint
        if ( eval { `co --version`; 1; } )    # Check to see if we have co
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

    # Data for attachments
    $this->{t_data} = join( '', map( chr($_), ( 0 .. 255 ) ) );
    $this->{t_data2} = join( '', map( chr( 255 - $_ ), ( 0 .. 255 ) ) );
    return;
}

sub tear_down {
    my $this = shift;

    unlink( $this->{t_datapath} )  if $this->{t_datapath};
    unlink( $this->{t_datapath2} ) if $this->{t_datapath2};
    $this->removeWeb( $this->{t_web} )
      if ( $this->{t_web}
        && $this->{session}->{store}->webExists( $this->{t_web} ) );
    $this->removeWeb( $this->{t_web2} )
      if ( $this->{t_web2}
        && $this->{session}->{store}->webExists( $this->{t_web2} ) );
    $this->SUPER::tear_down();
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
                next if $alg =~ m/RcsWrap/ && !rcs_is_installed();
                ($alg) = $alg =~ m/^(.*)$/ms;    # untaint
                eval "require Foswiki::Store::$alg;";
                $this->assert( !$@, $@ );
                my $algname = $alg;
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

    #return ( [ 'PlainFile' ], [ 'utf8' ] );
    if ($Foswiki::UNICODE) {
        return ( \@groups, [ 'iso8859', 'utf8', ] );
    }
    else {
        return \@groups;
    }
}

sub _make_data {
    my $this = shift;
    my $FILE;
    my $enc = $Foswiki::cfg{Store}{Encoding} || 'utf-8';

    $this->{t_datapath}  = "$Foswiki::cfg{TempfileDir}/TestAttachData";
    $this->{t_datapath2} = "$Foswiki::cfg{TempfileDir}/TestAttachData2";

    open( $FILE, ">", $this->{t_datapath} );
    print $FILE $this->{t_data};
    close($FILE);

    open( $FILE, ">", $this->{t_datapath2} );
    print $FILE $this->{t_data2};
    close($FILE);
}

sub open_data {
    my ( $this, $k ) = @_;

    my $fh;
    open( $fh, '<', $this->{$k} );
    return $fh;
}

sub utf8 {
    my $this = shift;
    $Foswiki::cfg{Site}{Locale} = 'en_US.utf-8';
    $Foswiki::cfg{UseLocale} = 1;
    undef $Foswiki::cfg{Store}{Encoding};
    $this->{t_web}       = 'Temporary普通话Web1';
    $this->{t_web2}      = 'Temporary国语Web2';
    $this->{t_topic}     = 'Testру́сскийTopic';
    $this->{t_datafile}  = "ŠňáĺľŠťěř.gif";
    $this->{t_datapath}  = "$Foswiki::cfg{TempfileDir}/$this->{t_datafile}";
    $this->{t_datafile2} = "پښتانهټبرونه.gif";
    $this->{t_datapath2} = "$Foswiki::cfg{TempfileDir}/$this->{t_datafile2}";
    $this->_make_data();
}

sub iso8859 {
    my $this = shift;

    $Foswiki::cfg{Site}{Locale}    = 'en_US.iso-8859-1';
    $Foswiki::cfg{UseLocale}       = 1;
    $Foswiki::cfg{Store}{Encoding} = 'iso-8859-1';
    my $s =
      Encode::decode( 'iso-8859-1',
        join( '', map( chr($_), ( 160 .. 255 ) ) ) );
    my $n = $s;
    $n =~ s/$Foswiki::cfg{NameFilter}//g;
    $this->{t_web}       = "Temporary${n}Web1";
    $this->{t_web2}      = "Temporary${n}Web2";
    $this->{t_topic}     = "Test${n}Topic";
    $this->{t_datafile}  = "${n}1.gif";
    $this->{t_datafile2} = "${n}2.gif";
    $this->_make_data();
}

1;
