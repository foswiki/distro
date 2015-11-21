# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Attrs

Class of attribute sets, designed for parsing and storing attribute values
from a macro e.g. =%<nop>MACRO{"joe" fred="bad" joe="mad"}%=

An attribute set is a hash containing an entry for each parameter. The
default parameter (unnamed quoted string) is named <code>_<nop>DEFAULT</code> in the hash.

Attributes declared later in the string will override those of the same
name defined earlier. The one exception to this is the _DEFAULT key, where
the _first_ instance is always taken.

As well as the default Foswiki syntax (parameter values double-quoted)
this class also parses single-quoted values, unquoted spaceless
values, spaces around the =, and commas as well as spaces separating values.
The extended syntax has to be enabled by passing the =$friendly= parameter
to =new=.

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (TWiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

# THIS PACKAGE IS PART OF THE PUBLISHED API USED BY EXTENSION AUTHORS.
# DO NOT CHANGE THE EXISTING APIS (well thought out extensions are OK)
# AND ENSURE ALL POD DOCUMENTATION IS COMPLETE AND ACCURATE.

package Foswiki::Attrs;

use strict;
use warnings;
use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Used in interpolation an regexes, so constant not appropriate
our $MARKER = "\0";

=begin TML

---++ ClassMethod new ($string) => \%attrsObjectRef

   * =$string= - String containing attribute specification

Parse a standard attribute string containing name=value pairs and create a new
attributes object. The value may be a word or a quoted string. If there is an
error during parsing, the parse will complete but $attrs->{_ERROR} will be
set in the new object. $attrs->{_RAW} will always contain the full unprocessed
$string.

=cut

sub new {
    my ( $class, $string, $friendly ) = @_;
    my $this = bless( {}, $class );

    $this->{_RAW} = $string;

    return $this unless defined($string);

    # Escapes
    $string =~ s/\\'/\x01/g;
    $string =~ s/\\"/\x02/g;

    if ($friendly) {
        _friendly( $this, $string );
    }
    else {
        _unfriendly( $this, $string );
    }
    for ( values %$this ) {
        s/\x01/'/g;
        s/\x02/"/g;
    }
    return $this;
}

sub _assign { ${ $_[0] } = $_[1]; }
sub _append { ${ $_[0] } .= $_[1]; }

# Kept as potential new FeatureProposal:
# sub _prepend { ${$_[0]} = $_[1] . ${$_[0]}; }

# Perl warned about undefined $_[1] (and the sub was buggy)
# hence 'my ($sr, $v) = @_;' which fixed it
sub _multi { my ( $sr, $v ) = @_; ${$sr} x= $v if $v =~ /[0-9]+/; }

my %Ops = (

    #    Op  => [ WithName , Without Name ]
    '=' => [ \&_assign, undef ],

    '+=' => [ \&_append, undef ],
    '+'  => [ undef,     \&_append ],

    # Kept as potential FeatureProposal
    # The community will also need to agree operators to use
    #    '-=' => [ \&_prepend , undef ] ,
    #    '-'  => [ undef      , \&_prepend ] ,

);

sub OpRegex {
    my ($opType) = @_;
    return join(
        '|', map { quotemeta($_); }
          grep { $Ops{$_}->[$opType]; }

          # We need to reverse sort to ensure that in cases when we have two
          # synonymous ops (e.g. '+=' & '=') then we always handle += first
          # (remember random hash order otherwise)
          # This ensures that in the _friendly case parm=56 +=78 always give
          # parm as '5678' and not '56=78'
          reverse sort { length($a) <=> length($b) }
          keys %Ops
    );
}

my $nameOp = OpRegex(0);
my $nonmOp = OpRegex(1);

sub _unfriendly {
    my ( $this, $string ) = @_;

    my $key   = '_DEFAULT';
    my $first = 1;

    if ( $string =~
s/^\s*\"(.*?)\"\s*(?=([a-z0-9_]+\s*(?:$nameOp)|[a-z0-9_]*\s*(?:$nonmOp))\s*\"|$)//is
      )
    {
        $this->{_DEFAULT} = $1;
    }

    while ( $string =~ m/\S/s ) {

        # name $op "value" pairs
        if ( $string =~ s/^\s*([a-z0-9_]+)\s*($nameOp)\s*\"(.*?)\"//is ) {
            $key = $1;
            $Ops{$2}[0]( \$this->{$key}, $3 );
            $first = 0;
        }

        # $op "value"  (the name (or key) is the most recent one seen)
        elsif ( $string =~ s/^\s*($nonmOp)\s*\"(.*?)\"//is ) {
            $Ops{$1}[1]( \$this->{$key}, $2 );
            $first = 0;
        }

        # simple double-quoted value with no name, sets the default
        elsif ( $string =~ s/^\s*\"(.*?)\"//s ) {
            unless ( defined( $this->{_DEFAULT} ) ) {
                $key = '_DEFAULT';
                $this->{_DEFAULT} = $1;
            }
            $first = 0;
        }

        # Unquoted string not matching any recognised structure
        # SMELL: unchecked implicit untaint?
        elsif ( $string =~ m/^\s*(.*?)\s*$/s ) {
            $this->{_DEFAULT} = $1 if ($first);
            last;
        }
    }
}

sub _friendly {
    my ( $this, $string ) = @_;

    my $key = "_DEFAULT";

    while ( $string =~ m/\S/s ) {

        # name $op "value" pairs
        if ( $string =~ s/^[\s,]*([a-z0-9_]+)\s*($nameOp)\s*\"(.*?)\"//is ) {
            $key = $1;
            $Ops{$2}[0]( \$this->{$key}, $3 );
        }

        # simple double-quoted value with no name, sets the default
        elsif ( $string =~ s/^[\s,]*\"(.*?)\"//s ) {
            unless ( defined( $this->{_DEFAULT} ) ) {
                $key = '_DEFAULT';
                $this->{_DEFAULT} = $1;
            }
        }

        # name $op 'value' pairs
        elsif ( $string =~ s/^[\s,]*([a-z0-9_]+)\s*($nameOp)\s*'(.*?)'//is ) {
            $key = $1;
            $Ops{$2}[0]( \$this->{$key}, $3 );
        }

        # name $op value pairs
        elsif (
            $string =~ s/^[\s,]*([a-z0-9_]+)\s*($nameOp)\s*([^\s,\}\'\"]*)//is )
        {
            $key = $1;
            $Ops{$2}[0]( \$this->{$key}, $3 );
        }

        # $op "value"
        elsif ( $string =~ s/^[\s,]*($nonmOp)\s*\"(.*?)\"//is ) {
            $Ops{$1}[1]( \$this->{$key}, $2 );
        }

        # $op 'value'
        elsif ( $string =~ s/^[\s,]*($nonmOp)\s*'(.*?)'//is ) {
            $Ops{$1}[1]( \$this->{$key}, $2 );
        }

        # $op value
        elsif ( $string =~ s/^[\s,]*($nonmOp)\s*([^\s,\}\'\"]*)//is ) {
            $Ops{$1}[1]( \$this->{$key}, $2 );
        }

        # simple single-quoted value with no name, sets the default
        elsif ( $string =~ s/^[\s,]*'(.*?)'//s ) {
            unless ( defined( $this->{_DEFAULT} ) ) {
                $key = '_DEFAULT';
                $this->{_DEFAULT} = $1;
            }
        }

        # simple name with no value (boolean, or _DEFAULT)
        elsif ( $string =~ s/^[\s,]*([a-z][a-z0-9_]*)\b//is ) {
            $this->{$1} = 1;
        }

        # otherwise the whole string - sans padding - is the default
        else {

            # SMELL: unchecked implicit untaint?
            if ( $string =~ m/^\s*(.*?)\s*$/s
                && !defined( $this->{_DEFAULT} ) )
            {
                $this->{_DEFAULT} = $1;
            }
            last;
        }
    }
    return $this;
}

=begin TML

---++ ObjectMethod isEmpty() -> boolean

Return false if attribute set is not empty.

=cut

sub isEmpty {
    my $this = shift;

    foreach my $k ( keys %$this ) {
        return 0 if $k ne '_RAW';
    }
    return 1;
}

=begin TML

---++ ObjectMethod remove($key) -> $value

   * =$key= - Attribute to remove
Remove an attr value from the map, return old value. After a call to
=remove= the attribute is no longer defined.

=cut

sub remove {
    my ( $this, $attr ) = @_;
    my $val = $this->{$attr};
    delete( $this->{$attr} ) if ( exists $this->{$attr} );
    return $val;
}

=begin TML

---++ ObjectMethod stringify() -> $string

Generate a printed form for the map, using strict
attribute syntax, with only the single-quote extension
syntax observed (no {} brackets, though).

=cut

sub stringify {
    my $this = shift;
    my $key;
    my @ss;
    foreach $key ( sort keys %$this ) {
        if ( $key ne '_ERROR' && $key ne '_RAW' ) {
            my $es = ( $key eq '_DEFAULT' ) ? '' : $key . '=';
            my $val = $this->{$key};
            $val =~ s/"/\\"/g;
            push( @ss, $es . '"' . $val . '"' );
        }
    }
    return join( ' ', @ss );
}

=begin TML

---++ ObjectMethod TO_JSON() -> \%map

Support for the JSON cpan module

=cut

sub TO_JSON {
    my $this = shift;
    my %res;
    while ( my ( $k, $v ) = each %$this ) {
        $res{$k} = $v;
    }
    return \%res;
}

=begin TML

---++ StaticMethod findFirstOccurenceAttrs($macro, $text) -> $args

Extract the first occurence of a macro from the text, taking into
account balancing %{}%'s. For example, given $macro=X and $text="X%Y{%X{%X{}%}%}%Y"
it will return "%X{}%". Given $text="%X%" it will return ''. Given "YYY" it
will return undef, because neither "%X%" nor "%X{}%" occur.

=cut

sub findFirstOccurenceAttrs {
    my ( $macro, $text ) = @_;
    return undef unless $text =~ m/\%${macro}[%{]/s;
    my @queue = split( /(%[A-Za-z0-9_]*{|}%|\%${macro}\%)/, $text );
    my $eat   = 0;
    my $eaten = '';
    while ( scalar(@queue) ) {
        my $token = shift @queue;
        if ($eat) {
            if ( $token =~ m/^%[A-Za-z0-9_]*{$/ ) {
                $eat++;
            }
            elsif ( $eat && $token eq '}%' ) {
                $eat--;
                return $eaten if ( !$eat );
            }
            $eaten .= $token;
        }
        else {
            if ( $token eq "\%${macro}%" ) {
                return '';
            }
            elsif ( $token eq "\%${macro}\{" ) {
                $eat = 1;
            }
        }
    }
    return '';
}

# ---++ StaticMethod extractValue() -> $string
#
# Legacy support, formerly known as extractNameValuePair. This
# static method uses context information to determine how a value
# string is to be parsed. For example, if you have an attribute string
# like this:
#
# "abc def="ghi" jkl" def="qqq"
#
# then call extractValue( "def" ), it will return "ghi".

sub extractValue {
    my ( $str, $name ) = @_;

    my $value = '';
    return $value unless ($str);
    $str =~ s/\\\"/\\$MARKER/g;    # escape \"

    if ($name) {

        # format is: %VAR{ ... name = "value" }%
        if ( $str =~ m/(^|[^\S])$name\s*=\s*\"([^\"]*)\"/ ) {
            $value = $2 if defined $2;    # distinguish between '' and "0"
        }

    }
    else {

        # test if format: { "value" ... }
        # SMELL: unchecked implicit untaint?
        if ( $str =~
            m/(^|\=\s*\"[^\"]*\")\s*\"(.*?)\"\s*([a-z0-9_]+\s*=\s*\"|$)/ )
        {

            # is: %VAR{ "value" }%
            # or: %VAR{ "value" param="etc" ... }%
            # or: %VAR{ ... = "..." "value" ... }%
            # Note: "value" may contain embedded double quotes
            $value = $2 if defined $2;    # distinguish between '' and "0";

        }
        elsif ( ( $str =~ m/^\s*[a-z0-9_]+\s*=\s*\"([^\"]*)/ ) && ($1) ) {

            # is: %VAR{ name = "value" }%
            # do nothing, is not a standalone var

        }
        else {

            # format is: %VAR{ value }%
            $value = $str;
        }
    }
    $value =~ s/\\$MARKER/\"/g;    # resolve \"
    return $value;
}

# ---++ ObjectMethod get($key) -> $value
#
# | $key | Attribute to get |
# Get an attr value from the map.
#
# Synonymous with $attrs->{$key}. Retained mainly for compatibility with
# the old AttrsContrib.
sub get {
    my ( $this, $field ) = @_;
    return $this->{$field};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Derived from Contrib::Attrs, which is
Copyright (C) 2001 Motorola - All rights reserved
Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
