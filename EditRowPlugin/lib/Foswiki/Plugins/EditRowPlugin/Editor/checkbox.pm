# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::Editor::checkbox;
use v5.14;

use Assert;

use Moo;
use namespace::clean;
extends qw(Foswiki::Plugins::EditRowPlugin::Editor);

around BUILDARGS => sub {
    my $orig = shift;
    return $orig->( @_, type => 'checkbox' );
};

sub BUILD {
    my $this = shift;
    $this->css_class('foswikiCheckBox');
}

sub htmlEditor {
    my ( $this, $cell, $colDef, $inRow, $unexpandedValue ) = @_;

    my ( $attrs, $defaults, $options ) =
      $this->_tickbox( $cell, $colDef, $unexpandedValue );

    return CGI::checkbox_group(
        -name       => $cell->getElementName(),
        -values     => $options,
        -defaults   => $defaults,
        -columns    => $colDef->{size},
        -attributes => $attrs
    );
}

around jQueryMetadata => sub {
    my $orig = shift;
    my $this = shift;
    my ( $cell, $colDef, $text ) = @_;
    my $data = $orig->( $this, @_ );
    $data->text($text);

    if ( $colDef->{values} && scalar( @{ $colDef->{values} } ) ) {
        $data->data( {} );
        map {
            $data->data->{$_} =
              Foswiki::Func::renderText(
                Foswiki::Func::expandCommonVariables($_) )
        } @{ $colDef->{values} };
    }
    $this->_addSaveButton($data);
    $this->_addCancelButton($data);
    return $data;
};

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2011 Foswiki Contributors
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this notice.
