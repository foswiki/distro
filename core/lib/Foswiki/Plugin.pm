# See bottom of file for license and copyright information

# PRIVATE CLASS Foswiki::Plugin
#
# Reference information for a single plugin.
package Foswiki::Plugin;

use Try::Tiny;

use Foswiki::Plugins                ();
use Foswiki::AccessControlException ();
use Foswiki::OopsException          ();
use Foswiki::ValidationException    ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::AppObject);

use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our @registrableHandlers = (    # Foswiki::Plugins::VERSION:
    'afterAttachmentSaveHandler',       # 1.022 DEPRECATED
    'afterUploadHandler',               # 2.1
    'afterCommonTagsHandler',           # 1.024
    'afterEditHandler',                 # 1.010
    'afterRenameHandler',               # 1.110
    'afterSaveHandler',                 # 1.020
    'beforeAttachmentSaveHandler',      # 1.022 DEPRECATED
    'beforeCommonTagsHandler',          # 1.024
    'beforeEditHandler',                # 1.010
    'beforeMergeHandler',               # 1.200
    'beforeSaveHandler',                # 1.010
    'beforeUploadHandler',              # 2.1
    'commonTagsHandler',                # 1.000
    'completePageHandler',              # 1.100
    'earlyInitPlugin',                  # 1.020
    'endRenderingHandler',              # 1.000 DEPRECATED
    'finishPlugin',                     # 2.100
    'initPlugin',                       # 1.000
    'initializeUserHandler',            # 1.010
    'insidePREHandler',                 # 1.000 DEPRECATED
    'modifyHeaderHandler',              # 1.026
    'mergeHandler',                     # 1.026
    'outsidePREHandler',                # 1.000 DEPRECATED
    'postRenderingHandler',             # 1.026
    'preRenderingHandler',              # 1.026
    'redirectCgiQueryHandler',          # 1.010 DEPRECATED
    'registrationHandler',              # 1.010 DEPRECATED
    'renderFormFieldForEditHandler',    # ?
    'renderWikiWordHandler',            # 1.023
    'startRenderingHandler',            # 1.000 DEPRECATED
    'validateRegistrationHandler',      # 2.3
    'writeHeaderHandler',               # 1.010 DEPRECATED
);

# deprecated handlers
our %deprecated = (
    afterAttachmentSaveHandler  => 1,
    beforeAttachmentSaveHandler => 1,
    endRenderingHandler         => 1,
    insidePREHandler            => 1,
    outsidePREHandler           => 1,
    redirectCgiQueryHandler     => 1,
    registrationHandler         => 1,
    startRenderingHandler       => 1,
    writeHeaderHandler          => 1,
);

has name => (
    is       => 'ro',
    required => 1,
    isa      => sub {
        ASSERT( UNTAINTED( $_[0] ), "Name $_[0] is tainted!" ) if DEBUG;
    },
);
has module => ( is => 'rw', );
has errors => (
    is      => 'rw',
    default => sub { return []; },
);
has disabled => (
    is      => 'rw',
    default => 0,
);
has reason => (
    is      => 'rw',
    default => '',
);
has topicWeb => (
    is      => 'rw',
    clearer => 1,
    lazy    => 1,
    default => sub {
        my $this = shift;
        unless ( $this->no_topic ) {

            # Find the plugin topic, if required
            my $app = $this->app;

            foreach
              my $web ( split( /[, ]+/, $Foswiki::cfg{Plugins}{WebSearchPath} ),
                $app->request->web )
            {
                $web = Foswiki::Sandbox::untaintUnchecked($web);    # Item11953
                if ( $app->store->topicExists( $web, $this->name ) ) {
                    return $web;
                }
            }
        }

        # If there is no web (probably because NO_PREFS_IN_TOPIC is set) then
        # default to the system web name.
        return $Foswiki::cfg{SystemWebName};
    },
);
has no_topic    => ( is => 'rw', );
has description => ( is => 'rw', );

#our @_newParameters = qw( app name module );

=begin TML

---++ ClassMethod new( app => $app, name => $name[, module => $module] )

   * =$app= - Foswiki::App object
   * =$name= - name of the plugin e.g. MyPlugin
   * =$module= - name of implementing package; optional, used for tests.
     Normally =load= is used to discover the module from the config.

=cut

sub BUILD {
    my $this = shift;

    my $name = $this->name;

    my $p = $Foswiki::cfg{Plugins}{$name}{Module};

    unless ($p) {
        $p = "Foswiki::Plugins::$name";
        push(
            @{ $this->errors },
"$p has been guessed. '\$Foswiki::cfg{Plugins}{$name}{Module}' should be defined in LocalSite.cfg"
        ) if DEBUG;
    }

    {
        local $SIG{__DIE__};
        local $SIG{__WARN__};
        eval "use $p";
        if ($@) {
            my $errMessage =
                "$p could not be loaded.  Errors were:\n"
              . Foswiki::Exception::errorStr($@)
              . "\n----";
            push( @{ $this->errors }, $errMessage );
            Foswiki::Func::writeDebug($errMessage);
            $this->disabled(1);
            $this->reason('no_load_plugin');
        }
        else {
            $this->module($p);
        }
    }
    my $fn = "${p}::preload";
    if ( !$this->disabled && defined &$fn ) {

        # A preload handler can simply die if it doesn't like what it sees
        no strict 'refs';
        &$fn( $this->app );
        use strict 'refs';
    }
}

# Load and verify a plugin, invoking any early registration
# handlers. Return the user resulting from the user handler call.
sub load {
    my ($this) = @_;

    return if $this->disabled;

    my $noTopic = eval '$' . $this->module . '::NO_PREFS_IN_TOPIC';
    $this->no_topic($noTopic);
    $this->clear_topicWeb;    # not known yet

    unless ($noTopic) {
        if ( !$this->topicWeb() ) {

            # not found
            push(
                @{ $this->errors },
                'Plugins: could not fully register '
                  . $this->name
                  . ', no plugin topic'
            );
            $noTopic = 1;
        }
    }

    # Get the description from the code, if present. if it's not there, it'll
    # be loaded as a preference from the plugin topic later
    $this->description( eval '$' . $this->module . '::SHORTDESCRIPTION' );

    # Set the app for this call stack
    #local $Foswiki::Plugins::SESSION = $this->session;
    #ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    my $sub = $this->module . "::initPlugin";
    if ( !defined(&$sub) ) {
        push( @{ $this->errors }, $sub . ' is not defined' );
        $this->disabled(1);
        $this->reason('no_initPlugin');
        return;
    }

    $sub = $this->module . '::earlyInitPlugin';
    if ( defined(&$sub) ) {
        no strict 'refs';
        my $error = &$sub();
        use strict 'refs';
        if ($error) {
            push( @{ $this->errors }, $sub . ' failed: ' . $error );
            $this->disabled(1);
            $this->reason('no_earlyInitPlugin');
            return;
        }
    }

    my $user;
    $sub = $this->module . '::initializeUserHandler';
    if ( defined(&$sub) ) {
        no strict 'refs';
        $user = &$sub(
            $this->app->remoteUser,
            $this->app->request->url,
            $this->app->request->pathInfo
        );
        use strict 'refs';
    }

#print STDERR "Compile ", $this->module, ": ".timestr(timediff(new Benchmark, $begin))."\n";

    return $user;
}

# register plugin settings
sub registerSettings {
    my ( $this, $plugins ) = @_;

    return if $this->disabled;

    my $prefs = $this->app->prefs;
    if ( !$this->no_topic ) {
        $prefs->setPluginPreferences( $this->topicWeb, $this->name );
    }
}

# invoke plugin initialisation and register handlers.
sub registerHandlers {
    my ( $this, $plugins ) = @_;

    return if $this->disabled;

    my $p         = $this->module;
    my $sub       = $p . "::initPlugin";
    my $users     = $Foswiki::app->users;
    my $status    = 0;
    my $exception = '';
    try {
        no strict 'refs';
        $status = &$sub(
            $Foswiki::app->request->topic,
            $Foswiki::app->request->web,
            $users->getLoginName( $Foswiki::app->user ),
            $this->topicWeb()
        );
        use strict 'refs';
    }
    catch {
        if (   $_->isa('Foswiki::AccessControlException')
            || $_->isa('Foswiki::OopsException')
            || $_->isa('Foswiki::ValidationException')
            || !ref($_)
            || $Foswiki::inUnitTestMode )
        {
            # SMELL Not sure how did it work with with Error.pm and die of
            # errors previously.
            Foswiki::Exception->rethrow($_);
        }
        else {
            # SMELL Shouldn't this conditional branch be executed only for
            # exceptions coming from a plugin code?
            $exception = $_->text . ' ' . $_->stacktrace;
        }

    };

    unless ($status) {
        if ( !$exception ) {
            $exception = <<MESSAGE;
$sub did not return true.
Check your Foswiki warning and error logs for more information.
MESSAGE
        }
        push( @{ $this->errors }, $exception );
        $this->disabled(1);
        $this->reason('plugin_ret_0');
        return;
    }

    my $compat = eval '\%' . $p . '::FoswikiCompatibility';
    foreach my $h (@registrableHandlers) {
        my $sub = $p . '::' . $h;
        if ( defined(&$sub) ) {
            if (   $deprecated{$h}
                && $compat
                && $compat->{$h}
                && $compat->{$h} <= $Foswiki::Plugins::VERSION )
            {

                # Compatibility handler not required in this version
                next;
            }
            $plugins->addListener( $h, $this );
        }
    }
    $this->app->enterContext( $this->name . 'Enabled' );
}

# Invoke a handler
sub invoke {
    my $this        = shift;    # remove from parameter vector
    my $handlerName = shift;
    my $handler = $this->module . '::' . $handlerName;
    no strict 'refs';
    return &$handler(@_);
    use strict 'refs';
}

# Get the VERSION number of the specified plugin.
# SMELL: may die if the plugin doesn't compile
sub getVersion {
    my $this = shift;

    no strict 'refs';
    return ${ $this->module . '::VERSION' } || '';
    use strict 'refs';
}

# Get the RELEASE of the specified plugin.
# SMELL: may die if the plugin doesn't compile
sub getRelease {
    my $this = shift;

    no strict 'refs';
    return ${ $this->module . '::RELEASE' } || '';
    use strict 'refs';
}

# Get the description string for the given plugin
sub getDescription {
    my $this = shift;

    unless ( defined $this->description ) {
        my $pref  = uc( $this->name ) . '_SHORTDESCRIPTION';
        my $prefs = $this->app->prefs;
        $this->description( $prefs->getPreference($pref) || '' );
    }
    if ( $this->disabled ) {
        my $reason = '';
        if ( $this->reason ) {
            $reason = $this->app->inlineAlert( 'alerts', $this->reason );
        }
        return
            ' '
          . $this->name . ': '
          . $this->app->inlineAlert( 'alerts', 'plugin_disabled' )
          . $reason;
    }

    my $release = $this->getRelease();
    my $version = $this->getVersion();
    $version =~ s/\$Rev: (\d+) \$/$1/g;
    $version = $release . ', ' . $version if $release;

    my $web = $this->topicWeb();
    my $result = ' ' . ( $web ? "$web." : '!' ) . $this->name . ' ';
    $result .= CGI::span( { class => 'foswikiGrayText foswikiSmall' },
        '(' . $version . ')' );
    $result .= ': ' . $this->description;
    return $result;
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
Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
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
