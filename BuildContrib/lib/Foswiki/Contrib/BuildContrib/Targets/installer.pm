#
# Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2010 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Contrib::Build;

use strict;

=begin TML

---++++ target_installer

Write an install/uninstall script that checks dependencies, and optionally
downloads and installs required zips from foswiki.org.

The install script is templated from =contrib/TEMPLATE_installer= and
is always named =module_installer= (where module is your module). It is
added to the release zip and is always shipped in the root directory.
It will automatically be added to the manifest if it doesn't appear in
MANIFEST.

The install script works using the dependency type and version fields.
It will try to download from foswiki.org to satisfy any missing dependencies.
Downloaded modules are automatically installed.

Note that the dependencies will only work if the module depended on follows
the naming standards for zips i.e. it must be attached to the topic in
foswiki.org and have the same name as the topic, and must be a zip file.

Dependencies on CPAN modules are also checked (type perl) but no attempt
is made to install them.

The install script also acts as an uninstaller and upgrade script.

__Note__ that =target_install= builds and invokes this install script.

At present there is no support for a caller-provided post-install script, but
this would be straightforward to do if it were required.

=cut

sub target_installer {
    my $this = shift;

    return
      if defined $this->{options}->{installers}
      && $this->{options}->{installers} =~ /none/;

    # Add the install script to the manifest, unless it is already there
    unless (
        grep( /^$this->{project}_installer$/,
            map { $_->{name} } @{ $this->{files} } )
      )
    {
        push(
            @{ $this->{files} },
            {
                name        => $this->{project} . '_installer',
                description => 'Install script',
                permissions => 0770
            }
        );
        warn 'Auto-adding install script to manifest', "\n"
          if ( $this->{-v} );
    }

    # Find the template on @INC
    my $template;
    foreach my $d (@INC) {
        my $dir = `dirname "$d"`;
        chop($dir);
        my $file =
          $dir . '/lib/Foswiki/Contrib/BuildContrib/TEMPLATE_installer.pl';
        if ( -f $file ) {
            $template = $file;
            last;
        }
        $dir .= '/contrib';
        if ( -f $dir . '/TEMPLATE_installer.pl' ) {
            $template = $dir . '/TEMPLATE_installer.pl';
            last;
        }
    }
    unless ($template) {
        die
'COULD NOT LOCATE TEMPLATE_installer.pl - required for install script generation';
    }

    my @sats;
    foreach my $dep ( @{ $this->{dependencies} } ) {
        my $descr = $dep->{description};
        $descr =~ s/"/\\\"/g;
        $descr =~ s/\$/\\\$/g;
        $descr =~ s/\@/\\\@/g;
        $descr =~ s/\%/\\\%/g;
        my $trig = $dep->{trigger};
        $trig = 1 unless ($trig);
        push( @sats,
"{ name=>'$dep->{name}', type=>'$dep->{type}',version=>'$dep->{version}',description=>'$descr', trigger=>$trig }"
        );
    }
    my $satisfies = join( ",", @sats );
    $this->{SATISFIES} = $satisfies;

    my $installScript =
      $this->{basedir} . '/' . $this->{project} . '_installer';
    if ( $this->{-v} || $this->{-n} ) {
        print 'Generating installer in ', $installScript, "\n";
    }

    $this->filter_txt( $template, $installScript );

    # Copy it to .pl
    $this->cp( $installScript, "$installScript.pl" );
}

1;
