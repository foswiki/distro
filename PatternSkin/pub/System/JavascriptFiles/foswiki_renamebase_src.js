/*

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

*/

/**
 * *Not used by core Foswiki* - kept for compatibility only.
 * Support for rename screen.
 */

/**
 * Checks/unchecks all checkboxes in form inForm.
 * SMELL: should use a class and should be moved to the form lib
 */
function checkAll(inForm, inState) {
	// find button element index
	if (inForm == undefined) return;
	var i, j = 0;
	for (i = 0; i < inForm.length; ++i) {
		if (inForm.elements[i].name.match("referring_topics")) {
			inForm.elements[i].checked = inState;
		}
	}
}
