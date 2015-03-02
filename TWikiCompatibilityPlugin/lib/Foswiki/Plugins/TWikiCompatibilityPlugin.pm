# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Plugins::TWikiCompatibilityPlugin


=cut

package Foswiki::Plugins::TWikiCompatibilityPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

require Foswiki::Func;       # The plugins API
require Foswiki::Plugins;    # For the API version
use vars qw($debug $pluginName);
our $VERSION           = '1.12';
our $RELEASE           = '1.12';
our $SHORTDESCRIPTION  = 'Add TWiki personality to Foswiki';
our $NO_PREFS_IN_TOPIC = 1;

$TWiki::RELEASE = 'TWiki 4.2.3';
$pluginName     = 'TWikiCompatibilityPlugin';

=begin TML

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    #initialise the augmented template path
    augmentedTemplatePath();

    return 1;
}

=begin TML

---++ earlyInitPlugin()

If the TWiki web does not exist, change the request to the %SYSTEMWEB%

This may not be enough for Plugins that do have in topic preferences.

=cut

sub earlyInitPlugin {

    my $session = $Foswiki::Plugins::SESSION;
    _patchWebTopic( $session->{webName}, $session->{topicName} );

    #Map TWIKIWEB to SYSTEMWEB and MAINWEB to USERSWEB
    #TODO: should we test for existance and other things?
    Foswiki::Func::setPreferencesValue( 'TWIKIWEB', 'TWiki' );

    # Load TWiki::Func and TWiki::Plugins, for badly written plugins
    # which rely on them being there without using them first
    use TWiki;
    use TWiki::Func;
    use TWiki::Plugins;

    return;
}

sub _patchWebTopic {

    my ( $web, $topic ) = @_;

    return unless Foswiki::Func::isValidWebName($web);
    $web = Foswiki::Sandbox::untaintUnchecked($web);

    return unless Foswiki::Func::isValidTopicName($topic);
    $topic = Foswiki::Sandbox::untaintUnchecked($topic);

    if (   ( $web eq 'TWiki' )
        && ( !Foswiki::Func::topicExists( $web, $topic ) ) )
    {
        my $TWikiWebTopicNameConversion =
          $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
          {TWikiWebTopicNameConversion};
        $_[0] = $Foswiki::cfg{SystemWebName};
        if ( defined( $TWikiWebTopicNameConversion->{$topic} ) ) {
            $_[1] = $TWikiWebTopicNameConversion->{$topic};

            #print STDERR "converted to $topic";
        }
    }
    my $MainWebTopicNameConversion =
      $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
      {MainWebTopicNameConversion};
    if (   ( $web eq 'Main' )
        && ( defined( $MainWebTopicNameConversion->{$topic} ) ) )
    {
        $_[1] = $MainWebTopicNameConversion->{$topic};

        #print STDERR "converted to $topic";
    }
}

sub augmentedTemplatePath {

    #TWikiCompatibility, need to test to see if there is a twiki.skin tmpl
    #allow the user to set the compatibility tempalte path too
    unless (
        defined(
            $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{TemplatePath}
        )
      )
    {
        my @cfgTemplatePath = split( /\s*,\s*/, $Foswiki::cfg{TemplatePath} );
        my @templatePath = ();
        foreach my $path (@cfgTemplatePath) {
            push( @templatePath, $path );
            if ( $path =~ m/^(.*)\$name(.*)$/ ) {

                #SMELL: hardcoded foswiki and twiki
                push( @templatePath, "$1twiki$2" );
            }
        }
        $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{TemplatePath} =
          \@templatePath;
    }

    return @{ $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{TemplatePath} };
}

=pod

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

using the same simplistic mechanism as DistributedServersPlugin, we find all
the System and TWiki web pub URL's and make sure they actually exist. If not,
we look in the 'other' place, and modify them if that file does exist.
   * TODO: should really protect non-HTML src type url's from re-writing

=cut

sub NOT_postRenderingHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;

    # remove duplicated hostPath's
    #my $hostUrl = TWiki::Func::getUrlHost( );
    #$_[0] =~ s|($hostUrl)($hostUrl)|$1|g;

#    $_[0] =~ s/(.*)($Foswiki::cfg{PubUrlPath}\/)(TWiki|$Foswiki::cfg{SystemWebName})([^"']*)/$1.validatePubURL($2, $3, $4)/ge;
    $_[0] =~
s/(.*)($Foswiki::cfg{PubUrlPath}\/)([^"'\/]*)([^"'<]*)/$1.validatePubURL($2, $3, $4, $1)/gem;
}

sub validatePubURL {
    my ( $pubUrl, $web, $file ) = @_;
    print STDERR "validatePubURL($pubUrl, $web, $file)\n";
    my %map = (
        'TWiki'                      => $Foswiki::cfg{SystemWebName},
        $Foswiki::cfg{SystemWebName} => 'TWiki'
    );

    #TODO: make into a hash - and see if we can persist it for fastcgi etc..
    my $filePath = $Foswiki::cfg{PubDir} . '/' . $web . $file;
    unless ( -e $filePath ) {
        $web      = $map{$web};
        $filePath = $Foswiki::cfg{PubDir} . '/' . $web . $file;
        unless ( -e $filePath ) {
            print STDERR
"   validatePubURL($pubUrl, $web, $file) ($filePath) - can't find file in either $map{$web} or $web\n";
        }
    }
    return $pubUrl . $web . $file;
}

=pod

---++ renderWikiWordHandler($linkText, $hasExplicitLinkLabel, $web, $topic) -> $linkText
   * =$linkText= - the text for the link i.e. for =[<nop>[Link][blah blah]]=
     it's =blah blah=, for =BlahBlah= it's =BlahBlah=, and for [[Blah Blah]] it's =Blah Blah=.
   * =$hasExplicitLinkLabel= - true if the link is of the form =[<nop>[Link][blah blah]]= (false if it's ==<nop>[Blah]] or =BlahBlah=)
   * =$web=, =$topic= - specify the topic being rendered

Called during rendering, this handler allows the plugin a chance to change
the rendering of labels used for links.

Return the new link text.

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub renderWikiWordHandler {
    my ( $linkText, $hasExplicitLinkLabel, $web, $topic ) = @_;
    if ( $web eq 'TWiki' or $web eq 'Main' ) {
        _patchWebTopic( $_[2], $_[3] );
    }
    return $_[3] if $topic ne $_[3] and not $hasExplicitLinkLabel;
    return $linkText if $hasExplicitLinkLabel;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
