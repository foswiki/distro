package Locale::Maketext::Extract::Plugin::Base;

use strict;

use File::Basename qw(fileparse);

=head1 NAME

Locale::Maketext::Extract::Plugin::Base - Base module for format parser plugins

=head1 SYNOPSIS

    package My::Parser::Plugin;
    use base qw(Locale::Maketext::Extract::Plugin::Base);

    sub file_types {
        return [qw( ext ext2 )]
    }

    sub extract {
        my $self = shift;
        my $filename = shift;
        local $_ = shift;

        my $line = 1;

        while (my $found = $self->routine_to_extract_strings) {
            $self->add_entry($str,[$filename,$line,$vars])
        }

        return;
    }

=head1 DESCRIPTION

All format parser plugins in Locale::Maketext::Extract inherit from
Locale::Maketext::Extract::Plugin::Base.

If you want to write your own custom parser plugin, you will need to inherit
from this module, and provide C<file_types()> and C<extract()> methods,
as shown above.

=head1 METHODS

=over 4

=item new()

    $plugin = My::Parser->new(
        @file_types         # Optionally specify a list of recognised file types
    )

=cut

sub new {
    my $class = shift;
    my $self = bless {
        entries => [],
    }, $class;

    $self->_compile_file_types(@_);
    return $self;
}

=item add_entry()

    $plugin->add_entry($str,$line,$vars)

=cut

sub add_entry {
    my $self = shift;
    push @{$self->{entries}},[@_];
}

=item C<entries()>

    $entries = $plugin->entries;

=cut

#===================================
sub entries {
#===================================
    my $self = shift;
    return $self->{entries};
}

=item C<clear()>

    $plugin->clear

Clears all stored entries.

=cut

#===================================
sub clear {
#===================================
    my $self = shift;
    $self->{entries}=[];
}

=item file_types()

    @default_file_types = $plugin->file_types

Returns a list of recognised file types that your module knows how to parse.

Each file type can be one of:

=over 4

=item * A plain string

   'pl'  => base filename is matched against qr/\.pl$/
   '*'   => all files are accepted

=item * A regex

   qr/\.tt2?\./ => base filename is matched against this regex

=item * A codref

    sub {}  => this codref is called as $coderef->($base_filename,$path_to_file)
               It should return true or false

=back

=cut

sub file_types {
    die "Please override sub file_types() to return "
        . "a list of recognised file extensions, or regexes";
}

=item extract()

    $plugin->extract($filecontents);

extract() is the method that will be called to process the contents of the
current file.

When it finds a string that should be extracted, it should call

   $self->add_entry($string,$line,$vars])

where C<$vars> refers to any arguments that are being passed to the localise
function. For instance:

   l("You found [quant,_1,file,files]",files_found)

     string: "You found [quant,_1,file,files]"
     vars  : (files_found)

IMPORTANT: a single plugin instance is used for all files, so if you plan
on storing state information in the C<$plugin> object, this should be cleared
out at the beginning of C<extract()>

=cut

sub extract {
    die "Please override sub extract()";
}

sub _compile_file_types {
    my $self = shift;
    my @file_types
        = ref $_[0] eq 'ARRAY'
            ? @{ shift @_ }
            : @_;
    @file_types = $self->file_types
        unless @file_types;

    my @checks;
    if ( grep { $_ eq '*' } @file_types ) {
        $self->{file_checks} = [ sub {1} ];
        return;
    }
    foreach my $type (@file_types) {
        if ( ref $type eq 'CODE' ) {
            push @checks, $type;
            next;
        }
        else {
            my $regex
                = ref $type
                ? $type
                : qr/^.*\.\Q$type\E$/;
            push @checks, sub { $_[0] =~ m/$regex/ };
        }
    }
    $self->{file_checks} = \@checks;
}

=item known_file_type()

    if ($plugin->known_file_type($filename_with_path)) {
        ....
    }

Determines whether the current file should be handled by this parser, based
either on the list of file_types speficied when this object was created,
or the default file_types specified in the module.

=cut

sub known_file_type {
    my $self = shift;
    my ( $name, $path ) = fileparse( shift @_ );
    foreach my $check ( @{ $self->{file_checks} } ) {
        return 1 if $check->( $name, $path );
    }
    return 0;
}

=back

=head1 SEE ALSO

=over 4

=item L<xgettext.pl>

for extracting translatable strings from common template
systems and perl source files.

=item L<Locale::Maketext::Lexicon>

=item L<Locale::Maketext::Extract::Plugin::Perl>

=item L<Locale::Maketext::Extract::Plugin::PPI>

=item L<Locale::Maketext::Extract::Plugin::TT2>

=item L<Locale::Maketext::Extract::Plugin::YAML>

=item L<Locale::Maketext::Extract::Plugin::FormFu>

=item L<Locale::Maketext::Extract::Plugin::Mason>

=item L<Locale::Maketext::Extract::Plugin::TextTemplate>

=item L<Locale::Maketext::Extract::Plugin::Generic>

=back

=head1 AUTHORS

Clinton Gormley [DRTECH] E<lt>clinton@traveljury.comE<gt>

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
