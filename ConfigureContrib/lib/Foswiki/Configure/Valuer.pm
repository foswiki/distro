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

use Assert;
use Foswiki::Configure(qw/:keys/);

use Foswiki::Configure::TypeUI ();
use Foswiki::Configure::Load   ();

=begin TML

---++ ClassMethod new($values)

$values is a reference to the hash of current values (also $Foswiki::cfg,
but as taken from Foswiki.spec + Config.spec + LocalSite.cfg)

=cut

sub new {
    my ( $class, $values ) = @_;

    my $this = bless( {}, $class );
    $this->{values} = $values;
    return $this;
}

=begin TML

---++ ObjectMethod hasCurrentValue($valobj) -> $boolean
Return true if Foswiki::cfg contains an entry for the $valobj - irrespective
of whether it is undef.

=cut

sub hasCurrentValue {
    my ( $this, $value ) = @_;

    my $keys = $value->{keys};
    my $var  = '$this->{values}->' . $keys;
    return eval "exists($var)";
}

=begin TML

---++ ObjectMethod currentValue($valobj) -> $data
Get the *current* value from Foswiki::cfg
If the value does not exist (isn't defined in Foswiki::cfg) it will
return undef; you can use =hasCurrentValue= to determine which.

=cut

sub currentValue {
    my ( $this, $value ) = @_;

    my $keys = $value->{keys};
    my $var  = '$this->{values}->' . $keys;
    return undef unless eval "exists($var)";
    ASSERT( !$@, $@ ) if DEBUG;
    my $data;
    eval "\$data=$var";
    ASSERT( !$@, $@ ) if DEBUG;
    if ( defined $data && $value->{typename} eq 'REGEX' ) {

        # Note:  Perl 5.10 has use re qw(regexp_pattern); to decompile a pattern
        #        my $pattern = regexp_pattern($data);
        while ( $data =~ s/^\(\?-xism:(.*)\)$/$1/ ) { }
        while ( $data =~ s/^\(\?\^:(.*)\)$/$1/ )    { }    # 5.14 RE wrapper
    }
    return $data;
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
    # Items may have an associated "Enable" item; if they do, and
    # Enable is not set, the item's value is undef'd.

    foreach $param ( $query->param ) {
        next unless $param =~ /^TYPEOF:($Foswiki::Configure::Load::ITEMREGEX)$/;

        my $keys = $1;
        next if ( $keys =~ /^\{ConfigureGUI\}/ );

        # An item that has the MUST_ENABLE attribute has an extra
        # pseudo-item (see also UIs/Value.pm). If it isn't true, ignore
        # the setting.
        next
          if ( $query->param("${param}enabled")
            && !$query->param("${keys}enabled") );

        # The value of TYPEOF: is the type name. Load the type.
        my $typename = $query->param($param);

        # check and untaint
        Carp::confess "Bad typename '$typename'" unless $typename =~ /(\w+)/;
        $typename = $1;
        my $type = Foswiki::Configure::TypeUI::load( $typename, $keys );

        my $hentry = "\$this->{values}->$keys";
        my $curval = eval $hentry;
        ASSERT( !$@ ) if DEBUG;

        my @values = $query->param($keys);
        my $newval = $type->string2value(@values);

        if ( !$type->equals( $newval, $curval ) ) {

        #            print STDERR "loadCGIParams ($typename:$keys)($param) cgi:"
        #                .(defined $newval ? "'$newval'" : 'undef')
        #                ."!= cfg:".(defined $curval ? "'$curval'" : 'undef').
        #                " PARM=".($query->param($keys)||'?')."\n";

            eval "$hentry=\$newval";
            ASSERT( !$@ ) if DEBUG;

            $changed++;
            $updated->{$keys} = 1 if ($updated);
        }
    }
    return $changed;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
