# See bottom of file for license and copyright information

=pod

---+ package Foswiki::Configure::Value

A Value object is a Foswiki::Configure::Item that represents a single entry
in a configuration spec i.e. it is the leaf type in a configuration
model.

Note that this object does *not* store the actual value of a configuration
item. This object is the *model* only.

---++ Value Attributes
Values may have attributes associated with them in the .spec file. These
attributes are identified by UPPERCASE names and may be one of four types:

   * boolean - a single name enables the option.
   * string - a name followed by an equals sign, followed by a quoted string
     (single or double quotes both supported)
   * keyword - a name followed by a keyword

The special prefix 'NO' on any attribute name will clear the value of
that attributes.

In support of older .spec files, the following are also supported (though
their usage is deprecated):

   * Single-character attributes M and H. These are synonymous with
     MANDATORY and HIDDEN.
   * Unquoted conditions - DISPLAY_IF and ENABLE_IF may be followed by a
     a space, and terminated by /DISPLAY_IF (or /ENABLE_IF) or the end of
     the string.

Formally,

attrs ::= attr attrs ;
attr ::= name '=' values | name ;
values ::= value | values ';' fattr ;
value ::= quoted-string | name ;
name is made up of [-A-Z0-9]

Certain attributes define a 'process' that allows further parsing of the
value of an attribute. A process is a ref to a function that performs
this parsing. Execution of processes may be supressed by setting
$Foswiki::Configure::LoadSpec::RAW_VALS to 1.

Processes are used to parse 'FEEDBACK' and 'CHECK' values.

=cut

package Foswiki::Configure::Value;

use strict;
use warnings;

use Data::Dumper ();

use Assert;

use Foswiki::Configure::Item ();
our @ISA = ('Foswiki::Configure::Item');

use Foswiki::Configure::FileUtil ();
use Foswiki::Configure::Reporter ();

# Options valid in a .spec for a leaf value
use constant ATTRSPEC => {
    FEEDBACK        => { parse_val => '_FEEDBACK' },
    CHECK           => { parse_val => '_CHECK' },
    CHECKER         => {},
    CHECK_ON_CHANGE => {},
    MANDATORY       => {},
    MULTIPLE        => {},         # Allow multiple select
    HIDDEN          => {},
    SPELLCHECK      => {},
    EXPERT          => {},
    DISPLAY_IF      => { openclose => 1 },
    ENABLE_IF       => { openclose => 1 },

    # Rename single character options (legacy)
    M => 'MANDATORY',
    H => 'HIDDEN'
};

=begin TML

---++ ClassMethod new($typename, %options)
   * =$typename= e.g 'STRING', name of one of the Foswiki::Configure::TypeUIs
     Defaults to 'UNKNOWN' if not given ('', 0 or undef).

Constructor.

*IMPORTANT NOTE*

When constructing value objects in Pluggables, bear in mind that the
=default= value is stored as *an unparsed perl string*. This string
is checked for valid perl during the .spec load, but otherwise
stored verbatim. It must be evaled to get the 'actual' default
value.

The presence of the key (tested using 'exists') indicates whether a
default is provided or not. undef is a valid default.

=cut

sub new {
    my ( $class, $typename, @options ) = @_;

    my $this = $class->SUPER::new(
        typename => ( $typename || 'UNKNOWN' ),
        keys => '',

        # We do not give it a value here, because the presence of
        # the key indicates that a default is provided.
        #default    => undef,
        @options
    );
    $this->{CHECK} ||= [];

    return $this;
}

sub parseTypeParams {
    my ( $this, $str ) = @_;

    if ( $this->{typename} =~ /^(SELECT|BOOLGROUP)/ ) {

        # SELECT types *always* start with a comma-separated list of
        # things to select from. These things may be words or wildcard
        # class specifiers, or quoted strings (no internal quotes)
        my @picks = ();
        do {
            if ( $str =~ s/^(["'])(.*?)\1// ) {
                push( @picks, $2 );
            }
            elsif ( $str =~ s/^([-A-Za-z0-9:.*]+)// || $str =~ /(\s)*,/ ) {
                my $v = $1;
                $v = '' unless defined $v;
                if ( $v =~ /\*/ && $this->{typename} eq 'SELECTCLASS' ) {

                    # Populate the class list
                    push( @picks,
                        Foswiki::Configure::FileUtil::findPackages($v) );
                }
                else {
                    push( @picks, $v );
                }
            }
            else {
                die "Illegal .spec at '$str'";
            }
        } while ( $str =~ s/\s*,\s*// );
        $this->{select_from} = [@picks];
    }
    elsif ( $str =~ s/^\s*(\d+(?:x\d+)?)// ) {

        # Width specifier for e.g. STRING
        $this->{SIZE} = $1;
    }
    return $str;
}

# A feedback is a set of key=value pairs
sub _FEEDBACK {
    my ( $this, $str ) = @_;

    $str =~ s/^\s*(["'])(.*)\1\s*$/$2/;

    my %fb;
    while ( $str =~ s/^\s*([a-z]+)\s*=\s*// ) {

        my $attr = $1;

        if ( $str =~ s/^(\d+)// ) {

            # name=number
            $fb{$attr} = $1;
        }
        elsif ( $str =~ s/(["'])(.*?[^\\])\1// ) {

            # name=string
            $fb{$attr} = $2;
        }
        last unless $str =~ s/^\s*;//;
    }

    die "FEEDBACK parse failed at $str" unless $str =~ /^\s*$/;

    push @{ $this->{FEEDBACK} }, \%fb;
}

# Spec file options are:
# CHECK="option option:value option:value,value option:'value'", where
#    * each option has a value (the default when just the keyword is
#      present is 1)
#    * options are separated by whitespace
#    * values are introduced by : and delimited by , (Unless quoted,
#      in which case there is just one value.  N.B. If quoted, double \.)
#    * Generated an arrayref containing all values for
#      each option
#
# Multiple CHECK clauses allow default checkers to do several checks
# for an item.
# For example, DataDir wants one set of options for .txt files, and
# another for ,v files.

sub _CHECK {
    my ( $this, $str ) = @_;

    my $ostr = $str;
    $str =~ s/^(["'])\s*(.*?)\s*\1$/$2/;

    my %options;
    while ( $str =~ s/^\s*([a-zA-Z][a-zA-Z0-9]*)// ) {
        my $name = $1;
        my @opts;
        if ( $str =~ s/^\s*:\s*// ) {
            do {
                if ( $str =~ s/^(["'])(.*?)[^\\]\1// ) {
                    push( @opts, $2 );
                }
                elsif ( $str =~ s/^([-+]?\d+)// ) {
                    push( @opts, $1 );
                }
                elsif ( $str =~ s/^([a-z_{}]+)//i ) {
                    push( @opts, $1 );
                }
                else {
                    die "CHECK parse failed: not a list at $str in $ostr";
                }
            } while ( $str =~ s/^\s*,\s*// );
        }
        else {
            push( @opts, 1 );
        }
        $options{$name} = \@opts;
    }
    die "CHECK parse failed, expected name at $str in $ostr"
      if $str !~ /^\s*$/;
    push( @{ $this->{CHECK} }, \%options );
}

# A value is a leaf, so this is a NOP.
sub getSectionObject {
    return;
}

=begin TML

---++ ObjectMethod getValueObject($keys)
This is a leaf object, so there's no recursive search to be done; we just
return $this if the keys match.

=cut

sub getValueObject {
    my ( $this, $keys ) = @_;

    return ( $this->{keys} && $keys eq $this->{keys} ) ? $this : undef;
}

sub getAllValueKeys {
    my $this = shift;
    return ( $this->{keys} );
}

=begin TML

---++ ObjectMethod getRawValue() -> $rawval

Get the current value of the key from $Foswiki::cfg.
The value returned is not expanded (embedded $Foswiki::cfg references
will be intact)

=cut

sub getRawValue {
    my ($this) = @_;

    my $val = eval "\$Foswiki::cfg$this->{keys}";
    ASSERT( !$@, $@ ) if DEBUG;
    return $val;
}

=begin TML

---++ ObjectMethod getExpandedValue() -> $expandedval

Get the current value of the key from $Foswiki::cfg.
The value returned with embedded $Foswiki::cfg references
recursively expanded. If the current value is undef, then undef
is returned. Embedded references that evaluate to undef
are expanded using the string 'undef'.

=cut

sub getExpandedValue {
    my ( $this, $name ) = @_;

    my $val = $this->getRawValue();
    return undef unless defined $val;
    Foswiki::Configure::Load::expandValue($val);
    return $val;
}

=begin TML

---++ ObjectMethod encodeValue($raw_value) -> $encoded_value

Encode a "real" cfg value as a string (if necessary) for passing
to other tools, such as UIs, in a type-sensitive way.

=cut

sub encodeValue {
    my ( $this, $value ) = @_;

    return undef unless defined $value;

    if ( ref($value) || $this->{typename} eq 'BOOLEAN' ) {
        return Foswiki::Configure::Reporter::uneval($value);
    }
    return $value;
}

=begin TML

---++ ObjectMethod decodeValue($encoded_value) -> $raw_value

Decode a string that represents the value (e.g a serialised perl structure)
and return the 'true' value by applying type rules

=cut

sub decodeValue {
    my ( $this, $value ) = @_;

    # Empty string always interpreted as undef
    return undef unless defined $value;

    if ( $this->{typename} eq 'REGEX' ) {
        return qr/$value/;
    }
    elsif ( $this->{typename} eq 'PERL' ) {
        my $value = eval $value;
        die $@ if $@;
        return $value;
    }
    elsif ( $this->{typename} eq 'BOOLEAN' ) {
        return $value ? 1 : 0;
    }

    # String or number, just sling it back
    return $value;
}

# Implements Foswiki::Configure::item
sub search {
    my ( $this, $re ) = @_;
    if ( $this->{keys} =~ /$re/ ) {
        return ($this);
    }
    return ();
}

# Implements Foswiki::Configure::item
sub getPath {
    my $this = shift;
    my @path;
    @path = $this->{_parent}->getPath() if ( $this->{_parent} );
    push( @path, $this->{keys} );
    return @path;
}

# Implements Foswiki::Configure::Item
sub find_also_dependencies {
    my ( $this, $root ) = @_;
    ASSERT($root) if DEBUG;

    return unless $this->{CHECK_ON_CHANGE};
    foreach my $slave ( split( /[\s,]+/, $this->{CHECK_ON_CHANGE} ) ) {
        my $vob = $root->getValueObject($slave);
        next unless ($vob);
        my $check = $vob->{CHECK}->[0];
        if ($check) {
            $check->{also} ||= [];
            push( @{ $check->{also} }, $slave );
        }
        else {
            $vob->{CHECK}->[0] = { also => [$slave] };
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2014 Foswiki Contributors. Foswiki Contributors
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
