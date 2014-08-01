# See bottom of file for license and copyright information

package Foswiki::Configure::TypeUIs::SELECTCLASS;

use strict;
use warnings;

use Foswiki::Configure::TypeUIs::SELECT ();
use Foswiki::Configure::FileUtil;

our @ISA = ('Foswiki::Configure::TypeUIs::SELECT');

# generate an input field for SELECTCLASS types
# Takes a comma-separated list of options
# Each option must be either 'none' or a wildcard expression that matches classes e.g.
# Foswiki::Plugins::*Plugin
# * is the only wildcard supported
# Finds all classes that match in @INC
sub prompt {
    my ( $this, $model, $value, $class ) = @_;
    unless ( $model->{_classes_expanded} ) {
        my @ropts;
        foreach my $opt ( @{ $model->{select_from} } ) {
            if ( $opt eq 'none' ) {
                push( @ropts, 'none' );
            }
            else {
                push( @ropts,
                    Foswiki::Configure::FileUtil::findPackages($opt) );
            }
        }
        $model->{select_from}       = \@ropts;
        $model->{_classes_expanded} = 1;
    }
    return $this->SUPER::prompt( $model, $value, $class );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
