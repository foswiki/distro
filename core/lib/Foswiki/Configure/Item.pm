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
            depth   => 0,

            # Serialisable attribtes
            desc       => '',
            defined_at => undef    # where it is defined [ "file", line ]
        },
        $class
    );

    $this->set(@opts);

    return $this;
}

sub stringify {
    my $this = shift;
    my $s = Data::Dumper->Dump( [ $this->TO_JSON() ] );
    $s =~ s/^.*?= //;
    return $s;
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
          unless scalar(@params);
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
        my $val;
        if ( $str =~ s/^\s*=// ) {
            if ( $str =~ s/^\s*(["'])(.*?[^\\])\1// ) {

                # =string
                $val = $2;
            }
            elsif ( $str =~ s/^\s*([A-Z0-9]+)// ) {

                # =keyword or number
                $val = $1;
            }
            else {
                die "Parse error when reading .spec options at $key=$str";
            }
        }
        elsif ( $spec->{openclose} ) {
            $str =~ s/^(.*?)(\/$key|$)//;
            $val = $1;
        }
        else {
            $val = 1;
        }
        if ($remove) {
            delete $this->{$key};
            $val = undef;
        }

        if ( defined $spec->{handler}
            && !$Foswiki::Configure::LoadSpec::RAW_VALS )
        {
            my $fn = $spec->{handler};
            $this->$fn( $val, $key );    # Process with delegate
        }
        else {
            $this->{$key} = $val;
        }
    }
    die "Parse failed at $str" unless $str =~ m/^\s*$/;
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

    if ( $this->{$key} ) {
        $this->{$key} .= "\n$str";
    }
    else {
        $this->{$key} .= $str;
    }
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

---++ ObjectMethod find_also_dependencies([$root])

Find 'also' dependencies by scanning values.

'also' dependencies are checker dependencies that are inferred from the
values of DISPLAY_IF and ENABLE_IF attributes. Some 'also' dependencies
may 'also' be explicitly declared in the CHECK clause of an item.

'also' dependencies are used to trigger checks of other items when the
value of an item they depend on changes.

   * =$root= - root used to getValueObject for keys found

=cut

sub find_also_dependencies {
    my ( $this, $root ) = @_;
    die 'Subclasses must define this method';
}

=begin TML

---++ ObjectMethod getPath() -> @list

Get the path down to a configuration item. The path is a list of
titles (headlines and keys).

=cut

sub getPath {
    my $this = shift;
    my @path = ();

    if ( $this->{_parent} ) {
        @path = $this->{_parent}->getPath();
        push( @path, $this->{_parent}->{headline} )
          if $this->{_parent}->{headline};
    }
    return @path;
}

=begin TML

---++ ObjectMethod unparent()

Unparent a configuration item. This only clears the parent of the node,
it does not remove the node from the parent. After removing parents
only the top-down structure remains, and methods that use the parent,
such as getPath, will not work any more, so use with great caution.

The main purpose of this method is to prepare a spec node for isolated
use (e.g. serialisation).

=cut

sub unparent {
    my $this = shift;
    delete $this->{_parent};
    delete $this->{_vobCache};
}

=begin TML

---++ ObjectMethod prune($depth)

Prunes the subtree under $this to a maximum depth of $depth, discarding
children under that point.

$depth = 0 will prune immediate children
$depth = 1 will prune children-of-children

etc.

=cut

sub prune {
    my ( $this, $depth ) = @_;

    # NOP
}

=begin TML

---++ ObjectMethod getSectionObject($head, $depth) -> $item

This gets the section object that has the heading $head and
$this->{depth} == $depth below this item. If $depth is not given,
will return the first headline that matches.

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

    while ( my ( $k, $e ) = each %search ) {
        if ( ref($e) ) {
            return 0
              unless ( ref( $this->{"_$k"} )
                && $this->{"_$k"}->isa('Foswiki::Configure::Item')
                && $this->{"_$k"}->_matches(%$e) );
        }
        elsif ( !defined $e ) {
            return 0 if defined $this->{$k};
        }
        elsif ( !defined $this->{$k} || $this->{$k} ne $e ) {
            return 0;
        }
    }
    return 1;
}

=begin TML

---++ ObjectMethod find(\%match) -> @nodes

Get a list of nodes that match the given search template. The template
is a node structure with a subset of fields filled in that must be
matched in a node for it to be returned.

Any fields can be used in searches and will match using eq, for example:
   * =headline= - title of a section,
   * =typename= - type of a leaf spec entry,
   * =keys= - keys of a spec entry,
   * =desc= - descriptive text of a section or entry.
   * =depth= - matches the depth of a node under the root
     (which is depth 0)
Fields starting with _ are assumed to refer to another Foswiki::Configure::Item
   * =parent= - a structure that will be used to match a parent (the value
     should be another match hash that will match the parent),

=cut

sub find {
    my $this   = shift;
    my %search = @_;

    my $match = $this->_matches(%search);

    if ($match) {
        return ($this);
    }
    return ();
}

=begin TML

---++ ObjectMethod search($re) -> @nodes

Get a list of nodes that match the given RE. Sections match on the headline,
Values on the keys.

=cut

sub search {
    my ( $this, $re ) = @_;
    return ();
}

=begin TML

---++ ObjectMethod promoteSetting($setting) -> $boolean
If all children of this node are tagged with the boolean attribute,
then tag me too. Return true if the attribute is on us, false
otherwise.

=cut

# Default impl assumes a leaf node
sub promoteSetting {
    my ( $this, $setting ) = @_;
    return $this->{$setting};
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
