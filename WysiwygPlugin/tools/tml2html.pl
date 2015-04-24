#! /usr/bin/env perl
#
# Static TML -> HTML converter
#
# cd to the tools directory to run it

use strict;

BEGIN { do 'setlib.cfg'; }

use Getopt::Long ();
use Pod::Usage   ();

use Foswiki::Plugins::WysiwygPlugin::TML2HTML;

my %opts = (
    dieonerror      => 0,
    forcenoautolink => 0
);

sub _setlist {
    my ( $name, $val ) = @_;
    if ( -e $val ) {

        # It's a file
        my $fh;
        open( $fh, '<', $val ) || die $!;
        local $/ = undef;
        $val = <$fh>;
        close($fh);
    }
    $opts{$name} = [ split( /\s*,\s*/s, $val ) ];
}

my $result = Getopt::Long::GetOptions(
    'keeptags:s'      => \&_setlist,
    'keepblocks:s'    => \&_setlist,
    'dieonerror'      => \{ $opts{dieonerror} },
    'forcenoautolink' => \{ $opts{forcenoautolink} },
    'help'            => sub {
        Pod::Usage::pod2usage( -exitstatus => 0, -verbose => 2 );
        exit 0;
    }
);

my $conv = new Foswiki::Plugins::WysiwygPlugin::TML2HTML();
undef $/;
my $html = <>;
my $tml = $conv->convert( $html, \%opts );
print $tml;

1;
__END__

=head1 tools/html2tml.pl

Convert TML input to HTML

=head1 SYNOPSIS

 perl -I bin tools/tml2html.pl [options]

Reads TML from STDIN and writes generated HTML to STDOUT.

=head1 OPTIONS

=over 8

=item B<--help>

Print this information.

=item B<dieonerror>

makes convert throw an exception if a conversion fails.
     The default behaviour is to encode the whole topic as verbatim text.
=item B<keeptags> [file|list]

A comma-separated list of HTML tag names that are to have
the TMLhtml class added, to protect them during subsequent
HTML2TML conversion. Default is 'div,span'. If a filename
is given, and the file exists, the option value will be read from
that file.

=item B<keepblocks> [file|list]

A comma-separated list of (lowercase) tag names of HTML block tags 
that are to be protected. Default is 'script,style'. If a filename
is given, and the file exists, the option value will be read from
that file.

=item B<forcenoautolink>

Can be given to apply NOAUTOLINK across the entire conversion.

=back

=head1 EXAMPLES

 $ cat data/System/WysiwygPlugin.txt | \
   perl -I bin tools/tml2html.pl --forcenoautolink

