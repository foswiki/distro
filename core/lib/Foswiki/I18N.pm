# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::I18N

Support for strings translation and language detection.

=cut

package Foswiki::I18N;

use strict;
use warnings;
use Assert;
use Error qw(:try);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our $initialised;
our @initErrors;

=begin TML

---++ ClassMethod available_languages

Lists languages tags for languages available at Foswiki installation. Returns a
list containing the tags of the available languages.

__Note__: the languages available to users are determined in the =configure=
interface.

=cut

sub available_languages {

    my @available;

    while ( my ( $langCode, $langOptions ) =
        each %{ $Foswiki::cfg{Languages} } )
    {
        if ( $langOptions->{Enabled} ) {
            push( @available, _normalize_language_tag($langCode) );
        }
    }

    return @available;
}

# utility function: normalize language tags like ab_CD to ab-cd
# also renove any character there is not a letter [a-z] or a hyphen.
sub _normalize_language_tag {
    my $tag = shift;
    $tag = lc( $tag || '' );
    $tag =~ s/\_/-/g;
    $tag =~ s/[^a-z-]//g;
    return $tag;
}

sub _loadLexicon {
    my ( $lang, $dir ) = @_;

    $dir ||= $Foswiki::cfg{LocalesDir};

    my $langFile = "$dir/$lang.po";

    #print STDERR "langFile=$langFile\n";

    # Use the compressed version if it exists
    if ( $langFile =~ m/^(.*)\.po$/
        && -f "$1.mo" )
    {
        $langFile = "$1.mo";
    }
    if ( -f $langFile ) {
        unless (
            eval {
                Locale::Maketext::Lexicon->import(
                    { _decode => 1, $lang => [ Gettext => $langFile ] } );
                1;
            }
          )
        {
            push( @initErrors, "I18N - Error loading language $lang: $@\n" );
        }
    }
}

# initialisation block
BEGIN {

    # we only need to proceed if user wants internationalisation support
    return unless $Foswiki::cfg{UserInterfaceInternationalisation};

    # no languages enabled is the same as disabling
    # {UserInterfaceInternationalisation}
    my @languages = available_languages();
    return unless ( scalar(@languages) );

    # we first assume it's ok
    $initialised = 1;

    eval "use Locale::Maketext ()";
    if ($@) {
        $initialised = 0;
        push( @initErrors,
                "I18N: Couldn't load required perl module Locale::Maketext: "
              . $@
              . "\nInstall the module or turn off {UserInterfaceInternationalisation}"
        );
    }
    else {
        @Foswiki::I18N::ISA = ('Locale::Maketext');
    }

    unless ( $Foswiki::cfg{LocalesDir} && -e $Foswiki::cfg{LocalesDir} ) {
        push( @initErrors,
'I18N: {LocalesDir} not configured. Define it or turn off {UserInterfaceInternationalisation}'
        );
        $initialised = 0;
    }

    # dynamically build languages to be loaded according to admin-enabled
    # languages.
    eval "use Locale::Maketext::Lexicon{ en => [ 'Auto' ] } ;";
    if ($@) {
        $initialised = 0;
        push( @initErrors,
                "I18N - Couldn't load default English messages: $@\n"
              . "Install Locale::Maketext::Lexicon or turn off {UserInterfaceInternationalisation}"
        );
    }

    opendir( my $dh, "$Foswiki::cfg{LocalesDir}/" ) || next;
    my @subDirs =
      grep { !/^\./ && -d "$Foswiki::cfg{LocalesDir}/$_" } readdir $dh;
    closedir $dh;

    foreach my $lang (@languages) {
        _loadLexicon($lang);
        _loadLexicon( $lang, "$Foswiki::cfg{LocalesDir}/$_" ) foreach @subDirs;
    }
}

=begin TML

---++ ClassMethod new ( $session )

Constructor. Gets the language object corresponding to the current users
language. If $session is not a Foswiki object reference, just calls
Local::Maketext::new (the superclass constructor)

=cut

sub new {
    my $class = shift;
    my ($session) = @_;

    unless ( ref($session) && $session->isa('Foswiki') ) {

        # it's recursive
        return $class->SUPER::new(@_);
    }

    if (@initErrors) {
        foreach my $error (@initErrors) {
            $session->logger->log( $initialised ? 'warning' : 'error', $error );
        }
    }

    # guesses the language from the CGI environment
    # TODO:
    #   web/user/session setting must override the language detected from the
    #   browser.
    my $this;
    if ($initialised) {
        $session->enterContext('i18n_enabled');
        my $userLanguage = _normalize_language_tag(
            $session->{prefs}->getPreference('LANGUAGE') );
        if ($userLanguage) {
            $this = Foswiki::I18N->get_handle($userLanguage);
        }
        else {
            $this = Foswiki::I18N->get_handle();
        }
    }
    else {
        require Foswiki::I18N::Fallback;

        $this = new Foswiki::I18N::Fallback();

        # we couldn't initialise 'optional' I18N infrastructure, warn that we
        # can only use English if I18N has been requested with configure
        $session->logger->log( 'warning',
            'Could not load I18N infrastructure; falling back to English' )
          if $Foswiki::cfg{UserInterfaceInternationalisation};
    }

    # keep a reference to the session object
    $this->{session} = $session;

    # languages we know about
    $this->{enabled_languages} = { en => 'English' };
    $this->{checked_enabled} = undef;

    # what to do with failed translations (only needed when already initialised
    # and language is not English);
    if ( $initialised and ( $this->language ne 'en' ) ) {
        my $fallback_handle = Foswiki::I18N->get_handle('en');
        $this->fail_with(
            sub {
                shift;    # get rid of the handle
                return $fallback_handle->maketext(@_);
            }
        );
    }

    # finally! :-p
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
    undef $this->{enabled_languages};
    undef $this->{checked_enabled};
    undef $this->{session};
}

=begin TML

---++ ObjectMethod maketext( $text ) -> $translation

Translates the given string (assumed to be written in English) into the
current language, as detected in the constructor, and converts it into
a binary UTF-8 string.

Wraps around Locale::Maketext's maketext method, adding charset conversion
and checking.

Return value: translated string, or the argument itself if no translation is
found for thet argument.

=cut

sub maketext {
    my ( $this, $text, @args ) = @_;

    if ( $text =~ m/^_/ && $text ne '_language_name' ) {
        require CGI;
        import CGI();

        return CGI::span(
            { -class => 'foswikiAlert' },
            "Error: MAKETEXT arguments can't start with an underscore (\"_\")."
        );
    }

    my $result = '';
    try {
        $result = $this->SUPER::maketext( $text, @args );
        return $result;
    }
    catch Error with {
        my $e = shift;
        print STDERR
          "#### Error: MAKETEXT - String translation failed for \"$text\". "
          . $e->stringify()
          if DEBUG;
        return
"<span class='foswikiAlert'>ERROR: Translation failed, see server error log.</span>";
    }
}

=begin TML

---++ ObjectMethod language() -> $language_tag

Indicates the language tag of the current user's language, as detected from the
information sent by the browser. Returns the empty string if the language
could not be determined.

=cut

sub language {
    my $this = shift;

    return $this->language_tag();
}

=begin TML

---++ ObjectMethod enabled_languages() -> %languages

Returns an array with language tags as keys and language (native) names as
values, for all the languages enabled in this site. Useful for
listing available languages to the user.

=cut

sub enabled_languages {
    my $this = shift;

    unless ( $this->{checked_enabled} ) {
        _discover_languages($this);
    }

    $this->{checked_enabled} = 1;
    return $this->{enabled_languages};

}

# discovers the available language.
sub _discover_languages {
    my $this       = shift;
    my $cache_open = 0;

    #use the cache, if available
    if ( open LANGUAGE, '<', "$Foswiki::cfg{WorkingDir}/languages.cache" ) {
        $cache_open = 1;
        foreach my $line ( map { Foswiki::decode_utf8($_) } <LANGUAGE> ) {
            my ( $key, $name ) = split( '=', $line );

            # Filter on enabled languages
            next
              unless ( $Foswiki::cfg{Languages}{$key}
                && $Foswiki::cfg{Languages}{$key}{Enabled} );
            chop($name);
            _add_language( $this, $key, $name );
        }
    }
    else {

        # Rebuild the cache, filtering on enabled languages.
        $cache_open =
          open( LANGUAGE, '>', "$Foswiki::cfg{WorkingDir}/languages.cache" );
        foreach my $tag ( available_languages() ) {
            my $h = Foswiki::I18N->get_handle($tag);
            my $name = eval { $h->maketext("_language_name") } or next;
            print LANGUAGE Foswiki::encode_utf8("$tag=$name\n") if $cache_open;

            # Filter on enabled languages
            next
              unless ( $Foswiki::cfg{Languages}{$tag}
                && $Foswiki::cfg{Languages}{$tag}{Enabled} );
            _add_language( $this, $tag, $name );
        }
    }

    close LANGUAGE if $cache_open;
    $this->{checked_enabled} = 1;

}

# private utility method: add a pair tag/language name
sub _add_language {
    my ( $this, $tag, $name ) = @_;
    $this->{enabled_languages}->{$tag} = $name;
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
