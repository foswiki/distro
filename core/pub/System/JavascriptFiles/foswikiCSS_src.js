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

Author: Arthur Clemens

*/

/**
 * Functions for manipulating class attributes.
 * *Not used by core Foswiki* - kept for compatibility only.
 * Requires JQUERYPLUGIN::FOSWIKI
 */
foswiki.CSS = {
    
	/**
     * Remove the given class from an element, if it is there.
     * @param el : (HTMLElement) element to remove the class of
     * @param inClassName : (String) CSS class name to remove
     */
	removeClass:function(el, inClassName) {
		if (!el) return;
		var classes = foswiki.CSS.getClassList(el);
		if (!classes) return;
		var index = foswiki.CSS._indexOf(classes, inClassName);
		if (index >= 0) {
			classes.splice(index,1);
			foswiki.CSS.setClassList(el, classes);
		}
	},
    
	/**
     * Add the given class to the element, unless it is already there.
     * @param el : (HTMLElement) element to add the class to
     * @param inClassName : (String) CSS class name to add
     */
	addClass:function(el, inClassName) {
		if (!el) return;
		var classes = foswiki.CSS.getClassList(el);
		if (!classes) return;
		if (foswiki.CSS._indexOf(classes, inClassName) < 0) {
			classes[classes.length] = inClassName;
			foswiki.CSS.setClassList(el,classes);
		}
	},
    
	/**
     * Replace the given class with a different class on the element.
     * The new class is added even if the old class is not present.
     * @param el : (HTMLElement) element to replace the class of
     * @param inOldClass : (String) CSS class name to remove
     * @param inNewClass : (String) CSS class name to add
     */
	replaceClass:function(el, inOldClass, inNewClass) {
		if (!el) return;
		foswiki.CSS.removeClass(el, inOldClass);
		foswiki.CSS.addClass(el, inNewClass);
	},
    
	/**
     * Get an array of the classes on the object.
     * @param el : (HTMLElement) element to get the class list from
     */
	getClassList:function(el) {
		if (!el) return;
		if (el.className && el.className != "") {
			return el.className.split(' ');
		}
		return [];
	},
    
	/**
     * Set the classes on an element from an array of class names.
     * @param el : (HTMLElement) element to set the class list to
     * @param inClassList : (Array) list of CSS class names
     */
	setClassList:function(el, inClassList) {
		if (!el) return;
		el.className = inClassList.join(' ');
	},
    
	/**
     * Determine if the element has the given class string somewhere in it's
     * className attribute.
     * @param el : (HTMLElement) element to check the class occurrence of
     * @param inClassName : (String) CSS class name
     */
	hasClass:function(el, inClassName) {
		if (!el) return;
		if (el.className) {
			var classes = foswiki.CSS.getClassList(el);
			if (classes) return (foswiki.CSS._indexOf(classes, inClassName) >= 0);
			return false;
		}
	},
    
    // PRIVATE
	_indexOf:function(inArray, el) {
		if (!inArray || inArray.length == undefined) return null;
		var i, ilen = inArray.length;
		for (i=0; i<ilen; ++i) {
			if (inArray[i] == el) return i;
		}
		return -1;
	}
};
