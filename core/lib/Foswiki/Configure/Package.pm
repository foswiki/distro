# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Package

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
         * ={ci}= - Flag specifying if file should be checked into the RCS system
         * ={perms}= - File permissions in Linux octal string format
         * ={md5}= - MD5 checksum of file - optional, recovered from MANIFEST2
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
use Assert;
use Foswiki::Configure::Dependency;
use Foswiki::Configure::Util;

our $VERSION = '$Rev: 6590 $';

my $depwarn = '';    # Pass back warnings from untaint validation routine

############# GENERIC METHODS #############

=begin TML

---++ ClassMethod new($root, $pkgname, $type, $session)
   * =$root= - The root of the Foswiki installation - used for file operations
   * =$pkgname= - The name of the the package. 
   * $type - The type of package represented by this objct.  Supported types include:
      * Plugin - A Foswiki Extension of type Plugin - Defined in Extension/_extension_.pm
      * Skin - A Foswiki Skin
      * Contrib - A Foswiki Contribution or AddOn.   Defined in Contrib/_extension_.pm
      * Core - (future) a packaged core installation.
   * =$session= (optional) - a Foswiki object (e.g. =$Foswiki::Plugins::SESSION=)
Required for installer methods - used for checkin operations

   * =$options= - A hash of options for the installation

      {
        EXPANDED => 0/1     Specify that archive file has already been expanded 
        USELOCAL => 0/1     If local versions of _installer or archives are found, use them instead of download.
        SHELL    => 0/1     Specify if executed from shell - default is to generate html markup in messages.
        NODEPS   => 0/1     Set if dependencies should not be installed.  Default is to always install Foswiki dependencies.
                            (CPAN and external dependencies are not handled by this module.)
        SIMULATE => 0/1     Set to 1 if actions should be simulated - no file system modifications other than temporary files.
        CONTINUE => 0/1     If set to 1, the installation will continue even if errors are encountered. (future)
      }
      
=cut

sub new {
    my ( $class, $root, $pkgname, $session, $options ) = @_;
    my @deps;

    my $this = bless(
        {
            _root    => $root,
            _pkgname => $pkgname,
            _session => $session,
            _options => $options,

  # Hash mapping the topics, attachment and other files supplied by this package
            _manifest => undef,

            # Array of dependencies required by this package
            _dependency => \@deps,
            _routines   => undef,
            _repository => undef,
            _loaded     => undef,    # Flag set if loadInstaller is complete
            _errors     => undef,    # Collected errors
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
    undef $this->{_session};
    undef $this->{_options};
    undef $this->{_manifest};
    undef $this->{_dependency};
    undef $this->{_routines};
    undef $this->{_loaded};
    undef $this->{_errors};

    for (qw( preinstall postinstall preuninstall postuninstall )) {
        undef &{$_};
    }

}

=begin TML

---++ ObjectMethod repository()

Get or set the respository associated with the object.

=cut

sub repository {
    my $this = shift;

    $this->{_repository} = $_[0] if defined $_[0];
    return $this->{_repository};
}

=begin TML

---++ ObjectMethod pkgname([$name])
   * =$name= - optional, change the package name in the object
Get/set the web name associated with the object.

=cut

sub pkgname {
    my ( $this, $pkgname ) = @_;
    $this->{_pkgname} = $pkgname if defined $pkgname;
    return $this->{_pkgname};
}

=begin TML

---++ ObjectMethod errors()
Return any errors encountered duriung the installation of this object
and those returned by any dependencies.

=cut

sub errors {
    my $this = shift;
    return $this->{_errors} || '';
}

=begin TML

---++ ObjectMethod fullInstall()

Perform a full installation of the package, including all dependencies
and any required downloads from the repository.

=cut

sub fullInstall {
    my $this = shift;

    my $feedback = '';
    my $rslt     = '';
    my $err      = '';

    my $nl   = "<br />\n";
    my $pre  = '<pre>';
    my $epre = '</pre>';

    if ( $this->{_options}->{SHELL} ) {
        $nl   = "\n";
        $pre  = '';
        $epre = '';
        $feedback .= "===== INSTALLING $this->{_pkgname} \n";
    }
    else {
        $feedback .=
          "<h3 style='margin-top:0'>Installing $this->{_pkgname}</h3>";
        $feedback .= "<div class='installDependency'>";
    }

    unless ( $this->{_loaded} ) {
        ( $rslt, $err ) = $this->loadInstaller()
          ;    # Recover the manifest from the _installer file
        if ($rslt) {
            $feedback .= "Loading package installer$nl";
            $feedback .= "$pre$rslt$epre";
            $rslt = '';
        }
    }

    if ($err) {
        $this->{_errors} .= $err;
        return ( "ERROR - " . $err )
          ;    # Don't try to continue if installer could not be loaded.
    }

    my ( $installed, $missing, $wiki, $cpan, $manual ) =
      $this->checkDependencies();

  # #wiki, $cpan and $manual are array references to array of Dependency objects

    $rslt .= "===== INSTALLED =======\n$installed\n" if ($installed);
    $rslt .= "====== MISSING ========\n$missing\n"   if ($missing);

    if ($rslt) {
        $feedback .= "Dependency Report for $this->{_pkgname} ..$nl";
        $feedback .= "$pre$rslt$epre";
        $rslt = '';
    }

    my $depPlugins;    # hashref to hash of plugin names
    my $depCPAN;       # hashref to hash of cpan dependency names
    unless ( $this->{_options}->{NODEPS} ) {
        ( $rslt, $depPlugins, $depCPAN ) = $this->installDependencies();
        $feedback .= $rslt;
    }

    $feedback .= "Creating Backup of $this->{_pkgname} ...$nl";
    ( $rslt, $err ) =
      $this->createBackup();    # Create a backup of the previous install if any
    if ($err) {
        $this->{_errors} .= $err;
        $feedback .= "$pre$err$pre";
    }
    $feedback .= "$pre$rslt$epre";
    $rslt = '';

    my %plugins;
    my %cpanDeps;

    unless ($err) {             # If backup failed don't proceed

        $this->loadExits();

        unless ( $this->{_options}->{SIMULATE} ) {
            $feedback .=
              "Running Pre-install exit for $this->{_pkgname} ...$nl";
            $rslt = $this->preinstall() || '';
            $feedback .= "$pre$rslt$epre";
            $rslt = '';
        }

        $err = '';
        ( $rslt, $err ) = $this->install();    # and do the installation
        $this->{_errors} .= $err if ($err);

        $feedback .= "Installing $this->{_pkgname}... $nl";
        $feedback .= "$pre$rslt$epre";
        $rslt = '';

        unless ( $this->{_options}->{SIMULATE} || $err ) {
            $feedback .=
              "Running Post-install exit for $this->{_pkgname}...$nl";
            $rslt = $this->postinstall() || '';
            $feedback .= "$pre$rslt$epre";
            $rslt = '';
        }
    }
    %plugins = $this->listPlugins()
      ;    # Retrieve a list of any plugin modules installed by this package.
    @plugins{ keys %$depPlugins } = values %$depPlugins; # merge in dependencies

    foreach my $cpdep (@$cpan) {
        $cpanDeps{ $cpdep->{module} } = $cpdep;
    }
    @cpanDeps{ keys %$depCPAN } =
      values %$depCPAN;    # merge in cpan from dependencies

    $feedback .= "</div>" unless ( $this->{_options}->{SHELL} );

    return ( $feedback, \%plugins, \%cpanDeps );

}

=begin TML

---++ ObjectMethod install()

Install files listed in the manifest.  $dir is the temporary directory where the 
Extension package will be found for installation.  

If repository is provided in addition to the directory, the archives will be 
retrieved.   If $uselocal is set, then local copies if found will be used instead of 
the download.

Missing directories are created as required.  The files are mapped into non-standard
locations by the mapTarget utility routine.  If a file is read-only, it is temporarily
overridden and the mode of the file is restored after the move.

The $session is a Foswiki session used for Topic checkin when required.  The session - while
optional, must be set prior to running the install method.

Files are "checked in" by creating a Topic Meta object and using the Foswiki Meta API to 
save the topic.

   * If the file is new, with no history, it is simply copied, 
   * If the file exists and has rcs history ( *,v file exists), it is always checked in 
   * If the file exists without history, the Manifest "CI" flag is followed

   * =%optios= (optional) options to override behavior - primarily for unit tests.
      * =DIR =>  directory where installer package is found
      * =USELOCAL => 1= Use local archives if found (Used by shell installations)
      * =EXPANDED => 1= Archive file has already been expanded - preventing any downloads - for unit tests

=cut

sub install {
    my $this    = shift;
    my $options = shift;

    my $expanded = $this->{_options}->{EXPANDED} || $options->{EXPANDED} || 0;
    my $uselocal = $this->{_options}->{USELOCAL} || $options->{USELOCAL} || 0;
    my $dir = $this->{_options}->{DIR} || $options->{DIR} || $this->{_root};

    my $ext       = '';
    my $feedback  = '';    # Results from install
    my $err       = '';    # Error results
    my $installer = '';
    my $simulated = '';
    $simulated = 'Simulated - ' if ( $this->{_options}->{SIMULATE} );

    unless ($expanded) {
        if ($uselocal) {

            for (qw( .tgz .zip .TGZ .tar.gz .ZIP  )) {
                use Cwd;
                if ( -r "$dir/$this->{_pkgname}$_" ) {    # readable by user
                    $ext = $_;
                    last;
                }
            }
            $feedback .=
'No local package found, and uselocal requested - download required'
              . "\n"
              unless ($ext);
        }
        my $tmpdir;         # Directory where archive was expanded
        my $tmpfilename;    # Filename set when downloaded

        if ( !$ext && $this->{_repository} )
        {                   # no extension found - need to download the package
            ( $err, $tmpfilename ) = $this->_fetchFile('.tgz');
            if ($err) {
                $this->{_errors} .= "Download failure\n $err";
                return ( $feedback, "Download failure\n $err" );
            }

            unless ( $tmpfilename && !$err )
            {               # no .tgz found - try the zip archive
                ( $err, $tmpfilename ) = $this->_fetchFile('.zip');
                if ($err) {
                    $this->{_errors} .= "Download failure\n $err";
                    return ( $feedback, "Download failure\n $err" );
                }
            }
        }
        $tmpfilename = "$dir/$this->{_pkgname}$ext" if ($ext);
        $feedback .= "Unpacking $tmpfilename...\n";
        ( $tmpdir, $err ) =
          Foswiki::Configure::Util::unpackArchive($tmpfilename);
        if ($err) {
            $feedback .= "$err\n";
            $this->{_errors} .= $err;
        }
        return ( $feedback, "No archive found to install\n" ) unless ($tmpdir);
        $dir = $tmpdir;
    }

    my $session =
      $this->{_session}; # Session used for file checkin - should be admin user.
    my $root     = $this->{_root};        # Root of the foswiki installation
    my $manifest = $this->{_manifest};    # Reference to the manifest

    my @names  = $this->listFiles();  # Retrieve list of filenames from manifest
    my $errors = '';                  # Accumulated errors

    # foreach file in list, move it to the correct place
    foreach my $file (@names) {

        $err = '';

        if ( $file =~ /^(:?bin|tools)\/[^\/]+$/ ) {
            my $perlLoc = Foswiki::Configure::Util::getPerlLocation();
            Foswiki::Configure::Util::rewriteShebang( "$dir/$file", "$perlLoc" )
              if $perlLoc;
        }

        # Find where it is meant to go
        my $target =
          Foswiki::Configure::Util::mapTarget( $this->{_root}, $file );

        # Make file writable if it is read-only
        if ( -e $target && !-w $target && !$this->{_options}->{SIMULATE} ) {
            chmod( oct(600), "$target" );
        }

        # Move or copy the file.

        if ( -f "$dir/$file" ) {    # Exists as a file.
            my $installed = $manifest->{$file}->{I}
              || '';                # Set to 1 if file already installed
            next if ($installed);
            $manifest->{$file}->{I} =
              1;    # Set this to installed (assuming it all works)

            my $ci = $manifest->{$file}->{ci}
              || '';    # Set to 1 if checkin desired
            my $perms = $manifest->{$file}->{perms};    # File permissions

            # Topic files in the data directory needing Checkin
            if ( $file =~ m/^data/
                && ( -e "$target,v" || ( -e "$target" && $ci ) ) )
            {
                my ( $web, $topic ) = $file =~ /^data\/(.*)\/(\w+).txt$/;
                my ( $tweb, $ttopic ) =
                  Foswiki::Configure::Util::getMappedWebTopic($file);

                if ( Foswiki::Func::webExists($tweb) ) {
                    my %opts;
                    $opts{forcenewrevision} = 1;

                    local $/ = undef;
                    open( my $fh, '<', "$dir/$file" )
                      or return ( $feedback,
"Cannot open $dir/$file for reading: $!\nProbably packaging error\n"
                      );
                    my $contents = <$fh>;
                    close $fh;

# If file is not writable, and not owned, the chmod probably won't work ...  so fail.
                    $err = "Target $file is not writable\n"
                      if ( -e "$target" && !-w "$target" && !-o "$target" );
                    if ($err) {
                        $errors .= $err;
                        next;
                    }

                    if ($contents) {
                        $feedback .=
                          "${simulated}Checked in: $file  as $tweb.$ttopic\n";
                        my $meta = Foswiki::Meta->new( $session, $tweb, $ttopic,
                            $contents );

                        ( my $afdbk, $err ) =
                          _installAttachments( $this, $dir, "$web/$topic",
                            "$tweb/$ttopic", $meta );
                        $feedback .= $afdbk;
                        $errors .= $err if ($err);
                        $meta->saveAs( $tweb, $ttopic, %opts )
                          unless $this->{_options}->{SIMULATE};
                    }
                    next;
                }
            }

            # Everything else
            $err = _moveFile( $this, "$dir/$file", "$target", $perms );
            $errors .= $err if ($err);
            $feedback .= "${simulated}Installed:  $file\n";
            next;
        }
    }
    my $pkgstore = "$Foswiki::cfg{WorkingDir}/configure/pkgdata";
    $err = _moveFile(
        $this,
        "$dir/$this->{_pkgname}_installer",
        "$pkgstore/$this->{_pkgname}_installer"
    );
    $errors .= $err if ($err);
    $feedback .= "${simulated}Installed:  $this->{_pkgname}_installer\n";

    return ( $feedback, $errors );

}

=begin TML
---+++ _installAttachments ()

Install the attachments associated with a topic.  Used when 
attachments or the owning topic have revision data to maintain.
Otherwise the attachments are just copied.

=cut

sub _installAttachments {
    my $this      = shift;
    my $dir       = shift;
    my $webTopic  = shift;    # Standard web/topic for the attachment
    my $twebTopic = shift;    # Mapped target web/topic
    my $meta      = shift;
    my $feedback  = '';
    my $errors    = '';

    foreach my $key ( keys %{ $this->{_manifest}{ATTACH}{$webTopic} } ) {
        my $file = $this->{_manifest}->{ATTACH}->{$webTopic}->{$key};
        my $tfile =
          Foswiki::Configure::Util::mapTarget( $this->{_root}, $file );

# Attach the file if rcs checkin is needed, otherwise skip it and it will be copied later.
        if (
            (
                $this->{_manifest}->{$file}->{ci}
                && ( -e "$tfile" )    # checkin requested and file exists
            )
            || ( -e "$tfile,v" )      # or rcs file exists
          )
        {
            my $err = '';
            $err = "Target file $tfile is not writable\n"
              if ( -e "$tfile" && !-w "$tfile" && !-o "$tfile" );
            $err .= "Source file missing, probable packaging error\n"
              if ( !-e "$dir/$file" );
            if ($err) {
                $errors .= $err;
                next;
            }

            my $attachinfo =
              $meta->get( 'FILEATTACHMENT', $key );  # Recover existing Metadata
            $this->{_manifest}->{$file}->{I} =
              1;    # Set this to installed (assuming it all works)
            my @stats = stat "$dir/$file";
            my %opts;
            $opts{name} = $key;
            $opts{file} = "$dir/$file";

            #$opts{dontlog} = 1;
            $opts{attr}     = $attachinfo->{attr};
            $opts{comment}  = $attachinfo->{comment};
            $opts{filesize} = $stats[7];
            $opts{filedate} = $stats[9];
            $meta->attach(%opts) unless ( $this->{_options}->{SIMULATE} );
            $feedback .= "Attached:   $file to $twebTopic\n";
        }
    }
    return ( $feedback, $errors );
}

=begin TML
---+++ _moveFile ()

Make the path as required and move or copy the file into the target location

=cut

sub _moveFile {
    my $this  = shift;
    my $from  = shift;
    my $to    = shift;
    my $perms = shift;

    my @path = split( /[\/\\]+/, $to, -1 );    # -1 allows directories
    pop(@path);
    unless ( $this->{_options}->{SIMULATE} ) {
        if ( scalar(@path) ) {
            umask( oct(777) - $Foswiki::cfg{RCS}{dirPermission} );
            File::Path::mkpath( join( '/', @path ),
                0, $Foswiki::cfg{RCS}{dirPermission} );
        }

        if ( !File::Copy::move( "$from", $to ) ) {
            if ( !File::Copy::copy( "$from", $to ) ) {
                return "Failed to move/copy file '$from' to $to: $!\n";
            }
        }
        if ( defined $perms ) {
            $to =~ /(.*)/;
            $to = $1;    #yes, we must untaint
            $perms =~ /(.*)/;
            $perms = $1;    #yes, we must untaint
            chmod( oct($perms), "$to" );
        }
    }
    else {
        return "Target file $to is not writable\n"
          if ( -e "$to" && !-w "$to" && !-o "$to" );
        return "Probably packaging error - $from not found" if ( !-e $from );
    }

    return 0;
}

=begin TML
---++ ObjectMethod createBackup ()
Create a backup of the extension by copying the files into the 
=working/configure/backup/= directory.  If system archive
tools are available, then the directory will be compressed
into a backup file.

=cut

sub createBackup {
    my $this = shift;
    my $root = $this->{_root};
    $root =~ s#\\#/#g;    # Convert windows style slashes

    require Foswiki::Time;
    my $stamp =
      Foswiki::Time::formatTime( time(), '$year$mo$day-$hour$minutes$seconds',
        'servertime' );

    my $bkdir  = "$Foswiki::cfg{WorkingDir}/configure/backup";
    my $bkname = "$this->{_pkgname}-backup-$stamp";
    my $pkgstore .= "$bkdir/$bkname";

    my @files = $this->listFiles('1');    # return list of installed files
    unshift( @files,
"$Foswiki::cfg{WorkingDir}/configure/pkgdata/$this->{_pkgname}_installer"
      )
      if (
        -e "$Foswiki::cfg{WorkingDir}/configure/pkgdata/$this->{_pkgname}_installer"
      );

    if ( scalar @files ) {                # Anything to backup?
        File::Path::mkpath("$pkgstore")
          unless ( $this->{_options}->{SIMULATE} );

        foreach my $file (@files) {
            my ($tofile) = $file =~ m/^$root(.*)$/
              ;    # Filename relative to root of Foswiki installation
            next
              unless $tofile
            ;    # Unit tests use a tmp working directory which fails the match
            my @path = split( /[\/\\]+/, "$pkgstore/$tofile", -1 )
              ;    # -1 allows directories
            pop(@path);
            if ( scalar(@path) ) {
                File::Path::mkpath( join( '/', @path ) )
                  unless ( $this->{_options}->{SIMULATE} );
                my $mode =
                  ( stat($file) )[2];    # File::Copy doesn't copy permissions
                File::Copy::copy( "$file", "$pkgstore/$tofile" )
                  unless ( $this->{_options}->{SIMULATE} );
                $mode =~ /(.*)/;
                $mode = $1;              #yes, we must untaint
                chmod( $mode, "$pkgstore/$tofile" )
                  unless ( $this->{_options}->{SIMULATE} );
            }
        }

        my ( $rslt, $err ) =
          Foswiki::Configure::Util::createArchive( $bkname, $bkdir, '1' )
          unless ( $this->{_options}->{SIMULATE} );

        $rslt = ' - Simulated backup, no files copied '
          if ( $this->{_options}->{SIMULATE} );

        $rslt = "FAILED \n" . $err unless ($rslt);

        return "Backup saved into $pkgstore \n   Archived as $rslt \n";
    }
    return "Nothing to backup \n";
}

=begin TML

---++ ObjectMethod setPermissions ()
Check each installed file against the manifest.  Apply the
permissions to the file.

=cut

sub setPermissions {
    my $this = shift;

    # foreach file in list, apply the permissions per the manifest
    my @names = $this->listFiles();
    foreach my $file (@names) {

        # Find where it is meant to go
        my $target =
          Foswiki::Configure::Util::mapTarget( $this->{_root}, $file );

        if ( -f $target ) {

            my $mode = $this->{_manifest}->{$file}->{perms};

            if ($mode) {
                $target =~ /(.*)/;
                $target = $1;    #yes, we must untaint
                $mode =~ /(.*)/;
                $mode = $1;      #yes, we must untaint
                chmod( oct($mode), $target )
                  unless ( $this->{_options}->{SIMULATE} );
            }
        }
    }
}

=begin TML

---++ listFiles ( $installed )
Return the sorted list of files in the package. 

If $installed is true, return the list of files that are actually installed
including rcs files.  

=cut

sub listFiles {
    my ( $this, $installed ) = @_;

    my @files;
    foreach my $key ( keys( %{ $this->{_manifest} } ) ) {
        next if ( $key eq 'ATTACH' );
        if ($installed) {
            my $target =
              Foswiki::Configure::Util::mapTarget( $this->{_root}, $key );
            push( @files, "$target" )   if ( -f "$target" );
            push( @files, "$target,v" ) if ( -f "$target,v" );
        }
        else {
            push( @files, $key );
        }
    }
    return sort(@files);
}

=begin TML
---++ ObjectMethod listPlugins ()
List the plugin modules provided by this extension.

=cut

sub listPlugins {
    my $this = shift;
    my %plugins;

    foreach my $plugin ( $this->listFiles() ) {
        my ($plugName) = $plugin =~ m/.*\/Plugins\/([^\/]+Plugin)\.pm$/;
        $plugins{$plugName} = 1 if $plugName;
    }
    return %plugins;
}

=begin TML

---++ uninstall ( $simulate )
Remove each file identified by the manifest.  Also remove
any rcs "...,v" files if they exist.   Note that directories
are NOT removed unless they are empty.

Returns the list of files that were removed.  If simulate is set to 
true, no files are uninstalled, but the list of files that would
have been removed is returned.

=cut

sub uninstall {
    my $this     = shift;
    my $simulate = shift;

    $simulate = $this->{_options}->{SIMULATE} unless ($simulate);

    my @removed;
    my %directories;

    # foreach file in the manifest, remove the file.
    foreach my $key ( keys( %{ $this->{_manifest} } ) ) {

        next if ( $key eq 'ATTACH' );

        # Find where it is meant to go
        my $target =
          Foswiki::Configure::Util::mapTarget( $this->{_root}, $key );

        if ($simulate) {
            push( @removed, "$target" )   if ( -f "$target" );
            push( @removed, "$target,v" ) if ( -f "$target,v" );
            $directories{$1}++ if $target =~ m!^(.*)/[^/]*$!;
        }
        else {

            if ( -f $target ) {
                my $n = unlink "$target";
                push( @removed, "$target" ) if ( $n == 1 );
            }
            if ( -f "$target,v" ) {
                my $n = unlink "$target,v";
                push( @removed, "$target,v" ) if ( $n == 1 );
            }
        }
    }

    my $pkgdata =
      "$Foswiki::cfg{WorkingDir}/configure/pkgdata/$this->{_pkgname}_installer";
    push( @removed, $pkgdata );
    unless ($simulate) {
        unlink "$pkgdata";
        for ( keys %directories ) {
            while (rmdir) { s!/[^/]*$!!; }
        }
    }
    return sort(@removed);
}

=begin TML

---++ loadInstaller ([$options])
This routine looks for the $extension_installer or 
$extension_installer.pl file  and extracts the manifest,
dependencies and pre/post Exit routines from the installer.  

If the installer is not found and a repository is provided, the
installer file will be retrieved from the repository.

The manifest and dependencies are parsed and loaded into their
respective hashes.  The pre and post routines are eval'd and 
installed as methods for this object.

   * =%options= (optional) options to override behavior - primarily for unit tests.
      * =DIR =>  directory where installer package is found
      * =USELOCAL => 1= Use local archives if found (Used by shell installations)
      * =EXPANDED => 1= Archive file has already been expanded - preventing any downloads - for unit tests

Returns:
   * Warning text if no fatal errors occurred
   * Error messages if load failed.

=cut

sub loadInstaller {
    my $this    = shift;
    my $options = shift;

    my $uselocal = $this->{_options}->{USELOCAL} || $options->{USELOCAL};
    my $temproot =
         $this->{_options}->{DIR}
      || $options->{DIR}
      || $this->{_root};

    my $file;
    my $err;

    my $pkgstore  = "$Foswiki::cfg{WorkingDir}/configure/pkgdata";
    my $extension = $this->{_pkgname};
    my $warn      = '';
    local $/ = "\n";

    if ($uselocal) {
        if ( -e "$temproot/${extension}_installer" ) {
            $file = "$temproot/${extension}_installer";
        }
        else {
            if ( -e "$temproot/${extension}_installer.pl" ) {
                $file = "$temproot/${extension}_installer.pl";
            }
            else {
                if ( -e "$pkgstore/${extension}_installer" ) {
                    $file = "$pkgstore/${extension}_installer";
                }
            }
        }
        $warn .= "Unable to find $extension locally in $temproot ..."
          unless ($file);
    }

    if ($file) {
        $warn .= "Using local $file for package manifest \n";
    }
    else {
        if ( defined $this->{_repository} ) {
            $warn .= "fetching installer from $this->{_repository}->{pub} ...";
            ( $err, $file ) = $this->_fetchFile('_installer');
            $warn .= " succeeded\n";
            if ($err) {
                $warn .= " Download failed \n - $err \n";
                $this->{_errors} .= "$err\n";
                return ( '', $warn );
            }
        }
        else {
            $warn .= 'unable to download - no repository provided';
            $this->{_errors} .= 'unable to download - no repository provided';
            return ( '', $warn );
        }
    }

    my $opened = open( my $fh, '<', $file );
    if ( !$opened ) {
        $err = "Extract manifest failed: $file -  $!";
        $this->{_errors} .= "$err\n";
        return ( '', $err );
    }

    my $found = '';
    my $depth = 0;
    while (<$fh>) {

        #if ( $_ =~ m/my PACKAGEURL
        if ( $_ eq "<<<< MANIFEST >>>>\n" ) {
            $found = 'M1';
            next;
        }
        else {
            if ( $_ eq "<<<< MANIFEST2 >>>>\n" ) {
                $found = 'M2';
                next;
            }
            else {
                if ( $_ eq "<<<< DEPENDENCIES >>>>\n" ) {
                    $found = 'D';
                    next;
                }
                else {
                    if (/sub\s*p(?:ost|re)(?:un)?install/) {
                        $found = 'P';
                    }
                }
            }
        }

        if ( $found eq 'M1' || $found eq 'M2' ) {
            if ( $_ eq "\n" ) {
                $found = '';
                next;
            }
            chomp $_;
            _parseManifest( $this, $_, ( $found eq 'M2' ) );
            next;
        }

        if ( $found eq 'D' ) {
            if ( $_ eq "\n" ) {
                $found = '';
                next;
            }
            chomp $_;
            $warn .= _parseDependency( $this, $_ ) if ($_);
            next;
        }

        if ( $found eq 'P' ) {

            # SMELL try to guess when the function is closed.
            # if brackets are not in pairs, this will fail, like { in comment
            $depth++ for /{/g;
            $depth-- for /}/g;
            $this->{_routines} .= $_;
            $found = '' unless $depth;
            next;
        }
    }
    close $fh;
    $this->{_loaded} = 1;
    return ( $warn, '' );
}

=begin TML

---++ ObjectMethod loadExits ()
Evaluate the pre and post install / uninstall routines extracted from 
the package file.  

=cut

sub loadExits {
    my $this = shift;
    my $err  = '';

    if ( $this->{_routines} ) {

        # Ensure it's clean, to avoid redefine error
        for (qw( preinstall postinstall preuninstall postuninstall )) {
            undef &{$_};
        }
        $this->{_routines} =~ /(.*)/sm;
        $this->{_routines} = $1;    #yes, we must untaint
        unless ( eval $this->{_routines} . "; 1; " ) {
            $err = "Couldn't load subroutines: $@";
            $this->{_errors} = $err;
        }
    }
    return;
}

=begin TML

---++ ObjectMethod deleteExits ()
Delete the pre and post install / uninstall routines from the namespace

=cut

sub deleteExits {
    my $this = shift;

    for (qw( preinstall postinstall preuninstall postuninstall )) {
        undef &{$_};
    }
    return;
}

=begin TML

---++ ObjectMethod Manifest ()
Return the manifest in printable format

=cut

sub Manifest {
    my ($this) = @_;
    my $rslt = '';

    foreach my $file ( sort keys( %{ $this->{_manifest} } ) ) {
        next if ( $file eq 'ATTACH' );
        $rslt .=
"$file $this->{_manifest}->{$file}->{perms} $this->{_manifest}->{$file}->{md5} $this->{_manifest}->{$file}->{desc}\n";
    }
    return $rslt;
}

=begin TML

---++ _parseManifest ( $line, $v2)
Parse the manifest line into the manifest hash.  If $v2 is
true, use the version 2 format containing the MD5 sum of 
the file.

->{filename}->{ci}      Flag if file should be "checked in"
->{filename}->{perms}   File permissions
->{filename}->{MD5}     MD5 of file (if available)

=cut

sub _parseManifest {
    my $this = shift;

    my $file  = '';
    my $perms = '';
    my $md5   = '';
    my $desc  = '';

    if ( $_[1] ) {
        ( $file, $perms, $md5, $desc ) = split( ',', $_[0], 4 );
    }
    else {
        ( $file, $perms, $desc ) = split( ',', $_[0], 3 );
    }

    return unless ($file);

    my $tweb    = '';
    my $ttopic  = '';
    my $tattach = '';

    if ( $file =~ m/^data\/.*/ ) {
        ( $tweb, $ttopic ) = $file =~ /^data\/(.*)\/(.*?).txt$/;
    }
    if ( $file =~ m/^pub\/.*/ ) {
        ( $tweb, $ttopic, $tattach ) = $file =~ /^pub\/(.*)\/(.*?)\/([^\/]+)$/;
    }

    $this->{_manifest}->{$file}->{ci}    = ( $desc =~ /\(noci\)/ ? 0 : 1 );
    $this->{_manifest}->{$file}->{perms} = $perms;
    $this->{_manifest}->{$file}->{md5}   = $md5 || '';
    $this->{_manifest}->{$file}->{topic} = "$tweb\t$ttopic\t$tattach";
    $desc =~ s/\(noci\)//;
    $this->{_manifest}->{$file}->{desc} = $desc;
    $this->{_manifest}->{ATTACH}->{"$tweb/$ttopic"}->{$tattach} = $file
      if ($tattach);
}

=begin TML

---++ _parseDependency ( \%DEPENDENCY, $_)
Parse the manifest line into the manifest hash.  

=cut

sub _parseDependency {
    my $this = shift;
    my $deps = $this->{_dependency};

    require Foswiki::Sandbox;

    my $warn = '';
    my ( $module, $condition, $trigger, $type, $desc ) =
      split( ',', $_[0], 5 );

    return unless ($module);

    if ( $type =~ m/cpan|perl/i ) {
        $depwarn = '';
        $module = Foswiki::Sandbox::untaint( $module, \&_validatePerlModule );
        $warn .= $depwarn;
    }

    if ( $trigger eq '1' ) {

        # ONLYIF is rare and dangerous
        push(
            @$deps,
            new Foswiki::Configure::Dependency(
                module      => $module,
                type        => $type,
                version     => $condition || 0,    # version condition
                trigger     => 1,                  # ONLYIF condition
                description => $desc
            )
        );
    }
    else {

        # There is a ONLYIF condition, warn user
        $warn .=
            "The script uses an ONLYIF condition for module $module"
          . ' which is potentially insecure: "'
          . $trigger . '"' . "\n";
        if ( $trigger =~ /^[a-zA-Z:\s<>0-9.()\$]*$/ ) {

            # It looks more or less safe
            push(
                @$deps,
                new Foswiki::Configure::Dependency(
                    module      => $module,
                    type        => $type,
                    version     => $condition,    # version condition
                    trigger     => $trigger,      # ONLYIF condition
                    description => $desc
                )
            );
        }
        else {
            $warn .=
                'This ' 
              . $trigger
              . ' condition does not look safe and is being disabled.' . "\n";
            $warn .=
              "This dependency on $module should be manually resolved \n";
        }
    }
    return $warn;
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
Checks the dependencies listed for this module.  Returns two "reports";
Installed dependencies and Missing dependencies.   It also returns a 
list of Foswiki package names that might be installed and a list of the
CPAN modules that could be installed.

=cut

sub checkDependencies {
    my $this      = shift;
    my $which     = shift;
    my $installed = '';
    my $missing   = '';
    my @wiki;
    my @cpan;
    my @manual;

    foreach my $dep ( @{ $this->{_dependency} } ) {

        ( my $trigger ) = $dep->{trigger} =~ /^(.*)$/s;
        my $required =
          eval "$trigger";  # Evaluate the trigger - if true, module is required
        next unless $required;    # Skip the module - trigger was false
        my $trig = '';
        $trig = " -- Triggered by $dep->{trigger}\n"
          unless ( $dep->{trigger} eq '1' );

        my ( $ok, $msg ) = $dep->check();
        if ($ok) {
            $installed .= "$msg$trig\n";
            next;
        }

        $missing .= "$msg$trig";
        $missing .= " -- Description: $dep->{description}\n"
          if ( $dep->{description} );
        $missing .=
          " -- Optional dependency will not be automatically installed\n"
          if ( $dep->{description} =~ m/^[Oo]ptional/ );
        $missing .= "\n";

        if ( $dep->{module} =~ m/^(Foswiki|TWiki)::(Contrib|Plugins)::(\w*)/ ) {
            my $type     = $1;
            my $pack     = $2;
            my $packname = $3;
            $packname .= $pack
              if ( $pack eq 'Contrib' && $packname !~ /Contrib$/ );
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
    return ( $installed, $missing, \@wiki, \@cpan, \@manual );

}

=begin TML
---++ ObjectMethod installDependencies ()
Installs the dependencies listed for this module.  Returns the details
of the installation.   

=cut

sub installDependencies {
    my $this    = shift;
    my $tmpRslt = '';
    my $rslt    = '';
    my $cpan;
    my $plugins;
    my %pluglist;
    my %cpanlist;

    foreach my $dep ( @{ $this->checkDependencies('wiki') } ) {
        my ( $ok, $msg ) = $dep->check();
        unless ($ok) {
            my $deppkg = new Foswiki::Configure::Package(
                $this->{_root},    $dep->{name},
                $this->{_session}, $this->{_options}
            );
            $deppkg->repository( $this->repository() );
            ( $tmpRslt, $plugins, $cpan ) = $deppkg->fullInstall();
            $this->{_errors} .= $deppkg->errors();
            $rslt .= $tmpRslt;
            @pluglist{ keys %$plugins } = values %$plugins;
            @cpanlist{ keys %$cpan }    = values %$cpan;
        }
    }
    return ( $rslt, \%pluglist, \%cpanlist );
}

#
#  Internal function to fetch a file from a repository - passed parameters:
#  * A repository hash
#       my $repository = {
#          name => 'Foswiki',
#          data => 'http://foswiki.org/Extensions/',
#          pub => 'http://foswiki.org/pub/Extensions/' };
#  * The filetype to be fetched - .tgz,  .zip,  .md5,  _installer
#  The function returns the file location & name,  along with a message if any.
#
sub _fetchFile {
    my $this = shift;
    my $ext  = shift;

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

    my $feedback;

    my $response = Foswiki::Configure::Package::_getUrl($arf);
    if ( !$response->is_error() ) {
        eval { $ar = $response->content(); };
    }
    else {
        $@ = $response->message();
    }

    if ($@) {
        $feedback .= <<HERE;
I can't download $arf because of the following error:
$@
HERE
        return $feedback;
    }

    if ( !defined($ar) ) {
        $feedback .= <<HERE;
No content.  Extension may not have been packaged correctly.
HERE
        return $feedback;
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

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
