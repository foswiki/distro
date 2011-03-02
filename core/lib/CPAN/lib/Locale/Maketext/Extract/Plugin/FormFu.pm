package Locale::Maketext::Extract::Plugin::FormFu;

use strict;
use base qw(Locale::Maketext::Extract::Plugin::Base);

=head1 NAME

Locale::Maketext::Extract::Plugin::FormFu - FormFu format parser

=head1 SYNOPSIS

    $plugin = Locale::Maketext::Extract::Plugin::FormFu->new(
        $lexicon            # A Locale::Maketext::Extract object
        @file_types         # Optionally specify a list of recognised file types
    )

    $plugin->extract($filename,$filecontents);

=head1 DESCRIPTION

HTML::FormFu uses a config-file to generate forms, with built in support
for localizing errors, labels etc.

=head1 SHORT PLUGIN NAME

    formfu

=head1 VALID FORMATS

We extract the text after any key which ends in C<_loc>:

    content_loc: this is the string

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

    my $y = Locale::Maketext::Extract::Plugin::FormFu::Extractor->new();
    $y->load($data);

    foreach my $entry ( @{ $y->found } ) {
        $self->add_entry(@$entry);
    }

}

package Locale::Maketext::Extract::Plugin::FormFu::Extractor;

use base qw(YAML::Loader);

#===================================
sub new {
#===================================
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{found}       = [];
    return $self;
}

#===================================
sub _check_key {
#===================================
    my $self = shift;
    my ( $key, $value, $line ) = @_;
    if ( $key && $key =~ /_loc$/ && defined $value && !ref $value ) {
        push @{ $self->{found} }, [ $value, $line ];
    }

    return;
}

#===================================
sub _parse_mapping {
#===================================
    my $self     = shift;
    my ($anchor) = @_;
    my $mapping  = {};
    $self->anchor2node->{$anchor} = $mapping;
    my $key;
    while ( not $self->done
            and $self->indent == $self->offset->[ $self->level ] )
    {

        # If structured key:
        if ( $self->{content} =~ s/^\?\s*// ) {
            $self->preface( $self->content );
            $self->_parse_next_line(YAML::Loader::COLLECTION);
            $key = $self->_parse_node();
            $key = "$key";
        }

        # If "default" key (equals sign)
        elsif ( $self->{content} =~ s/^\=\s*// ) {
            $key = YAML::Loader::VALUE;
        }

        # If "comment" key (slash slash)
        elsif ( $self->{content} =~ s/^\=\s*// ) {
            $key = YAML::Loader::COMMENT;
        }

        # Regular scalar key:
        else {
            $self->inline( $self->content );
            $key = $self->_parse_inline();
            $key = "$key";
            $self->content( $self->inline );
            $self->inline('');
        }

        unless ( $self->{content} =~ s/^:\s*// ) {
            $self->die('YAML_LOAD_ERR_BAD_MAP_ELEMENT');
        }
        $self->preface( $self->content );
        my $line = $self->line;
        $self->_parse_next_line(YAML::Loader::COLLECTION);
        my $value = $self->_parse_node();
        if ( exists $mapping->{$key} ) {
            $self->warn('YAML_LOAD_WARN_DUPLICATE_KEY');
        }
        else {
            $mapping->{$key} = $value;
            $self->_check_key( $key, $value, $line );
        }
    }
    return $mapping;
}

#===================================
sub _parse_inline_mapping {
#===================================
    my $self       = shift;
    my ($anchor)   = @_;
    my $node       = {};
    my $start_line = $self->{_start_line};

    $self->anchor2node->{$anchor} = $node;

    $self->die('YAML_PARSE_ERR_INLINE_MAP')
        unless $self->{inline} =~ s/^\{\s*//;
    while ( not $self->{inline} =~ s/^\s*\}// ) {
        my $key = $self->_parse_inline();
        $self->die('YAML_PARSE_ERR_INLINE_MAP')
            unless $self->{inline} =~ s/^\: \s*//;
        my $value = $self->_parse_inline();
        if ( exists $node->{$key} ) {
            $self->warn('YAML_LOAD_WARN_DUPLICATE_KEY');
        }
        else {
            $node->{$key} = $value;
            $self->_check_key( $key, $value, $start_line );
        }
        next if $self->inline =~ /^\s*\}/;
        $self->die('YAML_PARSE_ERR_INLINE_MAP')
            unless $self->{inline} =~ s/^\,\s*//;
    }
    return $node;
}

#===================================
sub _parse_next_line {
#===================================
    my $self = shift;
    $self->{_start_line}  = $self->line;
    $self->SUPER::_parse_next_line(@_);
}

#===================================
sub found {
#===================================
    my $self = shift;
    return $self->{found};
}

=head1 SEE ALSO

=over 4

=item L<xgettext.pl>

for extracting translatable strings from common template
systems and perl source files.

=item L<YAML>

=item L<HTML::FormFu>

=item L<Locale::Maketext::Lexicon>

=item L<Locale::Maketext::Extract::Plugin::Base>

=item L<Locale::Maketext::Extract::Plugin::Perl>

=item L<Locale::Maketext::Extract::Plugin::TT2>

=item L<Locale::Maketext::Extract::Plugin::YAML>

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
