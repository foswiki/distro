# See bottom of file for license and copyright information

=begin TML

---+ UNPUBLISHED package Foswiki::Prefs::Stack

Foswiki preferences mechanism are like stacks:
   * Preferences pushed later have precendence over ones pushed earlier I must
   * be able to return (restore) to a state I was earlier

This stack can exist as an index, so preference data is not copied everywhere.

This class deals with this index and must be used only by Foswiki::Prefs.

=cut

package Foswiki::Prefs::Stack;
use strict;

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
    foreach my $back ( @{ $this->{'levels'} } ) {
        $back->finish();
    }
    undef $this->{'levels'};
    undef $this->{'map'};
}

=begin TML

---++ ObjectMethod size() -> $size

Returns the size of the stack in number of levels.

=cut

sub size {
    return scalar @{ $_[0]->{levels} };
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
    return undef unless defined $map;
    if ( defined $level ) {
        my $mask =
          ( chr(0xFF) x int( $level / 8 ) )
          . chr( ( 2**( ( $level % 8 ) + 1 ) ) - 1 );
        $map &= $mask;
        substr( $map, -1 ) = ''
          while length($map) > 0 && ord( substr( $map, -1 ) ) == 0;
        return undef unless length($map) > 0;
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
    foreach ( keys %{ $this->{'map'} } ) {
        $this->{'map'}{$_} &= $mask;
        substr( $this->{'map'}{$_}, -1 ) = ''
          while length( $this->{'map'}{$_} ) > 0
              && ord( substr( $this->{'map'}{$_}, -1 ) ) == 0;
        delete $this->{'map'}{$_} if length( $this->{'map'}{$_} ) == 0;
    }
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
