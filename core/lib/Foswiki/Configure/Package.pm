# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Package

Support for installing/removing extension packages.
Objects of this class represent an installed or installable
Foswiki Extension.

To the caller, the Package object carries the manifest of the package,
and provides methods for loading the manifest from an extension installer,
and for backing up, installing or removing an Extension from the Foswiki
installation.

The internal storage of the manifest is as a hash.  The hash is populated
as two possible views:
   * File View - lists the attributes of each file in the package
   * Attachment View - list the files to be attached to each topic.

Pictorially,

   * MANIFEST
      * ={path/file.name}=  Distributed filename root is Foswiki root.
         * ={ci}= - Flag specifying if file should be checked into the revision control system
         * ={perms}= - File permissions in Linux octal string format
         * ={md5}= - MD5 checksum of file - optional
         * ={web}= - Web/Subweb name if topic or attachment
         * ={topic}= - Topic name if topic or attachment
         * ={attach}= - Attachment name if attachment
      * ={ATTACH}=
         * ={Web/Subweb/Topic}=
            * {AttachmentName} = Filename of the attachment.


=cut

package Foswiki::Configure::Package;

use strict;
use warnings;
use Error qw(:try);
use File::stat;    # Need to import functions!
use File::Copy            ();
use File::Copy::Recursive ();
use File::Spec            ();
use File::Path            ();
use File::Temp            ();
use Assert;
use Foswiki::Configure::Dependency ();
use Foswiki::Configure::FileUtil   ();
use Foswiki::Configure::Root       ();
use Foswiki::Plugins               ();

our $FALSE = 0;
our $TRUE  = 1;

############# GENERIC METHODS #############

=begin TML

---++ ClassMethod new(%options)
   * =%options= - A hash of options for the installation
      * =root=       => 'path'  The root path of the Foswiki installation used for file operations - REQUIRED
      * =module=     => 'name'  Name of the package being installed - REQUIRED
      * =repository= => hash    The source repository information, built from $Foswiki::cfg{ExtensionsRepositories}
      * =DIR=        => 'dir'   Directory containing expanded package,  Used with EXPANDED => 1
      * =EXPANDED=   => 0/1     Specify that archive file has already been expanded (for unit tests)
      * =USELOCAL=   => 0/1     If local versions of _installer or archives are found, use them instead of download.
      * =NODEPS=     => 0/1     Set if dependencies should not be installed.  Default is to always install Foswiki dependencies.
                                (CPAN and external dependencies are not handled by this module.)
      * =SIMULATE=   => 0/1     Set to 1 if actions should be simulated - no file system modifications other than temporary files.
      * =ENABLE=     => 0/1     Set to 0 to prevent extension from being enabled.  Defaults to ENABLE => 1
      * seen         => \%seen  Hash of modules already seen, to be installed.
      * =CONTINUE=   => ... (FUTURE) ... continue processing after errors.  Not implemented

=cut

sub new {
    my ( $class, %args ) = @_;
    my @deps;

    ASSERT( $args{root} )   if DEBUG;
    ASSERT( $args{module} ) if DEBUG;

    my $repo = $args{repository};
    delete $args{repository};
    my $root = $args{root};
    delete $args{root};
    my $module = $args{module};
    delete $args{module};

    my $seen = $args{seen} || {};
    $seen->{$module} = 1;

    my $this = bless(
        {
            _root       => $root,
            _pkgname    => $module,
            _repository => $repo,
            _options    => \%args,

            # Hash mapping the topics, attachment and other files
            # supplied by this package
            _manifest => undef,

            # Array of dependencies required by this package
            _dependencies => \@deps,
            _prepost_code => undef,
            _loaded       => undef,    # Flag set if loadInstaller is complete

            # Hash of package names that have already been seen / installed
            _seen => $seen,
        },
        $class
    );

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Clean up the object, releasing any memory stored in it.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{_root};
    undef $this->{_pkgname};
    undef $this->{_type};
    undef $this->{_options};
    undef $this->{_manifest};
    undef $this->{_dependencies};
    undef $this->{_prepost_code};
    undef $this->{_loaded};

    for (qw( preinstall postinstall preuninstall postuninstall )) {
        undef &{$_};
    }

}

=begin TML

---++ ObjectMethod module()

Get module name.

=cut

sub module {
    my ($this) = @_;

    return $this->{_pkgname};
}

=begin TML

---++ ObjectMethod repository()

Get repository.

=cut

sub repository {
    my ($this) = @_;

    return $this->{_repository};
}

=begin TML

---++ ObjectMethod option($name [, $value]))

Get or set the option associated with the object.

=cut

sub option {
    my ( $this, $name, $value ) = @_;

    $this->{_options}->{$name} = $value if scalar(@_) == 3;
    return $this->{_options}->{$name};
}

{
    # Subclass of reporter that writes reports to a file
    # as well as passing them to another logger.
    # TODO: abstract this out and share with tools/extender.pl
    package LoggingReporter;

    # $super - Foswiki::Configure::Reporter to pass all reports to
    # %options can include:
    #  filename => Override of generated name including path
    #  action   => Action - Install, Remove etc.
    #  path     => Override the default logging path
    #  pkgname  => name of package being installed
    #  nolog    => if true, don't log to file
    # Default name:  pkgname-[action]-yyyymmdd-hhmmss.log
    sub new {
        my ( $class, $super, %options ) = @_;
        my $this = bless( { _reporter => $super }, $class );
        if ( $options{filename} ) {
            $this->{_logfile} = $options{filename};
        }

        my $action = ( defined $options{action} ) ? $options{action} : 'run';
        my $path =
          ( defined $options{path} )
          ? $options{path}
          : "$Foswiki::cfg{Log}{Dir}/configure";
        my $timestamp =
          Foswiki::Time::formatTime( time(),
            '$year$mo$day-$hours$minutes$seconds' );
        $options{pkgname} ||= '';
        $this->{_logfile} = $path . "/$options{pkgname}-$timestamp-$action.log";
        Foswiki::Configure::Load::expandValue( $this->{_logfile} );
        return $this;
    }

    sub _log {
        my $this = shift;
        use filetest 'access';

        # Don't actually write any logs if simulating the install
        return if $this->{nolog};

        my $text = join( "\n", @_ ) . "\n";

        # Take out block formatting tags
        $text =~ s/<\/?verbatim>//g;

        # Take out active elements
        $text =~ s/<button.*?<\/button?//g;

        unless ( -e $this->{_logfile} ) {
            my @path =
              split( /[\/\\]+/, $this->{_logfile}, -1 ); # -1 allows directories
            pop(@path);
            if ( scalar(@path) ) {
                umask( oct(777) - $Foswiki::cfg{Store}{dirPermission} );
                File::Path::mkpath( join( '/', @path ),
                    0, $Foswiki::cfg{Store}{dirPermission} );
            }
        }

        if ( open( my $file, '>>', Foswiki::encode_utf8( $this->{_logfile} ) ) )
        {
            binmode $file, ":encoding(utf-8)";
            print $file $text;
            close($file);
        }
        else {
            if ( !-w $this->{_logfile} ) {
                die "ERROR: Could not open logfile "
                  . $this->{_logfile}
                  . " for write. Your admin should 'configure' now and fix the errors!";
            }

            # die to force the admin to get permissions correct
            die 'ERROR: Could not write to ' . $this->{_logfile} . ": $!";
        }
    }

    sub NOTE {
        my $this = shift;

        $this->{_reporter}->NOTE(@_);
        $this->_log(@_);
    }

    sub WARN {
        my ( $this, @p ) = @_;
        return unless scalar(@p);
        $this->{_reporter}->WARN(@p);
        unless ( $p[0] =~ s/^>/> *WARNING:* / ) {
            $p[0] = "> *WARNING:* ";
        }
        $this->_log(@p);
    }

    sub ERROR {
        my ( $this, @p ) = @_;
        return unless scalar(@p);
        $this->{_reporter}->ERROR(@p);
        unless ( $p[0] =~ s/^>/> *ERROR:* / ) {
            $p[0] = "> *ERROR:* ";
        }
        $this->_log(@p);
    }

    sub CHANGED {
        my ( $this, $keys ) = @_;
        $this->{_reporter}->CHANGED($keys);
        my $val = $this->{_reporter}->{changes}->{$keys};
        $this->_log("> _Changed:_ $keys = $val");
    }

    sub WIZARD {
        return shift->{_reporter}->WIZARD(@_);
    }

    sub messages {
        return shift->{_reporter}->messages(@_);
    }

    sub changes {
        return shift->{_reporter}->changes(@_);
    }
}

=begin TML

---++ ObjectMethod install($reporter) -> ($boolean, \%plugins, \$cpanDeps)

Perform a full installation of the package, including all dependencies
and any required downloads from the repository.

A backup is taken before any changes are made to the file system.

Missing directories are created as required.  The files are mapped into
non-standard locations by _mapTarget.  If a file is
read-only, it is temporarily overridden and the mode of the file is
restored after the move.

Unless the !noci flag is set in the manifest, files are "checked in"
by creating a Topic Meta object and using the Foswiki Meta API to save
the topic.

Returns a status (1 is good) and two hashes, one of installed plugins and
the other of required CPAN dependencies.

=cut

sub install {
    my ( $this, $supereporter, $spec ) = @_;

    my $reporter = LoggingReporter->new(
        $supereporter,
        action  => 'Install',
        pkgname => $this->{_pkgname},
        nolog   => $this->option('SIMULATE')
    );

    $reporter->NOTE("---+ Installing $this->{_pkgname}");

    unless ( $this->{_loaded} ) {

        # Recover the manifest from the _installer file
        $reporter->NOTE("> Loading package installer");

        # Don't try to continue if installer could not be loaded.
        return (0) unless $this->loadInstaller($reporter);
    }

    my ( $installed, $missing, $wiki, $cpan, $manual ) =
      $this->checkDependencies();

    # $wiki, $cpan and $manual are array references to array
    # of Dependency objects

    if ( $installed || $missing ) {
        $reporter->NOTE("---++ Dependency Report for $this->{_pkgname} ...");
        $reporter->NOTE( "> *INSTALLED*", map { "\t* $_" } @$installed )
          if (@$installed);
        $reporter->WARN( "> *MISSING*", map { "\t* $_" } @$missing )
          if (@$missing);
    }

    my $depPlugins;    # hashref to hash of plugin names
    my $depCPAN;       # hashref to hash of cpan dependency names
    unless ( $this->option('NODEPS') ) {

        # Don't log these results - each package uses it's own logfile
        my ( $depPlugins, $depCPAN ) =
          $this->_installDependencies( $supereporter, $spec );
    }

    # Create a backup of the previous install if any
    $reporter->NOTE("---+++ Creating backup of $this->{_pkgname} ...");
    my $ok = $this->_createBackup($reporter);

    my %plugins;
    my %cpanDeps;

    if ($ok) {    # If backup failed don't proceed

        $this->_loadExits();

        if ( $this->can('preinstall') && !$this->option('SIMULATE') ) {
            $reporter->NOTE("> Running pre-install for $this->{_pkgname} ...");
            my $rslt = $this->preinstall();
            $reporter->NOTE("<verbatim>$rslt</verbatim>") if $rslt;
        }

        $ok = $this->_install( $reporter, $spec );    # and do the installation

        return (0) unless $ok;
        if ( $this->can('postinstall')
            && !$this->option('SIMULATE') )
        {
            $reporter->NOTE("> Running post-install for $this->{_pkgname}...");
            my $rslt = $this->postinstall();
            $reporter->NOTE("<verbatim>$rslt</verbatim>") if $rslt;
        }
    }
    %plugins = $this->_listPlugins()
      ;    # Retrieve a list of any plugin modules installed by this package.
    @plugins{ keys %$depPlugins } = values %$depPlugins; # merge in dependencies

    foreach my $cpdep (@$cpan) {
        $cpanDeps{ $cpdep->{module} } = $cpdep;
    }
    @cpanDeps{ keys %$depCPAN } =
      values %$depCPAN;    # merge in cpan from dependencies

    my $extUrl =
      $Foswiki::Plugins::SESSION
      ? Foswiki::Func::getScriptUrl( $Foswiki::cfg{SystemWebName},
        $this->{_pkgname}, 'view' )
      : '';
    my $instUrl =
      $Foswiki::Plugins::SESSION
      ? Foswiki::Func::getScriptUrl( $Foswiki::cfg{SystemWebName},
        'InstalledPlugins', 'view' )
      : '';

    $reporter->NOTE( <<WRAPUP );
> Before proceeding, review the dependency reports of each installed extension
  and resolve any dependencies, as required.
   * External non-perl dependencies are never automatically resolved by Foswiki.
   * Dependencies noted as 'Optional' will not be automatically resolved, and
   * CPAN dependencies are never automatically resolved.

> After your configuration has been saved:
   * Visit <a href="$extUrl" target="_blank">$this->{_pkgname} extension page</a>
   * Check <a href="$instUrl" target="_blank">InstalledPlugins</a> to check for errors.
WRAPUP

    if ( keys %cpanDeps ) {
        $reporter->WARN(<<HERE);
> CPAN dependencies were detected, but will not be automatically
installed by the Web installer.  The following dependencies should be
manually resolved as required.
HERE
        foreach my $dep ( sort { lc($a) cmp lc($b) } keys %cpanDeps ) {
            $reporter->NOTE("\t* $dep");
        }
        $reporter->NOTE("");
    }

    $reporter->NOTE(<<HERE);
> The following configuration changes are needed to enable plugins.
These will be automatically applied when the configuration is saved.
HERE

    my $enabled =
      ( defined $this->option('ENABLE') ) ? $this->option('ENABLE') : 1;

    $reporter->NOTE("> Simulated:") if ( $this->option('SIMULATE') );
    foreach my $plu ( sort { lc($a) cmp lc($b) } keys %plugins ) {
        my $clef = "{Plugins}{$plu}";
        if ( $this->option('SIMULATE') ) {
            $reporter->NOTE("\t* ${clef}{Enabled} = $enabled");
        }
        else {
            eval("\$Foswiki::cfg${clef}{Enabled}=$enabled");
            $reporter->CHANGED("{Plugins}{$plu}{Enabled}");

            # Add it to the $spec
            $spec->addChild(
                Foswiki::Configure::Value->new(
                    'BOOLEAN',
                    LABEL   => $plu,
                    keys    => "{Plugins}{$plu}{Enabled}",
                    CHECKER => 'PLUGIN_MODULE',
                    default => '1'
                )
            );
        }

        if ( $this->option('SIMULATE') ) {
            $reporter->NOTE("\t* ${clef}{Module} = 'Foswiki::Plugins::$plu'");
        }
        else {
            eval("\$Foswiki::cfg${clef}{Module}='Foswiki::Plugins::$plu'");
            $reporter->CHANGED("{Plugins}{$plu}{Module}");

            # Add it to the $spec
            $spec->addChild(
                Foswiki::Configure::Value->new(
                    'STRING',
                    LABEL   => "$plu Module",
                    keys    => "{Plugins}{$plu}{Module}",
                    CHECKER => 'PLUGIN_MODULE',
                    default => 'Foswiki::Plugins::$plu'
                )
            );
        }
    }
    $reporter->NOTE('');

    unless ( $this->option('SIMULATE') ) {
        $reporter->WARN(
"Don't forget to save your configuration to complete installation of "
              . join( ', ', keys %plugins ) )
          if ( $reporter->changes()
            && scalar( keys %{ $reporter->changes() } ) );
    }

    $reporter->NOTE( "> Installation "
          . ( $this->option('SIMULATE') ? 'simulated' : 'finished' ) );

    return ( 1, \%plugins, \%cpanDeps );
}

{

    package _SpecChecker;

    use Assert;
    use Foswiki::Configure::Visitor ();

    our @ISA = ('Foswiki::Configure::Visitor');

    sub new {
        my ( $class, $r, $sim ) = @_;
        return bless( { reporter => $r, simulated => $sim }, $class );
    }

    sub startVisit {
        my ( $this, $node ) = @_;
        return 1
          unless $node->{keys}
          && exists $node->{default};
        my $val;
        if ( $node->isFormattedType() ) {

            # We're pulling in a formatted type, such as PERL. We have
            # code later to help handle formatted types represented as
            # strings so we can save the string default rather than evaling
            # it and destroying the formatting.
            $val = $node->{default};
        }
        else {
            $val = eval( $node->{default} );
        }
        if ( $this->{simulated} ) {
            $this->{reporter}->NOTE( "\t* $node->{keys} = "
                  . Foswiki::Configure::Reporter::uneval($val) );
        }
        else {
            return 1 if ( eval("exists \$Foswiki::cfg$node->{keys}") );
            eval("\$Foswiki::cfg$node->{keys}=\$val");
            ASSERT( !$@, $@ ) if DEBUG;
            $this->{reporter}->CHANGED( $node->{keys} );
        }
        return 1;
    }
    sub endVisit { return 1 }
}

# Map a standard filename from the default paths to any alternate file
# locations defined in $Foswiki::cfg.  Adjust for changes in directory
# names and also Web names.   The following mapping is performed:
#
# ---+++ Web names
#
#    * =SystemWebName=
#    * =TrashWebname=
#    * =UsersWebname=
#    * =SandboxWebName= ( Future - see  Foswikitask:Item8744 )
#
# ---+++ Topic Names
#    * =NotifyTopicName=
#    * =HomeTopicName=
#    * =WebPrefsTopicName=
#
# ---+++ Directory locations
#    * =DataDir=
#    * =PubDir=
#    * =WorkingDir=
#    * =TemplateDir=
#    * =ToolsDir=
#    * =LocalesDir=
#    * =ScriptDir=
#
# ---+++ Other
#    * =ScriptSuffix=
#    * =MimeTypesFileName=
sub _mapTarget {
    my $root = shift;
    my $file = shift;

    # Workaround for Tasks.Item8744 feature proposal
    my $sandbox = $Foswiki::cfg{SandboxWebName} || 'Sandbox';

    foreach my $t (
        qw( NotifyTopicName:WebNotify HomeTopicName:WebHome WebPrefsTopicName:WebPreferences
        )
      )
    {
        my ( $val, $def ) = split( ':', $t );
        if ( defined $Foswiki::cfg{$val} ) {
            $file =~
              s#^data/(.*)/$def(\.txt(?:,v)?)$#data/$1/$Foswiki::cfg{$val}$2#;
            $file =~ s#^pub/(.*)/$def/([^/]*)$#pub/$1/$Foswiki::cfg{$val}/$2#;
        }
    }

    if ( defined $Foswiki::cfg{MimeTypesFileName}
        && ( $file eq 'data/mime.types' ) )
    {
        $file =~ s#^data/mime\.types$#$Foswiki::cfg{MimeTypesFileName}#;
        return $file;
    }

    if ( $sandbox ne 'Sandbox' ) {
        $file =~ s#^data/Sandbox/#data/$sandbox/#;
        $file =~ s#^pub/Sandbox/#pub/$sandbox/#;
    }

    if ( $Foswiki::cfg{SystemWebName} ne 'System' ) {
        $file =~ s#^data/System/#data/$Foswiki::cfg{SystemWebName}/#;
        $file =~ s#^pub/System/#pub/$Foswiki::cfg{SystemWebName}/#;
    }

    if ( $Foswiki::cfg{TrashWebName} ne 'Trash' ) {
        $file =~ s#^data/Trash/#data/$Foswiki::cfg{TrashWebName}/#;
        $file =~ s#^pub/Trash/#pub/$Foswiki::cfg{TrashWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Main' ) {
        $file =~ s#^data/Main/#data/$Foswiki::cfg{UsersWebName}/#;
        $file =~ s#^pub/Main/#pub/$Foswiki::cfg{UsersWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Users' ) {
        $file =~ s#^data/Users/#data/$Foswiki::cfg{UsersWebName}/#;
        $file =~ s#^pub/Users/#pub/$Foswiki::cfg{UsersWebName}/#;
    }

# Canonical symbol mappings
#foreach my $w (qw( SystemWebName TrashWebName UsersWebName SandboxWebName )) {  #Waiting for Item8744
    foreach my $w (qw( SystemWebName TrashWebName UsersWebName )) {
        if ( defined $Foswiki::cfg{$w} ) {
            $file =~ s#^data/$w/#data/$Foswiki::cfg{$w}/#;
            $file =~ s#^pub/$w/#pub/$Foswiki::cfg{$w}/#;
        }
    }
    $file =~ s#^data/Sandbox/#data/$sandbox/#;
    $file =~ s#^pub/Sandbox/#pub/$sandbox/#;

    if ( $file =~ s#^data/#$Foswiki::cfg{DataDir}/# ) {
    }
    elsif ( $file =~ s#^pub/#$Foswiki::cfg{PubDir}/# ) {
    }
    elsif ( $file =~ s#^templates/#$Foswiki::cfg{TemplateDir}/# ) {
    }
    elsif ( $file =~ s#^tools/#$Foswiki::cfg{ToolsDir}/# ) {
    }
    elsif ( $file =~ s#^locale/#$Foswiki::cfg{LocalesDir}/# ) {
    }
    elsif ($Foswiki::foswikiLibPath
        && $file =~ s#^lib/#$Foswiki::foswikiLibPath/# )
    {
    }
    elsif ( $file =~
        s#^bin/(.*)$#$Foswiki::cfg{ScriptDir}/$1$Foswiki::cfg{ScriptSuffix}# )
    {

        #This makes a couple of bad assumptions
        #2. that any file going into there _is_ a script - making installing the
        #   .htaccess file via this machanism impossible
        #3. that softlinks are not in use (same issue below)
    }
    else {
        $file = File::Spec->catfile( $root, $file );
    }

    return $file;
}

# Extract a mapped Web,TopicName from the default path from a topic in the manifest.
# (Works for topics, not attachments)
#
# Returns ($web, $topic)
#
# ---+++ Web names
#
#    * =SystemWebName=
#    * =TrashWebname=
#    * =UsersWebname=
#    * =SandboxWebName= ( Future - see  Foswikitask:Item8744 )
#
# ---+++ Topic Names
#    * =NotifyTopicName=
#    * =HomeTopicName=
#    * =WebPrefsTopicName=

sub _getMappedWebTopic {
    my $file = shift;

    # Workaround for Tasks.Item8744 feature proposal
    my $sandbox = $Foswiki::cfg{SandboxWebName} || 'Sandbox';

    foreach my $t (
        qw( NotifyTopicName:WebNotify HomeTopicName:WebHome WebPrefsTopicName:WebPreferences
        )
      )
    {
        my ( $val, $def ) = split( ':', $t );
        if ( defined $Foswiki::cfg{$val} ) {
            $file =~
              s#^data/(.*)/$def(\.txt(?:,v)?)$#data/$1/$Foswiki::cfg{$val}$2#;
        }
    }

    if ( $sandbox ne 'Sandbox' ) {
        $file =~ s#^data/Sandbox/#$sandbox/#;
    }

    if ( $Foswiki::cfg{SystemWebName} ne 'System' ) {
        $file =~ s#^data/System/#$Foswiki::cfg{SystemWebName}/#;
    }

    if ( $Foswiki::cfg{TrashWebName} ne 'Trash' ) {
        $file =~ s#^data/Trash/#$Foswiki::cfg{TrashWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Main' ) {
        $file =~ s#^data/Main/#$Foswiki::cfg{UsersWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Users' ) {
        $file =~ s#^data/Users/#$Foswiki::cfg{UsersWebName}/#;
    }

# Canonical symbol mappings
#foreach my $w (qw( SystemWebName TrashWebName UsersWebName SandboxWebName )) {  #Waiting for Item8744
    foreach my $w (qw( SystemWebName TrashWebName UsersWebName )) {
        if ( defined $Foswiki::cfg{$w} ) {
            $file =~ s#^data/$w/#$Foswiki::cfg{$w}/#;
        }
    }
    $file =~ s#^data/Sandbox/#$sandbox/#;

    my ( $tweb, $ttopic ) = $file =~ m/^(?:data\/)?(.*)\/(\w+).txt$/;

    return ( $tweb, $ttopic );
}

# Install files listed in the manifest.
# Returns boolean status, reports progress to $reporter

sub _install {
    my ( $this, $reporter, $rootspec ) = @_;

    my $dir = $this->option('DIR') || $this->{_root};

    $reporter->NOTE( "---+++ Installing " . $this->module() );

    unless ($Foswiki::Plugins::SESSION) {
        $reporter->NOTE(" Creating a SESSION");
        Foswiki->new('admin');    # Create admin session for topic checkins
    }

    my $err;
    my $ext       = '';
    my $installer = '';
    my $simulated = '';
    $simulated = 'Simulated - ' if ( $this->option('SIMULATE') );

    # Counters for reporting results
    my $checkedIn = 0;
    my $copied    = 0;
    my $attached  = 0;

    unless ( $this->option('EXPANDED') ) {

        # Archive not yet expanded
        if ( $this->option('USELOCAL') ) {

            # Check $dir first, then the download directory.
            for
              my $sdir ( $dir, "$Foswiki::cfg{WorkingDir}/configure/download" )
            {
                for my $sext (qw( .tgz .zip .TGZ .tar.gz .ZIP  )) {
                    use Cwd;
                    if ( -r "$sdir/$this->{_pkgname}$sext" )
                    {    # readable by user
                        $ext = $sext;
                        $dir = $sdir;
                        last;
                    }
                }
                last if ($ext);
            }

            if ($ext) {
                $reporter->NOTE(
"> Using previously downloaded archive $dir/$this->{_pkgname}$ext"
                );
            }
            else {
                $reporter->WARN(
"> No previously downloaded archive found.  Download is required"
                );
            }
        }

        my $tmpdir;         # Directory where archive was expanded
        my $tmpfilename;    # Filename set when downloaded

        if ( !$ext && $this->{_repository} )
        {                   # no extension found - need to download the package

            $reporter->NOTE(
"\t* fetching $this->{_pkgname} from $this->{_repository}->{pub} ..."
            );

            ( $err, $tmpfilename ) = $this->_fetchFile('.tgz');
            if ($err) {
                $reporter->WARN( "Download failure fetching .tgz file - $err",
                    "Trying .zip file" );
            }

            unless ( $tmpfilename && !$err )
            {    # no .tgz found - try the zip archive
                ( $err, $tmpfilename ) = $this->_fetchFile('.zip');
                if ($err) {
                    $reporter->ERROR(
                        "Download failure fetching .zip file - $err");
                    return 0;
                }
            }
        }

        $tmpfilename = "$dir/$this->{_pkgname}$ext" if ($ext);
        my $sb = stat($tmpfilename);
        $reporter->NOTE( "> Unpacking $tmpfilename..., Size: "
              . $sb->size
              . " Modified: "
              . scalar( localtime( $sb->mtime ) ) );
        ( $tmpdir, $err ) =
          Foswiki::Configure::FileUtil::unpackArchive($tmpfilename);
        if ($err) {
            $reporter->ERROR("Unpack failed - $err");
            return 0;
        }
        unless ($tmpdir) {
            $reporter->ERROR("No archive found to install");
            return 0;
        }

        my ($tmpext) = $tmpfilename =~ m/.*(\.[^\.]+)$/;
        $reporter->NOTE(
"> Saving $tmpfilename to $Foswiki::cfg{WorkingDir}/configure/download/$this->{_pkgname}$tmpext"
        );
        $this->_moveFile(
            $tmpfilename,
"$Foswiki::cfg{WorkingDir}/configure/download/$this->{_pkgname}$tmpext",
            undef,
            1    # Force move even if simulate
        );

        $dir = $tmpdir;
    }

    my $root     = $this->{_root};        # Root of the foswiki installation
    my $manifest = $this->{_manifest};    # Reference to the manifest

    my @names = $this->_listFiles();  # Retrieve list of filenames from manifest
    my $ok    = 1;
    my $spec = Foswiki::Configure::Root->new();

    # foreach file in list, move it to the correct place
    foreach my $file (@names) {
        use filetest 'access';

        if ( $file =~ m/^(:?bin|tools)\/[^\/]+$/ ) {
            my $perlLoc = Foswiki::Configure::FileUtil::getPerlLocation();
            Foswiki::Configure::FileUtil::rewriteShebang( "$dir/$file",
                $perlLoc )
              if $perlLoc;
        }

        # Find where it is meant to go
        my $target = _mapTarget( $this->{_root}, $file );

        # Make file writable if it is read-only
        if ( -e $target && !-w $target && !$this->option('SIMULATE') ) {
            chmod( oct(600), $target );
        }

        # Move or copy the file.

        unless ( -f "$dir/$file" ) {    # Exists as a file.
            $reporter->WARN("Source missing $dir/$file - Skipping file");
            next;
        }

        my $installed = $manifest->{$file}->{I}
          || '';                        # Set to 1 if file already installed
        next if ($installed);
        $manifest->{$file}->{I} =
          1;    # Set this to installed (assuming it all works)

        my $ci = $manifest->{$file}->{ci}
          || '';    # Set to 1 if checkin desired
        my $perms = $manifest->{$file}->{perms};    # File permissions

        # Topic files in the data directory needing Checkin
        # SMELL: This only can checkin when a SESSION exists. This won't
        # work in CLI environment, so we are forced to skip this and just
        # copy the file directly.
        if (
            $file =~ m/^data/                      # File for the data directory
            && $file =~ m/^data\/(.*)\/(\w+).txt$/ # and is a topic
            && $Foswiki::Plugins::SESSION
            && (
                -e "$target,v"         # rcs history file exists
                || -e "$target,pfv"    # pfv versions directory exists
                || ( -e $target && $ci )   # target exists and checkin requested
                || (    # Or the store is not well known file based
                    $Foswiki::cfg{Store}{Implementation} ne
                    'Foswiki::Store::PlainFile'
                    && $Foswiki::cfg{Store}{Implementation} ne
                    'Foswiki::Store::RcsWrap'
                    && $Foswiki::cfg{Store}{Implementation} ne
                    'Foswiki::Store::RcsLite'
                )
            )
          )
        {
            my $web   = $1;
            my $topic = $2;
            my ( $tweb, $ttopic ) = _getMappedWebTopic($file);
            my $session = $Foswiki::Plugins::SESSION;

            if ( Foswiki::Func::webExists($tweb) ) {
                my %opts;
                $opts{forcenewrevision} = 1;

                local $/ = undef;
                my $fh;
                unless ( open( $fh, '<', "$dir/$file" ) ) {
                    $reporter->ERROR( "Cannot open $dir/$file for reading: $!",
                        "Probably packaging error" );
                    $ok = 0;
                    next;
                }
                my $contents = <$fh>;
                close $fh;

                # If file is not writable, and not owned, the chmod
                # probably won't work ...  so fail.
                if ( -e $target && !-w $target && !-o $target ) {
                    $reporter->ERROR("Target $file is not writable");
                    $ok = 0;
                    next;
                }

                if ($contents) {
                    $reporter->NOTE(
                        "> ${simulated}Checked in: $file  as $tweb.$ttopic")
                      if DEBUG;
                    $checkedIn++;

                    # This process is derived from Foswiki::Meta::saveTopicText

                    my $topicObject =
                      Foswiki::Meta->new( $session, $tweb, $ttopic );
                    $topicObject->remove('FILEATTACHMENT');

                    my $oldMeta = Foswiki::Meta->load( $session, $web, $topic );
                    $topicObject->copyFrom( $oldMeta, 'FILEATTACHMENT' );

                    require Foswiki::Serialise;
                    Foswiki::Serialise::deserialise( $contents, 'Embedded',
                        $topicObject );

                    unless ( $this->option('SIMULATE') ) {
                        $topicObject->setLoadStatus( $topicObject->getLoadedRev,
                            1 );
                        my $newRev = $topicObject->saveAs(%opts);
                        $session->logger->log(
                            {
                                level    => 'info',
                                action   => 'save',
                                webTopic => "$tweb.$ttopic",
                                extra    => "r$newRev - configure installed "
                                  . $this->module(),
                            }
                        );

                        $ok = 0
                          unless $this->_installAttachments( $reporter, $dir,
                            "$web/$topic", "$tweb/$ttopic", $topicObject,
                            $attached );

                    }
                }
                next;
            }
            else {
                $reporter->ERROR(
                    "Install of $tweb.$ttopic failed - $tweb does not exist!");
                $ok = 0;
            }
        }

        # Everything else
        $err = $this->_moveFile( "$dir/$file", $target, $perms );
        $copied++;
        if ($err) {
            $reporter->ERROR($err);
            $ok = 0;
            next;
        }

        # Pick up all Config.spec's
        if ( $file =~ m/\/Config.spec$/ && !$this->option('SIMULATE') ) {
            Foswiki::Configure::LoadSpec::parse( $target, $spec, $reporter, 1 );
            if ($rootspec) {

                # Also load it into the rootspec, so the caller has
                # access to the value definition
                Foswiki::Configure::LoadSpec::parse( $target, $rootspec,
                    $reporter );
            }
        }
        $reporter->NOTE("> ${simulated}Installed:  $file as $target") if DEBUG;
    }
    $reporter->NOTE(
"> ${simulated}Installed: $copied files copied; $checkedIn filed checked in, $attached files attached"
    );

    my $pkgstore = "$Foswiki::cfg{WorkingDir}/configure/pkgdata";
    $err = $this->_moveFile(
        "$dir/$this->{_pkgname}_installer",
        "$pkgstore/$this->{_pkgname}_installer"
    );
    if ($err) {
        $reporter->ERROR($err);
        $ok = 0;
    }
    if ($ok) {
        $spec->visit(
            _SpecChecker->new( $reporter, $this->option('SIMULATE') ) );

        $reporter->NOTE(
            "> ${simulated}Installed:  $this->{_pkgname}_installer to $pkgstore"
        );
    }

    return $ok;
}

# Install the attachments associated with a topic.  Used when
# attachments or the owning topic have revision data to maintain.
# Otherwise the attachments are just copied.
# Return boolean status.

sub _installAttachments {
    my $this      = shift;
    my $reporter  = shift;
    my $dir       = shift;
    my $webTopic  = shift;    # Standard web/topic for the attachment
    my $twebTopic = shift;    # Mapped target web/topic
    my $meta      = shift;

    use filetest 'access';

    #my $attached  = shift;    # Count of files attached,

    foreach my $key ( sort keys %{ $this->{_manifest}{ATTACH}{$webTopic} } ) {
        my $file = $this->{_manifest}->{ATTACH}->{$webTopic}->{$key};
        my $tfile = _mapTarget( $this->{_root}, $file );

# Attach the file if rcs checkin is needed, otherwise skip it and it will be copied later.
        if (
            (
                $this->{_manifest}->{$file}->{ci}
                && ( -e $tfile )    # checkin requested and file exists
            )
            || ( -e "$tfile,v" )    # or rcs file exists
          )
        {
            if ( -e $tfile && !-w $tfile && !-o $tfile ) {
                $reporter->ERROR("Target file $tfile is not writable");
                next;
            }
            if ( !-e "$dir/$file" ) {
                $reporter->ERROR(
                    "Source file $dir/$file missing, probable packaging error");
                next;
            }

            my $attachinfo =
              $meta->get( 'FILEATTACHMENT', $key );  # Recover existing Metadata
            $this->{_manifest}->{$file}->{I} =
              1;    # Set this to installed (assuming it all works)
            my $fstats = stat "$dir/$file";
            my %opts;
            $opts{name} = $key;
            $opts{file} = "$dir/$file";

            #$opts{dontlog} = 1;
            $opts{attr}     = $attachinfo->{attr};
            $opts{comment}  = $attachinfo->{comment};
            $opts{filesize} = $fstats->size;
            $opts{filedate} = $fstats->mtime;
            $meta->attach(%opts) unless ( $this->option('SIMULATE') );
            $reporter->NOTE("   * Attached:   $file to $twebTopic") if DEBUG;
            $_[0]++;    # Update the attached files counter
        }
    }
    return 1;
}

# Make the path as required and move or copy the file into the target location

sub _moveFile {
    my (
        $this,
        $from,     # Source path
        $to,       # Destination path
        $perms,    # File permissions
        $force     # Force copy even if simulate - used for the .tgz archive
    ) = @_;

    use filetest 'access';

    my @path = split( /[\/\\]+/, $to, -1 );    # -1 allows directories
    pop(@path);
    if ( !$this->option('SIMULATE') || $force ) {
        if ( scalar(@path) ) {
            umask( oct(777) - $Foswiki::cfg{Store}{dirPermission} );
            File::Path::mkpath( join( '/', @path ),
                0, $Foswiki::cfg{Store}{dirPermission} );
        }

        if ( !File::Copy::move( $from, $to ) ) {
            if ( !File::Copy::copy( $from, $to ) ) {
                return "Failed to move/copy file '$from' to $to: $!\n";
            }
        }
        if ( defined $perms ) {
            chmod( oct($perms), $to );
        }
    }
    else {
        return "Target file $to is not writable\n"
          if ( -e $to && !-w $to && !-o $to );
        return "Probably packaging error - $from not found" if ( !-e $from );
    }

    return 0;
}

# Create a backup of the extension by copying the files into the
# =working/configure/backup/= directory.  If system archive
# tools are available, then the directory will be compressed
# into a backup file.
sub _createBackup {
    my ( $this, $reporter ) = @_;
    my $root = $this->{_root};
    $root =~ s#\\#/#g;    # Convert windows style slashes

    require Foswiki::Time;
    my $stamp =
      Foswiki::Time::formatTime( time(), '$year$mo$day-$hour$minutes$seconds',
        'servertime' );

    my $bkdir  = "$Foswiki::cfg{WorkingDir}/configure/backup";
    my $bkname = "$this->{_pkgname}-backup-$stamp";
    my $pkgstore .= "$bkdir/$bkname";
    my $ok = 1;

    my @files = $this->_listFiles(1);    # return list of installed files
    unshift( @files,
"$Foswiki::cfg{WorkingDir}/configure/pkgdata/$this->{_pkgname}_installer"
      )
      if (
        -e "$Foswiki::cfg{WorkingDir}/configure/pkgdata/$this->{_pkgname}_installer"
      );

    unless ( scalar(@files) ) {          # Anything to backup?
        $reporter->NOTE("\t* Nothing to backup");
    }
    else {

        File::Path::mkpath($pkgstore)
          unless ( $this->option('SIMULATE') );

        foreach my $file (@files) {
            my $fstat = stat($file);
            my ($tofile) = $file =~ m/^$root(.*)$/
              ;    # Filename relative to root of Foswiki installation
            next
              unless $tofile
              ;   # Unit tests use a tmp working directory which fails the match
            my @path = split( /[\/\\]+/, "$pkgstore/$tofile", -1 )
              ;    # -1 allows directories
            pop(@path);
            if ( scalar(@path) ) {
                File::Path::mkpath( join( '/', @path ) )
                  unless ( $this->option('SIMULATE') );
                my $mode = $fstat->mode;

                #( stat($file) )[2];    # File::Copy doesn't copy permissions
                File::Copy::Recursive::rcopy( $file, "$pkgstore/$tofile" )
                  unless ( $this->option('SIMULATE') );
                chmod( $mode, "$pkgstore/$tofile" )
                  unless ( $this->option('SIMULATE') );
            }
        }

        my $rslt;
        if ( $this->option('SIMULATE') ) {
            $rslt = ' - Simulated backup, no files copied ';
        }
        else {
            ( $rslt, my $err ) =
              Foswiki::Configure::FileUtil::createArchive( $bkname, $bkdir,
                '1' );
            unless ($rslt) {
                $reporter->ERROR("FAILED $err");
                $ok = 0;
            }
        }

        $reporter->NOTE( "\t* Backup saved into $pkgstore",
            "\t* Archived as $rslt" );
    }
    return $ok;
}

# Check each installed file against the manifest.  Apply the
# permissions to the file.

sub _setPermissions {
    my $this = shift;

    # foreach file in list, apply the permissions per the manifest
    my @names = $this->_listFiles();
    foreach my $file (@names) {

        # Find where it is meant to go
        my $target = _mapTarget( $this->{_root}, $file );

        if ( -f $target ) {

            my $mode = $this->{_manifest}->{$file}->{perms};

            if ($mode) {
                chmod( oct($mode), $target )
                  unless ( $this->option('SIMULATE') );
            }
        }
    }
}

# Return the sorted list of files in the package.
#
# If $installed is true, return the list of files that are actually installed
# including rcs files.

sub _listFiles {
    my ( $this, $installed ) = @_;

    my @files;
    foreach my $key ( keys( %{ $this->{_manifest} } ) ) {
        next if ( $key eq 'ATTACH' );
        if ($installed) {
            my $target = _mapTarget( $this->{_root}, $key );
            push( @files, $target )     if ( -f $target );
            push( @files, "$target,v" ) if ( -f "$target,v" );
            if ( $target =~ m/\.txt$/ ) {
                my $pfv = $target;
                $pfv =~ s/\.txt$/,pfv/;
                push( @files, $pfv ) if ( -e $pfv );
            }
        }
        else {
            push( @files, $key );
        }
    }
    return sort(@files);
}

# List the plugin modules provided by this extension.

sub _listPlugins {
    my $this = shift;
    my %plugins;

    foreach my $plugin ( $this->_listFiles() ) {
        my ($plugName) = $plugin =~ m/.*\/Plugins\/([^\/]+Plugin)\.pm$/;
        $plugins{$plugName} = 1 if $plugName;
    }
    return %plugins;
}

=begin TML

---++ uninstall ( $reporter ) -> $status
Remove each file identified by the manifest.  Also remove
any rcs "...,v" files if they exist.   Note that directories
are NOT removed unless they are empty.

Pre and Post un-install handlers are run.

Returns a status (1 for success)

=cut

sub uninstall {
    my ( $this, $supereporter ) = @_;

    my @removed;
    my %directories;
    my $reporter = LoggingReporter->new(
        $supereporter,
        action => 'Uninstall',
        nolog  => $this->option('SIMULATE')
    );

    $reporter->NOTE("---+ Uninstalling $this->{_pkgname}");

    unless ( $this->{_loaded} ) {

        # Recover the manifest from the _installer file
        $reporter->NOTE("> Loading package installer");
        return 0 unless $this->loadInstaller($reporter);
    }

    $reporter->NOTE("> Creating Backup of $this->{_pkgname} ...");

    # Create a backup of the previous install if any
    $this->_createBackup($reporter);

    $this->_loadExits();

    if ( $this->can('preuninstall') && !$this->option('SIMULATE') ) {
        $reporter->NOTE("> Running Pre-uninstall for $this->{_pkgname} ...");
        my $rslt = $this->preuninstall();
        $reporter->NOTE("<verbatim>$rslt</verbatim>") if $rslt;
    }

    # foreach file in the manifest, remove the file.
    foreach my $key ( keys( %{ $this->{_manifest} } ) ) {

        next if ( $key eq 'ATTACH' );

        # Find where it is meant to go
        my $target = _mapTarget( $this->{_root}, $key );

        if ( $this->option('SIMULATE') ) {
            push( @removed, "simulated $target" )   if ( -f $target );
            push( @removed, "simulated $target,v" ) if ( -f "$target,v" );
            $directories{$1}++ if $target =~ m!^(.*)/[^/]*$!;
        }
        else {

            if ( -f $target ) {
                my $n = unlink $target;
                push( @removed, $target ) if ( $n == 1 );
            }
            if ( -f "$target,v" ) {
                my $n = unlink "$target,v";
                push( @removed, "$target,v" ) if ( $n == 1 );
            }
            if ( $target =~ m/\.txt$/ ) {
                my $pfv = $target;
                $pfv =~ s/\.txt$/,pfv/;
                if ( -e "$pfv" ) {
                    my $n = File::Path::remove_tree("$pfv");
                    push( @removed, "$pfv" ) if ( $n >= 1 );
                }
            }
        }
    }

    my $pkgdata =
      "$Foswiki::cfg{WorkingDir}/configure/pkgdata/$this->{_pkgname}_installer";
    unless ( $this->option('SIMULATE') ) {
        push( @removed, $pkgdata );
        unlink $pkgdata;
        for ( keys %directories ) {
            while (rmdir) { s!/[^/]*$!!; }
        }
    }
    else {
        push( @removed, "simulated $pkgdata" );
    }

    my @plugins;
    my @unpackedFeedback;

    foreach my $file ( sort @removed ) {
        push( @unpackedFeedback, "   * $file" );
        my ($plugName) = $file =~ m/.*\/Plugins\/([^\/]+Plugin)\.pm$/;
        push( @plugins, $plugName ) if $plugName;
    }
    if ( scalar(@unpackedFeedback) ) {
        $reporter->NOTE( "> Removed " . scalar @unpackedFeedback . " files:" );
        $reporter->NOTE(@unpackedFeedback) if DEBUG;
    }

    if ( $this->can('posuninstall') && !$this->option('SIMULATE') ) {
        $reporter->NOTE("> Running Post-uninstall for $this->{_pkgname} ...");
        my $rslt = $this->postuninstall();
        $reporter->NOTE("<verbatim>$rslt</verbatim>") if $rslt;
    }

    unless ( $this->option('SIMULATE') ) {
        foreach my $plu ( sort { lc($a) cmp lc($b) } @plugins ) {
            my $clef = "{Plugins}{$plu}";
            if ( eval("exists \$Foswiki::cfg${clef}{Enabled}") ) {
                eval("delete \$Foswiki::cfg${clef}{Enabled}");
                $reporter->CHANGED("{Plugins}{$plu}{Enabled}");
            }
            if ( eval("exists \$Foswiki::cfg${clef}{Module}") ) {
                eval("delete \$Foswiki::cfg${clef}{Module}");
                $reporter->CHANGED("{Plugins}{$plu}{Module}");
            }
        }
    }
    $reporter->WARN(
        "Don't forget to save your configuration to complete removal of "
          . join( ', ', @plugins ) )
      if ( $reporter->changes() && scalar( keys %{ $reporter->changes() } ) );

    $reporter->NOTE( "> Removal "
          . ( $this->option('SIMULATE') ? 'simulated' : 'finished' ) );

    return 1;
}

=begin TML

---++ loadInstaller ($reporter) -> $ok

Looks for the ${extension}_installer or
${extension}_installer.pl file  and extracts the manifest,
dependencies and pre/post Exit routines from the installer.

The local search path is:
   * Directory passed as parameter,  or root of installation
      * This directory is _also_ examined for the .pl version of the _installer
   * The =working/Configure/download= directory (recently downloaded)
   * The =working/Configure/pkgdata= directory (previously installed)

If the installer is not found and a repository is provided, the
installer file will be retrieved from the repository.

The manifest and dependencies are parsed and loaded into their
respective hashes.  The pre and post routines are eval'd and
installed as methods for this object.

Returns:
    * boolean success

=cut

sub loadInstaller {
    my ( $this, $reporter ) = @_;

    my $temproot = $this->option('DIR') || $this->{_root};

    my $file;
    my $err;

    my $downloadstore = "$Foswiki::cfg{WorkingDir}/configure/download";
    my $pkgstore      = "$Foswiki::cfg{WorkingDir}/configure/pkgdata";
    my $extension     = $this->{_pkgname};
    my $warn          = '';
    local $/ = "\n";

    if ( $this->option('USELOCAL') ) {

        #  The root for manually downloaded extensions
        if ( -e "$temproot/${extension}_installer" ) {
            $file = "$temproot/${extension}_installer";
        }
        elsif ( -e "$temproot/${extension}_installer.pl" ) {
            $file = "$temproot/${extension}_installer.pl";
        }

        #  The download directory for previously downloaded extensions
        elsif ( -e "$downloadstore/${extension}_installer" ) {
            $file = "$downloadstore/${extension}_installer";
        }

        #  The pkgdata directory for previously installed extensions
        elsif ( -e "$pkgstore/${extension}_installer" ) {
            $file = "$pkgstore/${extension}_installer";
        }
        else {
            $reporter->WARN(
                "> Unable to find $extension locally in $temproot ...");
        }
    }

    if ($file) {
        my $sb = stat($file);
        $reporter->WARN( "> Using local $file, Size: "
              . $sb->size
              . " Modified: "
              . scalar( localtime( $sb->mtime ) )
              . " for package manifest" );
    }
    else {
        if ( defined $this->{_repository} ) {
            $reporter->NOTE( "   * fetching $extension installer from "
                  . $this->repository()->{pub}
                  . '...' );
            ( $err, $file ) = $this->_fetchFile('_installer');
            if ($err) {
                $reporter->ERROR("Download failed - $err");
                return 0;
            }
        }
        else {
            $reporter->WARN(
                "Unable to download $this->{_pkgname} - no repository provided"
            );
            return 0;
        }
    }

    my $opened = open( my $fh, '<', $file );
    if ( !$opened ) {
        $reporter->ERROR("Extract manifest failed: $file -  $!");
        return 0;
    }

    my $found = '';
    my $depth = 0;
    while (<$fh>) {
        chomp;
        if ( $_ eq "<<<< MANIFEST >>>>" ) {
            $found = 'M';
            next;
        }
        elsif ( $_ eq "<<<< DEPENDENCIES >>>>" ) {
            $found = 'D';
            next;
        }
        elsif (/sub\s*p(?:ost|re)(?:un)?install/) {
            $found = 'P';
        }

        if ( $found eq 'M' ) {
            if (/^$/) {
                $found = '';
                next;
            }
            $this->_parseManifest( $_, $reporter );
            next;
        }

        if ( $found eq 'D' ) {
            if (/^$/) {
                $found = '';
                next;
            }
            $this->_parseDependency( $_, $reporter ) if ($_);
            next;
        }

        if ( $found eq 'P' ) {

            # SMELL try to guess when the function is closed.
            # if brackets are not in pairs, this will fail, like { in comment
            $depth++ for /{/g;
            $depth-- for /}/g;
            $_ =~ /^(.*)$/;    # untaint
            $this->{_prepost_code} .= "$1\n";
            $found = '' unless $depth;
            next;
        }
    }
    close $fh;
    $this->{_loaded} = 1;
    return 1;
}

# Evaluate the pre and post install / uninstall functions extracted from
# the package file.

sub _loadExits {
    my $this = shift;
    my $err  = '';

    if ( $this->{_prepost_code} ) {

        # Ensure it's clean, to avoid redefine error
        for (qw( preinstall postinstall preuninstall postuninstall )) {
            undef &{$_};
        }
        unless ( eval( $this->{_prepost_code} . "; 1; " ) ) {
            die "Couldn't load pre/post (un)install: $@";
        }
    }
    return;
}

# Delete the pre and post install / uninstall routines from the namespace

sub _deleteExits {
    my $this = shift;

    for (qw( preinstall postinstall preuninstall postuninstall )) {
        undef &{$_};
    }
    return;
}

# Return the manifest in printable format

sub manifest {
    my ($this) = @_;
    my $rslt = '';

    foreach my $file ( sort keys( %{ $this->{_manifest} } ) ) {
        next if ( $file eq 'ATTACH' );
        $rslt .= join( " ",
            $file,
            map { $this->{_manifest}->{$file}->{$_} } qw( perms md5 desc ) )
          . "\n";
    }
    return $rslt;
}

=begin TML

---++ _parseManifest ( $line, $reporter )
Parse the manifest line into the manifest hash.

->{filename}->{ci}      Flag if file should be "checked in"
->{filename}->{perms}   File permissions
->{filename}->{MD5}     MD5 of file (if available)

=cut

sub _parseManifest {
    my ( $this, $line, $reporter ) = @_;

    my ( $file, $perms, $md5, $desc ) =    # New format
      $line =~ m/^(".+"|\S+)\s+(\d+)(?:\s+([a-f0-9]{32}))?\s+(.*)$/;

    unless ($file) {                       # Old format, for legacy
        ( $file, $perms, $md5, $desc ) =
          /^([^,]+)(?:,([^,]+)(?:,([a-f0-9]{32}))?,(.*))?$/;
    }

    unless ($file) {
        $reporter->WARN("No file found in $line - line bypassed");
        return;
    }
    $file =~ s/^"(.+)"$/$1/;

    my $tweb       = '';
    my $ttopic     = '';
    my $tattach    = '';
    my $canCheckin = 0;

# DO NOT Let the Extensions installer save over .htpasswd, any .changes file or modify the server installation.
    if (
           substr( $file, -10 ) eq '/.htpasswd'
        || substr( $file, -10 ) eq '/.htaccess'
        || (   substr( $file, 0, 5 ) eq 'data/'
            && substr( $file, -9 ) eq '/.changes' )
      )
    {
        $reporter->WARN(
"Extension installer will not install $file. Server configuration file."
        );
        return;
    }

    if ( $file =~ m/^data\/.*/ && $file =~ m/^data\/(.*)\/(.*?).txt$/ ) {
        $tweb   = $1;
        $ttopic = $2;
        if (   defined $tweb
            && defined $ttopic
            && length($tweb) > 0
            && length($ttopic) > 0 )
        {
            $canCheckin = 1;
        }
        else {
            $reporter->WARN("$file is not a topic - file will be bypassed");
        }
    }
    if ( $file =~ m/^pub\/.*/ && $file =~ m/^pub\/(.*)\/(.*?)\/([^\/]+)$/ ) {
        $tweb    = $1;
        $ttopic  = $2;
        $tattach = $3;
        if (   defined $tweb
            && defined $ttopic
            && defined $tattach
            && length($tweb) > 0
            && length($ttopic) > 0
            && length($tattach) > 0 )
        {
            $canCheckin = 1;
        }
        else {
            $reporter->WARN(
                    "Unable to identify attachment $file name or location"
                  . " - file will be bypassed" );
            return;
        }
    }

    $this->{_manifest}->{$file}->{ci} =
      ( ( !$canCheckin || $desc =~ s/\(noci\)// ) ? 0 : 1 );
    $this->{_manifest}->{$file}->{perms} = $perms;
    $this->{_manifest}->{$file}->{md5} = $md5 || '';

    # SMELL: The {topic} field isn't used by Package. But it should be.
    $this->{_manifest}->{$file}->{topic} = "$tweb\t$ttopic\t$tattach";
    $this->{_manifest}->{$file}->{desc}  = $desc;
    $this->{_manifest}->{ATTACH}->{"$tweb/$ttopic"}->{$tattach} = $file
      if $tattach;

}

# Parse the manifest line into the manifest hash.
our $depwarn = '';    # Pass back warnings from untaint validation routine

sub _parseDependency {
    my ( $this, $line, $reporter ) = @_;

    require Foswiki::Sandbox;

    my $warn = '';
    my ( $module, $condition, $trigger, $type, $desc ) =
      split( ',', $line, 5 );

    return unless ($module);

    if ( $type =~ m/cpan|perl/i ) {
        local $depwarn = '';
        $module = Foswiki::Sandbox::untaint( $module, \&_validatePerlModule );
        $reporter->WARN($depwarn) if $depwarn;
    }

    # ONLYIF can be arbitrary perl code - but then, so can the
    # extension.  DEPENDENCIES files should be as secure as .pms.
    push(
        @{ $this->{_dependencies} },
        new Foswiki::Configure::Dependency(
            module      => $module,
            type        => $type,
            version     => $condition,    # version condition
            trigger     => $trigger,      # ONLYIF condition
            description => $desc
        )
    );
}

# This is used to ensure the perl module dependencies
# provided by the module are real module names, and not some random garbage
# which could be potentially insecure.
sub _validatePerlModule {
    my $module = shift;

    # Remove all non alpha-numeric caracters and :
    # Do not use \w as this is localized, and might be tainted
    my $replacements = $module =~ s/[^a-zA-Z:_0-9]//g;
    $depwarn =
        'validatePerlModule removed '
      . $replacements
      . ' characters, leading to '
      . $module . "\n"
      if $replacements;
    return $module;
}

=begin TML

---++ ObjectMethod checkDependencies ()
Checks the dependencies listed for this module.  Returns two lists, one
of Installed dependencies and one of Missing dependencies.   It also returns a
list of Foswiki package names that might be installed and a list of the
CPAN modules that could be installed.

=cut

sub checkDependencies {
    my $this  = shift;
    my $which = shift;
    my @installed;
    my @missing;
    my @wiki;
    my @cpan;
    my @manual;

    foreach my $dep ( @{ $this->{_dependencies} } ) {

        ( my $trigger ) = $dep->{trigger} =~ m/^(.*)$/s;

        # Evaluate the trigger - if true, module is required
        my $required = eval($trigger);
        if ($@) {
            push( @missing,
"$dep->{module} **ERROR** -- ONLYIF \"$trigger\" condition failed to compile: contact developer -- $@ "
            );
            next;
        }
        next unless $required;    # Skip the module - trigger was false

        my $trig =
          ( !(DEBUG) || $dep->{trigger} eq '1' )
          ? ''
          : " - Triggered by $dep->{trigger}";

        my ( $ok, $msg ) = $dep->checkDependency();
        if ($ok) {
            $msg =~ s/\n/ /g;
            push( @installed, "$msg$trig" );
            next;
        }

        $msg .= $trig;
        $msg .= " - $dep->{description}"
          if ( $dep->{description} );
        $msg .= " - Optional dependency, will not be automatically installed"
          if ( $dep->{description} =~ m/^[Oo]ptional/ );
        $msg =~ s/\n/ /g;
        push( @missing, $msg );

        if ( $dep->{module} =~ m/^(Foswiki|TWiki)::(Contrib|Plugins)::(\w*)/ ) {
            my $type     = $1;
            my $pack     = $2;
            my $packname = $3;
            $packname .= $pack
              if ( $pack eq 'Contrib' && $packname !~ /Contrib$|AddOn$|Skin$/ );
            $dep->{name} = $packname;
            push( @wiki, $dep )
              unless ( $dep->{description} =~ m/^[Oo]ptional/ );
            next;
        }

        if ( $dep->{type} =~ m/cpan/i ) {
            push( @cpan, $dep );
        }
        else {
            push( @manual, $dep );
        }
    }
    return ( \@wiki ) if ( defined $which && $which eq 'wiki' );
    return ( \@installed, \@missing, \@wiki, \@cpan, \@manual );
}

# Installs the dependencies listed for this module.  Returns the details
# of the installation.
sub _installDependencies {
    my ( $this, $reporter, $spec ) = @_;
    my %pluglist;
    my %cpanlist;

    foreach my $dep ( @{ $this->checkDependencies('wiki') } ) {
        my ( $ok, $msg ) = $dep->checkDependency();
        unless ($ok) {
            $reporter->NOTE("Skipping duplicate dependency $dep->{name}")
              if ( $this->{_seen}{ $dep->{name} } );
            next if ( $this->{_seen}{ $dep->{name} } );
            my $deppkg = Foswiki::Configure::Package->new(
                root       => $this->{_root},
                repository => $this->{_repository},
                module     => $dep->{name},
                seen       => $this->{_seen},
                %{ $this->{_options} }
            );
            my ( $ok, $plugins, $cpan ) = $deppkg->install( $reporter, $spec );
            if ($ok) {
                @pluglist{ keys %$plugins } = values %$plugins;
                @cpanlist{ keys %$cpan }    = values %$cpan;
            }
        }
    }
    return ( \%pluglist, \%cpanlist );
}

# Fetch a file from a repository.  It uses the repository hash
# set for the object:
# <verbatim>
#        my $repository = {
#           name => 'Foswiki',
#           data => 'http://foswiki.org/Extensions/',
#           pub => 'http://foswiki.org/pub/Extensions/' };
# <verbatim>
#
# $ext is the filetype to be fetched - .tgz,  .zip,  .md5,  _installer.
#
# Returns the file location & name,  along with a message if any.
sub _fetchFile {
    my ( $this, $ext ) = @_;

    my $arf =
        $this->{_repository}->{pub}
      . $this->{_pkgname} . '/'
      . $this->{_pkgname}
      . $ext;
    if ( defined( $this->{_repository}->{user} ) ) {
        $arf .= '?username=' . $this->{_repository}->{user};
        if ( defined( $this->{_repository}->{pass} ) ) {
            $arf .= ';password=' . $this->{_repository}->{pass};
        }
    }
    my $ar;

    my $response = _getUrl($arf);
    if ( !$response->is_error() ) {
        eval { $ar = $response->content(); };
    }
    else {
        $@ = $response->message();
    }

    my $feedback = '';
    if ($@) {
        $feedback .= <<HERE;
I can\'t download $arf because of the following error:
$@
HERE
        return ($feedback);
    }

    if ( !defined($ar) ) {
        $feedback .= <<HERE;
No content.  Extension may not have been packaged correctly.
HERE
        return ($feedback);
    }

    # Strip HTTP headers if necessary
    $ar =~ s/^HTTP(.*?)\r\n\r\n//sm;

    # Save it somewhere it will be cleaned up
    my ( $fh, $tmpfilename ) =
      File::Temp::tempfile( SUFFIX => $ext, UNLINK => 1 );
    binmode($fh);
    print $fh $ar;
    $fh->close();

    return ( '', $tmpfilename );

}

sub _getUrl {
    my ($url) = @_;

    require Foswiki::Net;
    my $tn       = new Foswiki::Net();
    my $response = $tn->getExternalResource($url);
    $tn->finish();
    return $response;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
