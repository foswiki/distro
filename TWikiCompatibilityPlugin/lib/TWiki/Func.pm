# See bottom of file for license and copyright information
package TWiki::Func;

# Bridge between TWiki::Func and Foswiki::Func

use strict;
use warnings;

use Foswiki::Func;
use Foswiki::Plugins;
use TWiki::Plugins;

sub getSkin             { Foswiki::Func::getSkin(@_) }
sub getUrlHost          { Foswiki::Func::getUrlHost(@_) }
sub getScriptUrl        { Foswiki::Func::getScriptUrl(@_) }
sub getViewUrl          { Foswiki::Func::getViewUrl(@_) }
sub getPubUrlPath       { Foswiki::Func::getPubUrlPath(@_) }
sub getExternalResource { Foswiki::Func::getExternalResource(@_) }
sub getCgiQuery         { Foswiki::Func::getCgiQuery(@_) }
sub getSessionKeys      { Foswiki::Func::getSessionKeys(@_) }
sub getSessionValue     { Foswiki::Func::getSessionValue(@_) }
sub setSessionValue     { Foswiki::Func::setSessionValue(@_) }
sub clearSessionValue   { Foswiki::Func::clearSessionValue(@_) }
sub getContext          { Foswiki::Func::getContext(@_) }
sub pushTopicContext    { Foswiki::Func::pushTopicContext(@_) }
sub popTopicContext     { Foswiki::Func::popTopicContext(@_) }
sub getPreferencesValue { Foswiki::Func::getPreferencesValue(@_) }
sub getPreferencesFlag  { Foswiki::Func::getPreferencesFlag(@_) }

sub getPluginPreferencesValue {
    my $key     = shift;
    my $package = caller;
    $package =~ s/.*:://;    # strip off TWiki::Plugins:: prefix
    return Foswiki::Func::getPreferencesValue("\U$package\E_$key");
}

sub getPluginPreferencesFlag {
    my $key     = shift;
    my $package = caller;
    $package =~ s/.*:://;    # strip off TWiki::Plugins:: prefix
    return Foswiki::Func::getPreferencesFlag("\U$package\E_$key");
}

sub setPreferencesValue   { Foswiki::Func::setPreferencesValue(@_) }
sub getDefaultUserName    { Foswiki::Func::getDefaultUserName(@_) }
sub getCanonicalUserID    { Foswiki::Func::getCanonicalUserID(@_) }
sub getWikiName           { Foswiki::Func::getWikiName(@_) }
sub getWikiUserName       { Foswiki::Func::getWikiUserName(@_) }
sub wikiToUserName        { Foswiki::Func::wikiToUserName(@_) }
sub userToWikiName        { Foswiki::Func::userToWikiName(@_) }
sub emailToWikiNames      { Foswiki::Func::emailToWikiNames(@_) }
sub wikinameToEmails      { Foswiki::Func::wikinameToEmails(@_) }
sub isGuest               { Foswiki::Func::isGuest(@_) }
sub isAnAdmin             { Foswiki::Func::isAnAdmin(@_) }
sub isGroupMember         { Foswiki::Func::isGroupMember(@_) }
sub eachUser              { Foswiki::Func::eachUser(@_) }
sub eachMembership        { Foswiki::Func::eachMembership(@_) }
sub eachGroup             { Foswiki::Func::eachGroup(@_) }
sub isGroup               { Foswiki::Func::isGroup(@_) }
sub eachGroupMember       { Foswiki::Func::eachGroupMember(@_) }
sub checkAccessPermission { Foswiki::Func::checkAccessPermission(@_) }
sub getListOfWebs         { Foswiki::Func::getListOfWebs(@_) }
sub webExists             { Foswiki::Func::webExists(@_) }
sub createWeb             { Foswiki::Func::createWeb(@_) }
sub moveWeb               { Foswiki::Func::moveWeb(@_) }
sub eachChangeSince       { Foswiki::Func::eachChangeSince(@_) }
sub getTopicList          { Foswiki::Func::getTopicList(@_) }
sub topicExists           { Foswiki::Func::topicExists(@_) }
sub checkTopicEditLock    { Foswiki::Func::checkTopicEditLock(@_) }
sub setTopicEditLock      { Foswiki::Func::setTopicEditLock(@_) }
sub saveTopic             { Foswiki::Func::saveTopic(@_) }
*saveTopicText = \&Foswiki::Func::saveTopicText;
sub moveTopic         { Foswiki::Func::moveTopic(@_) }
sub getRevisionInfo   { Foswiki::Func::getRevisionInfo(@_) }
sub getRevisionAtTime { Foswiki::Func::getRevisionAtTime(@_) }
sub readTopic         { Foswiki::Func::readTopic(@_) }
sub readTopicText     { Foswiki::Func::readTopicText(@_) }
sub attachmentExists  { Foswiki::Func::attachmentExists(@_) }
sub readAttachment    { Foswiki::Func::readAttachment(@_) }
sub saveAttachment    { Foswiki::Func::saveAttachment(@_) }
sub moveAttachment    { Foswiki::Func::moveAttachment(@_) }
sub readTemplate      { Foswiki::Func::readTemplate(@_) }
sub loadTemplate      { Foswiki::Func::loadTemplate(@_) }
sub expandTemplate    { Foswiki::Func::expandTemplate(@_) }

# The following parameters were previously supported on this function but have
# been deprecated and are ignored.
#    * =$query= - *DEPRECATED* CGI query object.
#    * =$length= - *DEPRECATED* The content length
sub writeHeader {
    my ( $query, $length ) = @_;
    if ( $query && $query != Foswiki::Func::getCgiQuery() ) {
        Foswiki::Func::writeWarning( join( ' ', caller ) . <<MESS);
 called TWiki::Func::writeHeader with a query parameter that does not match the current query. This could result in unpredictable behaviour.
MESS
    }
    if ($length) {
        Foswiki::Func::writeWarning( join( ' ', caller ) . <<MESS);
 called TWiki::Func::writeHeader with a length parameter. This parameter is deprecated, and will be ignored.
MESS
    }
    Foswiki::Func::writeHeader();
}

sub redirectCgiQuery      { Foswiki::Func::redirectCgiQuery(@_) }
sub addToHEAD             { Foswiki::Func::addToHEAD(@_) }
sub expandCommonVariables { Foswiki::Func::expandCommonVariables(@_) }
sub renderText            { Foswiki::Func::renderText(@_) }
sub internalLink          { Foswiki::Func::internalLink(@_) }
sub sendEmail             { Foswiki::Func::sendEmail(@_) }
sub wikiToEmail           { Foswiki::Func::wikiToEmail(@_) }

sub expandVariablesOnTopicCreation {
    Foswiki::Func::expandVariablesOnTopicCreation(@_);
}
*registerTagHandler  = \&Foswiki::Func::registerTagHandler;
*registerRESTHandler = \&Foswiki::Func::registerRESTHandler;
sub decodeFormatTokens     { Foswiki::Func::decodeFormatTokens(@_) }
sub searchInWebContent     { Foswiki::Func::searchInWebContent(@_) }
sub getWorkArea            { Foswiki::Func::getWorkArea(@_) }
sub readFile               { Foswiki::Func::readFile(@_) }
sub saveFile               { Foswiki::Func::saveFile(@_) }
sub getRegularExpression   { Foswiki::Func::getRegularExpression(@_) }
sub normalizeWebTopicName  { Foswiki::Func::normalizeWebTopicName(@_) }
sub sanitizeAttachmentName { Foswiki::Func::sanitizeAttachmentName(@_) }
sub spaceOutWikiWord       { Foswiki::Func::spaceOutWikiWord(@_) }
*writeWarning = \&Foswiki::Func::writeWarning;
sub writeDebug           { Foswiki::Func::writeDebug(@_) }
sub formatTime           { Foswiki::Func::formatTime(@_) }
sub isTrue               { Foswiki::Func::isTrue(@_) }
sub isValidWikiWord      { Foswiki::Func::isValidWikiWord(@_) }
sub extractParameters    { Foswiki::Func::extractParameters(@_) }
sub extractNameValuePair { Foswiki::Func::extractNameValuePair(@_) }
sub getScriptUrlPath     { Foswiki::Func::getScriptUrlPath(@_) }
sub getWikiToolName      { Foswiki::Func::getWikiToolName(@_) }
sub getMainWebname       { Foswiki::Func::getMainWebname(@_) }
sub getTwikiWebname      { Foswiki::Func::getTwikiWebname(@_) }
sub getOopsUrl           { Foswiki::Func::getOopsUrl(@_) }
sub permissionsSet       { Foswiki::Func::permissionsSet(@_) }
sub getPublicWebList     { Foswiki::Func::getPublicWebList(@_) }
sub formatGmTime         { Foswiki::Func::formatGmTime(@_) }
sub getDataDir           { Foswiki::Func::getDataDir(@_) }
sub getPubDir            { Foswiki::Func::getPubDir(@_) }
sub checkDependencies    { Foswiki::Func::checkDependencies(@_) }

# For extender.pl
sub TWiki::Extender::install { Foswiki::Extender::install(@_) }

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
