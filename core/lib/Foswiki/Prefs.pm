# See bottom of file for license and copyright information
use strict;
use warnings;
use Error;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---+ package Foswiki::Prefs

Preferences are set in topics, using either 'Set' lines embedded in the
topic text, or via PREFERENCE meta-data attached to the topic. A preference
value has four _scopes_:
   * _Global_ scope
   * _Local_ scope
   * _Web_ scope
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

Values in global and local scope are accessed using =getPreference=

_Web_ scope is used by web access controls. Subwebs inherint access controls
from parent webs and only from parent webs. Global and Local scopes are
disconsidered.

The final scope is _topic_ scope. In this scope, the value of the preference is
taken directly from the contents of the topic, and is not overridden by wider
scopes. Topic scope is used for topic access controls.

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
preferences are stored. 

=cut

package Foswiki::Prefs;

use Assert;
use Foswiki::Prefs::HASH  ();
use Foswiki::Prefs::Stack ();
use Foswiki::Prefs::Web   ();
use Scalar::Util          ();

=begin TML

---++ ClassMethod new( $session )

Creates a new Prefs object. 

=cut

sub new {
    my ( $proto, $session ) = @_;
    my $class = ref($proto) || $proto;
    my $this = {
        'main'  => Foswiki::Prefs::Stack->new(),  # Main preferences stack
        'paths' => {},                            # Map paths to backend objects
        'contexts'  => [],    # Store the main levels corresponding to contexts
        'prefix'    => [],    # Map level => prefix uesed
                              #     (plugins prefix prefs with PLUGINNAME_)
        'webprefs'  => {},    # Foswiki::Prefs::Web objs, used to get web prefs
        'internals' => {},    # Store internal preferences
        'session' => $session,
    };

    eval "use $Foswiki::cfg{Store}{PrefsBackend} ()";
    die $@ if $@;

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

    $this->{main}->finish() if $this->{main};
    undef $this->{main};
    undef $this->{prefix};
    undef $this->{session};
    undef $this->{contexts};
    if ( $this->{paths} ) {
        foreach my $back ( values %{ $this->{paths} } ) {
            $back->finish();
        }
    }
    undef $this->{paths};
    if ( $this->{webprefs} ) {
        foreach my $webStack ( values %{ $this->{webprefs} } ) {
            $webStack->finish();
        }
    }
    undef $this->{webprefs};
    undef $this->{internals};
}

# Get a backend object corresponding to the given $web,$topic
sub _getBackend {
    my $this = shift;

    my $metaObject = Foswiki::Meta->new( $this->{session}, @_ );
    my $path = $metaObject->getPath();
    unless ( exists $this->{paths}{$path} ) {
        $this->{paths}{$path} =
          $Foswiki::cfg{Store}{PrefsBackend}->new($metaObject);
    }
    return $this->{paths}{$path};
}

# Given a (sub)web and a stack object, push the (sub)web on the stack,
# considering that part of the (sub)web may already be in the stack.  This is
# used to build, for example, Web/Subweb/WebA stack based on Web/Subweb or Web
# stack.
sub _pushWebInStack {
    my ( $this, $stack, $web ) = @_;
    my @webPath = split( /[\/\.]+/, $web );
    my $subWeb = '';
    $subWeb = join '/', splice @webPath, 0, $stack->size();
    my $back;
    foreach (@webPath) {
        $subWeb .= '/' if $subWeb;
        $subWeb .= $_;
        $back = $this->_getBackend( $subWeb, $Foswiki::cfg{WebPrefsTopicName} );
        $stack->newLevel($back);
    }
}

# Returns a Foswiki::Prefs::Web object. It consider the already existing
# objects and build a new one only if it doesn't exist. And even if it doesn't
# exist, consider existing ones to speedup the construction. Example:
# Web/SubWeb already exists and we want Web/Subweb/WebA. Then we just push
# WebA. If, instead, Web/Subweb/WebB exists, then we clone tha stack up to
# Web/Subweb and push WebA on it.
sub _getWebPrefsObj {
    my ( $this, $web ) = @_;
    my ( $stack, $level );

    if ( exists $this->{webprefs}{$web} ) {
        return $this->{webprefs}{$web};
    }

    my $part;
    $stack = Foswiki::Prefs::Stack->new();
    my @path = split /[\/\.]+/, $web;
    my @websToAdd = ( pop @path );
    while ( @path > 0 ) {
        $part = join( '/', @path );
        if ( exists $this->{webprefs}{$part} ) {
            my $base = $this->{webprefs}{$part};
            $stack =
                $base->isInTopOfStack()
              ? $base->stack()
              : $base->cloneStack( scalar(@path) - 1 );
            last;
        }
        unshift @websToAdd, pop @path;
    }

    $this->_pushWebInStack( $stack, $web );
    $part = join( '/', @path );
    $level = scalar(@path);
    foreach (@websToAdd) {
        $part .= '/' if $part;
        $part .= $_;
        $this->{webprefs}{$part} = Foswiki::Prefs::Web->new( $stack, $level++ );
    }
    return $this->{webprefs}{$web};
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

    #    $topicObject->session->logger->log( 'debug',
    #        "Loading preferences for $path\n" )
    #      if DEBUG;

    my $obj;

    if ( $topicObject->topic() ) {
        $obj = $Foswiki::cfg{Store}{PrefsBackend}->new($topicObject);
    }
    elsif ( $topicObject->web() ) {
        $obj = $this->_getWebPrefsObj( $topicObject->web() );
    }
    elsif ( $Foswiki::cfg{LocalSitePreferences} ) {
        my ( $web, $topic ) =
          $this->{session}
          ->normalizeWebTopicName( undef, $Foswiki::cfg{LocalSitePreferences} );

        # Use the site preferences
        $obj = $this->_getBackend( $web, $topic );
    }

    return $obj;
}

sub invalidatePath {
    my $this = shift;
    my $path;
    if ( ref( $_[0] ) ) {
        ASSERT( $_[0]->isa('Foswiki::Meta') ) if DEBUG;
        $path = $_[0]->getPath;
    }
    else {
        $path = $_[0];
    }

    if ( $this->{paths}->{$path} ) {

        #print STDERR "INVALIDATED: $this->{paths}->{$path}\n";
        delete $this->{paths}->{$path};
    }

}

=begin TML

---++ ObjectMethod pushTopicContext( $web, $topic )

Reconfigures the preferences so that general preference values appear
to come from $web.$topic. The topic context can be popped again using 
popTopicContext.

=cut

sub pushTopicContext {
    my ( $this, $web, $topic ) = @_;

    my $stack = $this->{main};
    my %internals;
    while ( my ( $k, $v ) = each %{ $this->{internals} } ) {
        $internals{$k} = $v;
    }
    push(
        @{ $this->{contexts} },
        { internals => \%internals, level => $stack->size() - 1 }
    );
    my @webPath = split( /[\/\.]+/, $web );
    my $subWeb = '';
    my $back;
    foreach (@webPath) {
        $subWeb .= '/' if $subWeb;
        $subWeb .= $_;
        $back = $this->_getBackend( $subWeb, $Foswiki::cfg{WebPrefsTopicName} );
        $stack->newLevel($back);
    }
    $back = $this->_getBackend( $web, $topic );
    $stack->newLevel($back);
    $stack->newLevel( Foswiki::Prefs::HASH->new() );

    while ( my ( $k, $v ) = each %{ $this->{internals} } ) {
        $stack->insert( 'Set', $k, $v );
    }

}

=begin TML

---+++ popTopicContext()

Returns the context to the state it was in before the
=pushTopicContext= was last called.

=cut

sub popTopicContext {
    my $this    = shift;
    my $stack   = $this->{main};
    my $context = pop( @{ $this->{contexts} } );
    my $level   = $context->{level};
    while ( my ( $k, $v ) = each %{ $context->{internals} } ) {
        $this->{internals}{$k} = $v;
    }
    $stack->restore($level);
    splice @{ $this->{prefix} }, $level + 1 if @{ $this->{prefix} } > $level;

    # Note: this used to get the web from (-3) - but that only gives the
    # last component of the web path, and fails if the web name is empty.
    my $toRef = $stack->backAtLevel(-2)->topicObject;
    return ( $toRef->web(), $toRef->topic() );
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
    my $stack  = $this->{main};
    $stack->newLevel( $back, $prefix );
    $this->{prefix}->[ $stack->size() - 1 ] = $prefix;
}

=begin TML

---++ ObjectMethod setUserPreferences( $wikiname )

Reads preferences from the given user topic and pushes them to the preferences
stack.

=cut

sub setUserPreferences {
    my ( $this, $wn ) = @_;
    my $back = $this->_getBackend( $Foswiki::cfg{UsersWebName}, $wn );
    $this->{main}->newLevel($back);
}

=begin TML

---++ ObjectMethod loadDefaultPreferences()

Add default preferences to this preferences stack.

=cut

sub loadDefaultPreferences {
    my $this = shift;
    my $back = $this->_getBackend( $Foswiki::cfg{SystemWebName},
        $Foswiki::cfg{SitePrefsTopicName} );
    $this->{main}->newLevel($back);
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
        $this->{main}->newLevel($back);
    }
}

=begin TML

---++ ObjectMethod setSessionPreferences( %values )

Set the preference values in the parameters in the SESSION stack.

=cut

sub setSessionPreferences {
    my ( $this, %values ) = @_;
    my $stack = $this->{main};
    my $num   = 0;
    while ( my ( $k, $v ) = each %values ) {
        next if $stack->finalized($k);
        $num += $stack->insert( 'Set', $k, $v );
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
    my $stack   = $this->{main};
    my $prevLev = $stack->backAtLevel(-2);
    if ( $prevLev && !$stack->finalizedBefore( $key, -2 ) ) {
        $value = $prevLev->getLocal($key);
    }
    if ( !defined $value && $stack->prefIsDefined($key) ) {
        my $defLevel = $stack->getDefinitionLevel($key);
        my $prefix   = $this->{prefix}->[$defLevel];
        $key =~ s/^\Q$prefix\E// if $prefix;
        $value = $stack->backAtLevel($defLevel)->get($key);
    }
    return $value;
}

=begin TML

---++ ObjectMethod stringify([$key]) -> $text

Generate TML-formatted information about the key (all keys if $key is undef)

=cut

sub stringify {
    my ( $this, $key ) = @_;

    my $stack = $this->{main};
    my @keys = defined $key ? ($key) : sort $stack->prefs;
    my @list;
    foreach my $k (@keys) {
        my $val = Foswiki::entityEncode( $this->getPreference($k) || '' );
        push( @list, '   * Set ' . "$k = \"$val\"" );
        next unless exists $stack->{'map'}{$k};
        my $defLevel = $stack->getDefinitionLevel($k);
        if ( $stack->backAtLevel($defLevel)->can('topicObject') ) {
            my $topicObject = $stack->backAtLevel($defLevel)->topicObject();
            push( @list,
                    "      * $k was "
                  . ( $stack->finalized($k) ? '*finalised*' : 'defined' )
                  . ' in <nop>'
                  . $topicObject->web() . '.'
                  . $topicObject->topic() );
        }
    }

    @keys =
      defined $key ? ($key) : ( sort $stack->backAtLevel(-2)->localPrefs );
    foreach my $k (@keys) {
        next
          unless defined $stack->backAtLevel(-2)->getLocal($k)
          && !$stack->finalizedBefore( $k, -2 );
        my $val =
          Foswiki::entityEncode( $stack->backAtLevel(-2)->getLocal($k) );
        push( @list, '   * Local ' . "$k = \"$val\"" );
    }

    return join( "\n", @list ) . "\n";
}

1;
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
