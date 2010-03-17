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
use Error qw(:try);
use Assert;

our $VERSION = '$Rev: 6590 $';

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
Required for installer methods - used for checkin operations.
      
=cut

sub new {
    my ( $class, $root, $pkgname, $type, $session ) = @_;

    my $this = bless(
        {
            _root => $root,
            _pkgname => $pkgname,
            _type => $type,
            _session => $session,
            # Hash mapping the topics, attachment and other files supplied by this package
            _manifest => undef,
            # Hash mapping the dependencies required by this package 
            _dependency => undef,
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
    undef $this->{_manifest};
    undef $this->{_dependency};
}

=begin TML

---++ ObjectMethod session()

Get or set the session associated with the object.

=cut

sub session {
    my ( $this, $session ) = @_;
    $this->{_session} = $session if defined $session;
    return $this->{_session};
}

=begin TML

---++ ObjectMethod pkgname([$name])
   * =$name= - optional, change the package name in the object
      * *Since* 28 Nov 2008
Get/set the web name associated with the object.

=cut

sub pkgname {
    my ( $this, $pkgname ) = @_;
    $this->{_web} = $pkgname if defined $pkgname;
    return $this->{_pkgname};
}

=begin TML

---++ ObjectMethod install( $dir )

Install files listed in the manifest.  $dir is the temporary directory where the 
Extension package has been unpacked for installation

Missing directories are created as required.  The files are mapped into non-standard
locations by the mapTarget utility routine.  If a file is read-only, it is temporarily
overridden and the mode of the file is restored after the move.

The $session is a Foswiki session used for Topic checkin when required.  The session - while
optional, must be set prior to running the install method.

Files are "checked in" by creating a Topic Meta object and using the Foswiki Meta API to 
save the topic.

 - If the file is new, with no history, it is simply copied, 
 - If the file exists and has rcs history ( *,v file exists), it is always checked in 
 - If the file exists without history, the Manifest "CI" flag is followed

=cut

sub install {
    my $this = shift;    
    my $dir = shift;       # Location of unpacked extension

    my $session = $this->{_session};   # Session used for file checkin - should be admin user.
    my $root = $this->{_root};      # Root of the foswiki installation
    my $manifest = $this->{_manifest};  # Reference to the manifest 

    my @names = $this->files();         # Retrieve list of filenames from manifest
    my $results = '';                   # Results from install
    my $err = '';                       # Accumulated errors

    # foreach file in list, move it to the correct place
    foreach my $file (@names) {

        if ( $file =~ /^bin\/[^\/]+$/ ) {
            my $perlLoc = Foswiki::Configure::Util::getPerlLocation();
            Foswiki::Configure::Util::rewriteShbang("$dir/$file", "$perlLoc") if $perlLoc;
        }

        # Find where it is meant to go
        my $target = Foswiki::Configure::Util::mapTarget($this->{_root},$file);

        # If a file exists where a directory will go, clean it up.
        # and then make the directory if necessary.  Need to remove
        # trailing slash from filename to clean it up.
        #if ( -d "$dir/$file" ) {
        #    my $tf = $target;
        #    chop $tf if ( substr( $tf, -1 ) eq '/' );
        #    chmod( oct(600), "$tf") if (!-w $tf);  
        #    unlink $tf if (-f $tf) ;
        #    unless ( -e $target) {
        #        unless ( mkdir($target) ) {
        #            return "Cannot create directory $target: $!";
        #        }
        #    }
        #    next;
        #}

        # Make file writable if it is read-only 
        if ( -e $target && !-w $target ) {
            chmod( oct(600), "$target");
            }

        # Move or copy the file. 
        if ( -f "$dir/$file" ) {  # Exists as a file.
            my $installed = $manifest->{$file}->{I} || ''; # Set to 1 if file already installed
            next if ($installed);
            $manifest->{$file}->{I} = 1;   # Set this to installed (assuming it all works)

            my $ci = $manifest->{$file}->{ci} || '';       # Set to 1 if checkin desired
            my $perms = $manifest->{$file}->{perms};       # File permissions

            # Topic files in the data directory needing Checkin
            if ( $file =~ m/^data/ && (-e "$target,v" || (-e "$target" && $ci ) ) ) {
                my ($tweb, $ttopic) = $file =~ /^data\/(.*)\/(\w+).txt$/;

                my %opts;
                $opts{forcenewrevision} = 1;
                #$opts{dontlog} = 1;

                local $/ = undef;
                open(my $fh, '<', "$dir/$file" ) ;
                my $contents = <$fh>;
                close $fh;

                if ($contents) {
                    $results .= "Checked in: $file  as $tweb.$ttopic \n";
                    my $meta = Foswiki::Meta->new( $session, $tweb, $ttopic, $contents );
                    _installAttachments($this, $dir, "$tweb/$ttopic", $meta, $manifest, $results );
                    $meta->saveAs ( $tweb, $ttopic, %opts );
                }
                next;
            }


            # Everything else
            my $msg .= _moveFile ("$dir/$file", "$target", $perms);
            $err .= $msg if ($msg);
            $results .= "Installed:  $file  \n";
            next;
            }
        }
        my $pkgstore = "$Foswiki::cfg{WorkingDir}/configure/pkgdata";
        my $msg = _moveFile ("$dir/$this->{_pkgname}_installer", "$pkgstore/$this->{_pkgname}_installer");
        $results .= "Installed:  $pkgstore/$this->{_pkgname}_installer \n";

        $err .= $msg if ($msg);
        return ($results, $err);

}

=begin TML
---+++ _installAttachments ()

Install the attachments associated with a topic.  

=cut
sub _installAttachments {
    my $this = shift;
    my $dir = shift;
    my $webTopic = shift;
    my $meta = shift;
    my $manifest = shift;
    my $results = shift;

    foreach my $key ( keys %{ $this->{_manifest}->{ATTACH}->{$webTopic} } ) {
        my $file = $this->{_manifest}->{ATTACH}->{$webTopic}->{$key};
        my $attachinfo = $meta->get( 'FILEATTACHMENT', $key );  # Recover existing Metadata
        if ( ($this->{_manifest}->{$file}->{ci} && (-e "$this->{_root}/$file")) || (-e "$this->{_root}/$file,v" )) {
            $this->{_manifest}->{$file}->{I} = 1;   # Set this to installed (assuming it all works)
            my @stats    = stat "$dir/$file";
            my %opts;
            $opts{name} = $key;
            $opts{file} = "$dir/$file";
            #$opts{dontlog} = 1;
            $opts{attr} = $attachinfo->{attr};
            $opts{comment} = $attachinfo->{comment};
            $opts{filesize} = $stats[7];
            $opts{filedate} = $stats[9];
            $meta->attach (%opts);
            $results .= "  Attached: $file to $webTopic \n";
            }
        }
}
   
sub _moveFile {
   my $from = shift;
   my $to = shift;
   my $perms = shift;

   my @path = split( /[\/\\]+/, $to, -1 ); # -1 allows directories            
   pop(@path);                                                                    
   if ( scalar(@path) ) {                                                         
       File::Path::mkpath( join( '/', @path ) );                                  
       }                                                                              

   if ( !File::Copy::move( "$from", $to ) ) {
       if ( !File::Copy::copy( "$from", $to ) ) {
            return "Failed to move/copy file '$from' to $to: $!";
            }
        }
   $to = Foswiki::Sandbox::untaintUnchecked($to);
   $perms = Foswiki::Sandbox::untaintUnchecked($perms);
   chmod( oct($perms), "$to") if (defined $perms) ;
   return 0;
}


=begin TML

---++ ObjectMethod setPermissions ()
Check each installed file against the manifest.  Apply the
permissions to the file.

=cut

sub setPermissions {
    my $this = shift;

    # foreach file in list, apply the permissions per the manifest
    my @names = $this->files();
    foreach my $file (@names) {

        # Find where it is meant to go
        my $target = Foswiki::Configure::Util::mapTarget($this->{_root},$file);

        if (-f $target) {

            my $mode = $this->{_manifest}->{$file}->{perms};

            if ($mode) {
                $target = Foswiki::Sandbox::untaintUnchecked($target);
                $mode = Foswiki::Sandbox::untaintUnchecked($mode);
                chmod( oct($mode), $target);
            }
        }
    }
}

=begin TML

---++ files ( $installed )
Return the sorted list of files in the package. 

If $installed is true, return the list of files that are actually installed
including rcs files.  

=cut

sub files {
    my ($this, $installed)  = @_;

    my @files;
    foreach my $key ( keys( % {$this->{_manifest}} ) ) {
        next if ($key eq 'ATTACH');
        if ($installed) {
            my $target = Foswiki::Configure::Util::mapTarget($this->{_root},$key);
            push (@files, "$target") if  (-f "$target");
            push (@files, "$target,v") if  (-f "$target,v");
        } else {
            push (@files, $key);
        }
    }
    return sort(@files);
}

=begin TML

---++ uninstall ( $simulate )
Remove each file identified by the manifest.  Also remove
any rcs "...,v" files if they exist.   Note that directories
are NOT removed.

Returns the list of files that were removed.  If simulate is set to 
true, no files are uninstalled, but the list of files that would
have been removed is returned.

=cut

sub uninstall {
    my $this = shift;
    my $simulate = shift;
   
    my @removed;

    # foreach file in the manifest, remove the file. 
    foreach my $key ( keys( % {$this->{_manifest}} ) ) {

        next if ($key eq 'ATTACH');

        # Find where it is meant to go
        my $target = Foswiki::Configure::Util::mapTarget($this->{_root},$key);

        if ($simulate) {
            push (@removed, "$target") if  (-f "$target");
            push (@removed, "$target,v") if  (-f "$target,v");
        } else {

            if (-f $target) {
                chmod( '0600', $target);
                unlink "$target";
                push (@removed, "$target");
                }
            if (-f "$target,v") {
                chmod( '0600', "$target,v");
                unlink "$target,v";
                push (@removed, "$target,v");
                }
            }
        }

    my $pkgdata = "$Foswiki::cfg{WorkingDir}/configure/pkgdata/$this->{_pkgname}_installer";
    push (@removed, $pkgdata);
    unless ( $simulate ) {
        chmod( '0600', $pkgdata);
        unlink "$pkgdata";
        }
    return sort(@removed);
}

=begin TML

---++ loadInstaller ([$temproot] )
This routine looks for the $extension_installer or 
$extension_installer.pl and extracts the manifest
and dependencies from the installer.  

->{filename}->{ci}      Flag if file should be "checked in"
->{filename}->{perms}   File permissions
->{filename}->{MD5}     MD5 of file (if available)

=cut

sub loadInstaller {
    my ($this, $temproot) = @_;
    $temproot = $this->{_root} unless defined $temproot;

    my $extension = $this->{_pkgname};
    local $/ = "\n";

    my $file;
    if (-e "$temproot/${extension}_installer") {
       $file = "$temproot/${extension}_installer"; 
    } else {
       if (-e "$temproot/${extension}_installer.pl") {
           $file = "$temproot/${extension}_installer.pl";
       } else {
           return "ERROR - Extension $extension package not found ";
           }
    }     

    open(my $fh, '<', $file) || return "Extract manfiest failed: $file -  $!";

    my $found = '';
    while (<$fh>) {
       if ( $_ eq "<<<< MANIFEST >>>>\n" ) {
           $found = 'M1';
           next;
       } else {
           if ( $_ eq "<<<< MANIFEST2 >>>>\n" ) { 
               $found = 'M2';
               next;
           } else {
               if ( $_ eq "<<<< DEPENDENCIES >>>>\n" ) { 
                   $found = 'D';
                   next;
               }
           }
       }

       if ($found eq 'M1' || $found eq 'M2' ) {
          if ( $_ eq "\n") {
             $found = '';
             next;
          }
          chomp $_;
          _parseManifest ($this, $_, ($found eq 'M2') );
          next;
       }

       if ($found eq 'D' ) {
          if ( $_ eq "\n") {
             $found = '';
             next;
          }
          chomp $_;
          _parseDependency ($this, $_ ) if ($_);
          next;
       }
    }
    
    close $fh;
    return '';
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

    my $file = '';
    my $perms = '';
    my $md5 = '';
    my $desc = '';

    if ( $_[1] ) {
        ( $file, $perms, $md5, $desc ) = split( ',', $_[0], 4 ) ; 
    } else {
        ( $file, $perms, $desc ) = split( ',', $_[0], 3 );
    }

    return unless ($file);

    my $tweb = '';
    my $ttopic = '';
    my $tattach = '';

    if ( $file =~ m/^data\/.*/ ) {
        ($tweb, $ttopic) = $file =~ /^data\/(.*)\/(\w+).txt$/;
    }
    if ( $file =~ m/^pub\/.*/ ) {
        ($tweb, $ttopic, $tattach) = $file =~ /^pub\/(.*)\/(\w+)\/([^\/]+)$/;
    }

    $this->{_manifest}->{$file}->{ci} = ( $desc =~ /\(noci\)/ ? 0 : 1 );
    $this->{_manifest}->{$file}->{perms} = $perms;
    $this->{_manifest}->{$file}->{md5} = $md5 if ($md5);
    $this->{_manifest}->{$file}->{topic} = "$tweb\t$ttopic\t$tattach";
    $this->{_manifest}->{$file}->{desc} = $desc =~ s/\(noci\)//;
    $this->{_manifest}->{ATTACH}->{"$tweb/$ttopic"}{$tattach} = $file if ($tattach);
}

=begin TML

---++ _parseDependency ( \%DEPENDENCY, $_)
Parse the manifest line into the manifest hash.  

=cut

sub _parseDependency {
    my $this = shift;

    require Foswiki::Sandbox;

    my $warn = undef;
    my ( $module, $condition, $trigger, $type, $desc ) =
        split( ',', $_[0], 5 );

    return unless ($module);
   
    if ( $type =~ m/cpan|perl/i ) {
        $module  = Foswiki::Sandbox::untaint( $module, \&_validatePerlModule );
    }   

    $this->{_dependency}->{$module}->{condition} = $condition;
    $this->{_dependency}->{$module}->{trigger} = $trigger;
    $this->{_dependency}->{$module}->{type} = $type ;
    $this->{_dependency}->{$module}->{desc} = $desc ;
    $this->{_dependency}->{$module}->{warning} = $warn ;

}

# This is used to ensure the perl module dependencies
# provided by the module are real module names, and not some random garbage
# which could be potentially insecure.
sub _validatePerlModule {
    my $module = shift;
    # Remove all non alpha-numeric caracters and :
    # Do not use \w as this is localized, and might be tainted
    my $replacements = $module =~ s/[^a-zA-Z:_0-9]//g;
    #my $warn = 'validatePerlModule removed '
    #  . $replacements
    #  . ' characters, leading to '
    #  . $module . "\n"
    #  if $replacements;
    #print "$module - $replacements - $warn \n";
    return $module;
}

1;

__END__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
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
# See bottom of file for license and copyright information

