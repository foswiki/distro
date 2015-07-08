package Locale::Maketext::Extract::Plugin::Haml;
$Locale::Maketext::Extract::Plugin::Haml::VERSION = '1.00';
use strict;
use warnings;
use base qw(Locale::Maketext::Extract::Plugin::Base);
use Text::Haml;
use Locale::Maketext::Extract::Plugin::Perl;

# ABSTRACT: HAML format parser


sub file_types {
    return qw( haml );
}

sub extract {
    my $self    = shift;
    my $content = shift;

    my $haml = Text::Haml->new;
    $haml->parse($content);

    # Checking for expr and text allows us to recognise
    # the types of HTML entries we are interested in.
    my @texts = map { $_->{text} }
      grep { $_->{text} and ( $_->{expr} or $_->{type} eq 'block') }
          @{ $haml->tape };

    my $perl = Locale::Maketext::Extract::Plugin::Perl->new;

    # Calling extract on our strings will cause
    # EPPerl to store our entries internally.
    map { $perl->extract($_) } @texts;

    map { $self->add_entry( @{$_} ) } @{ $perl->entries };
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Locale::Maketext::Extract::Plugin::Haml - HAML format parser

=head1 VERSION

version 1.00

=head1 SYNOPSIS

    $plugin = Locale::Maketext::Extract::Plugin::Haml->new(
        $lexicon            # A Locale::Maketext::Extract object
        @file_types         # Optionally specify a list of recognised file types
    )

    $plugin->extract($filename,$filecontents);

=head1 DESCRIPTION

Extracts strings to localise from HAML files.

=head1 SHORT PLUGIN NAME

    haml

=head1 VALID FORMATS

Extracts strings in the same way as Locale::Maketext::Extract::Plugin::Perl,
but only ones within "text" components of HAML files.

=head1 KNOWN FILE TYPES

=over 4

=item .haml

=back

=head1 SEE ALSO

=over 4

=item L<xgettext.pl>

for extracting translatable strings from common template
systems and perl source files.

=item L<Locale::Maketext::Lexicon>

=item L<Locale::Maketext::Extract::Plugin::Base>

=item L<Locale::Maketext::Extract::Plugin::FormFu>

=item L<Locale::Maketext::Extract::Plugin::Mason>

=item L<Locale::Maketext::Extract::Plugin::Perl>

=item L<Locale::Maketext::Extract::Plugin::TT2>

=item L<Locale::Maketext::Extract::Plugin::YAML>

=item L<Locale::Maketext::Extract::Plugin::TextTemplate>

=item L<Locale::Maketext::Extract::Plugin::Generic>

=back

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

Calum Halcrow E<lt>cpan@calumhalcrow.comE<gt>

=head1 COPYRIGHT

Copyright 2002-2013 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

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

=head1 AUTHORS

=over 4

=item *

Clinton Gormley <drtech@cpan.org>

=item *

Audrey Tang <cpan@audreyt.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Audrey Tang.

This is free software, licensed under:

  The MIT (X11) License

=cut
