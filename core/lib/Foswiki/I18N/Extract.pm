# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::I18N::Extract

Support translatable strings extraction from Foswiki topics and templates.
Depends on Locale::Maketext::Extract (part of CPAN::Locale::Maketext::Lexicon).

=cut

package Foswiki::I18N::Extract;

use strict;
use warnings;

our $initError;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    require Locale::Maketext::Extract;
    if ($@) {
        $initError = $@;
    }
    else {
        @Foswiki::I18N::Extract::ISA = ('Locale::Maketext::Extract');
    }
}

##########################################################

=begin TML

---++ ClassMethod new ( $session ) -> $extract

Constructor. Creates a fresh new Extract object. A $session object, instance of
the Foswiki class, is optional: if it's available, it'll be used for printing
warnings.

=cut

sub new {
    my $class   = shift;
    my $session = shift;

    if ( defined $initError ) {
        $session->logger->log( 'warning', $initError ) if $session;
        return;
    }

    my $self = new Locale::Maketext::Extract;
    $self->{session} = $session;
    return bless( $self, $class );
}

=begin TML

---++ ObjectMethod extract ( $file , $text )

Extract the strings from =$text=,m using =$file= as the name of the current
file being read (for comments in PO file, for example). Overrides the base
class method but calls it so the base behavior is preserved.

As in base class, extracted strings are just stored in the =$self='s internal
table for further use (e.g. creating/updating a PO file). Nothing is returned.

=cut

sub extract {
    my $self = shift;
    my $file = shift;
    local $_ = shift;

    # do existing extraction
    $self->SUPER::extract( $file, $_ ) unless ( $file =~ m/\.(txt|tmpl)$/ );

    my $line;
    my $doublequoted = '"(\\\"|[^"])*"';

    # Foswiki's %MAKETEXT{...}% into topics and templates :
    $line = 1;
    pos($_) = 0;
    my @_lines = split( /\n/, $_ );
    foreach (@_lines) {
        while (m/%MAKETEXT\{\s*(string=)?($doublequoted)/gm) {
            my $str = substr( $2, 1, -1 );
            $str =~ s/\\"/"/g;
            $self->add_entry( $str, [ $file, $line, '' ] );
        }
        $line++;
    }

# Foswiki's %MAKETEXT{...}% inside a search format would look like this:
# %SEARCH{... format=" ... $percntMAKETEXT{\"...\" args=\"\"}$percent ..." ...}%
#
# XXX: the regex down there matches a sequence formed be an escaped double
# quote (\"), followed by characters that are not doublequotes OR
# double-escaped doublequotes (\\\"), and terminated with another escaped
# double-quote.
#
# SMELL: although here we can extract properly the string, %SEARCH{...}%
# won't convert (\\\") inside format into (") as we do here. So it's best
# to avoid trying to put doublequotes inside a MAKETEXT that is inside
# a %SEARCH{...}% format.
    $line = 1;
    pos($_) = 0;
    @_lines = split( /\n/, $_ );
    foreach (@_lines) {
        while (m/\$perce?ntMAKETEXT\{\s*(string=)?(\\"(\\\\\\"|[^"])*\\")/gm) {

            # remove the enclosing [\"]'s:
            my $str = substr( $2, 2, -2 );

            # remove escaped stuff:
            $str =~ s/\\\\"/"/g;
            $str =~ s/\\"/"/g;

            # collect the string:
            $self->add_entry( $str, [ $file, $line, '' ] );
        }
        $line++;
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

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
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
