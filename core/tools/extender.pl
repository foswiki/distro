# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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
#
# Author: Crawford Currie http://wikiring.com
#
# This module contains the functions used by the extensions installer.
# It is not treated as a "standard" module because it has radically
# different environment requirements (i.e. as few as possible)
#
# It is invoked from the individual installer scripts shipped with
# extensions, and should not be run directly.
#
package TWiki::Extender;
use strict;

use Cwd;
use File::Temp;
use File::Copy;
use File::Path;

no warnings 'redefine';

my $noconfirm = 0;
my $downloadOK = 0;
my $reuseOK = 0;
my $inactive = 0;
my $twiki;
my $twiki4OrMore;
my %available;
my $lwp;
my @archTypes = ( '.tgz', '.tar.gz', '.zip' );
my %cfg;
my $installationRoot;
my $MODULE;
my $PACKAGES_URL;
my $MANIFEST;

BEGIN {
    $installationRoot = Cwd::getcwd();
    my $check_perl_module = sub {
        my $module = shift;

        eval "use $module;";
        if( $@ ) {
            print "Warning: $module is not available, some installer functions have been disabled\n";
            $available{$module} = 0;
        } else {
            $available{$module} = 1;
        }
        return $available{$module};
    };

    unless ( -d 'lib' &&
             -d 'bin' &&
             -e 'bin/setlib.cfg' ) {
        die 'This installer must be run from the root directory of a TWiki installation';
    }
    # read setlib.cfg
    chdir('bin');
    require 'setlib.cfg';

    # See if we can make a TWiki. If we can, then we can save topic
    # and attachment histories. Key off TWiki::Merge because it was
    # added in Dakar.
    if( &$check_perl_module( 'TWiki::Merge' )) {
        eval {
            require TWiki;
            # We have to get the admin user, as a guest user may be blocked.
            # TWiki 4.2 has AdminUserLogin; for earlier releases, we need to
            # do something a bit different.
            my $user = $TWiki::cfg{AdminUserLogin} || 'admin';
            $twiki = new TWiki($user);
            # Compatibility with 4.0 <= TWiki::VERSION < 4.2
            if ($twiki->{users}->can('findUser')) {
                $TWiki::Plugins::SESSION = $twiki;
                $twiki->{user} =
                  $twiki->{users}->findUser(
                      $TWiki::cfg{AdminUserWikiName},
                      $TWiki::cfg{AdminUserWikiName});
            }
            chdir($installationRoot);
            $twiki4OrMore = 1;
        }; # if it fails, fall back to old behaviour
    } else {
        # Not TWiki-4
        chdir($installationRoot);
        no strict;
        do 'lib/TWiki.cfg';
        if( -e 'lib/LocalSite.cfg') {
            do 'lib/LocalSite.cfg';
        }
        use strict;
        $twiki4OrMore = 0;
    }

    if( &$check_perl_module( 'LWP' )) {
        $lwp = new LWP::UserAgent();
        $lwp->agent("PluginsInstaller");
        $lwp->env_proxy();
    }
    &$check_perl_module( 'CPAN' );
}

=pod

---+ StaticMethod remap ($file ) -> $file
Given a "canonical" path, convert it using the remappings in LocalSite.cfg to a site-
specific path. For example, if a site defines:
<verbatim>
$TWiki::cfg{UsersWebName} = 'Users';
</verbatim>
then this function will convert =data/Main/Burble.txt= to =data/Users/Burble.txt=.

Note: remapping only works for TWiki 4 and later. Anyone who cares enough can write
and test the mappings for Cairo.

=cut

sub remap {
    my $file = shift;
    if (defined $cfg{SitePrefsTopicName}) {
        $file =~ s#^data/(TWiki|Main)/TWikiPreferences\.txt(.*)$#data/$1/$cfg{SitePrefsTopicName}.txt$2#;
    }
    if (defined $cfg{UsersTopicName}) {
        $file =~ s#(Main)/WikiUsers\.txt(.*)$#$1/$cfg{UsersTopicName}.txt$2#;
    }
    foreach my $w qw( SystemWebName TrashWebName UsersWebName ) {
        if (defined $cfg{$w}) {
            $file =~ s#^data/$w/#data/$cfg{$w}/#;
            $file =~ s#^pub/$w/#pub/$cfg{$w}/#;
        }
    }
    foreach my $t qw( NotifyTopicName HomeTopicName WebPrefsTopicName MimeTypesFileName ) {
        if (defined $cfg{$t}) {
            $file =~ s#^data/(.*)/$t\.txt(,v)?#data/$1/$cfg{$t}.txt$2/#;
            $file =~ s#^pub/(.*)/$t/([^/]*)$#pub/$1/$cfg{$t}/$2/#;
        }
    }
    return $file;
}

sub check_dep {
    my $dep = shift;
    my( $ok, $msg ) = (1, '');

    if( $dep->{type} =~ /^(perl|cpan)$/i ) {
        # Try to 'use' the perl module
        eval 'use '.$dep->{name};
        if( $@ ) {
            $msg = $@;
            $msg =~ s/ in .*$/\n/s;
            $ok = 0;
        } else {
            # OK, it was loaded. See if a version constraint is specified
            if( defined( $dep->{version} ) ) {
                my $ver;
                # check the $VERSION variable in the loaded module
                eval '$ver = $'.$dep->{name}.'::VERSION;';
                if( $@ || !defined( $ver ) ) {
                    $msg .= 'The VERSION of the package could not be found: '.
                      $@;
                    $ok = 0;
                } else {
                    # The version variable exists. Clean it up
                    $ver =~ s/^.*\$Rev: (\d+)\$.*$/$1/;
                    $ver =~ s/[^\d]//g;
                    $ver ||= 0;
                    eval '$ok = ( $ver '.$dep->{version}.' )';
                    if( $@ || ! $ok ) {
                        # The version variable fails the constraint
                        $msg .= ' '.$ver.' is currently installed: '.$@;
                        $ok = 0;
                    }
                }
            }
        }
    } else {
        # This module has no perl interface, and can't be checked
        $ok = 0;
        $msg = <<END;
Module is type $dep->{type}, and cannot be automatically checked.
Please check it manually and install if necessary.
END
    }
    return ( $ok, $msg );
}

# Satisfy dependencies on modules, by checking:
# 1. If the module is a perl module, then:
#    1. If the module is loadable in the current environment
#    2. If the dependency has specified a version constraint, then
#       the module must have a top-level variable VERSION which satisfies
#       the constraint.
#       Note that all TWiki modules are perl modules - even non-perl
#       distributions have a perl 'stub' module that carries the version info.
# 2. If the module is _not_ perl, then we can't check it.
sub satisfy {
    my $dep = shift;
    my $trig = eval $dep->{trigger};

    return 1 unless ( $trig );

    print <<DONE;
##########################################################
Checking dependency on $dep->{name}....
DONE
    my ( $ok, $msg ) = check_dep( $dep );

    if( $ok ) {
        return 1;
    }

    print <<DONE;
*** $MODULE depends on $dep->{type} package $dep->{name} $dep->{version}
which is described as "$dep->{description}"
But when I tried to find it I got this error:

$msg
DONE

    if( $dep->{name} =~ m/^TWiki::(Contrib|Plugins)::(\w*)/ ) {
        my $pack = $1;
        my $packname = $2;
        $packname .= $pack if( $pack eq 'Contrib' && $packname !~ /Contrib$/);
        if (!$noconfirm || ($noconfirm && $downloadOK)) {
            my $reply = ask('Would you like me to try to download and install the latest version of '.$packname.' from twiki.org?');
            if( $reply ) {
                return installPackage( $packname );
            }
        }
        return 0;
    }

    if ( $dep->{type} eq 'cpan' && $available{CPAN} ) {
        print <<'DONE';
This module is available from the CPAN archive (http://www.cpan.org). You
can download and install it from here. The module will be installed
to wherever you configured CPAN to install to.

DONE
        my $reply = ask('Would you like me to try to download and install the latest version of '.$dep->{name}.' from cpan.org?');
        return 0 unless $reply;

        my $mod = CPAN::Shell->expand('Module', $dep->{name});
        my $info = $mod->dslip_status();
        if ($info->{D} eq 'S') {
            # Standard perl module!
            print STDERR <<DONE;
#########################################################################
# WARNING: $dep->{name} is a standard perl module
#
# I cannot install it without upgrading your version of perl, something
# I'm not willing to do. Please either install the module manually (from
# a package downloaded from cpan.org) or upgrade your perl to a version
# that includes this module.
#########################################################################

DONE
            return 0;
        }
        if ($noconfirm) {
            $CPAN::Config->{prerequisites_policy} = 'follow';
        } else {
            $CPAN::Config->{prerequisites_policy} = 'ask';
        }
        CPAN::install( $dep->{name} );
        ( $ok, $msg ) = check_dep( $dep );
        return 1 if $ok;

        my $e = 'it';
        if( $CPAN::Config->{makepl_arg} =~ /PREFIX=(\S+)/) {
            $e = $1;
        }
        print STDERR <<DONE;
#########################################################################
# WARNING: I still can't find the module $dep->{name}
#
# If you installed the module in a non-standard directory, make sure you
# have followed the instructions in bin/setlib.cfg and added $e
# to your \@INC path.
#########################################################################

DONE
    }

    return 0;
}

=pod

---++ StaticMethod ask( $question ) -> $boolean
Ask a question.
Example: =if( ask( "Proceed?" )) { ... }=

=cut

sub ask {
    my $q = shift;
    my $reply;

    return 1 if $noconfirm;
    local $/ = "\n";

    $q .= '?' unless $q =~ /\?\s*$/;

    print $q.' [y/n] ';
    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        print "Please answer yes or no\n";
    }
    return ( $reply =~ /^y/i ) ? 1 : 0;
}

=pod

---++ StaticMethod prompt( $question, $default ) -> $string
Prompt for a string, using a default if return is pressed.
Example: =$dir = prompt("Directory")=;

=cut

sub prompt {
    my( $q, $default) = @_;
    my $reply = '';
    local $/ = "\n";
    while( !$reply ) {
        print $q;
        print " ($default)" if defined $default;
        print ': ';
        $reply = <STDIN>;
        chomp($reply);
        $reply ||= $default;
    }
    return $reply;
}

# DEPRECATED - do not use - install a .spec instead
# ---++ StaticMethod getConfig( $major, $minor, $cairo ) -> $string
#    * =$major= name of major key.
#    * =$minor= if undefined, there is no minor key
#    * =$cairo= expression that when evaled will get the cairo style config var
# Get the value of a config var, trying first the Dakar option and
# then if that fails, the Cairo name (if any).
# Example:
# =getConfig("Name")=
# will get the value of =$TWiki::cfg{Name}=.
# =getConfig("MyPlugin", "Name")=
# will get the value of =$TWiki::cfg{Name}=.
# =getConfig("HomeTopicName", undef, '$mainTopicname')=
# will get the name of the WebHome topic on Dakar and Cairo.
#
# See setConfig for more information on major/minor keys.

sub getConfig {
    my( $major, $minor, $cairo ) = @_;

    if( $minor && defined $TWiki::cfg{$major}{$minor} ) {
        return getTWikiCfg("{$major}{$minor}");
    }
    if (!$minor && defined $TWiki::cfg{$major}) {
        return getTWikiCfg("{$minor}");
    }

    if( defined $cairo ) {
        return eval $cairo;
    }
    return undef;
}

# DEPRECATED - do not use - install a .spec instead
# ---++ StaticMethod commentConfig( $comment )
#    * $comment - comment to insert in LocalSite.cfg, usually before a setConfig
# Inserts a comment into LocalSite.cfg. The comment will usually describe a following setConfig; for example,
# <verbatim>
# commentConfig( <<HERE
# #---++ Cars Plugin
# # **STRING 30**
# # Name of manufacturer
# HERE
# );
# setConfig( 'CarsPlugin', Manufacturer => 'Mercedes' );
# </verbatim>

sub commentConfig {
    open(F, ">>lib/LocalSite.cfg") ||
              die "Failed to open lib/LocalSite.cfg for write";
    print F $_[0];
    close(F);
}

# DEPRECATED - do not use - install a .spec instead
# ---++ StaticMethod setConfig( $major, ... )
#    * =$major= if defined, name of major key. If not given, there is no major key and the minorkeys are treated as major keys
#    * =...= list of minorkey=>value pairs
# Set the given configuration variables in LocalSite.cfg. =$value= must be
# complete with all syntactic sugar, including quotes.
# The valued are written to $TWiki::cfg{major key}{setting} if a major
# key is given (recommended, use the plugin name) or $TWiki::cfg{setting} otherwise. Example:
# <verbatim>
# setConfig( 'CarsPlugin', Name=>"'Mercedes'" };
# setConfig( Tools => "qw(hammer saw screwdriver)" };
# </verbatim>
# will write
# <verbatim>
# $TWiki::cfg{CarsPlugin}{Best} = 'Mercedes';
# $TWiki::cfg{Tools} = qw(hammer saw screwdriver);
# </verbatim>

sub setConfig {
    my @settings = @_;
    my $txt;
    my $key;
    if (scalar(@settings) % 2) {
        # pluck the first odd parameter off to be the major key
        $key = shift @settings;
    }
    my %keys = @settings;
    if( -e "lib/LocalSite.cfg" ) {
        open(F, "<lib/LocalSite.cfg") ||
          die "Failed to open lib/LocalSite.cfg for read";
        local $/ = undef;
        $txt = <F>;
        close(F);
        $txt =~ s/\n+1;\s*//gs;
        # kill the old settings (and previous comment) if any are there
        foreach my $setting ( keys %keys ) {
            if( $key ) {
                $txt =~ s/(# \*\*.*?\n(#.*?\n))?\$TWiki::cfg{$key}{$setting}\s*=.*;\r?\n//s;
            } else {
                $txt =~ s/(# \*\*.*?\n(#.*?\n))?\$TWiki::cfg{$setting}\s*=.*;\r?\n//s;
            }
        }
    }
    $txt .= "\n" unless $txt =~ /\n$/s;
    open(F, ">lib/LocalSite.cfg") ||
      die "Failed to open lib/LocalSite.cfg for write";
    print F $txt if $txt;
    foreach my $setting ( keys %keys ) {
        if( defined $key ) {
            print F '$TWiki::cfg{'.$key.'}{'.$setting.'} = ';
        } else {
            print F '$TWiki::cfg{'.$setting.'} = ';
        }
        print F $keys{$setting}, ";\n";
    }
    print F "1;\n";
    close(F);

    # is this Cairo or earlier? If it is, we need to include
    # LocalSite.cfg from TWiki.cfg
    unless( $twiki4OrMore ) {
        open(F, "<lib/TWiki.cfg");
        undef $/;
        $txt = <F>;
        close(F);
        unless( $txt =~ /^do.*LocalSite\.cfg/m ) {
            $txt =~ s/^\s*1\s*;\s*$//m;
            open(F, ">lib/TWiki.cfg") ||
              die "Failed to open lib/TWiki.cfg for write";
            print F "$txt\ndo 'LocalSite.cfg';\n1;\n";
            close(F);
        }
    }
}

# Try and find an installer or archive.
# Look in (1) the current directory (2) on the $TWIKI_PACKAGES path and
# (3) in the twikiplugins subdirectory (if there, to support developers)
# and finally (4) download from $PACKAGES_URL
sub getComponent {
    my ($module, $types, $what) = @_;
    my $f;

    # Look for the archive.
    require Config;
    if (!$noconfirm || ($noconfirm && $reuseOK)) {
        foreach my $dir ($installationRoot,
                         $installationRoot.'/twikiplugins/'.$module,
                         split($Config::Config{path_sep},
                               $ENV{TWIKI_PACKAGES} || '')) {
            foreach my $type ( @$types ) { # .tgz preferred
                $f = $dir.'/'.$module.$type;
                if( -e $f ) {
                    my @st = stat($f);
                    my $credate = localtime($st[9]);
                    print <<HERE;
$f exists on this machine; would you like me to use it?
It was created on $credate.
If not, I will try to download a new one.
HERE
                    if (ask("Use existing $f?")) {
                        print "Got a local $what from $f\n";
                        return $f;
                    }
                }
            }
        }
    }

    unless( $lwp ) {
        print STDERR <<HERE;
Cannot find a local $what for $module, and LWP is not installed
so I can't download it. Please download it manually and re-run
this script.
HERE
        return undef;
    }

    my $url = "$PACKAGES_URL/$module/$module";
    my $downloadDir = $installationRoot;

    if ($ENV{TWIKI_PACKAGES} && -d $ENV{TWIKI_PACKAGES}) {
        # see if we can write in $TWIKI_PACKAGES
        my $test = $ENV{TWIKI_PACKAGES}.'/'.$$;
        if (open(F, ">$test")) {
            close(F);
            unlink($test);
            $downloadDir = $ENV{TWIKI_PACKAGES};
        }
    }

    my $response;
    foreach my $type ( @$types ) {
        $response = $lwp->get( $url.$type );

        if( $response->is_success() ) {
            $f = $downloadDir.'/'.$module.$type;
            open(F, ">$f" ) || die "Failed to open $f for write: $!";
            print F $response->content();
            close(F);
            last;
        }
    }

    unless ($f && -e $f) {
        print STDERR "Failed to download $module $what\n",
          $response->status_line(),"\n";
        return undef;
    } else {
        print "Downloaded $what from $PACKAGES_URL to $f\n";
    }

    return $f;
}

# Try and find an archive for the named module.
sub getArchive {
    my $module = shift;

    return getComponent($module, \@archTypes, 'archive');
}

# Try and find an installer for the named module.
sub getInstaller {
    my $module = shift;

    return getComponent($module, [ '_installer' ], 'installer');
}

# install a package by running the installer
sub installPackage {
    my( $module ) = @_;

    my $script = getInstaller( $module );
    if( $script && -e $script ) {
        my $cmd = "perl $script";
        $cmd .= ' -a' if $noconfirm;
        $cmd .= ' -n' if $inactive;
        $cmd .= ' install';
        local $| = 0;
        # Fork the installation of the downloaded package.
        my $pid = fork();
        if ($pid) {
            wait();
            if( $? ) {
                print STDERR "Installation of $module failed: $?\n";
                return 0;
            }
        } else {
            exec($cmd);
        }
    } else {
        print STDERR <<HERE;
I cannot locate an installer for $module.
$module may not have been designed to be installed with this installer.
I might be able to download and unpack a simple archive, but you will
have to satisfy the dependencies and finish the install of it yourself,
as per the instructions for $module.
HERE
        my $ans = ask("Would you like me to try to get an archive of $module?");
        return 0 unless ($ans);
        my $arch = getArchive($module);
        unless( $arch) {
            print STDERR <<HERE;
Cannot locate an archive for $module; installation failed.
HERE
            return 0;
        }
        # Unpack the archive in place. Don't bother trying to
        # look for a MANIFEST or run the installer script - it
        # was probably packaged by an amateur.
        unpackArchive($arch, $installationRoot);
    }

    return 1;
}

=pod

---++ StaticMethod unpackArchive($archive [,$dir] )
Unpack an archive. The unpacking method is determined from the file
extension e.g. .zip, .tgz. .tar, etc. If $dir is not given, unpack
to a temporary directory, the name of which is returned.

=cut

sub unpackArchive {
    my ($name, $dir) = @_;

    $dir ||= File::Temp::tempdir(CLEANUP=>1);
    chdir( $dir );
    unless( $name =~ /\.zip/i && unzip( $name ) ||
              $name =~ /(\.tar\.gz|\.tgz|\.tar)/ && untar( $name )) {
        $dir = undef;
        print STDERR "Failed to unpack archive $name\n";
    }
    chdir( $installationRoot );

    return $dir;
}

sub unzip {
    my $archive = shift;

    eval 'use Archive::Zip';
    unless ( $@ ) {
        my $zip = new Archive::Zip( $archive );
        unless ( $zip ) {
            print STDERR "Could not open zip file $archive\n";
            return 0;
        }

        my @members = $zip->members();
        foreach my $member ( @members ) {
            my $file = $member->fileName();
            my $target = $file ;
            my $err = $zip->extractMember( $file, $target );
            if ( $err ) {
                print STDERR "Failed to extract '$file' from zip file ",
                  $zip,". Archive may be corrupt.\n";
                return 0;
            } else {
                print "    $target\n";
            }
        }
    } else {
        print STDERR "Archive::Zip is not installed; trying unzip on the command line\n";
        print `unzip $archive`;
        if ( $? ) {
            print STDERR "unzip failed: $?\n";
            return 0;
        }
    }

    return 1;
}

sub untar {
    my $archive = shift;

    my $compressed = ( $archive =~ /z$/i ) ? 'z' : '';

    eval 'use Archive::Tar';
    unless ( $@ ) {
        my $tar = Archive::Tar->new( $archive, $compressed );
        unless ( $tar ) {
            print STDERR "Could not open tar file $archive\n";
            return 0;
        }

        my @members = $tar->list_files();
        foreach my $file ( @members ) {
            my $target = $file;

            my $err = $tar->extract_file( $file, $target );
            unless ( $err ) {
                print STDERR 'Failed to extract ',$file,' from tar file ',
                  $tar,". Archive may be corrupt.\n";
                return 0;
            } else {
                print "    $target\n";
            }
        }
    } else {
        print STDERR "Archive::Tar is not installed; trying tar on the command-line\n";
        print `tar xvf$compressed $archive`;
        if ( $? ) {
            print STDERR "tar failed: $?\n";
            return 0;
        }
    }

    return 1;
}

# Check in. On Cairo, do nothing because the apache user
# has everything checked out :-(
sub checkin {
    my( $web, $topic, $file ) = @_;

    # If this is Dakar, we have a good chance of completing the
    # install.
    my $err = 1;

    if( $twiki ) {
        if( $file ) {
            my $origfile = $TWiki::cfg{PubDir} . '/' . $web . '/' . $topic . '/' . $file;
            print "Add attachment $origfile\n";
            return 1 if ($inactive);
            print <<DONE;
##########################################################
Adding file: $file to installation ....
(attaching it to $web.$topic)
DONE
            # Need copy of file to upload it, use temporary location
            # Use non object version of File::Temp for Perl 5.6.1 compatibility
            my @stats = stat $origfile;
            my $fileSize = $stats[7];
            my $fileDate = $stats[9];

            # make sure it's readable and writable by the current user
            chmod(($stats[2] & 07777) | 0600, $origfile);

            my ($tmp, $tmpfilename) = File::Temp::tempfile(unlink=>1);
            File::Copy::copy($origfile, $tmpfilename) ||
              die "$origfile could not be copied to tmp dir ($tmpfilename): $!";
            eval {
                TWiki::Func::saveAttachment(
                    $web, $topic, $file,
                    { comment => 'Saved by install script',
                      file => $tmpfilename,
                      filesize => $fileSize,
                      filedate => $fileDate } );
            };
            $err = $@;
        } else {
            print "Add topic $web.$topic\n";
            return 1 if ($inactive);
            print <<DONE;
##########################################################
Adding topic: $web.$topic to installation ....
DONE
            # read the topic to recover meta-data
            eval {
                my( $meta, $text ) =
                  TWiki::Func::readTopic( $web, $topic );
                TWiki::Func::saveTopic(
                    $web, $topic, $meta, $text,
                    { comment => 'Saved by install script' } );
            };
            $err = $@;
        }
    }
    return ( !$err );
}

sub _uninstall {
    my $file;
    my @dead;
    foreach $file ( keys %$MANIFEST ) {
        if( -e $file ) {
            push( @dead, remap($file) );
        }
    }
    unless ( $#dead > 1 ) {
        print STDERR "No part of $MODULE is installed\n";
        return 0;
    }
    print "To uninstall $MODULE, the following files will be deleted:\n";
    print "\t".join( "\n\t", @dead )."\n";
    return 1 if $inactive;
    my $reply = ask("Are you SURE you want to uninstall $MODULE?");
    if( $reply ) {
        TWiki::preuninstall();
        foreach $file ( keys %$MANIFEST ) {
            if( -e $file ) {
                unlink( $file );
            }
        }
        TWiki::postuninstall();
        print "### $MODULE uninstalled ###\n";
    }
    return 1;
}

# 1 Check dependencies
# 2 Transfer files from temporary unpack area to the target installation
# 3 Check in any files with existing ,vs on disc
# 4 Perform post-install
sub _emplace {
    my $source = shift;

    # For each file in the MANIFEST, move the file into the installation,
    # set the permissions, and check if it is a data or pub file. If it is,
    # then check it in.
    my @topic;
    my @pub;
    my @bads;
    my $file;
    foreach $file ( keys %$MANIFEST ) {
        my $source = "$source/$file";
        my $target = remap($file);
        print "Install $target, permissions $MANIFEST->{$file}\n";
        unless ($inactive) {
            if (-e $target) {
                unless (File::Copy::move($target, "$target.bak")) {
                    print STDERR "Could not create $target.bak: $!\n";
                }
            }
            my @path = split(/[\/\\]+/, $target);
            pop(@path);
            if (scalar(@path)) {
                File::Path::mkpath(join('/',@path));
            }
            File::Copy::move($source, $target) ||
                die "Failed to move $source to $target: $!\n";
        }
        if( $target =~ /^data\/(\w+)\/(\w+).txt$/ ) {
            push(@topic, $target);
        } elsif( $target =~ /^pub\/(\w+)\/(\w+)\/([^\/]+)$/ ) {
            push(@pub, $target);
        }
        unless( $inactive ) {
            chmod( oct($MANIFEST->{$file}), $target ) ||
              print STDERR "WARNING: cannot set permissions on $target: $!\n";
        }
    }
    foreach $file ( @topic ) {
        $file =~ /^data\/(.*)\/(\w+).txt$/;
        unless( checkin( $1, $2, undef )) {
            push( @bads, $file );
        }
    }
    foreach $file ( @pub ) {
        $file =~ /^pub\/(.*)\/(\w+)\/([^\/]+)$/;
        unless( checkin( $1, $2, $3 )) {
            push( @bads, $file );
        }
    }

    if( scalar( @bads )) {
        print STDERR '
WARNING: I cannot automatically update the local revision history for:',"\n\t";
        print STDERR join( "\n\t", @bads );
        print STDERR <<DONE;

You can update the revision histories of these files by:
   1. Editing any topics and saving them without changing them,
   2. Uploading attachments to the same topics again.
Ignore this warning unless you have modified the files locally.
DONE
    }
}

sub usage {
    print STDERR <<DONE;
Usage: ${MODULE}_installer -a -n -d -r install
       ${MODULE}_installer -a -n uninstall
       ${MODULE}_installer manifest
       ${MODULE}_installer dependencies

Operates on the directory tree below where it is run from,
so should be run from the top level of your TWiki installation.

install will check dependencies and perform any required
post-install steps.

uninstall will remove all files that were installed for
$MODULE even if they have been locally modified.

-a means don't prompt for confirmation before resolving
   dependencies
-d means auto-download if -a (no effect if not -a)
-r means reuse packages on disc if -a (no effect if not -a)
-n means don't write any files into my current install, just
   tell me what you would have done

manifest will generate a list of the files in the package on
standard output. The list is generated in the same format as
the MANIFEST files used by BuildContrib.

dependencies will generate a list of dependencies on standard
output. the list is generated in the same format as the
DEPENDENCIES files used by BuidContrib.

DONE
}

# 1 Check and satisfy dependencies
# 2 Check if there is already an install of this module, and seek
#   overwrite confirmation
# 3 Locate a suitable archive, download if necessary
# 4 Unpack the archive
# 5 Move files into the target tree
# 6 Clean up
sub _install {
    my ($deps, $rootModule) = @_;
    my $unsatisfied = 0;
    foreach my $dep ( @$deps ) {
        unless ( satisfy( $dep ) ) {
            $unsatisfied++;
        }
    }

    my $path = $MODULE;

    if ($path !~ /^TWiki::/) {
        my $type = 'Contrib';
        if ($path =~ /Plugin$/) {
            $type = 'Plugins';
        }
        $path = 'TWiki::'.$type.'::'.$rootModule;
    }

    eval 'use '.$path;
    unless ($@) {
        my $version = eval '$'.$path.'::VERSION';
        if( $version ) {
            unless( ask("$MODULE version $version is already installed. Are you sure you want to re-install this module?")) {
                return 0;
            }
            print <<DONE;
I will keep a backup of any files I overwrite.
DONE
        }
    }

    print "Fetching the archive for $path.\n";
    my $archive = getArchive($MODULE);

    unless( $archive ) {
        print STDERR "Unable to locate suitable archive for install";
        return 0;
    }
    TWiki::preinstall();
    my $tmpdir = unpackArchive( $archive );
    print "Archive unpacked\n";
    return 0 unless $tmpdir;
    return 0 unless _emplace( $tmpdir );

    print "\n### $MODULE installed";
    print ' with ',$unsatisfied.' unsatisfied dependencies' if ( $unsatisfied );
    print " ###\n";
    TWiki::postinstall();

    print "\n### Installation finished ###\n";
    return ($unsatisfied ? 0 : 1);
}

sub install {
    $PACKAGES_URL = shift;
    $MODULE = shift;
    my $rootModule = shift;
    push(@_, '') if (scalar(@_) & 1);
    my %data = @_;

    foreach my $row (split(/\r?\n/, $data{MANIFEST})) {
        my ($file, $perms, $desc) = split(',', $row, 3);
        $MANIFEST->{$file} = $perms;
    }

    my @deps;
    foreach my $row (split(/\r?\n/, $data{DEPENDENCIES})) {
        my ($module, $condition, $trigger, $type, $desc) = split(',', $row, 5);
        push(@deps, {
            name=>$module,
            type=>$type,
            version=>$condition, # version condition
            trigger => $trigger, # ONLYIF condition
            description=>$desc,
        });
    }

    unshift( @INC, 'lib' );

    my $n = 0;
    my $action = 'install';
    while ( $n < scalar( @ARGV ) ) {
        if( $ARGV[$n] eq '-a' ) {
            $noconfirm = 1;
        } elsif( $ARGV[$n] eq '-d' ) {
            $downloadOK = 1;
        } elsif( $ARGV[$n] eq '-r' ) {
            $reuseOK = 1;
        } elsif( $ARGV[$n] eq '-n' ) {
            $inactive = 1;
        } elsif( $ARGV[$n] =~ m/(install|uninstall|manifest|dependencies)/ ) {
            $action = $1;
        } else {
            usage( );
            die 'Bad parameter '.$ARGV[$n];
        }
        $n++;
    }

    if ($action eq 'manifest') {
        foreach my $row (split(/\r?\n/, $data{MANIFEST})) {
            my ($file, $perms, $desc) = split(',', $row, 3);
            print "$file $perms $desc\n";
        }
        exit 0;
    }

    if ($action eq 'dependencies') {
        foreach my $dep (@deps) {
            if ($dep->{trigger} && $dep->{trigger} != '1') {
                print "ONLYIF $dep->{trigger}\n";
            }
            print "$dep->{name},$dep->{version},$dep->{type},$dep->{description}\n";
        }
        exit 0;
    }

    print "\n### ${MODULE} Installer ###\n\n";
    print <<DONE;
This installer must be run from the root directory of your TWiki
installation.
DONE
    unless( $noconfirm ) {
        print <<DONE
    * The script will not do anything without asking you for
      confirmation first (unless you used -a).
DONE
    }
    print <<DONE;
    * You can abort the script at any point and re-run it later
    * If you answer 'no' to any questions you can always re-run
      the script again later
DONE

    if( $action eq 'install' ) {
        _install(\@deps, $rootModule);
    } elsif( $action eq 'uninstall' ) {
        _uninstall();
    }
}

1;
