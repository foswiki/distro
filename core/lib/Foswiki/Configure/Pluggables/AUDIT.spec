# This file defines the AUDIT groups
#
# The object of groups is to have a small number of buttons that do a large number
# of checks.  They should all fit on a reasonably sized screen - so more buttons in
# one heading is preferable to lots of subheadings with one button each.
#
# But logical organization is important, too.  Bottons left to right should either
# be partitions of a heading, or increasing test strength/repair impact.
#
# Syntax:
# Lines can be arbitrarily long, or continued with \.  Leading whitespace on continuation
# lines is ignored, but space before the \ is significant.
#
# Blank lines are ignored.
#
# #! Comments (anywhere in file)
#
# # Comment lines (after this first block) are added to item/section descriptions.
#   As with Foswiki/Config.spec, this is HTML text.
#   Note that unlike Foswiki/Config.spec, description for items FOLLOWs the item
#   declaration.
#
# #---++ heading text -- options
#        Top level section heading - more +s for deeper levels
# {key}{s} [G:b G:b] [type] options
#        Defines an audit group.
#        {Key}{s} are the hash keys used to find the AuditGroup handler for this group
#        There are checkers (Foswiki::Configure::Checkers::Key::s) for each group.
#        Normally, these would be null derrivations from AUDITGROUP, but other things are possible.
#        G:b are the GroupName of the parameters to be audited, and the Audit Button number
#        GroupNames _* are reserved for internal functions.  _none is used for environment data
#        not directly related to any item.
#        that is pressed to select that group.
#        type is the TYPE used to display the item.  Usually NULL, but can be any item in Types;
#        e.g. when an audit produces a short result.  Defaults to NULL.
#        options are the usual item options - note that AUDIT is usually meaningless for
#        these items (except when they have dual auditor/item roles),
#        but FEEDBACK is used to define an audit button, CHECK and LABEL are also meaningful.
#
# __END__ Stops processing; legal notices or comments can be placed after this token.
#
#! Basic checks re-runs checkers from inital page load.  PARS:0 is
#! defined for all items loaded from a Config/Foswiki.spec file
#!
#! Extended basic also includes feedback selected in the config.spec files
#!
#---++ Basic checks
# Click the <b>Cursory checks</b> action button to re-run the checks
# performed when you entered <tt>configure</tt>.  These are quick,
# but important checks.<br />
# Click the <b>Extended checks</b> action button to run these and
# selected extended checks.
#!
{ConfigParams} [PARS PARS:2 EPARS:2] NOLABEL FEEDBACK="Cursory checks" FEEDBACK="Extended checks"
#!
#---++ Web server & Environment
# These action buttons analyze the webserver and Foswiki environments.
#!
#! CGISetup is both an auditor and an item checker.  The items are checked with
#! virtual buttons >= 100.
#!
#! The audit groups for the auditor use the standard button numbers.
#! Note that other items can be added by making them a member of one of these
#! audit groups.  (e.g. to add {foo} checker to the Webserver audit, in
#! Foswiki.spec, declare {foo} with AUDIT="CGI:0"

{CGISetup} [CGI CORE:2 EXTN:3] NOLABEL AUDIT="CGI:101 CORE:102 EXTN:103" \
                                       FEEDBACK="Web server";pinfo='/test/pathinfo' \
                                       FEEDBACK="Foswiki" \
                                       FEEDBACK="Extensions" 

#! Buttons can control overlapping groups, which can be usefule for a series of tests that
#! include supersets.
#!{CGISetup} [CGI CORE:2 EXTN:3 CGI:4 CORE:4 EXTN:4] NOLABEL AUDIT="CGI:101 CORE:102 EXTN:103" \
#!                                                           FEEDBACK="Web server";pinfo='/test/pathinfo' \
#!                                                           FEEDBACK="Foswiki" \
#!                                                           FEEDBACK="Extensions" \
#!                                                           FEEDBACK="Everything";pinfo='/test/pathinfo'

# Click the Webserver action button to analyze and display the webserver environment.
{ConfigureGUI}{PATHINFO} [_none] [PATHINFO] LABEL="<span class=\"configureItemLabel\">\
                                                    <b>PathInfo</b> test results</span>"
# Extended path information (PATH_INFO) is used to provide arguments to CGI scripts
# such as configure. 
# <p>Verifying that your webserver correctly delivers PATH_INFO is particularly
# important if you are using mod_perl, Apache or IIS, or are using a web hosting
# provider, as these environments are frequently misconfigured or running out-of-date software.
# <p>When you click <strong>Analyze Environment</strong>, configure tests PATH_INFO
# by making a special request to itself with known PATH_INFO. Configure verifies that
# it receives the correct information from the webserver.
# <p>Any error that is detected by this test will be reported above.

#! Initially, this includes the extended paths/permissions checks.
#! Intention is to add storage (e.g. database backends, etc) to this section.
#---++ Disks & Storage
# Click the action button to analyze paths and permissions<br />Note that you can
# perform these checks for individual items under the General path settings tab.
{DisksAndStorage} [DIRS] NOLABEL FEEDBACK="Analyze"


__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
