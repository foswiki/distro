#!/usr/bin/perl -wT

use strict;
use File::Spec;

BEGIN {
    my ($vol, @path);
    foreach my $file ( keys %INC ) {
        next unless $file =~ /mod_perl_startup\.pl$/;
        my ($vol, $dir) = (File::Spec->splitpath($file))[0,1];
        @path = File::Spec->splitdir($dir);
        last;
    }
    pop @path while $path[-1] eq '';
    $path[-1] = 'lib';
    unshift @INC, File::Spec->catpath($vol, File::Spec->catdir(@path));
    push @path, qw(CPAN lib);
    unshift @INC, File::Spec->catpath($vol, File::Spec->catdir(@path));
}

use Foswiki::Engine::Apache ();

1;
