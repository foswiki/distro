# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Prefs::PrefsCache

The PrefsCache package holds a cache of topics that have been read in, using
the TopicPrefs class.  These functions manage that cache.

We maintain 2 hashes of values:
   * {locals} Contains all locals at this level. Locals are values that
     only apply when the current topic is the topic where the local is
     defined. The variable names are decorated with the locality where
     they apply.
   * {values} contains all sets, locals, and all values inherited from
     the parent level

As each cache level is built, the values are copied down from the parent
cache level. This sounds monstrously inefficient, but in fact perl does
this a lot better than doing a multi-level lookup when a value is referenced.
This is especially important when many prefs lookups may be done in a
session, for example when searching.

=cut

package Foswiki::Prefs::PrefsCache;

use strict;
use Assert;

require Foswiki;
require Foswiki::Prefs::Parser;

#SMELL: I don't know why this is a global - and where it should be undef'd..
use vars qw( $parser );

=begin TML

---++ ClassMethod new( $prefs, $parent, $type, $web, $topic, $prefix )

Creates a new Prefs object.
   * =$prefs= - controlling Foswiki::Prefs object
   * =$parent= - the PrefsCache object to use to initialise values from
   * =$type= - Type of prefs object to create, see notes.
   * =$web= - web containing topic to load from (required is =$topic= is set)
   * =$topic= - topic to load from
   * =$prefix= - key prefix for all preferences (used for plugins)
If the specified topic is not found, returns an empty object.

=cut

sub new {
    my ( $class, $prefs, $parent, $type, $web, $topic, $prefix ) = @_;

    ASSERT( $prefs->isa('Foswiki::Prefs') ) if DEBUG;
    ASSERT($type) if DEBUG;

    my $this = bless( {}, $class );
    $this->{MANAGER} = $prefs;
    $this->{TYPE}    = $type;
    $this->{SOURCE}  = '';
    $this->{CONTEXT} = $prefs;

    if ( $parent && $parent->{values} ) {
        %{ $this->{values} } = %{ $parent->{values} };
    }
    if ( $parent && $parent->{locals} ) {
        %{ $this->{locals} } = %{ $parent->{locals} };
    }

    if ( $web && $topic ) {
        $this->loadPrefsFromTopic( $web, $topic, $prefix );
    }

    return $this;
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
    undef $this->{MANAGER};
    undef $this->{TYPE};
    undef $this->{SOURCE};
    undef $this->{CONTEXT};
    undef $this->{values};
    undef $this->{locals};
    undef $this->{final};
    undef $this->{SetHere};
}

=begin TML

---++ ObjectMethod finalise( $parent )

Finalise preferences in this cache, by freezing any preferences
listed in FINALPREFERENCES at their current value.
   * $parent = object that supports getPreferenceValue

=cut

sub finalise {
    my $this = shift;

    my $value = $this->{values}{FINALPREFERENCES};
    if ($value) {
        foreach ( split( /[\s,]+/, $value ) ) {

            # Note: cannot refinalise an already final value
            unless ( $this->{CONTEXT}->isFinalised($_) ) {
                $this->{final}{$_} = 1;
            }
        }
    }
}

=begin TML

---++ ObjectMethod loadPrefsFromTopic( $web, $topic, $keyPrefix )

Loads preferences from a topic. All settings loaded are prefixed
with the key prefix (default '').

=cut

sub loadPrefsFromTopic {
    my ( $this, $web, $topic, $keyPrefix ) = @_;

    $keyPrefix ||= '';

    $this->{SOURCE} = $web . '.' . $topic;

    my $session = $this->{MANAGER}->{session};
    if ( $session->{store}->topicExists( $web, $topic ) ) {
        my ( $meta, $text ) =
          $session->{store}->readTopic( undef, $web, $topic, undef );

        $parser ||= new Foswiki::Prefs::Parser();
        $parser->parseText( $text, $this, $keyPrefix );
        $parser->parseMeta( $meta, $this, $keyPrefix );
    }
}

=begin TML

---++ ObjectMethod loadPrefsFromText( $text, $meta, $web, $topic )

Loads preferences from text and optional metadata. All settings loaded
are prefixed with the key prefix (default ''). If =$meta= is defined,
then metadata will be taken from that object. Otherwise, =$text= will
be parsed to extract meta-data.

=cut

# Note: this is required because Foswiki stores access control
# information in topic text. Useful because you get a complete
# audit trail of access control settings for free.

sub loadPrefsFromText {
    my ( $this, $text, $meta, $web, $topic ) = @_;

    $this->{SOURCE} = $web . '.' . $topic;

    my $session = $this->{MANAGER}->{session};
    unless ($meta) {
        require Foswiki::Meta;
        $meta = new Foswiki::Meta( $session, $web, $topic, $text );
    }

    $parser ||= new Foswiki::Prefs::Parser();
    $parser->parseText( $meta->text(), $this, '' );
    $parser->parseMeta( $meta, $this, '' );
}

=begin TML

---++ ObjectMethod insert($type, $key, $val) -> $boolean

Adds a key-value pair of the given type to the object. Type is Set or Local.
Callback used for the Prefs::Parser object, or can be used to add
arbitrary new entries to a prefs cache.

Note that attempts to redefine final preferences will be ignored.

Returns 1 if the preference was defined, 0 otherwise.

=cut

sub insert {
    my ( $this, $type, $key, $value ) = @_;

    return 0 if $this->{CONTEXT}->isFinalised($key);

    $value =~ tr/\r//d;                  # Delete \r
    $value =~ tr/\t/ /;                  # replace TAB by space
    $value =~ s/([^\\])\\n/$1\n/g;       # replace \n by new line
    $value =~ s/([^\\])\\\\n/$1\\n/g;    # replace \\n by \n
    $value =~ tr/`//d;                   # filter out dangerous chars
    if ( $type eq 'Local' ) {
        $this->{locals}{ $this->{SOURCE} . '-' . $key } = $value;
    }
    else {
        $this->{values}{$key} = $value;
    }
    $this->{SetHere}{$key} = 1;

    return 1;
}

=begin TML

---++ ObjectMethod stringify($html, \%shown) -> $text

Generate an (HTML if $html) representation of the content of this cache.

=cut

sub stringify {
    my ( $this, $html ) = @_;
    my $res;

    if ($html) {
        $res = CGI::Tr(
            CGI::th(
                { colspan => 2, class => 'foswikiFirstCol' },
                CGI::h3( $this->{TYPE} . ' ' . $this->{SOURCE} )
            )
        ) . "\n";
    }
    else {
        $res = '******** ' . $this->{TYPE} . ' ' . $this->{SOURCE} . "\n";
    }

    foreach my $key ( sort keys %{ $this->{values} } ) {
        next unless $this->{SetHere}{$key};
        my $final = '';
        if ( $this->{final}{$key} ) {
            $final = ' *final* ';
        }
        my $val = $this->{values}{$key};
        $val =~ s/^(.{32}).*$/$1..../s;
        if ($html) {
            $val = "\n<verbatim style='margin:0;'>\n$val\n</verbatim>\n"
              if $val;
            $res .= CGI::Tr( { valign => 'top' },
                CGI::td(" Set $final $key") . CGI::td($val) )
              . "\n";
        }
        else {
            $res .= "Set $final $key = $val\n";
        }
    }
    foreach my $key ( sort keys %{ $this->{locals} } ) {
        next unless $this->{SetHere}{$key};
        my $final = '';
        my $val   = $this->{locals}{$key};
        $val =~ s/^(.{32}).*$/$1..../s;
        if ($html) {
            $val = "\n<verbatim style='margin:0;'>\n$val\n</verbatim>\n"
              if $val;
            $res .= CGI::Tr( { valign => 'top' },
                CGI::td(" Local $key") . CGI::td($val) )
              . "\n";
        }
        else {
            $res .= "Local $key = $val\n";
        }
    }
    return $res;
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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
