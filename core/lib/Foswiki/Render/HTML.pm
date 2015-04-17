# See bottom of file for license and copyright information
package Foswiki::Render::HTML;

use strict;
use warnings;

use Foswiki       ();
use Foswiki::Meta ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod textarea( $params) -> $text

Render parent meta-data. Support for %META%.

=cut

sub textarea {
    my ($ah) = @_;

    my $cols     = $ah->{cols};
    my $disabled = $ah->{disabled};
    my $name     = $ah->{name};
    my $readonly = $ah->{readonly};
    my $rows     = $ah->{rows};
    my $style    = $ah->{style};
    my $class    = $ah->{class};
    my $id       = $ah->{id};
    my $default  = $ah->{default};

    #$default =~ s/([<>%'"])/'&#'.ord($1).';'/ge;

    $default =~ s/&/&amp;/g;
    $default =~ s/</&lt;/g;
    $default =~ s/>/&gt;/g;
    $default =~ s/"/&quot;/g;

    print STDERR Data::Dumper::Dumper( \$ah );

    my $html = '<textarea ';
    $html .= "class='$class' "      if $class;
    $html .= "cols='$cols' ";
    $html .= "name='$name' "        if $name;
    $html .= "readonly='readonly' " if $readonly;
    $html .= "rows='$rows' ";
    $html .= "style='$style' "      if $style;
    $html .= "id='$id'"             if $id;

    $html .= ">$default</textarea>";

    return $html;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
