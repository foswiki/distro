# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Plugins

This module defines the singleton object that handles Plugins
loading, initialization and execution.

This class uses Chain of Responsibility (GOF) pattern to dispatch
handler calls to registered plugins.

=cut

package Foswiki::Plugins;

use strict;
use warnings;
use Assert;

use Foswiki::Plugin ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ PUBLIC constant $VERSION

This is the version number of the plugins package. Use it for checking
if you have a recent enough version.

=cut

use version 0.77; our $VERSION = version->parse("2.4");

our $inited = 0;

my %onlyOnceHandlers = (
    registrationHandler           => 1,
    writeHeaderHandler            => 1,
    redirectCgiQueryHandler       => 1,
    renderFormFieldForEditHandler => 1,
    renderWikiWordHandler         => 1,
);

=begin TML

---++ PUBLIC $SESSION

This is a reference to the Foswiki session object. It can be used in
plugins to get at the methods of the Foswiki kernel.

You are _highly_ recommended to only use the methods in the
=Foswiki::Func= interface, unless you have no other choice,
as kernel methods may change between Foswiki releases.

=cut

our $SESSION;

=begin TML

---++ ClassMethod new( $session )

Construct new singleton plugins collection object. The object is a
container for a list of plugins and the handlers registered by the plugins.
The plugins and the handlers are carefully ordered.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    # Load the plugins code and invoke preload handlers
    $this->preload();

    unless ($inited) {
        Foswiki::registerTagHandler( 'PLUGINDESCRIPTIONS',
            \&_handlePLUGINDESCRIPTIONS );
        Foswiki::registerTagHandler( 'ACTIVATEDPLUGINS',
            \&_handleACTIVATEDPLUGINS );
        Foswiki::registerTagHandler( 'FAILEDPLUGINS', \&_handleFAILEDPLUGINS );
        Foswiki::registerTagHandler( 'RESTHANDLERS',  \&_handleRESTHANDLERS );
        $inited = 1;
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

    $this->dispatch('finishPlugin');

    undef $this->{registeredHandlers};
    foreach ( @{ $this->{plugins} } ) {
        $_->finish();
    }
    undef $this->{plugins};
    undef $this->{session};
}

=begin TML

---++ ObjectMethod preload() -> $loginName

Find all active plugins, load the code and and invoke the preload handler

=cut

sub preload {
    my ($this) = @_;
    my %lookup;
    our @pluginList = ();

    my $session = $this->{session};
    my $query   = $session->{request};

    my %already;
    unless ( $Foswiki::cfg{DisableAllPlugins} ) {

        # debugenableplugins only supported in DEBUG and unit test modes
        if (   $query
            && defined $query->param('debugenableplugins')
            && ( DEBUG || $query->isa('Unit::Request') ) )
        {
            foreach
              my $pn ( split( /[,\s]+/, $query->param('debugenableplugins') ) )
            {
                push(
                    @pluginList,
                    Foswiki::Sandbox::untaint(
                        $pn,
                        sub {
                            my $pn = shift;
                            throw Error::Simple('Bad debugenableplugins')
                              unless $pn =~ m/^[a-zA-Z0-9_]+$/;
                            return $pn;
                        }
                    )
                );
            }
        }
        else {
            if ( $Foswiki::cfg{PluginsOrder} ) {
                foreach
                  my $plugin ( split( /[,\s]+/, $Foswiki::cfg{PluginsOrder} ) )
                {

                    # Note this allows the same plugin to be listed
                    # multiple times! Thus their handlers can be called
                    # more than once. This is *desireable*.
                    if ( $Foswiki::cfg{Plugins}{$plugin}{Enabled} ) {
                        $plugin = Foswiki::Sandbox::untaintUnchecked($plugin)
                          ;    # Item 11953
                        push( @pluginList, $plugin );
                        $already{$plugin} = 1;
                    }
                }
            }
            foreach my $plugin ( sort keys %{ $Foswiki::cfg{Plugins} } ) {
                next unless ref( $Foswiki::cfg{Plugins}{$plugin} ) eq 'HASH';
                if ( $Foswiki::cfg{Plugins}{$plugin}{Enabled}
                    && !$already{$plugin} )
                {
                    push( @pluginList, $plugin );
                    $already{$plugin} = 1;
                }
            }
        }
    }

    foreach my $pn (@pluginList) {
        my $p;
        unless ( $p = $lookup{$pn} ) {

            # The 'new' will call the preload handler
            $p = new Foswiki::Plugin( $session, $pn );
        }
        push @{ $this->{plugins} }, $p;
        $lookup{$pn} = $p;
    }
}

=begin TML

---++ ObjectMethod load($allDisabled) -> $loginName

Find all active plugins, and invoke the early initialisation.
Has to be done _after_ prefs are read.

Returns the user returned by the last =initializeUserHandler= to be
called.

If allDisabled is set, no plugin handlers will be called.

=cut

sub load {
    my ($this) = @_;

    my $session = $this->{session};

    # Uncomment this to monitor plugin load times
    #Monitor::MARK('About to initPlugins');

    my $user;           # the user login name
    my $userDefiner;    # the plugin that is defining the user
    foreach my $p ( @{ $this->{plugins} } ) {
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
        if ( $p->{errors} && @{ $p->{errors} } ) {
            $this->{session}
              ->logger->log( 'error', join( "\n", @{ $p->{errors} } ) );
        }

        # Uncomment this to monitor plugin load times
        #Monitor::MARK($pn);
    }

    return $user;
}

=begin TML

---++ ObjectMethod settings()

Push plugin settings onto preference stack

=cut

sub settings {
    my $this = shift;

    # Set the session for this call stack
    local $Foswiki::Plugins::SESSION = $this->{session};
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    foreach my $plugin ( @{ $this->{plugins} } ) {
        $plugin->registerSettings($this);
    }
}

=begin TML

---++ ObjectMethod enable()

Initialisation that is done after the user is known.

=cut

sub enable {
    my $this     = shift;
    my $prefs    = $this->{session}->{prefs};
    my $dissed   = $prefs->getPreference('DISABLEDPLUGINS') || '';
    my %disabled = map { s/^\s+//; s/\s+$//; $_ => 1 } split( /,/, $dissed );

    # Set the session for this call stack
    local $Foswiki::Plugins::SESSION = $this->{session};
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    foreach my $plugin ( @{ $this->{plugins} } ) {
        if ( $disabled{ $plugin->{name} } ) {
            $plugin->{disabled} = 1;
            $plugin->{reason} =
              $this->{session}
              ->i18n->maketext('See the DISABLEDPLUGINS preference setting.');
            push(
                @{ $plugin->{errors} },
                $plugin->{name} . ' has been disabled'
            ) if DEBUG;
        }
        else {
            $plugin->registerHandlers($this);
        }

        # Report initialisation errors
        if ( $plugin->{errors} && @{ $plugin->{errors} } ) {
            $this->{session}
              ->logger->log( 'warning', join( "\n", @{ $plugin->{errors} } ) );
        }
    }
}

=begin TML

---++ ObjectMethod getPluginVersion() -> $number

Returns the $Foswiki::Plugins::VERSION number if no parameter is specified,
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

=begin TML

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

=begin TML

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
        ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

        # apply handler on the remaining list of args
        no strict 'refs';
        my $status = $plugin->invoke( $handlerName, @_ );
        use strict 'refs';
        if ( $status && $onlyOnceHandlers{$handlerName} ) {
            return $status;
        }
    }
    return;
}

=begin TML

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

# %RESTHANDLERS% reports the registred rest handlers and a bit of information
# about them
#
sub _handleRESTHANDLERS {
    my $this = shift->{plugins};

    return
'%MAKETEXT{"The details about REST Handlers are only available to users with Admin authority."}%'
      unless ( $SESSION->{users}->isAdmin( $SESSION->{user} ) );

    require Foswiki::UI::Rest;
    my $restHandlers = Foswiki::UI::Rest::getRegisteredHandlers();
    my $out          = <<DONE
| *Extension* | *REST Verb* | *HTTP<br />Method* | *Validation* | *Requires<br />Authentication* | *Description* |
DONE
      ;    #Collect output for display

    foreach my $handler ( sort keys %$restHandlers ) {
        $out .=
          "| [[$Foswiki::cfg{SystemWebName}.$handler][$handler]] | ||||||\n";
        foreach my $verb ( keys %{ $restHandlers->{$handler} } ) {
            my $method =
              ( defined $restHandlers->{$handler}{$verb}{http_allow} )
              ? $restHandlers->{$handler}{$verb}{http_allow}
              : 'undef';
            my $authenticate =
              ( defined $restHandlers->{$handler}{$verb}{authenticate} )
              ? $restHandlers->{$handler}{$verb}{authenticate}
              : 'undef';
            my $validate =
              ( defined $restHandlers->{$handler}{$verb}{validate} )
              ? $restHandlers->{$handler}{$verb}{validate}
              : 'undef';
            $out .=
                "| | $verb | $method | $validate | $authenticate | "
              . ( $restHandlers->{$handler}{$verb}{description} || '' )
              . " |\n";

        }
    }

    return $out;
}

# %FAILEDPLUGINS reports reasons why plugins failed to load
# note this is invoked with the session as the first parameter
sub _handleFAILEDPLUGINS {
    my $this = shift->{plugins};

    my $text = CGI::start_table(
        {
            border  => 1,
            class   => 'foswikiTable',
            summary => $this->{session}->i18n->maketext("Failed plugins")
        }
    ) . CGI::Tr( {}, CGI::th( {}, 'Plugin' ) . CGI::th( {}, 'Errors' ) );

    foreach my $plugin ( @{ $this->{plugins} } ) {
        my $td;
        if ( $plugin->{errors} && @{ $plugin->{errors} } ) {
            $td = CGI::td(
                { class => 'foswikiAlert' },
                "\n<verbatim>\n"
                  . join( "\n", @{ $plugin->{errors} } )
                  . "\n</verbatim>\n"
            );
        }
        else {
            $td = CGI::td( {}, 'none' );
        }
        my $web     = $plugin->topicWeb();
        my $modname = '';
        if ( $SESSION->{users}->isAdmin( $SESSION->{user} ) ) {
            if ( $Foswiki::cfg{Plugins}{ $plugin->{name} }{Module} ) {
                $modname =
                  $Foswiki::cfg{Plugins}{ $plugin->{name} }{Module} . ' ';
            }
            else {
                $modname = "Foswiki::Plugins::$plugin->{name} _(guessed)_ ";
            }
        }

        $text .= CGI::Tr(
            { valign => 'top' },
            CGI::td( {},
                    ' '
                  . ( $web ? "$web." : '!' )
                  . $plugin->{name} . ' '
                  . CGI::br()
                  . $modname )
              . $td
        );
    }

    $text .= CGI::end_table()
      . CGI::start_table(
        {
            border  => 1,
            class   => 'foswikiTable',
            summary => $this->{session}->i18n->maketext("Plugin handlers")
        }
      ) . CGI::Tr( {}, CGI::th( {}, 'Handler' ) . CGI::th( {}, 'Plugins' ) );

    foreach my $handler (@Foswiki::Plugin::registrableHandlers) {
        my $h = '';
        if ( defined( $this->{registeredHandlers}{$handler} ) ) {
            $h = join(
                CGI::br(),
                map { $_->{name} } @{ $this->{registeredHandlers}{$handler} }
            );
        }
        if ($h) {
            if ( defined( $Foswiki::Plugin::deprecated{$handler} ) ) {
                $h .= CGI::br()
                  . CGI::span(
                    { class => 'foswikiAlert' },
" __This handler is deprecated__ - please check for updated versions of the plugins that use it!"
                  );
            }
            $text .= CGI::Tr( { valign => 'top' },
                CGI::td( {}, $handler ) . CGI::td( {}, $h ) );
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
        $text .= CGI::li( {}, $plugin->getDescription() . ' ' );
    }

    return CGI::ul( {}, $text );
}

# note this is invoked with the session as the first parameter
sub _handleACTIVATEDPLUGINS {
    my $this = shift->{plugins};
    my $text = '';
    foreach my $plugin ( @{ $this->{plugins} } ) {
        unless ( $plugin->{disabled} ) {
            my $web = $plugin->topicWeb();
            $text .= ( $web ? "$web." : '!' ) . "$plugin->{name}, ";
        }
    }
    $text =~ s/\,\s*$//;
    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
