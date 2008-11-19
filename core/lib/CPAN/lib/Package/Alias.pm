# -*- perl -*-
#
# Package::Alias - Alias one namespace into another
#
# $Id: Alias.pm,v 1.9 2003/07/17 20:17:16 jkeroes Exp $

package Package::Alias;
use strict qw/vars subs/;
use vars   qw/$VERSION $DEBUG $BRAVE/;
use Carp;

$VERSION     = '0.04';
$DEBUG       = 0;

#------------------------------------------------------------
# Class Methods
#------------------------------------------------------------

sub alias {
    my $class_or_self = shift;
    my %args  = @_;

    while ( my ( $alias, $orig ) = each %args ) {

	if ( scalar keys %{$alias . "::" } && ! $BRAVE ) {
	    carp "Cowardly refusing to alias over '$alias' because it's already in use";
	    next;
	}

	*{$alias . "::"} = \*{$orig . "::"};

	print STDERR __PACKAGE__ . ": aliasing '$alias' => '$orig'\n"
	    if $DEBUG;
    }
}

*import = \&alias;

1;

__END__

#------------------------------------------------------------
# Docs
#------------------------------------------------------------

=head1 NAME

Package::Alias - alias one namespace into another

=head1 SYNOPSIS

  use Package::Alias Foo    => 'main',
		     P      => 'Really::Long::Package::Name',
                     'A::B' => 'C::D',
		     Alias  => 'Existing::Namespace';

=head1 DESCRIPTION

This module aliases one package name to another. After running the
SYNOPSIS code,  C<@INC> and C<@Foo::INC> reference the same memory.
C<$Really::Long::Package::Name::var> and $P::var do as well.

To be strict-compliant, you'll need to quote any packages on the
left-hand side of a => if the namespace has colons. Packages on the
right-hand side all have to be quoted. This is documented as
L<perlop/"Comma Operator">.

Chip Salzenberg says that it's not technically feasible to perform
runtime namespace aliasing.  At compile time, Perl grabs pointers to
functions and global vars.  Those pointers aren't updated if we alias
the namespace at runtime.

=head1 GLOBALS

Package::Alias won't, by default, alias over a namespace if it's
already in use. That's not considered a fatal error - you'll just get
a warning and flow will continue. You can change that cowardly
behaviour this way:

  # Make Bar like Foo, even if Bar is already in use.

  BEGIN { $Package::Alias::BRAVE = 1 }

  use Package::Alias Bar => 'Foo';

=head1 AUTHOR

Joshua Keroes <skunkworks@eli.net>

=head1 SEE ALSO

L<Devel::Symdump>

=cut
