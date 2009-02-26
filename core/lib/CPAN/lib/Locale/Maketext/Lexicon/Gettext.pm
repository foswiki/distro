package Locale::Maketext::Lexicon::Gettext;
$Locale::Maketext::Lexicon::Gettext::VERSION = '0.14';

use strict;

=head1 NAME

Locale::Maketext::Lexicon::Gettext - PO and MO file parser for Maketext

=head1 SYNOPSIS

Called via B<Locale::Maketext::Lexicon>:

    package Hello::I18N;
    use base 'Locale::Maketext';
    use Locale::Maketext::Lexicon {
        de => [Gettext => 'hello/de.mo'],
    };

Directly calling C<parse()>:

    use Locale::Maketext::Lexicon::Gettext;
    my %Lexicon = %{ Locale::Maketext::Lexicon::Gettext->parse(<DATA>) };
    __DATA__
    #: Hello.pm:10
    msgid "Hello, World!"
    msgstr "Hallo, Welt!"

    #: Hello.pm:11
    msgid "You have %quant(%1,piece) of mail."
    msgstr "Sie haben %quant(%1,Poststueck,Poststuecken)."

=head1 DESCRIPTION

This module implements a perl-based C<Gettext> parser for
B<Locale::Maketext>. It transforms all C<%1>, C<%2>, <%*>... sequences
to C<[_1]>, C<[_2]>, C<[_*]>, and so on.  It accepts either plain PO
file, or a MO file which will be handled with a pure-perl parser
adapted from Imacat's C<Locale::Maketext::Gettext>.

Since version 0.03, this module also looks for C<%I<function>(I<args...>)>
in the lexicon strings, and transform it to C<[I<function>,I<args...>]>.
Any C<%1>, C<%2>... sequences inside the I<args> will have their percent
signs (C<%>) replaced by underscores (C<_>).

The name of I<function> above should begin with a letter or underscore,
followed by any number of alphanumeric characters and/or underscores.
As an exception, the function name may also consist of a single asterisk
(C<*>) or pound sign (C<#>), which are C<Locale::Maketext>'s shorthands
for C<quant> and C<numf>, respectively.

As an additional feature, this module also parses MIME-header style
metadata specified in the null msgstr (C<"">), and add them to the
C<%Lexicon> with a C<__> prefix.  For example, the example above will
set C<__Content-Type> to C<text/plain; charset=iso8859-1>, without
the newline or the colon.

Any normal entry that duplicates a metadata entry takes precedence.
Hence, a C<msgid "__Content-Type"> line occurs anywhere should override
the above value.

=head1 OPTIONS

=head2 use_fuzzy

When parsing PO files, fuzzy entries (entries marked with C<#, fuzzy>)
are silently ignored.  If you wish to use fuzzy entries, specify a true
value to the C<_use_fuzzy> option:

    use Locale::Maketext::Lexicon {
        de => [Gettext => 'hello/de.mo'],
        _use_fuzzy => 1,
    };

=head2 allow_empty

When parsing PO files, empty entries (entries with C<msgstr "">) are
silently ignored.  If you wish to allow empty entries, specify a true
value to the C<_allow_empty> option:

    use Locale::Maketext::Lexicon {
        de => [Gettext => 'hello/de.mo'],
        _allow_empty => 1,
    };

=cut

my ($InputEncoding, $OutputEncoding, $DoEncoding);

sub input_encoding { $InputEncoding };
sub output_encoding { $OutputEncoding };

sub parse {
    my $self = shift;
    my (%var, $key, @ret);
    my @metadata;

    $InputEncoding = $OutputEncoding = $DoEncoding = undef;

    use Carp;
    Carp::cluck "Undefined source called\n" unless defined $_[0];

    # Check for magic string of MO files
    return parse_mo(join('', @_))
        if ($_[0] =~ /^\x95\x04\x12\xde/ or $_[0] =~ /^\xde\x12\x04\x95/);

    local $^W;  # no 'uninitialized' warnings, please.

    require Locale::Maketext::Lexicon;
    my $UseFuzzy = Locale::Maketext::Lexicon::option('use_fuzzy');
    my $AllowEmpty = Locale::Maketext::Lexicon::option('allow_empty');
    my $process = sub {
            if ( length($var{msgstr}) and ($UseFuzzy or !$var{fuzzy}) ) {
                push @ret, (map transform($_), @var{'msgid', 'msgstr'});
            }
            elsif ( $AllowEmpty ) {
                push @ret, (transform($var{msgid}), '');
            }
            push @metadata, parse_metadata($var{msgstr})
                if $var{msgid} eq '';
            %var = ();
    };

    # Parse PO files
    foreach (@_) {
        s/[\015\012]*\z//; # fix CRLF issues

        /^(msgid|msgstr) +"(.*)" *$/    ? do {  # leading strings
            $var{$1} = $2;
            $key = $1;
        } :

        /^"(.*)" *$/                    ? do {  # continued strings
            $var{$key} .= $1;
        } :

        /^#, +(.*) *$/                  ? do {  # control variables
            $var{$_} = 1 for split(/,\s+/, $1);
        } :

        /^ *$/ && %var                  ? do {  # interpolate string escapes
		$process->($_);
        } : ();
    }
    # do not silently skip last entry
    $process->() if keys %var != 0;

    push @ret, map { transform($_) } @var{'msgid', 'msgstr'}
        if length $var{msgstr};
    push @metadata, parse_metadata($var{msgstr})
        if $var{msgid} eq '';

    return {@metadata, @ret};
}

sub parse_metadata {
    return map {
        (/^([^\x00-\x1f\x80-\xff :=]+):\s*(.*)$/) ?
            ($1 eq 'Content-Type') ? do {
                my $enc = $2;
                if ($enc =~ /\bcharset=\s*([-\w]+)/i) {
                    $InputEncoding = $1 || '';
                    $OutputEncoding = Locale::Maketext::Lexicon::encoding() || '';
                    $InputEncoding = 'utf8' if $InputEncoding =~ /^utf-?8$/i;
                    $OutputEncoding = 'utf8' if $OutputEncoding =~ /^utf-?8$/i;
                    if ( Locale::Maketext::Lexicon::option('decode') and
                        (!$OutputEncoding or $InputEncoding ne $OutputEncoding)) {
                        require Encode::compat if $] < 5.007001;
                        require Encode;
                        $DoEncoding = 1;
                    }
                }
                ("__Content-Type", $enc);
            } : ("__$1", $2)
        : ();
    } split(/\r*\n+\r*/, transform(pop));
}

sub transform {
    my $str = shift;

    if ($DoEncoding and $InputEncoding) {
        $str = ($InputEncoding eq 'utf8')
            ? Encode::decode_utf8($str)
            : Encode::decode($InputEncoding, $str)
    }

    $str =~ s/\\([0x]..|c?.)/qq{"\\$1"}/eeg;

    if ($DoEncoding and $OutputEncoding) {
        $str = ($OutputEncoding eq 'utf8')
            ? Encode::encode_utf8($str)
            : Encode::encode($OutputEncoding, $str)
    }

    $str =~ s/([~\[\]])/~$1/g;
    $str =~ s/(?<![%\\])%([A-Za-z#*]\w*)\(([^\)]*)\)/[$1,~~~$2~~~]/g;
    $str = join('', map {
        /^~~~.*~~~$/ ? unescape(substr($_, 3, -3)) : $_
    } split(/(~~~.*?~~~)/, $str));
    $str =~ s/(?<![%\\])%(\d+|\*)/\[_$1]/g;

    return $str;
}

sub unescape {
    join(',', map {
        /^%(?:\d+|\*)$/ ? ("_" . substr($_, 1)) : $_
    } split(/,/, $_[0]));
}

# This subroutine was derived from Locale::Maketext::Gettext::readmo()
# under the Perl License; the original author is Yi Ma Mao (IMACAT).
sub parse_mo {
    my $content = shift;
    my $tmpl = (substr($content, 0, 4) eq "\xde\x12\x04\x95") ? 'V' : 'N';

    # Check the MO format revision number
    # There is only one revision now: revision 0.
    return if unpack($tmpl, substr($content, 4, 4)) > 0;

    my ($num, $offo, $offt);
    # Number of strings
    $num = unpack $tmpl, substr($content, 8, 4);
    # Offset to the beginning of the original strings
    $offo = unpack $tmpl, substr($content, 12, 4);
    # Offset to the beginning of the translated strings
    $offt = unpack $tmpl, substr($content, 16, 4);

    my (@metadata, @ret);
    for (0 .. $num - 1) {
        my ($len, $off, $stro, $strt);
        # The first word is the length of the string
        $len = unpack $tmpl, substr($content, $offo+$_*8, 4);
        # The second word is the offset of the string
        $off = unpack $tmpl, substr($content, $offo+$_*8+4, 4);
        # Original string
        $stro = substr($content, $off, $len);

        # The first word is the length of the string
        $len = unpack $tmpl, substr($content, $offt+$_*8, 4);
        # The second word is the offset of the string
        $off = unpack $tmpl, substr($content, $offt+$_*8+4, 4);
        # Translated string
        $strt = substr($content, $off, $len);

        # Hash it
        push @metadata, parse_metadata($strt) if $stro eq '';
        push @ret, (map transform($_), $stro, $strt) if length $strt;
    }

    return {@metadata, @ret};
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
