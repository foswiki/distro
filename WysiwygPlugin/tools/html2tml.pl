#! /usr/bin/env perl
#
# Static HTML -> TML converter
#
# cd to the tools directory to run it

use strict;

BEGIN { do 'setlib.cfg'; }

use Getopt::Long ();
use Pod::Usage   ();

use Foswiki;
use Foswiki::Plugins::WysiwygPlugin::HTML2TML;
use Foswiki::Plugins::WysiwygPlugin::TML2HTML;

my %opts = ( very_clean => 1 );

sub _setopt {
    my ( $name, $val ) = @_;
    if ( -e $val ) {

        # It's a file
        my $fh;
        open( $fh, '<', $val ) || die $!;
        local $/ = undef;
        $val = <$fh>;
        close($fh);
    }
    $opts{$name} = $val;
}

my $result = Getopt::Long::GetOptions(
    'stickybits:s'  => \&_setopt,
    'ignoreattrs:s' => \&_setopt,
    'help'          => sub {
        Pod::Usage::pod2usage( -exitstatus => 0, -verbose => 2 );
        exit 0;
    }
);

my $session  = new Foswiki();
my $html2tml = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
undef $/;
my $html = <>;
my $tml = $html2tml->convert( $html, \%opts );
print $tml;

1;
__END__

=head1 tools/html2tml.pl

Convert HTML input to TML

=head1 SYNOPSIS

 perl -I bin tools/html2tml.pl [options]

Reads HTML from STDIN and writes generated TML to STDOUT.

=head1 OPTIONS

=over 8

=item B<--help>

Print this information.

=item B<--ignoreattrs> [file|value]

Sets the value of the WYSIWYGPLUGIN_IGNOREATTRS preference. If a filename is given, and the file exists, the option value will be read from that file. See the WysiwygPlugin docs for a detailed explanation of WYSIWYGPLUGIN_IGNOREATTRS.

=item B<--stickybits> [file|value]

Sets the value of the WYSIWYGPLUGIN_STICKYBITS preference. If a filename is given, and the file exists, the option value will be read from that file. See the WysiwygPlugin docs for a detailed explanation of WYSIWYGPLUGIN_STICKYBITS.


=back

=head1 EXAMPLES

 $ curl http://foswiki.org/Extensions/WysiwygPlugin | \
   perl -I bin tools/html2tml.pl --ignoreattrs 'font=face,size'

