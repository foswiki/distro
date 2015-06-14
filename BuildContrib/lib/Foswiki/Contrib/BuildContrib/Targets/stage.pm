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

our @stageFilters;

sub form_repair {
    my ( $this, $from, $to ) = @_;

    $this->filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;

            # Don't replace existing form
            return $text if $text =~ /^\%META:FORM\{/m;

            # Extract form data from text
            my %data = (
                Author    => "ProjectContributor",
                Release   => '%$RELEASE%',
                Version   => '%$VERSION%',
                Copyright => 'Foswiki Contributors, All Rights Reserved',
                License =>
'GPL ([[http://www.gnu.org/copyleft/gpl.html][GNU General Public License]])',
                Home       => 'http://foswiki.org/Extensions/%$ROOTMODULE%',
                Support    => 'http://foswiki.org/Support/%$ROOTMODULE%',
                Repository => 'https://github.com/foswiki/%$ROOTMODULE%'
            );
            my $form = "\n\%META:FORM{name=\"PackageForm\"}%\n";
            foreach my $field ( sort keys %data ) {
                if ( $text =~
s/\n\|\s*(?:Plugin\s+)?$field(?:\(s\))?:?\s*\|\s*(.*?)\s*\|\n/\n/i
                  )
                {
                    $data{$field} = $1;
                    $data{$field} =~ s/(["\r\n])/'%'.sprintf('%02x',ord($1))/ge;
                }
                $form .= "\%META:FIELD{name=\"$field\" ";
                $form .= "title=\"$field\" value=\"$data{$field}\"}%\n";
            }
            return $text . $form;
        }
    );
}

=begin TML

---++++ target_stage
stages all the files to be in the release in a tmpDir, ready for target_archive

=cut

sub target_stage {
    my $this    = shift;
    my $project = $this->{project};

    push( @stageFilters,
        { RE => qr/$project\.txt$/, filter => 'form_repair' } );
    push( @stageFilters, { RE => qr/\.txt$/, filter => 'filter_txt' } );
    push( @stageFilters, { RE => qr/\.pm$/,  filter => 'filter_pm' } );

    $this->{tmpDir} ||= File::Temp::tempdir( CLEANUP => 1 );
    File::Path::mkpath( $this->{tmpDir} );

    $this->copy_fileset( $this->{files}, $this->{basedir}, $this->{tmpDir} );

    foreach my $file ( @{ $this->{files} } ) {
        foreach my $filter (@stageFilters) {
            if ( $file->{name} =~ /$filter->{RE}/ ) {

                #print "FILTER $file->{name} $filter->{RE} $filter->{filter}\n";
                my $fn = $filter->{filter};
                $this->$fn(
                    $this->{tmpDir} . '/' . $file->{name},
                    $this->{tmpDir} . '/' . $file->{name}
                );
            }
        }
    }
    if ( -e $this->{tmpDir} . '/' . $this->{topic_root} . '.txt' ) {
        $this->cp(
            $this->{tmpDir} . '/' . $this->{topic_root} . '.txt',
            $this->{basedir} . '/' . $project . '.txt'
        );
    }

    $this->apply_perms( $this->{files}, $this->{tmpDir} );

    if ( $this->{other_modules} ) {
        my $libs = join( ':', @INC );
        foreach my $module ( @{ $this->{other_modules} } ) {

            die
"$Foswiki::Contrib::Build::basedir / $module does not exist, cannot build $module\n"
              unless ( -e "$Foswiki::Contrib::Build::basedir/$module" );

            warn "Installing $module in $this->{tmpDir}\n";

            #SMELL: uses legacy TWIKI_ exports
            my $cmd =
"export FOSWIKI_HOME=$this->{tmpDir}; export FOSWIKI_LIBS=$libs; export TWIKI_HOME=$this->{tmpDir}; export TWIKI_LIBS=$libs; cd $Foswiki::Contrib::Build::basedir/$module; perl build.pl handsoff_install";

            #warn "***** running $cmd \n";
            print `$cmd`;
        }
    }
}

1;
