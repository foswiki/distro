# Plugin for a software formerly known as TWiki<tm> 
#
# Copyright (C) 2008 Oliver Krueger <oliver@wiki-one.net>
# All Rights Reserved.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# This piece of software is licensed under the GPLv2.

package TWiki::Plugins::AutoViewTemplatePlugin;

use strict;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION 
  $debug $mode $override $isEditAction
  $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = 'ipo';
$SHORTDESCRIPTION = 'Automatically sets VIEW_TEMPLATE and EDIT_TEMPLATE';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'AutoViewTemplatePlugin';


sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # get configuration
    $debug = $TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Debug}       || 0;
    $mode = $TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Mode}         || "exist";
    $override = $TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Override} || 0;    

    # is this an edit action?
    $isEditAction = TWiki::Func::getContext()->{edit};
    my $templateVar = $isEditAction?'EDIT_TEMPLATE':'VIEW_TEMPLATE';

    # back off if there is a view template already and we are not in override mode
    my $currentTemplate = TWiki::Func::getPreferencesValue($templateVar);
    return 1 if $currentTemplate && !$override;

    # check if this is a new topic and - if so - try to derive the templateName from
    # the WebTopicEditTemplate
    if (!TWiki::Func::topicExists($web, $topic)) {
      if (TWiki::Func::topicExists($web, 'WebTopicEditTemplate')) {
        $topic = 'WebTopicEditTemplate';
      } else {
        return 1;
      }
    }
	
    # get form-name
    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
    my $form = $meta->get("FORM");
    my $formName = $form->{"name"} if $form;
    
    # is it a structured topic?
    return 1 unless $formName;
    TWiki::Func::writeDebug("- ${pluginName}: formfields detected ($formName)") if $debug;

    # get it
    my $templateName = "";
    MODE: {
      if ( $mode eq "section" ) {
        $templateName = _getTemplateFromSectionInclude( $formName, $topic, $web );		
        last MODE;	
      }
      if ( $mode eq "exist" ) {
        $templateName = _getTemplateFromTemplateExistence( $formName, $topic, $web );
        last MODE;	
      }
    }
    
    # only set the view template if there is anything to set
    return 1 unless $templateName;

    # in edit mode, try to read the template to check if it exists
    if ($isEditAction && !TWiki::Func::readTemplate($templateName)) {
      TWiki::Func::writeDebug("- ${pluginName}: edit tempalte not found") if $debug;
      return 1;
    }
    
    # do it
    if ($debug) {
      if ( $currentTemplate ) {
        if ( $override ) {
          TWiki::Func::writeDebug("- ${pluginName}: $templateVar already set, overriding with: $templateName");
        } else {
          TWiki::Func::writeDebug("- ${pluginName}: $templateVar not changed/set.");
        }
      } else {
        TWiki::Func::writeDebug("- ${pluginName}: $templateVar set to: $templateName");
      }      	
    }
    $TWiki::Plugins::SESSION->{prefs}->pushPreferenceValues( 'SESSION', { $templateVar => $templateName } );

    # Plugin correctly initialized
    return 1;
}

sub _getTemplateFromSectionInclude {
    my $formName = $_[0];
    my $topic    = $_[1];
    my $web      = $_[2];

    TWiki::Func::writeDebug("- ${pluginName}: called _getTemplateFromSectionInclude($formName, $topic, $web)") if $debug;
	
    my ($formweb, $formtopic) = TWiki::Func::normalizeWebTopicName($web, $formName);

    # SMELL: This can be done much faster, if the formdefinition topic is read directly
    my $sectionName = $isEditAction?'edittemplate':'viewtemplate';
    my $templateName = "%INCLUDE{ \"$formweb.$formtopic\" section=\"$sectionName\"}%";
    $templateName = TWiki::Func::expandCommonVariables( $templateName, $topic, $web );
      
    # TODO: sanatize value
      
    return $templateName;
}


# replaces Web.MyForm with Web.MyViewTemplate and returns Web.MyViewTemplate if it exists otherwise nothing
sub _getTemplateFromTemplateExistence {
    my $formName = $_[0];
    my $topic    = $_[1];
    my $web      = $_[2];
	
    TWiki::Func::writeDebug("- ${pluginName}: called _getTemplateFromTemplateExistence($formName, $topic, $web)") if $debug;
    my ($templateWeb, $templateTopic) = TWiki::Func::normalizeWebTopicName($web, $formName);
    
    $templateWeb =~ s/\//\./go;
    my $templateName = $templateWeb.'.'.$templateTopic;
    $templateName =~ s/Form$//;
    $templateName .= $isEditAction?'Edit':'View';

    return $templateName;
}

1;
