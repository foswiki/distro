package Locale::Maketext::Lexicon::Tie;

use strict;
use Symbol ();

$Locale::Maketext::Lexicon::Tie::VERSION = '0.03';

=head1 NAME

Locale::Maketext::Lexicon::Tie - Use tied hashes as lexicons for Maketext

=head1 SYNOPSIS

    package Hello::I18N;
    use Locale::Maketext;
    our @ISA = qw( Locale::Maketext );
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
        eval "use $mod; 1" or die $@ unless defined %{"$mod\::"};
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

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002, 2003, 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
