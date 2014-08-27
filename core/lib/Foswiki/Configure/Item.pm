# See bottom of file for license and copyright information

=begin TML

---++ package Foswiki::Configure::Item

Abstract base class of all nodes in a configuration spec tree.
Item is the base class for all of Section (collection) Value (an
individual value).

Objects of this class are intended to form a tree with references in
both directions, circular references ahead.

IMPORTANT: there are some naming conventions for fields that apply to
all subclasses of this class:
   * All internal attributes of this class are named [a-z][a-z_]*
     i.e. lowercase alphabetic
   * All internal attributes *that must not be serialised* (such as
     tree pointers) are named _[a-z][a-z_]* i.e. with a
     leading underscore.
   * All attributes read dynamically from the .spec must be [A-Z][A-Z_]+

=cut

package Foswiki::Configure::Item;

use strict;
use warnings;

use Foswiki::Configure::LoadSpec ();

# Schema for dynamic attributes
use constant ATTRSPEC => {};

sub new {
    my ( $class, @opts ) = @_;

    my $this = bless(
        {
            _parent => undef,
            _depth  => 0,

            # Serialisable attribtes
            desc         => '',
            errorcount   => 0,
            warningcount => 0,
            defined_at   => undef    # where it is defined [ "file", line ]
        },
        $class
    );

    $this->set(@opts);

    return $this;
}

sub DESTROY {
    my $this = shift;

    # Clear dynamic attributes
    foreach my $field ( keys %{ $this->{ATTRSPEC} } ) {
        undef $this->{$field};
    }

    # Undef unserialisable internals
    map { undef $this->{$_} } grep { /^__/ } keys %$this;
}

=begin TML

---++ ObjectMethod getDepth() -> $integer

Get the depth of the item in the item tree, where the root is at depth 0,
it's children at depth 1, etc.

=cut

sub getDepth {
    my $this = shift;
    return $this->{_depth};
}

=begin TML

---++ ObjectMethod set(@what) / set(%what)
   * =@what= array of key-value pairs for attributes to set e.g.
     set(typename=> 'BLAH'). The array may be interpreted as a hash,
    so must be even-sized.
Add options. The default implementation supports setting keys directly,
and also supports a special 'opts' key, which defines a string that is
parsed according to the .spec standard for options.
Subclasses define ATTRSPEC to declare attribute types valid for the
entity, used while parsing this string.

Note that all internal fields of this class use a leading underscore
naming convention, while all dynamically-read attributes are all
upper case with no leading underscore.

Note that the global $RAW_VALS=1 will
supress calling of the parsers responsible to expanding attribute
values.

When the same option is set twice in the parameters, the *second*
value will take precedence. This allows the caller to declare defaults
early in the list before appending options from other sources.

=cut

sub set {
    my ( $this, @params ) = @_;

    while ( my $k = shift(@params) ) {
        die "Uneven sized options hash " . join( ' ', caller )
          unless scalar @params;
        my $v = shift @params;
        if ( $k eq 'opts' ) {
            $this->_parseOptions($v);
        }
        else {
            $this->{$k} = $v;
        }
    }
}

# Implemented by subclasses to perform type-specific attribute parsing
sub parseTypeParams {
    my ( $this, $str ) = @_;
    return $str;
}

sub _parseOptions {
    my ( $this, $str, %controls ) = @_;

    # Parcel out defaults
    while ( my ( $attr, $spec ) = each %{ $this->ATTRSPEC } ) {
        next unless ref($spec);
        if ( !defined $this->{$attr} && defined $spec->{default} ) {
            if ( ref $spec->{default} eq 'ARRAY' ) {
                @{ $this->{$attr} } = @{ $spec->{default} };
            }
            elsif ( ref $spec->{default} eq 'HASH' ) {
                %{ $this->{$attr} } = %{ $spec->{default} };
            }
            else {
                $this->{$attr} = $spec->{default};
            }
        }
    }

    # A couple of special cases, specific to Values
    $str = $this->parseTypeParams($str);

    # Parse the options
    while ( $str =~ s/^\s*([A-Za-z0-9_]+)// ) {

        my $key    = $1;
        my $spec   = $this->ATTRSPEC;
        my $remove = 0;
        if ( $key =~ s/^NO// ) {
            $remove = 1;
        }
        if ( $spec && defined $spec->{$key} && !ref( $spec->{$key} ) ) {

            # Rename single-character keys
            $key = $spec->{$key};
        }
        $spec = $spec->{$key};

        die "Bad option '$key' in .spec before $str" unless $spec;
        if ( $str =~ s/^\s*=// ) {
            my $val;
            if ( $str =~ s/^\s*((["']).*?[^\\]\2)// ) {

                # =string (must retain quotes)
                $val = $1;
            }
            elsif ( $str =~ s/^\s*([A-Z0-9]+)// ) {

                # =keyword or number
                $val = $1;
            }
            else {
                die "Parse error when reading .spec options at $key=$str";
            }
            if (   $spec
                && defined $spec->{parse_val}
                && !$Foswiki::Configure::LoadSpec::RAW_VALS )
            {
                my $fn = $spec->{parse_val};
                $this->$fn($val);
            }
            else {

                # Can shed quotes now
                $val =~ s/^(["'])(.*)\1$/$2/;
                if ( ref( $this->{$key} ) eq 'ARRAY' ) {
                    push( @{ $this->{$key} }, $val );
                }
                else {
                    $this->{$key} = $val;
                }
            }
        }
        elsif ($remove) {
            delete $this->{$key};
        }
        elsif ( $spec->{openclose} ) {
            $str =~ s/^(.*?)(\/$key|$)//;
            $this->{$key} = $1;
        }
        else {
            $this->{$key} = 1;
        }
    }
    die "Parse failed at $str" unless $str =~ /^\s*$/;
}

=begin TML

---++ ObjectMethod clear(%what)
Delete attributes set by =set=.

=cut

sub clear {
    my $this = shift;
    return unless (@_);

    delete @{$this}{@_};
}

=begin TML

---++ ObjectMethod append($key, $str)

Concatenate $str to the string value of $key.

=cut

sub append {
    my ( $this, $key, $str ) = @_;

    my @l = split( /\n/, $this->{$key} || '' );
    push( @l, $str );
    $this->{$key} = join( "\n", @l );
}

=begin TML

---++ ObjectMethod inc($key)

Increment a numeric value identified by $key, recursing up the tree to the
root.

Assumptions
   * All item levels have $key defined and initialized
   * Parents of items are items (or more precisely: can inc())

This is used for counting the numbers of warnings, errors etc found in
subtrees of the configuration structure.

=cut

sub inc {
    my ( $this, $key ) = @_;

    $this->{$key}++;
    $this->{_parent}->inc($key) if $this->{_parent};
}

=begin TML

---++ ObjectMethod hasDeep($attrname) -> $boolean

Determine if this item (or any sub-item if this is a collection)
has the given boolean attribute

=cut

sub hasDeep {
    my ( $this, $attrname ) = @_;
    return $this->{$attrname};
}

=begin TML

---++ ObjectMethod getAllValueKeys() -> @list

Return a list of all the keys for value objects under this node.

=cut

sub getAllValueKeys {
    my $this = shift;

    return ();
}

=begin TML

---++ ObjectMethod getSectionPath() -> @list

Get the path down to a configuration item. The path is a list of section
titles.

=cut

sub getSectionPath {
    my $this = shift;
    my @path = ();

    if ( $this->{parent} ) {
        @path = $this->{parent}->getSectionPath();
        push( @path, $this->{parent}->{headline} )
          if $this->{parent}->{headline};
    }
    return @path;
}

=begin TML

---++ ObjectMethod getSectionObject($head, $depth) -> $item

This gets the section object that has the heading $head and
getDepth() == $depth below this item.

Subclasses must provide an implementation.

=cut

sub getSectionObject {
    die 'Subclasses must define this method';
}

=begin TML

---++ find(%search) -> @result

Find the first item that matches the search keys given in %search.
For example, find(keys => '{Keys}') or find(headline => 'Section').
Searches recursively. You can use the pseudo-key =parent= to look up the
tree, and =depth= to match the depth (the spec root is at depth 0).

An empty search matches the first thing found.
If there are search terms, then the entire subtree is searched,
but the shallowest matching node is returned.
All search terms must be matched.

=cut

# True if the given configuration item matches the given search
sub _matches {
    my ( $this, %search ) = @_;
    my $match = 1;

    while ( my ( $k, $e ) = each %search ) {
        if ( $k eq 'parent' ) {
            unless ( $this->{_parent}
                && $this->{_parent}->_matches(%$e) )
            {
                $match = 0;
                last;
            }
        }
        elsif ( $k eq 'depth' ) {
            unless ( $this->getDepth() == $e ) {
                $match = 0;
                last;
            }
        }
        elsif ( !defined $this->{$k} || $this->{$k} ne $e ) {
            $match = 0;
            last;
        }
    }
    return $match;
}

sub find {
    my $this   = shift;
    my %search = @_;

    my $match = $this->_matches(%search);

    # Return without searching the subtree if this node matches
    if ($match) {
        return ($this);
    }

    return () unless $this->{children};

    # Search children
    my @result = ();
    foreach my $child ( @{ $this->{children} } ) {
        push( @result, $child->find(@_) );
    }

    return @result;
}

=begin TML

---++ ObjectMethod getValueObject($keys) -> $value
Get the first Foswiki::Configure::Value object (leaf configuration item)
associated with this Item. If this Item is a Value object, it will
just return 'this'. if it is a Section, it will search the section
(and it's subsections) for the value object with matching keys.

Subclasses must define this method.

=cut

sub getValueObject {
    die 'Subclasses must define this method';
}

=begin TML

---++ ObjectMethod visit($visitor) -> $boolean
Start a visit over this item.
   * $visitor - an object that implements Foswiki::Configure::Visitor

The default implementation just visits this item, and returns 1 if
both the startVisit and the endVisit returned true.

=cut

sub visit {
    my ( $this, $visitor ) = @_;
    return 0 unless $visitor->startVisit($this);
    return 0 unless $visitor->endVisit($this);
    return 1;
}

=begin TML

---++ ObjectMethod TO_JSON

Provided so the JSON module can serialise blessed objects. Creates
a copy of the object without internal pointers that is suitable for
serialisation. Subclasses that add fields that need to be serialised
*MUST* implement this method (by modifying the object returned by
SUPER::TO_JSON to remove internal fields).

=cut

sub TO_JSON {
    my $this   = shift;
    my $struct = {
        class => ref($this),

        # Don't serialise anything with a leading __
        map { $_ => $this->{$_} } grep { !/^_/ } keys %$this
    };
    return $struct;
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
