# Copyright (C) 2007-2009 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatEditPlugin;

use strict;
use Foswiki::Func;


use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
  $baseWeb $baseTopic 
);

$VERSION = '$Rev$';
$RELEASE = 'v4.02';

$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'A Wikiwyg Editor';

use constant DEBUG => 0; # toggle me
use Foswiki::Plugins::JQueryPlugin ();

###############################################################################
sub writeDebug {
  return unless DEBUG;
  print STDERR "- NatEditPlugin - " . $_[0] . "\n";
  #Foswiki::Func::writeDebug("- NatEditPlugin - $_[0]");
}


###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  Foswiki::Func::registerTagHandler('FORMBUTTON', \&handleFORMBUTTON);
  Foswiki::Func::registerTagHandler('NATFORMLIST', \&handleNATFORMLIST);

  my $skin = Foswiki::Func::getPreferencesValue('SKIN');
  # not using Foswiki::Func::getSkin() to prevent 
  # getting the cover as well

  unless ($skin =~ /\b(natedit)\b/) {
    $skin = "natedit,$skin";
    Foswiki::Func::setPreferencesValue('SKIN', $skin);
  }

  # register the natedit jquery plugin
  Foswiki::Plugins::JQueryPlugin::registerPlugin("NatEdit",
    'Foswiki::Plugins::NatEditPlugin::NATEDIT');

  return 1;
}

###############################################################################
# render a button to add/change the form while editing
# returns 
#    * the empty string if there's no WEBFORM
#    * or "Add form" if there is no form attached to a topic yet
#    * or "Change form" otherwise
#
# there are no native means besides the "addform" template being used
# to render the FORMFIELDS. but this is not what we need here at all. infact
# we need an empty addform.nat.tmp to switch off this feature of FORMFIELDS
sub handleFORMBUTTON {
  my ($session, $params, $theTopic, $theWeb) = @_;

  Foswiki::Plugins::JQueryPlugin::createPlugin("natedit");

  my $saveCmd = '';
  my $request = Foswiki::Func::getCgiQuery();
  $saveCmd = $request->param('cmd') || '' if $request;
  return '' if $saveCmd eq 'repRev';

  my $form = $request->param('formtemplate') || '';

  unless ($form) {
    my ($meta, $dumy) = Foswiki::Func::readTopic($theWeb, $theTopic);
    my $formMeta = $meta->get('FORM'); 
    $form = $formMeta->{"name"} if $formMeta;
  }

  $form = '' if $form eq 'none';

  my $action;
  my $actionTitle;
  my $actionText;

  if ($form) {
    $action = 'replaceform';
  } else {
    $action = 'addform';
  }

  if ($form) {
    $actionText = $session->{i18n}->maketext("Change form");
    $actionTitle = $session->{i18n}->maketext("Change the current form of <nop>[_1]", "$theWeb.$theTopic");
  } elsif (Foswiki::Func::getPreferencesValue('WEBFORMS', $theWeb)) {
    $actionText = $session->{i18n}->maketext("Add form");
    $actionTitle = $session->{i18n}->maketext("Add a new form to <nop>[_1]", "$theWeb.$theTopic");
  } else {
    return '';
  }
  $actionText =~ s/&&/\&/g;
  $actionTitle =~ s/&&/\&/g;
  
  my $theFormat = $params->{_DEFAULT} || $params->{format} || '$link';
  $theFormat =~ s/\$link/<a href='\$url' accesskey='f' title='\$title'><span>\$acton<\/span><\/a>/g;
  $theFormat =~ s/\$url/javascript:\$script/g;
  $theFormat =~ s/\$script/submitEditForm('save', '$action');/g;
  $theFormat =~ s/\$title/$actionTitle/g;
  $theFormat =~ s/\$action/$actionText/g;
  $theFormat =~ s/\$id/$action/g;
  $theFormat = Foswiki::Func::expandCommonVariables($theFormat, $theTopic, $theWeb)
    if escapeParameter($theFormat);

  return $theFormat;
}

###############################################################################
# This function will store the TopicTitle in a preference variable if it isn't
# part of the DataForm of this topic. In a way, we do the reverse of
# WebDB::onReload() where the TopicTitle is extracted and put into the cache.
sub beforeSaveHandler {
  my ($text, $topic, $web, $meta) = @_;

  writeDebug("called beforeSaveHandler");
  # find out if we received a TopicTitle 
  my $request = Foswiki::Func::getCgiQuery();
  my $topicTitle = $request->param('TopicTitle');

  unless (defined $topicTitle) {
    writeDebug("didn't get a TopicTitle, nothing do here");
    return;
  }

  # find out if this topic can store the TopicTitle in its metadata
  if (defined($meta->get('FIELD', 'TopicTitle'))) {
    writeDebug("can deal with TopicTitles by itself");

    # however, check if we've got a TOPICTITLE preference setting
    # if so remove it. this happens if we stored a topic title but
    # then added a form that now takes the topic title instead
    if (defined $meta->get('PREFERENCE', 'TOPICTITLE')) {
      writeDebug("removing redundant TopicTitles in preferences");
      $meta->remove('PREFERENCE', 'TOPICTITLE');
    }
    return;
  } 

  writeDebug("we need to store the TopicTitle in the preferences");

  if ($topicTitle eq $topic) {
    writeDebug("same as topic name");
    $topicTitle = '';
  }


  # if it is a topic setting, override it.
  my $topicTitleHash = $meta->get('PREFERENCE', 'TOPICTITLE');
  if (defined $topicTitleHash) {
    writeDebug("found old TopicTitle in preference settings: $topicTitleHash->{value}");
    if ($topicTitle) {
      # set the new value
      $topicTitleHash->{value} = $topicTitle; 
    } else {
      # remove the value if the new TopicTitle is an empty string
      $meta->remove('PREFERENCE', 'TOPICTITLE');
    }
    return;
  } 

  writeDebug("no TopicTitle in preference settings");

  # if it is a bullet setting, replace it.
  if ($text =~ s/((?:^|[\n\r])(?:\t|   )+\*\s+(?:Set|Local)\s+TOPICTITLE\s*=\s*)(.*)((?:$|[\r\n]))/$1$topicTitle$3/o) {
    writeDebug("found old TopicTitle defined as a bullet setting: $2");
    $_[0] = $text;
    return;
  }

  writeDebug("no TopicTitle stored anywhere. creating a new preference setting");

  if ($topicTitle) { # but only if we don't set it to the empty string
    $meta->putKeyed('PREFERENCE', {
      name=>'TOPICTITLE', 
      title=>'TOPICTITLE', 
      type=>'Local', 
      value=>$topicTitle
    });
  }
}

###############################################################################
# taken from Foswiki::UI::ChangeForm and leveraged to normal formatting standards
sub handleNATFORMLIST {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theFormat = $params->{_DEFAULT} || $params->{format} 
    || '<label><input type="radio" name="formtemplate" id="formtemplateelem$index" $checked value="$name">'.
       '&nbsp;$formTopic</input></label>';

  $theWeb = $params->{web} if defined $params->{web};
  $theTopic = $params->{topic} if defined $params->{topic};
  my $theSeparator = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSelected = $params->{selected};
  
  my $request = Foswiki::Func::getCgiQuery();
  $theSelected = $request->param('formtemplate') unless defined $theSelected;
  $theSeparator = '<br />' unless defined $theSeparator;

  unless ($theSelected) {
    my ($meta) = Foswiki::Func::readTopic($theWeb, $theTopic);
    my $form = $meta->get( 'FORM' );
    $theSelected = $form->{name} if $form;
  }
  $theSelected = 'none' unless $theSelected;

  my $legalForms = Foswiki::Func::getPreferencesValue('WEBFORMS', $theWeb);
  $legalForms =~ s/^\s*//;
  $legalForms =~ s/\s*$//;
  my %forms = map {$_ => 1} split( /[,\s]+/, $legalForms );
  my @forms = sort keys %forms;
  push @forms, 'none';

  my @formList = '';
  my $index = 0;
  foreach my $form (@forms) {
      $index++;
      my $text = $theFormat;
      my $checked = '';
      $checked = 'checked' if $form eq $theSelected;
      my ($formWeb, $formTopic) = $session->normalizeWebTopicName($theWeb, $form);

      $text =~ s/\$index/$index/g;
      $text =~ s/\$checked/$checked/g;
      $text =~ s/\$name/$form/g;
      $text =~ s/\$formWeb/$formWeb/g;
      $text =~ s/\$formTopic/$formTopic/g;
      
      push @formList, $text;
  }
  my $result = $theHeader.join($theSeparator, @formList).$theFooter;
  $result =~ s/\$count/$index/g;
  $result =~ s/\$web/$theWeb/g;
  $result =~ s/\$topic/$theTopic/g;
  $result = Foswiki::Func::expandCommonVariables($result, $theTopic, $theWeb)
    if escapeParameter($result);

  return $result;
}

###############################################################################
sub escapeParameter {

  return 0 unless $_[0];

  my $found = 0;

  $found = 1 if $_[0] =~ s/\$percnt/%/g;
  $found = 1 if $_[0] =~ s/\$nop//g;
  $found = 1 if $_[0] =~ s/\\n/\n/g;
  $found = 1 if $_[0] =~ s/\$n/\n/g;
  $found = 1 if $_[0] =~ s/\\%/%/g;
  $found = 1 if $_[0] =~ s/\\"/"/g;
  $found = 1 if $_[0] =~ s/\$dollar/\$/g;

  return $found;
}

1;
