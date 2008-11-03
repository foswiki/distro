# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
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

=pod

---+ package TWiki::Plugins

This module defines the singleton object that handles Plugins
loading, initialization and execution.

This class uses Chain of Responsibility (GOF) pattern to dispatch
handler calls to registered plugins.

=cut

=pod

Note that as of version 1.026 of this module, TWiki internal
methods are _no longer available_ to plugins. Any calls to
TWiki internal methods must be replaced by calls via the
=$SESSION= object in this package, or via the Func package.
For example, the call:

=my $pref = TWiki::getPreferencesValue('URGH');=

should be replaced with

=my $pref = TWiki::Func::getPreferencesValue('URGH');=

and the call

=my $t = TWiki::writeWarning($message);=

should be replaced with

=my $pref = $TWiki::Plugins::SESSION->writeWarning($message);=

Methods in other modules such as Store must be accessed through
the relevant TWiki sub-object, for example

=TWiki::Store::saveTopic(...)=

should be replaced with

=$TWiki::Plugins::SESSION->{store}->saveTopic(...)=

Note that calling TWiki internal methods is very very bad practice,
and should be avoided wherever practical.

The developers of TWiki reserve the right to change internal
methods without warning, unless those methods are clearly
marked as PUBLIC. PUBLIC methods are part of the core specification
of a module and can be trusted.

=cut

package TWiki::Plugins;

use strict;
use Assert;

require TWiki::Plugin;

use vars qw ( $VERSION $SESSION $inited );

=pod

---++ PUBLIC constant $VERSION

This is the version number of the plugins package. Use it for checking
if you have a recent enough version.

---++ PUBLIC $SESSION

This is a reference to the TWiki session object. It can be used in
plugins to get at the methods of the TWiki kernel.

You are _highly_ recommended to only use the methods in the
[[TWikiFuncDotPm][Func]] interface, unless you have no other choice,
as kernel methods may change between TWiki releases.

=cut

$VERSION = '1.2';

$inited = 0;

my %onlyOnceHandlers = (
    registrationHandler           => 1,
    writeHeaderHandler            => 1,
    redirectCgiQueryHandler       => 1,
    renderFormFieldForEditHandler => 1,
    renderWikiWordHandler         => 1,
);

=pod

---++ ClassMethod new( $session )

Construct new singleton plugins collection object. The object is a
container for a list of plugins and the handlers registered by the plugins.
The plugins and the handlers are carefully ordered.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    unless ($inited) {
        TWiki::registerTagHandler( 'PLUGINDESCRIPTIONS',
            \&_handlePLUGINDESCRIPTIONS );
        TWiki::registerTagHandler( 'ACTIVATEDPLUGINS',
            \&_handleACTIVATEDPLUGINS );
        TWiki::registerTagHandler( 'FAILEDPLUGINS', \&_handleFAILEDPLUGINS );
        $inited = 1;
    }

    return $this;
}

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{registeredHandlers};
    foreach ( @{ $this->{plugins} } ) {
        $_->finish();
    }
    undef $this->{plugins};
    undef $this->{session};
}

=pod

---++ ObjectMethod load($allDisabled) -> $loginName

Find all active plugins, and invoke the early initialisation.
Has to be done _after_ prefs are read.

Returns the user returned by the last =initializeUserHandler= to be
called.

If allDisabled is set, no plugin handlers will be called.

=cut

sub load {
    my ( $this, $allDisabled ) = @_;

    my %lookup;

    my $session = $this->{session};
    my $query   = $session->{request};

    my @pluginList = ();
    my %already;

    unless ($allDisabled) {
        if ( $query && defined( $query->param('debugenableplugins') ) ) {
            @pluginList =
              split( /[,\s]+/, $query->param('debugenableplugins') );
        }
        else {
            if ( $TWiki::cfg{PluginsOrder} ) {
                foreach
                  my $plugin ( split( /[,\s]+/, $TWiki::cfg{PluginsOrder} ) )
                {

                    # Note this allows the same plugin to be listed
                    # multiple times! Thus their handlers can be called
                    # more than once. This is *desireable*.
                    if ( $TWiki::cfg{Plugins}{$plugin}{Enabled} ) {
                        push( @pluginList, $plugin );
                        $already{$plugin} = 1;
                    }
                }
            }
            foreach my $plugin ( sort keys %{ $TWiki::cfg{Plugins} } ) {
                if ( $TWiki::cfg{Plugins}{$plugin}{Enabled}
                    && !$already{$plugin} )
                {
                    push( @pluginList, $plugin );
                    $already{$plugin} = 1;
                }
            }
        }
    }

    my $user;           # the user login name
    my $userDefiner;    # the plugin that is defining the user
    foreach my $pn (@pluginList) {
        my $p;
        unless ( $p = $lookup{$pn} ) {
            $p =
              new TWiki::Plugin( $session, $pn,
                $TWiki::cfg{Plugins}{$pn}{Module} );
        }
        push @{ $this->{plugins} }, $p;
        my $anotherUser = $p->load();
        if ($anotherUser) {
            if ($userDefiner) {
                die 'Two plugins - '
                  . $userDefiner->{name} . ' and '
                  . $p->{name}
                  . ' are both trying to define the user login name.';
            }
            else {
                $userDefiner = $p;
                $user        = $anotherUser;
            }
        }

        # Report initialisation errors
        if ( $p->{errors} ) {
            $this->{session}->writeWarning( join( "\n", @{ $p->{errors} } ) );
        }
        $lookup{$pn} = $p;
    }

    return $user;
}

=pod

---++ ObjectMethod settings()

Push plugin settings onto preference stack

=cut

sub settings {
    my $this = shift;

    # Set the session for this call stack
    local $TWiki::Plugins::SESSION = $this->{session};

    foreach my $plugin ( @{ $this->{plugins} } ) {
        $plugin->registerSettings($this);
    }
}

=pod

---++ ObjectMethod enable()

Initialisation that is done after the user is known.

=cut

sub enable {
    my $this     = shift;
    my $prefs    = $this->{session}->{prefs};
    my $dissed   = $prefs->getPreferencesValue('DISABLEDPLUGINS') || '';
    my %disabled = map { $_ => 1 } split( /,\s*/, $dissed );

    # Set the session for this call stack
    local $TWiki::Plugins::SESSION = $this->{session};

    foreach my $plugin ( @{ $this->{plugins} } ) {
        if ( $disabled{ $plugin->{name} } ) {
            $plugin->{disabled} = 1;
            push(
                @{ $plugin->{errors} },
                $plugin->{name} . ' has been disabled'
            );
        }
        else {
            $plugin->registerHandlers($this);
        }

        # Report initialisation errors
        if ( $plugin->{errors} ) {
            $this->{session}
              ->writeWarning( join( "\n", @{ $plugin->{errors} } ) );
        }
    }
}

=pod

---++ ObjectMethod getPluginVersion() -> $number

Returns the $TWiki::Plugins::VERSION number if no parameter is specified,
else returns the version number of a named Plugin. If the Plugin cannot
be found or is not active, 0 is returned.

=cut

sub getPluginVersion {
    my ( $this, $thePlugin ) = @_;

    return $VERSION unless $thePlugin;

    foreach my $plugin ( @{ $this->{plugins} } ) {
        if ( $plugin->{name} eq $thePlugin ) {
            return $plugin->getVersion();
        }
    }
    return 0;
}

=pod

---++ ObjectMethod addListener( $command, $handler )

   * =$command= - name of the event
   * =$handler= - the handler object.

Add a listener to the end of the list of registered listeners for this event.
The listener must implement =invoke($command,...)=, which will be triggered
when the event is to be processed.

=cut

sub addListener {
    my ( $this, $c, $h ) = @_;

    push( @{ $this->{registeredHandlers}{$c} }, $h );
}

=begin twiki

---++ ObjectMethod dispatch( $handlerName, ...)
Dispatch the given handler, passing on ... in the parameter vector

=cut

sub dispatch {

    # must be shifted to clear parameter vector
    my $this        = shift;
    my $handlerName = shift;
    foreach my $plugin ( @{ $this->{registeredHandlers}{$handlerName} } ) {

        # Set the value of $SESSION for this call stack
        local $SESSION = $this->{session};

        # apply handler on the remaining list of args
        no strict 'refs';
        my $status = $plugin->invoke( $handlerName, @_ );
        use strict 'refs';
        if ( $status && $onlyOnceHandlers{$handlerName} ) {
            return $status;
        }
    }
    return undef;
}

=pod

---++ ObjectMethod haveHandlerFor( $handlerName ) -> $boolean

   * =$handlerName= - name of the handler e.g. preRenderingHandler
Return: true if at least one plugin has registered a handler of
this type.

=cut

sub haveHandlerFor {
    my ( $this, $handlerName ) = @_;

    return 0 unless defined( $this->{registeredHandlers}{$handlerName} );
    return scalar( @{ $this->{registeredHandlers}{$handlerName} } );
}

# %FAILEDPLUGINS reports reasons why plugins failed to load
# note this is invoked with the session as the first parameter
sub _handleFAILEDPLUGINS {
    my $this = shift->{plugins};

    my $text =
        CGI::start_table( { border => 1, class => 'twikiTable' } )
      . CGI::Tr( CGI::th('Plugin') . CGI::th('Errors') );

    foreach my $plugin ( @{ $this->{plugins} } ) {
        my $td;
        if ( $plugin->{errors} ) {
            $td = CGI::td(
                { class => 'twikiAlert' },
                "\n<verbatim>\n"
                  . join( "\n", @{ $plugin->{errors} } )
                  . "\n</verbatim>\n"
            );
        }
        else {
            $td = CGI::td('none');
        }
        $text .= CGI::Tr(
            { valign => 'top' },
            CGI::td(
                ' ' . $plugin->{installWeb} . '.' . $plugin->{name} . ' '
              )
              . $td
        );
    }

    $text .=
        CGI::end_table()
      . CGI::start_table( { border => 1, class => 'twikiTable' } )
      . CGI::Tr( CGI::th('Handler') . CGI::th('Plugins') );

    foreach my $handler (@TWiki::Plugin::registrableHandlers) {
        my $h = '';
        if ( defined( $this->{registeredHandlers}{$handler} ) ) {
            $h = join(
                CGI::br(),
                map { $_->{name} } @{ $this->{registeredHandlers}{$handler} }
            );
        }
        if ($h) {
            if ( defined( $TWiki::Plugin::deprecated{$handler} ) ) {
                $h .= CGI::br()
                  . CGI::span(
                    { class => 'twikiAlert' },
" __This handler is deprecated__ - please check for updated versions of the plugins that use it!"
                  );
            }
            $text .=
              CGI::Tr( { valign => 'top' }, CGI::td($handler) . CGI::td($h) );
        }
    }

    return
        $text
      . CGI::end_table() . "\n*"
      . scalar( @{ $this->{plugins} } )
      . " plugins*\n\n";
}

# note this is invoked with the session as the first parameter
sub _handlePLUGINDESCRIPTIONS {
    my $this = shift->{plugins};
    my $text = '';
    foreach my $plugin ( @{ $this->{plugins} } ) {
        $text .= CGI::li( $plugin->getDescription() . ' ' );
    }

    return CGI::ul($text);
}

# note this is invoked with the session as the first parameter
sub _handleACTIVATEDPLUGINS {
    my $this = shift->{plugins};
    my $text = '';
    foreach my $plugin ( @{ $this->{plugins} } ) {
        unless ( $plugin->{disabled} ) {
            $text .= "$plugin->{installWeb}.$plugin->{name}, ";
        }
    }
    $text =~ s/\,\s*$//o;
    return $text;
}

1;
