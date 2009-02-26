package Locale::Maketext::Extract::Run;

use strict;
use vars qw( @ISA @EXPORT_OK );

use Cwd;
use File::Find;
use Getopt::Long;
use Locale::Maketext::Extract;
use Exporter;

@ISA = 'Exporter';
@EXPORT_OK = 'xgettext';

sub xgettext { __PACKAGE__->run(@_) }

sub run {
    my $self = shift;
    local @ARGV = @_;

    my %opts;
    Getopt::Long::Configure("no_ignore_case");
    Getopt::Long::GetOptions( \%opts,
        'f|files-from:s@',
        'D|directory:s@',
        'u|unescaped',
        'g|gnu-gettext',
        'o|output:s@',
        'd|default-domain:s',
        'p|output-dir:s@',
        'h|help',
    ) or help();
    help() if $opts{h};

    my @po = @{$opts{o} || [($opts{d}||'messages').'.po']};

    foreach my $file (@{$opts{f}||[]}) {
        open FILE, $file or die "Cannot open $file: $!";
        while (<FILE>) {
            push @ARGV, $_ if -r and !-d;
        }
    }

    foreach my $dir (@{$opts{D}||[]}) {
        File::Find::find( {
            wanted      => sub {
                return if
                    ( -d ) ||
                    ( $File::Find::dir =~ 'lib/blib|lib/t/autogen|var|m4|local' ) ||
                    ( /\.po$|\.bak$|~|,D|,B$/i ) ||
                    ( /^[\.#]/ );
                push @ARGV, $File::Find::name;
            },
            follow      => 1,
        }, $dir );
    }

    @ARGV = ('-') unless @ARGV;
    s!^.[/\\]!! for @ARGV;

    my $cwd = getcwd();

    foreach my $dir (@{$opts{p}||['.']}) {
        foreach my $po (@po) {
            my $Ext = Locale::Maketext::Extract->new;
            $Ext->read_po($po, $opts{u}) if -r $po;
            $Ext->extract_file($_) for grep !/\.po$/i, @ARGV;
            $Ext->compile($opts{u}) or next;

            chdir $dir;
            $Ext->write_po($po, $opts{g});
            chdir $cwd;
        }
    }
}

sub help {
    local $SIG{__WARN__} = sub {};
    { exec "perldoc $0"; }
    { exec "pod2text $0"; }
}

1;
