# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::IncludeHandlers::doc

This package is designed to be lazy-loaded when Foswiki sees
an INCLUDE macro with the doc: protocol. It implements a single
method INCLUDE.

=cut

package Foswiki::IncludeHandlers::doc;

use strict;
use warnings;

use Foswiki ();

# Include embedded doc in a core module
sub INCLUDE {
    my ( $ignore, $session, $control, $params ) = @_;
    my $class = $control->{_DEFAULT};
    $class =~ s/[a-z]+://;    # remove protocol
    return '' unless $class && $class =~ /^Foswiki/;
    $class =~ s/[^\w:]//g;

    my $pmfile;
    $class =~ s#::#/#g;
    foreach my $inc (@INC) {
        if ( -f "$inc/$class.pm" ) {
            $pmfile = "$inc/$class.pm";
            last;
        }
    }
    return '' unless $pmfile;

    my $PMFILE;
    open( $PMFILE, '<', $pmfile ) || return '';
    my $inPod = 0;
    my $pod   = '';
    local $/ = "\n";
    while ( my $line = <$PMFILE> ) {
        if ( $line =~ /^=(begin (twiki|TML|html)|pod)/ ) {
            $inPod = 1;
        }
        elsif ( $line =~ /^=cut/ ) {
            $inPod = 0;
        }
        elsif ($inPod) {
            $pod .= $line;
        }
    }
    close($PMFILE);

    $pod =~ s/.*?%STARTINCLUDE%//s;
    $pod =~ s/%STOPINCLUDE%.*//s;

    $pod = Foswiki::applyPatternToIncludedText( $pod, $control->{pattern} )
      if ( $control->{pattern} );

    # Adjust the root heading level
    if ( $params->{level} ) {
        my $minhead = '+' x 100;
        $pod =~ s/^---(\++)/
          $minhead = $1 if length($1) < length($minhead); "---$1"/gem;
        return $pod if length($minhead) == 100;
        my $newroot = '+' x $params->{level};
        $minhead =~ s/\+/\\+/g;
        $pod     =~ s/^---$minhead/---$newroot/gm;
    }
    return $pod;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
