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

# Used for dynamic data only (Static should be
# pre-compressed - see the make_gz script).

eval "use IO::Compress::Gzip ();";
my $gzipAvail = !$@;

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

    no warnings 'once';
    my $template =
      $this->getTemplate( $templateName, RESOURCEURI => $Foswiki::resourceURI );

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

    return $this->getFile(
        "$foswikiConfigureFilesDir/templates/", $resource,
        -binmode => 0,
        %vars
    );
}

sub getFile {
    my ( $this, $dir, $resource, %vars ) = @_;

    my $zipok    = delete $vars{'-zipok'};
    my $wantEtag = delete $vars{'-etag'};
    my $binmode  = delete $vars{'-binmode'};

    $binmode =
      $resource =~ /\.(png|gif|ico|psd|jpe?g|tiff|ppm|pgm|pbm|pnm|img|svg|bmp)$/
      unless ( defined $binmode );

   # Serve static content from a pre-zipped resource file if it's available.
   # Note that these files can not have variables or INCLUDEs.  But don't panic.

    my $zipped;
    if ( $zipok && -f "$dir${resource}.gz" ) {
        $zipped = 1;
        $resource .= '.gz';
    }
    my $text    = '';
    my $dynamic = 0;
    my $reqlog  = $Foswiki::cfg{Configure}{LogDataRequests};
    $reqlog &&= $reqlog =~ /all/i || $vars{'-remote'};
    my $remote = delete $vars{'remote'};

    if ( open( my $F, '<', $dir . $resource ) ) {
        print STDERR sprintf(
            "Configure: %s %s%s (inode=%u) size=%u\n",
            ( $remote ? 'providing' : 'using' ),
            $dir, $resource, ( stat($F) )[ 1, 7 ]
        ) if ($reqlog);
        binmode $F if ( $binmode || $zipped );
        local $/;
        $text = <$F>;
        close($F);

        # Dynamic content requires a digest.
        # Static content can use a weak validator.
        # N.B. Vars are only handled at the top level in
        # one pass over the interpolated text.
        # the '?' hack is to fix URIs in styles.css - if it
        # is direct-mapped, it doesn't pass thru here.

        unless ( $binmode || $zipped ) {
            $dynamic += $text =~
s/%INCLUDE{(.*?)}%/$this->getResource($1, -binmode => $binmode)/ges;
            while ( my ( $k, $v ) = each %vars ) {
                if ( $k =~ /^\?/ ) {
                    $dynamic += ( $text =~ s/\Q$k\E/$v/gs );
                }
                else {
                    $dynamic += ( $text =~ s/\%$k\%/$v/gs );
                }
            }
        }
    }
    else {
        print STDERR
          sprintf( "Configure: Can't open resource or data file %s%s: $!\n",
            $dir, $resource )
          if ($reqlog);
        return $wantEtag ? ( $text, undef ) : $text;
    }

    # Nothing fancy unless caller knows about $wantEtag
    return $text unless ($wantEtag);

    # Produce etag based on the file actually used.

    my $etag = makeETag( $dir . $resource, ( $dynamic ? \$text : undef ) );

   # If zip requested but static file not available (hopefully, dynamic content)
   # zip the output stream if gzip is available.  Don't bother for tiny stuff.

    if ( $zipok && !$zipped && $gzipAvail && length($text) >= 2048 ) {
        print STDERR
          sprintf(
"Configure: File %s%s contents are static, .gz file not available.  Compressing every request.\n",
            $dir, $resource )
          if ( !$dynamic && $reqlog );
        my $data = $text;
        undef $text;
        no warnings 'once';
        IO::Compress::Gzip::gzip( \$data, \$text )
          or die "Unable to gzip $resource: $IO::Compress::Gzip::GzipError\n";
        $zipped = 1;
    }
    return ( $text, $etag, $zipped );
}

sub makeETag {
    my $file = shift;
    my $text = shift;

    # Generate an ETag
    # Optionally include digest of text content because of variable substitution
    # Validator is weak if just size/mtime, strong if includes digest

    my @s = stat $file;
    return undef unless (@s);

    my $tag = sprintf( '"%010u:%010u', $s[7], $s[9] );
    return 'W/' . $tag . '"' unless ( defined $text );

    require Digest::MD5;
    return $tag . ':' . Digest::MD5::md5_hex($$text) . '"';
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
