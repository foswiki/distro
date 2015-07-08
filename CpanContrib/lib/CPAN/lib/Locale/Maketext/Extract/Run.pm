package Locale::Maketext::Extract::Run;
$Locale::Maketext::Extract::Run::VERSION = '1.00';
use strict;
use vars qw( @ISA @EXPORT_OK );
use File::Spec::Functions qw(catfile);

# ABSTRACT: Module interface to xgettext.pl


use Cwd;
use Config ();
use File::Find;
use Getopt::Long;
use Locale::Maketext::Extract;
use Exporter;

use constant HAS_SYMLINK => ( $Config::Config{d_symlink} ? 1 : 0 );

@ISA       = 'Exporter';
@EXPORT_OK = 'xgettext';

sub xgettext { __PACKAGE__->run(@_) }

sub run {
    my $self = shift;
    local @ARGV = @_;

    my %opts;
    Getopt::Long::Configure("no_ignore_case");
    Getopt::Long::GetOptions(
        \%opts,               'f|files-from:s@',
        'D|directory:s@',     'u|use-gettext-style|unescaped',
        'g|gnu-gettext',      'o|output:s@',
        'd|default-domain:s', 'p|output-dir:s@',
        'P|plugin:s@',        'W|wrap!',
        'w|warnings!',        'v|verbose+',
        'h|help',
    ) or help();

    help() if $opts{h};

    my %extract_options = %{ $self->_parse_extract_options( \%opts ) };

    my @po = @{ $opts{o} || [ ( $opts{d} || 'messages' ) . '.po' ] };

    foreach my $file ( @{ $opts{f} || [] } ) {
        open FILE, $file or die "Cannot open $file: $!";
        while (<FILE>) {
            chomp;
            push @ARGV, $_ if -r and !-d;
        }
    }

    foreach my $dir ( @{ $opts{D} || [] } ) {
        File::Find::find(
            {   wanted => sub {
                    if (-d) {
                        $File::Find::prune
                            = /^(\.svn|blib|autogen|var|m4|local|CVS|\.git)$/;
                        return;
                    }

                    # Only extract from non-binary, normal files
                    return unless ( -f or -s ) and -T;
                    return
                        if (/\.pot?$|\.bak$|~|,D|,B$/i)
                        || (/^[\.#]/);
                    push @ARGV, $File::Find::name;
                },
                follow => HAS_SYMLINK,
            },
            $dir
        );
    }

    @ARGV = ('-') unless @ARGV;
    s!^\.[/\\]!! for @ARGV;

    my $cwd = getcwd();

    my $Ext = Locale::Maketext::Extract->new(%extract_options);
    foreach my $dir ( @{ $opts{p} || ['.'] } ) {
        $Ext->extract_file($_) for grep !/\.po$/i, @ARGV;
        foreach my $po (@po) {
            $Ext->read_po($po) if -r $po and -s _;
            $Ext->compile( $opts{u} ) or next;
            $Ext->write_po( catfile( $dir, $po ), $opts{g} );
        }
    }
}

sub _parse_extract_options {
    my $self = shift;
    my $opts = shift;

    # If a list of plugins is specified, then we use those modules
    # plus their default list of file extensions
    # and warnings enabled by default

    my %extract_options
        = ( verbose => $opts->{v}, wrap => $opts->{W} || 0 );

    if ( my $plugin_args = $opts->{P} ) {

        # file extension with potentially multiple dots eg .tt.html
        my %plugins;

        foreach my $param (@$plugin_args) {
            my ( $plugin, $args )
                = ( $param =~ /^([a-z_]\w+(?:::\w+)*)(?:=(.+))?$/i );
            die "Couldn't understand plugin option '$param'"
                unless $plugin;
            my @extensions;
            if ($args) {
                foreach my $arg ( split /,/, $args ) {
                    if ( $arg eq '*' ) {
                        @extensions = ('*');
                        last;
                    }
                    my ($extension) = ( $arg =~ /^\.?(\w+(?:\.\w+)*)$/ );
                    die "Couldn't understand '$arg' in plugin '$param'"
                        unless defined $extension;
                    push @extensions, $extension;
                }
            }

            $plugins{$plugin} = \@extensions;
        }
        $extract_options{plugins} = \%plugins;
        $extract_options{warnings} = exists $opts->{w} ? $opts->{w} : 1;
    }

    # otherwise we default to the original xgettext.pl modules
    # with warnings disabled by default
    else {
        $extract_options{warnings} = $opts->{w};
    }
    return \%extract_options;

}

sub help {
    local $SIG{__WARN__} = sub { };
    { exec "perldoc $0"; }
    { exec "pod2text $0"; }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Locale::Maketext::Extract::Run - Module interface to xgettext.pl

=head1 VERSION

version 1.00

=head1 SYNOPSIS

    use Locale::Maketext::Extract::Run 'xgettext';
    xgettext(@ARGV);

=head1 COPYRIGHT

Copyright 2003-2013 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This software is released under the MIT license cited below.

=head2 The "MIT" License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

=head1 AUTHORS

=over 4

=item *

Clinton Gormley <drtech@cpan.org>

=item *

Audrey Tang <cpan@audreyt.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Audrey Tang.

This is free software, licensed under:

  The MIT (X11) License

=cut
