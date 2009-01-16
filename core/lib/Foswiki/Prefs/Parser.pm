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
use Assert;

require Foswiki;

my $settingPrefPrefix = 'PREFERENCE_';

=begin TML

---++ ClassMethod new() -> topic parser object

Construct a new parser object.

=cut

sub new {
    return bless {}, $_[0];
}

=begin TML

---++ ObjectMethod parseText( $text, $prefs )

Parse settings from text and add them to the preferences in $prefs

=cut

sub parseText {
    my ( $this, $text, $prefs, $keyPrefix ) = @_;

    $text =~ tr/\r//d;
    my $key   = '';
    my $value = '';
    my $type;
    foreach ( split( "\n", $text ) ) {
        if (m/$Foswiki::regex{setVarRegex}/os) {
            if ( defined $type ) {
                $prefs->insert( $type, $keyPrefix . $key, $value );
            }
            $type  = $1;
            $key   = $2;
            $value = ( defined $3 ) ? $3 : '';
        }
        elsif ( defined $type ) {
            if ( /^(   |\t)+ *[^\s]/ && !/$Foswiki::regex{bulletRegex}/o ) {

                # follow up line, extending value
                $value .= "\n" . $_;
            }
            else {
                $prefs->insert( $type, $keyPrefix . $key, $value );
                undef $type;
            }
        }
    }
    if ( defined $type ) {
        $prefs->insert( $type, $keyPrefix . $key, $value );
    }
}

=begin TML

---++ ObjectMethod parseMeta( $metaObject, $prefs )

Traverses through all PREFERENCE attributes of the meta object, creating one 
setting named with $settingPrefPrefix . 'title' for each.  It also 
creates an entry named with the field 'name', which is a cleaned-up, 
space-removed version of the title.

Settings are added to the $prefs passed.

=cut

sub parseMeta {
    my ( $this, $meta, $prefs, $keyPrefix ) = @_;

    my @fields = $meta->find('PREFERENCE');
    foreach my $field (@fields) {
        my $title         = $field->{title};
        my $prefixedTitle = $settingPrefPrefix . $title;
        my $value         = $field->{value};
        my $type          = $field->{type} || 'Set';
        $prefs->insert( $type, $prefixedTitle, $value );

        #SMELL: Why do we insert both based on title and name?
        my $name = $field->{name};
        $prefs->insert( $type, $keyPrefix . $name, $value );
    }

    # Note that the use of the "S" attribute to support settings in
    # form fields has been deprecated.
    my $form = $meta->get('FORM');
    if ($form) {
        my @fields = $meta->find('FIELD');
        foreach my $field (@fields) {
            my $title      = $field->{title};
            my $attributes = $field->{attributes};
            if ( $attributes && $attributes =~ /S/o ) {
                my $value = $field->{value};
                my $name  = $field->{name};
                $prefs->insert( 'Set', 'FORM_' . $name, $value );
                $prefs->insert( 'Set', $name,           $value );
            }
        }
    }
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
