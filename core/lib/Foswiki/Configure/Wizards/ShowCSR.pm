package Foswiki::Configure::Wizards::ShowCSR;

=begin TML

---++ package Foswiki::Configure::Wizards::ShowCSR

Wizard to show pending SSL Certificate signing request.
Returns certificate in param 'certificate'.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

# WIZARD
sub execute {
    my ( $this, $reporter ) = @_;

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $csrfile = "$ceertfile.csr";

    unless ( -r $csrfile ) {
        return $reporter->ERROR("No CSR pending");
    }

    my $output;
    {
        no warnings 'exec';

        $output = `openssl req -in $csrfile -batch -subject -text 2>&1`;
    }
    if ($?) {
        return $reporter->ERROR(
            "Operation failed" . ( $? == -1 ? " (No openssl: $!)" : '' ) );
    }

    $this->param( 'certificate', $output );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
