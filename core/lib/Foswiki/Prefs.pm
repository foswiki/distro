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
topic definition of the variable is always taken when it is referenced in the
topic where it is defined. This is a special case to deal with the case where a
preference has to have a different value in the defining topic.

Values in global and local scope are accessed using =getPreference=/

The final scope is _topic_ scope. In this scope, the value of the preference is
taken directly from the contents of the topic, and is not overridden by wider
scopes. Topic scope is used for access controls.

Because the highest cost in evaluating preferences is reading the individual
topics, preferences read from a topic are cached.

An object of type Foswiki::Prefs is a singleton that provides an interface to
this cache. Normally the cache is repopulated for each request, though it would
be feasible to cache it on disc if some invalidation mechanism were available
to deal with topic changes.

This mechanism is composed by a front-end (implemented by this class) that
deals with preferences logic and back-end objects that provide access to
preferences values. There is one back-end for each topic (Web preferences are
back-ends correspondind to the WebPreferences topic). Additionaly, there is a
back-end object for session preferences. Each context has its own session
preferences and thus its own session back-end object.

Preferences are like a stack: there are many levels and higher levels have
precedence over lower levels. It's also needed to push a context and pop to the
earlier state. It would be easy to implement this stack, but then we would have
a problem: to get the value of a preference we would need to scan each level
and it's slow, so we need some fast mechanism to know in which level a
preference is defined. Or we could copy the values from lower leves to higher
ones and override the preferences defined at that level. This later approach
wastes memory. This implementation picks the former and we use bitstrings and
some maths to accomplish that. It's also flexible and it doesn't matter how
preferences are stored.  Refer to http://foswiki.org/Development/ThinPrefs for
details.

=cut

package Foswiki::Prefs;

use bytes;

use Assert;
use Foswiki::Prefs::TopicRAM ();
use Foswiki::Prefs::HASH     ();
use Scalar::Util             ();

=begin TML

---++ ClassMethod new( $session )

Creates a new Prefs object. 

=cut

sub new {
    my ( $proto, $session ) = @_;
    my $class = ref($proto) || $proto;
    my $this = {
        'stacks' => [
            {

                # There is the main stack and one stack for each (sub)web.
                # We initialize the first (main) and others are created on
                # demand.
                'final'  => {},    # Map prefs to the level where
                                   # they were finalised
                'levels' => [],    # Map the level to the
                                   # corresponding back-end object.
                'map'    => {},    # Stores the preferences bitmaps
            }
        ],
        'prefix'      => [],   # Map level => prefix uesed
                               #     (plugins prefix prefs with PLUGINNAME_)
        'paths'       => {},   # Map paths to backend objects
        'contexts'    => [],   # Store the main levels corresponding to contexts
        'weblocation' => {},   # Stack and Level where prefs from a (sub)web are
        'internals'   => {},   # Store internal preferences
        'session' => $session,
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

    undef $this->{stacks};
    undef $this->{prefix};
    undef $this->{session};
    undef $this->{contexts};
    $_->finish() foreach values %{ $this->{paths} };
    undef $this->{paths};
    undef $this->{weblocation};
    undef $this->{internals};
}

# Get a backend object corresponding to the given $web,$topic
# or Foswiki::Meta object
sub _getBackend {
    my $this       = shift;
    my $metaObject = shift;
    $metaObject = Foswiki::Meta->new( $this->{session}, $metaObject, @_ )
      unless ref($metaObject) && UNIVERSAL::isa( $metaObject, 'Foswiki::Meta' );
    my $path = $metaObject->getPath();
    unless ( exists $this->{paths}{$path} ) {
        $this->{paths}{$path} = Foswiki::Prefs::TopicRAM->new($metaObject);
    }
    return $this->{paths}{$path};
}

# Create a new level on the preferences stack, based on the
# given backend object or class name and prefix.
sub _newLevel {
    my ( $stack, $back, $prefix ) = @_;

    push @{ $stack->{levels} }, $back;
    my $level = $#{ $stack->{levels} };
    $prefix ||= '';
    foreach ( map { $prefix . $_ } $back->prefs ) {
        next if exists $stack->{final}{$_};
        $stack->{'map'}{$_} = '' unless exists $stack->{'map'}{$_};
        vec( $stack->{'map'}{$_}, $level, 1 ) = 1;
    }

    my @finalPrefs = split /[,\s]+/, ( $back->get('FINALPREFERENCES') || '' );
    foreach (@finalPrefs) {
        $stack->{final}{$_} = $level
          unless exists $stack->{final}{$_};
    }

    return $back;
}

sub _getDefinitionLevel {
    my $map = shift;
    return
      int( log( ord( substr( $map, -1 ) ) ) / log(2) ) +
      ( ( length($map) - 1 ) * 8 );
}

sub _getStackPreference {
    my ( $stack, $key, $level ) = @_;
    my $map = $stack->{'map'}{$key};
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
    my $defLevel = _getDefinitionLevel($map);
    return $stack->{levels}->[$defLevel]->get($key);
}

sub _cloneStack {
    my ( $src, $level );
    my $clone = {
        'map'    => { %{ $src->{'map'} } },
        'levels' => [ @{ $src->{levels} } ],
        'final'  => { %{ $src->{final} } },
    };
    _restore( $src, $level ) if defined $level;
    return $clone;
}

sub _pushWebInStack {
    my ( $this, $stack, $web ) = @_;
    my @webPath = split( /[\/\.]+/, $web );
    my $subWeb = '';
    $subWeb = join '/', splice @webPath, 0, scalar @{ $stack->{levels} };
    my $back;
    foreach (@webPath) {
        $subWeb .= '/' if $subWeb;
        $subWeb .= $_;
        $back = $this->_getBackend( $subWeb, $Foswiki::cfg{WebPrefsTopicName} );
        _newLevel( $stack, $back );
    }
}

sub _getWebPreference {
    my ($this, $web, $key) = @_;
    my ($stack, $level);
    
    if ( exists $this->{weblocation}{$web} ) {
        ( $stack, $level ) = $this->{weblocation}{$web};
        return _getStackPreference( $stack, $key, $level );
    }
    
    my $part;
    $stack = {
        'levels' => [],
        'map'    => '',
        'final'  => {},
    };
    my @path = split /[\/\.]+/, $web;
    my @websToAdd = (pop @path);
    while ( @path > 0 ) {
        $part = join( '/', @path );
        if ( exists $this->{weblocation}{$part} ) {
            $stack = _cloneStack(@{$this->{weblocation}{$part}});
            last;
        }
        unshift @websToAdd, pop @path;
    }

    _pushWebInStack($stack, $web);
    push @{ $this->{stacks} }, $stack;
    $level = scalar @path;
    foreach (@websToAdd) {
        $part .= '/' if $part;
        $part .= $_;
        $this->{weblocation}{$part} = [ $stack, $level++ ];
    }
    return _getStackPreference( $stack, $key );
}

=begin TML

---++ ObjectMethod loadPreferences( $topicObject ) -> $back

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

    my $back;

    if ( $topicObject->topic() ) {
        $back = $this->_getBackend($topicObject);
    }
    elsif ( $topicObject->web() ) {

        # Link to the cache for the web preferences topic
        $back =
          $this->_getBackend( $topicObject->web(),
            $Foswiki::cfg{WebPrefsTopicName} );
    }
    elsif ( $Foswiki::cfg{LocalSitePreferences} ) {
        my ( $web, $topic ) =
          $this->{session}
          ->normalizeWebTopicName( undef, $Foswiki::cfg{LocalSitePreferences} );

        # Use the site preferences
        $back = $this->_getBackend( $web, $topic );
    }

    return $back;
}

=begin TML

---++ ObjectMethod pushTopicContext( $web, $topic )

Reconfigures the preferences so that general preference values appear
to come from $web.$topic. The topic context can be popped again using 
popTopicContext.

=cut

sub pushTopicContext {
    my ( $this, $web, $topic ) = @_;

    my $stack = $this->{stacks}->[0];    # Main prefs is always stack 0.
    push @{ $this->{contexts} }, $#{ $stack->{levels} };
    my @webPath = split( /[\/\.]+/, $web );
    my $subWeb = '';
    my $back;
    foreach (@webPath) {
        $subWeb .= '/' if $subWeb;
        $subWeb .= $_;
        $back = $this->_getBackend( $subWeb, $Foswiki::cfg{WebPrefsTopicName} );
        _newLevel( $stack, $back );
    }
    $back = $this->_getBackend( $web, $topic );
    _newLevel( $stack, $back );
    _newLevel( $stack, Foswiki::Prefs::HASH->new() );
}

=begin TML

---+++ popTopicContext()

Returns the context to the state it was in before the
=pushTopicContext= was last called.

=cut

sub popTopicContext {
    my $this  = shift;
    my $stack = $this->{stacks}->[0];
    my $level = pop @{ $this->{contexts} };
    _restore( $stack, $level );
    splice @{ $this->{prefix} }, $level + 1 if @{ $this->{prefix} } > $level;
    return (
        $stack->{levels}->[-3]->topicObject->web(),
        $stack->{levels}->[-2]->topicObject->topic()
    );
}

# Restores the preferences stack to the given level
sub _restore {
    my ( $stack, $level ) = @_;

    my @keys = grep { $stack->{final}{$_} > $level } keys %{ $stack->{final} };
    delete @{ $stack->{final} }{@keys};
    splice @{ $stack->{levels} }, $level + 1;

    my $mask =
      ( chr(0xFF) x int( $level / 8 ) )
      . chr( ( 2**( ( $level % 8 ) + 1 ) ) - 1 );
    foreach ( keys %{ $stack->{'map'} } ) {
        $stack->{'map'}{$_} &= $mask;
        substr( $stack->{'map'}{$_}, -1 ) = ''
          while length( $stack->{'map'}{$_} ) > 0
              && ord( substr( $stack->{'map'}{$_}, -1 ) ) == 0;
        delete $stack->{'map'}{$_} if length( $stack->{'map'}{$_} ) == 0;
    }
}

=begin TML

---++ ObjectMethod setPluginPreferences( $web, $plugin )

Reads preferences from the given plugin topic and injects them into
the plugin preferences cache. Preferences cannot be finalised in
plugin topics.

=cut

sub setPluginPreferences {
    my ( $this, $web, $plugin ) = @_;
    my $back   = $this->_getBackend( $web, $plugin );
    my $prefix = uc($plugin) . '_';
    my $stack  = $this->{stacks}->[0];
    _newLevel( $stack, $back, $prefix );
    $this->{prefix}->[ $#{ $stack->{levels} } ] = $prefix;
}

=begin TML

---++ ObjectMethod setUserPreferences( $wikiname )

Reads preferences from the given user topic and pushes them to the preferences
stack.

=cut

sub setUserPreferences {
    my ( $this, $wn ) = @_;
    my $back = $this->_getBackend( $Foswiki::cfg{UsersWebName}, $wn );
    _newLevel($this->{stacks}->[0], $back);
}

=begin TML

---++ ObjectMethod loadDefaultPreferences()

Add default preferences to this preferences stack.

=cut

sub loadDefaultPreferences {
    my $this = shift;
    my $back = $this->_getBackend( $Foswiki::cfg{SystemWebName},
        $Foswiki::cfg{SitePrefsTopicName} );
    _newLevel($this->{stacks}->[0], $back);
}

=begin TML

---++ ObjectMethod loadSitePreferences()
Add local site preferences to this preferences stack.

=cut

sub loadSitePreferences {
    my $this = shift;
    if ( $Foswiki::cfg{LocalSitePreferences} ) {
        my ( $web, $topic ) =
          $this->{session}
          ->normalizeWebTopicName( undef, $Foswiki::cfg{LocalSitePreferences} );
        my $back = $this->_getBackend( $web, $topic );
        _newLevel($this->{stacks}->[0], $back);
    }
}

=begin TML

---++ ObjectMethod setSessionPreferences( %values )

Set the preference values in the parameters in the SESSION stack.

=cut

sub setSessionPreferences {
    my ( $this, %values ) = @_;
    my $stack = $this->{stacks}->[0];
    my $back  = $stack->{levels}->[-1];
    my $level = $#{ $stack->{levels} };
    my $num   = 0;
    while ( my ( $k, $v ) = each %values ) {
        $num += $back->insert( 'Set', $k, $v );
        $stack->{'map'}{$k} = '' unless exists $stack->{'map'}{$k};
        vec( $stack->{'map'}{$k}, $level, 1 ) = 1;
    }

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
        $this->{internals}{$k} = $v;
    }
}

=begin TML

---++ ObjectMethod getPreference( $key ) -> $value
   * =$key - key to look up

Returns the finalised preference value.

=cut

sub getPreference {
    my ( $this, $key ) = @_;

    if ( defined $this->{internals}{$key} ) {
        return $this->{internals}{$key};
    }

    my $value;
    my $stack = $this->{stacks}->[0];
    my $level = $#{ $stack->{levels} };
    $value = $stack->{levels}->[-2]->getLocal($key)
      unless defined $stack->{final}{$key}
          && $stack->{final}{$key} < $level - 1;

    if ( !defined $value && exists $stack->{'map'}{$key} ) {
        my $defLevel = _getDefinitionLevel( $stack->{'map'}{$key} );
        my $prefix   = $this->{prefix}->[$defLevel];
        $key =~ s/^\Q$prefix\E// if $prefix;
        $value = $stack->{levels}->[$defLevel]->get($key);
    }
    return $value;
}

=begin TML

---++ ObjectMethod stringify([$key]) -> $text

Generate TML-formatted information about the key (all keys if $key is undef)

=cut

sub stringify {
    my ( $this, $key ) = @_;

    my $stack = $this->{stacks}->[0];
    my @keys = defined $key ? ($key) : sort keys %{ $stack->{'map'} };
    my @list;
    foreach my $k (@keys) {
        my $val = Foswiki::entityEncode( $this->getPreference($k) || '' );
        push( @list, '   * Set ' . "$k = \"$val\"" );
        next unless exists $stack->{'map'}{$k};
        my $defLevel = _getDefinitionLevel( $stack->{'map'}{$k} );
        if ( $stack->{levels}->[$defLevel]->can('topicObject') ) {
            my $topicObject = $stack->{levels}->[$defLevel]->topicObject();
            push( @list,
                    "      * $k was "
                  . ( defined $stack->{final}{$k} ? '*finalised*' : 'defined' )
                  . ' in <nop>'
                  . $topicObject->web() . '.'
                  . $topicObject->topic() );
        }
    }

    @keys = defined $key ? ($key) : ( sort $stack->{levels}->[-2]->localPrefs );
    foreach my $k (@keys) {
        next
          unless defined $stack->{levels}->[-2]->getLocal($k)
              && ( !defined $stack->{final}{$k}
                  || $stack->{final}{$k} >= $stack->{level} - 1 );
        my $val = Foswiki::entityEncode( $stack->{levels}->[-2]->getLocal($k) );
        push( @list, '   * Local ' . "$k = \"$val\"" );
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
