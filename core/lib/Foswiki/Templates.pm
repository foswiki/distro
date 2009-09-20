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
use Assert;

require Foswiki::Attrs;

=begin TML

---++ ClassMethod new ( $session )

Constructor. Creates a new template database object.
   * $session - session (Foswiki) object

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    $this->{VARS} = { sep => ' | ' };

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
    $text =~ /%TMPL\:P{(.*)}%/;
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
$tmpls->expandTemplate('"blah");
$tmpls->expandTemplate('context="view" then="sigh" else="humph"');
</verbatim>

=cut

sub expandTemplate {
    my ( $this, $params ) = @_;

    my $attrs = new Foswiki::Attrs($params);
    my $value = $this->tmplP($attrs);
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
would add considerably to the power of templates. There is already code
to do this in the MacrosPlugin.

=cut

sub tmplP {
    my ( $this, $params ) = @_;

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

    my $val = '';
    if ( exists( $this->{VARS}->{$template} ) ) {
        $val = $this->{VARS}->{$template};
        foreach my $p ( keys %$params ) {
            if ( $p eq 'then' || $p eq 'else' ) {
                $val =~ s/%$p%/$this->expandTemplate($1)/ge;
            }
            elsif ( defined( $params->{$p} ) ) {
                $val =~ s/%$p%/$params->{$p}/ge;
            }
        }
        $val =~ s/%TMPL:P{(.*?)}%/$this->expandTemplate($1)/ge;
    }

    return $val;
}

=begin TML

---++ ObjectMethod readTemplate ( $name, $skins, $web ) -> $text

Return value: expanded template text

Reads a template, constructing a candidate name for the template thus
   0 looks for file =$name.$skin.tmpl= (for each skin)
      0 in =templates/$web=
      0 in =templates=, look for
   0 looks for file =$name.tmpl=
      0 in =templates/$web=
      0 in =templates=, look for
   0 if a template is not found, tries in this order
      0 parse =$name= into a web name (default to $web) and a topic name and looks for this topic
      0 looks for topic =${skin}Skin${name}Template= 
         0 in $web (for each skin)
         0 in =Foswiki::cfg{SystemWebName}= (for each skin)
      0 looks for topic =${name}Template=
         0 in $web (for each skin)
         0 in =Foswiki::cfg{SystemWebName}= (for each skin)
In the event that the read fails (template not found, access permissions fail)
returns the empty string ''.

=$skin=, =$web= and =$name= are forced to an upper-case first character
when composing user topic names.

If template text is found, extracts include statements and fully expands them.
Also extracts template definitions and adds them to the
list of loaded templates, overwriting any previous definition.

=cut

sub readTemplate {
    my ( $this, $name, $skins, $web ) = @_;

    $this->{files} = ();

    # recursively read template file(s)
    my $text = _readTemplateFile( $this, $name, $skins, $web );

    # SMELL: unchecked implicit untaint?
    while ( $text =~ /%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/s ) {
        $text =~
s/%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/_readTemplateFile( $this, $1, $skins, $web )/geo;
    }

    # Kill comments, marked by %{ ... }%
    $text =~ s/%{.*?}%//sg;

    if ( !( $text =~ /%TMPL\:/s ) ) {

        # no template processing
        $text =~
          s|^(( {3})+)|"\t" x (length($1)/3)|geom;    # leading spaces to tabs
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
        elsif ( (/^DEF{[\s\"]*(.*?)[\"\s]*}%(.*)/s) && ($1) ) {

            # handle %TMPL:DEF{key}%
            if ($key) {
                $this->{VARS}->{$key} = $val;
            }
            $key = $1;

            # SMELL: unchecked implicit untaint?
            $val = $2;

        }
        elsif (/^END%[\n\r]*(.*)/s) {

            # handle %TMPL:END%
            $this->{VARS}->{$key} = $val;
            $key                  = '';
            $val                  = '';

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
    $result =~ s/(%TMPL\:P{.*?}%)/_expandTrivialTemplate( $this, $1)/geo;

    $result =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom; # leading spaces to tabs
    return $result;
}

# STATIC: Return value: raw template text, or '' if read fails
sub _readTemplateFile {
    my ( $this, $name, $skins, $web ) = @_;
    my $session = $this->{session};
    my $store   = $session->{store};

    $skins = $session->getSkin() unless defined($skins);

    #print STDERR "SKIN path is $skins\n";
    $web  ||= $session->{webName};
    $name ||= '';

    # SMELL: not i18n-friendly (can't have accented characters in skin name)
    # zap anything suspicious
    $name  =~ s/[^A-Za-z0-9_,.\/]//go;
    $skins =~ s/[^A-Za-z0-9_,.]//go;

    # if the name ends in .tmpl, then this is an explicit include from
    # the templates directory. No further searching required.
    if ( $name =~ /\.tmpl$/ ) {
        return Foswiki::readFile( $Foswiki::cfg{TemplateDir} . '/' . $name );
    }

    my $userdirweb  = $web;
    my $userdirname = $name;
    if ( $name =~ /^(.+)\.(.+?)$/ ) {

        # ucfirst taints if use locale is in force
        $userdirweb  = Foswiki::Sandbox::untaintUnchecked( ucfirst($1) );
        $userdirname = Foswiki::Sandbox::untaintUnchecked( ucfirst($2) );

        # if the name can be parsed into $web.$name, then this is an attempt
        # to explicit include that topic. No further searching required.
        if (
            validateTopic(
                $session,     $store, $session->{user},
                $userdirname, $userdirweb
            )
          )
        {
            return retrieveTopic( $store, $userdirweb, $userdirname );
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

        #TWikiCompatibility, need to test to see if there is a twiki.skin tmpl
        @templatePath =
          @{ $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{TemplatePath} };
    }

    # Search the $Foswiki::cfg{TemplatePath} for the skinned versions
    my @candidates;

    $nrskins = 0 if $nrskins < 0;
    foreach my $template (@templatePath) {
        for ( my $idx = 0 ; $idx <= $nrskins ; $idx++ ) {
            my $file    = $template;
            my $userdir = 0;

            # also need to do %PUBURL% etc.?
            # push the first time even if not modified
            my $skin     = $skinList[$idx] || '';
            my $webName  = $web            || '';
            my $tmplName = $name           || '';
            unless ( $file =~ m/.tmpl$/ ) {

                # Could also use $Skin, $Web, $Name to indicate uppercase
                $userdir  = 1;
                $skin     = ucfirst($skin);
                $webName  = $userdirweb;
                $tmplName = $userdirname;
            }
            $file =~ s/\$skin/$skin/geo;
            $file =~ s/\$web/$webName/geo;
            $file =~ s/\$name/$tmplName/geo;

            my ( $candidatename, $candidatevalidate, $candidateretrieve );

            if ($userdir) {

                # candidate in user directory
                my ( $web1, $name1 ) =
                  $session->normalizeWebTopicName( $web, $file );

                if (
                    validateTopic(
                        $session, $store, $session->{user}, $name1, $web1
                    )
                  )
                {
                    next
                      if (
                        defined(
                            $this->{files}
                              ->{ 'topic' . $session->{user}, $name1, $web1 }
                        )
                      );

                    #recursion prevention.
                    $this->{files}
                      ->{ 'topic' . $session->{user}, $name1, $web1 } = 1;
                    return retrieveTopic( $store, $web1, $name1 );
                }
            }
            else {
                if ( validateFile($file) ) {
                    next if ( defined( $this->{files}->{$file} ) );

                    #recursion prevention.
                    $this->{files}->{$file} = 1;
                    return Foswiki::readFile($file);
                }
            }
        }
    }

    # SMELL: should really
    #throw Error::Simple( 'Template '.$name.' was not found' );
    # instead of
    #print STDERR "Template $name could not be found anywhere\n";
    #Is Failing Silently the best option here?
    return '';
}

sub validateFile {
    my $file = shift;
    return -e $file;
}

sub validateTopic {
    my ( $session, $store, $user, $topic, $web ) = @_;
    return $store->topicExists( $web, $topic )
      && $session->security->checkAccessPermission( 'VIEW', $user, undef, undef,
        $topic, $web );
}

sub retrieveTopic {
    my ( $store, $web, $topic ) = @_;
    my ( $meta, $text ) = $store->readTopic( undef, $web, $topic, undef );
    return $text;
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
