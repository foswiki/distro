# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

use Foswiki::Store ();
use Foswiki::Meta  ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub FORMFIELD {
    my ( $this, $args, $topicObject ) = @_;

    if ( $args->{topic} ) {
        my $web = $args->{web} || $topicObject->web;
        my $topic = $args->{topic};
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );
        $topicObject = new Foswiki::Meta( $this, $web, $topic );
    }
    else {

        # SMELL: horrible hack; assumes the current rev comes from the 'rev'
        # parameter. There has to be a better way!
        my $query = $this->{request};
        my $cgiRev;
        $cgiRev = $query->param('rev') if ($query);
        $args->{rev} =
          Foswiki::Store::cleanUpRevID( $args->{rev} || $cgiRev ) || '';
    }

    my $formField = $args->{_DEFAULT};
    return '' unless defined $formField;

    my $text;

    my $fdef = $topicObject->get( 'FIELD', $formField );
    if ( $fdef && ( !defined $fdef->{value} || $fdef->{value} eq '' ) ) {

        # SMELL: weird; ignores format=
        $text = $args->{default} || '';
        $text =~ s/!($Foswiki::regex{wikiWordRegex})/<nop>$1/gs;
        return $text;
    }

    my $altText = $args->{alttext};
    my $default = $args->{default};
    my $rev     = $args->{rev} || '';
    my $format  = $args->{format};

    $altText = '' unless defined $altText;
    $default = '' unless defined $default;

    unless ( defined $format ) {
        $format = '$value';
    }

    my $formTopicObject = $this->{_ffCache}{ $topicObject->getPath() . $rev };

    unless ($formTopicObject) {
        $formTopicObject =
          Foswiki::Meta->load( $this, $topicObject->web, $topicObject->topic,
            $rev );
        unless ( $formTopicObject->haveAccess('VIEW') ) {

            # Access violation, create dummy meta with empty text, so
            # it looks like it was already loaded.
            $formTopicObject = Foswiki::Meta->new( $this, $topicObject->web,
                $topicObject->topic, '' );
        }

        $this->{_ffCache}{ $formTopicObject->getPath() . $rev } =
          $formTopicObject;
    }

    my $found = 0;
    my $field = $formTopicObject->get( 'FIELD', $formField );
    if ($field) {
        my $name = $field->{name};
        my $title = $field->{title} || $name;
        $text = $formTopicObject->renderFormFieldForDisplay(
            $name, $format,
            {
                showhidden => 1,
                usetitle   => $field->{title},
                newline    => '$n'
            }
        );
        $text = $default unless length($text);
    }
    else {
        $text = $altText || '';
    }

    # $formname is correct. $form works but is deprecated for
    # compatibility with SEARCH{format}
    if ( $text =~ m/\$form(name)?/ ) {
        my @defform = $formTopicObject->find('FORM');
        my $form    = $defform[0];                     # only one form per topic
        my $fname   = '';
        $fname = $form->{name} if $form;
        $text =~ s/\$form(name)?/$fname/g;
    }

    $text = Foswiki::expandStandardEscapes($text);

    # render nop exclamation marks before words as <nop>
    $text =~ s/!($Foswiki::regex{wikiWordRegex})/<nop>$1/gs;

    return $text;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
