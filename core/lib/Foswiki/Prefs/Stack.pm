# See bottom of file for license and copyright information

=begin TML

---+ UNPUBLISHED package Foswiki::Prefs::Stack

Foswiki preferences mechanism are like stacks:
   * Preferences pushed later have precedence over ones pushed earlier I must
   * be able to return (restore) to a state I was earlier

This stack can exist as an index, so preference data is not copied everywhere.

The index is composed by three elements:
   * A bitstring map. Each preference has a bitmap. Each bit corresponds to a
     level. The bit is 1 if the preference is defined at that level and 0
     otherwise. If a preference is "defined" in some level, but it was
     finalized, then the corresponding bit is 0.  
   * A level list storing a backend object that is associated with each level 
   * A final hash that maps preferences to the level they were finalized.

This class deals with this stuff and must be used only by =Foswiki::Prefs=

=cut

package Foswiki::Prefs::Stack;
use strict;
use warnings;
use bytes;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new( $session )

Creates a new Stack object. 

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this  = {
        'final'  => {},    # Map preferences to the level the were finalized.
        'levels' => [],    # Maps leves to the corresponding backend objects.
        'map'    => {},    # Associate each preference with its bitstring map.
    };
    return bless $this, $class;
}

=begin TML

---++ ObjectMethod finish()

Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{'final'};
    if ( $this->{'levels'} ) {
        foreach my $back ( @{ $this->{'levels'} } ) {
            $back->finish();
        }
    }
    undef $this->{'levels'};
    undef $this->{'map'};
}

=begin TML

---++ ObjectMethod size() -> $size

Returns the size of the stack in number of levels.

=cut

sub size {
    return scalar( @{ $_[0]->{levels} } );
}

=begin TML

---++ ObjectMethod backAtLevel($level) -> $back

Returns the backend object corresponding to $level. If $level is negative,
consider that number from the top of the stack. -1 means the top element.

=cut

sub backAtLevel {
    return $_[0]->{levels}->[ $_[1] ];
}

=begin TML

---++ ObjectMethod finalizedBefore($pref, $level) -> $boolean

Returns true if $pref was finalized somewhere earlier than $level. If $pref is
finalized *in* $level or it's not finalized, returns true.

=cut

sub finalizedBefore {
    my ( $this, $key, $level ) = @_;
    $level += @{ $this->{levels} } if $level < 0;
    return exists $this->{final}{$key} && $this->{final}{$key} < $level;
}

=begin TML

---++ ObjectMethod finalized($pref) -> $boolean

Returns true if $pref in finalized.

=cut

sub finalized {
    my ( $this, $key ) = @_;
    return exists $this->{final}{$key};
}

=begin TML

---++ ObjectMethod prefs() -> @prefs

Returns a list with the name of all defined prefs in the stack.

=cut

sub prefs {
    return keys %{ $_[0]->{'map'} };
}

=begin TML

---++ ObjectMethod prefIsDefined($pref) -> $boolean

Returns true if $pref is defined somewhere in the stack.

=cut

sub prefIsDefined {
    return exists $_[0]->{'map'}{ $_[1] };
}

=begin TML

---++ ObjectMethod insert($type, $pref, $value) -> $num

Define preference named $pref of type $type as $value. $type can be 'Local' or
'Set'. 

Returns the number of inserted preferences (0 or 1).

=cut

sub insert {
    my $this = shift;

    my $back = $this->{levels}->[-1];
    my $num  = $back->insert(@_);

    my $key = $_[1];
    $this->{'map'}{$key} = '' unless exists $this->{'map'}{$key};

    my $level = $#{ $this->{levels} };
    vec( $this->{'map'}{$key}, $level, 1 ) = 1;

    return $num;
}

=begin TML

---++ ObjectMethod newLevel($back, $prefix)

Pushes all preferences in $back on the stack, except for the finalized ones.
Optionally $prefix preferences name in the index. This feature is used by
plugins: A preference PREF defined in MyPlugin topic should be referenced by
MYPLUGIN_PREF. In this example $prefix is MYPLUGIN_.

=cut

sub newLevel {
    my ( $this, $back, $prefix ) = @_;

    push @{ $this->{levels} }, $back;
    my $level = $#{ $this->{levels} };
    $prefix ||= '';
    foreach ( map { $prefix . $_ } $back->prefs ) {
        next if exists $this->{final}{$_};
        $this->{'map'}{$_} = '' unless exists $this->{'map'}{$_};
        vec( $this->{'map'}{$_}, $level, 1 ) = 1;
    }

    my @finalPrefs = split /[,\s]+/, ( $back->get('FINALPREFERENCES') || '' );
    foreach (@finalPrefs) {
        $this->{final}{$_} = $level
          unless exists $this->{final}{$_};
    }

    return $back;
}

=begin TML

---++ ObjectMethod getDefinitionLevel($pref) -> $level

Returns the $level in which $pref was defined or undef if it's not defined.

=cut

sub getDefinitionLevel {
    my ( $this, $pref ) = @_;
    return
      exists $this->{'map'}{$pref} ? _getLevel( $this->{'map'}{$pref} ) : undef;
}

# Used to get the level of the highest 1, given a bitstring map.
sub _getLevel {
    my $map = shift;
    return
      int( log( ord( substr( $map, -1 ) ) ) / log(2) ) +
      ( ( length($map) - 1 ) * 8 );
}

=begin TML

---++ ObjectMethod getPreference($pref [, $level] ) -> $value

Returns the $value of $pref, considering the stack rules (values in higher
levels overrides those in lower levels).

Optionally consider preferences at most $level. This is usefull to get a
preference of Web if the stack has Web/Subweb. This makes it possible to use
the same stack for Web and Web/Subweb.

=cut

sub getPreference {
    my ( $this, $key, $level ) = @_;
    my $map = $this->{'map'}{$key};
    return unless defined $map;
    if ( defined $level ) {
        my $mask =
          ( chr(0xFF) x int( $level / 8 ) )
          . chr( ( 2**( ( $level % 8 ) + 1 ) ) - 1 );
        $map &= $mask;
        substr( $map, -1 ) = ''
          while length($map) > 0 && ord( substr( $map, -1 ) ) == 0;
        return unless length($map) > 0;
    }
    return $this->{levels}->[ _getLevel($map) ]->get($key);
}

=begin TML

---++ ObjectMethod clone($level ) -> $stack

This constructs a new $stack object as a clone of this one, up to the given
$level. If no $level is given, the resulting object is an extac copy.

=cut

sub clone {
    my ( $this, $level ) = @_;

    my $clone = $this->new();
    $clone->{'map'}    = { %{ $this->{'map'} } };
    $clone->{'levels'} = [ @{ $this->{levels} } ];
    $clone->{'final'}  = { %{ $this->{final} } };
    $clone->restore($level) if defined $level;

    return $clone;
}

=begin TML

---++ ObjectMethod restore($level)

Restores tha stack to the state it was in the given $level.

=cut

sub restore {
    my ( $this, $level ) = @_;

    my @keys = grep { $this->{final}{$_} > $level } keys %{ $this->{final} };
    delete @{ $this->{final} }{@keys};
    splice @{ $this->{levels} }, $level + 1;

    my $mask =
      ( chr(0xFF) x int( $level / 8 ) )
      . chr( ( 2**( ( $level % 8 ) + 1 ) ) - 1 );
    foreach my $p ( keys %{ $this->{'map'} } ) {
        $this->{'map'}{$p} &= $mask;

        while ( length( $this->{'map'}{$p} ) > 0
            && ord( substr( $this->{'map'}{$p}, -1 ) ) == 0 )
        {
            substr( $this->{'map'}{$p}, -1 ) = '';
        }

        delete $this->{'map'}{$p} if length( $this->{'map'}{$p} ) == 0;
    }
}

1;
__END__

=begin TML

#MathStuff
---+ Mathematical Considerations

<div align="right"> 
_by [[Foswiki:Main/GilmarSantosJr][Gilmar Santos Jr]], May 2009_
</div>

The bitmap is built in an way to meet two properties:
   * It has the minimal possible length.                       (I)
   * If it exists in the hash, it has at least length 1.       (II)

Preference levels 0-7 are in the first byte. 8-15 in the second and so on. If a
preference is defined in levels 2 and 7, for example, its bitmap will have
length 1, even if the stack is in 30th level. 
This is what _minimal possible length_ means.

These two properties implies that the last byte of a bit string is non-zero.

---++ Getting/Setting preferences with at most 8 levels

Let's consider the first scenario: at most 8 preference values. This means that
bitmaps have one character. The built-in perl function =ord= converts a
character to an integer between 0 and 255. If the character of a preference is
0, then the preference doesn't exist in the map hash, cause of the second
listed property above. 

This implies that I can *always* take the logarithm of =ord($map)=. (III)

The question is: 
__given a bitstring, what is the highest level containing a 1?__

To answer this question let's consider the following mathematical expressions:
(=log2(X)= means _the logarithm of X in base 2_)

<verbatim>
log2(1) = 0; 1 == 1 * 2 ** 0; 1 in base 2 is "00000001" (considering one byte)
log2(2) = 1; 2 == 1 * 2 ** 1; 2 in base 2 is "00000010" (considering one byte)
log2(4) = 2; 4 == 1 * 2 ** 2; 4 in base 2 is "00000100" (considering one byte)
log2(8) = 3; 8 == 1 * 2 ** 3; 8 in base 2 is "00001000" (considering one byte)
</verbatim>

Also notice that:

<verbatim>
2 ** B <= X < 2 ** (B + 1) implies B <= log2(X) < (B + 1) 
</verbatim>

This implies:

<verbatim>
int(log2(X)) == B, for any X in the above rage.
</verbatim>

 Some examples:

<verbatim>
int(log2(3)) = log2(2) = 1; 3 in base 2 is "00000011" (considering one byte)
int(log2(5)) = log2(4) = 2; 5 in base 2 is "00000101" (considering one byte)
int(log2(6)) = log2(4) = 2; 6 in base 2 is "00000110" (considering one byte)
int(log2(7)) = log2(4) = 2; 7 in base 2 is "00000111" (considering one byte)
int(log2(9)) = log2(8) = 3; 9 in base 2 is "00001001" (considering one byte)
</verbatim>

The position of least significant bit is 0 and the position of the most
significant bit is 8, then: =int(log2(X))= is the position of the
highest-significant bit equal to 1.  This always holds. The complete
mathematical proof is left as an exercise.

Back to the question __what is the highest level containing a 1?__

It's clear the answer is: =int(log2(X))=. 

=X= is the number corresponding to the bitstring character, so X = =ord($map)=.

Also, 
<verbatim>
log2(Y) == ln(Y)/ln(2), for any Y real positive
</verbatim>

Then we have: 
<verbatim>
int(log2(X)) == int( ln( ord($map) ) / ln(2) )
</verbatim>

*Conclusion*: considering (III) and at most 8 levels I can figure out in
which level a preference is defined with the following _O(1)_ operation: 

<verbatim>
$defLevel = int( ln( ord($map) ) / ln(2) );
</verbatim>

---++ Getting/Setting preferences with arbitrary number of levels

But preferences may have far more levels than 8. Now let's consider this
general case. We'll reduce it to the _at most 8 levels_ case.

At this point I must consider how perl built-in function =vec= works:
<verbatim>
$a = '';
vec($a,  0, 1) = 1; print unpack("b*", $a);  # "10000000"
vec($a,  2, 1) = 1; print unpack("b*", $a);  # "10100000"
vec($a,  7, 1) = 1; print unpack("b*", $a);  # "10100001"
vec($a, 16, 1) = 1; print unpack("b*", $a);  # "1010000100000000100000000"
</verbatim>

The least significant bit is the bit 0 of the first byte. The most significant
bit is the bit 7 of the last byte. =unpack= with ="b*"= gives us this
representation, that is different from the one we're used to, but it's only a
representation. Test for yourself:

<verbatim>
$a = '';
vec($a, 0, 1) = 1; print ord($a); #   1
vec($a, 2, 1) = 1; print ord($a); #   5
vec($a, 7, 1) = 1; print ord($a); # 133
</verbatim>

Since =ord()= operates with one character (or with the first one, if
=length($a) > 1=), we have to figure out a way to deal with preferences bigger
than 8 levels. 

The level to consider in order to get a preference value is the highest in
which it was defined. Because of properties (I) and (II) above, this level is
in the last byte of the bitmap. This implies that no matter the value of the
other bytes are, I need to consider only the last byte. (IV)

Since (IV) holds, we can reduce the general case to the restricted case as
follows: we calculate the level considering the last byte. We'll get =$L= in
=[0,7]=.  Then we transform this value to the correct, considering that the bit
0 of the last byte is the bit =(N - 1) * 8= of the general string, where =N= is
the total number of bytes. Examples:

<verbatim>
1  byte: bit 0 of the last byte is bit (1 - 1) * 8 == 0  of the string
2 bytes: bit 0 of the last byte is bit (2 - 1) * 8 == 8  of the string
3 bytes: bit 0 of the last byte is bit (3 - 1) * 8 == 16 of the string
</verbatim>

and so on.

So, considering the general case where =$map= has arbitrary length, the
*general answer* to __what is the highest level containing a 1?__ is:

<verbatim>
$defLevel = int( log( ord( substr($map, -1) ) ) / ln(2) ) + 
            (length($map) - 1) * 8;
</verbatim>

=substr($map, -1)= is _the last byte of =$map=_ and because of (I) it's
non-zero, so =log( ord( substr($map,-1) ) )= exists.  Because of (II),
=length($map)= is at least 1. So this general expression is *always* valid.

---++ Growth/Shrink operations with at most 8 levels

There are growth and shrink operations on the stack and hence in the bitmaps.
These operations *must* keep (I) and (II). Let's consider the initial case:
=$stack->{map}= is an empty hashref, so both (I) and (II) holds.

The addition of a preference uses =vec()=, that expands the string as (and only
as) needed, so (I) holds. And if the preference is being added, then it must
exist in preferences map, so (II) also holds.

The restore operation is more complex: if we're restoring to level L, this
means that all bits above level L must be 0. I can accomplish this using
bitwise AND (&):

Considering at most 8 bytes, let's assume we want to restore to the level 5.
Notice that:

<verbatim>
2 ** (5 + 1) == 64 == "01000000"
64 - 1 == 63 == "00111111"
</verbatim>

Bits 0-5 are 1 and all others are 0. 

And Since:

<verbatim>
(1 & X) == X
(0 & X) == 0
</verbatim>

we can build a mask using this process and apply it to the map and we'll get
the bitmap restored to the desired level. So, in order to restore to level =$L=
we build a mask as =((2 ** (L+1)) - 1)= and perform: 

<verbatim>
$map &= $mask;
</verbatim>

If the result is 0, we need to remove that preference from the hash, so both
(I) and (II) holds.

---++ Growth/Shrink operations with arbitrary number of levels

Now considering the general case: if we want to restore to level =$L=, we need
to build a mask whose bits 0-L are 1. This mask will have =int($L/8) + 1=
bytes.

<verbatim>
0  <= $L <  8 implies the mask 1-byte  long.
8  <= $L < 16 implies the mask 2-bytes long.
16 <= $L < 24 implies the mask 3-bytes long. 
</verbatim>

and so on. We conclude that all bytes of the mask, except the last, will be
=\xFF= (all bits 1). If we map =$L= to [0,7], then we have the restricted case
above.

The number of bytes except the last in the bitstring is =int($L/8)=. The bit
position of =$L= in the last byte is =($L % 8)=:

<verbatim>
Level  8 corresponds to bit 0 of the second byte. int(8/8)  = 1.  8 % 8 = 0.
Level  9 corresponds to bit 1 of the second byte. int(9/8)  = 1.  9 % 8 = 1.
Level 15 corresponds to bit 7 of the second byte. int(15/8) = 1. 15 % 8 = 7.
Level 16 corresponds to bit 0 of the third byte.  int(16/8) = 2. 16 % 8 = 0.
</verbatim>

So the general way to build the mask is:

<verbatim>
$mask = ("\xFF" x int($L/8)); # All bytes except the last have all bits 1.
$mask .= chr( ( 2**( ( $L % 8 ) + 1 ) ) - 1 ); # The last byte is built based
                                               # on the restricted case above.
</verbatim>

The =$mask= has the minimal possible length, cause the way it's built. 
=$map & $mask= has at most =length($mask)= bytes, cause the way =&= works. But
we still must guarantee (I) and (II), so we need to purge the possible
zero-bytes in the end of the bitstring:

<verbatim>
while (ord(substr($map, -1)) == 0 && length($map) > 0 ) {
    substr($map, -1) = '';
}
</verbatim>

We need to test if =length($map)= is greater than 0, otherwise we may enter on
an infinite loop, if all bytes of the result are 0.

This =while= guarantee (I) above. Then we check if the resulting =$map= has
length 0. If so we remove the pref from the hash, so (II) is also achieved.

---+ Other Considerations

This implementation is more complex than the "natural" way, but using this:
   * We avoid to have more than one copy of preference values
   * This architecture (index separated from the values) make it easy to change
     the way values are stored. 

Also, consider it's slow to copy large chunks of data around. All copied values
in this architecture are far smaller than the preferences values (a typical big
bitstring has less than 4 bytes, while a preference value is bigger than this).

=pack= and =unpack= are not used cause they are not needed and cause the way to
know the level where a preference is defined is an =O(1)= operation that
*depends* on the packed string.

=cut
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
