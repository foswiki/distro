# See bottom of file for license and copyright information
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

# Still do to:
# Handle continuation lines (see Prefs::parseText). These should always
# go into a text area.

package Foswiki::Plugins::PreferencesPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use vars qw( @shelter );

our $VERSION = '1.16';
our $RELEASE = '1.16';
our $SHORTDESCRIPTION =
  'Allows editing of preferences using fields predefined in a form';
our $NO_PREFS_IN_TOPIC = 1;

my $MARKER = "\007";

# Markers used during form generation
my $START_MARKER = $MARKER . 'STARTPREF' . $MARKER;
my $END_MARKER   = $MARKER . 'ENDPREF' . $MARKER;

sub initPlugin {

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            'Version mismatch between PreferencesPlugin and Plugins.pm');
        return 0;
    }
    @shelter = ();

    return 1;
}

sub beforeCommonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;
    my $topic = $_[1];
    my $web   = $_[2];
    return unless ( $_[0] =~ m/%EDITPREFERENCES(?:\{(.*?)\})?%/ );

    require CGI;
    require Foswiki::Attrs;
    my $formDef;
    my $attrs = new Foswiki::Attrs($1);
    if ( defined( $attrs->{_DEFAULT} ) ) {
        my ( $formWeb, $form ) =
          Foswiki::Func::normalizeWebTopicName( $web, $attrs->{_DEFAULT} );

        # SMELL: Unpublished API. No choice, though :-(
        require Foswiki::Form;    # SMELL
        $formDef =
          new Foswiki::Form( $Foswiki::Plugins::SESSION, $formWeb, $form );
    }

    my $query = Foswiki::Func::getCgiQuery();

    my $action = lc( $query->param('prefsaction') || '' );
    $query->Delete('prefsaction');
    $action =~ s/\s.*$//;

    if ( $action eq 'edit' ) {
        Foswiki::Func::setTopicEditLock( $web, $topic, 1 );

        # Replace setting values by form fields but not inside comments Item4816
        # and also not inside verbatim blocks Item1117
        my $outtext        = '';
        my $insidecomment  = 0;
        my $insideverbatim = 0;
        foreach my $token ( split /(<!--|-->|<\/?verbatim\b[^>]*>)/, $_[0] ) {
            if ( !$insideverbatim and $token =~ m/<!--/ ) {
                $insidecomment++;
            }
            elsif ( !$insideverbatim and $token =~ m/-->/ ) {
                $insidecomment-- if ( $insidecomment > 0 );
            }
            elsif ( $token =~ m/<verbatim/ ) {
                $insideverbatim++;
            }
            elsif ( $token =~ m/<\/verbatim/ ) {
                $insideverbatim-- if ( $insideverbatim > 0 );
            }
            elsif ( !$insidecomment and !$insideverbatim ) {
                $token =~
s/^($Foswiki::regex{setRegex})($Foswiki::regex{tagNameRegex})\s*\=(.*$(?:\n[ \t]+[^\s*].*$)*)/
                           $1._generateEditField($web, $topic, $3, $4, $formDef)/gem;
            }
            $outtext .= $token;
        }
        $_[0] = $outtext;

        $_[0] =~ s/%EDITPREFERENCES(\{.*?\})?%/
          _generateControlButtons($web, $topic)/ge;
        my $viewUrl = Foswiki::Func::getScriptUrl( $web, $topic, 'viewauth' );
        my $startForm = CGI::start_form(
            -name   => 'editpreferences',
            -method => 'post',
            -action => $viewUrl
        );
        $startForm =~ s/\s+$//s;
        my $endForm = CGI::end_form();
        $endForm =~ s/\s+$//s;
        $_[0] =~
          s/^(.*?)$START_MARKER(.*)$END_MARKER(.*?)$/$1$startForm$2$endForm$3/s;
        $_[0] =~ s/$START_MARKER|$END_MARKER//gs;
    }

    if ( $action eq 'cancel' ) {
        Foswiki::Func::setTopicEditLock( $web, $topic, 0 );

    }
    elsif ( $action eq 'save' ) {

        # Make sure the request came from POST
        if ( $query && $query->method() && uc( $query->method() ) ne 'POST' ) {

            # silently ignore it if the request didn't come from a POST
        }
        else {
            my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

            # SMELL: unchecked implicit untaint of value?
            # $text =~ s/($Foswiki::regex{setVarRegex})/
            $text =~
s/^($Foswiki::regex{setRegex})($Foswiki::regex{tagNameRegex})\s*\=(.*$(?:\n[ \t]+[^\s*].*$)*)/
                 $1._saveSet($query, $web, $topic, $3, $4, $formDef)/mgeo;
            Foswiki::Func::saveTopic( $web, $topic, $meta, $text );
        }
        Foswiki::Func::setTopicEditLock( $web, $topic, 0 );

        # Finish with a redirect so that the *new* values are seen
        my $viewUrl = Foswiki::Func::getScriptUrl( $web, $topic, 'view' );
        Foswiki::Func::redirectCgiQuery( undef, $viewUrl );
        return;
    }

    # implicit action="view", or drop through from "save" or "cancel"
    $_[0] =~ s/%EDITPREFERENCES(\{.*?\})?%/_generateEditButton($web, $topic)/ge;
}

# Use the post-rendering handler to plug our formatted editor units
# into the text
sub postRenderingHandler {
    ### my ( $text ) = @_;

    $_[0] =~ s/SHELTER$MARKER(\d+)/$shelter[$1]/g;
}

# Pluck the default value of a named field from a form definition
sub _getField {
    my ( $formDef, $name ) = @_;
    foreach my $f ( @{ $formDef->{fields} } ) {
        if ( $f->{name} eq $name ) {
            return $f;
        }
    }
    return;
}

# Generate a field suitable for editing this type. Use of the core
# function 'renderFieldForEdit' ensures that we will pick up
# extra edit types defined in other plugins.
sub _generateEditField {
    my ( $web, $topic, $name, $value, $formDef ) = @_;
    $value =~ s/^\s*(.*?)\s*$/$1/ge;

    my ( $extras, $html );

    if ($formDef) {
        my $fieldDef = $formDef->getField($name);
        if ($fieldDef) {
            my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );
            ( $extras, $html ) =
              $fieldDef->renderForEdit( $topicObject, $value );
        }
    }
    unless ($html) {

        if ( $value =~ m/\n/ ) {
            my $rows = 1;
            $rows++ while $value =~ m/\n/g;

            # No form definition and there are newlines, default to textarea
            $html = CGI::textarea(
                -class   => 'foswikiAlert foswikiInputField',
                -name    => $name,
                -cols    => 80,
                -rows    => $rows,
                -default => $value
            );
        }
        else {

            # No form definition and no newlines, default to text field.
            $html = CGI::textfield(
                -class => 'foswikiAlert foswikiInputField',
                -name  => $name,
                -size  => 80,
                -value => $value
            );
        }
    }

    push( @shelter, $html );

    return $START_MARKER
      . CGI::span(
        {
            class => 'foswikiAlert',
            style => 'font-weight:bold;'
        },
        $name . ' = SHELTER' . $MARKER . $#shelter
      ) . $END_MARKER;
}

# Generate the button that replaces the EDITPREFERENCES tag in view mode
sub _generateEditButton {
    my ( $web, $topic ) = @_;

    my $viewUrl = Foswiki::Func::getScriptUrl( $web, $topic, 'viewauth' );
    my $text = CGI::start_form(
        -name   => 'editpreferences',
        -method => 'post',
        -action => $viewUrl
    );
    $text .= CGI::input(
        {
            type  => 'hidden',
            name  => 'prefsaction',
            value => 'edit'
        }
    );
    $text .= CGI::submit(
        -name  => 'edit',
        -value => 'Edit Preferences',
        -class => 'foswikiRequiresChangePermission foswikiButton'
    );
    $text .= CGI::end_form();
    $text =~ s/\n//sg;
    return $text;
}

# Generate the buttons that replace the EDITPREFERENCES tag in edit mode
sub _generateControlButtons {
    my ( $web, $topic ) = @_;

    my $text = $START_MARKER
      . CGI::submit(
        -name      => 'prefsaction',
        -value     => 'Save new settings',
        -class     => 'foswikiSubmit',
        -accesskey => 's'
      );
    $text .= '&nbsp;';
    $text .= CGI::submit(
        -name      => 'prefsaction',
        -value     => 'Cancel',
        -class     => 'foswikiButtonCancel',
        -accesskey => 'c'
    ) . $END_MARKER;
    return $text;
}

# Given a Set in the topic being saved, look in the query to see
# if there is a new value for the Set and generate a new
# Set statement.
sub _saveSet {
    my ( $query, $web, $topic, $name, $value, $formDef ) = @_;

    my $newValue = $query->param($name);
    if ( not defined $newValue ) {
        $newValue = $value;
        $newValue =~ s/^\s+//;    # strip leading whitespace
    }

    if ($formDef) {
        my $fieldDef = _getField( $formDef, $name );
        my $type = $fieldDef->{type} || '';
        if ( $type && $type =~ m/^checkbox/ ) {
            my $val  = '';
            my $vals = $fieldDef->{value};
            foreach my $item (@$vals) {
                my $cvalue = $query->param( $name . $item );
                if ( defined($cvalue) ) {
                    if ( !$val ) {
                        $val = '';
                    }
                    else {
                        $val .= ', ' if ($cvalue);
                    }
                    $val .= $item if ($cvalue);
                }
            }
            $newValue = $val;
        }
    }

    # if no form def, it's just treated as text

    return $name . ' = ' . $newValue;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
