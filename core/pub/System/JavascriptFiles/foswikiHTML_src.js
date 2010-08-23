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
 * HTML utility functions.
 * *Not used by core Foswiki* - kept for compatibility only.
 * Requires: JQUERYPLUGIN::FOSWIKI
 */

foswiki.HTML = {

	/**
     * Writes HTML to an HTMLElement.
     * @param inId : (String) id of element to write to
     * @param inHtml : (String) HTML to write
     * @return The updated HTMLElement
     */
	setHtmlOfElementWithId:function(inId, inHtml) {
		var elem = document.getElementById(inId);
		return foswiki.HTML.setHtmlOfElement(elem, inHtml);
	},
	
	/**
     * Writes HTML to HTMLElement el.
     * @param el : (HTMLElement) element to write to
     * @param inHtml : (String) HTML to write
     * @return The updated HTMLElement
     */
	setHtmlOfElement:function(el, inHtml) {
		if (!el || inHtml == undefined)
            return null;
		el.innerHTML = inHtml;
		return el;
	},
	
	/**
     * Returns the HTML contents of element with id inId.
     * @param inId : (String) id of element to get contents of
     * @return HTLM contents string.
     */
	getHtmlOfElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return foswiki.HTML.getHtmlOfElement(elem);
	},
	
	/**
     * Returns the HTML contents of element el.
     * @param el : (HTMLElement) element to get contents of
     * @return HTLM contents string.
     */
	getHtmlOfElement:function(el) {
		if (!el)
            return null;
		return el.innerHTML;
	},
	
	/**
     * Clears the contents of element inId.
     * @param inId : (String) id of element to clear the contents of
     * @return The cleared HTMLElement.
     */
	clearElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return foswiki.HTML.clearElement(elem);
	},
	
	/**
     * Clears the contents of element el.
     * @param el (HTMLElement) : object to clear
     */
	clearElement:function(el) {
		if (!el)
            return null;
		foswiki.HTML.setHtmlOfElement(el, "");
		return el;
	},
	
	/**
     * untested
     */
	deleteElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		return foswiki.HTML.deleteElement(elem);
	},
	
	/**
     * untested
     */
	deleteElement:function(el) {
		if (!el)
            return null;
		el.parentNode.removeChild(el);
		return el;
	},
	
	/**
     * Inserts a new HTMLElement after an existing element.
     * @param el : (HTMLElement) (required) the element to insert after
     * @param inType : (String) (required) element type of the new
     * HTMLElement: 'p', 'b', 'span', etc
     * @param inHtmlContents : (String) (optional) element HTML contents
     * @param inAttributes : (Object) (optional) value object with attributes
     * to set to the new element
     * @return The new HTMLElement
     * @use
     * <pre>
     * foswiki.HTML.insertAfterElement(
     *   		document.getElementById('title'),
     *   		'div',
     *   		'<strong>not published</strong>',
     *   		{
     *   			"style":
     *   				{
     *   					"backgroundColor":"#f00",
     *   					"color":"#fff"
     *   				}
     *   		}
     *   	);
     * </pre>
     */
	insertAfterElement:function(el, inType, inHtmlContents, inAttributes) {
		if (!el || !inType)
            return null;
		var newElement = foswiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			el.appendChild(newElement);
			return newElement;
		}
		return null;
	},
	
	/**
     * Inserts a new HTMLElement before an existing element.
     * @param el : (HTMLElement) (required) the element to insert before
     * @param inType : (String) (required) element type of the new
     * HTMLElement: 'p', 'b', 'span', etc
     * @param inHtmlContents : (String) (optional) element HTML contents
     * @param inAttributes : (Object) (optional) value object with attributes
     * to set to the new element
     * @return The new HTMLElement
     */
	insertBeforeElement:function(el, inType, inHtmlContents, inAttributes) {
		if (!el || !inType) return null;
		var newElement = foswiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			el.parentNode.insertBefore(newElement, el);
			return newElement;
		}
		return null;
	},
	
	/**
     * Replaces an existing HTMLElement with a new element.
     * @param el : (HTMLElement) (required) the existing element to replace
     * @param inType : (String) (required) element type of the new
     * HTMLElement: 'p', 'b', 'span', etc
     * @param inHtmlContents : (String) (optional) element HTML contents
     * @param inAttributes : (Object) (optional) value object with attributes
     * to set to the new element
     * @return The new HTMLElement
     */
	replaceElement:function(el, inType, inHtmlContents, inAttributes) {
		if (!el || !inType)
            return null;
		var newElement = foswiki.HTML._createElementWithTypeAndContents(
			inType,
			inHtmlContents,
			inAttributes
		);
		if (newElement) {
			el.parentNode.replaceChild(newElement, el);
			return newElement;
		}
		return null;
	},
	
	/**
     * PRIVATE
     * Creates a new HTMLElement. See insertAfterElement, insertBeforeElement
     * and replaceElement.
     * @return The new HTMLElement
	*/
	_createElementWithTypeAndContents:function(
        inType, inHtmlContents, inAttributes) {
		var newElement = document.createElement(inType);
		if (inHtmlContents != undefined) {
			newElement.innerHTML = inHtmlContents;
		}
		if (inAttributes != undefined) {
			foswiki.HTML.setElementAttributes(newElement, inAttributes);
		}
		return newElement;
	},

	/**
     * Passes attributes from value object inAttributes to all nodes in
     * NodeList inNodeList.
     * @param inNodeList : (NodeList) nodes to set the style of
     * @param inAttributes : (Object) value object with element properties,
     * with stringified keys. For example, use "class":"foswikiSmall" to set
     * the class. This cannot be a property key written as <code>class</code>
     * because this is a reserved keyword.
     * @use
     * In this example all NodeList elements get assigend a class and style:
     * <pre>
     * var elem = document.getElementById("my_div");
     * var nodeList = elem.getElementsByTagName('ul')
     * var attributes = {
     * 	"class":"foswikiSmall foswikiGrayText",
     *   	"style":
     *   		{
     *   			"fontSize":"20px",
     *   			"backgroundColor":"#444",
     *   			"borderLeft":"5px solid red",
     * 			"margin":"0 0 1em 0"
     *   		}
     *   	};
     * foswiki.HTML.setNodeAttributesInList(nodeList, attributes);
     * </pre>
     */
	setNodeAttributesInList:function (inNodeList, inAttributes) {
		if (!inNodeList)
            return;
		var i, ilen = inNodeList.length;
		for (i=0; i<ilen; ++i) {
			var elem = inNodeList[i];
			foswiki.HTML.setElementAttributes(elem, inAttributes);
		}
	},
	
	/**
     * Sets attributes to an HTMLElement.
     * @param el : (HTMLElement) element to set attributes to
     * @param inAttributes : (Object) value object with attributes
     */
	setElementAttributes:function (el, inAttributes) {
		for (var attr in inAttributes) {
			if (attr == "style") {
				var styleObject = inAttributes[attr];
				for (var style in styleObject) {
					el.style[style] = styleObject[style];
				}
			} else {
				//el.setAttribute(attr, inAttributes[attr]);
				el[attr] = inAttributes[attr];
			}
		}
	}
	
};
