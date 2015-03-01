# See bottom of file for license and copyright information

=begin TML

---+ UNPUBLISHED package Foswiki::Prefs::Parser

This Prefs-internal class is used to parse * Set and * Local statements
from arbitrary text, and extract settings from meta objects.  It is used
by TopicPrefs to parse preference settings from topics.

This class does no validation or duplicate-checking on the settings; it
simply returns the recognized settings in the order it sees them in.

=cut

package Foswiki::Prefs::Parser;

use strict;
use warnings;
use Assert;

use Foswiki ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticFunction parse( $topicObject, $prefs )

Parse settings from the topic and add them to the preferences in $prefs

=cut

sub parse {
    my ( $topicObject, $prefs ) = @_;

    # Process text first
    my $key   = '';
    my $value = '';
    my $type;
    my $text = $topicObject->text();
    $text = '' unless defined $text;

    foreach ( split( "\n", $text ) ) {
        if (m/$Foswiki::regex{setVarRegex}/s) {
            if ( defined $type ) {
                $prefs->insert( $type, $key, $value );
            }
            $type  = $1;
            $key   = $2;
            $value = ( defined $3 ) ? $3 : '';
        }
        elsif ( defined $type ) {
            if ( /^(   |\t)+ *[^\s]/ && !/$Foswiki::regex{bulletRegex}/ ) {

                # follow up line, extending value
                $value .= "\n" . $_;
            }
            else {
                $prefs->insert( $type, $key, $value );
                undef $type;
            }
        }
    }
    if ( defined $type ) {
        $prefs->insert( $type, $key, $value );
    }

    # Now process PREFERENCEs
    my @fields = $topicObject->find('PREFERENCE');
    foreach my $field (@fields) {
        my $type  = $field->{type} || 'Set';
        my $value = $field->{value};
        my $name  = $field->{name};
        $prefs->insert( $type, $name, $value );
    }

    # Note that the use of the "S" attribute to support settings in
    # form fields has been deprecated.
    my $form = $topicObject->get('FORM');
    if ($form) {
        my @fields = $topicObject->find('FIELD');
        foreach my $field (@fields) {
            my $attributes = $field->{attributes};
            if ( $attributes && $attributes =~ m/S/ ) {
                my $value = $field->{value};
                my $name  = $field->{name};
                $prefs->insert( 'Set', 'FORM_' . $name, $value );
                $prefs->insert( 'Set', $name,           $value );
            }
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
