package Locale::Maketext::Extract::Plugin::YAML;

use strict;
use base qw(Locale::Maketext::Extract::Plugin::Base);

=head1 NAME

Locale::Maketext::Extract::Plugin::YAML - YAML format parser

=head1 SYNOPSIS

    $plugin = Locale::Maketext::Extract::Plugin::YAML->new(
        $lexicon            # A Locale::Maketext::Extract object
        @file_types         # Optionally specify a list of recognised file types
    )

    $plugin->extract($filename,$filecontents);

=head1 DESCRIPTION

Extracts strings to localise from YAML files.

=head1 SHORT PLUGIN NAME

    yaml

=head1 VALID FORMATS

Valid formats are:

=over 4

=item *

    key: _"string"

=item *

    key: _'string'

=item *

    key: _'string with embedded 'quotes''

=item *

    key: |-
         _'my folded
         string
         to translate'

Note, the left hand side of the folded string must line up with the C<_>,
otherwise YAML adds spaces at the beginning of each line.

=item *

    key: |-
         _'my block
         string
         to translate
         '
Note, you must use the trailing C<-> so that YAMl doesn't add a carriage
return after your final quote.

=back

=head1 KNOWN FILE TYPES

=over 4

=item .yaml

=item .yml

=item .conf

=back

=head1 REQUIRES

L<YAML>

=head1 NOTES

The docs for the YAML module describes it as alpha code. It is not as tolerant
of errors as L<YAML::Syck>. However, because it is pure Perl, it is easy
to hook into.

I have seen it enter endless loops, so if xgettext.pl hangs, try running it
again with C<--verbose --verbose> (twice) enabled, so that you can see if
the fault lies with YAML.  If it does, either correct the YAML source file,
or use the file_types to exclude that file.

=cut


sub file_types {
    return qw( yaml yml conf );
}

sub extract {
    my $self = shift;
    my $data = shift;

    my $y = Locale::Maketext::Extract::Plugin::YAML::Extractor->new();
    $y->load($data);

    foreach my $entry (@{$y->found}) {
        $self->add_entry(@$entry)
    }

}


package Locale::Maketext::Extract::Plugin::YAML::Extractor;

use base qw(YAML::Loader);

#===================================
sub new {
#===================================
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{found} = [];
    return $self;
}

#===================================
sub check_scalar {
#===================================
    my $self = shift;
    my $node = $_[0];
    if ( defined $node && !ref $node && $node =~ /^__?(["'])(.+)\1$/s ) {
        my $string = $2;
        my $line   = $_[1];
        push @{ $self->{found} }, [ $string, $line ];
    }
    return $node;
}

sub _parse_node {
    my $self = shift;
    my $line = $self->{_start_line}||=length($self->preface) ? $self->line - 1 : $self->line;
    my $node = $self->SUPER::_parse_node(@_);
    $self->{start_line} = 0;
    return $self->check_scalar($node,$line);
}

sub _parse_inline_seq {
    my $self = shift;
    my $line = $self->{_start_line}||=$self->line;
    my $node = $self->SUPER::_parse_inline_seq(@_);
    foreach (@$node) {
        $self->check_scalar( $_, $line );
    }
    $self->{start_line} = 0;
    return $node;
}

sub _parse_inline_mapping {
    my $self = shift;
    my $line = $self->{_start_line}||=$self->line;
    my $node = $self->SUPER::_parse_inline_mapping(@_);
    foreach ( values %$node ) {
        $self->check_scalar( $_, $line );
    }
    $self->{start_line} = 0;
    return $node;
}

#===================================
sub _parse_next_line {
#===================================
    my $self = shift;
    $self->{_start_line}  = $self->line
        if $_[0] == YAML::Loader::COLLECTION;
    $self->SUPER::_parse_next_line(@_);
}

sub found {
    my $self = shift;
    return $self->{found};
}

=head1 SEE ALSO

=over 4

=item L<xgettext.pl>

for extracting translatable strings from common template
systems and perl source files.

=item L<YAML>

=item L<Locale::Maketext::Lexicon>

=item L<Locale::Maketext::Extract::Plugin::Base>

=item L<Locale::Maketext::Extract::Plugin::FormFu>

=item L<Locale::Maketext::Extract::Plugin::Perl>

=item L<Locale::Maketext::Extract::Plugin::TT2>

=item L<Locale::Maketext::Extract::Plugin::Mason>

=item L<Locale::Maketext::Extract::Plugin::TextTemplate>

=item L<Locale::Maketext::Extract::Plugin::Generic>

=back

=head1 AUTHORS

Clinton Gormley E<lt>clint@traveljury.comE<gt>

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