# See bottom of file for description
package Unit::Eavesdrop;
use base 'Tie::Handle';

use strict;

sub new {
    my ($class, $baseName) = @_;
    return eval "tie(*$baseName, \$class, \$baseName)";
}

sub DESTROY {
    my $this = shift;
    { local $^W = 0; untie(*$this->{baseName}) }
}

sub TIEHANDLE {
    my ($class, $baseName) = @_;
    my $this = bless({}, $class);
    $this->{baseName} = $baseName;
    # dup the base file handle, otherwise we get an infinite recursion
    # when printing
    my $fh;
    open($fh, ">&$baseName") || die "Failed to dup $baseName; $!";
    $this->{principal} = $fh;
    return $this;
}

sub UNTIE {
    my $this = shift;
    close($this->{principal}) if $this->{principal};
    foreach my $tee (@{$this->{tees}}) {
        close($tee);
    }
}

sub teeTo {
    my ($this, $fh) = @_;
    push(@{$this->{tees}}, $fh);
}

sub PRINT {
    my $this = shift;
    my $fh;

    if ($this->{principal}) {
        $fh = *{$this->{principal}};
        print $fh @_;
    }
    foreach my $tee (@{$this->{tees}}) {
        $fh = *{$tee};
        print $fh @_;
    }
}

sub OPEN {
    my $this = $_[0];
    # Redirect the principal; leave the tees alone
    my $fh;
    # Must use 3 arg form; passing @_ doesn't work
    my $status = open($fh, $_[1], $_[2]);
    if ($status) {
        close($this->{principal}) if $this->{principal};
        $this->{principal} = $fh;
    } else {
        print STDERR "Open failed: ",join(' ',@_)." - $!\n";
    }
    return $status;
}

sub CLOSE {
    my $this = shift;
    # Close the principal, keeping the tees
    close($this->{principal}) if $this->{principal};
    undef $this->{principal};
    return 1;
}

1;

__DATA__

=pod

Duplication of STDOUT and STDERR from tests to a (single) log file. Lets
you log everything printed on streams to another stream.

Author: Crawford Currie, http://c-dot.co.uk

Usage:

my $logfile = 'test.log';
open(F, ">$logfile");
my $stdout = new Unit::Eavesdrop('STDOUT', \*F);
my $stderr = new Unit::Eavesdrop('STDERR', \*F);
print STDERR "Foo\n";
print STDOUT "Bar\n";
close(F);

Copyright (C) 2007 WikiRing, http://wikiring.com
All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

=cut

