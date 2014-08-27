# See bottom of file for default license and copyright information

# Note that POD in this module is included in the documentation topic
# by BuildContrib

=pod

---++ Remote Procedure Call (RPC) interface
RPC calls are handled via the =JsonRpcContrib=. Callers must authenticate
as admins, or the request will be rejected with a 403 status.

Note: If Foswiki is running in 'bootstrap' mode (without a !LocalSite.cfg)
then *all* calls are automatically assumed to be from an admin. As soon
as a !LocalSite.cfg is put in place, then the authentication set up
therein will apply, and users are required to logged in as admins.

The following procedures are supported:

=cut

package Foswiki::Plugins::ConfigurePlugin;

use strict;
use warnings;
use version; our $VERSION = version->declare("v1.0.0_001");
use Assert;

use Foswiki::Contrib::JsonRpcContrib             ();
use Foswiki::Plugins::ConfigurePlugin::SpecEntry ();
use Foswiki::Configure::LoadSpec                 ();
use Foswiki::Configure::Load                     ();
use Foswiki::Configure::Root                     ();
use Foswiki::Configure::Reporter                 ();
use Foswiki::Configure::Checker                  ();
use Foswiki::Configure::Wizard                   ();

our $RELEASE          = '29 May 2013';
our $SHORTDESCRIPTION = '=configure= interface using json-rpc';

our $NO_PREFS_IN_TOPIC = 1;

use constant TRACE => 0;

BEGIN {
    # Note: if Foswiki is in bootstrap mode, Foswiki.pm will try
    # to require this module, thus executing this BEGIN block.
    $Foswiki::cfg{SwitchBoard}{jsonrpc} = {
        package  => 'Foswiki::Contrib::JsonRpcContrib',
        function => 'dispatch',
        context  => { jsonrpc => 1 }
    };
    $Foswiki::cfg{Plugins}{ConfigurePlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{ConfigurePlugin}{Module} =
      'Foswiki::Plugins::ConfigurePlugin';
}

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # No way to auto-register JsonRpcContrib, so we have to do it :-(
    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'JsonRpc',
        'Foswiki::Contrib::JsonRpcContrib::JQueryPlugin' );

    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'Configure',
        'Foswiki::Plugins::ConfigurePlugin::JQuery' );

    # Register each of the RPC methods with JsonRpcContrib
    foreach my $method (
        qw(getcfg getspec check_current_value changecfg deletecfg purgecfg wizard)
      )
    {
        Foswiki::Contrib::JsonRpcContrib::registerMethod( 'configure', $method,
            _JSONwrap($method) );
    }

    return 1;
}

sub _JSONwrap {
    my $method = shift;
    return sub {
        my ( $session, $request ) = @_;

        if ( $Foswiki::cfg{isVALID} ) {

            # Check rights to use this interface - admins only
            die
              "You must be logged in as an administrator to use this interface."
              unless Foswiki::Func::isAnAdmin();
        }
        else {
            # Otherwise we must be bootstrapping - an inherently dangerous
            # operation. TODO: check we can do this safely.
        }

        no strict 'refs';
        return &$method( $request->params() );
        use strict 'refs';
      }
}

# Canonicalise a key string
sub safeKeys {
    my $k = shift;
    $k =~ s/^{(.*)}$/$1/;
    return '{'
      . join( '}{',
        map { $_ =~ s/^(['"])(.*)\1$/$2/; safeKey($_) }
          split( /}{/, $k ) )
      . '}';
}

# Make a single key safe for use in a canonical key string
sub safeKey {
    my $k = shift;
    return $k if ( $k =~ /^[a-z_][a-z0-9_]*$/i );
    $k =~ s/'/\\'/g;
    return "'$k'";
}

# For each key in the spec missing from the %cfg passed, add the
# default (unexpanded) from the spec to the %cfg, if it exists.
sub _addSpecDefaultsToCfg {
    my ( $spec, $cfg ) = @_;
    if ( $spec->{children} ) {
        foreach my $child ( @{ $spec->{children} } ) {
            _addSpecDefaultsToCfg( $child, $cfg );
        }
    }
    else {
        if ( exists( $spec->{default} )
            && eval("!exists(\$cfg->$spec->{keys})") )
        {
            eval("\$cfg->$spec->{keys}=\$spec->{default}");
        }
    }
}

# For each key in the spec add the current value from the %cfg
# as current_value. NOT SET values are skipped. If the key is
# not set in the %cfg, then set it to the default.
# Note that the %cfg should contain *unexpanded* values.
sub _addCfgValuesToSpec {
    my ( $cfg, $spec ) = @_;
    if ( $spec->{children} ) {
        foreach my $child ( @{ $spec->{children} } ) {
            _addCfgValuesToSpec( $cfg, $child );
        }
    }
    else {
        if (   eval("exists(\$cfg->$spec->{keys})")
            && eval("\$cfg->$spec->{keys}") ne "NOT SET" )
        {
            eval("\$spec->{current_value}=\$cfg->$spec->{keys}");
        }

        # Don't do this; it's not the case that the default value
        # will end up in LocalSite.cfg
        #elsif (exists($spec->{default})) {
        #    eval("\$spec->{current_value}=eval(\$spec->{default})");
        #}
    }
}

=pod

---+++ =getcfg=
Retrieve for the value of one or more keys.
   * =keys= - array of key names to recover values for.
If there isn't at least one key parameter, returns the
entire configuration hash. Values are returned unexpanded
(with embedded $Foswiki::cfg references intact)
The result is a hash containing that subsection of %Foswiki::cfg
that has the keys requested.

=cut

sub getcfg {
    my $params = shift;

    # Reload Foswiki::cfg without expansions
    local %Foswiki::cfg = ();
    Foswiki::Configure::Load::readConfig( 1, 1 );
    my $keys = $params->{keys};    # expect a list
    my $what;
    my $root;
    if ( defined $keys ) {
        $what = {};
        foreach my $key (@$keys) {
            die "Bad key '$key'"
              unless $key =~ /^($Foswiki::Configure::Load::ITEMREGEX)$/;

            # Implicit untaint for use in eval
            $key = $1;

            # Avoid loading specs unless we are being asked for a key that's
            # not in LocalSite.cfg
            unless ( eval "exists \$Foswiki::cfg$key" || $root ) {
                $root = _loadSpec();
                _addSpecDefaultsToCfg( $root, \%Foswiki::cfg );
            }
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

=pod

---+++ =getspec=

Use a search to find a configuration item spec
   * =get= specifies the search. The following fields can be used in searches:
      * =headline= - title of a section,
      * =typename= - type of a leaf spec entry,
      * =parent= - a structure that will be used to match a parent,
      * =keys= - keys of a spec entry,
      * =desc= - descriptive text of a section or entry.
      * =depth= - matches the depth of a node under the root
        (which is depth 0)
   * =depth= - specifies the depth of the subtree below matched items
     to return.
Only exact matches are supported.

For example, ={ 'get': {'headline':'Store'}}= will retrieve the entire
spec subtree for the section called 'Store'.

={ 'get' : {'keys' : '{Store}{Implementation}'}}= will retrieve the spec
for that one entry. You cannot pass a list; if you require the spec for a
subsection, retrieve the section title.

={ 'get' : { 'parent' : {'headline' : 'Something'}, 'depth' : 0}= will
return all specs within the section named =Something=.

=cut

sub getspec {
    my $params = shift;

    # Reload Foswiki::cfg without expansions so we get the unexpanded
    # values in the spec structure
    my $upper_cfg = \%Foswiki::cfg;
    local %Foswiki::cfg = ();
    if ( $upper_cfg->{isBOOTSTRAPPING} ) {

        # If we're bootstrapping, retain the values calculated in
        # the bootstrap process. They are almost certainly wrong,
        # but are a better starting point that the .spec defaults.
        %Foswiki::cfg = %$upper_cfg;
    }
    Foswiki::Configure::Load::readConfig( 1, 1 );

    my $root = _loadSpec();
    _addCfgValuesToSpec( \%Foswiki::cfg, $root );

    my $depth  = $params->{depth};
    my $search = $params->{get};

    my @matches = ();
    if ($search) {
        @matches = $root->find(%$search);
    }
    else {
        @matches = ($root);
    }

    if ( defined $depth ) {

        # Children to a fixed depth only; prune
        foreach my $m (@matches) {
            _prune( $m, $depth );
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

# Recursive locate references to other keys in the values of keys
# Returns a =forward= hash mapping keys to a list of the keys that depend
# on their value, and a =reverse= hash mapping keys to a list of keys
# whose value they depend on.
sub _findDependencies {
    my ( $deps, $fwcfg, $extend_keypath, $keypath ) = @_;

    unless ( defined $fwcfg ) {
        ( $fwcfg, $extend_keypath, $keypath ) = ( \%Foswiki::cfg, 1, '' );
    }

    if ( ref($fwcfg) eq 'HASH' ) {
        while ( my ( $k, $v ) = each %$fwcfg ) {
            if ( defined $v ) {
                my $subkey = $extend_keypath ? "$keypath\{$k\}" : $keypath;
                _findDependencies( $deps, $v, $extend_keypath, $subkey );
            }
        }
    }
    elsif ( ref($fwcfg) eq 'ARRAY' ) {
        foreach my $v (@$fwcfg) {
            if ( defined $v ) {
                _findDependencies( $deps, $v, 0, $keypath );
            }
        }
    }
    else {
        while ( $fwcfg =~ /\$Foswiki::cfg(({[^}]*})+)/g ) {
            push( @{ $deps->{forward}->{$1} },       $keypath );
            push( @{ $deps->{reverse}->{$keypath} }, $1 );
        }
    }
}

sub _loadSpec {
    my $reporter = shift;

    my $root = Foswiki::Configure::Root->new();
    Foswiki::Configure::LoadSpec::readSpec($root);
    if ( @Foswiki::Configure::LoadSpec::errors && $reporter ) {
        foreach my $e (@Foswiki::Configure::LoadSpec::errors) {
            $reporter->ERROR( join( ' ', @$e ) );
        }
    }
    if ( @Foswiki::Configure::LoadSpec::warnings && $reporter ) {
        foreach my $e (@Foswiki::Configure::LoadSpec::warnings) {
            $reporter->WARN( join( ' ', @$e ) );
        }
    }
    return $root;
}

=pod

---+++ =check_current_value=

Runs the server-side =check-current_value= checkers on a set of keys.
The keys to be checked are passed in as key-value pairs. You can also
pass in candidate values that will be set before any keys are checked.
   * =keys= - array of keys to be checked (or the headline(s) of the
     sections(s) to be recursively checked. '' checks the root. All
     keys under the headlined section(s) will be checked). The default
     is to check everything under the root.
   * =check_dependencies= - if true, check everything that depends
     on any of the keys being checked
   * =set= - hash of key-value pairs that maps the names of keys
     to the value to be set. Strings in the values are assumed to be
     unexpanded (i.e. with =$Foswiki::cfg= references intact).

The results of the check are reported in an array where each entry is a
hash with fields =keys= and =reports=. =reports= is an array of reports,
each being a hash with keys =level= (e.g. =warnings=, =errors=), and
=message=.

=cut

sub _getSetParams {
    my $params = shift;

    if ( $params->{set} ) {
        while ( my ( $k, $v ) = each %{ $params->{set} } ) {
            if ( defined $v && $v =~ /(.*)/ ) {
                eval "\$Foswiki::cfg$k=\$1";
            }
            else {
                eval "undef \$Foswiki::cfg$k";
            }
            die $@ if $@;
        }

        # Expand imported values
        Foswiki::Configure::Load::expandValue( \%Foswiki::cfg );
    }
}

sub check_current_value {
    my $params = shift;

    my @report;

    # Load the spec files
    my $reporter = Foswiki::Configure::Reporter->new();
    my $root     = _loadSpec($reporter);
    foreach my $level ( 'errors', 'warnings', 'confirmations', 'notes' ) {
        push(
            @report,
            {
                keys    => '',
                level   => $level,
                message => $reporter->html($level)
            }
        ) if $reporter->has($level);
    }
    $reporter->clear();

    # Because we're running in a plugin, we already have LocalSite.cfg
    # loaded. It's in $Foswiki::cfg! of course if we're bootstrapping,
    # that config is wishful thinking, but hey, can't have everything.

    # Determine the set of value keys being checked
    my %check;
    my $keys = $params->{keys};
    if ( !$keys || scalar @$keys == 0 ) {
        $check{''} = 1;
    }

    foreach my $k (@$keys) {

        # $k='' is the root section
        my $v = $root->getValueObject($k);
        if ($v) {
            $check{$k} = 1;
        }
        else {
            $v = $root->getSectionObject($k);
            if ($v) {
                foreach my $kk ( $v->getAllValueKeys() ) {
                    $check{$kk} = 1;
                }
            }
            else {
                $k = "'$k'" unless $k =~ /^\{.*\}$/;
                $reporter->ERROR("$k is not part of this .spec");
            }
        }
    }

    # Are we to follow dependencies?
    my $dependants = 0;
    my %deps;

    # Apply "set" values to $Foswiki::cfg
    _getSetParams($params);

    if ( $params->{check_dependencies} ) {

        # Reload Foswiki::cfg without expansions so we can find
        # dependencies
        local %Foswiki::cfg = ();
        Foswiki::Configure::Load::readConfig( 1, 1 );
        if ( $params->{with} ) {
            while ( my ( $k, $v ) = each %{ $params->{with} } ) {
                eval "\$Foswiki::cfg$k=$v";
            }
        }
        _findDependencies( \%deps );

        # Extend the list of requested keys with the keys that depend
        # on their values.
        my @dep_keys = keys %check;
        my %done;
        while ( my $dep = shift @dep_keys ) {
            next if $done{$dep};
            $check{$dep} = 1;
            $done{$dep}  = 1;
            push( @dep_keys, @{ $deps{forward}->{$dep} } );
        }
    }

    foreach my $k ( keys %check ) {
        my $spec = $root->getValueObject($k);
        ASSERT( $spec, $k ) if DEBUG;
        my $checker = Foswiki::Configure::Checker::loadChecker($spec);
        if ($checker) {
            $reporter->clear();
            $checker->check_current_value($reporter);
            my @reps;
            foreach my $level ( 'errors', 'warnings', 'confirmations', 'notes' )
            {
                push(
                    @reps,
                    {
                        level   => $level,
                        message => $reporter->html($level)
                    }
                ) if $reporter->has($level);
            }
            push(
                @report,
                {
                    keys    => $k,
                    path    => [ $spec->getSectionPath() ],
                    reports => \@reps
                }
            );
        }
    }
    return \@report;
}

# Purge keys from Foswiki::cfg unless they are listed in %ok. Return
# the number of keys purged.
sub _purge {
    my ( $ok, $cfg, $path ) = @_;
    unless ( defined $cfg ) {
        ( $cfg, $path ) = ( \%Foswiki::cfg, '' );
    }

    my $purged = 0;
    if ( ref($cfg) eq 'HASH' ) {
        while ( my ( $k, $v ) = each %$cfg ) {
            next unless defined $v;
            $purged += _purge( $ok, $v, "$path\{$k\}" );
        }
    }
    elsif ( !ref($cfg) ) {
        if ( !$ok->{$path} && eval "exists \$Foswiki::cfg$path" ) {
            print STDERR "Purge $path\n" if TRACE;
            eval "delete \$Foswiki::cfg$path";
            $purged = 1;
        }
    }
    return $purged;
}

# Purge Foswiki::cfg, removing items that have no spec, and nothing depends on.
sub _purgecfg {
    my $root = shift;

    # All specced keys are OK
    my %ok = map { $_ => 1 } $root->getAllKeys();

    # See if there are any dependencies between OK keys and other
    # keys
    my %deps;
    _findDependencies( \%deps );
    my $changed;
    do {
        $changed = 0;
        while ( my ( $k, $v ) = each %{ $deps{reverse} } ) {
            next unless $ok{$k} == 1;
            $ok{$k} = 2;

            # This key validates all the (non-ok) keys that it depends on
            foreach my $sk (@$v) {
                unless ( $ok{$sk} ) {
                    $ok{$sk} = 1;

                    #print STDERR "Adding $sk\n";
                    $changed = 1;
                }
            }
        }
    } while ($changed);

    # $ok now contains the set of keys that we want to keep
    return _purge( \%ok );
}

=pod

---+++ =changecfg=

Lets you change configuration values and clear them. Changes will be saved
without further checking. Takes two (optional) parameters:
   * =clear= - array of keys to delete from the configuration. Keys will be
     deleted even if they have a .spec entry.
   * =set= - hash mapping key names to new values. Clears are done *before*
     sets.

Result is a string reporting the outcome.

=cut

sub changecfg {
    my $params    = shift;
    my $changes   = $params->{set};      # expect a hash
    my $deletions = $params->{clear};    # expect an array of keys
    my $purge     = $params->{purge};    # purge unspecced keys
    my $added     = 0;
    my $changed   = 0;
    my $cleared   = 0;
    my $purged    = 0;

    # Reload Foswiki::cfg without expansions
    $Foswiki::cfg{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 1, 1 );

    # Pick up any missing config options from .spec
    my $root = _loadSpec();
    _addSpecDefaultsToCfg( $root, \%Foswiki::cfg );

    _getSetParams($params);

    if ($purge) {
        $purged = _purgecfg($root);
    }

    if ( defined $deletions ) {
        foreach my $key (@$deletions) {
            die "Bad key '$key'"
              unless $key =~
/^($Foswiki::Plugins::ConfigurePlugin::SpecEntry::configItemRegex)$/;

            # Implicit untaint
            $key = safeKeys($1);
            if ( eval "exists \$Foswiki::cfg$key" ) {
                print STDERR "Cleared $key\n" if TRACE;
                $cleared++;
            }
            eval "delete \$Foswiki::cfg$key";
        }
    }
    if ( defined $changes ) {
        while ( my ( $key, $value ) = each %$changes ) {
            die "Bad key '$key'"
              unless $key =~
/^($Foswiki::Plugins::ConfigurePlugin::SpecEntry::configItemRegex)$/;

            # Implicit untaint
            $key = safeKeys($1);
            if ( eval "exists \$Foswiki::cfg$key" ) {
                my $oval = eval "\$Foswiki::cfg$key";
                if ( ref($oval) || $oval =~ /^[0-9]+$/ ) {
                    if ( $oval != $value ) {
                        print STDERR "Changed $key\n" if TRACE;
                        $changed++;
                    }
                }
                else {
                    if ( $oval ne $value ) {
                        print STDERR "Changed $key\n" if TRACE;
                        $changed++;
                    }
                }
            }
            else {
                print STDERR "Added $key\n" if TRACE;
                $added++;
            }
            eval "\$Foswiki::cfg$key=\$value";
        }
    }
    if ( $changed || $added || $cleared || $purged ) {
        _save();
    }

    $Foswiki::cfg{ConfigurationFinished} = 0;
    Foswiki::Configure::Load::readConfig( 0, 1 );

    return
      "Added: $added; Changed: $changed; Cleared: $cleared; Purged: $purged";
}

# Traverse LSC generating LSC format output
sub _lscify {
    my ( $specs, $data, @path ) = @_;

    my @content;
    if ( scalar(@path) ) {
        my $keypath = '{' . join( '}{', @path ) . '}';

        my $spec = ( $specs->_keyCache->{$keypath} );
        if ( $spec && defined $spec->{keys} ) {

            # This is a specced level; we will take the entire data
            # under this point as the new value.
            # Stomp Foswiki::cfg with our new value for checking
            # and return
            unless ($@) {
                my $nval = eval "\$Foswiki::cfg$keypath";
                die $@ if $@;
                my $string = _value2string( $keypath, $nval );
                if ( DEBUG && defined $spec->{defined} ) {
                    push( @content,
                        '# ' . join( ':', @{ $spec->{defined} } ) . "\n" );
                }
                push( @content, $string );
                return \@content;
            }
        }
        elsif ( $spec && defined $spec->{title} ) {
            push( @content, "# $spec->{title}" );
        }
    }
    if ( ref($data) eq 'HASH' ) {
        foreach my $sk ( sort keys %$data ) {
            my $c = _lscify( $specs, $data->{$sk}, ( @path, safeKey($sk) ) );
            push( @content, @$c );
        }
    }
    else {

        # Something else; unspecced and not a hash.
        my $keypath = '{' . join( '}{', @path ) . '}';
        my $val     = eval "\$Foswiki::cfg$keypath";
        my $var     = _value2string( $keypath, $val );
        push( @content, "# UN.specCED\n" );
        push( @content, $var );
    }
    return \@content;
}

# Used to generate appropriate lines values for storing in LocalSite.cfg.
sub _value2string {
    my ( $kp, $val ) = @_;
    return Data::Dumper->Dump( [$val], ["\$Foswiki::cfg$kp"] );
}

sub _save {
    my $lsc = Foswiki::Plugins::ConfigurePlugin::SpecEntry::findFileOnPath(
        'Foswiki.spec')
      || '';
    $lsc =~ s/Foswiki\.spec/LocalSite.cfg/;
    print STDERR "LSC is at $lsc\n" if TRACE;

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
    my $root = _loadSpec();
    my $lines = _lscify( $root, \%Foswiki::cfg );
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

=pod

---+++ wizard

Call a configuration wizard.

Configuration wizards are modules that support complex operations on
configuration data; for example, auto-configuration of email and complex
and time-consuming integrity checks.

   * =wizard= - name of a wizard class to load
   * =keys= - name of a checker to use if =wizard= is not given
   * =method= - name of the method in the wizard or checker to call

The return result is a hash containing the following keys:
    * =report= - Error/Warning etc messages, formatted as HTML. Each
      entry in this array is a hash with keys 'level' (e.g. error, warning)
      and 'message'.
   * =changes= - This is a hash mapping changed keys to their new values

=cut

sub wizard {
    my $params = shift;

    my $target;
    if ( defined $params->{wizard} ) {
        die unless $params->{wizard} =~ /^(\w+)$/;    # untaint
        $target = Foswiki::Configure::Wizard::loadWizard( $1, $params );
    }
    else {
        die unless $params->{keys};
        my $root = _loadSpec();
        my $vob  = $root->getValueObject( $params->{keys} );
        $target = Foswiki::Configure::Checker::loadChecker($vob);
    }
    die unless $target;
    my $method = $params->{method};
    die unless $method =~ /^(\w+)$/;
    $method = $1;                                     # untaint
    my $reporter = Foswiki::Configure::Reporter->new();

    _getSetParams($params);

    $target->$method($reporter);

    my @report;
    foreach
      my $level ( 'errors', 'warnings', 'confirmations', 'notes', 'changes' )
    {
        push(
            @report,
            {
                level   => $level,
                message => $reporter->html($level)
            }
        ) if $reporter->has($level);
    }

    return { changes => $reporter->{changes}, report => \@report };
}

1;

__END__

Author: Crawford Currie http://c-dot.co.uk

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
