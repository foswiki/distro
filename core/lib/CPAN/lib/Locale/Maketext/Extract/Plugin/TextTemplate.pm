package Locale::Maketext::Extract::Plugin::TextTemplate;

use strict;
use base qw(Locale::Maketext::Extract::Plugin::Base);
use vars qw($VERSION);

$VERSION = '0.31';

=head1 NAME

Locale::Maketext::Extract::Plugin::TextTemplate - Text::Template format parser

=head1 SYNOPSIS

    $plugin = Locale::Maketext::Extract::Plugin::TextTemplate->new(
        $lexicon            # A Locale::Maketext::Extract object
        @file_types         # Optionally specify a list of recognised file types
    )

    $plugin->extract($filename,$filecontents);

=head1 DESCRIPTION

Extracts strings to localise from Text::Template files

=head1 SHORT PLUGIN NAME

    text

=head1 VALID FORMATS

Sentences between STARTxxx and ENDxxx are extracted individually.

=head1 KNOWN FILE TYPES

=over 4

=item All file types

=back

=cut

sub file_types {
    return qw( * );
}


sub extract {
    my $self = shift;
    local $_ = shift;

    my $line = 1; pos($_) = 0;

    # Text::Template
    if ($_=~/^STARTTEXT$/m and $_=~ /^ENDTEXT$/m) {
        require HTML::Parser;
        require Lingua::EN::Sentence;

        {
            package Locale::Maketext::Extract::Plugin::TextTemplate::Parser;
            our @ISA = 'HTML::Parser';
            *{'text'} = sub {
                my ($self, $str, $is_cdata) = @_;
                my $sentences = Lingua::EN::Sentence::get_sentences($str) or return;
                $str =~ s/\n/ /g; $str =~ s/^\s+//; $str =~ s/\s+$//;
                $self->add_entry($str , $line);
            };
        }

        my $p = Locale::Maketext::Extract::Plugin::TextTemplate::Parser->new;
        while (m/\G((.*?)^(?:START|END)[A-Z]+$)/smg) {
            my ($str) = ($2);
            $line += ( () = ($1 =~ /\n/g) ); # cryptocontext!
            $p->parse($str); $p->eof;
        }
        $_ = '';
    }

}

=head1 SEE ALSO

=over 4

=item L<xgettext.pl>

for extracting translatable strings from common template
systems and perl source files.

=item L<Locale::Maketext::Lexicon>

=item L<Locale::Maketext::Extract::Plugin::Base>

=item L<Locale::Maketext::Extract::Plugin::FormFu>

=item L<Locale::Maketext::Extract::Plugin::Perl>

=item L<Locale::Maketext::Extract::Plugin::TT2>

=item L<Locale::Maketext::Extract::Plugin::YAML>

=item L<Locale::Maketext::Extract::Plugin::Mason>

=item L<Locale::Maketext::Extract::Plugin::Generic>

=back

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2002-2008 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This software is released under the MIT license cited below.

=head2 The "MIT" License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

=cut


1;
