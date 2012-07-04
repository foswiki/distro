# See bottom of file for license and copyright information
package Foswiki::Render::FormField;

use strict;
use warnings;

use Foswiki       ();
use Foswiki::Meta ();

=begin TML

---++ ObjectMethod render ( $session, %params, $topic, $web ) -> $html

Returns the fully rendered expansion of a %FORMFIELD{}% tag.

=cut

sub render {
    my ( $session, $params, $topicObject ) = @_;

    my $formField = $params->{_DEFAULT};
    return '' unless defined $formField;
    my $altText = $params->{alttext};
    my $default = $params->{default};
    my $rev     = $params->{rev} || '';
    my $format  = $params->{format};

    $altText = '' unless defined $altText;
    $default = '' unless defined $default;

    unless ( defined $format ) {
        $format = '$value';
    }

    my $formTopicObject =
      $session->{_ffCache}{ $topicObject->getPath() . $rev };

    unless ($formTopicObject) {
        $formTopicObject =
          Foswiki::Meta->load( $session, $topicObject->web, $topicObject->topic,
            $rev );
        unless ( $formTopicObject->haveAccess('VIEW') ) {

            # Access violation, create dummy meta with empty text, so
            # it looks like it was already loaded.
            $formTopicObject = Foswiki::Meta->new( $session, $topicObject->web,
                $topicObject->topic, '' );
        }

        $session->{_ffCache}{ $formTopicObject->getPath() . $rev } =
          $formTopicObject;
    }

    my $text   = $format;
    my $found  = 0;
    my $title  = '';
    my @fields = $formTopicObject->find('FIELD');
    foreach my $field (@fields) {
        my $name = $field->{name};
        $title = $field->{title} || $name;
        if ( $title eq $formField || $name eq $formField ) {
            $found = 1;
            my $value = $field->{value};
            $text = $default if !length($value);
            $text =~ s/\$title/$title/go;
            $text =~ s/\$value/$value/go;
            $text =~ s/\$name/$name/g;
            if ( $text =~ m/\$form/ ) {
                my @defform = $formTopicObject->find('FORM');
                my $form  = $defform[0];     # only one form per topic
                my $fname = $form->{name};
                $text =~ s/\$form/$fname/g;
            }

            last;                            # one hit suffices
        }
    }

    unless ($found) {
        $text = $altText || '';
    }

    $text = Foswiki::expandStandardEscapes($text);

    # render nop exclamation marks before words as <nop>
    $text =~ s/!(\w+)/<nop>$1/gs;

    return $text;
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
