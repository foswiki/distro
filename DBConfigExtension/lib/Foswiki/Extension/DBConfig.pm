# See bottom of file for license and copyright information

package Foswiki::Extension::DBConfig;

use DBI;
use Try::Tiny;

use Foswiki::FeatureSet qw(featuresComply);

use Foswiki::Class qw(extension);
extends qw(Foswiki::Extension);

use version 0.77; our $VERSION = version->declare(0.1.1);
our $API_VERSION = version->declare("2.99.0");
our @FS_REQUIRED = qw( MOO OOSPECS );

has dbh => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    builder   => 'prepareDbh',
);

has sth => (
    is      => 'rw',
    clearer => 1,
);

has data => ( is => 'rw', );

# Text to be indicate if we're reading or writing LSC.
has mode => ( is => 'rw', );

# We cannot use readLSC{Start|Record|Finalize} because we depend of database
# connection info stored in the local LSC file. This is also the reason for
# using plugAfter.
plugAfter 'Foswiki::Config::readLSC' => sub {
    my $this = shift;    # This is extension object, not the Foswiki::Config
    my ($params) = @_;

    # Do nothing if LSC reading has already failed.
    return if $params->{rc} == 0;

    $this->mode('read');

    my $cfg = $params->{object};    # This is Foswiki::Config

    my %callParams = @{ $params->{args} };
    my $cfgData = $callParams{data} // $cfg->data;
    $this->data($cfgData);

    my $connData = $cfgData->{Extensions}{DBConfigExtension}{Connection};

    # SMELL We expect all connection data to be in place if the Connection key
    # is defined. Fair enough for testing but better be fully checked for the
    # production use.
    if ( defined $connData ) {
        try {
            my $dbh = $this->dbh;

            my $records =
              $dbh->selectall_arrayref("SELECT `key`, value FROM LSC");

            foreach my $rec (@$records) {
                my ( $keyPath, $keyVal ) = @$rec;
                if ( defined $keyVal ) {
                    my $interp = eval $keyVal;
                    if ($@) {
                        Foswiki::Exception::Harmless->throw(
                            text => "Syntax error in value '$keyVal': $@" );
                    }
                    $keyVal = $interp;
                }

                $cfg->set( $keyPath, $keyVal, data => $cfgData, );
            }

        }
        catch {
            my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

            # For this moment it doesn't matter what kind of exception has been
            # caught. Just warn and return FALSE.
            warn $e->stringify;

            $params->{rc} = 0;
        };
    }
};

plugAround 'Foswiki::Config::writeLSCStart' => sub {
    my $this = shift;
    my ($params) = @_;

    #my $cfg = $params->{object};    # This is Foswiki::Config

    $this->mode('write');

    my %callParams = @{ $params->{args} };

    $this->clear_dbh;
    $this->data( $callParams{data} );

    my $dbh = $this->dbh;

    my $tblName =
      $this->data->{Extensions}{DBConfigExtension}{Connection}{Table};

    $this->lockTable;

    $dbh->do( 'DELETE FROM ' . $tblName // 'LSC' );

    my $statement =
        'INSERT INTO `'
      . $this->data->{Extensions}{DBConfigExtension}{Connection}{Table}
      . '` (`key`,`value`,`comment`) VALUES (?, ?, ?)';
    my $sth = $dbh->prepare($statement);

    $this->sth($sth);
};

plugAround 'Foswiki::Config::writeLSCRecord' => sub {
    my $this = shift;
    my ($params) = @_;

    my $cfg = $params->{object};    # This is Foswiki::Config

    my %callParams = @{ $params->{args} };

    #say STDERR "Writing to DBConfig: $callParams{key}='"
    #  . ( $callParams{value} // '' ), "'";

    my ( $keyPath, $keyVal, $comment ) = @callParams{qw(key value comment)};

    # SMELL Temporary solution to automate replacement of $Foswiki::cfg with ${}
    # macro format.
    $keyVal =~ s/\$Foswiki::cfg\{/\$\{/g;

    $this->sth->execute( $keyPath, $keyVal, $comment );
};

plugAround 'Foswiki::Config::writeLSCFinalize' => sub {
    my $this = shift;

    #my ($params) = @_;

    #my $cfg = $params->{object};    # This is Foswiki::Config

    #my %callParams = @{ $params->{args} };

    $this->dbh->commit;
    $this->dbh->disconnect;
    $this->clear_dbh;
};

tagHandler DBCONFIG_INFO => sub {
    my $this = shift;

    my $text = "*DBConfig Extension " . $VERSION . "*\n";

    my $connData =
      $this->app->cfg->data->{Extensions}{DBConfigExtension}{Connection};

    foreach my $kw (qw(Driver Host Port Database Table)) {
        $text .=
          "| *$kw* |  " . ( "=$connData->{$kw}=" // '_unknown_' ) . "|\n";
    }

    return $text;
};

sub lockTable {
    my $this = shift;

    my $cfgData = $this->data;
    my $driver  = $cfgData->{Extensions}{DBConfigExtension}{Connection}{Driver};
    my $table   = $cfgData->{Extensions}{DBConfigExtension}{Connection}{Table};

    my $lockMode = $driver eq 'mysql' ? 'WRITE' : 'IN EXCLUSIVE MODE';

    $this->dbh->do("LOCK TABLE $table $lockMode");
}

sub prepareDbh {
    my $this = shift;

    my $cfgData = $this->data;

    my $connData = $cfgData->{Extensions}{DBConfigExtension}{Connection};

    my $dsn = "DBI:"
      . $connData->{Driver}
      . ":database="
      . $connData->{Database}
      . ";host="
      . $connData->{Host};

    $dsn .= ";port" . $connData->{Port}
      if defined $connData->{Port};

    my $dbh = DBI->connect(
        $dsn,
        $connData->{User},
        $connData->{Password},
        {
            AutoCommit  => 0,
            RaiseError  => 1,
            PrintError  => 0,
            HandleError => sub {
                $this->_dbiError(@_);
            },
        }
    );

    # SMELL Must be some kind of Foswiki::Exception::Config:: exception. Fatal
    # is used for test purposes only.
    Foswiki::Exception::Fatal->throw(
            text => "Failed to connect to database '"
          . $connData->{Database} . ": "
          . $DBI::errstr, )
      unless defined $dbh;

    return $dbh;
}

sub _dbiError {
    my $this = shift;

    if ( $this->has_dbh && defined $this->dbh ) {
        $this->dbh->rollback;
        $this->dbh->disconnect;
        $this->clear_dbh;
    }

    # SMELL Must be some kind of Foswiki::Exception::Config:: exception. Fatal
    # is used for test purposes only.
    Foswiki::Exception::Fatal->throw(
        text => "Database config " . $this->mode . " failed: " . $_[0], );
}

=begin TML


---++ SEE ALSO

=Foswiki::Extensions=, =Foswiki::Extension=, =Foswiki::Class=, and
=ExtensionsTests= test suite.

=cut

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2017 Foswiki Contributors. Foswiki Contributors
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
