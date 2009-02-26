package Locale::Maketext::Lexicon::Auto;
$Locale::Maketext::Lexicon::Auto::VERSION = '0.02';

use strict;

=head1 NAME

Locale::Maketext::Lexicon::Auto - Auto fallback lexicon for Maketext

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

=cut

sub parse {
    return { _AUTO => 1 };
}

1;

=head1 SEE ALSO

L<Locale::Maketext>, L<Locale::Maketext::Lexicon>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002, 2003, 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
