package Locale::Msgfmt;

use 5.008005;
use strict;
use warnings;
use Exporter              ();
use File::Spec            ();
use Locale::Msgfmt::mo    ();
use Locale::Msgfmt::po    ();
use Locale::Msgfmt::Utils ();

our $VERSION = '0.15';
our @ISA     = 'Exporter';
our @EXPORT  = qw/msgfmt/;

sub do_msgfmt_for_module_install {
	my $lib       = shift;
	my $sharepath = shift;
	my $fullpath  = File::Spec->catfile( $lib, $sharepath, 'locale' );
	unless ( -d $fullpath ) {
		die "$fullpath isn't a directory";
	}
	msgfmt( { in => $fullpath, verbose => 1, remove => 1 } );
}

sub msgfmt {
	my $hash = shift;
	unless ( defined($hash) ) {
		die "error: must give input";
	}
	unless ( ref($hash) eq "HASH" ) {
		$hash = { in => $hash };
	}
	unless ( defined $hash->{in} and length $hash->{in} ) {
		die "error: must give an input file";
	}
	unless ( -e $hash->{in} ) {
		die "error: input does not exist";
	}
	unless ( defined $hash->{verbose} ) {
		$hash->{verbose} = 1;
	}
	if ( -d $hash->{in} ) {
		return _msgfmt_dir($hash);
	} else {
		return _msgfmt($hash);
	}
}

sub _msgfmt {
	my $hash = shift;
	unless ( defined $hash->{in} ) {
		die "error: must give an input file";
	}
	unless ( -f $hash->{in} ) {
		die "error: input file does not exist";
	}
	unless ( defined $hash->{out} ) {
		unless ( $hash->{in} =~ /\.po$/ ) {
			die "error: must give an output file";
		}
		$hash->{out} = $hash->{in};
		$hash->{out} =~ s/po$/mo/;
	}
	unless ( $hash->{force} ) {
		my $min  = Locale::Msgfmt::Utils::mtime( $hash->{in} );
		my $mout = Locale::Msgfmt::Utils::mtime( $hash->{out} );
		if ( -f $hash->{out} and $mout > $min ) {
			return;
		}
	}
	my $mo = Locale::Msgfmt::mo->new;
	$mo->initialize;
	my $po = Locale::Msgfmt::po->new( { fuzzy => $hash->{fuzzy} } );
	$po->parse( $hash->{in}, $mo );
	$mo->prepare;
	unlink( $hash->{out} ) if -f $hash->{out};
	$mo->out( $hash->{out} );
	print $hash->{in} . " -> " . $hash->{out} . "\n" if $hash->{verbose};
	unlink( $hash->{in} ) if $hash->{remove};
}

sub _msgfmt_dir {
	my $hash = shift;
	unless ( -d $hash->{in} ) {
		die("error: input directory does not exist");
	}
	unless ( defined $hash->{out} ) {
		$hash->{out} = $hash->{in};
	}
	unless ( -d $hash->{out} ) {
		File::Path::mkpath( $hash->{out} );
	}

	print "$hash->{in} -> $hash->{out}\n" if $hash->{verbose};

	local *DIRECTORY;
	opendir( DIRECTORY, $hash->{in} ) or die "Could not open ($hash->{in}) $!";
	my @list = readdir DIRECTORY;
	closedir DIRECTORY;

	my @removelist = ();
	if ( $hash->{remove} ) {
		@removelist = grep /\.pot$/, @list;
	}
	@list = grep /\.po$/, @list;

	my %files;
	foreach ( @list ) {
		my $in  = File::Spec->catfile( $hash->{in}, $_ );
		my $out = File::Spec->catfile( $hash->{out}, substr( $_, 0, -3 ) . ".mo" );
		$files{$in} = $out;
	}
	foreach ( keys %files ) {
		_msgfmt( { %$hash, in  => $_, out => $files{$_} } );
	}
	foreach ( @removelist ) {
		my $f = File::Spec->catfile( $hash->{in}, $_ );
		print "-$f\n" if $hash->{verbose};
		unlink($f);
	}
}

1;

=pod

=head1 NAME

Locale::Msgfmt - Compile .po files to .mo files

=head1 SYNOPSIS

This module does the same thing as msgfmt from GNU gettext-tools,
except this is pure Perl. The interface is best explained through
examples:

  use Locale::Msgfmt;

  # Compile po/fr.po into po/fr.mo
  msgfmt({in => "po/fr.po", out => "po/fr.mo"});
  
  # Compile po/fr.po into po/fr.mo and include fuzzy translations
  msgfmt({in => "po/fr.po", out => "po/fr.mo", fuzzy => 1});
  
  # Compile all the .po files in the po directory, and write the .mo
  # files to the po directory
  msgfmt("po/");
  
  # Compile all the .po files in the po directory, and write the .mo
  # files to the po directory, and include fuzzy translations
  msgfmt({in => "po/", fuzzy => 1});
  
  # Compile all the .po files in the po directory, and write the .mo
  # files to the output directory, creating the output directory if
  # it doesn't already exist
  msgfmt({in => "po/", out => "output/"});
  
  # Compile all the .po files in the po directory, and write the .mo
  # files to the output directory, and include fuzzy translations
  msgfmt({in => "po/", out => "output/", fuzzy => 1});
  
  # Compile po/fr.po into po/fr.mo
  msgfmt("po/fr.po");
  
  # Compile po/fr.po into po/fr.mo and include fuzzy translations
  msgfmt({in => "po/fr.po", fuzzy => 1});

=head1 COPYRIGHT & LICENSE

Copyright 2009 Ryan Niebur, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
