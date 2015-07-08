package Locale::Maketext::Lexicon::Auto;
$Locale::Maketext::Lexicon::Auto::VERSION = '1.00';
use strict;

# ABSTRACT: Auto fallback lexicon for Maketext


sub parse {
    +{ _AUTO => 1 };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Locale::Maketext::Lexicon::Auto - Auto fallback lexicon for Maketext

=head1 VERSION

version 1.00

=head1 SYNOPSIS

    package Hello::I18N;
    use base 'Locale::Maketext';
    use Locale::Maketext::Lexicon {
        en => ['Auto'],
        # ... other languages
    };

=head1 DESCRIPTION

This module builds a simple Lexicon hash that contains nothing but
C<( '_AUTO' =E<gt> 1)>, which tells C<Locale::Maketext> that no
localizing is needed -- just use the lookup key as the returned string.

It is especially useful if you're starting to prototype a program, and
do not want to deal with the localization files yet.

=head1 CAVEATS

If the key to C<-E<gt>maketext> begins with a C<_>, C<Locale::Maketext>
will still throw an exception.  See L<Locale::Maketext/CONTROLLING LOOKUP
FAILURE> for how to prevent it.

=head1 SEE ALSO

L<Locale::Maketext>, L<Locale::Maketext::Lexicon>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2002 - 2013 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

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
