# See bottom of file for license and copyright information
package Foswiki::Render::HTML;

use strict;
use warnings;

use Foswiki       ();
use Foswiki::Meta ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod textarea( $params) -> $text

Generates a HTML textarea by expanding the 'textarea' template
definition in =templates/html.tmpl=. If the optional -template
parameter is provided, it is *appended* to the textarea template.

Called using same parameters as CGI::Template.

  my $text = Foswiki::Render::HTML::textarea(
      -class => 'foswikiInput',
      -disabled => 1,
      -template => ':special',
      );

This call will expand the TMPL:DEF{'textarea:special', substituting
the %CLASS% and %DISABLED% tokens.

=cut

sub textarea {
    my %ah = @_;

    my $template = 'textarea';
    $template .= $ah{'-template'} if ( defined $ah{'-template'} );

    #load the templates (relying on the system-wide skin path.)
    my $session = $Foswiki::Plugins::SESSION;
    $session->templates->readTemplate('html');
    my $tmpl = $session->templates->expandTemplate($template);

    return _replaceTokens(
        $tmpl,
        CLASS    => $ah{'-class'},
        COLS     => $ah{'-cols'} || 20,
        ID       => $ah{'-id'},
        NAME     => $ah{'-name'},
        ROWS     => $ah{'-rows'} || 4,
        STYLE    => $ah{'-style'},
        TEXTe    => $ah{'-default'},                          # Entity encode
        DISABLED => ( $ah{'-disabled'} ) ? 'disabled' : '',
        READONLY => ( $ah{'-readonly'} ) ? 'readonly' : '',
    );
}

=begin TML

---++ StaticMethod textfield( $params) -> $text

Generates a HTML input textfield by expanding the 'textfield' template
definition in =templates/html.tmpl=. If the optional -template
parameter is provided, it is *appended* to the textarea template.

Called using same parameters as CGI::Template.

  my $text = Foswiki::Render::HTML::textfield(
      -class => 'foswikiInput',
      -readonly => 1,
      -template => ':special',
      );

This call will expand the TMPL:DEF{'textarea:special', substituting
the %CLASS% and %READONLY% tokens.

=cut

sub textfield {
    my %ah = @_;

    my $template = 'textfield';
    $template .= $ah{'-template'} if ( defined $ah{'-template'} );

    my $disabled = ( $ah{'-disabled'} ) ? 'disabled' : '';
    my $readonly = ( $ah{'-readonly'} ) ? 'readonly' : '';

    #load the templates (relying on the system-wide skin path.)
    my $session = $Foswiki::Plugins::SESSION;
    $session->templates->readTemplate('html');
    my $tmpl = $session->templates->expandTemplate('textfield');

    return _replaceTokens(
        $tmpl,
        CLASS    => $ah{'-class'},
        ID       => $ah{'-id'},
        NAME     => $ah{'-name'},
        SIZE     => $ah{'-size'} || 20,
        STYLE    => $ah{'-style'},
        VALUEe   => $ah{'-value'},                            # Entity encode
        DISABLED => ( $ah{'-disabled'} ) ? 'disabled' : '',
        READONLY => ( $ah{'-readonly'} ) ? 'readonly' : '',
    );

}

=begin TML

---++ StaticMethod checkbox_group( $params) -> $text

Generates a HTML checkbox group by expanding the 'cbgroup:' templates
   * cbgroup:table - The table definition
   * cbgroup:row - A table row definition
   * cbgroup:checkbox - the checkbox

Called using same parameters as CGI::checkbox_group.   Currently only as subset
of checkbox_group parameters are supported.  rows is not supported.

=cut

sub checkbox_group {
    my %ah = @_;

    my $template = 'cbgroup';          # Template prefix
    my $name     = $ah{'-name'};       # Checkbox name
    my $cols     = $ah{'-columns'};    # number of columns
    my $label    = $ah{'-labels'};     # Map values to user labels
    my %checked;

    if ( $ah{'-defaults'} ) {
        %checked = map { $_ => 'checked' } @{ $ah{'-defaults'} };
    }

    my $attributes = $ah{'-attributes'};

    my $out  = '';
    my $rslt = '';

    #load the templates (relying on the system-wide skin path.)
    my $session = $Foswiki::Plugins::SESSION;
    $session->templates->readTemplate('html');
    my $cbtmpl = $session->templates->expandTemplate( $template . ':checkbox' );
    $cbtmpl =~ s/%NAME%/$name/;
    my $rowtmpl = $session->templates->expandTemplate( $template . ':row' );
    my $count   = 0;

    my $values = $ah{'-values'};

#<td><label><input type='checkbox' name='%NAME%' value='%VALUE%' %CHECKED% class='%CLASS%' title='%TITLE%'/>%LABEL%</label>
    foreach my $v (@$values) {
        my $v  = Foswiki::entityEncode($v);
        my $cb = $cbtmpl;
        $cb =~ s/%VALUE%/$v/;
        if ($label) {
            my $l = Foswiki::entityEncode( $label->{$v} );
            $cb =~ s/%LABEL%/$l/;
        }
        else {
            $cb =~ s/%LABEL%/$v/;
        }
        my $chk = ( exists( $checked{$v} ) ) ? 'checked' : '';
        my $attrs = $attributes->{$v};
        if ($attrs) {
            my $class = $attrs->{class};
            my $title = $attrs->{title};
            $chk = 'checked'
              if ( $attrs->{checked} && $attrs->{checked} eq 'checked' );
            $title = Foswiki::entityEncode($title);
            $cb =~ s/%CLASS%/$class/;
            $cb =~ s/%TITLE%/$title/;
        }
        $cb =~ s/%CHECKED%/$chk/;
        $cb =~ s/class='%CLASS%'//;
        $cb =~ s/class='%TITLE%'//;
        $out .= $cb;
        $count++;
        if ( $count == $cols ) {
            my $rowout = $rowtmpl;
            $rowout =~ s/%TEXT%/$out/;
            $rslt .= $rowout;
            $count = 0;
            $out   = '';
        }
    }
    if ($out) {    # any leftover?
        my $rowout = $rowtmpl;
        $rowout =~ s/%TEXT%/$out/;
        $rslt .= $rowout;
    }
    my $table = $session->templates->expandTemplate( $template . ':table' );
    $table =~ s/%TEXT%/$rslt/;
    return $table;

}

=begin TML

---++ PrivateMethod _replaceTokens( $templ, $params) -> $text

Process the passed hash of TOKEN => 'value', and replace each
token with the corresponding value in the template.

A special TOKEN name with suffix 'e' (lower case) causes the field
to be entity encoded.

=cut

sub _replaceTokens {
    my $tmpl  = shift;
    my %thash = @_;

    foreach my $token ( keys %thash ) {
        my $repl = ( defined $thash{$token} ) ? $thash{$token} : '';
        if ( substr( $token, -1, 1 ) eq 'e' ) {
            chop $token;
            $repl = Foswiki::entityEncode($repl);
        }
        $tmpl =~ s/id='%ID%'//       if ( $token eq 'ID'    && !length($repl) );
        $tmpl =~ s/style='%STYLE%'// if ( $token eq 'STYLE' && !length($repl) );
        $tmpl =~ s/%$token%/$repl/;
    }

    return $tmpl;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
