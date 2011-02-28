package Locale::Maketext::Lexicon::Tie;
$Locale::Maketext::Lexicon::Tie::VERSION = '0.05';

use strict;
use Symbol ();

=head1 NAME

Locale::Maketext::Lexicon::Tie - Use tied hashes as lexicons for Maketext

=head1 SYNOPSIS

    package Hello::I18N;
    use base 'Locale::Maketext';
    use Locale::Maketext::Lexicon {
        en => [ Tie => [ DB_File => 'en.db' ] ],
    };

=head1 DESCRIPTION

This module lets you easily C<tie> the C<%Lexicon> hash to a database
or other data sources.  It takes an array reference of arguments, and
passes them directly to C<tie()>.

Entries will then be fetched whenever it is used; this module does not
cache them.

=cut

sub parse {
    my $self = shift;
    my $mod  = shift;
    my $sym  = Symbol::gensym();

    # Load the target module into memory
    {
        no strict 'refs';
        eval "use $mod; 1" or die $@ unless %{"$mod\::"};
    }

    # Perform the actual tie
    tie %{*$sym}, $mod, @_;

    # Returns the GLOB reference, so %Lexicon will be tied too
    return $sym;
}

1;

=head1 SEE ALSO

L<Locale::Maketext>, L<Locale::Maketext::Lexicon>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2002, 2003, 2004, 2007 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

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
