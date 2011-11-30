# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Valuer
A container for configuration data values. This class is used to refer
to two hashes of configuration values. The first is a hash of default
values, and the second (which will have mostly the same keys) contains
the *current* value (i.e. the value after any edits have been applied).

=cut

package Foswiki::Configure::Valuer;

use strict;
use warnings;

use Foswiki::Configure::Type ();

=begin TML

---++ ClassMethod new($defaults, $values)

$defaults is a reference to the raw hash of defaults ($Foswiki::cfg, as
taken from Foswiki.spec + Config.spec)

$values is a reference to the hash of current values (also $Foswiki::cfg,
but as taken from Foswiki.spec + Config.spec + LocalSite.cfg)

=cut

sub new {
    my ( $class, $defaults, $values ) = @_;

    my $this = bless( {}, $class );
    $this->{defaults} = $defaults;
    $this->{values}   = $values;

    return $this;
}

# Get a value from one of the value sets (defaults or values)
sub _getValue {
    my ( $this, $value, $set ) = @_;
    my $keys = $value->getKeys();
    my $var  = '$this->{' . $set . '}->' . $keys;
    my $val;
    eval '$val = ' . $var . ' if exists(' . $var . ')';
    die "Unable to obtain value from $var.  eval failed with $@\n" if ($@);
    if ( defined $val ) {

        # SMELL: Really shouldn't do this unless we are sure it's an RE,
        # but the probability of this string occurring elsewhere than an
        # RE is so low that we can afford to take the risk.
        # Note:  Perl 5.10 has use re qw(regexp_pattern); to decompile a pattern
        #        my $pattern = regexp_pattern($val);
        while ( $val =~ s/^\(\?-xism:(.*)\)$/$1/ ) { }
        while ( $val =~ s/^\(\?\^:(.*)\)$/$1/ )    { }    # 5.14 RE wrapper
    }
    return $val;
}

=begin TML

---++ ObjectMethod getCurrentValue() -> $data
Get the *current* value

=cut

sub currentValue {
    my ( $this, $value ) = @_;
    return $this->_getValue( $value, 'values' );
}

=begin TML

---++ ObjectMethod defaultValue() -> $data
Get the *default* value

=cut

sub defaultValue {
    my ( $this, $value ) = @_;
    return $this->_getValue( $value, 'defaults' );
}

=begin TML

---++ ObjectMethod loadCGIParams($query, \%updated)

Get changed values from CGI. Each parameter is identified by a
TYPEOF: param that specifies the keys e.g. ?TYPEOF:{Kiss}=Smooch. The
type is used to determine if the value of {Kiss} in CGI is different to
the value known to the Valuer (i.e. has been updated). If it is, the keys
are added to the $updated hash.

=cut

sub loadCGIParams {
    my ( $this, $query, $updated ) = @_;
    my $param;
    my $changed = 0;

    # Each config param has an associated TYPEOF: param, so we only
    # pick up those things that we really want
    foreach $param ( $query->param ) {

        # the - (and therefore the ' and ") is required for languages
        # e.g. {Languages}{'zh-cn'}.
        next unless $param =~ /^TYPEOF:((?:{[-:\w'"]+})*)/;
        my $keys = $1;

        # The value of TYPEOF: is the type name
        my $typename = $query->param($param);
        Carp::confess "Bad typename '$typename'" unless $typename =~ /(\w+)/;
        $typename = $1;    # check and untaint
        my $type   = Foswiki::Configure::Type::load( $typename, $keys );
        my $newval = $type->string2value( $query->param($keys) );
        my $xpr    = '$this->{values}->' . $keys;
        my $curval = eval $xpr;
        if ( !$type->equals( $newval, $curval ) ) {

#Foswiki::log("loadCGIParams ($typename: $keys)($param)\n'$newval' != \n'".($curval||'undef')."'");
            eval $xpr . ' = $newval';
            $changed++;
            $updated->{$keys} = 1;
        }
    }
    return $changed;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
