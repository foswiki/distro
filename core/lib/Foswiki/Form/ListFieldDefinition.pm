# See bottom of file for license and copyright information

=begin TML

---++ package Foswiki::Form::ListFieldDefinition
Form field definitions that accept lists of values in the field definition.
This is different to being multi-valued, which means the field type
can *store* multiple values.

=cut

package Foswiki::Form::ListFieldDefinition;
use v5.14;

use Assert;

use Moo;
use namespace::clean;
extends qw(Foswiki::Form::FieldDefinition);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

has valueMap => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);
has _options => ( is => 'rw', );
has _descriptions => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

sub isMultiValued { return ( shift->type =~ m/\+multi/ ); }

sub isValueMapped { return ( shift->type =~ m/\+values/ ); }

# PROTECTED - parse the {value} and extract a list of options.
# Done lazily to avoid repeated topic reads.
sub getOptions {

    # $web and $topic are where the form definition lives
    my $this = shift;

    return $this->_options if $this->_options;

    my @vals  = ();
    my %descr = ();

    @vals = split( /,/, $this->value );

    if ( !scalar(@vals) ) {
        my $topic = $this->definingTopic || $this->name;
        my $app = $this->app;

        my ( $fieldWeb, $fieldTopic ) =
          $app->request->normalizeWebTopicName( $this->web, $topic );

        $fieldWeb = Foswiki::Sandbox::untaint( $fieldWeb,
            \&Foswiki::Sandbox::validateWebName );
        $fieldTopic = Foswiki::Sandbox::untaint( $fieldTopic,
            \&Foswiki::Sandbox::validateTopicName );

        if ( $app->store->topicExists( $fieldWeb, $fieldTopic ) ) {

            my $meta = Foswiki::Meta->load( $app, $fieldWeb, $fieldTopic );
            if ( $meta->haveAccess('VIEW') ) {

                # Process SEARCHES for Lists
                my $text = $meta->expandMacros( $meta->text() );

                # SMELL: yet another table parser
                my $inBlock = 0;
                foreach ( split( /\r?\n/, $text ) ) {
                    if (/^\s*\|\s*\*Name\*\s*\|/) {
                        $inBlock = 1;
                    }
                    elsif (/^\s*\|\s*([^|]*?)\s*\|(?:\s*([^|]*?)\s*\|)?/) {
                        if ($inBlock) {
                            push( @vals, TAINT($1) );
                            $descr{$1} = $2 if defined $2;
                        }
                    }
                    else {
                        $inBlock = 0;
                    }
                }
            }
        }
    }
    @vals = map { $_ =~ s/^\s*(.*)\s*$/$1/; $_; } @vals;

    $this->_descriptions( \%descr );

    if ( $this->isValueMapped() ) {

        # create a values map
        $this->clear_valueMap;
        $this->_options( [] );
        my $str;
        foreach my $val (@vals) {
            if ( $val =~ m/^(.*[^\\])*=(.*)$/ ) {
                $str = TAINT( $1 || '' );    # label
                      # Copy the description to the real value
                my $descr = $this->_descriptions->{$val};
                $val = $2;
                $this->_descriptions->{$val} = $descr;

                # Unescape = - legacy! Entities should suffice
                $str =~ s/\\=/=/g;
            }
            else {
                # Label and value are the same
                $str = $val;
            }

            # SMELL: when it was first coded, the subclasses of
            # ListFieldDefinition all did an urlDecode on labels in
            # parsed +values. This was undocumented, but presumably
            # was intended to protect any characters that might
            # interfere with the rendering of the form table,
            # but were desireable in the label. Quite why
            # URL encoding was chosen over the more obvious
            # entity encoding is obscure, as is the reasoning behind
            # applying the encoding to the label, but not the value.
            # For compatibility we retain this decoding step here.
            # It remains undocumented, and therefore a potential
            # gotcha for the unwary.
            $str =~ s/%([\da-f]{2})/chr(hex($1))/gei;

            $this->valueMap->{$val} = $str;
            push @{ $this->_options }, $val;
        }
    }
    else {
        $this->_options( \@vals );
    }

    return $this->_options;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
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
