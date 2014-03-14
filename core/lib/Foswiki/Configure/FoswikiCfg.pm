# See bottom of file for license and copyright information
# Also documentation.

package Foswiki::Configure::FoswikiCfg;

use strict;
use warnings;

use Foswiki::Configure(qw/:DEFAULT :config :keys :util/);

use Data::Dumper ();

use Foswiki::Configure::Visitor ();
our @ISA = ('Foswiki::Configure::Visitor');

use Foswiki::Configure::Util      ();
use Foswiki::Configure::Section   ();
use Foswiki::Configure::Value     ();
use Foswiki::Configure::Pluggable ();
use Foswiki::Configure::Item      ();

our @errors;    # For external parsers.
our @warnings;

my %dupItem;

=begin TML

---++ ClassMethod new()

Used in saving, when we need a callback. Otherwise the methods here are
all static.

=cut

sub new {
    my $class = shift;

    return bless( {}, $class );
}

=begin TML

---++ StaticMethod load($root, $haveLSC)

Load the configuration declarations. The core set is defined in
Foswiki.spec, which must be found on the @INC path and is always loaded
first. Then find all settings for extensions in their .spec files.

This *only* reads type specifications, it *does not* read values.

SEE ALSO Foswiki::Configure::Load::readDefaults

   * $root Foswiki::Configure::Root of the model
   * $haveLSC if we have a LocalSite.cfg
   * $flags control data loaded
      * 1 - Verification not needed (e.g. Feedback)

If we don't have a LocalSite.cfg, only Foswiki.spec will be loaded
(Config.spec files from extensions will be skipped) and only the
first section of Config.spec will be loaded. This means that checkers
will only be built and run for that first section.

=cut

sub load {
    my ( $root, $haveLSC, $flags ) = @_;

    $flags ||= 0;

    my $file = Foswiki::Configure::Util::findFileOnPath('Foswiki.spec');
    if ($file) {
        _parse( $file, $root, $haveLSC );
    }
    if ($haveLSC) {

        # Blot out specs from the template EmptyPlugin
        my %read = ( EmptyPlugin => 1 );
        foreach my $dir (@INC) {
            _loadSpecsFrom( "$dir/Foswiki/Plugins", $root, \%read );
            _loadSpecsFrom( "$dir/Foswiki/Contrib", $root, \%read );
            _loadSpecsFrom( "$dir/TWiki/Plugins",   $root, \%read );
            _loadSpecsFrom( "$dir/TWiki/Contrib",   $root, \%read );
        }
    }

    return if ( $flags & 1 );

    # Verify values vs. specs

    {

        package Foswiki::Configure::FoswikiCfg::Verify;

        use Foswiki::Configure;

     # If spec files were parsed, but require failed, all kinds of trouble
     # follows because the UI has references, but there are no defaults.
     # Complicating matters, certain parameters in the spec file are
     # commented out so as to have NO default, but require initial setup.
     # These are classified as warnings here only if they have no current value.
     #
     # To try to report the trouble intelligently, we walk the UI and try
     # to fetch the value of each variable.

        require Foswiki::Configure::Root;
        require Foswiki::Configure::Valuer;

        require Foswiki::Configure::Visitor;
        our @ISA = ('Foswiki::Configure::Visitor');

        require Foswiki::Configure::Visitor;

        *stripTraceback = \&Foswiki::Configure::FoswikiCfg::stripTraceback;

        sub new {
            my $class = shift;
            return bless( {@_}, $class );
        }

        sub startVisit {
            my ( $this, $visitee ) = @_;

            if ( $visitee->isa('Foswiki::Configure::Value') ) {

                # See if this item is exempt

                return 1 if ( $visitee->{opts} =~ /\bU\b/ );
                my $valuer = $this->{valuer};

                my $ok = eval {
                    return defined $valuer->currentValue($visitee)
                      && defined $valuer->defaultValue($visitee);
                };
                return 1 if ($ok);

              # Sone dynamically-created items (e.g. Languages) don't have defs;
              # Presumably they can cope with missing keys...

                return 1 unless ( exists $visitee->{_defined} );

       # Known items materialized without a .spec entry can provide a default.
       # All items from the spec files record file and line for diagnostics
       # Spec file items that are optional (commented-out for guessing support)
       # provide the default as "undef"; we set based on type, but don't report.

                my @defs = @{ $visitee->{_defined} };
                my ( $file, $line, $default ) = @defs;
                $file = $$file;

                my $keys = $visitee->getKeys();

                # If no default, try to muddle along so these can be reported

                unless ( defined $default ) {
                    my $type =
                      Foswiki::Configure::Type::load( $visitee->{typename},
                        $keys );

                    #if ( $type->isa('Foswiki::Configure::Types::HASH' )) {
                    #    $default = {};
                    #}
                    #elsif ( $type->isa('Foswiki::Configure::Types::ARRAY' )) {
                    #    $default = [];
                    #}
                    #els
                    if ( $type->isa('Foswiki::Configure::Types::PERL') ) {

                        # Could be 'string' or {hash} but no way to guess.
                        $default = [];
                    }
                    elsif ($type->isa('Foswiki::Configure::Types::BOOLEAN')
                        || $type->isa('Foswiki::Configure::Types::NUMBER') )
                    {
                        $default = 0;
                    }
                    else {
                        $default = '';
                    }
                }

                my $hasMissingValue;
                eval
"\$hasMissingValue = !exists \$cfg$keys || !ref( \$cfg$keys) && \$cfg$keys =~ /NOT SET/;\n\$cfg$keys = \$default unless( exists \$cfg$keys ); \$Foswiki::defaultCfg->$keys = \$default unless( exists \$Foswiki::defaultCfg->$keys );";

                # Report unless default was provided by the item.

                if ( @defs <= 2 ) {
                    push @Foswiki::Configure::FoswikiCfg::errors,
                      [
                        $file,
                        $line,
                        "$keys is missing or undefined in configuration: "
                          . stripTraceback($@)
                      ];
                }
                else {
                    if ( !defined $defs[2] && $hasMissingValue ) {
                        push @Foswiki::Configure::FoswikiCfg::warnings,
                          [
                            $file,
                            $line,
                            "$keys is missing or undefined in configuration: "
                              . stripTraceback($@)
                          ];
                    }
                }
            }
            return 1;
        }

        sub endVisit {
            my ( $this, $visitee ) = @_;

            return 1;
        }

        my $valuer =
          new Foswiki::Configure::Valuer( $Foswiki::defaultCfg, \%cfg );
        my $this = Foswiki::Configure::FoswikiCfg::Verify->new(
            valuer => $valuer,
            root   => $root,
        );
        $root->visit($this);
    }
    if ( @errors || @warnings ) {
        my $errors = SectionMarker->new( 0, qq{Configuration file errors} );
        if (@errors) {
            $errors->addToDesc(
"<p>Errors were detected in component specification files.  Contact the developer of the associated component to have them corrected.<ul>"
            );
            foreach my $error (@errors) {
                $errors->addToDesc(
                    "<li>$error->[2]"
                      . (
                        $error->[0]
                        ? " in $error->[0] at line $error->[1]"
                        : ''
                      )
                      . "</li>"
                );
            }
            $errors->addToDesc("</ul>");
        }
        if (@warnings) {
            $errors->addToDesc(
"<p>Configuration items are missing from your site configuration file. Please define them and save your configuration before proceeding.<ul>"
            );
            foreach my $warning (@warnings) {
                $errors->addToDesc(
                    "<li>$warning->[2]"
                      . (
                        $warning->[0]
                        ? " in $warning->[0] at line $warning->[1]"
                        : ''
                      )
                      . "</li>"
                );
            }
            $errors->addToDesc("</ul>");
        }
        my $item = new Foswiki::Configure::Value( 'BOOLEAN', keys => 'DUMMY' );
        _extractSections( [ $errors, $item ], $root );

        $item->inc('errors') foreach (@errors);
        {
            no warnings 'once';
            $Foswiki::Configure::UI::toterrors += @errors;
            $item->inc('warnings') foreach (@warnings);
            $Foswiki::Configure::UI::totwarnings += @warnings;
        }
        delete $item->{parent}{children};
        delete $item->{parent}{values};
        undef $item;
    }

}

# Strip traceback from die and carp for a user message

sub stripTraceback {
    my $message = shift;

    return '' unless ( length $message );

    return $message if ( $cfg::{DebugTracebacks} );

    $message = ( split( /\n/, $message ) )[0];
    $message =~ s/ at .*? line \d+\.$//;
    return $message;
}

sub _loadSpecsFrom {
    my ( $dir, $root, $read ) = @_;

    return unless opendir( D, $dir );
    foreach my $extension ( grep { !/^\./ } readdir D ) {
        next if $read->{$extension};
        $extension =~ /(.*)/;
        $extension = $1;    # untaint
        my $file = "$dir/$extension/Config.spec";
        next unless -e $file;
        _parse( $file, $root, 1 );
        $read->{$extension} = $file;
    }
    closedir(D);
}

###########################################################################
## INPUT
###########################################################################
{

    # Inner class that represents section headings temporarily during the
    # parse. They are expanded to section blocks at the end.
    package SectionMarker;
    @SectionMarker::ISA = ('Foswiki::Configure::Item');

    use Foswiki::Configure;

    sub new {
        my ( $class, $depth, $head ) = @_;
        my $this = bless( {}, $class );
        $this->{depth} = $depth + 1;
        $this->{head}  = $head;
        return $this;
    }

    sub getValueObject { return; }
}

# Process the config array and add section objects
sub _extractSections {
    my ( $settings, $root ) = @_;

    my $section = $root;
    my $depth   = 0;

    foreach my $item (@$settings) {
        if ( $item->isa('SectionMarker') ) {
            my $opts = '';
            if ( $item->{head} =~ s/^(.*?)\s*--\s*(.*?)\s*$/$1/ ) {
                $opts = $2;
            }
            my $ns =
              $root->getSectionObject( $item->{head}, $item->{depth} + 1 );
            if ($ns) {
                $depth = $item->{depth};
            }
            else {
                while ( $depth > $item->{depth} - 1 ) {
                    $section = $section->{parent};
                    $depth--;
                }
                while ( $depth < $item->{depth} - 1 ) {
                    my $ns = new Foswiki::Configure::Section('');
                    $section->addChild($ns);
                    $section = $ns;
                    $depth++;
                }
                $ns = new Foswiki::Configure::Section( $item->{head}, $opts );
                $ns->{desc} = $item->{desc};
                $section->addChild($ns);
                $depth++;
            }
            $section = $ns;
        }
        elsif ( $item->isa('Foswiki::Configure::Value') ) {

            # Skip it if we already have a settings object for these
            # keys (first loaded always takes precedence, irrespective
            # of which section it is in)
            my $vo = $root->getValueObject( $item->getKeys() );
            next if ($vo);
            $section->addChild($item);
        }
        else {
            $section->addChild($item);
        }
    }
}

# See if we have already build a value object for these keys
sub _getValueObject {
    my ( $keys, $settings ) = @_;
    foreach my $item (@$settings) {
        my $i = $item->getValueObject($keys);
        return $i if $i;
    }
    return;
}

# Parse the config declaration file and return a root node for the
# configuration it describes

sub _parse {
    my ( $file, $root, $haveLSC ) = @_;

    open( F, '<', $file ) || return '';
    local $/ = "\n";
    my $open = undef;    # current setting or section
    my $isEnhancing = 0; # Is the current $open an existing item being enhanced?
    my @settings;
    my $sectionNum = 0;

    while ( my $l = <F> ) {
        $l =~ s/\r//g;

        # Continuation lines

        while ( $l =~ /\\$/ && !eof F ) {
            my $cont = <F>;
            $cont =~ s/\r//g;
            $cont =~ s/^#// if ( $l =~ /^#/ );
            $cont =~ s/^\s*//;
            chomp $l;
            unless ( $cont =~ /^#/ ) {
                chop $l;
                $l .= $cont;
            }
        }
        if ( $l =~ /\\$/ ) {
            push @errors,
              [ $file, $., "Reached end-of-file, continuation expected" ];
            next;
        }

        last if ( $l =~ /^1;|^__\w+__/ );
        next if ( $l =~ /^\s*$/ || $l =~ /^\s*#!/ );

        if ( $l =~ /^#\s*\*\*\s*([A-Z]+)\s*(.*?)\s*\*\*\s*$/ ) {

            # **STRING 30 EXPERT**
            _pusht( \@settings, $open ) if $open;
            if ( $1 eq 'ENHANCE' ) {

                # Enhance the description of an existing value
                $open        = $root->getValueObject($2);
                $isEnhancing = 1;
            }
            else {
                $open = new Foswiki::Configure::Value( $1, opts => $2 );
                $isEnhancing = 0;
            }
        }

        elsif ( $l =~ /^(#)?\s*\$(?:(?:Fosw|TW)iki::)?cfg([^=\s]*)\s*=(.*)$/ ) {

            # $Foswiki::cfg{Rice}{Brown} =
            my $optional = $1;
            my $keys     = $2;
            unless ( $keys =~ /^$configItemRegex$/ ) {
                push @errors, [ $file, $., 'Invalid item specifier $keys' ];
                undef $open;
                next;
            }

            #            my $tentativeVal = $3; # Possibly line 1 of many
            if ( $open && $open->isa('SectionMarker') ) {
                _pusht( \@settings, $open );
                undef $open;
            }

            # If there is already a UI object for
            # these keys, we don't need to add another. But if there
            # isn't, we do.
            if ( !$open ) {
                next if $root->getValueObject($keys);

                # A pluggable may have already added an entry for these keys
                next if ( _getValueObject( $keys, \@settings ) );

                # This is an untyped value.
                $open        = new Foswiki::Configure::Value('UNKNOWN');
                $isEnhancing = 0;
            }
            $open->set( _defined =>
                  ( $optional ? [ \$file, $., undef ] : [ \$file, $. ] ) );

            # All spec file items are in audit group PARS, button 0
            $open->addAuditGroup(qw/PARS:0/)
              if ( $open->isa('Foswiki::Configure::Value') );
            $open->set( keys => $keys );
            _pusht( \@settings, $open );
            $open        = undef;
            $isEnhancing = 0;
        }

        elsif ( $l =~ /^#\s*\*([A-Z]+)\*/ ) {

            # *FINDEXTENSIONS*
            my $pluggable = $1;
            my $p         = eval {
                Foswiki::Configure::Pluggable::load( $pluggable, $file, $root,
                    \@settings );
            };
            if ($p) {
                if ( $open && !$isEnhancing ) {
                    if ( $open->isa('Foswiki::Configure::Value') ) {
                        my $otype = $open->getTypeName;
                        push @errors,
                          [ $file, $., "Incomplete $otype declaration" ];
                    }
                    else {
                        _pusht( \@settings, $open );
                    }
                }
                if ( ref($p) eq 'ARRAY' ) {
                    _pusht( \@settings, $_ ) foreach (@$p);
                    $open = undef;
                }
                elsif ( ref $p ) {
                    $open = $p;
                }
                else {    # Pluggable took control
                    $open = undef;
                }
            }
            else {
                push @errors,
                  [
                    $file, $.,
                    "Can't load configuration plugin $pluggable: "
                      . stripTraceback($@)
                  ];
                if ($open) {

                    # Not recognised
                    # $l =~ s/^#\s?//;
                    #  $open->addToDesc($l);
                    undef $open;
                }
            }
            $isEnhancing = 0;
        }

        elsif ( $l =~ /^#\s*---\+(\+*) *(.*?)$/ ) {

            # ---++ Section
            # Only load the first section if we don't have LocalSite.cfg
            last if ( $sectionNum && !$haveLSC );
            $sectionNum++;
            if ( $open && !$isEnhancing ) {

               # We have an open item.  If it's a value, we don't want to create
               # it since that will confuse the UI.  Report such errors.
                if ( $open->isa('Foswiki::Configure::Value') ) {
                    my $otype = $open->getTypeName;
                    push @errors,
                      [ $file, $., "Incomplete $otype declaration" ];
                }
                else {
                    _pusht( \@settings, $open );
                }
            }
            $open = new SectionMarker( length($1), $2 );
            $isEnhancing = 0;
        }

        elsif ( $l =~ /^#\s?(.*)$/ ) {

            # Bog standard comment
            $open->addToDesc($1) if $open;
        }
    }
    close(F);
    if ( $open && !$isEnhancing ) {
        if ( $open->isa('Foswiki::Configure::Value') ) {
            my $otype = $open->getTypeName;
            push @errors, [ $file, $., "Incomplete $otype declaration" ];
        }
        else {
            _pusht( \@settings, $open );
        }
    }
    _extractSections( \@settings, $root );
}

sub _pusht {
    my ( $a, $n ) = @_;
    Carp::confess "_pusht called with undef" if ( !defined $n );
    foreach my $v (@$a) {

        # OK IFF we are processing **ENHANCE**
        return if ( $v eq $n );
    }
    push( @$a, $n );
}

###########################################################################
## OUTPUT
###########################################################################

=begin TML

---++ StaticMethod save($root, $valuer, $logger, $insane)
   * $root is a Foswiki::Configure::Root
   * $valuer is a Foswiki::Configure::Valuer
   * $logger an object that implements a logChange($keys,$value) method,
     called to record the changes.
   * $insane set to true if existing LocalSite.cfg should be overwritten

Generate .cfg file format output

=cut

sub lscFileName {
    my $lsc = Foswiki::Configure::Util::findFileOnPath('LocalSite.cfg');

    return $lsc if ($lsc);

    # If not found on the path, park it beside Foswiki.spec
    $lsc = Foswiki::Configure::Util::findFileOnPath('Foswiki.spec') || '';
    $lsc =~ s/Foswiki\.spec/LocalSite.cfg/;

    return $lsc;
}

sub save {
    my ( $root, $valuer, $logger, $insane ) = @_;

    # Object used to act as a visitor to hold the output
    my $this = new Foswiki::Configure::FoswikiCfg();
    $this->{logger}  = $logger;
    $this->{valuer}  = $valuer;
    $this->{root}    = $root;
    $this->{content} = '';

    my $lsc = lscFileName();

    my ( @backups, $backup );
    while ( -f $lsc ) {
        if ( open( F, '<', $lsc ) ) {
            local $/ = undef;
            $this->{content} = <F>;
            close(F);
        }
        else {
            last if ( $!{ENOENT} );    # Race: file disappeared
            die "Unable to read $lsc: $!\n";    # Serious error
        }

        $cfg{MaxLSCBackups} ||= 0;

        last unless ( $cfg{MaxLSCBackups} );

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
            print F $this->{content};
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

    $this->{oldContent} = $this->{content} || '';

    if ( $insane || !-f $lsc ) {
        $this->{content} = <<'HERE';
# Local site settings for Foswiki. This file is managed by the 'configure'
# CGI script, though you can also make (careful!) manual changes with a
# text editor.  See the Foswiki.spec file in this directory for documentation
# Extensions are documented in the Config.spec file in the Plugins/<extension>
# or Contrib/<extension> directories  (Do not remove the following blank line.)

HERE
    }

    # Clean out deprecated settings, so they don't occlude the
    # replacements
    {
        no warnings 'once';
        foreach my $key ( keys %Foswiki::Configure::Load::remap ) {
            $this->{content} =~ s/\$Foswiki::cfg$key\s*=.*?;\s*//sg;
        }
    }

    # Sort keys so it's possible to diff LSC files.
    local $Data::Dumper::Sortkeys = 1;

    $this->_save();

    my $msg = '';

    if ( ( $this->{content} || '' ) ne $this->{oldContent} ) {
        my $um = umask(007);   # Contains passwords, no world access to new file
        open( F, '>', $lsc )
          || die "Could not open $lsc for write: $!\n";
        print F $this->{content};
        close(F) or die "Close failed for $lsc: $!\n";
        umask($um);
        if ( $backup && ( my $max = $cfg{MaxLSCBackups} ) >= 0 ) {
            while ( @backups > $max ) {
                my $n = pop @backups;
                unlink "$lsc.$n";
            }
            $msg = "<br />Previous configuration saved in $backup\n";
        }
        $msg = "New configuration saved in $lsc\n$msg";
    }
    else {
        unlink $backup if ($backup);
        $msg = "No change made to $lsc\n";
    }
    delete $this->{oldContent};
    return $msg;
}

sub _save {
    my $this = shift;

    %dupItem = ();
    my %requires;

    $this->{content} =~ s/^\s*1;\s*\n//msg;
    $this->{content} =~ s/^\s*require\s+([^;]+);\n/$requires{$1} = 1; ''/msge;

    $this->{requires} = \%requires;

    # Sort the resulting data by hash key.  Attaches any comments to the
    # following item.  Requires blank line after header to differentiate
    # file block comment from comment on first item.  Alternate (old
    # standard) is to leave (mostly) in .spec file order.
    # Turning this on may have compatibility issues, and I'm not sure what
    # it gains. The consequences are more worrisome than the mechanics...

    if (0) {
        my $header = '';
        my @content = split( /\r?\n/, $this->{content} );

        while ( @content && $content[0] =~ /^\s*#/ ) {
            $header .= "$content[0]\n";
            shift @content;
        }
        if ( @content && $content[0] =~ /^\s*$/ ) {
            $header .= "$content[0]\n";
            shift @content;
        }

        my $content;
        if (@content) {
            $content = join( "\n", @content ) . "\n";
        }
        else {
            $content = '';
        }
        $this->{content} = $content;
        @content = ();

        $this->{root}->visit($this);

        my %content;
        $content = $this->{content};
        $content =~
s/\A(.*?^\s*?\$(?:Foswiki::)?cfg($configItemRegex)\s*=.*?;\n)/push @content, $2; $content{$2} = $1;''/msge;

        my $trailer = $content;

        $content = $header;
        $content .= "require $_;\n" foreach ( sort keys %requires );
        $content .= $content{$_} foreach ( sortHashkeyList(@content) );
        $this->{content} = "$content${trailer}1;\n";
    }
    else {
        $this->{root}->visit($this);
        my $requires = '';
        $requires .= "require $_;\n" foreach ( sort keys %requires );
        $this->{content} =~ s/\A((?:^#[^\n]*\n)*)/$1$requires/ms if ($requires);
        $this->{content} .= "1;\n";
    }
    delete $this->{requires};
}

# Visitor method called by node traversal during save. Incrementally modify
# values, unless a value is reverting to undefined, in which case remove it.
sub startVisit {
    my ( $this, $visitee ) = @_;

    return 1 unless ( $visitee->isa('Foswiki::Configure::Value') );

    my $keys     = $visitee->getKeys();
    my $typeName = $visitee->getTypeName();

    return 1
      if ( $keys =~ /^\{ConfigureGUI\}/
        || $typeName eq 'NULL' );

    my $value = $this->{valuer}->currentValue($visitee);

    my $logValue;
    if ( defined $value ) {
        my $type = $visitee->getType;
        $logValue = $visitee->asString( $this->{valuer} )
          if ( $this->{logger} );
        my ( $txt, $require ) = $type->value2string( $keys, $value, $logValue );
        if ( defined $require ) {
            if ( ref $require ) {
                $this->{requires}{$_} = 1 foreach (@$require);
            }
            else {
                $this->{requires}{$require} = 1;
            }
        }

        # Substitute any existing value, or append if not there

        $this->{content} .= $txt
          unless ( $this->{content} =~
s/^\s*\$(?:Foswiki::)?cfg$keys\s*=.*?;\n/_updateEntry($keys,$txt)/msge
          );
    }
    else {
        $logValue = '<--undefined-->';
        $this->{content} =~ s/^\s*?\$(?:Foswiki::)?cfg$keys\s*=.*?;\n//msg;
    }

    $this->{logger}->logChange( $keys, $logValue )
      if ( $this->{logger} );

    return 1;
}

sub _updateEntry {
    my $keys     = shift;
    my $newentry = shift;
    return '' if $dupItem{"$keys"};
    $dupItem{"$keys"} = 1;
    return $newentry;
}

sub endVisit {
    my ( $this, $visitee ) = @_;

    return 1;
}

1;
__END__

=begin TML

---+ package Foswiki::Configure::FoswikiCfg

This is both a parser for configuration declaration files, such as
FoswikiCfg.spec, and a serialisation visitor for writing out changes
to LocalSite.cfg

The supported syntax in declaration files is as follows:
<verbatim>
cfg ::= ( setting | section | extension )* ;
setting ::= BOL typespec EOL comment* BOL def ;
typespec ::= "**" typeid options "**" ;
def ::= "$" ["Foswiki::"] "cfg" keys "=" value ";" ;
keys ::= ( "{" id "}" )+ ;
value is any perl value not including ";"
comment ::= BOL "#" string EOL ;
section ::= BOL "#--+" string ( "--" options )? EOL comment* ;
extension ::= BOL " *" id "*"
EOL ::= end of line
BOL ::= beginning of line
typeid ::= id ;
id ::= a \w+ word (legal Perl bareword)
</verbatim>

A *section* is simply a divider used to create blocks. It can
  have varying depth depending on the number of + signs and may have
  options after -- e.g. #---+ Section -- TABS EXPERT

A *setting* is the sugar required for the setting of a single
  configuration value.

An *extension* is a pluggable UI extension that supports some extra UI
  functionality, such as the menu of languages or the menu of plugins.

Each *setting* has a *typespec* and a *def*.

The typespec consists of a type id and some options. Types are loaded by
type id from the Foswiki::Configure::Types hierachy - for example, type
BOOLEAN is defined by Foswiki::Configure::Types::BOOLEAN. Each type is a
subclass of Foswiki::Configure::Type - see that class for more details of
what is supported.

A *def* is a specification of a field in the $Foswiki::cfg hash,
together with a perl value for that hash. Each field can have an
associated *Checker* which is loaded from the Foswiki::Configure::Checkers
hierarchy. Checkers are responsible for specific checks on the value of
that variable. For example, the checker for $Foswiki::cfg{Banana}{Republic}
will be expected to be found in
Foswiki::Configure::Checkers::Banana::Republic.
Checkers are subclasses of Foswiki::Configure::Checker. See that class for
more details.

An *extension* is a placeholder for a pluggable UI module (a class in
Foswiki::Configure::Checkers::UIs)

=cut

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
