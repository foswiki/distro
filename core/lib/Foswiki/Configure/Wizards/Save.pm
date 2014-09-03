package Foswiki::Configure::Wizards::Save;

=begin TML

---++ package Foswiki::Configure::Wizards::Save

Wizard to generate LocalSite.cfg file from current $Foswiki::cfg,
taking a backup as necessary.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

use Errno;
use Fcntl;
use File::Spec                   ();
use Foswiki::Configure::Load     ();
use Foswiki::Configure::FileUtil ();

use constant STD_HEADER => <<'HERE';
# Local site settings for Foswiki. This file is managed by the 'configure'
# CGI script, though you can also make (careful!) manual changes with a
# text editor.  See the Foswiki.spec file in this directory for documentation
# Extensions are documented in the Config.spec file in the Plugins/<extension>
# or Contrib/<extension> directories  (Do not remove the following blank line.)

HERE

# Perlise a key string
sub _perlKeys {
    my $k = shift;
    $k =~ s/^{(.*)}$/$1/;
    return '{'
      . join(
        '}{', map { _perlKey($_) }
          split( /}{/, $k )
      ) . '}';
}

# Make a single key safe for use in perl
sub _perlKey {
    my $k = shift;
    return $k if $k =~ /^[a-zA-Z_]\w*$/;
    return $k if $k =~ /^(['"]).*\1$/;     # Already encoded
    $k =~ s/'/\\'/g;
    return "'$k'";
}

sub save {
    my ( $this, $reporter ) = @_;
    my $session = $Foswiki::Plugins::SESSION;

    # Sort keys so it's possible to diff LSC files.
    local $Data::Dumper::Sortkeys = 1;

    my ( @backups, $backup );

    my $old_content;
    my $orig_content;    # used so diff detects remapping of keys
    my %changeLog;

    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec($root);

    my $lsc = Foswiki::Configure::FileUtil::lscFileName();

    # while loop used just so it can use 'last' :-(
    while ( -f $lsc ) {
        if ( open( F, '<', $lsc ) ) {
            local $/ = undef;
            $old_content = <F>;
            close(F);
        }
        else {
            last if ( $!{ENOENT} );    # Race: file disappeared
            die "Unable to read $lsc: $!\n";    # Serious error
        }

        unless ( defined $Foswiki::cfg{MaxLSCBackups}
            && $Foswiki::cfg{MaxLSCBackups} >= -1 )
        {
            $Foswiki::cfg{MaxLSCBackups} = 0;
            $reporter->CHANGED('{MaxLSCBackups}');
        }

        last unless ( $Foswiki::cfg{MaxLSCBackups} );

        # Save backup copy of current configuration (even if always_write)

        Fcntl->import(qw/:DEFAULT/);

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
        unshift @backups, $n++
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
            unshift @backups, $n;
            print F $old_content;
            close(F);
            utime $atime, $mtime, $backup;
            chown $uid, $gid, $backup;
        }
        else {
            die "Unable to open $lsc.$n for write: $!\n";
        }
        umask($um);
        last;
    }

    if ( defined $old_content && $old_content =~ /^(.*)$/s ) {
        local %Foswiki::cfg;
        eval $1;
        if ($@) {
            die "Error reading existing LocalSite.cfg: $@";
        }
        else {
            $orig_content = \%Foswiki::cfg;

            # Clean out deprecated settings, so they don't occlude the
            # replacements
            foreach my $key ( keys %Foswiki::Configure::Load::remap ) {
                $old_content =~ s/\$Foswiki::cfg$key\s*=.*?;\s*//sg;
            }
        }
    }

    unless ( defined $old_content ) {

        # Pull in a new LocalSite.cfg from the spec
        local %Foswiki::cfg = ();
        Foswiki::Configure::Load::readConfig( 1, 0, 1 );
        delete $Foswiki::cfg{ConfigurationFinished};
        $old_content =
          STD_HEADER
          . join( '', _spec_dump( $root, \%Foswiki::cfg, '' ) ) . "1;\n";
    }

    # In bootstrap mode, we want to keep the essential settings that
    # the bootstrap process worked out.
    if ( $Foswiki::cfg{isBOOTSTRAPPING} ) {
        my %save;
        foreach my $key (@Foswiki::Configure::Load::NOT_SET) {
            eval("\$save$key = \$Foswiki::cfg$key ");
        }

        # Re-read LocalSite.cfg without expansions but with
        # the .spec
        %Foswiki::cfg = ();
        Foswiki::Configure::Load::readConfig( 1, 0, 1 );

        while ( my ( $k, $v ) = each %save ) {
            $Foswiki::cfg{$k} = $v;
        }
    }
    else {

        # Re-read LocalSite.cfg without expansions
        %Foswiki::cfg = ();
        Foswiki::Configure::Load::readConfig( 1, 1 );
    }

    # Import sets without expanding
    if ( $this->param('set') ) {
        while ( my ( $k, $v ) = each %{ $this->param('set') } ) {
            if ( defined $v && $v =~ /(.*)/ ) {
                eval "\$Foswiki::cfg" . _perlKeys($k) . "=\$1";
            }
            else {
                eval "undef \$Foswiki::cfg" . _perlKeys($k);
            }
        }
    }

    delete $Foswiki::cfg{ConfigurationFinished};
    my $new_content =
      STD_HEADER . join( '', _spec_dump( $root, \%Foswiki::cfg, '' ) ) . "1;\n";

    if ( $new_content ne $old_content ) {
        my $um = umask(007);   # Contains passwords, no world access to new file
        open( F, '>', $lsc )
          || die "Could not open $lsc for write: $!\n";
        print F $new_content;
        close(F) or die "Close failed for $lsc: $!\n";
        umask($um);
        if ( $backup && ( my $max = $Foswiki::cfg{MaxLSCBackups} ) >= 0 ) {
            while ( @backups > $max ) {
                my $n = pop @backups;
                unlink "$lsc.$n";
            }
            $reporter->NOTE("Previous configuration saved in $backup");
        }
        $reporter->NOTE("New configuration saved in $lsc");

        _compareConfigs( $root, $orig_content, \%Foswiki::cfg, $reporter )
          if $orig_content;
    }
    else {
        unlink $backup if ($backup);
        $reporter->NOTE("No change made to $lsc");
    }
}

sub _compareConfigs {

    my ( $spec, $oldcfg, $newcfg, $reporter ) = @_;

    $reporter->NOTE('| *Key* | *Old* | *New* |');
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Indent   = 0;
    local $Data::Dumper::SortKeys = 1;

    _same( $spec, $oldcfg, $newcfg, '', $reporter );
}

sub _same {
    my ( $spec, $o, $n, $keypath, $reporter ) = @_;
    print STDERR "SNIFFING $keypath $o $n\n" if $keypath =~ /zh/;
    my ( $old, $new );

    if ( ref($o) ne ref($n) ) {
        $old = ref($o) || ( defined $o ? $o : 'undef' );
        $new = ref($n) || ( defined $n ? $n : 'undef' );
        $reporter->NOTE("| $keypath | $old | $new |") if $reporter;
        return 0;
    }

    # We know they are the same type
    if ( ref($o) eq 'HASH' ) {
        my %keys = map { $_ => 1 } ( keys %$o, keys %$n );
        my $ok = 1;
        foreach my $k ( sort keys %keys ) {
            unless (
                _same(
                    $spec, $o->{$k}, $n->{$k},
                    $keypath . '{' . _perlKey($k) . '}', $reporter
                )
              )
            {
                $ok = 0;
            }
        }
        return $ok;
    }

    if ( ref($o) eq 'ARRAY' ) {
        if ( scalar(@$o) != scalar(@$n) ) {
            $old = '[' . scalar($o) . ']';
            $new = '[' . scalar($n) . ']';
            $reporter->NOTE("| $keypath | $old | $new |") if $reporter;
            return 0;
        }
        else {
            for ( my $i = 0 ; $i < scalar(@$o) ; $i++ ) {
                unless ( _same( $spec, $o->[$i], $n->[$i], "$keypath\[$i\]" ) )
                {
                    if ($reporter) {
                        $old = Data::Dumper->Dump( [$o] );
                        $old =~ s/^.*?= //;
                        $new = Data::Dumper->Dump( [$n] );
                        $new =~ s/^.*?= //;
                        $reporter->NOTE("| $keypath | $old | $new |");
                    }
                    return 0;
                }
            }
        }
    }
    elsif (( !defined $o && defined $n )
        || ( defined $o && !defined $n )
        || $o ne $n )
    {
        if ( my $vs = $spec->getValueObject($keypath) ) {
            if ( $vs->{typename} eq 'PASSWORD' ) {
                $reporter->NOTE("| $keypath | _[redacted]_ | _[redacted]_ |")
                  if $reporter;
                return 0;
            }
        }

        $old = ref($o) || ( defined $o ? $o : 'undef' );
        $new = ref($n) || ( defined $n ? $n : 'undef' );
        $reporter->NOTE("| $keypath | $old | $new |") if $reporter;
        return 0;
    }

    return 1;
}

sub _spec_dump {
    my ( $spec, $datum, $keys ) = @_;

    my @dump;
    if ( my $vs = $spec->getValueObject($keys) ) {
        my $d;
        if ( $vs->{typename} eq 'REGEX' ) {
            $datum = "$datum";
        }
        if ( $vs->{typename} eq 'BOOLEAN' ) {
            $d = ( $datum ? 1 : 0 );
        }
        elsif ( $vs->{typename} eq 'NUMBER' ) {
            $d = $datum;
        }
        else {
            $d = Data::Dumper->Dump( [$datum] );
            $d =~ s/^\$VAR1\s*=\s*//s;
            $d =~ s/;\s*$//s;
        }
        push( @dump, "\$Foswiki::cfg$keys = $d;\n" );
    }
    elsif ( ref($datum) eq 'HASH' ) {
        foreach my $k ( sort keys %$datum ) {
            my $v  = $datum->{$k};
            my $sk = _perlKeys("{$k}");
            push( @dump, _spec_dump( $spec, $v, "${keys}$sk" ) );
        }
    }
    else {
        my $d = Data::Dumper->Dump( [$datum] );
        my $sk = _perlKeys($keys);
        $d =~ s/^\$VAR1/\$Foswiki::cfg$sk/;
        push( @dump, "# Not found in .spec\n" );
        push( @dump, $d );
    }

    return @dump;
}

1;
