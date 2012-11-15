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

use B::PerlReq;

=begin TML

---++++ target_dependencies

Extract and print all dependencies, in standard DEPENDENCIES syntax.
Requires B::PerlReq. Analyses perl sources in !includes as well.

All dependencies except those on pragmas (strict, integer etc) are
extracted.

=cut

sub target_dependencies {
    my $this = shift;
    local $/ = "\n";

    foreach my $m (
        'strict',   'vars',     'diagnostics', 'base',
        'bytes',    'constant', 'integer',     'locale',
        'overload', 'warnings', 'Assert',      'TWiki',
        'Foswiki'
      )
    {
        $this->{satisfied}{$m} = 1;
    }

    # See if we already know about it
    foreach my $dep ( @{ $this->{dependencies} } ) {
        $this->{satisfied}{ $dep->{name} } = 1;
    }

    $this->{extracted_deps} = undef;
    my @queue;
    my %tainted;
    foreach my $file ( @{ $this->{files} } ) {
        my $is_perl = 0;
        my $pmfile  = $file->{name};
        if (   $pmfile =~ /\.p[ml]$/o
            && $pmfile !~ /build.pl/
            && $pmfile !~ /TEMPLATE_installer.pl/ )
        {
            $is_perl = 1;
        }
        else {
            my $testfile = $this->{basedir} . '/' . $pmfile;
            if ( -e $testfile ) {
                open( PMFILE, '<', $testfile ) || die "$testfile: $!";
                my $fline = <PMFILE>;
                if ( $fline && $fline =~ m.#!/usr/bin/perl. ) {
                    $is_perl = 1;
                    $tainted{$pmfile} = '-T' if $fline =~ /-T/;
                }
                close(PMFILE);
            }
        }
        if ( $pmfile =~ /^lib\/(.*)\.pm$/ ) {
            my $f = $1;
            $f =~ s.CPAN/lib/..;
            $f =~ s./.::.g;
            $this->{satisfied}{$f} = 1;
        }
        if ($is_perl) {
            $tainted{$pmfile} = '' unless defined $tainted{$pmfile};
            push( @queue, $pmfile );
        }
    }

    my $inc = '-I' . join( ' -I', @INC );
    foreach my $pmfile (@queue) {
        die         unless defined $basedir;
        die         unless defined $inc;
        die         unless defined $pmfile;
        die $pmfile unless defined $tainted{$pmfile};
        my $deps =
`cd $basedir && perl $inc $tainted{$pmfile} -MO=PerlReq,-strict $pmfile 2>/dev/null`;
        $deps =~ s/perl\((.*?)\)/$this->_addDep($pmfile, $1)/ge if $deps;
    }

    print "MISSING DEPENDENCIES:\n";
    my $depcount = 0;
    foreach my $module ( sort keys %{ $this->{extracted_deps} } ) {
        print "$module,>=0,cpan,May be required for "
          . join( ', ', @{ $this->{extracted_deps}{$module} } ) . "\n";
        $depcount++;
    }
    print $depcount
      . ' missing dependenc'
      . ( $depcount == 1 ? 'y' : 'ies' ) . "\n";
}

sub _addDep {
    my ( $this, $from, $file ) = @_;

    $file =~ s./.::.g;
    $file =~ s/\.pm$//;
    return '' if $this->{satisfied}{$file};
    push( @{ $this->{extracted_deps}{$file} }, $from );
    return '';
}

1;
