# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Templates

Support for Skin Template directives

=cut

=begin TML

The following tokens are supported by this language:

| %<nop>TMPL:P% | Instantiates a previously defined template |
| %<nop>TMPL:DEF% | Opens a template definition |
| %<nop>TMPL:END% | Closes a template definition |
| %<nop>TMPL:INCLUDE% | Includes another file of templates |

Note; the template cache does not get reset during initialisation, so
the haveTemplate test will return true if a template was loaded during
a previous run when used with mod_perl or speedycgi. Frustrating for
the template author, but they just have to switch off
the accelerators during development.

This is to all intents and purposes a singleton object. It could
easily be coverted into a true singleton (template manager).

=cut

package Foswiki::Templates;

use strict;
use warnings;
use Assert;

use Foswiki::Attrs ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Enable TRACE to get HTML comments in the output showing where templates
# (both DEFs and files) open and close. Will probably bork the output, so
# normally you should use it with a bin/view command-line.
use constant TRACE => 0;

my $MAX_EXPANSION_RECURSIONS = 999;

=begin TML

---++ ClassMethod new ( $session )

Constructor. Creates a new template database object.
   * $session - session (Foswiki) object

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    $this->{VARS}                = {};
    $this->{VARS}->{sep}->{text} = ' | ';
    $this->{expansionRecursions} = {};
    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{VARS};
    undef $this->{session};
    undef $this->{expansionRecursions};
}

=begin TML

---++ ObjectMethod haveTemplate( $name ) -> $boolean

Return true if the template exists and is loaded into the cache

=cut

sub haveTemplate {
    my ( $this, $template ) = @_;

    return exists( $this->{VARS}->{$template} );
}

# Expand only simple templates that can be expanded statically.
# Templates with conditions can only be expanded after the
# context is fully known.
sub _expandTrivialTemplate {
    my ( $this, $text ) = @_;

    # SMELL: unchecked implicit untaint?
    $text =~ m/%TMPL\:P\{(.*)}%/;
    my $attrs = new Foswiki::Attrs($1);

    # Can't expand context-dependant templates
    return $text if ( $attrs->{context} );
    return $this->tmplP($attrs);
}

=begin TML

---++ ObjectMethod expandTemplate( $params ) -> $string

Expand the template specified in the parameter string using =tmplP=.

Examples:
<verbatim>
$tmpls->expandTemplate("blah");
$tmpls->expandTemplate(context="view" then="sigh" else="humph");
</verbatim>

=cut

sub expandTemplate {
    my ( $this, $params ) = @_;

    my $attrs = new Foswiki::Attrs($params);
    no warnings 'recursion';
    my $value = $this->tmplP($attrs);
    use warnings 'recursion';
    return $value;
}

=begin TML

---+ ObjectMethod tmplP( $attrs ) -> $string

Return value expanded text of the template, as found from looking
in the register of template definitions. The attrs can contain a template
name in _DEFAULT, and / or =context=, =then= and =else= values.

Recursively expands any contained TMPL:P tags.

Note that it would be trivial to add template parameters to this,
simply by iterating over the other parameters (other than _DEFAULT, context,
then and else) and doing a s/// in the template for that parameter value. This
would add considerably to the power of templates.

=cut

sub tmplP {
    my ( $this, $params ) = @_;

    $params->remove('_RAW');    # don't need to iterate over _RAW
    my $template = $params->remove('_DEFAULT') || '';
    my $context  = $params->remove('context');
    my $then     = $params->remove('then');
    my $else     = $params->remove('else');
    if ($context) {
        $template = $then if defined($then);
        foreach my $id ( split( /\,\s*/, $context ) ) {
            unless ( $this->{session}->{context}->{$id} ) {
                $template = ( $else || '' );
                last;
            }
        }
    }

    return '' unless $template;

    $this->{expansionRecursions}->{$template} += 1;

    if ( $this->{expansionRecursions}->{$template} > $MAX_EXPANSION_RECURSIONS )
    {
        throw Foswiki::OopsException(
            'attention',
            def    => 'template_recursion',
            params => [$template]
        );
    }

    my $val = '';
    if ( exists( $this->{VARS}->{$template} ) ) {
        $val = $this->{VARS}->{$template}->{text};
        $val = "<!--$template-->\n$val<!--/$template-->\n" if (TRACE);

        foreach my $p ( keys %$params ) {
            if ( $p eq 'then' || $p eq 'else' ) {
                $val =~ s/%$p%/$this->expandTemplate($1)/ge;
            }
            elsif ( defined( $params->{$p} ) ) {
                $val =~ s/%$p%/$params->{$p}/ge;
            }
        }

        # process default values; this will clean up orphaned %p% params
        foreach my $p ( keys %{ $this->{VARS}->{$template}->{params} } ) {

            # resolve dynamic lookups such as %TMPL:DEF{"LIBJS" name="%id%"}%
            my $pvalue = $this->{VARS}->{$template}->{params}->{$p};
            $pvalue =~ s/\%(.*?)\%/$params->{$1}/g;
            $val    =~ s/%$p%/$pvalue/ge;
        }

        $val =~ s/%TMPL:PREV%/%TMPL:P{"$template:_PREV"}%/g;
        no warnings 'recursion';
        $val =~ s/%TMPL:P\{(.*?)\}%/$this->expandTemplate($1)/ge;
        use warnings 'recursion';
    }

    $this->{expansionRecursions}->{$template} -= 1;
    return $val;
}

=begin TML

---++ ObjectMethod readTemplate ( $name, %options ) -> $text

Reads a template, loading the definitions therein.

Return value: expanded template text

By default throws an OopsException if the template was not found or the 
access controls denied access.

%options include:
   * =skin= - skin name, 
   * =web= - web to search
   * =no_oops= - if true, will not throw an exception. Instead, returns undef.

If template text is found, extracts include statements and fully expands them.
Also extracts template definitions and adds them to the
list of loaded templates, overwriting any previous definition.

=cut

sub readTemplate {
    my ( $this, $name, %opts ) = @_;
    ASSERT($name) if DEBUG;
    my $skins = $opts{skins} || $this->{session}->getSkin();
    my $web   = $opts{web}   || $this->{session}->{webName};

    $this->{files} = ();

    # recursively read template file(s)
    my $text = _readTemplateFile( $this, $name, $skins, $web );

    # Check file was found
    unless ( defined $text ) {

        # if no_oops is given, return undef silently
        if ( $opts{no_oops} ) {
            return undef;
        }
        else {
            throw Foswiki::OopsException(
                'attention',
                def    => 'no_such_template',
                params => [
                    $name,

                    # More info for overridable templates
                    ( $name =~ m/^(view|edit)$/ ) ? $name . '_TEMPLATE' : ''
                ]
            );
        }
    }

    # SMELL: unchecked implicit untaint?
    while ( $text =~ m/%TMPL\:INCLUDE\{[\s\"]*(.*?)[\"\s]*\}%/s ) {
        $text =~ s/%TMPL\:INCLUDE\{[\s\"]*(.*?)[\"\s]*\}%/
          _readTemplateFile( $this, $1, $skins, $web ) || ''/ge;
    }

    if ( $text !~ /%TMPL\:/ ) {

        # no %TMPL's to process

        # SMELL: legacy - leading spaces to tabs, should not be required
        $text =~ s|^(( {3})+)|"\t" x (length($1)/3)|gem;

        return $text;
    }

    my $result = '';
    my $key    = '';
    my $val    = '';
    my $delim  = '';
    foreach ( split( /(%TMPL\:)/, $text ) ) {
        if (/^(%TMPL\:)$/) {
            $delim = $1;
        }
        elsif ( (/^DEF\{(.*?)\}%(.*)/s) && ($1) ) {

            # handle %TMPL:DEF{"key"}% and %TMPL:DEF{"key" p="1"}%
            if ($key) {

                # if the key is already defined, rename the existing
                # template to  key:_PREV
                my $new_value  = $val;
                my $prev_key   = $key;
                my $prev_value = $this->{VARS}->{$prev_key}->{text};
                $this->{VARS}->{$prev_key}->{text} = $new_value;
                while ($prev_value) {
                    $new_value  = $prev_value;
                    $prev_key   = "$prev_key:_PREV";
                    $prev_value = $this->{VARS}->{$prev_key}->{text};
                    $this->{VARS}->{$prev_key}->{text} = $new_value;
                }
            }

            my $attrs = new Foswiki::Attrs($1);
            $key = $attrs->{_DEFAULT};

            # store params in TMPL:DEF for later retrieval
            $attrs->remove('_DEFAULT');
            $attrs->remove('_RAW');
            foreach my $p ( keys %$attrs ) {
                $this->{VARS}->{$key}->{params}->{$p} = $attrs->{$p};
            }

            # SMELL: unchecked implicit untaint?
            $val = $2;

        }
        elsif (/^END%[\s\n\r]*(.*)/s) {

            # handle %TMPL:END%

            # if the key is already defined, rename the existing template to
            # key:_PREV
            my $new_value  = $val;
            my $prev_key   = $key;
            my $prev_value = $this->{VARS}->{$prev_key}->{text};
            $this->{VARS}->{$prev_key}->{text} = $new_value;
            while ($prev_value) {
                $new_value  = $prev_value;
                $prev_key   = "$prev_key:_PREV";
                $prev_value = $this->{VARS}->{$prev_key}->{text};
                $this->{VARS}->{$prev_key}->{text} = $new_value;
            }

            $key = '';
            $val = '';

            # SMELL: unchecked implicit untaint?
            $result .= $1;

        }
        elsif ($key) {
            $val .= "$delim$_";

        }
        else {
            $result .= "$delim$_";
        }
    }

    # handle %TMPL:P{"..."}% recursively
    $result =~ s/(%TMPL\:P\{.*?\}%)/_expandTrivialTemplate( $this, $1)/ge;

    # SMELL: legacy - leading spaces to tabs, should not be required
    $result =~ s|^(( {3})+)|"\t" x (length($1)/3)|gem;

    $this->saveTemplateToCache( '_complete', $name, $skins, $web, $result )
      if (TRACE);
    return $result;
}

# STATIC: Return value: raw template text, or undef if read fails
sub _readTemplateFile {
    my ( $this, $name, $skins, $web ) = @_;
    my $session = $this->{session};

    # zap anything suspicious
    $name =~ s/$Foswiki::regex{webTopicInvalidCharRegex}//g;

    # if the name ends in .tmpl, then this is an explicit include from
    # the templates directory. No further searching required.
    if ( $name =~ m/\.tmpl$/ ) {
        my $text =
          _decomment(
            _readFile( $session, "$Foswiki::cfg{TemplateDir}/$name" ) );
        $this->saveTemplateToCache( '_cache', $name, $skins, $web, $text )
          if (TRACE);
        return $text;
    }

    my $userdirweb  = $web;
    my $userdirname = $name;
    if ( $name =~ m/^(.+)\.(.+?)$/ ) {

        # ucfirst taints if use locale is in force
        $userdirweb  = Foswiki::Sandbox::untaintUnchecked( ucfirst($1) );
        $userdirname = Foswiki::Sandbox::untaintUnchecked( ucfirst($2) );

        # if the name can be parsed into $web.$name, then this is an attempt
        # to explicit include that topic. No further searching required.
        if ( $session->topicExists( $userdirweb, $userdirname ) ) {
            my $meta =
              Foswiki::Meta->load( $session, $userdirweb, $userdirname );

            # Check we are allowed access
            unless ( $meta->haveAccess( 'VIEW', $session->{user} ) ) {
                return $this->{session}->inlineAlert( 'alerts', 'access_denied',
                    "$userdirweb.$userdirname" );
            }
            my $text = $meta->text();
            $text = '' unless defined $text;

            $text =
                "<!--$userdirweb/$userdirname-->\n"
              . $text
              . "<!--/$userdirweb/$userdirname-->\n"
              if (TRACE);

            $text = _decomment($text);
            $this->saveTemplateToCache( '_cache', $name, $skins, $web, $text )
              if (TRACE);
            return $text;
        }
    }
    else {

        # ucfirst taints if use locale is in force
        $userdirweb =
          Foswiki::Sandbox::untaintUnchecked( ucfirst($userdirweb) );
        $userdirname =
          Foswiki::Sandbox::untaintUnchecked( ucfirst($userdirname) );
    }

    my @skinList = split( /\,\s*/, $skins );
    my $nrskins = $#skinList;

    my @templatePath = split( /\s*,\s*/, $Foswiki::cfg{TemplatePath} );
    if (
           ( $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} )
        && ( lc($name) eq 'foswiki' )
        && defined(
            $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{TemplatePath}
        )
      )
    {

        # TWikiCompatibility, need to test to see if there is a twiki.skin tmpl
        @templatePath =
          @{ $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{TemplatePath} };
    }

    # Search the $Foswiki::cfg{TemplatePath} for the skinned versions
    my @candidates = ();

    $nrskins = 0 if $nrskins < 0;

    my $nrtemplates = $#templatePath;

    for ( my $templateixd = 0 ; $templateixd <= $nrtemplates ; $templateixd++ )
    {
        for ( my $idx = 0 ; $idx <= $nrskins ; $idx++ ) {
            my $file    = $templatePath[$templateixd];
            my $userdir = 0;

            # also need to do %PUBURL% etc.?
            # push the first time even if not modified
            my $skin = $skinList[$idx] || '';

            # consider skin templates first
            # this is done by giving the template path with 'skin' in it
            # a higher sort priority (so a lower number: 0)
            my $isSkinned = ( $file =~ m/\$skin/ ? 0 : 1 );

            my $webName  = $web  || '';
            my $tmplName = $name || '';
            unless ( $file =~ m/.tmpl$/ ) {

                # Could also use $Skin, $Web, $Name to indicate uppercase
                $userdir = 1;

                # Again untainting when using ucfirst
                $skin    = Foswiki::Sandbox::untaintUnchecked( ucfirst($skin) );
                $webName = $userdirweb;
                $tmplName = $userdirname;
            }
            $file =~ s/\$skin/$skin/g;
            $file =~ s/\$web/$webName/g;
            $file =~ s/\$name/$tmplName/g;

# sort priority is:
# primary: if template path has 'skin' in it; so that skin templates are considered first
# secondary: the skin order number
# tertiary: the template path order number

            push(
                @candidates,
                {
                    primary   => $isSkinned,
                    secondary => $idx,
                    tertiary  => $templateixd,
                    file      => $file,
                    userdir   => $userdir,
                    skin      => $skin
                }
            );
        }
    }

    # sort
    @candidates = sort {
        foreach my $i (qw/primary secondary tertiary/)
        {
            if ( $a->{$i} < $b->{$i} ) {
                return -1;
            }
            elsif ( $a->{$i} > $b->{$i} ) {
                return 1;
            }
        }
        return 0;
    } @candidates;

    foreach my $candidate (@candidates) {
        my $file = $candidate->{file};

        if ( $candidate->{userdir} ) {

            my ( $web1, $name1 ) =
              $session->normalizeWebTopicName( $web, $file );

            if ( $session->topicExists( $web1, $name1 ) ) {

                # recursion prevention.
                next
                  if (
                    defined(
                        $this->{files}
                          ->{ 'topic' . $session->{user}, $name1, $web1 }
                    )
                  );
                $this->{files}->{ 'topic' . $session->{user}, $name1, $web1 } =
                  1;

                # access control
                my $meta = Foswiki::Meta->load( $session, $web1, $name1 );
                next unless $meta->haveAccess( 'VIEW', $session->{user} );

                my $text = $meta->text();
                $text = '' unless defined $text;

                $text = "<!--$web1.$name1-->\n$text<!--/$web1.$name1-->\n"
                  if (TRACE);

                $text = _decomment($text);
                $this->saveTemplateToCache( '_cache', $name, $skins, $web,
                    $text )
                  if (TRACE);
                return $text;
            }
        }
        elsif ( -e $file ) {
            next if ( defined( $this->{files}->{$file} ) );

            # recursion prevention.
            $this->{files}->{$file} = 1;

            my $text = _decomment( _readFile( $session, $file ) );
            $this->saveTemplateToCache( '_cache', $name, $skins, $web, $text )
              if (TRACE);
            return $text;
        }
    }

    # File was not found
    return undef;
}

sub _readFile {
    my ( $session, $fn ) = @_;
    my $F;

    if ( open( $F, '<:encoding(utf-8)', $fn ) ) {
        local $/;
        my $text = <$F>;
        close($F);

        $text = "<!--$fn-->\n$text<!--/$fn-->\n" if (TRACE);

        return $text;
    }
    else {
        $session->logger->log( 'warning', "$fn: $!" );
        return undef;
    }
}

sub _decomment {
    my $text = shift;

    return $text unless $text;

    # Kill comments, marked by %{ ... }%
    # (and remove whitespace either side of the comment)
    $text =~ s/\s*%\{.*?\}%\s*//sg;
    return $text;
}

#See http://wikiring.com/Blog/BlogEntry8?cat=WikiRing
#used for debugging templates, and later maybe for speed.
sub saveTemplateToCache {
    my ( $this, $cacheName, $name, $skins, $web, $tmplText ) = @_;
    $skins = '' unless ( defined($skins) );
    $web   = '' unless ( defined($web) );

    my $tmpl_cachedir = $Foswiki::cfg{TemplateDir} . $cacheName;
    mkdir($tmpl_cachedir) unless ( -e $tmpl_cachedir );
    my $filename = Foswiki::Sandbox::untaintUnchecked(
        $tmpl_cachedir . '/' . $name . '__' . $skins . '__' . $web . '.tmpl' );

    open( my $file, '>:encoding(utf-8)', $filename ) or do {
        die "Can't create file $filename - $!\n" if DEBUG;
        print STDERR "Can't create file $filename - $!\n";

        return;
    };
    print $file $tmplText;
    close($file);
}

#unused, but can be used for a speedup by caching the expanded Template
sub getTemplateFromCache {
    my ( $this, $name, $skins, $web ) = @_;
    $skins = '' unless ( defined($skins) );
    $web   = '' unless ( defined($web) );

    my $tmpl_cachedir = $Foswiki::cfg{TemplateDir} . '_cache';
    mkdir($tmpl_cachedir) unless ( -e $tmpl_cachedir );
    my $filename = Foswiki::Sandbox::untaintUnchecked(
        $tmpl_cachedir . '/' . $name . '__' . $skins . '__' . $web . '.tmpl' );

    if ( -e $filename ) {
        open( my $in_file, '<:encoding(utf-8)', $filename ) or return;
        local $/ = undef;    # set to read to EOF
        my $data = <$in_file>;
        close($in_file);
        return $data;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
