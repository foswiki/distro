# ---+ Extensions
# ---++ TWikiCompatibilityPlugin
# **PERL LABEL="TWiki Web/Topic Name Conversion"**
# a hash mapping TWiki's TWiki web topics to Foswiki's topics
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{TWikiWebTopicNameConversion} = {
    'ATasteOfTWiki' => 'BeginnersStartHere',
    'TWikiAccessControl' => 'AccessControl',
    'TWikiAddOns' => 'ContributedAddOns',
    'TWikiContribs' => 'Contribs',
    'TWikiContributor' => 'ProjectContributor',
    'TWikiCss' => 'CascadingStyleSheets',
    'TWikiDocGraphics' => 'DocumentGraphics',
    'TWikiDocumentation' => 'CompleteDocumentation',
    'TWikiDownload' => 'DownloadSources',
    'TWikiEditingShorthand' => 'EditingShorthand',
    'TWikiEnhancementRequests' => 'EnhancementRequests',
    'TWikiFaqTemplate' => 'FaqTemplate',
    'TWikiFAQ' => 'FrequentlyAskedQuestions',
    'TWikiForms' => 'DataForms',
    'TWikiGlossary' => 'GlossaryOfTerms',
    'TWikiHistory' => 'ReleaseHistory',
    'TWikiInstallationGuide' => 'InstallationGuide',
    'TWikiJavascripts' => 'JavascriptFiles',
    'TWikiLogos' => 'ProjectLogos',
    'TWikiMetaData' => 'MetaData',
    'TWikiPlannedFeatures' => '_remove_',
    'TWikiPlugins' => 'Plugins',
    'TWikiPreferences' => 'DefaultPreferences',
    'TWikiReferenceManual' => 'ReferenceManual',
    'TWikiRegistration' => 'UserRegistration',
    'TWikiReleaseNotes04x00' => '_remove_',
    'TWikiReleaseNotes04x01' => '_remove_',
    'TWikiReleaseNotes04x02' => 'ReleaseNotes01x00',
    'TWikiRenderingShortcut' => 'RenderingShortcut',
    'TWikiScripts' => 'CommandAndCGIScripts',
    'TWikiShorthand' => 'ShortHand',
    'TWikiSiteTools' => 'SiteTools',
    'TWikiSite' => '_remove_',
    'TWikiSkinBrowser' => 'SkinBrowser',
    'TWikiSkins' => 'Skins',
    'TWikiSystemRequirements' => 'SystemRequirements',
    'TWikiTemplates' => 'SkinTemplates',
    'TWikiTemplates' => 'TemplateTopics',
    'TWikiTopics' => 'TopicsAndWebs',
    'TWikiTutorial' => 'TwentyMinuteTutorial',
    'TWikiUpgradeGuide' => 'UpgradeGuide',
    'TWikiUserAuthentication' => 'UserAuthentication',
    'TWikiUsersGuide' => 'UsersGuide',
    'TWikiVariablesQuickStart' => 'MacrosQuickStart',
    'TWikiVariables' => 'Macros',
    'TWikiWebsTable' => 'WebsTable',
    'WhatDoesTWikiStandFor' => '_remove_',
    'TWikiRegistrationAgent' => 'RegistrationAgent',
#TopicUserMapping topics
	'TWikiUserMappingContrib' => 'TopicUserMappingContrib',
	'TWikiUserSetting' => 'UserSetting',
	'TWikiUsersTemplate' => 'UsersTemplate',
};
# **PERL LABEL="Main-Web TopicName Conversion"**
# a hash mapping TWiki's Main web topics to Foswiki's topics
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{MainWebTopicNameConversion} = {
    'TWikiAdminGroup' => 'AdminGroup',
    'TWikiGroupTemplate' => 'GroupTemplate',
    'TWikiPreferences' => 'SitePreferences',
    'TWikiGroups' => 'WikiGroups',
    'TWikiContributor' => 'ProjectContributor',
    'TWikiUsers' => 'WikiUsers',
    'TWikiGuest' => 'WikiGuest',
    'TWikiRegistrationAgent' => 'RegistrationAgent',
    'TWikiAdminUser' => 'AdminUser',
};

# **PERL LABEL="Web Search Path"**
# Used by TWikiCompatibilityPlugin view and viewfile auto-compatibility.
# if a topic or attachment is not found in one web, it will try the other.
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{WebSearchPath} = {
    "$Foswiki::cfg{SystemWebName}" => 'TWiki',
    'TWiki' => "$Foswiki::cfg{SystemWebName}"
};

1;
