# See bottom of file for license and copyright information
use strict;

=begin TML

---+ package Foswiki::Prefs

The Prefs class is a singleton that implements management of preferences.
It uses a stack of Foswiki::Prefs::PrefsCache objects to store the
preferences for global, web, user and topic contexts, and provides
the means to look up preferences in these.

Preferences from different places stack on top of each other, so there
are global preferences, then site, then web (and subweb and subsubweb),
then topic, included topic and so on. Each level of the stack is tagged with
a type identifier.

The module also maintains a separate of the preferences found in every topic
and web it reads. This supports the lookup of preferences for webs and topics
that are not on the stack, and must not be chained in (you can't allow
a user to override protections from their home topic!)

=cut

package Foswiki::Prefs;

use Assert;

require Foswiki::Prefs::PrefsCache;

=begin TML

---++ ClassMethod new( $session [, $cache] )

Creates a new Prefs object. If $cache is defined, it will be
pushed onto the stack.

=cut

sub new {
    my ( $class, $session, $cache ) = @_;
    my $this = bless( { session => $session }, $class );

    push( @{ $this->{PREFS} }, $cache ) if defined($cache);

    # $this->{TOPICS} - hash of Foswiki::Prefs objects, for solitary topics
    # $this->{WEBS} - hash of Foswiki::Prefs objects, for solitary webs
    # remember what "Local" means
    $this->{LOCAL} = $session->{webName} . '.' . $this->{session}->{topicName};

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

    foreach ( @{ $this->{PREFS} } ) {
        $_->finish();
    }
    undef $this->{PREFS};

    foreach ( values %{ $this->{TOPICS} } ) {
        $_->finish();
    }
    undef $this->{TOPICS};

    foreach ( values %{ $this->{WEBS} } ) {
        $_->finish();
    }
    undef $this->{WEBS};

    undef $this->{LOCAL};
    undef $this->{session};
}

=begin TML

---++ ObjectMethod pushPreferences( $web, $topic, $type, $prefix )
   * =$web= - web to read from
   * =$topic= - topic to read
   * =$type= - DEFAULT, SITE, USER, SESSION, WEB, TOPIC or PLUGIN
   * =$prefix= - key prefix for all preferences (used for plugins)
Reads preferences from the given topic, and pushes them onto the
preferences stack.

=cut

sub pushPreferences {
    my ( $this, $web, $topic, $type, $prefix ) = @_;
    my $top;

    if ( $this->{PREFS} ) {
        $top = $this->{PREFS}[ $#{ $this->{PREFS} } ];
    }

    my $req =
      new Foswiki::Prefs::PrefsCache( $this, $top, $type, $web, $topic, $prefix );

    if ($req) {
        push( @{ $this->{PREFS} }, $req );
        $req->finalise($this);
    }
}

=begin TML

---++ ObjectMethod pushWebPreferences( $web )

Pushes web preferences. Web preferences for a particular web depend
on the preferences of all containing webs.

=cut

sub pushWebPreferences {
    my ( $this, $web ) = @_;

    my @webPath = split( /[\/\.]/, $web );
    my $path = '';
    foreach my $tmp (@webPath) {
        $path .= '/' if $path;
        $path .= $tmp;
        $this->pushPreferences( $path, $Foswiki::cfg{WebPrefsTopicName}, 'WEB' );
    }
}

=begin TML

---++ ObjectMethod pushGlobalPreferences()
Add global preferences to this preferences stack.

=cut

sub pushGlobalPreferences {
    my $this = shift;

    # Default prefs first, from read-only web
    my $prefs = $this->pushPreferences( $Foswiki::cfg{SystemWebName},
        $Foswiki::cfg{SitePrefsTopicName}, 'DEFAULT' );

}

sub pushGlobalPreferencesSiteSpecific {
    my $this = shift;

    # Then local site prefs
    if ( $Foswiki::cfg{LocalSitePreferences} ) {
        my ( $lweb, $ltopic ) =
          $this->{session}
          ->normalizeWebTopicName( undef, $Foswiki::cfg{LocalSitePreferences} );
        $this->pushPreferences( $lweb, $ltopic, 'SITE' );
    }
}

=begin TML

---++ ObjectMethod pushPreferencesValues( $type, \%values )
Push a new preference level using type and values given

=cut

sub pushPreferenceValues {
    my ( $this, $type, $values ) = @_;

    return unless $values;

    my $top;
    if ( $this->{PREFS} ) {
        $top = $this->{PREFS}[ $#{ $this->{PREFS} } ];
    }

    my $req = new Foswiki::Prefs::PrefsCache( $this, $top, $type );

    foreach my $key ( keys %$values ) {
        my $val = $values->{$key} || '';
        $req->insert( 'Set', $key, $val );
    }

    push( @{ $this->{PREFS} }, $req );
    $req->finalise($this);
}

=begin TML

---++ ObjectMethod mark()
Return a marker representing the current top of the preferences
stack. Used to remember the stack when new web and topic preferences
are pushed during a topic include.

=cut

sub mark {
    my $this = shift;
    return scalar( @{ $this->{PREFS} } );
}

=begin TML

---++ ObjectMethod restore( $mark )
Resets the preferences stack to the given mark, to recover after a topic
include.

=cut

sub restore {
    my ( $this, $where ) = @_;
    ASSERT($where) if DEBUG;
    splice( @{ $this->{PREFS} }, $where );
}

=begin TML

---++ ObjectMethod getPreferencesValue( $key ) -> $value
   * =$key - key to look up

Returns the value of the preference =$key=, or undef.

Looks up local preferences when the level
topic is the same as the current web,topic in the session.

=cut

sub getPreferencesValue {
    my ( $this, $key ) = @_;

    return undef unless @{ $this->{PREFS} };
    my $top = $this->{PREFS}[ $#{ $this->{PREFS} } ];
    my $lk  = $this->{LOCAL} . '-' . $key;
    if ( defined( $top->{locals}{$lk} ) ) {
        return $top->{locals}{$lk};
    }
    else {
        return $top->{values}{$key};
    }
}

=begin TML

---++ ObjectMethod isFinalised( $key )
Return true if $key is finalised somewhere in the prefs stack

=cut

sub isFinalised {
    my ( $this, $key ) = @_;

    foreach my $level ( @{ $this->{PREFS} } ) {
        return 1 if $level->{final}{$key};
    }

    return 0;
}

=begin TML

---++ ObjectMethod getTopicPreferencesValue( $key, $web, $topic ) -> $value

Recover a preferences value that is defined in a specific topic. Does
not recover web, user or global settings.

Intended for use in protections mechanisms, where the order doesn't match
the prefs stack.

=cut

sub getTopicPreferencesValue {
    my ( $this, $key, $web, $topic ) = @_;

    return undef unless defined $web && defined $topic;
    my $wtn = $web . '.' . $topic;

    unless ( $this->{TOPICS}{$wtn} ) {
        $this->{TOPICS}{$wtn} =
          new Foswiki::Prefs::PrefsCache( $this, undef, 'TOPIC', $web, $topic );
    }
    return $this->{TOPICS}{$wtn}->{values}{$key};
}

=begin TML

---++ getTextPreferencesValue( $key, $text, $meta, $web, $topic ) -> $value
Get a preference value from the settings in the text (and/or optional $meta).
The values read are *not* cached.

=cut

sub getTextPreferencesValue {
    my ( $this, $key, $text, $meta, $web, $topic ) = @_;

    my $wtn = $web . '.' . $topic;

    my $cache = new Foswiki::Prefs::PrefsCache( $this, undef, 'TOPIC' );
    $cache->loadPrefsFromText( $text, $meta, $web, $topic );

    return $cache->{values}{$key};
}

=begin TML

---++ ObjectMethod getWebPreferencesValue( $key, $web ) -> $value

Recover a preferences value that is defined in the webhome topic of
a specific web.. Does not recover user or global settings, but
does recover settings from containing webs.

Intended for use in protections mechanisms, where the order doesn't match
the prefs stack.

=cut

sub getWebPreferencesValue {
    my ( $this, $key, $web ) = @_;

    return undef unless defined $web;

    my $wtn = $web . '.' . $Foswiki::cfg{WebPrefsTopicName};

    unless ( $this->{WEBS}{$wtn} ) {
        my $blank = new Foswiki::Prefs( $this->{session} );
        $blank->pushWebPreferences($web);
        $this->{WEBS}{$wtn} = $blank;
    }

    return $this->{WEBS}{$wtn}->getPreferencesValue($key);
}

=begin TML

---+++ setPreferencesValue($name, $val)

Set a preferences value. The preference is set in the context at the
top of the preference stack, whatever the current state may be.

The preference is not serialised.

=cut

sub setPreferencesValue {
    my ( $this, $name, $value ) = @_;

    my $top = $this->{PREFS}[ $#{ $this->{PREFS} } ];
    return $top->insert( 'Set', $name, $value );
}

=begin TML

---++ObjectMethod stringify() -> $text

Generate a TML-formatted version of the current preferences

=cut

sub stringify {
    my ( $this, $html ) = @_;
    my $s = '';

    my %shown;
    $html = 1 unless defined $html;

    foreach my $ptr ( reverse @{ $this->{PREFS} } ) {
        $s .= $ptr->stringify( $html, \%shown );
    }

    if ($html) {
        return CGI::table( { class => 'foswikiTable' }, $s );
    }
    else {
        return $s;
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
