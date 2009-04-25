# See bottom of file for license and copyright information
use strict;

=begin TML

---+ package Foswiki::Prefs

Preferences are set in topics, using either 'Set' lines embedded in the
topic text, or via PREFERENCE meta-data attached to the topic. A preference
value has three _scopes_:
   * _Global_ scope
   * _Local_ scope
   * _Topic_ scope

In _global_ scope, the value of a preference is determined by examining
settings of the variable at different levels; default preferences, site level,
parent web level, web level, user level, and topic level. To determine a
preference value in global scope, you have to know what topic the topic is
referenced in, to provide the scope for the request.

A preference may be optionally defined in _Local_ scope, in which case the
topic definition of the variable is always taken when it is referenced in
the topic where it is defined. This is a special case to deal with the case
where a preference has to have a different value in the defining topic.

Values in global and local scope are accessed using =getPreference=/

The final scope is _topic_ scope. In this scope, the value of the preference
is taken directly from the contents of the topic, and is not overridden by
wider scopes. Topic scope is used for access controls.

Because the highest cost in evaluating preferences is reading the individual
topics, preferences read from a topic are cached.

An object of type Foswiki::Prefs is a singleton that provides an interface
to this cache. Normally the cache is repopulated for each request, though
it would be feasible to cache it on disc if some invalidation mechanism
were available to deal with topic changes.

As well as the caches for the individual topics there is a stack for each
level of preferences; DEFAULT, SITE, USER, SESSION, WEB, TOPIC and PLUGIN.
The head of each stack represents the current state of that preference
context.

Whenever one or more stacks has been pushed, the Prefs object is "finalised"
to generate the general prefs tables. These tables reflect the current state
of the preferences context, taking into account finalisation at different
levels in the scoping. There are two tables for finalised value, one for
locals and another for globals, and a third table that stores an internal
preferences table that overrides the other two. This is used for transitory
preferences, such as the including context during transclusion, and for
preferences that must not be overriden by any user action, such as the
session ID.

=cut

package Foswiki::Prefs;

use Assert;

use Foswiki::Prefs::Cache ();

# Preference stacks, in order of evaluation (SESSION overrides DEFAULT)
our @levels = qw( DEFAULT PLUGIN SITE USER WEB TOPIC SESSION );

=begin TML

---++ ClassMethod new( $session [, $cache] )

Creates a new Prefs object. If $cache is defined, it will be
pushed onto the stack.

=cut

sub new {
    my ( $class, $session, $cache ) = @_;
    my $this = bless(
        {
            session   => $session,
            stacks    => {},         # hash of stacks, indexed by @levels
            topics    => {},         # hash of Foswiki::Prefs::Cache objects
            internals => {},         # Foswiki internals
            finalised => undef,      # the finalised preferences cache
            locals    => undef,      # locals cache
        },
        $class
    );

    foreach my $level (@levels) {
        $this->{stacks}->{$level} = [];
    }

    # Always have a session stack, so no point creating it lazily
    push( @{ $this->{stacks}->{SESSION} }, new Foswiki::Prefs::Cache() );

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

    foreach my $topic ( values %{ $this->{cache} } ) {
        $topic->finish();
    }
    undef $this->{cache};
    undef $this->{stacks};
    undef $this->{values};
    undef $this->{locals};
    undef $this->{internals};
    undef $this->{session};
}

# Look up, lazy-loading if required, the preferences cache for a topic
# or web.
sub _getCache {
    my ( $this, $web, $topic ) = @_;
    ASSERT( $this->{session} ) if DEBUG;
    my $path = $web;
    $path .= ".$topic" if $topic;
    unless ( $this->{cache}->{$path} ) {
        my $meta = Foswiki::Meta->load( $this->{session}, $web, $topic );
        $meta->getPreference('ANY');    # to force a cache load
    }
    return $this->{cache}->{$path};
}

=begin TML

---++ ObjectMethod loadPreferences( $topicObject ) -> $cache

Invoked from Foswiki::Meta to load the preferences into the preferences
cache. used as part of the lazy-loading of preferences.

Web preferences are loaded from the {WebPrefsTopicName}.

=cut

sub loadPreferences {
    my ( $this, $topicObject ) = @_;
    my $path = $topicObject->getPath();
    $topicObject->session->logger->log( 'debug',
        "Loading preferences for $path\n" )
      if DEBUG;
    my $cache;
    if ( $topicObject->topic() ) {
        $cache = new Foswiki::Prefs::Cache($topicObject);
    }
    elsif ( $topicObject->web() ) {

        # Link to the cache for the web preferences topic
        $cache =
          $this->_getCache( $topicObject->web(),
            $Foswiki::cfg{WebPrefsTopicName} );
    }
    else {

        # Use the site preferences
        $cache = $this->{stacks}->{SITE}[-1];
    }

    $this->{cache}->{$path} = $cache;

    return $cache;
}

=begin TML

---++ ObjectMethod pushTopicContext( $web, $topic )

Reconfigures the preferences so that general preference values appear
to come from $web.$topic. The topic context can be popped again using 
popTopicContext.

=cut

sub pushTopicContext {
    my ( $this, $web, $topic ) = @_;
    my $session = $this->{session};

    # Push the web preferences and topic preferences of the new context
    # The act of pushing will inherit the preferences of the topic
    # already at the head of the stack.
    push(
        @{ $this->{stacks}->{WEB} },
        $this->_getCache( $web, $Foswiki::cfg{WebPrefsTopicName} )
    );
    push( @{ $this->{stacks}->{TOPIC} }, $this->_getCache( $web, $topic ) );

    # Also push a new session stack, to accept local session vars e.g.
    # include params
    push(
        @{ $this->{stacks}->{SESSION} },
        new Foswiki::Prefs::Cache( $this->{stacks}->{SESSION}[-1] )
    );
    $this->{values} = undef;
}

=begin TML

---+++ popTopicContext()

Returns the context to the state it was in before the
=pushTopicContext= was last called.

=cut

sub popTopicContext {
    my $this    = shift;
    my $session = $this->{session};
    pop( @{ $this->{stacks}->{TOPIC} } );
    pop( @{ $this->{stacks}->{WEB} } );
    pop( @{ $this->{stacks}->{SESSION} } );
    $this->{values} = undef;
    return (
        $this->{stacks}->{WEB}[-1]->{web},
        $this->{stacks}->{TOPIC}[-1]->{topic}
    );
}

=begin TML

---++ ObjectMethod setPluginPreferences( $web, $plugin )

Reads preferences from the given plugin topic and injects them into
the plugin preferences cache. Preferences cannot be finalised in
plugin topics.

=cut

sub setPluginPreferences {
    my ( $this, $web, $plugin ) = @_;
    unless ( scalar( @{ $this->{stacks}->{PLUGIN} } ) ) {

        # Create pseudo-topic for collating plugins preferences
        push( @{ $this->{stacks}->{PLUGIN} }, new Foswiki::Prefs::Cache() );
    }

    # And load it with values from the plugin topic
    my $topic = $this->_getCache( $web, $plugin );
    while ( my ( $k, $v ) = each %{ $topic->{values} } ) {
        $this->{stacks}->{PLUGIN}[-1]
          ->insert( 'Set', uc($plugin) . '_' . $k, $v );
    }
    $this->{values} = undef;
}

=begin TML

---++ ObjectMethod pushUserPreferences( $wikiname )

Reads preferences from the given user topic and pushes them to the head
of the user preferences stack.

=cut

sub pushUserPreferences {
    my ( $this, $wn ) = @_;
    push(
        @{ $this->{stacks}->{USER} },
        $this->_getCache( $Foswiki::cfg{UsersWebName}, $wn )
    );
    $this->{values} = undef;
}

=begin TML

---++ ObjectMethod popUserPreferences()

Pop the preferences pushed by an earlier pushUserPreferences.

=cut

sub popUserPreferences {
    my ( $this, $wn ) = @_;
    ASSERT( scalar( @{ $this->{stacks}->{USER} } ) > 1 ) if DEBUG;
    pop( @{ $this->{stacks}->{USER} } );
    $this->{values} = undef;
}

=begin TML

---++ ObjectMethod loadDefaultPreferences()
Add default preferences to this preferences stack.

=cut

sub loadDefaultPreferences {
    my $this = shift;

    push(
        @{ $this->{stacks}->{DEFAULT} },
        $this->_getCache(
            $Foswiki::cfg{SystemWebName},
            $Foswiki::cfg{SitePrefsTopicName}
        )
    );
    $this->{values} = undef;
}

=begin TML

---++ ObjectMethod loadSitePreferences()
Add local site preferences to this preferences stack.

=cut

sub loadSitePreferences {
    my $this = shift;

    # Then local site prefs
    if ( $Foswiki::cfg{LocalSitePreferences} ) {
        my ( $lweb, $ltopic ) =
          $this->{session}
          ->normalizeWebTopicName( undef, $Foswiki::cfg{LocalSitePreferences} );
        push( @{ $this->{stacks}->{SITE} },
            $this->_getCache( $lweb, $ltopic ) );
        $this->{values} = undef;
    }
}

=begin TML

---++ ObjectMethod setSessionPreferences( %values )

Set the preference values in the parameters in the SESSION stack.

=cut

sub setSessionPreferences {
    my ( $this, %values ) = @_;

    my $req = $this->{stacks}->{SESSION}[-1];
    my $num = 0;
    while ( my ( $k, $v ) = each %values ) {
        $num += $req->insert( 'Set', $k, $v );
    }

    # Force re-finalisation
    $this->{values} = undef;

    return $num;
}

=begin TML

---++ ObjectMethod setInternalPreferences( %values )

Designed specifically for imposing the value of preferences on a short-term
basis in the code, internal preferences override all other definitions of
the same tag. This function should be used with great care.

For those who are used to the old code, internal preferences replace the old
SESSION_TAGS field from the Foswiki object.

=cut

sub setInternalPreferences {
    my ( $this, %values ) = @_;

    while ( my ( $k, $v ) = each %values ) {
        $this->{internals}->{$k} = $v;
    }
}

=begin TML

---++ ObjectMethod getPreference( $key ) -> $value
   * =$key - key to look up

Returns the finalised preference value.

=cut

sub getPreference {
    my ( $this, $key, $scope ) = @_;

    $this->_finalise();
    ASSERT( $this->{values} ) if DEBUG;

    if ( defined $this->{internals}->{$key} ) {
        return $this->{internals}->{$key};
    }
    elsif ( defined $this->{locals}->{$key} ) {
        return $this->{locals}->{$key};
    }
    else {
        return $this->{values}->{$key};
    }
}

# Evaluate all the stacks to generate finalised preferences
sub _finalise {
    my ( $this, $whereSet ) = @_;

    # $whereSet is an optional ref to a hash, which we use for ALLVARIABLES.
    # We only populate it if we are asked to.

    return if $this->{values};

    my %values    = ();
    my %finalised = ();
    foreach my $level (@levels) {
        next unless $this->{stacks}->{$level};
        next unless scalar( @{ $this->{stacks}->{$level} } );
        # Examine values at each level in the stack
        my $top = $this->{stacks}->{$level}->[-1];
        while ( my ( $k, $v ) = each %{ $top->{values} } ) {
            # If this key has not been finalised
            unless ( $finalised{$k} ) {
                $values{$k} = $v;
                if ($whereSet) {
                    # Record where this value was set for debugging
                    $whereSet->{$k} =
                      ( $top->{web} ? "$top->{web}.$top->{topic}" : $level );
                }
            }
        }

        # Update finalisation for the next level
        my $finals = $top->{values}->{FINALPREFERENCES};
        if ($finals) {
            foreach my $fk ( split( /[\s,]+/, $finals ) ) {

                # Record *where* it was finalised
                $finalised{$fk} = 1;
            }
        }
    }
    $this->{values}    = \%values;
    $this->{finalised} = \%finalised;

    # Compute locals
    my %locals = ();
    if ( $this->{stacks}->{TOPIC}
        && scalar( @{ $this->{stacks}->{TOPIC} } ) )
    {
        my $top = $this->{stacks}->{TOPIC}->[-1];
        while ( my ( $k, $v ) = each %{ $top->{locals} } ) {
            $locals{$k} = $v;    # Locals are not affected by finalisation
        }
    }
    $this->{locals} = \%locals;
}

=begin TML

---++ ObjectMethod stringify([$key]) -> $text

Generate TML-formatted information about the key (all keys if $key is undef)

=cut

sub stringify {
    my ($this, $key) = @_;

    # Refinalise to populate %whereSet
    undef $this->{values};
    my %whereSet;
    $this->_finalise( \%whereSet );

    my @keys = defined $key ? ( $key ) : sort keys %{ $this->{values} };
    my @list;
    foreach my $k ( @keys ) {
        my $val = Foswiki::entityEncode( $this->{values}->{$k} );
        push( @list, '   * Set '."$k = \"$val\"");
        if (defined $whereSet{$k}) {
            push( @list, "      * $k was "
                    .($this->{finalised}->{$k} ? '*finalised*' : 'defined')
                      ." in <nop>$whereSet{$k}");
        }
    }
    @keys = defined $key ? ( $key ) : sort keys %{ $this->{locals} };
    foreach my $k ( @keys ) {
        next unless defined $this->{locals}->{$k};
        my $val = Foswiki::entityEncode( $this->{locals}->{$k} );
        push( @list, '   * Local '."$k = \"$val\"" );
    }

    return join( "\n", @list ) . "\n";
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
# and TWiki Contributors. All Rights Reserved.
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
