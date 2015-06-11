# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Password;

use strict;
use warnings;
use Assert;

use Crypt::PasswdMD5;
use Encode;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    # Checkers may be called in a script context, in which case
    # Foswiki::Func is not available. However in a script context
    # this option isn't interesting anyway.
    return
      unless defined $Foswiki::Plugins::SESSION
      && eval("require Foswiki::Func");
    my $it = Foswiki::Func::eachGroupMember( $Foswiki::cfg{SuperAdminGroup} );
    my @admins;

    while ( defined $it && $it->hasNext() ) {
        push @admins, Foswiki::Func::getCanonicalUserID( $it->next() );
    }

    $reporter->WARN(
"$Foswiki::cfg{SuperAdminGroup} contains no users except for the _internal admin_ $Foswiki::cfg{AdminUserWikiName} ($Foswiki::cfg{AdminUserLogin}) and the _internal admin_ password is not set ( =\$Foswiki::cfg{Password}= )"
      )
      if ( scalar(@admins) lt 2
        && !$Foswiki::cfg{Password}
        && !$Foswiki::cfg{FeatureAccess}{Configure} );

}

=begin TML

---++ =onSave()= handler

When the password is set using the Web or CLI configure interface
hash it with salt following the Apache APR1 password standard.

=cut

sub onSave {
    my $this     = shift;
    my $reporter = shift;

    #my ( $key, $value ) = shift;

    return unless ( $_[1] );    # If no password, let it through.

    # Allow an existing encoded password to go through without re-hashing it.
    unless ( $_[1]
        && length( $_[1] ) eq 37
        && $_[1] =~ m/^\$apr1\$/ )
    {
        my $pw = _setPassword( 'admin', $_[1] );
        $_[1] = $pw;
    }
}

sub _setPassword {
    my ( $login, $passwd ) = @_;
    my $salt = '$apr1$';
    my @saltchars = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );
    foreach my $i ( 0 .. 7 ) {

        # generate a salt not only from rand() but also mixing
        # in the users login name: unecessary
        $salt .= $saltchars[
          (
              int( rand( $#saltchars + 1 ) ) +
                $i +
                ord( substr( $login, $i % length($login), 1 ) ) )
          % ( $#saltchars + 1 )
        ];
    }

  #    print STDERR "encoded $passwd as "
  #      . Crypt::PasswdMD5::apache_md5_crypt( $passwd, substr( $salt, 0, 14 ) )
  #      . "\n";

    return Crypt::PasswdMD5::apache_md5_crypt( Encode::encode_utf8($passwd),
        substr( $salt, 0, 14 ) );
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014-2015 Foswiki Contributors. Foswiki Contributors
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
