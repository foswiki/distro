package Locale::Msgfmt::mo;

use 5.008005;
use strict;
use warnings;
use Locale::Msgfmt::Utils ();

our $VERSION = '0.15';

sub new {
	return bless {}, shift;
}

sub initialize {
	my $self = shift;
	$self->{magic}   = "0x950412de";
	$self->{format}  = 0;
	$self->{strings} = {};
}

sub add_string {
	$_[0]->{strings}->{$_[1]} = $_[2];
}

sub prepare {
	my $self = shift;
	$self->{count}        = scalar keys %{ $self->{strings} };
	$self->{free_mem}     = 28 + $self->{count} * 16;
	$self->{sorted}       = [ sort keys %{ $self->{strings} } ];
	$self->{translations} = [
		map { $self->{strings}->{$_} } @{ $self->{sorted} }
	];
}

sub out {
	my $self = shift;
	my $file = shift;
	open my $OUT, ">", $file or die "Could not open ($file) $!";
	binmode $OUT;
	print $OUT Locale::Msgfmt::Utils::from_hex( $self->{magic} );
	print $OUT Locale::Msgfmt::Utils::character( $self->{format} );
	print $OUT Locale::Msgfmt::Utils::character( $self->{count} );
	print $OUT Locale::Msgfmt::Utils::character(28);
	print $OUT Locale::Msgfmt::Utils::character( 28 + $self->{count} * 8 );
	print $OUT Locale::Msgfmt::Utils::character(0);
	print $OUT Locale::Msgfmt::Utils::character(0);

	foreach ( @{ $self->{sorted} } ) {
		my $length = length($_);
		print $OUT Locale::Msgfmt::Utils::character($length);
		print $OUT Locale::Msgfmt::Utils::character( $self->{free_mem} );
		$self->{free_mem} += $length + 1;
	}
	foreach ( @{ $self->{translations} } ) {
		my $length = length($_);
		print $OUT Locale::Msgfmt::Utils::character($length);
		print $OUT Locale::Msgfmt::Utils::character( $self->{free_mem} );
		$self->{free_mem} += $length + 1;
	}
	foreach ( @{ $self->{sorted} } ) {
		print $OUT Locale::Msgfmt::Utils::null_terminate($_);
	}
	foreach ( @{ $self->{translations} } ) {
		print $OUT Locale::Msgfmt::Utils::null_terminate($_);
	}
	close $OUT;
}

1;

__END__

=pod

=head1 NAME

Locale::Msgfmt::mo - class used internally by Locale::Msgfmt

=head1 SYNOPSIS

This module shouldn't be used by other software.

=head1 SEE ALSO

L<Locale::Msgfmt>

=cut
