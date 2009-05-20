package Locale::Maketext::Extract;

use strict;

$Locale::Maketext::Extract::VERSION = '0.08';

=head1 NAME

Locale::Maketext::Extract - Extract translatable strings from source

=head1 SYNOPSIS

    my $Ext = Locale::Maketext::Extract->new;
    $Ext->read_po('messages.po');
    $Ext->extract_file($_) for <*.pl>;
    $Ext->compile;
    $Ext->write_po('messages.po');

=head1 DESCRIPTION

This module can extract translatable strings from files, and write
them back to PO files.  It can also parse existing PO files and merge
their contents with newly extracted strings.

A command-line utility, L<xgettext.pl>, is installed with this module
as well.

Following formats of input files are supported:

=over 4

=item Perl source files

Valid localization function names are: C<translate>, C<maketext>,
C<gettext>, C<loc>, C<x>, C<_> and C<__>.

=item HTML::Mason

Strings inside C<E<lt>&|/lE<gt>I<...>E<lt>/&E<gt>> and
C<E<lt>&|/locE<gt>I<...>E<lt>/&E<gt>> are extracted.

=item Template Toolkit

Strings inside C<[%|l%]...[%END%]> or C<[%|loc%]...[%END%]>
are extracted.

=item Text::Template

Sentences between C<STARTxxx> and C<ENDxxx> are extracted individually.

=item Generic Template

Strings inside {{...}} are extracted.

=back

=head1 METHODS

=head2 Constructor

    new

=cut

sub new {
    my $class = shift;
    bless({ header => '', entries => {}, lexicon => {}, @_ }, $class);
}

=head2 Accessors

    header, set_header
    lexicon, set_lexicon, msgstr, set_msgstr
    entries, set_entries, entry, add_entry, del_entry
    clear

=cut

sub header { $_[0]{header} || _default_header() };
sub set_header { $_[0]{header} = $_[1] };

sub lexicon { $_[0]{lexicon} }
sub set_lexicon { $_[0]{lexicon} = $_[1] || {}; delete $_[0]{lexicon}{''}; }

sub msgstr { $_[0]{lexicon}{$_[1]} }
sub set_msgstr { $_[0]{lexicon}{$_[1]} = $_[2] }

sub entries { $_[0]{entries} }
sub set_entries { $_[0]{entries} = $_[1] || {} }

sub entry { @{$_[0]->entries->{$_[1]} || [] } }
sub add_entry { push @{$_[0]->entries->{$_[1]}}, $_[2] }
sub del_entry { delete $_[0]->entries->{$_[1]} }

sub clear {
    $_[0]->set_header;
    $_[0]->set_lexicon;
    $_[0]->set_entries;
}

=head2 PO File manipulation

    read_po
    write_po

=cut

sub read_po {
    my ($self, $file, $verbatim) = @_;
    my $header = '';

    local *LEXICON;
    open LEXICON, '<', $file or die $!;
    while (<LEXICON>) {
        (1 .. /^$/) or last;
        $header .= $_;
    }
    1 while chomp $header;

    $self->set_header("$header\n");

    require Locale::Maketext::Lexicon::Gettext;
    my $lexicon = Locale::Maketext::Lexicon::Gettext->parse($_, <LEXICON>);

    $self->set_lexicon(
        $verbatim ? { map _to_gettext($_), %$lexicon } : $lexicon
    );
    close LEXICON;
}

sub write_po {
    my ($self, $file, $add_format) = @_;

    local *LEXICON;
    open LEXICON, '>', $file or die "Can't write to $file$!\n";

    print LEXICON $self->header;

    foreach my $msgid ($self->msgids) {
        $self->normalize_space($msgid);
        print LEXICON "\n";
        print LEXICON $self->msg_positions($msgid);
        print LEXICON $self->msg_variables($msgid);
        print LEXICON $self->msg_format($msgid) if $add_format;
        print LEXICON $self->msg_out($msgid);
    }
}

=head2 Extraction

    extract
    extract_file

=cut

use constant NUL  => 0;
use constant BEG  => 1;
use constant PAR  => 2;
use constant QUO1 => 3;
use constant QUO2 => 4;
use constant QUO3 => 5;
sub extract {
    my $self = shift;
    my $file = shift;
    local $_ = shift;

    my $entries = $self->entries;
    my $line = 1; pos($_) = 0;

    # Text::Template
    if (/^STARTTEXT$/m and /^ENDTEXT$/m) {
        require HTML::Parser;
        require Lingua::EN::Sentence;

        {
            package MyParser;
            @MyParser::ISA = 'HTML::Parser';
            *{'text'} = sub {
                my ($self, $str, $is_cdata) = @_;
                my $sentences = Lingua::EN::Sentence::get_sentences($str) or return;
                $str =~ s/\n/ /g; $str =~ s/^\s+//; $str =~ s/\s+$//;
                $self->add_entry($str => [$file, $line]);
            };
        }   

        my $p = MyParser->new;
        while (m/\G((.*?)^(?:START|END)[A-Z]+$)/smg) {
            my ($str) = ($2);
            $line += ( () = ($1 =~ /\n/g) ); # cryptocontext!
            $p->parse($str); $p->eof; 
        }
        $_ = '';
    }

    # HTML::Mason
    $line = 1; pos($_) = 0;
    while (m!\G(.*?<&\|/l(?:oc)?(.*?)&>(.*?)</&>)!sg) {
        my ($vars, $str) = ($2, $3);
        $line += ( () = ($1 =~ /\n/g) ); # cryptocontext!
        $self->add_entry($str, [ $file, $line, $vars ]);
    }

    # Template Toolkit
    $line = 1; pos($_) = 0;
    while (m!\G(.*?\[%\s*\|l(?:oc)?(.*?)\s*%\](.*?)\[%\s*END\s*%\])!sg) {
        my ($vars, $str) = ($2, $3);
        $line += ( () = ($1 =~ /\n/g) ); # cryptocontext!
        $vars =~ s/^\s*\(//;
        $vars =~ s/\)\s*$//;
        $self->add_entry($str, [ $file, $line, $vars ]);
    }

    # Generic Template:
    $line = 1; pos($_) = 0;
    while (m/\G(.*?(?<!\{)\{\{(?!\{)(.*?)\}\})/sg) {
        my ($vars, $str) = ('', $2);
        $line += ( () = ($1 =~ /\n/g) ); # cryptocontext!
        $self->add_entry($str, [ $file, $line, $vars ]);
    }

    my $quoted = '(\')([^\\\']*(?:\\.[^\\\']*)*)(\')|(\")([^\\\"]*(?:\\.[^\\\"]*)*)(\")';

    # Comment-based mark: "..." # loc
    $line = 1; pos($_) = 0;
    while (m/\G(.*?($quoted)[\}\)\],]*\s*\#\s*loc\s*$)/smog) {
        my $str = substr($2, 1, -1);
        $line += ( () = ( $1 =~ /\n/g ) );    # cryptocontext!
        $str  =~ s/\\(["'])/$1/g;
        $self->add_entry($str, [ $file, $line, '' ]);
    }

    # Comment-based pair mark: "..." => "..." # loc_pair
    $line = 1; pos($_) = 0;
    while (m/\G(.*?(\w+)\s*=>\s*($quoted)[\}\)\],]*\s*\#\s*loc_pair\s*$)/smg) {
        my $key = $2;
        my $val = substr($3, 1, -1);
        $line += ( () = ( $1 =~ /\n/g ) );    # cryptocontext!
        $key  =~ s/\\(["'])/$1/g;
        $val  =~ s/\\(["'])/$1/g;
        $self->add_entry($key, [ $file, $line, '' ]);
        $self->add_entry($val, [ $file, $line, '' ]);
    }

    # Perl code:
    my ($state,$str,$vars,$quo)=(0);
    pos($_) = 0;
    my $orig = 1 + (() = ((my $__ = $_) =~ /\n/g));

    PARSER: {
        $_ = substr($_, pos($_)) if (pos($_));
        my $line = $orig - (() = ((my $__ = $_) =~ /\n/g));

        # maketext or loc or _
        $state == NUL && m/\b(translate|maketext|gettext|__?|loc|x)/gc
                      && do { $state = BEG; redo };
        $state == BEG && m/^([\s\t\n]*)/gc && redo;

        # begin ()
        $state == BEG && m/^([\S\(])\s*/gc
                      && do { $state = ( ($1 eq '(') ? PAR : NUL); redo };

        # begin or end of string
        $state == PAR  && m/^(\')/gc      && do { $state = $quo = QUO1;   redo };
        $state == QUO1 && m/^([^\']+)/gc  && do { $str  .= $1;            redo };
        $state == QUO1 && m/^\'/gc        && do { $state = PAR;           redo };

        $state == PAR  && m/^\"/gc        && do { $state = $quo = QUO2;   redo };
        $state == QUO2 && m/^([^\"]+)/gc  && do { $str  .= $1;            redo };
        $state == QUO2 && m/^\"/gc        && do { $state = PAR;           redo };

        $state == PAR  && m/^\`/gc        && do { $state = $quo = QUO3;   redo };
        $state == QUO3 && m/^([^\`]*)/gc  && do { $str  .= $1;            redo };
        $state == QUO3 && m/^\`/gc        && do { $state = PAR;           redo };

        # end ()
        $state == PAR && m/^\s*[\)]/gc && do {
            $state = NUL; 
            $vars =~ s/[\n\r]//g if ($vars);
            if ($quo == QUO1) {
                $str =~ s/\\([\\'])/$1/g; # normalize q strings
            }
            else {
                $str =~ s/(\\(?:[0x]..|c?.))/"qq($1)"/eeg; # normalize qq / qx strings
            }
            push @{$entries->{$str}}, [ $file, $line - (() = $str =~ /\n/g), $vars] if ($str);
            undef $str; undef $vars;
            redo;
        };

        # a line of vars
        $state == PAR && m/^([^\)]*)/gc && do { $vars .= "$1\n"; redo };
    }
}

sub extract_file {
    my ($self, $file) = @_;

    local($/, *FH);
    open FH, '<', $file or die $!;
    $self->extract($file => scalar <FH>);
    close FH;
}

=head2 Compilation

    compile
    normalize_space

=cut

sub compile {
    my ($self, $verbatim) = @_;
    my $entries = $self->entries;
    my $lexicon = $self->lexicon;

    foreach my $str (sort keys %$entries) {
        my $ostr    = $str;
        my $entry   = $entries->{$str};
        my $lexi    = $lexicon->{$ostr};

        $str  = _to_gettext($str, $verbatim);
        $lexi = _to_gettext($lexi, $verbatim);

        $lexicon->{$str} ||= '';
        next if $ostr eq $str;

        $lexicon->{$str} ||= $lexi;
        delete $entries->{$ostr}; delete $lexicon->{$ostr};
        $entries->{$str} = $entry;
    }

    return %$lexicon;
}

my %Escapes = map {("\\$_" => eval("qq(\\$_)"))} qw(t r f b a e);
sub normalize_space {
    my ($self, $msgid) = @_;
    my $nospace = $msgid;
    $nospace =~ s/ +$//;

    return unless (!$self->has_msgid($msgid) and $self->has_msgid($nospace));

    $self->set_msgstr(
        $msgid => $self->msgstr($nospace) .
                    (' ' x (length($msgid) - length($nospace)))
    );
}

=head2 Lexicon accessors

    msgids, has_msgid,
    msgstr, set_msgstr
    msg_positions, msg_variables, msg_format, msg_out

=cut

sub msgids { sort keys %{$_[0]{lexicon}} }
sub has_msgid { length $_[0]->msgstr($_[1]) }

sub msg_positions {
    my ($self, $msgid) = @_;
    my %files = (map { ( " $_->[0]:$_->[1]" => 1 ) } $self->entry($msgid));
    return join('', '#:', sort(keys %files), "\n");
}

sub msg_variables {
    my ($self, $msgid) = @_;
    my $out = '';

    my %seen;
    foreach my $entry ( grep { $_->[2] } $self->entry($msgid) ) {
        my ($file, $line, $var) = @$entry;
        $var =~ s/^\s*,\s*//; $var =~ s/\s*$//;
        $out .= "#. ($var)\n" unless !length($var) or $seen{$var}++;
    }

    return $out;
}

sub msg_format {
    my ($self, $msgid) = @_;
    return "#, perl-maketext-format\n" if $msgid =~ /%(?:\d|\w+\([^\)]*\))/;
    return '';
}

sub msg_out {
    my ($self, $msgid) = @_;

    return "msgid "  . _format($msgid) .
           "msgstr " . _format($self->msgstr($msgid));
}

=head2 Internal utilities

    _default_header
    _to_gettext
    _escape
    _format

=cut

sub _default_header {
    return << '.';
# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
# This file is distributed under the same license as the PACKAGE package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#
#, fuzzy
msgid ""
msgstr ""
"Project-Id-Version: PACKAGE VERSION\n"
"POT-Creation-Date: YEAR-MO-DA HO:MI+ZONE\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=CHARSET\n"
"Content-Transfer-Encoding: 8bit\n"
.
}

sub _to_gettext {
    my ($text, $verbatim) = @_;
    return '' unless defined $text;

    $text =~ s/\\/\\\\/g;
    $text =~ s/\"/\\"/g;

    while (my ($char, $esc) = each %Escapes) {
        $text =~ s/$esc/$char/g;
    }
    return $text if $verbatim;

    $text =~ s/((?<!~)(?:~~)*)\[_(\d+)\]/$1%$2/g;
    $text =~ s/((?<!~)(?:~~)*)\[([A-Za-z#*]\w*),([^\]]+)\]/$1%$2("""$3""")/g;
    $text = join('', map {
        /^""".*"""$/ ? _escape(substr($_, 3, -3)) : $_
    } split(/(""".*?""")/, $text));

    $text =~ s/~([\~\[\]])/$1/g;
    return $text;
}

sub _escape {
    my $text = shift;
    $text =~ s/\b_(\d+)/%$1/g;
    return $text;
}

sub _format {
    my $str = shift;
    $str =~ s/\\/\\\\/g;
    $str =~ s/"/\\"/g;
    return "\"$str\"\n" unless $str =~ /\n/;
    my $multi_line = ($str =~ /\n(?!\z)/);
    $str =~ s/\n/\\n"\n"/g;
    if ($str =~ /\n"$/) {
        chop $str;
    }
    else {
        $str .= "\"\n";
    }
    return $multi_line ? qq(""\n"$str) : qq("$str);
}

1;

=head1 ACKNOWLEDGMENTS

Thanks to Jesse Vincent for contributing to an early version of this
module.

Also to Alain Barbet, who effectively re-wrote the source parser with a
flex-like algorithm.

=head1 SEE ALSO

L<xgettext.pl>, L<Locale::Maketext>, L<Locale::Maketext::Lexicon>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2003, 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
