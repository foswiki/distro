package Locale::Maketext::Extract::Plugin::TT2;

use strict;
use base qw(Locale::Maketext::Extract::Plugin::Base);
use Template::Constants qw( :debug );
use Template::Parser;

=head1 NAME

Locale::Maketext::Extract::Plugin::TT2 - Template Toolkit format parser

=head1 SYNOPSIS

    $plugin = Locale::Maketext::Extract::Plugin::TT2->new(
        $lexicon            # A Locale::Maketext::Extract object
        @file_types         # Optionally specify a list of recognised file types
    )

    $plugin->extract($filename,$filecontents);

=head1 DESCRIPTION

Extracts strings to localise from Template Toolkit templates.

=head1 SHORT PLUGIN NAME

    tt2

=head1 VALID FORMATS

Valid formats are:

=over 4

=item [% |l(args) %]string[% END %]

=item [% 'string' | l(args) %]

=item [% l('string',args) %]

=back

l and loc are interchangable.

| and FILTER are interchangable.

=head1 KNOWN FILE TYPES

=over 4

=item .tt

=item .tt2

=item .html

=item .tt.*

=item .tt2.*

=back

=head1 REQUIRES

L<Template>

=head1 NOTES

=over 4

=item *

B<BEWARE> Using the C<loc> form can give false positives if you use the Perl parser
plugin on TT files.  If you want to use the C<loc> form, then you should
specify the file types that you want to the Perl plugin to parse, or enable
the default file types, eg:

   xgetext.pl -P perl ....        # default file types
   xgettext.pl -P perl=pl,pm  ... # specified file types

=item *

The string-to-be-localised must be a string, not a variable. We try not
to extract calls to your localise function which contain variables eg:

    l('string',arg)  # extracted
    l(var,arg)       # not extracted

This doesn't work for block filters, so don't do that. Eg:

    [%  FILTER l %]
       string [% var %]      # BAD!
    [% END %]

=item *

Getting the right line number is difficult in TT. Often it'll be a range
of lines, or it may be thrown out by the use of PRE_CHOMP or POST_CHOMP.  It will
always be within a few lines of the correct location.

=item *

If you have PRE/POST_CHOMP enabled by default in your templates, then you should
extract the strings using the same values.  In order to set them, you can
use the following wrapper script:

   #!/usr/bin/perl

   use Locale::Maketext::Extract::Run qw(xgettext);
   use Locale::Maketext::Extract::Plugin::TT2();

   %Locale::Maketext::Extract::Plugin::TT2::PARSER_OPTIONS = (
        PRE_CHOMP  => 1, # or 2
        POST_CHOMP => 1, # or 2

        # Also START/END_TAG, ANYCASE, INTERPOLATE, V1DOLLAR, EVAL_PERL
   );

   xgettext(@ARGV);

=back


=cut

# import strip_quotes
*strip_quotes
    = \&Locale::Maketext::Extract::Plugin::TT2::Directive::strip_quotes;

our %PARSER_OPTIONS;

#===================================
sub file_types {
#===================================
    return ( qw( tt tt2 html ), qr/\.tt2?\./ );
}

my %Escapes = map { ( "\\$_" => eval("qq(\\$_)") ) } qw(t n r f b a e);

#===================================
sub extract {
#===================================
    my $self = shift;
    my $data = shift;

    $Template::Directive::PRETTY = 1;
    my $parser =
        Locale::Maketext::Extract::Plugin::TT2::Parser->new(
               %PARSER_OPTIONS,
               FACTORY => 'Locale::Maketext::Extract::Plugin::TT2::Directive',
               FILE_INFO => 0,
        );
    _init_overrides($parser);

    $parser->{extracted} = [];

    $Locale::Maketext::Extract::Plugin::TT2::Directive::PARSER
        = $parser;    # hack
    $parser->parse($data)
        || die $parser->error;

    foreach my $entry ( @{ $parser->{extracted} } ) {
        $entry->[2] =~ s/^\((.*)\)$/$1/s;    # Remove () from vars
        $_ =~ s/\\'/'/gs                     # Unescape \'
            for @{$entry}[ 0, 2 ];
        $entry->[2] =~ s/\\(?!")/\\\\/gs;    # Escape all \ not followed by "
                                             # Escape argument lists correctly
        while ( my ( $char, $esc ) = each %Escapes ) {
            $entry->[2] =~ s/$esc/$char/g;
        }
        $entry->[1] =~ s/\D+.*$//;
        $self->add_entry(@$entry);
    }
}

#===================================
sub _init_overrides {
#===================================
    my $parser = shift;

    # Override the concatenation sub to return _ instead of .
    my $states = $parser->{STATES};
    foreach my $state ( @{$states} ) {
        if ( my $CAT_no = $state->{ACTIONS}{CAT} ) {
            my $CAT_rule_no
                = $states->[ $states->[$CAT_no]{GOTOS}{expr} ]->{DEFAULT};

            # override the TT::Grammar sub which cats two args
            $parser->{RULES}[ -$CAT_rule_no ][2] = sub {
                my $first  = ( $_[1] );
                my $second = ( $_[3] );
                if ( strip_quotes($first) && strip_quotes($second) ) {

                    # both are literal
                    return "'${first}${second}'";
                }
                else {

                    # at least one is an ident
                    return "$_[1] _ $_[3]";
                }
            };
            last;
        }
    }
}

#===================================
#===================================
package Locale::Maketext::Extract::Plugin::TT2::Parser;
#===================================
#===================================

use base 'Template::Parser';

# disabled location() because it was adding unneccessary text
# to filter blocks
#===================================
sub location {''}
#===================================

# Custom TT parser for Locale::Maketext::Lexicon
#
# Written by Andy Wardley http://wardley.org/
#
# 18 September 2008
#

#-----------------------------------------------------------------------
# custom directive generator to capture filters, variables and
# massage a few other elements to make life easy.
#-----------------------------------------------------------------------

#===================================
#===================================
package Locale::Maketext::Extract::Plugin::TT2::Directive;
#===================================
#===================================

use base 'Template::Directive';

our $PARSER;

#===================================
sub textblock {
#===================================
    my ( $class, $text ) = @_;
    $text =~ s/([\\'])/\\$1/g;
    return "'$text'";
}

#===================================
sub ident {
#===================================
    my ( $class, $ident ) = @_;
    return "NULL" unless @$ident;
    if ( scalar @$ident <= 2 && !$ident->[1] ) {
        my $var = $ident->[0];
        $var =~ s/^'(.+)'$/$1/;
        return $var;
    }
    else {
        my @source = @$ident;
        my @dotted;
        my $first = 1;
        my $first_literal;
        while (@source) {
            my ( $name, $args ) = splice( @source, 0, 2 );
            if ($first) {
                strip_quotes($name);
                my $first_arg = $args && @$args ? $args->[0] : '';
                $first_literal = strip_quotes($first_arg);
                $first--;
            }
            elsif ( !strip_quotes($name) && $name =~ /\D/ ) {
                $name = '$' . $name;
            }
            $name .= join_args($args);
            push( @dotted, $name );
        }
        if ( $first_literal
             && ( $ident->[0] eq "'l'" or $ident->[0] eq "'loc'" ) )
        {
            my $string = shift @{ $ident->[1] };
            strip_quotes($string);
            $string =~ s/\\\\/\\/g;
            my $args = join_args( $ident->[1] );
            push @{ $PARSER->{extracted} },
                [ $string, ${ $PARSER->{LINE} }, $args ];
        }
        return join( '.', @dotted );
    }
}

#===================================
sub text {
#===================================
    my ( $class, $text ) = @_;
    $text =~ s/\\/\\\\/g;
    return "'$text'";
}

#===================================
sub quoted {
#===================================
    my ( $class, $items ) = @_;
    return '' unless @$items;
    return ( $items->[0] ) if scalar @$items == 1;
    return '(' . join( ' _ ', @$items ) . ')';
}

#===================================
sub args {
#===================================
    my ( $class, $args ) = @_;
    my $hash = shift @$args;
    push( @$args, '{ ' . join( ', ', @$hash ) . ' }' )    # named params
        if @$hash;
    return $args;
}

#===================================
sub get {
#===================================
    my ( $class, $expr ) = @_;
    return $expr;
}

#===================================
sub filter {
#===================================
    my ( $class, $lnameargs, $block ) = @_;
    my ( $name,  $args,      $alias ) = @$lnameargs;
    $name = $name->[0];
    return ''
        unless $name eq "'l'"
            or $name eq "'loc'";
    if ( strip_quotes($block) ) {
        $block =~ s/\\\\/\\/g;
        $args = join_args( $class->args($args) );

        # NOTE: line number is at end of block, and can be a range
        my ($end) = ( ${ $PARSER->{LINE} } =~ /^(\d+)/ );
        my $start = $end;

        # rewind line count for newlines
        $start -= $block =~ tr/\n//;
        my $line = $start == $end ? $start : "$start-$end";
        push @{ $PARSER->{extracted} }, [ $block, $line, $args ];

    }
    return '';
}

# strips outer single quotes from a string (modifies original string)
# returns true if stripped, or false
#===================================
sub strip_quotes {
#===================================
    return scalar $_[0] =~ s/^'(.*)'$/$1/s;
}

#===================================
sub join_args {
#===================================
    my $args = shift;
    return '' unless $args && @$args;
    my @new_args = (@$args);
    for (@new_args) {
        s/\\\\/\\/g;
        if ( strip_quotes($_) ) {
            s/"/\\"/g;
            $_ = qq{"$_"};
        }
    }
    return '(' . join( ', ', @new_args ) . ')';
}

=head1 ACKNOWLEDGEMENTS

Thanks to Andy Wardley for writing the Template::Directive subclass which
made this possible.

=head1 SEE ALSO

=over 4

=item L<xgettext.pl>

for extracting translatable strings from common template
systems and perl source files.

=item L<Locale::Maketext::Lexicon>

=item L<Locale::Maketext::Extract::Plugin::Base>

=item L<Locale::Maketext::Extract::Plugin::FormFu>

=item L<Locale::Maketext::Extract::Plugin::Perl>

=item L<Locale::Maketext::Extract::Plugin::YAML>

=item L<Locale::Maketext::Extract::Plugin::Mason>

=item L<Locale::Maketext::Extract::Plugin::TextTemplate>

=item L<Locale::Maketext::Extract::Plugin::Generic>

=item L<Template::Toolkit>

=back

=head1 AUTHORS

Clinton Gormley E<lt>clint@traveljury.comE<gt>

Andy Wardley http://wardley.org

=head1 COPYRIGHT

Copyright 2002-2008 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

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

1;
