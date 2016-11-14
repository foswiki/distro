# See bottom of file for license and copyright information

package Foswiki::Aux::MuteOut;
use strict;
use warnings;

=begin TML

---+!! Package Foswiki::Aux::MuteOut

Very simplistic redirection of STDERR/STDOUT.

---++ SYNOPSIS

Simply avoid any output:

<verbatim>

use Foswiki::Aux::MuteOut;

sub proc {
    my ($dir) = @_;

    my $rc = system "ls -la $dir";
    print STDERR "RC=", $rc;
}

my $mute = Foswiki::Aux::MuteOut->new;

# Nothing will be displayed by proc()
$mute->exec(\&proc, "/etc");
</verbatim>

Capture output into files:

<verbatim>
my $capture = Foswiki::Aux::MuteOut->new(
    outFile => 'stdout.txt',
    errFile => 'stderr.txt',
);

# The output will end up in corresponding files.
$capture->exec(\&proc, "/etc");
</verbatim>

---++ DESCRIPTION

Redirections are restored when the object destroyed.

=cut

sub new {
    my $class  = shift;
    my %params = @_;

    $class = ref($class) || $class;

    my ( $oldOut, $oldErr, $rc );

    my $outFile =
      ( defined $params{outFile} ) ? $params{outFile} : File::Spec->devnull;
    my $errFile =
      ( defined $params{errFile} ) ? $params{errFile} : File::Spec->devnull;

    unless ( open $oldOut, ">&", STDOUT ) {
        Foswiki::Aux::Dependencies::_msg( "Cannot dup STDOUT: " . $! );
        return undef;
    }
    unless ( open $oldErr, ">&", STDERR ) {
        Foswiki::Aux::Dependencies::_msg( "Cannot dup STDERR: " . $! );
        return undef;
    }
    unless ( open STDOUT, ">", $outFile ) {
        Foswiki::Aux::Dependencies::_msg( "Failed to redirect STDOUT: " . $! );
    }
    unless ( open STDERR, ">", $errFile ) {
        Foswiki::Aux::Dependencies::_msg( "Failed to redirect STDERR: " . $! );
    }

    my $obj = bless {
        oldOut  => $oldOut,
        oldErr  => $oldErr,
        outFile => $outFile,
        errFile => $errFile,
    }, $class;

    return $obj;
}

sub exec {
    my $this = shift;
    my ($sub) = shift;

    my @rc;
    my $wantarray = wantarray;
    if ($wantarray) {
        @rc = $sub->(@_);
    }
    elsif ( defined $wantarray ) {
        $rc[0] = $sub->(@_);
    }
    else {
        $sub->(@_);
    }

    return $wantarray ? @rc : $rc[0];
}

sub DESTROY {
    my $this = shift;

    unless ( open STDOUT, ">&", $this->{oldOut} ) {
        Foswiki::Aux::Dependencies::_msg( "Failed to restore STDOUT: " . $! );
    }
    unless ( open STDERR, ">&", $this->{oldErr} ) {
        Foswiki::Aux::Dependencies::_msg( "Failed to restore STDERR: " . $! );
    }
}

1;
__END__
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
