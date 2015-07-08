package Locale::Maketext::Extract;
$Locale::Maketext::Extract::VERSION = '1.00';
use strict;
use Locale::Maketext::Lexicon();

# ABSTRACT: Extract translatable strings from source


our %Known_Plugins = (
    perl    => 'Locale::Maketext::Extract::Plugin::Perl',
    yaml    => 'Locale::Maketext::Extract::Plugin::YAML',
    tt2     => 'Locale::Maketext::Extract::Plugin::TT2',
    text    => 'Locale::Maketext::Extract::Plugin::TextTemplate',
    mason   => 'Locale::Maketext::Extract::Plugin::Mason',
    generic => 'Locale::Maketext::Extract::Plugin::Generic',
    formfu  => 'Locale::Maketext::Extract::Plugin::FormFu',
    haml    => 'Locale::Maketext::Extract::Plugin::Haml',
);

sub new {
    my $class   = shift;
    my %params  = @_;
    my $plugins = delete $params{plugins}
        || { map { $_ => undef } keys %Known_Plugins };

    Locale::Maketext::Lexicon::set_option( 'keep_fuzzy' => 1 );
    my $self = bless(
        {   header           => '',
            entries          => {},
            compiled_entries => {},
            lexicon          => {},
            warnings         => 0,
            verbose          => 0,
            wrap             => 0,
            %params,
        },
        $class
    );
    $self->{verbose} ||= 0;
    die "No plugins defined in new()"
        unless $plugins;
    $self->plugins($plugins);
    return $self;
}


sub header { $_[0]{header} || _default_header() }
sub set_header { $_[0]{header} = $_[1] }

sub lexicon { $_[0]{lexicon} }
sub set_lexicon { $_[0]{lexicon} = $_[1] || {}; delete $_[0]{lexicon}{''}; }

sub msgstr { $_[0]{lexicon}{ $_[1] } }
sub set_msgstr { $_[0]{lexicon}{ $_[1] } = $_[2] }

sub entries { $_[0]{entries} }
sub set_entries { $_[0]{entries} = $_[1] || {} }

sub compiled_entries { $_[0]{compiled_entries} }
sub set_compiled_entries { $_[0]{compiled_entries} = $_[1] || {} }

sub entry { @{ $_[0]->entries->{ $_[1] } || [] } }
sub add_entry { push @{ $_[0]->entries->{ $_[1] } }, $_[2] }
sub del_entry { delete $_[0]->entries->{ $_[1] } }

sub compiled_entry { @{ $_[0]->compiled_entries->{ $_[1] } || [] } }
sub add_compiled_entry { push @{ $_[0]->compiled_entries->{ $_[1] } }, $_[2] }
sub del_compiled_entry { delete $_[0]->compiled_entries->{ $_[1] } }

sub plugins {
    my $self = shift;
    if (@_) {
        my @plugins;
        my %params = %{ shift @_ };

        foreach my $name ( keys %params ) {
            my $plugin_class = $Known_Plugins{$name} || $name;
            my $filename = $plugin_class . '.pm';
            $filename =~ s/::/\//g;
            local $@;
            eval {
                require $filename && 1;
                1;
            } or do {
                my $error = $@ || 'Unknown';
                print STDERR "Error loading $plugin_class: $error\n"
                    if $self->{warnings};
                next;
            };

            my $plugin
                = $params{$name}
                ? $plugin_class->new( $params{$name} )
                : $plugin_class->new;
            push @plugins, $plugin;
        }
        $self->{plugins} = \@plugins;
    }
    return $self->{plugins} || [];
}

sub clear {
    $_[0]->set_header;
    $_[0]->set_lexicon;
    $_[0]->set_comments;
    $_[0]->set_fuzzy;
    $_[0]->set_entries;
    $_[0]->set_compiled_entries;
}


sub read_po {
    my ( $self, $file ) = @_;
    print STDERR "READING PO FILE : $file\n"
        if $self->{verbose};

    my $header = '';

    local ( *LEXICON, $_ );
    open LEXICON, $file or die $!;
    while (<LEXICON>) {
        ( 1 .. /^$/ ) or last;
        $header .= $_;
    }
    1 while chomp $header;

    $self->set_header("$header\n");

    require Locale::Maketext::Lexicon::Gettext;
    my $lexicon  = {};
    my $comments = {};
    my $fuzzy    = {};
    $self->set_compiled_entries( {} );

    if ( defined($_) ) {
        ( $lexicon, $comments, $fuzzy )
            = Locale::Maketext::Lexicon::Gettext->parse( $_, <LEXICON> );
    }

    # Internally the lexicon is in gettext format already.
    $self->set_lexicon( { map _maketext_to_gettext($_), %$lexicon } );
    $self->set_comments($comments);
    $self->set_fuzzy($fuzzy);

    close LEXICON;
}

sub msg_comment {
    my $self    = shift;
    my $msgid   = shift;
    my $comment = $self->{comments}->{$msgid};
    return $comment;
}

sub msg_fuzzy {
    return $_[0]->{fuzzy}{ $_[1] } ? ', fuzzy' : '';
}

sub set_comments {
    $_[0]->{comments} = $_[1];
}

sub set_fuzzy {
    $_[0]->{fuzzy} = $_[1];
}


sub write_po {
    my ( $self, $file, $add_format_marker ) = @_;
    print STDERR "WRITING PO FILE : $file\n"
        if $self->{verbose};

    local *LEXICON;
    open LEXICON, ">$file" or die "Can't write to $file$!\n";

    print LEXICON $self->header;

    foreach my $msgid ( $self->msgids ) {
        $self->normalize_space($msgid);
        print LEXICON "\n";
        if ( my $comment = $self->msg_comment($msgid) ) {
            my @lines = split "\n", $comment;
            print LEXICON map {"# $_\n"} @lines;
        }
        print LEXICON $self->msg_variables($msgid);
        print LEXICON $self->msg_positions($msgid);
        my $flags = $self->msg_fuzzy($msgid);
        $flags .= $self->msg_format($msgid) if $add_format_marker;
        print LEXICON "#$flags\n" if $flags;
        print LEXICON $self->msg_out($msgid);
    }

    print STDERR "DONE\n\n"
        if $self->{verbose};

}


sub extract {
    my $self    = shift;
    my $file    = shift;
    my $content = shift;

    local $@;

    my ( @messages, $total, $error_found );
    $total = 0;
    my $verbose = $self->{verbose};

    my @plugins = $self->_plugins_specifically_for_file($file);

    # If there's no plugin which can handle this file
    # specifically, fall back trying with all known plugins.
    @plugins = @{ $self->plugins } if not @plugins;

    foreach my $plugin (@plugins) {
        pos($content) = 0;
        my $success = eval { $plugin->extract($content); 1; };
        if ($success) {
            my $entries = $plugin->entries;
            if ( $verbose > 1 && @$entries ) {
                push @messages,
                      "     - "
                    . ref($plugin)
                    . ' - Strings extracted : '
                    . ( scalar @$entries );
            }
            for my $entry (@$entries) {
                my ( $string, $line, $vars ) = @$entry;
                $self->add_entry( $string => [ $file, $line, $vars ] );
                if ( $verbose > 2 ) {
                    $vars = '' if !defined $vars;

                    # pad string
                    $string =~ s/\n/\n               /g;
                    push @messages,
                        sprintf(
                        qq[       - %-8s "%s" (%s)],
                        $line . ':',
                        $string, $vars
                        ),
                        ;
                }
            }
            $total += @$entries;
        }
        else {
            $error_found++;
            if ( $self->{warnings} ) {
                push @messages,
                      "Error parsing '$file' with plugin "
                    . ( ref $plugin )
                    . ": \n $@\n";
            }
        }
        $plugin->clear;
    }

    print STDERR " * $file\n   - Total strings extracted : $total"
        . ( $error_found ? ' [ERROR ] ' : '' ) . "\n"
        if $verbose
        && ( $total || $error_found );
    print STDERR join( "\n", @messages ) . "\n"
        if @messages;

}

sub extract_file {
    my ( $self, $file ) = @_;

    local ( *FH );
    open FH, $file or die "Error reading from file '$file' : $!";
    my $content = do {
        local $/;
        scalar <FH>;
    };

    $self->extract( $file => $content );
    close FH;
}


sub compile {
    my ( $self, $entries_are_in_gettext_style ) = @_;
    my $entries = $self->entries;
    my $lexicon = $self->lexicon;
    my $comp    = $self->compiled_entries;

    while ( my ( $k, $v ) = each %$entries ) {
        my $compiled_key = (
            ($entries_are_in_gettext_style)
            ? $k
            : _maketext_to_gettext($k)
        );
        $comp->{$compiled_key}    = $v;
        $lexicon->{$compiled_key} = ''
            unless exists $lexicon->{$compiled_key};
    }

    return %$lexicon;
}


my %Escapes = map { ( "\\$_" => eval("qq(\\$_)") ) } qw(t r f b a e);

sub normalize_space {
    my ( $self, $msgid ) = @_;
    my $nospace = $msgid;
    $nospace =~ s/ +$//;

    return
        unless ( !$self->has_msgid($msgid) and $self->has_msgid($nospace) );

    $self->set_msgstr( $msgid => $self->msgstr($nospace)
            . ( ' ' x ( length($msgid) - length($nospace) ) ) );
}


sub msgids { sort keys %{ $_[0]{lexicon} } }

sub has_msgid {
    my $msg_str = $_[0]->msgstr( $_[1] );
    return defined $msg_str ? length $msg_str : 0;
}

sub msg_positions {
    my ( $self, $msgid ) = @_;
    my %files = ( map { ( " $_->[0]:$_->[1]" => 1 ) }
            $self->compiled_entry($msgid) );
    return $self->{wrap}
        ? join( "\n", ( map { '#:' . $_ } sort( keys %files ) ), '' )
        : join( '', '#:', sort( keys %files ), "\n" );
}

sub msg_variables {
    my ( $self, $msgid ) = @_;
    my $out = '';

    my %seen;
    foreach my $entry ( grep { $_->[2] } $self->compiled_entry($msgid) ) {
        my ( $file, $line, $var ) = @$entry;
        $var =~ s/^\s*,\s*//;
        $var =~ s/\s*$//;
        $out .= "#. ($var)\n" unless !length($var) or $seen{$var}++;
    }

    return $out;
}

sub msg_format {
    my ( $self, $msgid ) = @_;
    return ", perl-maketext-format"
        if $msgid =~ /%(?:[1-9]\d*|\w+\([^\)]*\))/;
    return '';
}

sub msg_out {
    my ( $self, $msgid ) = @_;
    my $msgstr = $self->msgstr($msgid);

    return "msgid " . _format($msgid) . "msgstr " . _format($msgstr);
}


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

sub _maketext_to_gettext {
    my $text = shift;
    return '' unless defined $text;

    $text =~ s{((?<!~)(?:~~)*)\[_([1-9]\d*|\*)\]}
              {$1%$2}g;
    $text =~ s{((?<!~)(?:~~)*)\[([A-Za-z#*]\w*),([^\]]+)\]}
              {"$1%$2(" . _escape($3) . ')'}eg;

    $text =~ s/~([\~\[\]])/$1/g;
    return $text;
}

sub _escape {
    my $text = shift;
    $text =~ s/\b_([1-9]\d*)/%$1/g;
    return $text;
}

sub _format {
    my $str = shift;

    $str =~ s/(?=[\\"])/\\/g;

    while ( my ( $char, $esc ) = each %Escapes ) {
        $str =~ s/$esc/$char/g;
    }

    return "\"$str\"\n" unless $str =~ /\n/;
    my $multi_line = ( $str =~ /\n(?!\z)/ );
    $str =~ s/\n/\\n"\n"/g;
    if ( $str =~ /\n"$/ ) {
        chop $str;
    }
    else {
        $str .= "\"\n";
    }
    return $multi_line ? qq(""\n"$str) : qq("$str);
}

sub _plugins_specifically_for_file {
    my ( $self, $file ) = @_;

    return () if not $file;

    my @plugins = grep {
        my $plugin     = $_;
        my @file_types = $plugin->file_types;
        my $is_generic
            = ( scalar @file_types == 1 and $file_types[0] eq '*' );
        ( not $is_generic and $plugin->known_file_type($file) );
    } @{ $self->plugins };

    return @plugins;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Locale::Maketext::Extract - Extract translatable strings from source

=head1 VERSION

version 1.00

=head1 SYNOPSIS

    my $Ext = Locale::Maketext::Extract->new;
    $Ext->read_po('messages.po');
    $Ext->extract_file($_) for <*.pl>;

    # Set $entries_are_in_gettext_format if the .pl files above use
    # loc('%1') instead of loc('[_1]')
    $Ext->compile($entries_are_in_gettext_format);

    $Ext->write_po('messages.po');

    -----------------------------------

    ### Specifying parser plugins ###

    my $Ext = Locale::Maketext::Extract->new(

        # Specify which parser plugins to use
        plugins => {

            # Use Perl parser, process files with extension .pl .pm .cgi
            perl => [],

            # Use YAML parser, process all files
            yaml => ['*'],

            # Use TT2 parser, process files with extension .tt2 .tt .html
            # or which match the regex
            tt2  => [
                'tt2',
                'tt',
                'html',
                qr/\.tt2?\./
            ],

            # Use My::Module as a parser for all files
            'My::Module' => ['*'],

        },

        # Warn if a parser can't process a file or problems loading a plugin
        warnings => 1,

        # List processed files
        verbose => 1,

    );

=head1 DESCRIPTION

This module can extract translatable strings from files, and write
them back to PO files.  It can also parse existing PO files and merge
their contents with newly extracted strings.

A command-line utility, L<xgettext.pl>, is installed with this module
as well.

The format parsers are loaded as plugins, so it is possible to define
your own parsers.

Following formats of input files are supported:

=over 4

=item Perl source files  (plugin: perl)

Valid localization function names are: C<translate>, C<maketext>,
C<gettext>, C<l>, C<loc>, C<x>, C<_> and C<__>.

For a slightly more accurate, but much slower Perl parser, you can  use the PPI
plugin. This does not have a short name (like C<perl>), but must be specified
in full.

=item HTML::Mason (Mason 1) and Mason (Mason 2) (plugin: mason)

HTML::Mason (aka Mason 1)
 Strings inside <&|/l>...</&> and <&|/loc>...</&> are extracted.

Mason (aka Mason 2)
Strings inside <% $.floc { %>...</%> or <% $.fl { %>...</%> or
<% $self->floc { %>...</%> or <% $self->fl { %>...</%> are extracted.

=item Template Toolkit (plugin: tt2)

Valid forms are:

  [% | l(arg1,argn) %]string[% END %]
  [% 'string' | l(arg1,argn) %]
  [% l('string',arg1,argn) %]

  FILTER and | are interchangeable
  l and loc are interchangeable
  args are optional

=item Text::Template (plugin: text)

Sentences between C<STARTxxx> and C<ENDxxx> are extracted individually.

=item YAML (plugin: yaml)

Valid forms are _"string" or _'string', eg:

    title: _"My title"
    desc:  _'My "quoted" string'

Quotes do not have to be escaped, so you could also do:

    desc:  _"My "quoted" string"

=item HTML::FormFu (plugin: formfu)

HTML::FormFu uses a config-file to generate forms, with built in
support for localizing errors, labels etc.

We extract the text after C<_loc: >:
    content_loc: this is the string
    message_loc: ['Max string length: [_1]', 10]

=item Generic Template (plugin: generic)

Strings inside {{...}} are extracted.

=back

=head1 METHODS

=head2 Constructor

    new()

    new(
        plugins   => {...},
        warnings  => 1 | 0,
        verbose   => 0 | 1 | 2 | 3,
    )

See L</"Plugins">, L</"Warnings"> and L</"Verbose"> for details

=head2 Plugins

    $ext->plugins({...});

Locale::Maketext::Extract uses plugins (see below for the list)
to parse different formats.

Each plugin can also specify which file types it can parse.

    # use only the YAML plugin
    # only parse files with the default extension list defined in the plugin
    # ie .yaml .yml .conf

    $ext->plugins({
        yaml => [],
    })


    # use only the Perl plugin
    # parse all file types

    $ext->plugins({
        perl => '*'
    })

    $ext->plugins({
        tt2  => [
            'tt',              # matches base filename against /\.tt$/
            qr/\.tt2?\./,      # matches base filename against regex
            \&my_filter,       # codref called
        ]
    })

    sub my_filter {
        my ($base_filename,$path_to_file) = @_;

        return 1 | 0;
    }

    # Specify your own parser
    # only parse files with the default extension list defined in the plugin

    $ext->plugins({
        'My::Extract::Parser'  => []
    })

By default, if no plugins are specified, it first tries to determine which
plugins are intended specifically for the file type and uses them. If no
such plugins are found, it then uses all of the builtin plugins, overriding
the file types specified in each.

=head3 Available plugins

=over 4

=item C<perl>    : L<Locale::Maketext::Extract::Plugin::Perl>

For a slightly more accurate but much slower Perl parser, you can use
the PPI plugin. This does not have a short name, but must be specified in
full, ie: L<Locale::Maketext::Extract::Plugin::PPI>

=item C<tt2>     : L<Locale::Maketext::Extract::Plugin::TT2>

=item C<yaml>    : L<Locale::Maketext::Extract::Plugin::YAML>

=item C<formfu>  : L<Locale::Maketext::Extract::Plugin::FormFu>

=item C<mason>   : L<Locale::Maketext::Extract::Plugin::Mason>

=item C<text>    : L<Locale::Maketext::Extract::Plugin::TextTemplate>

=item C<generic> : L<Locale::Maketext::Extract::Plugin::Generic>

=back

Also, see L<Locale::Maketext::Extract::Plugin::Base> for details of how to
write your own plugin.

=head2 Warnings

Because the YAML and TT2 plugins use proper parsers, rather than just regexes,
if a source file is not valid and it is unable to parse the file, then the
parser will throw an error and abort parsing.

The next enabled plugin will be tried.

By default, you will not see these errors.  If you would like to see them,
then enable warnings via new(). All parse errors will be printed to STDERR.

Also, if developing your own plugin, turn on warnings to see any errors that
result from loading your plugin.

=head2 Verbose

If you would like to see which files have been processed, which plugins were
used, and which strings were extracted, then enable C<verbose>. If no
acceptable plugin was found, or no strings were extracted, then the file
is not listed:

      $ext = Locale::Extract->new( verbose => 1 | 2 | 3);

   OR
      xgettext.pl ... -v           # files reported
      xgettext.pl ... -v -v        # files and plugins reported
      xgettext.pl ... -v -v -v     # files, plugins and strings reported

=head2 Accessors

    header, set_header
    lexicon, set_lexicon, msgstr, set_msgstr
    entries, set_entries, entry, add_entry, del_entry
    compiled_entries, set_compiled_entries, compiled_entry,
    add_compiled_entry, del_compiled_entry
    clear

=head2 PO File manipulation

=head3 method read_po ($file)

=head3 method write_po ($file, $add_format_marker?)

=head2 Extraction

    extract
    extract_file

=head2 Compilation

=head3 compile($entries_are_in_gettext_style?)

Merges the C<entries> into C<compiled_entries>.

If C<$entries_are_in_gettext_style> is true, the previously extracted entries
are assumed to be in the B<Gettext> style (e.g. C<%1>).

Otherwise they are assumed to be in B<Maketext> style (e.g. C<[_1]>) and are
converted into B<Gettext> style before merging into C<compiled_entries>.

The C<entries> are I<not> cleared after each compilation; use
C<->set_entries()> to clear them if you need to extract from sources with
varying styles.

=head3 normalize_space

=head2 Lexicon accessors

    msgids, has_msgid,
    msgstr, set_msgstr
    msg_positions, msg_variables, msg_format, msg_out

=head2 Internal utilities

    _default_header
    _maketext_to_gettext
    _escape
    _format
    _plugins_specifically_for_file

=head1 ACKNOWLEDGMENTS

Thanks to Jesse Vincent for contributing to an early version of this
module.

Also to Alain Barbet, who effectively re-wrote the source parser with a
flex-like algorithm.

=head1 SEE ALSO

L<xgettext.pl>, L<Locale::Maketext>, L<Locale::Maketext::Lexicon>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

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
