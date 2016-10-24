#!/usr/bin/env perl
# See bottom of file for license and copyright information

use v5.14;
use lib "$ENV{FOSWIKI_HOME}/lib";
use Getopt::Long;
use Foswiki::Aux::Dependencies;
use Data::Dumper;
use Pod::Usage;

my %args;

GetOptions( \%args, "help", "root-dir=s", "extensions!", "inline-exec!",
    "upgrade!", )
  or die "Bad command line arguments";

pod2usage(1) if $args{help};

my %params = (
    rootDir        => $ENV{FOSWIKI_HOME},
    withExtensions => 1,
    inlineExec     => 1,
    verbose        => 1,
);

my %cmdarg2param = (
    'root-dir'    => 'rootDir',
    'extensions'  => 'withExtensions',
    'inline-exec' => 'inlineExec',
    'upgrade'     => 'doUpgrade',
);
foreach my $arg ( keys %args ) {
    $params{ $cmdarg2param{$arg} } = $args{$arg} if $args{$arg};
}

$params{depFileList} = \@ARGV if @ARGV;

if ( !Foswiki::Aux::Dependencies::checkDependencies(%params) ) {
    say STDERR "Dependencies check failed.\n",
      join( "\n", @Foswiki::Aux::Dependencies::messages );
}
else {
    say STDERR "Dependencies check succeed.\n",
      say join( "\n", @Foswiki::Aux::Dependencies::messages );
}

exit 0;
__END__

=head1 NAME

cpan_dependencies.pl - frontend script for Foswiki::Aux::Dependencies module
for installing CPAN modules defined by DEPENDENCIES files.

=head1 SYNOPSIS

cpan_dependencies.pl [--help] [--root-dir=dir] [--[no]extensions] [--[no]inline-exec] [--[no]upgrade]

=head1 DESCRIPTION

This script scans for DEPENDENCIES files and installs missing dependency modules
from CPAN using C<cpanm> utility.

=head1 OPTIONS

=over 8

=item B<--help>

Display this help and exit.

=item B<--root-dir>

Defines root directory of Foswiki installation. Defaults to environment variable
FOSWIKI_HOME.

=item B<--[no]extensions>

If defined then subdirectories will be scanned for installed extensions. Their
DEPENDENCIES content will be added to the list of modules to install.

Default to scan.

=item B<--[no]inline-exec>

By default C<cpanm> code is fetched into memory from F<$FOSWIKI_HOME/tools/cpanm>
script and used as a module. With B<--noinline-exec> it would be executed using
Perl binary as a separate process. This approach is slower but might be more
safe and robust.

=item B<--[no]upgrade>

Check if modules can be upgraded. Note that this doesn't mean that modules will
be unconditionally upgraded with this option. It would only happen if DEPENDENCIES
file defining these modules has been changed since the last run; or if there were
no runs yet (no F<$FOSWIKI_HOME/perl5/.checksum> file).

Note that for modules already installed with your OS packaging system this would
mean newer copies will be installed and used locally.

=back

=head1 TIPS

Use of F<$FOSWIKI_HOME/tools/dependencies_installer.pl> is preferred over this
tool.

=head1 AUTHOR

Vadim Belman <vrurg@lflat.org>

=cut

---------------------------------------------------------------
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
