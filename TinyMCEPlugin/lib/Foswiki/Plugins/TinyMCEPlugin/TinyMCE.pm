# JQuery plugin for Foswiki JQueryPlugin
# This plugin is responsible for loading the Javascript that interfaces
# with the TinyMCE editor.
#
# Javascript is Copyright (C) 2012 Sven Dowideit - SvenDowideit@fosiki.com
# Portions Copyright (C) 2017 Crawford Currie http://c-dot.co.uk
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details,
# published at http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TinyMCEPlugin::TinyMCE;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

use Assert;

=begin TML

---+ package Foswiki::Plugins::TinyMCEPlugin::TinyMCE

This is the perl stub for tinyMCE.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = bless(
        $class->SUPER::new(
            name          => 'TinyMCE',
            version       => $Foswiki::Plugins::TinyMCEPlugin::VERSION,
            author        => 'Foswiki Contributors',
            homepage      => 'http://foswiki.org/Extensions/TinyMCEPlugin',
            documentation => "$Foswiki::cfg{SystemWebName}.TinyMCEPlugin",
            puburl        => '%PUBURLPATH%/%SYSTEMWEB%/TinyMCEPlugin',
            javascript =>
              [ 'foswiki_tiny.js', 'tinymce/js/tinymce/tinymce.min.js' ],
            css          => ['wysiwyg.css'],
            dependencies => ['foswiki'],
            debug        => DEBUG
        ),
        $class
    );

    return $this;
}

sub renderJS {
    my ( $this, $text ) = @_;

    $text = $this->SUPER::renderJS($text);

    # Uncompressed is not available any more.
    $text =~ s(/tinymce/js/tinymce/tinymce\.min\.uncompressed\.js)
        (/tinymce/js/tinymce/tinymce.min.js);

    return $text;
}

1;
