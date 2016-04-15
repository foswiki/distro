# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::Plugin;
use v5.14;

use Foswiki::Plugins::JQueryPlugin::Plugins ();
use Foswiki::Func                           ();

use constant TRACE => 0;

use Moo;
use namespace::clean;
extends qw(Foswiki::AppObject);

has author => ( is => 'rw', default => 'unknown', );
has css => ( is => 'rw', default => sub { [] }, );
has debug =>
  ( is => 'ro', default => $Foswiki::cfg{JQueryPlugin}{Debug} || 0, );
has dependencies => ( is => 'rw', default => sub { [] }, );
has documentation => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $this = shift;
        my $documentation =
          $Foswiki::cfg{SystemWebName} . '.JQuery' . ucfirst( $this->name );

        $documentation =~ s/:://g;
        return $documentation;
    },
);
has homepage   => ( is => 'rw', default => 'unknown', );
has javascript => ( is => 'rw', default => sub { [] }, );
has name       => ( is => 'rw', default => $class, );
has puburl => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return
            $Foswiki::cfg{PubUrlPath} . '/'
          . $Foswiki::cfg{SystemWebName}
          . '/JQueryPlugin/plugins/'
          . lc( $_[0]->name );
    },
);
has summary => ( is => 'rw', );
has tags => ( is => 'rw', default => sub { [] }, );
has version  => ( is => 'rw', default => 'unknown', );
has idPrefix => ( is => 'rw', default => 'JQUERYPLUGIN', );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::Plugin

abstract class for a jQuery plugin

=cut

=begin TML

---++ ClassMethod new( $class, ... )

   * =$class=: Plugin class
   * =...=: additional properties to be added to the object. i.e. 
      * =author => 'pluginAuthor'= (default unknown)
      * =debug => 0 or 1= (default =$Foswiki::cfg{JQueryPlugin}{Debug}=)
      * =dependencies => []=
      * =documentation => 'pluginDocumentation'= (default JQuery&lt;Name>)
      * =homepage => 'pluginHomepage'= (default unknown)
      * =javascript => []
      * =name => 'pluginName'= (default unknown)
      * =puburl= => 'pubUrl'= (default =%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/pluginname=)
      * =summary => 'pluginSummary'= (default undefined)
      * =tags= => []
      * =version => 'pluginVersion'= (default unknown)

=cut

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    # backwards compatibility: the session param is deprecated now
    if ( ref( $_[0] ) =~ /^Foswiki/ ) {
        my ( $package, $file, $line ) = caller;

        # emit a deprecation warning
        print STDERR
"$package constructor called with deprecated session object in $file:$line\n"
          if TRACE;
        shift;    # ... it off the args
    }

    return $orig->( $class, @_ );
};

=begin TML

---++ ClassMethod init( )

add jQuery plugin to web and make sure all its dependencies 
are fulfilled. 

=cut

sub init {
    my $this = shift;

    return 0 if $this->isInit;
    $this->isInit(1);

    my $header = '';
    my $footer = '';

    # load all css
    foreach my $css ( @{ $this->css } ) {
        $header .= $this->renderCSS($css);
    }

    # load all javascript
    foreach my $js ( @{ $this->javascript } ) {
        $footer .= $this->renderJS($js);
    }

    # load any i18n messages
    if ( $this->i18n ) {
        $this->renderI18N( $this->i18n );
    }

    # gather dependencies
    my @dependencies =
      ('JQUERYPLUGIN::FOSWIKI');    # jquery.foswiki is in there by default

    # add i18n when required
    push @{ $this->dependencies }, "i18n" if $this->i18n;

    my $idPrefix = $this->idPrefix;
    foreach my $dep ( @{ $this->dependencies } ) {
        if ( $dep =~ /^($idPrefix|JQUERYPLUGIN|JavascriptFiles)/ )
        {  # SMELL: there are some jquery modules that depend on non-jquery code
            push @dependencies, $dep;
        }
        else {
            my $plugin =
              Foswiki::Plugins::JQueryPlugin::Plugins::createPlugin($dep);
            if ($plugin) {
                push @dependencies,
                  $plugin->{idPrefix} . '::' . uc( $plugin->{name} );
            }
            else {
                my $trace = '';

                # require Devel::StackTrace;
                # $trace = Devel::StackTrace->new()->as_string()."\n";

                print STDERR "ERROR: can't load plugin for $dep\n" . $trace;
            }
        }
    }

    Foswiki::Func::addToZone(
        'head', $idPrefix . '::' . uc( $this->name ),
        $header, join( ', ', @dependencies )
    );
    Foswiki::Func::addToZone(
        'script', $idPrefix . '::' . uc( $this->name ),
        $footer, join( ', ', @dependencies )
    );

    my $contextID = $this->name . 'Enabled';
    $contextID =~ s/\W//g;
    Foswiki::Func::getContext()->{$contextID} = 1;

    return 1;
}

sub renderCSS {
    my ( $this, $text ) = @_;

    $text =~ s/\.css$/.uncompressed.css/
      if $this->debug && $text !~ /(\.uncompressed|_src)\./;
    $text .= '?version=' . $this->version;
    $text =
        "<link rel='stylesheet' href='"
      . $this->puburl
      . "/$text' type='text/css' media='all' />\n";

    return $text;
}

sub renderJS {
    my ( $this, $text ) = @_;

    $text =~ s/\.js$/.uncompressed.js/
      if $this->debug && $text !~ /(\.uncompressed|_src)\./;
    $text .= '?version=' . $this->version;
    $text =
        "<script type='text/javascript' src='"
      . $this->puburl
      . "/$text'></script>\n";

    return $text;
}

sub renderI18N {
    my ( $this, $path ) = @_;

    # open matching localization file if it exists
    my $app     = $Foswiki::app;
    my $langTag = $app->i18n->language();

    my $messagePath = $path . '/' . $langTag . '.js';
    my $messageFile = $Foswiki::cfg{PubDir} . '/' . $messagePath;
    if ( -f $messageFile ) {
        my $text .=
"<script type='application/l10n' data-i18n-language='$langTag' data-i18n-namespace='"
          . uc( $this->name )
          . "' src='$Foswiki::cfg{PubUrlPath}/$messagePath' ></script>\n";
        Foswiki::Func::addToZone(
            'script', uc( $this->name ) . "::I8N",
            $text,    'JQUERYPLUGIN::I18N'
        );
    }
}

=begin TML

---++ ClassMethod getSummary()

returns the summary text for this plugin. this is either the =summary= property of the class or the
=summary= section of the plugin's documentation topic. 

=cut

sub getSummary {
    my $this = shift;

    my $summary = $this->summary;

    unless ( defined $summary ) {
        $summary = 'n/a';
        if ( $this->documentation ) {
            $summary =
              Foswiki::Func::expandCommonVariables( '%INCLUDE{"'
                  . $this->documentation
                  . '" section="summary" warn="off"}%' );
        }

        $this->summary($summary);
    }

    return $summary;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
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
