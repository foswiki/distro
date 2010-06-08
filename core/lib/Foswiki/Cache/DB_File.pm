# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Cache::DB_File;

Implementation of a Foswiki::Cache using DB_File. See Foswiki::Cache
for details of the methods implemented by this class.

=cut

package Foswiki::Cache::DB_File;

use strict;
use warnings;
use DB_File;
use Storable       ();
use Foswiki::Cache ();
use Fcntl qw( :flock O_RDONLY O_RDWR O_CREAT );
use Assert;

use constant F_STORABLE => 1;

@Foswiki::Cache::DB_File::ISA = ('Foswiki::Cache');

sub new {
    my ( $class, $session ) = @_;

    return bless( $class->SUPER::new($session), $class );
}

sub init {
    my ( $this, $session ) = @_;

    $this->SUPER::init($session);
    $this->{filename} = $Foswiki::cfg{Cache}{DBFile}
      || $Foswiki::cfg{WorkingDir} . '/foswiki_db';

    # first we are in read-only mode - we retie for writing
    $this->_tie('ro');
}

sub get {
    my ( $this, $key ) = @_;

    return undef unless $this->{handler};

    my $pageKey = $this->genKey($key);

    if ( $this->{delBuffer} && $this->{delBuffer}{$pageKey} ) {
        return undef;
    }

    my $obj = $this->{readBuffer}{$pageKey};
    if ($obj) {
        return undef if $obj eq '_UNKNOWN_';
        return $obj;
    }

    $obj = '_UNKNOWN_';

    my $value = $this->{tie}->{$pageKey} || '';
    if ($value) {
        my $flags = int( substr( $value, 0, 3 ) );
        $obj = substr( $value, 5 );
        if ( $flags & F_STORABLE ) {

           #Foswiki::Func::writeWarning("reading $pageKey is a storable image");
            eval { $obj = Storable::thaw($obj); };
            if ($@) {
                print STDERR
"WARNING: found a corrupt storable image for pageKey='$pageKey' ... deleting\n";
                print STDERR $@ . "\n";
                delete $this->{tie}->{$pageKey};    # corrupt storable image
                $obj = '_UNKNOWN_';
            }
        }
        else {

            #Foswiki::Func::writeWarning("reading $pageKey is a scalar");
        }
    }

    $this->{readBuffer}{$pageKey} = $obj;
    return undef if $obj eq '_UNKNOWN_';

    return $obj;
}

sub finish {
    my $this = shift;

    if ( $this->{handler} ) {
        if ( $this->{delBuffer} || $this->{writeBuffer} ) {

            # retie the database
            $this->_tie('rw');

            if ( $this->{delBuffer} ) {
                foreach my $key ( keys %{ $this->{delBuffer} } ) {
                    next unless $this->{delBuffer}{$key};
                    delete $this->{tie}->{$key};
                }
            }

            if ( $this->{writeBuffer} ) {
                foreach my $key ( keys %{ $this->{writeBuffer} } ) {
                    my $obj = $this->{writeBuffer}{$key};
                    next unless $obj;
                    my $value;
                    my $flags = 0;
                    if ( ref $obj ) {
                        $flags |= F_STORABLE;
                        $value =
                          sprintf( "%03d::", $flags ) . Storable::freeze($obj);

               #Foswiki::Func::writeWarning("writing $key as a storable image");
                    }
                    else {
                        $value = sprintf( "%03d::", $flags ) . $obj;

                       #Foswiki::Func::writeWarning("writing $key is a scalar");
                    }
                    $this->{tie}->{$key} = $value;

              #my $test = $this->{tie}->{$key} || '';
              #if ($value ne $test) {
              #  print STDERR "WARNING: key=$key - test does not match value\n";
              #  print STDERR "value=$value\n";
              #  print STDERR "test=$test\n";
              #}
                }
            }

            $this->_untie();
        }
    }

    undef $this->{session};
    undef $this->{readBuffer};
    undef $this->{writeBuffer};
    undef $this->{delBuffer};
}

# (re)ties the cache db using the given $mode 'ro' or 'rw'
# a file lock is acquired depending on the intended tie mode.
sub _tie {
    my ( $this, $mode ) = @_;

    # untie first
    if ( $this->{handler} ) {
        $this->_untie();
    }

    # aquire a file lock
    my $lockfile = "$this->{filename}.lock";
    open( $this->{lock}, ">$lockfile" )
      or die "can't create lockfile $lockfile";

    if ( $mode eq 'rw' ) {
        $mode = O_CREAT | O_RDWR;
        flock( $this->{lock}, LOCK_EX )
          or die "can't lock cache db: $!";
    }
    elsif ( $mode eq 'ro' ) {
        $mode = O_CREAT | O_RDONLY;
        flock( $this->{lock}, LOCK_SH )
          or die "can't lock cache db: $!";
    }
    else {
        ASSERT( 0, "unknown mode $mode in Cache::DB_File" );
    }

    $this->{handler} = tie %{ $this->{tie} },
      'DB_File', $this->{filename}, $mode, 0664, $DB_HASH
      or die "Cannot open file $this->{filename}: $!";
}

# unties this module from the DB
sub _untie {
    my ($this) = @_;

    if ( $this->{handler} ) {
        undef $this->{handler};
        untie %{ $this->{tie} };

        flock( $this->{lock}, LOCK_UN )
          or die "unable to unlock: $!";

        close $this->{lock};
    }
}

sub clear {
    my $this = shift;

    return unless $this->{handler};
    $this->_tie('rw');
    %{ $this->{tie} } = ();
    $this->_tie('ro');

    undef $this->{writeBuffer};
    undef $this->{delBuffer};
    undef $this->{readBuffer};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
