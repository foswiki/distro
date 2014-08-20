# See bottom of file for license and copyright information
package Foswiki::Configure::Reporter;

# Report package for configure, supporting text reporting and
# simple TML expansion to HTML.

sub new {
    my $class = shift;

    my $this = {
        notes => [],
        confirmations => [],
        warnings => [],
        errors => [],
    };
    return bless($this, $class);
}

sub NOTE {
    my $this = shift;
    push(@{$this->{notes}}, map {
        $_ =~ /^PREFORMAT:/ ? $_ : split /\n/ } @_);
}

sub CONFIRM {
    my $this = shift;
    push(@{$this->{confirmations}}, map { split /\n/ } @_);
}

sub WARN {
    my $this = shift;
    push(@{$this->{warnings}}, map { split /\n/ } @_);
}

sub ERROR {
    my $this = shift;
    print STDERR join("\n",@_)."\n";
    push(@{$this->{errors}}, map { split /\n/ } @_);
}

sub text {
    my $this = shift;

    my @notes;
    for my $e (@{$this->{errors}}) {
        push(@notes, "Error: $e" ) if $e;;

    }
    for my $e (@{$this->{warnings}}) {
        push(@notes, "Warning: $e" ) if $e;
    }
    for my $e (@{$this->{confirmations}}) {
        push(@notes, "OK: $e" ) if $e;
    }
    for my $e (@{$this->{notes}}) {
        push(@notes, "Note: $e" ) if $e;
    }
    return join("\n", @notes);
}

our $S = qr/^|(?<=[\s\(])/m;
our $E = qr/$|(?=[\s,.;:!?)])/m;

# Formatting using a cut-down version of TML
sub html {
    my $this = shift;

    foreach $group ( 'errors', 'warnings', 'confirmations', 'notes' ) {
        my $in_list, # in an ol or ul
        $in_table; # in a table

        foreach ( @{$this->{$group}} ) {

            # {strong}
            $_ =~ s/${S}\{(\S+?|\S[^\n]*?\S)\}$E/<strong><code>{$1}<\/code><\/strong>/g;
            # *strong*
            $_ =~ s/${S}\*(\S+?|\S[^\n]*?\S)\*$E/<strong>$1<\/strong>/g;
            # _em_
            $_ =~ s/${S}\_(\S+?|\S[^\n]*?\S)\_$E/<em>$1<\/em>/g;
            # =code=
            $_ =~ s/${S}\=(\S+?|\S[^\n]*?\S)\=$E/<code>$1<\/code>/g;
            # [[http][link]]
            $_ =~ s/[[([^][])+][([^][]+)]]/<a href="$1">$2<\/a>/g;
            $_ =~ s/\n/<br \/>/g;

            if ($_ =~ s/^   (\*|\d) (.*)$/<li>$2<\/li>/) {
                #    * Bullet list item
                #    1 Ordered list item
                if ($in_list) {
                    $$in_list .= $_;
                    $_ = '';
                } else {
                    $list_type = ($1 eq '*') ? 'ul' : 'ol';
                    if ($in_table) {
                        $$in_table .= "</table>";
                        undef $in_table;
                    }
                    $_ = "<$list_type>$_";
                    $in_list = \$_;
                }
                next;
            }

            if ($_ =~ s/^\|(.*)\|$/$1/) {
                # | Table row |
                my @cols = split(/\|/, $_);
                if ($in_list) {
                    $$in_list .= "</$list_type>";
                    undef $in_list;
                }
                if ($in_table) {
                    $_ = '';
                } else {
                    $_ = '<table>';
                    $in_table = \$_;
                }
                $$in_table .= '<tr><td>'
                    . join('</td><td>', @cols) . '</td></tr>';
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

            if ($_ =~ s/^PREFORMAT://) {
                $_ =~ s/&/&amp;/g;
                $_ =~ s/</&lt;/g;
                $_ =~ s/>/&gt;/g;
                $_ = "<textarea>$_</textarea>";
            } elsif ($_ =~ s/^---(\++) (.*)$/
                    '<h' . length($1) . "> $2 <\/h" . length($1) .'>'/e) {
            }
        }
        if ($in_list) {
            $$in_list .= "</$list_type>";
        } elsif ($in_table) {
            $$in_table .= '</table>';
        }
    }

    my @notes;

    for my $e (@{$this->{errors}}) {
        next unless $e;
        push(@notes, "<div class='foswikiAlert configureError'><strong>Error:</strong>$e</div>");
    }
    for my $e (@{$this->{warnings}}) {
        next unless $e;
        push(@notes, "<div class='foswikiAlert configureError'><em>Warning:</em>$e</div/");
    }
    for my $e (@{$this->{confirmations}}) {
        next unless $e;
        push(@notes, "<div class='configureOk'>$e</div>");
    }
    push(@notes, '<div class="configureInfo">'
         .join('<br />', grep { $_ } @{$this->{notes}}) . '</div>');
    return join("\n", @notes);
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
