# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
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

# PRIVATE CLASS TWiki::Plugin
#
# Reference information for a single plugin.
package TWiki::Plugin;

use strict;
use Assert;

require TWiki::Plugins;

use vars qw( @registrableHandlers %deprecated );

@registrableHandlers =
  (                                # TWiki::Plugins::VERSION:
   'afterAttachmentSaveHandler',   # 1.022
   'afterCommonTagsHandler',       # 1.024
   'afterEditHandler',             # 1.010
   'afterRenameHandler',           # 1.110
   'afterSaveHandler',             # 1.020
   'beforeAttachmentSaveHandler',  # 1.022
   'beforeCommonTagsHandler',      # 1.024
   'beforeEditHandler',            # 1.010
   'beforeMergeHandler',           # 1.200
   'beforeSaveHandler',            # 1.010
   'commonTagsHandler',            # 1.000
   'completePageHandler',          # 1.100
   'earlyInitPlugin',              # 1.020
   'endRenderingHandler',          # 1.000 DEPRECATED
   'initPlugin',                   # 1.000
   'initializeUserHandler',        # 1.010
   'insidePREHandler',             # 1.000 DEPRECATED
   'modifyHeaderHandler',          # 1.026
   'mergeHandler',                 # 1.026
   'outsidePREHandler',            # 1.000 DEPRECATED
   'postRenderingHandler',         # 1.026
   'preRenderingHandler',          # 1.026
   'redirectCgiQueryHandler',      # 1.010
   'registrationHandler',          # 1.010
   'renderFormFieldForEditHandler',# ?
   'renderWikiWordHandler',        # 1.023
   'startRenderingHandler',        # 1.000 DEPRECATED
   'writeHeaderHandler',           # 1.010 DEPRECATED
  );

# deprecated handlers
%deprecated =
  (
   startRenderingHandler => 1,
   outsidePREHandler => 1,
   insidePREHandler => 1,
   endRenderingHandler => 1,
   writeHeaderHandler => 1,
  );

=pod

---++ ClassMethod new( $session, $name, $module )

   * =$session= - TWiki object
   * =$name= - name of the plugin e.g. MyPlugin
   * =$module= - (options) name of the plugin class. Default is TWiki::Plugins::$name

=cut

sub new {
    my ( $class, $session, $name, $module ) = @_;
    my $this = bless( { session => $session }, $class );
    require TWiki::Sandbox;
    $name = TWiki::Sandbox::untaintUnchecked( $name );
    $this->{name} = $name || '';
    $this->{module} = $module || 'TWiki::Plugins::'.$name;

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
    my ( $this ) = @_;

    # look for the plugin installation web (needed for attached files)
    # in the order:
    #   1 fully specified web.plugin
    #   2 TWiki.plugin
    #   3 Plugins.plugin
    #   4 thisweb.plugin

    my $p = $this->{module};

    $this->{installWeb} = $TWiki::cfg{SystemWebName};

    #use Benchmark qw(:all :hireswallclock);
    #my $begin = new Benchmark;
    eval "use $p;";
    if ($@) {
        push( @{$this->{errors}}, $p.
              ' could not be loaded.  Errors were: '."\n$@\n".'----' );
        $this->{disabled} = 1;
        return undef;
    }

    my $noTopic = eval '$'.$p.'::NO_PREFS_IN_TOPIC';
    $this->{no_topic} = $noTopic;

    unless ($noTopic) {
        my $store = $this->{session}->{store};
        if ( $store->topicExists(
            $TWiki::cfg{SystemWebName}, $this->{name} ) ) {
            # found plugin in TWiki web
        } elsif ( $store->topicExists( 'Plugins', $this->{name} ) ) {
            # found plugin in Plugins web (compatibility, deprecated)
            $this->{installWeb} = 'Plugins';
        } elsif ( $store->topicExists( $this->{session}->{webName},
                                       $this->{name} ) ) {
            # found plugin in current web
            $this->{installWeb} = $this->{session}->{webName};
        } else {
            # not found
            push( @{$this->{errors}}, 'Plugins: could not fully register '.
                    $this->{name}.', no plugin topic' );
            $noTopic = 1;
        }
    }

    # Get the description from the code, if present. if it's not there, it'll
    # be loaded as a preference from the plugin topic later
    $this->{description} = eval '$'.$p.'::SHORTDESCRIPTION';

    # Set the session for this call stack
    local $TWiki::Plugins::SESSION = $this->{session};

    my $sub = $p . '::earlyInitPlugin';
    if( defined( &$sub ) ) {
        no strict 'refs';
        my $error = &$sub();
        if( $error ) {
            push( @{$this->{errors}}, $sub.' failed: '.$error );
            $this->{disabled} = 1;
            return undef;
        }
        use strict 'refs';
    }

    my $user;
    $sub = $p. '::initializeUserHandler';
    if( defined( &$sub ) ) {
        no strict 'refs';
        $user = &$sub( $this->{session}->{remoteUser},
                       $this->{session}->{request}->url(),
                       $this->{session}->{request}->path_info());
        use strict 'refs';
    }
    #print STDERR "Compile $p: ".timestr(timediff(new Benchmark, $begin))."\n";

    return $user;
}

# register plugin settings
sub registerSettings {
    my ( $this, $plugins ) = @_;

    return if $this->{disabled};

    my $p = $this->{module};
    my $sub = $p . "::initPlugin";
    if( ! defined( &$sub ) ) {
        push( @{$this->{errors}}, $sub.' is not defined');
        $this->{disabled} = 1;
        return;
    }

    my $prefs = $this->{session}->{prefs};
    if( !$this->{no_topic} ) {
        $prefs->pushPreferences( $this->{installWeb}, $this->{name}, 'PLUGIN',
                                 uc( $this->{name} ) . '_');
    }
}

# invoke plugin initialisation and register handlers.
sub registerHandlers {
    my ( $this, $plugins ) = @_;

    return if $this->{disabled};

    my $p = $this->{module};
    my $sub = $p . "::initPlugin";
    my $users = $TWiki::Plugins::SESSION->{users};
    no strict 'refs';
    my $status = &$sub(
        $TWiki::Plugins::SESSION->{topicName},
        $TWiki::Plugins::SESSION->{webName},
        $users->getLoginName($TWiki::Plugins::SESSION->{user}),
        $this->{installWeb} );
    use strict 'refs';

    unless( $status ) {
        push( @{$this->{errors}}, $sub.' did not return true ('.$status.')' );
        $this->{disabled} = 1;
        return;
    }

    my $compat = eval '\%'.$p.'::TWikiCompatibility';
    foreach my $h ( @registrableHandlers ) {
        my $sub = $p.'::'.$h;
        if( defined( &$sub )) {
            if( $deprecated{$h} && $compat && $compat->{$h} &&
                  $compat->{$h} <= $TWiki::Plugins::VERSION ) {
                # Compatibility handler not required in this version
                next;
            }
            $plugins->addListener( $h, $this );
        }
    }
    $this->{session}->enterContext( $this->{name}.'Enabled' );
}

# Invoke a handler
sub invoke {
    my $this = shift; # remove from parameter vector
    my $handlerName = shift;
    my $handler = $this->{module}.'::'.$handlerName;
    no strict 'refs';
    return &$handler( @_ );;
    use strict 'refs';
}

# Get the VERSION number of the specified plugin.
# SMELL: may die if the plugin doesn't compile
sub getVersion {
    my $this = shift;

    no strict 'refs';
    return ${$this->{module}.'::VERSION'} || '';
    use strict 'refs';
}

# Get the RELEASE of the specified plugin.
# SMELL: may die if the plugin doesn't compile
sub getRelease {
    my $this = shift;

    no strict 'refs';
    return ${$this->{module}.'::RELEASE'} || '';
    use strict 'refs';
}

# Get the description string for the given plugin
sub getDescription {
    my $this = shift;

    unless( defined $this->{description} ) {
        my $pref = uc( $this->{name} ) . '_SHORTDESCRIPTION';
        my $prefs = $this->{session}->{prefs};
        $this->{description} = $prefs->getPreferencesValue( $pref ) || '';
    }
    if( $this->{disabled} ) {
        return ' !'.$this->{name}.': (disabled)';
    }

    my $release = $this->getRelease();
    my $version = $this->getVersion();
    $version =~ s/\$Rev: (\d+) \$/$1/g;
    $version = $release.', '.$version if $release;

    my $result = ' '.$this->{installWeb}.'.'.$this->{name}.' ';
    $result .= CGI::span( { class=> 'twikiGrayText twikiSmall'}, '('.$version.')' );
    $result .= ': '.$this->{description};
    return $result;
}

1;
