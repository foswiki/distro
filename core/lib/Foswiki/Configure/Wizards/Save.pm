# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::Save;

=begin TML

---++ package Foswiki::Configure::Wizards::Save

Wizard to generate LocalSite.cfg file from current $Foswiki::cfg,
taking a backup as necessary.

=cut

use strict;
use warnings;

use Assert;

use Errno;
use Fcntl;
use File::Spec                   ();
use Foswiki::Configure::Load     ();
use Foswiki::Configure::LoadSpec ();
use Foswiki::Configure::FileUtil ();

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

use constant STD_HEADER => <<'HERE';
# Local site settings for Foswiki. This file is managed by the 'configure'
# CGI script, though you can also make (careful!) manual changes with a
# text editor.  See the Foswiki.spec file in this directory for documentation
# Extensions are documented in the Config.spec file in the Plugins/<extension>
# or Contrib/<extension> directories  (Do not remove the following blank line.)

HERE

# Max length of a change report before ellipsis
use constant CHANGE_LIMIT => 256;

# back up the current LSC content and return it
sub _backupCurrentContent {
    my ( $path, $reporter ) = @_;
    my $content;

    if ( open( F, '<', $path ) ) {
        local $/ = undef;
        $content = <F>;
        close(F);
    }
    else {
        return ($content) if ( $!{ENOENT} );    # Race: file disappeared
        die "Unable to read $path: $!\n";       # Serious error
    }
    $Foswiki::cfg{MaxLSCBackups} = 10
      unless defined $Foswiki::cfg{MaxLSCBackups};
    unless ( $Foswiki::cfg{MaxLSCBackups} >= -1 ) {
        $Foswiki::cfg{MaxLSCBackups} = 0;
        $reporter->CHANGED('{MaxLSCBackups}');
    }

    return ($content) unless ( $Foswiki::cfg{MaxLSCBackups} );

    # Save backup copy of current configuration (even if always_write)

    Fcntl->import(qw/:DEFAULT/);

    my ( $mode, $uid, $gid, $atime, $mtime ) = ( stat(_) )[ 2, 4, 5, 8, 9 ];

    # Find a reasonable starting point for the new backup's name

    my $n = 0;
    my ( $vol, $dir, $file ) = File::Spec->splitpath($path);
    $dir = File::Spec->catpath( $vol, $dir, 'x' );
    chop $dir;
    my @backups;
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
        unshift @backups, $n++ while ( -e "$path.$n" );
    }

    # Find the actual filename and open for write

    my $open;
    my $um = umask(0);
    unshift @backups, $n++
      while (
        !(
            $open = sysopen( F, "$path.$n",
                O_WRONLY() | O_CREAT() | O_EXCL(), $mode & 07777
            )
        )
        && $!{EEXIST}
      );
    my $backup;
    if ($open) {
        $backup = "$path.$n";
        unshift @backups, $n;
        print F $content;
        close(F);
        utime $atime, $mtime, $backup;
        chown $uid, $gid, $backup;
    }
    else {
        die "Unable to open $path.$n for write: $!\n";
    }
    umask($um);

    return ( $content, $backup, @backups );
}

=begin TML

---++ WIZARD save
Params:
   * set - hash mapping keys to values

Returns a wizard report.

=cut

sub save {
    my ( $this, $reporter ) = @_;

    my $logger;
    if ($Foswiki::Plugins::SESSION) {
        $logger = $Foswiki::Plugins::SESSION->logger;
    }
    elsif ( defined $this->param('logger') ) {
        $logger = $this->param('logger');
    }

    # Sort keys so it's possible to diff LSC files.
    local $Data::Dumper::Sortkeys = 1;

    my %changeLog;

    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec( $root, $reporter );

    my $lsc = Foswiki::Configure::FileUtil::lscFileName();

    # Pick up any missing config options from .spec
    # SMELL: this *should* be a NOP, if the wizards did their job correctly,
    # though if an extension was installed from the shell when we weren't
    # looking it might be required.
    Foswiki::Configure::LoadSpec::addSpecDefaultsToCfg( $root, \%Foswiki::cfg );

    my ( $old_content, $backup, @backups ) =
      _backupCurrentContent( $lsc, $reporter );

    my %orig_content;    # used so diff detects remapping of keys

    if ( defined $old_content && $old_content =~ /^(.*)$/s ) {

        # Eval the old LSC and extract the content (assuming we can)
        local %Foswiki::cfg;
        {
            our $FALSE = 0;
            our $TRUE  = 1;
            eval $1;
        }
        if ($@) {
            print STDERR "Error reading existing $lsc: $@";

            # Continue, but will be unable to detect changes
        }
        else {
            %orig_content = %Foswiki::cfg;

            # Clean out deprecated settings, so they don't occlude the
            # replacements
            foreach my $key ( keys %Foswiki::Configure::Load::remap ) {
                $old_content =~ s/\$Foswiki::cfg$key\s*=.*?;\s*//sg;
            }
        }
    }

    unless ( defined $old_content ) {

        # Construct a new LocalSite.cfg from the spec
        local %Foswiki::cfg = ();

        #---++ StaticMethod readConfig([$noexpand][,$nospec][,$config_spec])
        Foswiki::Configure::Load::readConfig( 1, 0, 1 );
        delete $Foswiki::cfg{ConfigurationFinished};
        $old_content =
            STD_HEADER
          . join( '', _generateLSC( $root, \%Foswiki::cfg, '', $reporter ) )
          . "1;\n";
    }

    my %save;

    # Clear out the configuration and re-initialize it either
    # with or without the .spec expansion.
    if ( $Foswiki::cfg{isBOOTSTRAPPING} ) {
        foreach my $key ( @{ $Foswiki::cfg{BOOTSTRAP} } ) {
            eval("(\$save$key)=\$Foswiki::cfg$key=~/^(.*)\$/");
            ASSERT( !$@, $@ ) if DEBUG;
            delete $Foswiki::cfg{BOOTSTRAP};
        }

        %Foswiki::cfg = ();

        # Read without expansions but with the .spec
        Foswiki::Configure::Load::readConfig( 1, 0, 1 );

        # apply bootstrapped settings
        # print STDERR join( '', _generateLSC( $root, \%save, '', $reporter ) );
        eval( join( '', _generateLSC( $root, \%save, '', $reporter ) ) );
        die "Internal error: $@" if ($@);
    }
    else {
        %Foswiki::cfg = ();

        # Read without expansions and without the .spec
        Foswiki::Configure::Load::readConfig( 1, 1 );
    }

    # Get changes from 'set' *without* expanding values
    if ( $this->param('set') ) {
        while ( my ( $k, $v ) = each %{ $this->param('set') } ) {
            my $spec = $root->getValueObject($k);
            if ( defined $v ) {
                my ($value) = $v =~ m/^(.*)$/s;    #UNTAINT
                if ($spec) {
                    eval { $value = $spec->decodeValue($value) };
                    if ($@) {
                        $reporter->ERROR(
"SAVE ABORTED: Could not interpret new value for $k: "
                              . Foswiki::Configure::Reporter::stripStacktrace(
                                $@) );
                        return undef;
                    }
                }
                if ( defined $value ) {
                    eval "\$Foswiki::cfg$k=\$value";
                }
                else {
                    eval "undef \$Foswiki::cfg$k";
                }
            }
            elsif ( $spec->CHECK_option('nullok') ) {
                eval "undef \$Foswiki::cfg$k";
            }
            else {
                $reporter->ERROR(
"SAVE ABORTED: undef given as value for $k, but the spec is not undefok"
                );
                return undef;
            }
            ASSERT( !$@, $@ ) if DEBUG;
        }
    }

    delete $Foswiki::cfg{ConfigurationFinished};
    my $new_content =
        STD_HEADER
      . join( '', _generateLSC( $root, \%Foswiki::cfg, '', $reporter ) )
      . "1;\n";

    if ( $new_content ne $old_content ) {
        my $um = umask(007);   # Contains passwords, no world access to new file
        open( F, '>', $lsc )
          || die "Could not open $lsc for write: $!\n";
        print F $new_content;
        close(F) or die "Close failed for $lsc: $!\n";
        umask($um);
        my $max = $Foswiki::cfg{MaxLSCBackups};
        $max = -1 unless defined $max;    # Unlimited
        if ($backup) {

            while ( $max >= 0 && @backups > $max ) {
                my $n = pop @backups;
                unlink "$lsc.$n";
            }
            $reporter->NOTE("Previous configuration saved in $backup");
        }
        $reporter->NOTE("New configuration saved in $lsc");

        if (%orig_content) {
            $reporter->NOTE('| *Key* | *Old* | *New* |');
            _compareConfigs( $root, \%orig_content, \%Foswiki::cfg,
                $reporter, $logger, '' );
        }
    }
    else {
        unlink $backup if ($backup);
        $reporter->NOTE("No changes needed to be made to $lsc");
    }
    return undef;    # return the report
}

# $reporter is set to undef when recursing into a hash below the
# Foswiki::Configure::Value level
sub _compareConfigs {
    my ( $spec, $o, $n, $reporter, $logger, $keypath ) = @_;

    my $old = Foswiki::Configure::Reporter::uneval($o);
    my $new = Foswiki::Configure::Reporter::uneval($n);

    my $vs = $spec->getValueObject($keypath);

    if ($vs) {

        #print STDERR "REPORT ON $vs->{keys} $old $new\n";
        if ( $old ne $new ) {
            if ( $vs->{typename} eq 'PASSWORD' ) {
                $old = '_[redacted]_';
                $new = '_[redacted]_';
            }
            $old = "($vs->{default})" if $old eq 'undef' && $vs->{default};
            _logAndReport( $reporter, $logger, $keypath, $old, $new );
            return 0;
        }
        return 1;
    }

    #print STDERR "$keypath is not in spec\n";
    if ( $o && $n && ref($o) ne ref($n) ) {

        # Both set, but different types. Stop the recursion here.
        _logAndReport( $reporter, $logger, $keypath, $old, $new );
        return 0;
    }

    # We know they are the same type (or one is undef)
    if ( ref($o) eq 'HASH' || ref($n) eq 'HASH' ) {
        $o = {} unless defined $o;
        $n = {} unless defined $n;
        my %keys = map { $_ => 1 } ( keys %$o, keys %$n );
        my $ok = 1;
        foreach my $k ( sort keys %keys ) {
            unless (
                _compareConfigs(
                    $spec,
                    $o->{$k},
                    $n->{$k},
                    $reporter,
                    $logger,
                    $keypath . '{'
                      . Foswiki::Configure::LoadSpec::protectKey($k) . '}'
                )
              )
            {
                $ok = 0;
            }
        }
        return $ok;
    }

    if ( ref($o) eq 'ARRAY' || ref($n) eq 'ARRAY' ) {
        $o = [] unless defined $o;
        $n = [] unless defined $n;
        if ( scalar(@$o) != scalar(@$n) ) {
            _logAndReport( $reporter, $logger, $keypath, $old, $new );
            return 0;
        }
        for ( my $i = 0 ; $i < scalar(@$o) ; $i++ ) {
            unless (
                _compareConfigs(
                    $spec,     $o->[$i], $n->[$i],
                    $reporter, $logger,  "$keypath\[$i\]"
                )
              )
            {
                _logAndReport( $reporter, $logger, $keypath, $old, $new );
                return 0;
            }
        }
        return 1;
    }

    if (   ( !defined $o && defined $n )
        || ( defined $o && !defined $n )
        || $o ne $n )
    {
        _logAndReport( $reporter, $logger, $keypath, $old, $new );
        return 0;
    }

    return 1;
}

sub _logAndReport {
    my ( $reporter, $logger, $keypath, $old, $new ) = @_;

    $logger->log(
        {
            level    => 'notice',
            action   => 'save',
            setting  => $keypath,
            newvalue => $new,
            oldvalue => $old,
        }
    ) if ( defined $logger );

    # Truncate the change for the UI
    $old = Foswiki::Configure::Reporter::ellipsis( $old, CHANGE_LIMIT );
    $new = Foswiki::Configure::Reporter::ellipsis( $new, CHANGE_LIMIT );

    # Encode vertcal bars, so that the TML table isn't corrupted.
    $old =~ s/\|/&#124;/g;
    $new =~ s/\|/&#124;/g;

    if ($reporter) {
        $reporter->NOTE("| $keypath | $old | $new |");
    }
}

# $datum starts as \%Foswiki::cfg and recurses down the hash tree
sub _generateLSC {
    my ( $spec, $datum, $keys, $reporter ) = @_;

    my @dump;

    my $vs = $spec->getValueObject($keys);
    if ($vs) {

        if ( !defined $datum ) {

            # An undef value and undefok will suppress the item in LSC
            return ()
              if ( $vs->can('CHECK_option') && $vs->CHECK_option('undefok') );

        }
        elsif ( $datum eq '' ) {

            # Treat '' as undef unless emptyok
            return ()
              if ( $vs->can('CHECK_option') && $vs->CHECK_option('emptyok') );
        }
        my $d = Foswiki::Configure::Reporter::uneval($datum);
        push( @dump, "\$Foswiki::cfg$keys = $d;\n" );
    }
    elsif ( ref($datum) eq 'HASH' ) {
        foreach my $k ( sort keys %$datum ) {
            my $v  = $datum->{$k};
            my $sk = Foswiki::Configure::LoadSpec::protectKeys("{$k}");
            push( @dump, _generateLSC( $spec, $v, "${keys}$sk", $reporter ) );
        }
    }
    else {
        my $d  = Foswiki::Configure::Reporter::uneval($datum);
        my $sk = Foswiki::Configure::LoadSpec::protectKeys($keys);
        push( @dump, "# $sk was not found in .spec\n" );
        push( @dump, "\$Foswiki::cfg$sk = $d;\n" );
    }

    return @dump;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2014 Foswiki Contributors. Foswiki Contributors
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
