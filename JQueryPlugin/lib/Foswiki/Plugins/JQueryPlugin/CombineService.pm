# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::CombineService;

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::CombineService

combines the js and css files of a set of jQuery modules into a single js and css
file

=cut

use strict;
use warnings;

use constant TRACE => 0;    # toggle me

use Foswiki::Func  ();
use Digest::MD5    ();
use URI            ();
use Compress::Zlib ();
use Foswiki::Plugins::JQueryPlugin::Plugins();

use constant BASE_MODULES => qw(jquery ui migrate observer foswiki i18n);

=begin tml

---++ ClassMethod new()

constructs a singleton instance for this package

=cut

sub new {
    my $class = shift;

    my @combinedModules =
      split( /\s*,\s*/, $Foswiki::cfg{JQueryPlugin}{Combine}{Modules} // '' );

    push @combinedModules,
      split( /\s*,\s*/, $Foswiki::cfg{JQueryPlugin}{DefaultPlugins} )
      if $Foswiki::cfg{JQueryPlugin}{DefaultPlugins};

    push @combinedModules, "noconflict"
      if $Foswiki::cfg{JQueryPlugin}{NoConflict};

# SMELL: writeCompletePage will add strikeone nevertheless
#push @combinedModules, "JavascriptFiles/strikeone" if $Foswiki::cfg{Validation}{Method} eq 'strikeone';

    unshift @combinedModules, BASE_MODULES;

    my $this = bless(
        {
            cacheDir =>
"$Foswiki::cfg{PubDir}/$Foswiki::cfg{SystemWebName}/JQueryPlugin/cache",
            cacheUrl =>
"$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{SystemWebName}/JQueryPlugin/cache",
            combinedModules => \@combinedModules,
            exclude         => "^(NATSKIN|PATTERNSKIN)",
            @_
        },
        $class
    );

#_writeDebug("combinedModules=" . join( ", ", @{ $this->{combinedModules} } ) );

    return $this;
}

=begin TML

---++ ObjectMethod finish()

called when destroying this instance

=cut

sub finish {
    my $this = shift;

    undef $this->{combinedModules};
}

=begin TML

---++ ObjectMethod run() -> ($cssUrl, $jsUrl, $i18nUrl, $ids)

runs the actual file compression of all assets and returns the urls of the results.
the compressed files have been added to the head and script zones of the page.

=cut

sub run {
    my $this = shift;

    my $request = Foswiki::Func::getRequestObject();
    my $refresh = $request->param("refresh") // '';
    $this->clearCache() if $refresh =~ /^(on|css)$/;

    my ( $cssFiles, $jsFiles, $i18nFiles, $ids ) =
      $this->getFiles( $this->{combinedModules} );

    #print STDERR "jsFiles:\n".join("\n", @$jsFiles)."\n" if $jsFiles;
    #print STDERR "cssFiles:\n".join("\n", @$cssFiles)."\n" if $cssFiles;

    my $cssUrl  = $this->combineCssFiles($cssFiles);
    my $jsUrl   = $this->combineJsFiles($jsFiles);
    my $i18nUrl = $this->combineI18nFiles($i18nFiles);

    my $cls = join( " ", @$ids );
    if ( $Foswiki::Plugins::VERSION > 2.4 && $Foswiki::cfg{ObfuscateZoneIDs} ) {
        $cls =~ tr/N-ZA-Mn-za-m/A-Za-z/;    # obfuscate ids
    }

    if ($jsUrl) {
        my $code = <<"HERE";
<script class="script $cls" src='$jsUrl'></script>
HERE
        Foswiki::Func::addToZone( 'script', 'JQUERYPLUGIN', $code );

        foreach my $id (@$ids) {
            next if $id eq 'JQUERYPLUGIN';
            Foswiki::Func::addToZone( 'script', $id, "<!-- $id -->",
                "JQUERYPLUGIN" );
        }
    }

    if ($cssUrl) {
        my $code = <<"HERE";
<link class="head $cls" href="$cssUrl" rel="stylesheet" type="text/css" media="all">
HERE
        Foswiki::Func::addToZone( 'head', 'JQUERYPLUGIN', $code );

        foreach my $id (@$ids) {
            next if $id eq 'JQUERYPLUGIN';
            Foswiki::Func::addToZone( 'head', $id, "<!-- $id -->",
                "JQUERYPLUGIN" );
        }
    }

    if ($i18nUrl) {
        my $lang = $Foswiki::Plugins::SESSION->i18n->language();
        my $code = <<"HERE";
<script type="application/l10n" data-i18n-language="$lang" data-i18n-src="$i18nUrl" ></script>
HERE
        Foswiki::Func::addToZone( 'script', 'JQUERYPLUGIN::I18N', $code );
    }

    return ( $cssUrl, $jsUrl, $i18nUrl, $ids );
}

=begin TML

---++ ObjectMethod clearCache()

clears all css, js and gz files from the cache

=cut

sub clearCache {
    my $this = shift;

    my $num = unlink glob "$this->{cacheDir}/*.{js,css,gz}";
    _writeDebug("cleared $num files from cache");
}

=begin TML

---++ ObjectMethod handleRestCombine($session, $subject, $verb, $response)

testing handler for the combine service

=cut

sub handleRestCombine {
    my ( $this, $session, $subject, $verb, $response ) = @_;

    _writeDebug("called handleRestCombine()");

    $this->clearCache();

    my ( $cssUrl, $jsUrl, $i18nUrl, $ids ) = $this->run();

    my $request = Foswiki::Func::getRequestObject();
    my $quiet   = Foswiki::Func::isTrue( $request->param("quiet") );

    return "" if $quiet;

    return
        "cssUrl="
      . ( $cssUrl // 'undef' ) . "\n"
      . "jsUrl="
      . ( $jsUrl // 'undef' ) . "\n"
      . "i18nUrl="
      . ( $i18nUrl // 'undef' ) . "\n" . "ids="
      . join( ", ", @$ids ) . "\n\n";
}

=begin TML

---++ ObjectMethod getFiles($modules, $seen) -> ( $cssFiles, $jsFiles, $i18nFiles, $ids)

gathers all files that can be combined. css, js and i18n files are gathered individually.
The $i18nFiles is an array containing entries of the form

{
  namespace => "module name",
  file => $filePath
}

So the combined i18n file can properly attribute all translation strings to their namespace.

=cut

sub getFiles {
    my ( $this, $modules, $seen ) = @_;

    return () unless $modules;

    $seen //= {};
    $modules = [ split( /\s*,\s*/, $modules ) ] unless ref($modules);

    #_writeDebug("called getFiles(@$modules)");

    my @cssFiles  = ();
    my @jsFiles   = ();
    my @i18nFiles = ();
    my %ids       = ();

    my $pubDir =
        $Foswiki::cfg{PubDir} . '/'
      . $Foswiki::cfg{SystemWebName}
      . '/JQueryPlugin';

    foreach my $module (@$modules) {
        if ( $this->{exclude} && $module =~ /$this->{exclude}/ ) {
            _writeDebug("foreign module $module ... skipping");
            next;
        }
        $module =~ s/^JQUERYPLUGIN:://;
        $module = 'jquery' if $module eq 'JQUERYPLUGIN';

        if ( $seen->{ uc($module) } ) {

            #_writeDebug("... already seen $module");
            next;
        }
        $seen->{ uc($module) } = 1;

        #_writeDebug("reading $module");

        # SMELL: duplicates code in JQueryPlugin::Plugins
        if ( $module eq 'jquery' ) {
            my $jQuery = $Foswiki::cfg{JQueryPlugin}{JQueryVersion}
              // "jquery-2.2.4";
            push @jsFiles, "$pubDir/$jQuery.js";
            $ids{"JQUERYPLUGIN"} = 1;
            next;
        }

        if ( $module eq 'noconflict' ) {
            if ( $Foswiki::cfg{JQueryPlugin}{NoConflict} ) {
                push @jsFiles, "$pubDir/noconflict.js";
            }
            $ids{"JQUERYPLUGIN"} = 1;
            next;
        }

        if ( $module =~ /^JavascriptFiles/ ) {
            my $jsFile =
                $Foswiki::cfg{PubDir} . '/'
              . $Foswiki::cfg{SystemWebName} . '/'
              . $module . '.js';
            if ( -f $jsFile ) {
                push @jsFiles, $jsFile;
            }
            else {
                print STDERR "WARNING: couldn't find file for module $module\n";
            }
            $ids{$module} = 1;
            next;
        }

        my $plugin = Foswiki::Plugins::JQueryPlugin::Plugins::load($module);
        next unless $plugin;
        $plugin->{isLoaded} = 1;

        if ( $plugin->{dependencies} && @{ $plugin->{dependencies} } ) {

 #_writeDebug("... found dependencies ".join(", ", @{$plugin->{dependencies}}));
            my ( $thisCssFiles, $thisJsFiles, $thisI18nFiles, $thisIds ) =
              $this->getFiles( $plugin->{dependencies}, $seen );
            push @cssFiles, @$thisCssFiles if $thisCssFiles && @$thisCssFiles;
            push @jsFiles,  @$thisJsFiles  if $thisJsFiles  && @$thisJsFiles;
            push @i18nFiles, @$thisI18nFiles
              if $thisI18nFiles && @$thisI18nFiles;
            if ($thisIds) {
                $ids{$_} = 1 foreach @$thisIds;
            }
        }
        else {
            #_writeDebug("... no dependencies for $module");
        }

        $ids{ "JQUERYPLUGIN::" . uc( $plugin->{name} ) } = 1;

        my $thisPubDir = _url2FileName( $plugin->{puburl} )
          || $pubDir . '/plugins/' . lc( $plugin->{name} );

        if ( $plugin->{css} ) {
            foreach my $css ( @{ $plugin->{css} } ) {
                push @cssFiles, "$thisPubDir/$css";
            }
        }
        if ( $plugin->{javascript} ) {
            foreach my $js ( @{ $plugin->{javascript} } ) {
                push @jsFiles, "$thisPubDir/$js";
            }
        }

        my $i18nPath = $plugin->{i18n};
        if ($i18nPath) {
            my $lang = $Foswiki::Plugins::SESSION->i18n->language();
            my $msgFile =
              $Foswiki::cfg{PubDir} . '/' . $i18nPath . '/' . $lang . '.js';
            push @i18nFiles,
              {
                namespace => uc($module),
                file      => $msgFile
              }
              if -f $msgFile;
        }
    }

    # expand some common vars
    foreach my $file (@cssFiles) {
        next unless $file =~ /%/;
        $file = _expandCommonVariables($file);
        $file = _url2FileName($file);
    }
    foreach my $file (@jsFiles) {
        next unless $file =~ /%/;
        $file = _expandCommonVariables($file);
        $file = _url2FileName($file);
    }

    #_writeDebug("... done getFiles");
    return ( \@cssFiles, \@jsFiles, \@i18nFiles, [ keys %ids ] );
}

=begin TML

---++ ObjectMethod combineCssFiles($files) -> $urlPath

combines all css files into one and creates a .css and a .css.gz
file in the cache.

=cut

sub combineCssFiles {
    my ( $this, $files ) = @_;

    return unless $files && scalar(@$files);
    _writeDebug("called combineCssFiles(@$files)");

    my $fileName = _md5($files) . '.css';
    my $urlPath  = $this->{cacheUrl} . '/' . $fileName;
    my $filePath = $this->{cacheDir} . '/' . $fileName;

    if ( -e $filePath ) {
        _writeDebug("... found cached $filePath");
    }
    else {
        _writeDebug("... compressing files to $filePath");

        my $data = "";
        foreach my $file (@$files) {

            if ( -f $file ) {
                $data .= "\n" . $this->readCss($file);
            }
            else {
                print STDERR "WARNING: cannot read file $file\n";
            }
        }
        Foswiki::Func::saveFile( $filePath, $data );
        my $gzData = Compress::Zlib::memGzip($data);
        Foswiki::Func::saveFile( $filePath . '.gz', $gzData );
    }

    return $urlPath;
}

=begin TML

---++ ObjectMethod readCss($fileName) -> $data

reads and parses the css files. all contained url() and import()
expressions will be rewritten to fix their baseUrl according to the 
location of the red file

=cut

sub readCss {
    my ( $this, $fileName ) = @_;

    my $data    = "";
    my $baseUrl = _fileName2Url($fileName);

    #_writeDebug("called readCss($fileName), baseUrl=$baseUrl");

    $data = Foswiki::Func::readFile($fileName);
    $data =~ s/url\(["']?(.*?)["']?\)/"url("._rewriteUrl($1, $baseUrl).")"/ge;
    $data =~
s/\@import +url\(["']?(.*?)["']?\);/$this->readCss(_url2FileName(_rewriteUrl($1, $baseUrl)))/ge;

    return $data;
}

=begin TML

---++ ObjectMethod combineJsFiles($files) -> $urlPath

combines all js files into one and creates a .js and .js.gz file in the cache

=cut

sub combineJsFiles {
    my ( $this, $files ) = @_;

    return unless $files && scalar(@$files);
    _writeDebug("called combineJsFiles(@$files)");

    my $fileName = _md5($files) . '.js';
    my $urlPath  = $this->{cacheUrl} . '/' . $fileName;
    my $filePath = $this->{cacheDir} . '/' . $fileName;

    if ( -e $filePath ) {
        _writeDebug("... found cached $filePath");
    }
    else {
        _writeDebug("... compressing files to $filePath");

        my $data = "";
        foreach my $file (@$files) {
            $data .= "\n" . Foswiki::Func::readFile($file);
        }
        Foswiki::Func::saveFile( $filePath, $data );
        my $gzData = Compress::Zlib::memGzip($data);
        Foswiki::Func::saveFile( $filePath . '.gz', $gzData );
    }

    return $urlPath;
}

=begin TML

---++ ObjectMethod combineI18nFiles($entries) -> $url

combines all i18n file entries and creates a combined i18n file

=cut

sub combineI18nFiles {
    my ( $this, $entries ) = @_;

    return unless $entries && scalar(@$entries);

    _writeDebug("called combineI18nFiles()");

    my @files = map { $_->{file} } @$entries;

    my $fileName = _md5( \@files ) . '.js';
    my $urlPath  = $this->{cacheUrl} . '/' . $fileName;
    my $filePath = $this->{cacheDir} . '/' . $fileName;

    if ( -e $filePath ) {
        _writeDebug("... found cached $filePath");
    }
    else {
        _writeDebug("... compressing files to $filePath");

        my @data = ();
        foreach my $entry (@$entries) {
            my $data = Foswiki::Func::readFile( $entry->{file} );
            $data =~ s/^\s+//;
            $data =~ s/\s+$//;
            next unless $data;
            push @data,
              "{ \"namespace\": \"$entry->{namespace}\", \"data\": $data}";
        }
        my $data = "[" . join( ", ", @data ) . "]";

        #print STDERR "i18n data=$data\n";
        _writeDebug("i18n data=$data");
        Foswiki::Func::saveFile( $filePath, $data );
        my $gzData = Compress::Zlib::memGzip($data);
        Foswiki::Func::saveFile( $filePath . '.gz', $gzData );
    }

    return $urlPath;
}

=begin TML

---++ StaticMethod _md5($files) -> $m5String

creates am md5 for all filenames in the list

=cut

sub _md5 {
    my $files = shift;

    _writeDebug("md5-ing @$files");
    return Digest::MD5::md5_hex(@$files);
}

=begin TML

---++ StaticMethod _url2FileName($url) -> $fileName

convers an url to a public asset to a fileName as stored
on the server

=cut

sub _url2FileName {
    my $url = shift;

    my $defaultUrlHost = $Foswiki::cfg{DefaultUrlHost};
    $defaultUrlHost =~ s/^https?:/https?:/;

    #_writeDebug("defaultUrlHost=$defaultUrlHost");

    my $fileName = $url;
    $fileName =~ s/^$defaultUrlHost//;
    $fileName =~ s/^$Foswiki::cfg{PubUrlPath}/$Foswiki::cfg{PubDir}/;
    $fileName =~ s/\?.*$//;

 #_writeDebug("converting url=$url to fileName=$fileName") if $url ne $fileName;

    return $fileName;
}

=begin TML

---++ StaticMethod _fileName2Url($fileName) -> $url

returns the url to a public asset 

=cut

sub _fileName2Url {
    my $fileName = shift;

    my $url = $fileName;
    $url =~ s/^$Foswiki::cfg{PubDir}/$Foswiki::cfg{PubUrlPath}/;

    return $url;
}

=begin TML

---++ StaticMethod _rewriteUrl($url, $baseUrl) -> $newUrl

rewrites relative urls using a new base

=cut

sub _rewriteUrl {
    my ( $url, $baseUrl ) = @_;

    return $url if $url =~ /^(data|https?):/;

    #_writeDebug("rewriteUrl($url, $baseUrl)");

    my $uri    = URI->new($url);
    my $newUrl = $uri->abs($baseUrl);

    #_writeDebug("... url=$url");

    return $newUrl;
}

=begin TML

---++ StaticMethod _writeDebug($msg)

prints a debug message to stderr. use TRACE constant to activate debug
output

=cut

sub _writeDebug {
    return unless TRACE;
    print STDERR "- CombineService - $_[0]\n";
}

=begin TML

---++ StaticMethod _expandCommonVariables()

lightweight expansion of some common variables, i.e. not
using Foswiki::Func::expandCommonVariables()= for performance reasons

=cut

sub _expandCommonVariables {
    my $text = shift;

    $text =~ s/\%PUBURLPATH\%/$Foswiki::cfg{PubUrlPath}/g;
    $text =~ s/\%SYSTEMWEB\%/$Foswiki::cfg{SystemWebName}/g;
    $text =~ s/\%USERSWEB\%/$Foswiki::cfg{UsersWebName}/g;
    $text =~ s/\%MAINWEB\%/$Foswiki::cfg{UsersWebName}/g;

    return $text;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2023-2026 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
