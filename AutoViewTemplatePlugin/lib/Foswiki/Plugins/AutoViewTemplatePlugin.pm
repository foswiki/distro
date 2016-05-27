# See bottom of file for license and copyright information
package Foswiki::Plugins::AutoViewTemplatePlugin;

use strict;
use warnings;
use vars qw( $debug $mode $override $isEditAction $pluginName);

our $VERSION           = '1.24';
our $RELEASE           = '2016-04-08';
our $SHORTDESCRIPTION  = 'Automatically sets VIEW_TEMPLATE and EDIT_TEMPLATE';
our $NO_PREFS_IN_TOPIC = 1;

$pluginName = 'AutoViewTemplatePlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    my $session = $Foswiki::Plugins::SESSION;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # get configuration
    $debug = $Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Debug} || 0;
    $mode  = $Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Mode}  || "exist";
    $override = $Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Override} || 0;

    # is this an edit action?
    $isEditAction = Foswiki::Func::getContext()->{edit};
    my $templateVar = $isEditAction ? 'EDIT_TEMPLATE' : 'VIEW_TEMPLATE';

  # back off if there is a view template already and we are not in override mode
    my $currentTemplate = Foswiki::Func::getPreferencesValue($templateVar);
    return 1 if $currentTemplate && !$override;

# check if this is a new topic and - if so - try to derive the templateName from
# the WebTopicEditTemplate
    if ( !Foswiki::Func::topicExists( $web, $topic ) ) {
        if ( Foswiki::Func::topicExists( $web, 'WebTopicEditTemplate' ) ) {
            $topic = 'WebTopicEditTemplate';
        }
        else {
            return 1;
        }
    }

    # get form-name
    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
    my $form = $meta->get("FORM");
    my $formName;
    $formName = $form->{"name"} if $form;

    # is it a structured topic?
    return 1 unless $formName;
    Foswiki::Func::writeDebug(
        "- ${pluginName}: formfields detected ($formName)")
      if $debug;

    # get it
    my $templateName = "";
  MODE: {
        if ( $mode eq "section" ) {
            $templateName =
              _getTemplateFromSectionInclude( $formName, $topic, $web );
            last MODE;
        }
        if ( $mode eq "exist" ) {
            $templateName =
              _getTemplateFromTemplateExistence( $formName, $topic, $web );
            last MODE;
        }
    }

    # only set the view template if there is anything to set
    return 1 unless $templateName;

    my $tryname = $templateName;

    if ( $Foswiki::Plugins::VERSION < 2.4 ) {
        $tryname =~ s/[^A-Za-z0-9_,.\/]//g;
    }
    else {
        $tryname =~ s/$Foswiki::regex{webTopicInvalidCharRegex}//g;
    }

    if ( $tryname ne $templateName ) {
        Foswiki::Func::setPreferencesValue(
            'FLASHNOTE',
            $session->i18n->maketext(
'[_1]: Invalid template name ([_2]) - Contains invalid characters.',
                "%SYSTEMWEB%.$pluginName",
                "${templateName}Template"
            )
        );
        Foswiki::Func::writeDebug(
"- ${pluginName}: Template name ($templateName) ignored - contains invalid characters."
        );
        return 1;
    }

    # in edit mode, try to read the template to check if it exists
    if ( $isEditAction && !Foswiki::Func::readTemplate($templateName) ) {
        Foswiki::Func::writeDebug("- ${pluginName}: edit template not found")
          if $debug;
        return 1;
    }

    # do it
    if ($debug) {
        if ($currentTemplate) {
            if ($override) {
                Foswiki::Func::writeDebug(
"- ${pluginName}: $templateVar already set, overriding with: $templateName"
                );
            }
            else {
                Foswiki::Func::writeDebug(
                    "- ${pluginName}: $templateVar not changed/set.");
            }
        }
        else {
            Foswiki::Func::writeDebug(
                "- ${pluginName}: $templateVar set to: $templateName");
        }
    }
    if ( $Foswiki::Plugins::VERSION >= 2.1 ) {
        Foswiki::Func::setPreferencesValue( $templateVar, $templateName );
    }
    else {
        $Foswiki::Plugins::SESSION->{prefs}->pushPreferenceValues( 'SESSION',
            { $templateVar => $templateName } );
    }

    # Plugin correctly initialized
    return 1;
}

sub _getTemplateFromSectionInclude {
    my $formName = $_[0];
    my $topic    = $_[1];
    my $web      = $_[2];

    Foswiki::Func::writeDebug(
"- ${pluginName}: called _getTemplateFromSectionInclude($formName, $topic, $web)"
    ) if $debug;

    my ( $formweb, $formtopic ) =
      Foswiki::Func::normalizeWebTopicName( $web, $formName );

# SMELL: This can be done much faster, if the formdefinition topic is read directly
    my $sectionName = $isEditAction ? 'edittemplate' : 'viewtemplate';
    my $templateName =
"%INCLUDE{ \"$formweb.$formtopic\" section=\"$sectionName\" warn=\"off\"}%";
    $templateName =
      Foswiki::Func::expandCommonVariables( $templateName, $topic, $web );

    return $templateName;
}

# replaces Web.MyForm with Web.MyViewTemplate and returns Web.MyViewTemplate or Web.MyEditTemplate
sub _getTemplateFromTemplateExistence {
    my $formName = $_[0];
    my $topic    = $_[1];
    my $web      = $_[2];

    Foswiki::Func::writeDebug(
"- ${pluginName}: called _getTemplateFromTemplateExistence($formName, $topic, $web)"
    ) if $debug;
    my ( $templateWeb, $templateTopic ) =
      Foswiki::Func::normalizeWebTopicName( $web, $formName );

    $templateWeb =~ s/\//\./g;
    my $templateName = $templateWeb . '.' . $templateTopic;
    $templateName =~ s/Form$//;
    $templateName .= $isEditAction ? 'Edit' : 'View';

    return $templateName;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008 Oliver Krueger <oliver@wiki-one.net>
Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
