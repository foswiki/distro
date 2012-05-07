package Locale::Maketext::Extract::Plugin::PPI;

use strict;
use base qw(Locale::Maketext::Extract::Plugin::Base);
use PPI();

=head1 NAME

Locale::Maketext::Extract::Plugin::PPI - Perl format parser

=head1 SYNOPSIS

    $plugin = Locale::Maketext::Extract::Plugin::PPI->new(
        $lexicon            # A Locale::Maketext::Extract object
        @file_types         # Optionally specify a list of recognised file types
    )

    $plugin->extract($filename,$filecontents);

=head1 DESCRIPTION

Does exactly the same thing as the L<Locale::Maketext::Extract::Plugin::Perl>
parser, but more accurately, and more slowly. Considerably more slowly! For this
reason it isn't a built-in plugin.


=head1 SHORT PLUGIN NAME

    none - the module must be specified in full

=head1 VALID FORMATS

Valid localization function names are:

=over 4

=item translate

=item maketext

=item gettext

=item loc

=item x

=item _

=item __

=back

=head1 KNOWN FILE TYPES

=over 4

=item .pm

=item .pl

=item .cgi

=back

=cut

sub file_types {
    return qw( pm pl cgi );
}

my %subnames = map { $_ => 1 } qw (translate maketext gettext loc x __);

#===================================
sub extract {
#===================================
    my $self = shift;
    my $text = shift;

    my $doc = PPI::Document->new( \$text, index_locations => 1 );

    foreach my $statement ( @{ $doc->find('PPI::Statement') } ) {
        my @children = $statement->schildren;

        while ( my $child = shift @children ) {
            next
                unless @children
                    && (    $child->isa('PPI::Token::Word')
                         && $subnames{ $child->content }
                         || $child->isa('PPI::Token::Magic')
                         && $child->content eq '_' );

            my $list = shift @children;
            next
                unless $list->isa('PPI::Structure::List')
                    && $list->schildren;

            $self->_check_arg_list($list);
        }
    }
}

#===================================
sub _check_arg_list {
#===================================
    my $self = shift;
    my $list = shift;
    my @args = ( $list->schildren )[0]->schildren;

    my $final_string = '';
    my ( $line, $mode );

    while ( my $string_el = shift @args ) {
        return
            unless $string_el->isa('PPI::Token::Quote')
                || $string_el->isa('PPI::Token::HereDoc');
        $line ||= $string_el->location->[0];
        my $string;
        if ( $string_el->isa('PPI::Token::HereDoc') ) {
            $string = join( '', $string_el->heredoc );
            $mode
                = $string_el->{_mode} eq 'interpolate'
                ? 'double'
                : 'literal';
        }
        else {
            $string = $string_el->string;
            $mode
                = $string_el->isa('PPI::Token::Quote::Literal') ? 'literal'
                : (    $string_el->isa('PPI::Token::Quote::Double')
                    || $string_el->isa('PPI::Token::Quote::Interpolate') )
                ? 'double'
                : 'single';
        }

        if ( $mode eq 'double' ) {
            return
                if !!( $string =~ /(?<!\\)(?:\\\\)*[\$\@]/ );
            $string = eval qq("$string");
        }
        elsif ( $mode eq 'single' ) {
            $string =~ s/\\'/'/g;
        }

        #    $string =~ s/(?<!\\)\\//g;
        $string =~ s/\\\\/\\/g;

        #        unless $mode eq 'literal';

        $final_string .= $string;

        my $next_op = shift @args;
        last
            unless $next_op
                && $next_op->isa('PPI::Token::Operator')
                && $next_op->content eq '.';
    }
    return unless $final_string;

    my $vars = join( '', map { $_->content } @args );
    $self->add_entry( $final_string, $line, $vars );
}

=head1 SEE ALSO

=over 4

=item L<xgettext.pl>

for extracting translatable strings from common template
systems and perl source files.

=item L<Locale::Maketext::Lexicon>

=item L<Locale::Maketext::Extract::Plugin::Base>

=item L<Locale::Maketext::Extract::Plugin::Perl>

=item L<Locale::Maketext::Extract::Plugin::FormFu>

=item L<Locale::Maketext::Extract::Plugin::Perl>

=item L<Locale::Maketext::Extract::Plugin::TT2>

=item L<Locale::Maketext::Extract::Plugin::YAML>

=item L<Locale::Maketext::Extract::Plugin::TextTemplate>

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
