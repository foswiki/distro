package Module::Install::Msgfmt;

use 5.008005;
use strict;
use warnings;
use File::Spec            ();
use Module::Install::Base ();

our $VERSION = '0.15';
our @ISA     = 'Module::Install::Base';

sub install_share_with_mofiles {
	my $self      = shift;
	my @orig      = (@_);
	my $class     = ref($self);
	my $prefix    = $self->_top->{prefix};
	my $name      = $self->_top->{name};
	my $dir       = @_ ? pop   : 'share';
	my $type      = @_ ? shift : 'dist';
	my $module    = @_ ? shift : '';
	$self->build_requires( 'Locale::Msgfmt' => '0.15' );
	$self->install_share(@orig);
	my $distname = "";
	if ( $type eq 'dist' ) {
		$distname = $self->name;
	} else {
		$distname = Module::Install::_CLASS($module);
		$distname =~ s/::/-/g;
	}
	my $path = File::Spec->catfile( 'auto', 'share', $type, $distname );
	$self->postamble(<<"END_MAKEFILE");
config ::
\t\$(NOECHO) \$(PERL) "-MLocale::Msgfmt" -e "Locale::Msgfmt::do_msgfmt_for_module_install(q(\$(INST_LIB)), q($path))"

END_MAKEFILE
}

1;
