# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
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

# PRIVATE CLASS Foswiki::Plugin
#
# Reference information for a single plugin.
package Foswiki::Plugin;

use strict;
use Assert;

require Foswiki::Plugins;

use vars qw( @registrableHandlers %deprecated );

@registrableHandlers = (    # Foswiki::Plugins::VERSION:
    'afterAttachmentSaveHandler',       # 1.022
    'afterCommonTagsHandler',           # 1.024
    'afterEditHandler',                 # 1.010
    'afterRenameHandler',               # 1.110
    'afterSaveHandler',                 # 1.020
    'beforeAttachmentSaveHandler',      # 1.022
    'beforeCommonTagsHandler',          # 1.024
    'beforeEditHandler',                # 1.010
    'beforeMergeHandler',               # 1.200
    'beforeSaveHandler',                # 1.010
    'commonTagsHandler',                # 1.000
    'completePageHandler',              # 1.100
    'earlyInitPlugin',                  # 1.020
    'endRenderingHandler',              # 1.000 DEPRECATED
    'initPlugin',                       # 1.000
    'initializeUserHandler',            # 1.010
    'insidePREHandler',                 # 1.000 DEPRECATED
    'modifyHeaderHandler',              # 1.026
    'mergeHandler',                     # 1.026
    'outsidePREHandler',                # 1.000 DEPRECATED
    'postRenderingHandler',             # 1.026
    'preRenderingHandler',              # 1.026
    'redirectCgiQueryHandler',          # 1.010
    'registrationHandler',              # 1.010
    'renderFormFieldForEditHandler',    # ?
    'renderWikiWordHandler',            # 1.023
    'startRenderingHandler',            # 1.000 DEPRECATED
    'writeHeaderHandler',               # 1.010 DEPRECATED
);

# deprecated handlers
%deprecated = (
    startRenderingHandler => 1,
    outsidePREHandler     => 1,
    insidePREHandler      => 1,
    endRenderingHandler   => 1,
    writeHeaderHandler    => 1,
);

=pod

---++ ClassMethod new( $session, $name )

   * =$session= - Foswiki object
   * =$name= - name of the plugin e.g. MyPlugin

=cut

sub new {
    my ( $class, $session, $name ) = @_;
    my $this = bless( { session => $session }, $class );

    require Foswiki::Sandbox;
    $name = Foswiki::Sandbox::untaintUnchecked($name);
    $this->{name}   = $name   || '';

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

    undef $this->{name};
    undef $this->{installWeb};
    undef $this->{module};
    undef $this->{errors};
    undef $this->{disabled};
    undef $this->{no_topic};
    undef $this->{description};
    undef $this->{session};
}

# Load and verify a plugin, invoking any early registration
# handlers. Return the user resulting from the user handler call.
sub load {
    my ($this) = @_;
    my $p = $Foswiki::cfg{Plugins}{$this->{name}}{Module};
    $this->{installWeb} = $Foswiki::cfg{SystemWebName};

    if (defined $p) {
        eval "use $p";
        if ($@) {
            push(@{ $this->{errors} },
                 "$p could not be loaded.  Errors were:\n$@\n----");
            $this->{disabled} = 1;
            return undef;
        } else {
            $this->{module} = $p;
        }
    } else {
        push(@{ $this->{errors} },
             "$this->{name} could not be loaded. No \$Foswiki::cfg{Plugins}{$this->{name}}{Module} is not defined - re-run configure\n---");
        $this->{disabled} = 1;
        return undef;
    }

    my $noTopic = eval '$' . $p . '::NO_PREFS_IN_TOPIC';
    $this->{no_topic} = $noTopic;
    $this->{installWeb} = undef; # not known yet

    # Find the plugin topic, if required
    if ($noTopic) {
        $this->{installWeb} = $Foswiki::cfg{SystemWebName};
    } else  {
        my $store = $this->{session}->{store};

        foreach my $web (split(/[, ]+/,
                               $Foswiki::cfg{Plugins}{WebSearchPath}),
                         $this->{session}->{webName}) {
            if ( $store->topicExists( $web, $this->{name} ) ) {
                $this->{installWeb} = $web;
                last;
            }
        }
        if (!$this->{installWeb}) {
            # not found
            push(
                @{ $this->{errors} },
                'Plugins: could not fully register '
                  . $this->{name}
                  . ', no plugin topic'
            );
            $noTopic = 1;
            $this->{installWeb} = $Foswiki::cfg{SystemWebName};
        }
    }

    # Get the description from the code, if present. if it's not there, it'll
    # be loaded as a preference from the plugin topic later
    $this->{description} = eval '$' . $p . '::SHORTDESCRIPTION';

    # Set the session for this call stack
    local $Foswiki::Plugins::SESSION = $this->{session};

    my $sub = $p . '::earlyInitPlugin';
    if ( defined(&$sub) ) {
        no strict 'refs';
        my $error = &$sub();
        if ($error) {
            push( @{ $this->{errors} }, $sub . ' failed: ' . $error );
            $this->{disabled} = 1;
            return undef;
        }
        use strict 'refs';
    }

    my $user;
    $sub = $p . '::initializeUserHandler';
    if ( defined(&$sub) ) {
        no strict 'refs';
        $user = &$sub(
            $this->{session}->{remoteUser},
            $this->{session}->{request}->url(),
            $this->{session}->{request}->path_info()
        );
        use strict 'refs';
    }

    #print STDERR "Compile $p: ".timestr(timediff(new Benchmark, $begin))."\n";

    return $user;
}

# register plugin settings
sub registerSettings {
    my ( $this, $plugins ) = @_;

    return if $this->{disabled};

    my $sub = $this->{module} . "::initPlugin";
    if ( !defined(&$sub) ) {
        push( @{ $this->{errors} }, $sub . ' is not defined' );
        $this->{disabled} = 1;
        return;
    }

    my $prefs = $this->{session}->{prefs};
    if ( !$this->{no_topic} ) {
        $prefs->pushPreferences( $this->{installWeb}, $this->{name}, 'PLUGIN',
            uc( $this->{name} ) . '_' );
    }
}

# invoke plugin initialisation and register handlers.
sub registerHandlers {
    my ( $this, $plugins ) = @_;

    return if $this->{disabled};

    my $p     = $this->{module};
    my $sub   = $p . "::initPlugin";
    my $users = $Foswiki::Plugins::SESSION->{users};
    no strict 'refs';
    my $status = &$sub(
        $Foswiki::Plugins::SESSION->{topicName},
        $Foswiki::Plugins::SESSION->{webName},
        $users->getLoginName( $Foswiki::Plugins::SESSION->{user} ),
        $this->{installWeb}
    );
    use strict 'refs';

    unless ($status) {
        push(
            @{ $this->{errors} },
            $sub . ' did not return true (' . $status . ')'
        );
        $this->{disabled} = 1;
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
    $this->{session}->enterContext( $this->{name} . 'Enabled' );
}

# Invoke a handler
sub invoke {
    my $this        = shift;    # remove from parameter vector
    my $handlerName = shift;
    my $handler = $this->{module} . '::' . $handlerName;
    no strict 'refs';
    return &$handler(@_);
    use strict 'refs';
}

# Get the VERSION number of the specified plugin.
# SMELL: may die if the plugin doesn't compile
sub getVersion {
    my $this = shift;

    no strict 'refs';
    return ${ $this->{module} . '::VERSION' } || '';
    use strict 'refs';
}

# Get the RELEASE of the specified plugin.
# SMELL: may die if the plugin doesn't compile
sub getRelease {
    my $this = shift;

    no strict 'refs';
    return ${ $this->{module} . '::RELEASE' } || '';
    use strict 'refs';
}

# Get the description string for the given plugin
sub getDescription {
    my $this = shift;

    unless ( defined $this->{description} ) {
        my $pref  = uc( $this->{name} ) . '_SHORTDESCRIPTION';
        my $prefs = $this->{session}->{prefs};
        $this->{description} = $prefs->getPreferencesValue($pref) || '';
    }
    if ( $this->{disabled} ) {
        return ' !' . $this->{name} . ': (disabled)';
    }

    my $release = $this->getRelease();
    my $version = $this->getVersion();
    $version =~ s/\$Rev: (\d+) \$/$1/g;
    $version = $release . ', ' . $version if $release;

    my $result = ' ' . $this->{installWeb} . '.' . $this->{name} . ' ';
    $result .=
      CGI::span( { class => 'twikiGrayText twikiSmall' },
        '(' . $version . ')' );
    $result .= ': ' . $this->{description};
    return $result;
}

1;
