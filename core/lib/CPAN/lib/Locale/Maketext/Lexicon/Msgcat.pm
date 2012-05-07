package Locale::Maketext::Lexicon::Msgcat;
$Locale::Maketext::Lexicon::Msgcat::VERSION = '0.03';

use strict;

=head1 NAME

Locale::Maketext::Lexicon::Msgcat - Msgcat catalog parser Maketext

=head1 SYNOPSIS

    package Hello::I18N;
    use base 'Locale::Maketext';
    use Locale::Maketext::Lexicon {
        en => ['Msgcat', 'en_US/hello.pl.m'],
    };

    package main;
    my $lh = Hello::I18N->get_handle('en');
    print $lh->maketext(1,2);   # set 1, msg 2
    print $lh->maketext("1,2"); # same thing

=head1 DESCRIPTION

This module parses one or more Msgcat catalogs in plain text format,
and returns a Lexicon hash, which may be looked up either with a
two-argument form (C<$set_id, $msg_id>) or as a single string
(C<"$set_id,$msg_id">).

=head1 NOTES

All special characters (C<[>, C<]> and C<~>) in catalogs will be
escaped so they lose their magic meanings.  That means C<-E<gt>maketext>
calls to this lexicon will I<not> take any additional arguments.

=cut

sub parse {
    my $set = 0;
    my $msg = undef;
    my ($qr, $qq, $qc) = (qr//, '', '');
    my @out;

    # Set up the msgcat handler
    {
        no strict 'refs';
        *{Locale::Maketext::msgcat} = \&_msgcat;
    }

    # Parse *.m files; Locale::Msgcat objects and *.cat are not yet supported.
    foreach (@_) {
        s/[\015\012]*\z//;    # fix CRLF issues

        /^\$set (\d+)/
          ? do {              # set_id
            $set = int($1);
            push @out, $1, "[msgcat,$1,_1]";
          }
          :

          /^\$quote (.)/
          ? do {              # quote character
            $qc = $1;
            $qq = quotemeta($1);
            $qr = qr/$qq?/;
          }
          :

          /^(\d+) ($qr)(.*?)\2(\\?)$/
          ? do {              # msg_id and msg_str
            local $^W;
            push @out, "$set," . int($1);
            if ($4) {
                $msg = $3;
            }
            else {
                push @out, unescape($qq, $qc, $3);
                undef $msg;
            }
          }
          :

          (defined $msg and /^($qr)(.*?)\1(\\?)$/)
          ? do {    # continued string
            local $^W;
            if ($3) {
                $msg .= $2;
            }
            else {
                push @out, unescape($qq, $qc, $msg . $2);
                undef $msg;
            }
          }
          : ();
    }

    push @out, '' if defined $msg;

    return {@out};
}

sub _msgcat {
    my ($self, $set_id, $msg_id, @args) = @_;
    return $self->maketext(int($set_id) . ',' . int($msg_id), @args);
}

sub unescape {
    my ($qq, $qc, $str) = @_;
    $str =~ s/(\\([ntvbrf\\$qq]))/($2 eq $qc) ? $qc : eval qq("$1")/e;
    $str =~ s/([\~\[\]])/~$1/g;
    return $str;
}

1;

=head1 SEE ALSO

L<Locale::Maketext>, L<Locale::Maketext::Lexicon>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2002, 2003, 2004, 2007 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

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

=cut
