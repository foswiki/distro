# See bottom of file for license and copyright information
package Foswiki::Configure::Reporter;

use strict;
use warnings;

=begin TML

---+ package Foswiki::Configure::Reporter

Report package for configure, supporting text reporting and
simple TML expansion to HTML.

=cut

sub new {
    my $class = shift;

    my $this = bless( {}, $class );
    $this->clear();
    return $this;
}

=begin TML

---++ ObjectMethod NOTE(...) -> $this

Report a note. The parameters are concatenated to form the message.
Returns the reporter to allow chaining.

=cut

sub NOTE {
    my $this = shift;
    push(
        @{ $this->{notes} },
        map { $_ =~ /^PREFORMAT:/ ? $_ : split /\n/ } @_
    );
    return $this;
}

=begin TML

---++ ObjectMethod CONFIRM(...) -> $this

Report a confirmation. The parameters are concatenated to form the message.

=cut

sub CONFIRM {
    my $this = shift;
    push( @{ $this->{confirmations} }, map { split /\n/ } @_ );
    return $this;
}

=begin TML

---++ ObjectMethod WARN(...)

Report a warning. The parameters are concatenated to form the message.
Returns the reporter to allow chaining.

=cut

sub WARN {
    my $this = shift;
    push( @{ $this->{warnings} }, map { split /\n/ } @_ );
}

=begin TML

---++ ObjectMethod ERROR(...) -> $this

Report an error. The parameters are concatenated to form the message.
Returns the reporter to allow chaining.

=cut

sub ERROR {
    my $this = shift;
    push( @{ $this->{errors} }, map { split /\n/ } @_ );
    return $this;
}

=begin TML

---++ ObjectMethod CHANGED($keys) -> $this

Report that a =Foswiki::cfg= entry has changed. The new value will
be taken from the current value in =$Foswiki::cfg=

Example: =$reporter->CHANGED('{Email}{Method}')=

Returns the reporter to allow chaining.

=cut

sub CHANGED {
    my ( $this, $keys ) = @_;
    $this->{changes}->{$keys} = eval "\$Foswiki::cfg$keys";
    return $this;
}

=begin TML

---++ ObjectMethod has($level) -> $number

Return the number of reports of the given level (errors, warnings,
notes, confirmations) gathered so far. 

=cut

sub has {
    my ( $this, $level ) = @_;
    return scalar( keys %{ $this->{changes} } ) if $level eq 'changes';
    return scalar( @{ $this->{$level} } );
}

=begin TML

---++ ObjectMethod clear() -> $this

Clear all contents from the reporter.
Returns the reporter to allow chaining.

=cut

sub clear {
    my $this = shift;
    $this->{notes}         = [];
    $this->{confirmations} = [];
    $this->{warnings}      = [];
    $this->{errors}        = [];
    $this->{changes}       = {};
    return $this;
}

=begin TML

---++ ObjectMethod text() -> $text

Generate a text representation of the content of the reporter.

=cut

sub text {
    my $this = shift;

    my @notes;
    for my $e ( @{ $this->{errors} } ) {
        push( @notes, "Error: $e" ) if $e;

    }
    for my $e ( @{ $this->{warnings} } ) {
        push( @notes, "Warning: $e" ) if $e;
    }
    for my $e ( @{ $this->{confirmations} } ) {
        push( @notes, "OK: $e" ) if $e;
    }
    for my $e ( @{ $this->{notes} } ) {
        push( @notes, "Note: $e" ) if $e;
    }
    while ( my ( $k, $v ) = each %{ $this->{changes} } ) {
        push( @notes, "Change: $k => $v" );
    }
    return join( "\n", @notes );
}

our $S = qr/^|(?<=[\s\(])/m;
our $E = qr/$|(?=[\s,.;:!?)])/m;

=begin TML

---++ ObjectMethod html([@levels]) -> $html

Generate an HTML representation of the content of the reporter.
Messages are formatted using a cut-down version of TML.

   * =@levels= optional list of levels e.g. 'errors', 'changes' to
     expand in the result. Default is to expand all levels.

=cut

my %group_css = (
    errors        => 'foswikiAlert configureError',
    warnings      => 'foswikiAlert configureWarning',
    confirmations => 'configureOk',
    notes         => 'configureOk',
    changes       => 'configureOk'
);

sub html {
    my ( $this, @groups ) = @_;
    @groups = ( 'errors', 'warnings', 'confirmations', 'notes', 'changes' )
      unless scalar(@groups);
    my @notes;
    foreach my $group (@groups) {
        if ( $group eq 'changes' ) {
            while ( my ( $k, $v ) = each %{ $this->{changes} } ) {
                push( @notes,
                    "<div class='$group_css{changes}'>Changed: $k = $v</div>" );
            }
            next;
        }

        my (
            $in_list,     # in an ol or ul
            $in_table,    # in a table
            $list_type
        );                # u or o

        foreach ( @{ $this->{$group} } ) {

            # {strong}
            $_ =~
s/${S}\{(\S+?|\S[^\n]*?\S)\}$E/<strong><code>{$1}<\/code><\/strong>/g;

            # *strong*
            $_ =~ s/${S}\*(\S+?|\S[^\n]*?\S)\*$E/<strong>$1<\/strong>/g;

            # _em_
            $_ =~ s/${S}\_(\S+?|\S[^\n]*?\S)\_$E/<em>$1<\/em>/g;

            # =code=
            $_ =~ s/${S}\=(\S+?|\S[^\n]*?\S)\=$E/<code>$1<\/code>/g;

            # [[http][link]]
            $_ =~ s/[[([^][])+][([^][]+)]]/<a href="$1">$2<\/a>/g;
            $_ =~ s/\n/<br \/>/g;

            if ( $_ =~ s/^   (\*|\d) (.*)$/<li>$2<\/li>/ ) {

                #    * Bullet list item
                #    1 Ordered list item
                if ($in_list) {
                    $$in_list .= $_;
                    $_ = '';
                }
                else {
                    $list_type = ( $1 eq '*' ) ? 'ul' : 'ol';
                    if ($in_table) {
                        $$in_table .= "</table>";
                        undef $in_table;
                    }
                    $_       = "<$list_type>$_";
                    $in_list = \$_;
                }
                next;
            }

            if ( $_ =~ s/^\|(.*)\|$/$1/ ) {

                # | Table row |
                my @cols = split( /\|/, $_ );
                if ($in_list) {
                    $$in_list .= "</$list_type>";
                    undef $in_list;
                }
                if ($in_table) {
                    $_ = '';
                }
                else {
                    $_        = '<table>';
                    $in_table = \$_;
                }
                $$in_table .=
                  '<tr><td>' . join( '</td><td>', @cols ) . '</td></tr>';
                next;
            }

            if ($in_list) {
                $$in_list .= "</$list_type>";
                undef $in_list;
            }
            elsif ($in_table) {
                $$in_table .= '</table>';
                undef $in_table;
            }

            if ( $_ =~ s/^PREFORMAT:// ) {
                $_ =~ s/&/&amp;/g;
                $_ =~ s/</&lt;/g;
                $_ =~ s/>/&gt;/g;
                $_ = "<textarea>$_</textarea>";
            }
            elsif (
                $_ =~ s/^---(\++) (.*)$/
                    '<h' . length($1) . "> $2 <\/h" . length($1) .'>'/e
              )
            {
            }
        }
        if ($in_list) {
            $$in_list .= "</$list_type>";
        }
        elsif ($in_table) {
            $$in_table .= '</table>';
        }

        for my $e ( @{ $this->{$group} } ) {
            next unless $e;
            push( @notes, "<div class='$group_css{$group}'>$e</div>" );
        }
    }
    return join( "\n", @notes );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
