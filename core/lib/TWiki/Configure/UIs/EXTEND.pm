#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
package TWiki::Configure::UIs::EXTEND;
use base 'TWiki::Configure::UI';

use strict;
use File::Temp;
use File::Copy;
use File::Spec;
use Cwd;

sub ui {
    my $this = shift;
    my $query = $TWiki::query;
    my $ar;
    my $extension = $query->param('extension');
    $extension =~ /(\w+)/; # filter-in and untaint
    $extension = $1;
    die "Bad extension name" unless $extension;
    my $ext = '.tgz';

    $this->findRepositories();

    my $repository = $this->getRepository($query->param('repository'));
    if (!defined($repository)) {
        return $this->ERROR("Repository not found. <pre> ".$query->param('repository')." </pre>");
    }
    my $arf = $repository->{pub}.$extension.'/'.$extension.$ext;

    print "<br/>Fetching $arf...<br />\n";
    my $response = $this->getUrl($arf);
    if (!$response->is_error()) {
        eval { $ar = $response->content(); };
    } else {
        $@ = $response->message();
    }

    if ($@) {
        print $this->WARN(<<HERE);
I can't download $arf because of the following error:
<pre>$@</pre>
HERE
        undef $ar;
    }

    if (!defined($ar)) {
        print $this->WARN(<<HERE);
Extension may not have been packaged correctly.
Trying for a .zip file instead.
HERE
        $ext = '.zip';
        $arf = $repository->{pub}.$extension.'/'.$extension.$ext;
        print "<br/>Fetching $arf...<br />\n";
        $response = $this->getUrl($arf);
        if (!$response->is_error()) {
            eval { $ar = $response->content(); };
        } else {
            $@ = $response->message();
        }
        if ($@) {
            print $this->WARN(<<HERE);
I can't download $arf because of the following error:
<pre>$@</pre>
HERE
            undef $ar;
        }
    }

    unless ($ar) {
        return $this->ERROR(<<MESS);
Please follow the published process for manual installation from the
command line.
MESS
    }

    # Strip HTTP headers if necessary
    $ar =~ s/^HTTP(.*?)\r\n\r\n//sm;

    # Save it somewhere it will be cleaned up
    my ($tmp, $tmpfilename) = File::Temp::tempfile(SUFFIX => $ext, UNLINK=>1);
    binmode($tmp);
    print $tmp $ar;
    $tmp->close();
    print "Unpacking...<br />\n";
    my $dir = _unpackArchive($tmpfilename);

    my @names = _listDir($dir);
    # install the contents
    my $installScript = undef;
    unless ($query->param('confirm')) {
        foreach my $file (@names) {
            my $ef = $this->_findTarget($file);
            if (-e $ef && !-d $ef) {
                my $mess = "Note: Existing $file overwritten.";
                if (File::Copy::move($ef, "$ef.bak")) {
                    $mess .= " Backup saved in $ef.bak";
                }
                print $this->NOTE("$mess<br />");
            } else {
                print "$file<br />";
            }
            if( $file =~ /^${extension}_installer(\.pl)?$/) {
                $installScript = $this->_findTarget($file);
            }
        }
        unless ($installScript) {
            print $this->WARN(
                "No installer script found in archive");
        }
    }

    # foreach file in archive, move it to the correct place
    foreach my $file (@names) {
        # The file may already have been moved along with its directory
        next unless -e "$dir/$file";
        # Find where it is meant to go
        my $ef = $this->_findTarget($file);
        if (-e $ef && !-d $ef && !-w $ef) {
            print $this->ERROR("No permission to write to $ef");
            die "Installation terminated";
        } elsif (!-d $ef) {
            if (-d "$dir/$file") {
                unless (mkdir($ef)) {
                    print $this->ERROR(
                        "Cannot create directory $ef: $!");
                    die "Installation terminated";
                }
            } elsif (!File::Copy::move("$dir/$file", $ef)) {
                print $this->ERROR("Failed to move file '$file' to $ef: $!");
                die "Installation terminated";
            };
        }
    }

    if ($installScript && -e $installScript) {
        # invoke the installer script.
        # SMELL: Not sure yet how to handle
        # interaction if the script ignores -a. At the moment it
        # will just hang :-(
        chdir($this->{root});
        unshift(@ARGV, '-a');
        print "<pre>\n";
        eval {
            no warnings 'redefine';
            unshift(@INC, '.'); # needed to find tools/extender.pl
            do $installScript;
            use warnings 'redefine';
            die $@ if $@; # propagate
        };
        print "</pre>\n";
        if ($@) {
            print $this->ERROR(<<HERE);
Installer returned errors:
<pre>$@</pre>
You may be able to resolve these errors and complete the installation
from the command line, so I will leave the installed files where they are.
HERE
        } else {
            print $this->NOTE("Installer ran without errors");
        }
        chdir($this->{bin});
    }

    if ($this->{warnings}) {
        print $this->NOTE(
            "Installation finished with $this->{errors} error".
              ($this->{errors}==1?'':'s').
                " and $this->{warnings} warning".
                  ($this->{warnings}==1?'':'s'));
    } else {
        print 'Installation finished.';
    }
    unless ($installScript) {
        print $this->WARN(<<HERE);
You should test this installation very carefully, as there is no installer
script. This suggests that $arf may have been generated manually, and may
require further manual configuration.
HERE
    }
    if ($extension =~ /Plugin$/) {
        print $this->NOTE(<<HERE);
Note: Before you can use newly installed plugins, you must enable them in the
"Plugins" section in the main page.
HERE
    }

    return '';
}

# Find the installation target of a single file. This involves remapping
# through the settings in LocalSite.cfg. If the target is not remapped, then
# the file is installed relative to the root, which is the directory
# immediately above bin.
sub _findTarget {
    my ($this, $file) = @_;

    if ($file =~ s#^data/#$TWiki::cfg{DataDir}/#) {
    } elsif ($file =~ s#^pub/#$TWiki::cfg{PubDir}/#) {
    } elsif ($file =~ s#^templates/#$TWiki::cfg{TemplateDir}/#) {
    } elsif ($file =~ s#^locale/#$TWiki::cfg{LocalesDir}/#) {
    } elsif ($file =~ s#^(bin/\w+)$#$this->{root}$1$TWiki::cfg{ScriptSuffix}#) {
        #This makes a couple of bad assumptions
        #1. that the twiki's bin dir _is_ called bin
        #2. that any file going into there _is_ a script - making installing the 
        #   .htaccess file via this machanism impossible
        #3. that softlinks are not in use (same issue below)
    } else {
        $file = File::Spec->catfile($this->{root}, $file);
    }
    return $file;
}

# Recursively list a directory
sub _listDir {
    my ($dir, $path) = @_;
    $path ||= '';
    $dir .= '/' unless $dir =~ /\/$/;
    my $d;
    my @names = ();
    if (opendir($d, "$dir$path")) {
        foreach my $f ( grep { !/^\.*$/ } readdir $d ) {
            # Someone might upload a package to twiki.org that contains
            # a filename which, when passed to File::Copy, does something
            # evil. Check and untaint the filenames here.
            # SMELL: potential problem with unicode chars in file names?
            $f =~ /([\w.]+)/; $f = $1;
            if (-d "$dir$path/$f") {
                push(@names, "$path$f/");
                push(@names, _listDir($dir, "$path$f/"));
            } else {
                push(@names, "$path$f");
            }
        }
        closedir($d);
    }
    return @names;
}

=pod

---++ StaticMethod _unpackArchive($archive [,$dir] )
Unpack an archive. The unpacking method is determined from the file
extension e.g. .zip, .tgz. .tar, etc. If $dir is not given, unpack
to a temporary directory, the name of which is returned.

=cut

sub _unpackArchive {
    my ($name, $dir) = @_;

    $dir ||= File::Temp::tempdir(CLEANUP=>1);
    my $here = Cwd::getcwd();
    $here =~ /(.*)/; $here = $1; # untaint current dir name
    chdir( $dir );
    unless( $name =~ /\.zip/i && _unzip( $name ) ||
              $name =~ /(\.tar\.gz|\.tgz|\.tar)/ && _untar( $name )) {
        $dir = undef;
        print "Failed to unpack archive $name<br />\n";
    }
    chdir( $1 );

    return $dir;
}

sub _unzip {
    my $archive = shift;

    eval 'use Archive::Zip';
    unless ( $@ ) {
        my $zip = Archive::Zip->new( $archive );
        unless ( $zip ) {
            print "Could not open zip file $archive<br />\n";
            return 0;
        }

        my @members = $zip->members();
        foreach my $member ( @members ) {
            my $file = $member->fileName();
            my $target = $file ;
            my $err = $zip->extractMember( $file, $target );
            if ( $err ) {
                print "Failed to extract '$file' from zip file ",
                  $zip,". Archive may be corrupt.<br />\n";
                return 0;
            }
        }
    } else {
        print "Archive::Zip is not installed; trying unzip on the command line<br />\n";
        print `unzip $archive`;
        # On certain older versions of perl / unzip it seems the unzip results
        # in an illegal seek error. But running the same command again often
        # goes well. Seems like the 2nd pass works because the subdirectories
        # are then created. A hack but it seems to work.
        if ( $! ) {
            print `unzip $archive`;
            if ( $! ) {
                print "unzip failed: $!\n";
                return 0;
            }
        }
    }

    return 1;
}

sub _untar {
    my $archive = shift;

    my $compressed = ( $archive =~ /z$/i ) ? 'z' : '';

    eval 'use Archive::Tar';
    unless ( $@ ) {
        my $tar = Archive::Tar->new( $archive, $compressed );
        unless ( $tar ) {
            print "Could not open tar file $archive<br />\n";
            return 0;
        }

        my @members = $tar->list_files();
        foreach my $file ( @members ) {
            my $err = $tar->extract( $file );
            unless ( $err ) {
                print 'Failed to extract ',$file,' from tar file ',
                  $tar,". Archive may be corrupt.<br />\n";
                return 0;
            }
        }
    } else {
        print "Archive::Tar is not installed; trying tar on the command-line<br />\n";
        print `tar xvf$compressed $archive`;
        if ( $! ) {
            print "tar failed: $!\n";
            return 0;
        }
    }

    return 1;
}

1;
