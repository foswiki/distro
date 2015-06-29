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

Based on code written by Simon Willison,
see http://simonwillison.net/2004/May/26/addLoadEvent/

*/

/*
 * Event handling.
 * *Not used by core Foswiki* - kept for compatibility only.
 */
foswiki.Event = {

	/**
     * Chain a new load handler onto the existing handler chain
     * @param inFunction : (Function) function to add
     * @param inDoPrepend : (Boolean) if true: adds the function to the
     * head of the handler list; otherwise it will be added to the end
     * (executed last)
     */
	addLoadEvent:function (inFunction, inDoPrepend) {
		if (typeof(inFunction) != "function") {
			return;
		}
		var oldonload = window.onload;
		if (typeof window.onload != 'function') {
			window.onload = function() {
				inFunction();
			};
		} else {
			var prependFunc = function() {
				inFunction(); oldonload();
			};
			var appendFunc = function() {
				oldonload(); inFunction();
			};
			window.onload = inDoPrepend ? prependFunc : appendFunc;
		}
	}
	
};
