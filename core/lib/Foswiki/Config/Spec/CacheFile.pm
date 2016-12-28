# See bottom of file for license and copyright information

package Foswiki::Config::Spec::CacheFile;

use Storable qw(freeze thaw);

use Foswiki::Class;
extends qw(Foswiki::File);

has entries => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    builder   => 'prepareEntries',
    trigger   => 1,
    isa       => Foswiki::Object::isaARRAY( 'nodes', noUndef => 1, ),
);

sub store {
    my $this = shift;

    my @entries;
    foreach my $node (@_) {
        push @entries, { $node->fullName => $node->default };
    }

    $this->entries( \@entries );
}

sub prepareEntries {
    my $this = shift;

    my $content = $this->content;

    return [] unless $content;

    return thaw( $this->content );
}

sub _trigger_entries {
    my $this    = shift;
    my $entries = shift;

    $this->content( freeze($entries) );
}

around prepareUnicode => sub {
    return 0;
};

around prepareBinary => sub {
    return 1;
};

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
