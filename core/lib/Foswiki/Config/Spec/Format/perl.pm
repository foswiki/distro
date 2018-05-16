# See bottom of file for license and copyright information

package Foswiki::Config::Spec::Format::perl::Wrapper;

use Foswiki::Class -app;
extends qw(Foswiki::Object);
with qw(Foswiki::Config::CfgObject);

package Foswiki::Config::Spec::Format::perl;

use Foswiki::Exception::Config;

use Foswiki::Class -app;
extends qw(Foswiki::Object);
with qw(Foswiki::Config::Spec::Parser Foswiki::Config::CfgObject);

sub parse {
    my $this     = shift;
    my $specFile = shift;

    my $specSrc = $specFile->content;

    my $specCode = <<SPECCODE;
sub {
    my \$this = shift;
#line 1 "spec data"
    $specSrc
}
SPECCODE

    my $sub = eval $specCode;

    if ($@) {
        Foswiki::Exception::Config::BadSpecSrc->throw(
            srcFile => $specFile->path,
            text    => $@,
        );
    }

    my $wrapper = $this->create( 'Foswiki::Config::Spec::Format::perl::Wrapper',
        cfg => $this->cfg, );

    return $sub->($wrapper);
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
