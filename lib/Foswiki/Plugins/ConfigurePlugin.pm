# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ConfigurePlugin

=cut

package Foswiki::Plugins::ConfigurePlugin;

use strict;
use warnings;
use version; our $VERSION = version->declare("v1.0.0_001");
use Assert;

use Foswiki::Contrib::JsonRpcContrib             ();
use Foswiki::Plugins::ConfigurePlugin::SpecEntry ();

our $RELEASE          = '29 May 2013';
our $SHORTDESCRIPTION = '=configure= interface using json-rpc';

our $NO_PREFS_IN_TOPIC = 1;

BEGIN {
    unless ( $Foswiki::cfg{isVALID} ) {
        $Foswiki::cfg{SwitchBoard}{jsonrpc} = {
            package  => 'Foswiki::Contrib::JsonRpcContrib',
            function => 'dispatch',
            context  => { jsonrpc => 1 }
        };
        $Foswiki::cfg{Plugins}{ConfigurePlugin}{Enabled} = 1;
        $Foswiki::cfg{Plugins}{ConfigurePlugin}{Module} =
          'Foswiki::Plugins::ConfigurePlugin';
    }
}

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Register each of the RPC methods with JsonRpcContrib
    foreach my $method (qw(getcfg getspec check changecfg deletecfg)) {
        Foswiki::Contrib::JsonRpcContrib::registerMethod( 'configure', $method,
            _JSONwrap($method) );
    }

    return 1;
}

sub _JSONwrap {
    my $method = shift;
    return sub {
        my ( $session, $request ) = @_;

        # Check rights to use this interface - admins only
        die "We wants our rights, precious!" unless Foswiki::Func::isAnAdmin();
        no strict 'refs';
        return &$method( $request->params() );
        use strict 'refs';
      }
}

# Retrieve for the value of one or more keys.
# params: 'keys' - list of key names to recover values for
# If there isn't at least one 'key' parameter, returns the
# entire configuration hash.
sub getcfg {
    my $params = shift;

    # Reload Foswiki::cfg without expansions
    %Foswiki::cfg = ();
    Foswiki::Configure::Load::readConfig( 1, 1 );
    my $keys = $params->{keys};    # expect a list
    my $what;
    if ( defined $keys ) {
        $what = {};
        foreach my $key (@$keys) {
            die "Bad key '$key'"
              unless $key =~
/^($Foswiki::Plugins::ConfigurePlugin::SpecEntry::configItemRegex)$/;
            $key = $1;             # Implicit untaint for use in eval
            die "$key not defined" unless eval "exists \$Foswiki::cfg$key";
            eval "\$what->$key=\$Foswiki::cfg$key";
            die $@ if $@;
        }
    }
    else {
        $what = \%Foswiki::cfg;
    }
    return $what;
}

# Use a search to find a configuration item spec
sub getspec {
    my $params = shift;

    # Reload Foswiki::cfg without expansions so we get the unexpanded
    # values in the spec structure
    %Foswiki::cfg = ();
    Foswiki::Configure::Load::readConfig( 1, 1 );

    my $root = Foswiki::Plugins::ConfigurePlugin::SpecEntry::loadSpecFiles();

    my $search;
    my $child_levels;
    my @roots = ($root);

    while ( my ( $k, $e ) = each %$params ) {
        if ( $k eq 'children' ) {
            $child_levels = $e;
        }
        else {
            $search ||= {};
            $search->{$k} = $e;
        }
    }

    my @matches = ();
    if ($search) {
        @matches = $root->findSpecEntries(%$search);
    }
    else {
        @matches = ($root);
    }

    if ( defined $child_levels ) {

        # Children to a fixed depth only; prune
        foreach my $m (@matches) {
            _prune( $m, $child_levels );
        }
    }

    return \@matches;
}

# 0 will prune children
# 1 will prune children-of-children
sub _prune {
    my ( $node, $level ) = @_;

    if ( $level == 0 ) {
        delete $node->{children};
    }
    elsif ( $node->{children} ) {
        foreach my $c ( @{ $node->{children} } ) {
            _prune( $c, $level - 1 );
        }
    }
}

# Run checkers on the configuration data passed in, or the whole current
# LSC if nothing is passed.
sub check {
    my $params = shift;

    # Load the spec files so we can find the type checker
    my $root = Foswiki::Plugins::ConfigurePlugin::SpecEntry::loadSpecFiles();

    if ( scalar keys %$params ) {

        # Set the new values while we check them
        while ( my ( $keypath, $value ) = each %$params ) {

            # Ignore a value setting to undefined. This is used to indicate
            # that the current value is to be checked, rather than a new
            # value being passed in.
            if ( defined $value ) {
                eval "\$Foswiki::cfg$keypath=\$value";
                die $@ if $@;
            }
        }
    }
    else {

        # Pull current keys and values from $Foswiki::cfg
        my @keys = $root->getAllKeys();
        foreach my $k (@keys) {
            $params->{$k} = eval '\$Foswiki::cfg$k';
        }
    }

    # now check them
    my @report = $root->check($params);

    return \@report;
}

# Save changes to the LSC, making backups as required
sub changecfg {
    my $params    = shift;
    my $changes   = $params->{set};      # expect a hash
    my $deletions = $params->{clear};    # expect an array of keys
    my $added     = 0;
    my $changed   = 0;
    my $cleared   = 0;

    # Reload Foswiki::cfg without expansions
    $Foswiki::cfg{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 1, 1 );

    if ( defined $deletions ) {
        foreach my $key (@$deletions) {
            die "Bad key '$key'"
              unless $key =~
/^($Foswiki::Plugins::ConfigurePlugin::SpecEntry::configItemRegex)$/;

            # Implicit untaint
            $key = Foswiki::Plugins::ConfigurePlugin::SpecEntry::safeKeys($1);
            $cleared += eval "exists \$Foswiki::cfg$key" ? 1 : 0;
            eval "delete \$Foswiki::cfg$key";
        }
    }
    if ( defined $changes ) {
        while ( my ( $key, $value ) = each %$changes ) {
            die "Bad key '$key'"
              unless $key =~
/^($Foswiki::Plugins::ConfigurePlugin::SpecEntry::configItemRegex)$/;

            # Implicit untaint
            $key = Foswiki::Plugins::ConfigurePlugin::SpecEntry::safeKeys($1);
            if ( eval "exists \$Foswiki::cfg$key" ) {
                my $oval = eval "\$Foswiki::cfg$key";
                if ( ref($oval) || $oval =~ /^[0-9]+$/ ) {
                    $changed++ if $oval != $value;
                }
                else {
                    $changed++ if $oval ne $value;
                }
            }
            else {
                $added++;
            }
            eval "\$Foswiki::cfg$key=\$value";
        }
    }
    if ( $changed || $added || $cleared ) {
        _save();
    }

    $Foswiki::cfg{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 0, 1 );

    return "Added: $added; Changed: $changed; Cleared: $cleared";
}

sub _save {
    my $lsc = Foswiki::Plugins::ConfigurePlugin::SpecEntry::findFileOnPath(
        'Foswiki.spec')
      || '';
    $lsc =~ s/Foswiki\.spec/LocalSite.cfg/;

    my $content;
    my ( @backups, $backup );
    while ( -f $lsc ) {

        if ( open( F, '<', $lsc ) ) {
            local $/ = undef;
            $content = <F>;
            close(F);
        }
        else {
            last if ( $!{ENOENT} );    # Race: file disappeared
            die "Unable to read $lsc: $!\n";    # Serious error
        }

        $Foswiki::cfg{MaxLSCBackups} ||= 0;

        last unless ( $Foswiki::cfg{MaxLSCBackups} );

        # Save backup copy of current configuration (even if insane)

        require Errno;
        require Fcntl;
        Fcntl->import(qw/:DEFAULT/);
        require File::Spec;

        my ( $mode, $uid, $gid, $atime, $mtime ) = ( stat(_) )[ 2, 4, 5, 8, 9 ];

        # Find a reasonable starting point for the new backup's name

        my $n = 0;
        my ( $vol, $dir, $file ) = File::Spec->splitpath($lsc);
        $dir = File::Spec->catpath( $vol, $dir, 'x' );
        chop $dir;
        if ( opendir( my $d, $dir ) ) {
            @backups =
              sort { $b <=> $a }
              map { /^$file\.(\d+)$/ ? ($1) : () } readdir($d);
            my $last = $backups[0];
            $n = $last if ( defined $last );
            $n++;
            closedir($d);
        }
        else {
            $n = 1;
            unshift @backups, $n++ while ( -e "$lsc.$n" );
        }

        # Find the actual filename and open for write

        my $open;
        my $um = umask(0);
        unshift( @backups, $n++ )
          while (
            !(
                $open = sysopen( F, "$lsc.$n",
                    O_WRONLY() | O_CREAT() | O_EXCL(), $mode & 07777
                )
            )
            && $!{EEXIST}
          );
        if ($open) {
            $backup = "$lsc.$n";
            unshift( @backups, $n );
            print F $content;
            close(F);
            utime( $atime, $mtime, $backup );
            chown( $uid, $gid, $backup );
        }
        else {
            die "Unable to open $lsc.$n for write: $!\n";
        }
        umask($um);
        last;
    }
    my $oldContent = $content || '';

    $content = <<'HERE';
# Local site settings for Foswiki. This file is managed by the system,
# though you can also make (careful!) manual changes with a text editor.
# See the Foswiki.spec file in this directory for documentation
# Extensions are documented in the Config.spec file in the Plugins/<extension>
# or Contrib/<extension> directories  (Do not remove the following blank line.)

HERE
    my $root = Foswiki::Plugins::ConfigurePlugin::SpecEntry::loadSpecFiles();
    my ( $lines, $requires ) = $root->lscify( \%Foswiki::cfg );
    if ($requires) {
        $content .= join( '', map { "require $_;\n" } keys %$requires );
    }
    $content .= join( '', @$lines ) . "1;\n";

    my $um = umask(007);    # Contains passwords, no world access to new file
    open( F, '>', $lsc )
      || die "Could not open $lsc for write: $!\n";
    print F $content;
    close(F) or die "Close failed for $lsc: $!\n";
    umask($um);
    if ( $backup && ( my $max = $Foswiki::cfg{MaxLSCBackups} ) >= 0 ) {
        while ( @backups > $max ) {
            my $n = pop @backups;
            unlink "$lsc.$n";
        }
    }
}

1;

__END__

Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2013 Foswiki Contributors. Foswiki Contributors
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
