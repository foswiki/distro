# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2007  Foswiki Contributors.
# All Rights Reserved. Foswiki Contributors are listed in the
# AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

# Still do to:
# Handle continuation lines (see Prefs::parseText). These should always
# go into a text area.

package Foswiki::Plugins::PreferencesPlugin;

use strict;

require Foswiki::Func;    # The plugins API
require Foswiki::Plugins; # For the API version

use vars qw( $VERSION $RELEASE @shelter );

# This should always be $Rev: 13963 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 13963 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'TWiki-4.2';

my $MARKER = "\007";

# Markers used during form generation
my $START_MARKER  = $MARKER.'STARTPREF'.$MARKER;
my $END_MARKER    = $MARKER.'ENDPREF'.$MARKER;

sub initPlugin {
    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between PreferencesPlugin and Plugins.pm' );
        return 0;
    }
    @shelter = ();

    return 1;
}

sub beforeCommonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;
    my $topic = $_[1];
    my $web = $_[2];
    return unless ( $_[0] =~ m/%EDITPREFERENCES(?:{(.*?)})?%/ );

    require CGI;
    require Foswiki::Attrs;
    my $formDef;
    my $attrs = new Foswiki::Attrs( $1 );
    if( defined( $attrs->{_DEFAULT} )) {
        my( $formWeb, $form ) = Foswiki::Func::normalizeWebTopicName(
            $web, $attrs->{_DEFAULT} );

        # SMELL: Unpublished API. No choice, though :-(
        require Foswiki::Form;    # SMELL
        $formDef =
          new Foswiki::Form( $Foswiki::Plugins::SESSION, $formWeb, $form );
    }

    my $query = Foswiki::Func::getCgiQuery();

    my $action = lc $query->param( 'prefsaction' );
    $query->Delete( 'prefsaction' );
    $action =~ s/\s.*$//;

    if ( $action eq 'edit' ) {
        Foswiki::Func::setTopicEditLock( $web, $topic, 1 );
        
        # Replace setting values by form fields but not inside comments Item4816
        my $outtext = '';
        my $insidecomment = 0;
        foreach my $token ( split/(<!--|-->)/, $_[0] ) {
            if ( $token =~ /<!--/ ) {
                $insidecomment++;
            } elsif ( $token =~ /-->/ ) {
                $insidecomment-- if ( $insidecomment > 0 );
            } elsif ( !$insidecomment ) {
                $token =~ s(^((?:\t|   )+\*\sSet\s*)(\w+)\s*\=(.*$(\n[ \t]+[^\s*].*$)*))
                           ($1._generateEditField($web, $topic, $2, $3, $formDef))gem;
            }
            $outtext .= $token;
        }
        $_[0] = $outtext;
          
        $_[0] =~ s/%EDITPREFERENCES({.*?})?%/
          _generateControlButtons($web, $topic)/ge;
        my $viewUrl = Foswiki::Func::getScriptUrl(
            $web, $topic, 'viewauth' );
        my $startForm = CGI::start_form(
            -name => 'editpreferences',
            -method => 'post',
            -action => $viewUrl );
        $startForm =~ s/\s+$//s;
        my $endForm = CGI::end_form();
        $endForm =~ s/\s+$//s;
        $_[0] =~ s/^(.*?)$START_MARKER(.*)$END_MARKER(.*?)$/$1$startForm$2$endForm$3/s;
        $_[0] =~ s/$START_MARKER|$END_MARKER//gs;
    }

    if( $action eq 'cancel' ) {
        Foswiki::Func::setTopicEditLock( $web, $topic, 0 );

    } elsif( $action eq 'save' ) {

        my( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        $text =~ s(^((?:\t|   )+\*\sSet\s)(\w+)\s\=\s(.*)$)
          ($1._saveSet($query, $web, $topic, $2, $3, $formDef))mgeo;
        Foswiki::Func::saveTopic( $web, $topic, $meta, $text );
        Foswiki::Func::setTopicEditLock( $web, $topic, 0 );
        # Finish with a redirect so that the *new* values are seen
        my $viewUrl = Foswiki::Func::getScriptUrl( $web, $topic, 'view' );
        Foswiki::Func::redirectCgiQuery( undef, $viewUrl );
        return;
    }
    # implicit action="view", or drop through from "save" or "cancel"
    $_[0] =~ s/%EDITPREFERENCES({.*?})?%/_generateEditButton($web, $topic)/ge;
}

# Use the post-rendering handler to plug our formatted editor units
# into the text
sub postRenderingHandler {
    ### my ( $text ) = @_;

    $_[0] =~ s/SHELTER$MARKER(\d+)/$shelter[$1]/g;
}

# Pluck the default value of a named field from a form definition
sub _getField {
    my( $formDef, $name ) = @_;
    foreach my $f ( @{$formDef->{fields}} ) {
        if( $f->{name} eq $name ) {
            return $f;
        }
    }
    return undef;
}

# Generate a field suitable for editing this type. Use of the core
# function 'renderFieldForEdit' ensures that we will pick up
# extra edit types defined in other plugins.
sub _generateEditField {
    my( $web, $topic, $name, $value, $formDef ) = @_;
    $value =~ s/^\s*(.*?)\s*$/$1/ge;

    my ($extras, $html);

    if( $formDef ) {
        my $fieldDef;
        if (defined(&Foswiki::Form::getField)) {
            # TWiki 4.2 and later
            $fieldDef = $formDef->getField( $name );
        } else {
            # TWiki < 4.2
            $fieldDef = _getField( $formDef, $name );
        }
        if ( $fieldDef ) {
            if( defined(&Foswiki::Form::renderFieldForEdit)) {
                # TWiki < 4.2 SMELL: use of unpublished core function
                ( $extras, $html ) =
                  $formDef->renderFieldForEdit( $fieldDef, $web, $topic, $value);
            } else {
                # TWiki 4.2 and later SMELL: use of unpublished core function
                ( $extras, $html ) =
                  $fieldDef->renderForEdit( $web, $topic, $value );
            }
        }
    }
    unless( $html ) {
        # No form definition, default to text field.
        $html = CGI::textfield( -class=>'foswikiAlert twikiInputField',
                                -name => $name,
                                -size => 80, -value => $value );
    }

    push( @shelter, $html );

    return $START_MARKER.
      CGI::span({class=>'foswikiAlert',
                 style=>'font-weight:bold;'},
                $name . ' = SHELTER' . $MARKER . $#shelter).$END_MARKER;
}

# Generate the button that replaces the EDITPREFERENCES tag in view mode
sub _generateEditButton {
    my( $web, $topic ) = @_;

    my $viewUrl = Foswiki::Func::getScriptUrl(
        $web, $topic, 'viewauth' );
    my $text = CGI::start_form(
        -name => 'editpreferences',
        -method => 'post',
        -action => $viewUrl );
    $text .= CGI::input({
        type => 'hidden',
        name => 'prefsaction',
        value => 'edit'});
    $text .= CGI::submit(-name => 'edit',
                         -value=>'Edit Preferences',
                         -class=>'foswikiButton');
    $text .= CGI::end_form();
    $text =~ s/\n//sg;
    return $text;
}

# Generate the buttons that replace the EDITPREFERENCES tag in edit mode
sub _generateControlButtons {
    my( $web, $topic ) = @_;

    my $text = $START_MARKER.CGI::submit(-name=>'prefsaction',
                                         -value=>'Save new settings',
                                         -class=>'twikiSubmit',
                                         -accesskey=>'s');
    $text .= '&nbsp;';
    $text .= CGI::submit(-name=>'prefsaction', -value=>'Cancel',
                         -class=>'foswikiButton',
                         -accesskey=>'c').$END_MARKER;
    return $text;
}

# Given a Set in the topic being saved, look in the query to see
# if there is a new value for the Set and generate a new
# Set statement.
sub _saveSet {
    my( $query, $web, $topic, $name, $value, $formDef ) = @_;

    my $newValue = $query->param( $name ) || $value;

    if( $formDef ) {
        my $fieldDef = _getField( $formDef, $name );
        my $type = $fieldDef->{type} || '';
        if( $type && $type =~ /^checkbox/ ) {
            my $val = '';
            my $vals = $fieldDef->{value};
            foreach my $item ( @$vals ) {
                my $cvalue = $query->param( $name.$item );
                if( defined( $cvalue ) ) {
                    if( ! $val ) {
                        $val = '';
                    } else {
                        $val .= ', ' if( $cvalue );
                    }
                    $val .= $item if( $cvalue );
                }
            }
            $newValue = $val;
        }
    }
    # if no form def, it's just treated as text

    return $name.' = '.$newValue;
}

1;
