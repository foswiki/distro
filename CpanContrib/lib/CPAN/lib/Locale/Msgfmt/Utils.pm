package Locale::Msgfmt::Utils;

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.15';

sub character {
	return map { pack "N*", $_ } @_;
}

sub _from_character {
	return map { ord($_) } @_;
}

sub from_character {
	return character( _from_character(@_) );
}

sub _from_hex {
	return map { hex($_) } @_;
}

sub from_hex {
	return character( _from_hex(@_) );
}

sub _from_string {
	return split //, join '', @_;
}

sub from_string {
	return join_string( from_character( _from_string(@_) ) );
}

sub join_string {
	return join '', @_;
}

sub number_to_s {
	return sprintf "%d", shift;
}

sub null_terminate {
	return pack "Z*", shift;
}

sub null {
	return null_terminate("");
}

sub eot {
	return chr(4);
}

sub mtime {
	return @{ [ stat(shift) ] }[9];
}

1;

__END__

=pod

=head1 NAME

Locale::Msgfmt::Utils - Functions used internally by Locale::Msgfmt

=head1 SYNOPSIS

This module shouldn't be used by other software.

=head1 SEE ALSO

L<Locale::Msgfmt>

=cut
