# See bottom of file for license and copyright information

#
# ======================================================================
# Abstract base class of a template parser.
#
# Create a new parser by calling:
#
# my $parser = Foswiki::Configure::TemplateParser::parser('MyTemplateParser');
# my $template = Foswiki::Configure::UI::getTemplateParser()->readTemplate('main');
# Foswiki::Configure::UI::getTemplateParser()->parse( $template, {
#			'contents' => 'ABC',
#		});
#
# Templates are used:
# - complete html page : page.tmpl
# - main part : main.tmpl
# - section part (in main content pane) : section.tmpl
# - authorization screen: authorize.tmpl
# - intro screen for "find more extensions": findextensionsintro.tmpl
# - extensions screen: extentions.tmpl
#
# Templates can be skinned just as with Foswiki templates.
# Pass url param 'skin' to the configure url:
# http://localhost/~foswiki/core/bin/configure?skin=android
# or set it programmatically:
# $parser->setSkin('android');

package Foswiki::Configure::TemplateParser;

use strict;
use warnings;
use Foswiki::Configure::Util ();

# Where to look for templates and resources
my $foswikiConfigureFilesDir;

=pod

parser ($parserId) -> $parser

Static parser factory. Param $parserId must point to existing TemplateParser subclass!

=cut

sub getParser {
    my ($id) = @_;

    my $class = 'Foswiki::Configure::TemplateParser::' . $id;
    my $parser;

    eval "use $class; \$parser = $class->new();";

    if ( !$parser && $@ ) {
        $parser = Foswiki::Configure::TemplateParser->new();
    }

    return $parser;
}

sub new {
    my $class = shift;

    my $this = bless( {}, $class );
    $this->{skin} = undef;

    $foswikiConfigureFilesDir = "$Foswiki::foswikiLibPath/Foswiki/Configure";

    return $this;
}

=pod

Sets the skin of the parser

=cut

sub setSkin {
    my ( $this, $skin ) = @_;

    $this->{skin} = $skin;
}

=pod

parse( $templateText, \%keyValues ) 

To be implemented by subclasses.

=cut

sub parse {

    #my $this = $_[0]
    #my $template = $_[1]
    #my $keyValueHash = $_[2]

}

=pod

_cleanupTemplateResidues( $templateText )

To be implemented by subclasses.

=cut

sub cleanupTemplateResidues {

    #my $this = $_[0]
    #my $template = $_[1]
}

=pod

readTemplate( $name ) => $text

Reads the contents of template file with name $name, where the name is either:
- 'page'
- 'main'
- 'section'

Example:
my $text = Foswiki::readTemplate('section');

=cut

sub readTemplate {
    my ( $this, $name ) = @_;

    my $template = $this->_getTemplate( $name, $this->{skin} );
    $template = $this->_getTemplate($name) unless $template;

    return $template;
}

sub _getTemplate {
    my ( $this, $name, $skin ) = @_;

    my $templateName = $this->_getTemplateFileName( $name, $skin );

    my $template =
      $this->getTemplate( $templateName,
        SCRIPTNAME => Foswiki::Configure::Util::getScriptName() );

    return $template;
}

sub _getTemplateFileName {
    my ( $this, $name, $skin ) = @_;

    my $skinPath = $skin ? '.' . $skin : '';
    return "$name$skinPath.tmpl";

}

sub getResource {
    my ( $this, $resource, %vars ) = @_;

    return $this->getFile( "$foswikiConfigureFilesDir/resources/", $resource,
        %vars );
}

sub getTemplate {
    my ( $this, $resource, %vars ) = @_;

    return $this->getFile( "$foswikiConfigureFilesDir/templates/", $resource,
        %vars );
}

sub getFile {
    my ( $this, $dir, $resource, %vars ) = @_;
    my $text = '';
    if ( open( my $F, '<', $dir . $resource ) ) {
        local $/;
        $text = <$F>;
        close($F);
        if ( $resource =~ /\.(js|css)$/ ) {

=pod
commenting out, this seems just 'to work'
            $text =~ s#/\*.*?\*/##g;
            $text =~ s#\s*//.*$##gm if ( $resource =~ /\.js$/ ); #
            $text =~ s/\t/ /g;
            $text =~ s/[ ]+$//gm;
            $text =~ s/^\s+//gm;
            $text =~ s/ +/ /g;
            $text =~ s/\s*\n/\n/gs;
=cut

        }
        $text =~ s/%INCLUDE\{(.*?)\}%/$this->getResource($1)/ges;
        while ( my ( $k, $v ) = each %vars ) {
            $text =~ s/\%$k%/$v/gs;
        }
    }
    else {
        print STDERR "Error loading resource $dir$resource: $!\n";
    }

    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
