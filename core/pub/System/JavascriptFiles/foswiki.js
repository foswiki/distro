/*

THIS COLLECTION OF JAVASCRIPT FUNCTIONS IS DEPRECATED!

Use the Foswiki library classes instead:
foswikilib.js
foswikiArray.js
foswikiCSS.js
foswikiEvent.js
foswikiForm.js
foswikiHTML.js
foswikiPref.js
foswikiString.js, foswikiStringUnicodeChars.js
foswikiWindow.js

When converting to the new classes: some functions may have changed name or parameters.

*/

var POPUP_WINDOW_WIDTH = 500;
var POPUP_WINDOW_HEIGHT = 480;
var POPUP_ATTRIBUTES = "titlebar=0,resizable,scrollbars";

var FOSWIKI_PREF_COOKIE_NAME = "FOSWIKIPREF";
var COOKIE_PREF_SEPARATOR = "|"; // separates key-value pairs
var COOKIE_PREF_VALUE_SEPARATOR = "="; // separates key from value
var COOKIE_EXPIRY_TIME = 365 * 24 * 60 * 60 * 1000; // one year from now

// Constants for the browser type
var ns4 = (document.layers) ? true : false;
var ie4 = (document.all) ? true : false;
var dom = (document.getElementById) ? true : false;

// Unicode conversion tools:
// Convert text to hexadecimal Unicode escape sequence (\uXXXX)
// http://www.hot-tips.co.uk/useful/unicode_converter.HTML
// Convert hexadecimal Unicode escape sequence (\uXXXX) to text
// http://www.hot-tips.co.uk/useful/unicode_convert_back.HTML

// More international characters in unicode_chars.js
// Import file when international support is needed:
// <script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JavascriptFiles/unicode_chars.js"></script>
// unicode_chars.js will overwrite the regexes below

// Info on unicode: http://www.fileformat.info/info/unicode/

var UPPER_ALPHA_CHARS    	= "A-Z";
var LOWER_ALPHA_CHARS		= "a-z";
var NUMERIC_CHARS			= "\\d";
var MIXED_ALPHA_CHARS		= UPPER_ALPHA_CHARS + LOWER_ALPHA_CHARS;
var MIXED_ALPHANUM_CHARS	= MIXED_ALPHA_CHARS + NUMERIC_CHARS;
var LOWER_ALPHANUM_CHARS	= LOWER_ALPHA_CHARS + NUMERIC_CHARS;
var WIKIWORD_REGEX = "^" + "[" + UPPER_ALPHA_CHARS + "]" + "+" + "[" + LOWER_ALPHANUM_CHARS + "]" + "+" + "[" + UPPER_ALPHA_CHARS + "]" + "+" + "[" + MIXED_ALPHANUM_CHARS + "]" + "*";
var ALLOWED_URL_CHARS = MIXED_ALPHANUM_CHARS + "-_^";

// Foswiki namespace
var Foswiki = {};

// Chain a new load handler onto the existing handler chain
// http://simon.incutio.com/archive/2004/05/26/addLoadEvent
// if prepend is true, adds the function to the head of the handler list
// otherwise it will be added to the end (executed last)
function addLoadEvent(func, prepend) {
	var oldonload = window.onload;
	if (typeof window.onload != 'function') {
		window.onload = function() {
			func();
		};
	} else {
		var prependFunc = function() {
			func(); oldonload();
		};
		var appendFunc = function() {
			oldonload(); func();
		};
		window.onload = prepend ? prependFunc : appendFunc;
	}
}

// Stub
function initForm() {
}

// Launch a fixed-size help window
function launchTheWindow(inPath, inWeb, inTopic, inSkin, inTemplate) {

	var pathComps = [];
	if (inWeb != undefined) pathComps.push(inWeb);
	if (inTopic != undefined) pathComps.push(inTopic);
	var pathString = inPath + pathComps.join("/");
	
	var params = [];
	if (inSkin != undefined && inSkin.length > 0) {
		params.push("skin=" + inSkin);
	}
	if (inTemplate != undefined && inTemplate.length > 0) {
		params.push("template=" + inTemplate);
	}
	var paramsString = params.join(";");
	if (paramsString.length > 0) paramsString = "?" + paramsString;
	var name = (inTopic != undefined) ? inTopic : "";
	
	var attributes = [];
	attributes.push("width=" + POPUP_WINDOW_WIDTH);
	attributes.push("height=" + POPUP_WINDOW_HEIGHT);
	attributes.push(POPUP_ATTRIBUTES);
	var attributesString = attributes.join(",");
	
	var win = open(pathString + paramsString, name, attributesString);
	if (win) win.focus();
	return false;
}

/** 
Writes html inside container with id inId.
*/
function insertHtml (inHtml, inId) {
	var elem = document.getElementById(inId);
	if (elem) {
		elem.innerHTML = inHtml;
	}
}

// Remove the given class from an element, if it is there
function removeClass(element, classname) {
	var classes = getClassList(element);
	if (!classes) return;
	var index = indexOf(classname,classes);
	if (index >= 0) {
		classes.splice(index,1);
		setClassList(element, classes);
	}
}

// Add the given class to the element, unless it is already there
function addClass(element, classname) {
	var classes = getClassList(element);
	if (!classes) return;
	if (indexOf(classname, classes) < 0) {
		classes[classes.length] = classname;
		setClassList(element,classes);
	}
}

// Replace the given class with a different class on the element.
// The new class is added even if the old class is not present.
function replaceClass(element, oldclass, newclass) {
	removeClass(element, oldclass);
	addClass(element, newclass);
}

// Get an array of the classes on the object.
function getClassList(element) {
	if (element.className && element.className != "") {
		return element.className.split(' ');
	}
	return [];
}

// Set the classes on an element from an array of class names
// Cache the list in the 'classes' attribute on the element
function setClassList(element, classlist) {
	element.className = classlist.join(' ');
}

// Determine the first index of a string in an array.
// Return -1 if the string is not found.
// WATCH OUT: the refactored function in foswiki.Array returns null with an
// invalid array, but CSS class manipulation functions still rely on a 
// return value of -1
function indexOf(inElement, inArray) {
		if (!inArray || inArray.length == undefined) return -1;
		var i, ilen = inArray.length;
		for (i=0; i<ilen; ++i) {
			if (inArray[i] == inElement) return i;
		}
		return -1;
	}

// Applies the given function to all elements in the document of
// the given tag type
function applyToAllElements(fn, type) {
    var c = document.getElementsByTagName(type);
    for (var j = 0; j < c.length; j++) {
        fn(c[j]);
    }
}

// Determine if the element has the given class string somewhere in it's
// className attribute.
function hasClass(node, className) {
    if (node.className) {
    	var classes = getClassList(node);
    	if (classes) return (indexOf(className, classes) >= 0);
    	return false;
    }
}

/**
Checks if a string is a WikiWord.
@param inValue : string to test
@return True if a WikiWord, false if not.
*/
function isWikiWord(inValue) {
	var re = new RegExp(WIKIWORD_REGEX);
	return (inValue.match(re)) ? true : false;
}

/**
Capitalizes words in the string. For example: "A handy dictionary" becomes "A Handy Dictionary".
*/
String.prototype.capitalize = function() {
	var re = new RegExp("[" + MIXED_ALPHANUM_CHARS + "]+", "g");
    return this.replace(re, function(a) {
        return a.charAt(0).toLocaleUpperCase() + a.substr(1);
    });
};

/**
Returns true if the string is either "on", "true" or "1"; otherwise: false.
*/
String.prototype.toBoolean = function() {
	return (this == "on") || (this == "true") || (this == "1");
};

/**
@deprecated: Use someString.capitalize().
*/
function capitalize(inValue) {
	return inValue.capitalize();
}

/**
Removes spaces from a string. For example: "A Handy Dictionary" becomes "AHandyDictionary".
@param inValue : the string to remove spaces from
@return A new space free string.
*/
function removeSpaces(inValue) {
	var sIn = inValue;
	var sOut = '';
	for ( var i = 0; i < sIn.length; i++ ) {
		var ch = sIn.charAt( i );
		if( ch==' ' ) {
			chgUpper = true;
			continue;
		}
		sOut += ch;
	}
	return sOut;
}

/**
Removes punctuation characters from a string. For example: "A/Z" becomes "AZ".
@param inValue : the string to remove chars from
@return A new punctuation free string.
*/
function removePunctuation(inValue) {
	var allowedRegex = "[^" + ALLOWED_URL_CHARS + "]";
	var re = new RegExp(allowedRegex, "g");
  	return inValue.replace(re, "");
}

/**
Combines removePunctuation and removeSpaces.
*/
function removeSpacesAndPunctuation(inValue) {
	return removePunctuation(removeSpaces(inValue));
}

/**
Creates a WikiWord from a string. For example: "A handy dictionary" becomes "AHandyDictionary".
@param inValue : the string to wikiwordize
@return A new WikiWord string.
*/
function makeWikiWord(inString) {
	return removeSpaces(capitalize(inString));
}

/**
Javascript query string parsing.
Author: djohnson@ibsys.com {{djohnson}} - you may use this file as you wish but please keep this header with it thanks
@use 
Pass location.search to the constructor:
<code>var myPageQuery = new PageQuery(location.search)</code>
Retrieve values
<code>var myValue = myPageQuery.getValue("param1")</code>
*/
Foswiki.PageQuery = function (q) {
	if (q.length > 1) {
		this.q = q.substring(1, q.length);
	} else {
		this.q = null;
	}
	this.keyValuePairs = new Array();
	if (q) {
		for(var i=0; i < this.q.split(/[&;]/).length; i++) {
			this.keyValuePairs[i] = this.q.split(/[&;]/)[i];
		}
	}
}
Foswiki.PageQuery.prototype.getKeyValuePairs = function() {
	return this.keyValuePairs;
}
/**
@return The query string value; if not found returns -1.
*/
Foswiki.PageQuery.prototype.getValue = function (s) {
	for(var j=0; j < this.keyValuePairs.length; j++) {
		if(this.keyValuePairs[j].split(/=/)[0] == s)
			return this.keyValuePairs[j].split(/=/)[1];
	}
	return -1;
}
Foswiki.PageQuery.prototype.getParameters = function () {
	var a = new Array(this.getLength());
	for(var j=0; j < this.keyValuePairs.length; j++) {
		a[j] = this.keyValuePairs[j].split(/=/)[0];
	}
	return a;
}
Foswiki.PageQuery.prototype.getLength = function() {
	return this.keyValuePairs.length;
}

// COOKIE FUNCTIONS

/**
Add a cookie. If 'days' is set to a non-zero number of days, sets an expiry on the cookie.
@deprecated Use setPref.
*/
function writeCookie(name,value,days) {
	var expires = "";
	if (days) {
		var date = new Date();
		date.setTime(date.getTime()+(days*24*60*60*1000));
		expires = "; expires="+date.toGMTString();
	}
	// cumulative
	document.cookie = name + "=" + value + expires + "; path=/";
}

/**
Reads the named cookie and returns the value.
@deprecated Use getPref.
*/
function readCookie(name) { 
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	if (ca.length == 0) {
		ca = document.cookie.split(';');
	}
	for (var i=0;i < ca.length;++i) {
		var c = ca[i];
		while (c.charAt(0)==' ')
            c = c.substring(1,c.length);
		if (c.indexOf(nameEQ) == 0)
            return c.substring(nameEQ.length,c.length);
	}
	return null;
}

/**
Writes a Foswiki preference value. If the Foswiki preference of given name already exists, a new value is written. If the preference name is new, a new preference is created.
Characters '|' and '=' are reserved as separators.
@param inPrefName (String): name of the preference to write, for instance 'SHOWATTACHMENTS'
@param inPrefValue (String): value to write, for instance '1'
*/
function setPref(inPrefName, inPrefValue) {
	var prefName = _getSafeString(inPrefName);
	var prefValue = (isNaN(inPrefValue)) ? _getSafeString(inPrefValue) : inPrefValue;
	var cookieString = _getPrefCookie();
	var prefs = cookieString.split(COOKIE_PREF_SEPARATOR);
	var index = _getKeyValueLoc(prefs, prefName);
	if (index != -1) {
		// updating this entry is done by removing the existing entry from the array and then pushing the new key-value onto it
		prefs.splice(index, 1);
	}
	// else not found, so don't remove an existing entry
	var keyvalueString = prefName + COOKIE_PREF_VALUE_SEPARATOR + prefValue;
	prefs.push(keyvalueString);
	_writePrefValues(prefs);
}

/**
Reads the value of a preference.
Characters '|' and '=' are reserved as separators.
@param inPrefName (String): name of the preference to read, for instance 'SHOWATTACHMENTS'
@return The value of the preference; an empty string when no value is found.
*/
function getPref(inPrefName) {
	var prefName = _getSafeString(inPrefName);
	return getPrefValueFromPrefList(prefName, getPrefList());
}

/**
Reads the value of a preference from an array of key-value pairs. Use in conjunction with getPrefList() when you want to store the key-value pairs for successive look-ups.
@param inPrefName (String): name of the preference to read, for instance 'SHOWATTACHMENTS'
@param inPrefList (Array): list of key-value pairs, retrieved with getPrefList()
@return The value of the preference; an empty string when no value is found.
*/
function getPrefValueFromPrefList (inPrefName, inPrefList) {
	var keyvalue = _getKeyValue(inPrefList, inPrefName);
	if (keyvalue != null) return keyvalue[1];
	return '';
}

/**
@return The array of key-value pairs.
*/
function getPrefList () {
	var cookieString = _getPrefCookie();
	if (!cookieString) return null;
	return cookieString.split(COOKIE_PREF_SEPARATOR);
}

/**
Finds a key-value pair in an array.
@param inKeyValues: (Array) the array to iterate
@param inKey: (String) the key to find in the array
@return The first occurrence of a key-value pair, where key == inKey; null if none is found.
*/
function _getKeyValue (inKeyValues, inKey) {
	if (!inKeyValues) return null;
	var i = inKeyValues.length;
	while (i--) {
		var keyvalue = inKeyValues[i].split(COOKIE_PREF_VALUE_SEPARATOR);
		if (keyvalue[0] == inKey) return keyvalue;	
	}
	return null;
}

/**
Finds the location of a key-value pair in an array.
@param inKeyValues: (Array) the array to iterate
@param inKey: (String) the key to find in the array
@return The location of the first occurrence of a key-value tuple, where key == inKey; -1 if none is found.
*/
function _getKeyValueLoc (inKeyValues, inKey) {
	if (!inKeyValues) return null;
	var i = inKeyValues.length;
	while (i--) {
		var keyvalue = inKeyValues[i].split(COOKIE_PREF_VALUE_SEPARATOR);
		if (keyvalue[0] == inKey) return i;	
	}
	return -1;
}

/**
Writes a cookie with the stringified array values of inValues.
@param inValues: (Array) an array with key-value tuples
*/
function _writePrefValues (inValues) {
	var cookieString = (inValues != null) ? inValues.join(COOKIE_PREF_SEPARATOR) : '';
	var expiryDate = new Date ();
	FixCookieDate (expiryDate); // Correct for Mac date bug - call only once for given Date object!
	expiryDate.setTime (expiryDate.getTime() + COOKIE_EXPIRY_TIME);
	SetCookie(FOSWIKI_PREF_COOKIE_NAME, cookieString, expiryDate, '/');
}

/**
Gets the Foswiki pref cookie; creates a new cookie if it does not exist.
@return The Foswiki pref cookie.
*/
function _getPrefCookie () {
	var cookieString = GetCookie(FOSWIKI_PREF_COOKIE_NAME);
	if (cookieString == undefined) {
		cookieString = "";
	}
	return cookieString;
}

/**
Strips reserved characters '|' and '=' from the input string.
@return The stripped string.
*/
function _getSafeString (inString) {
	var regex = new RegExp(/[|=]/);
	return inString.replace(regex, "");
}

//
//  Cookie Functions -- "Night of the Living Cookie" Version (25-Jul-96)
//
//  Written by:  Bill Dortch, hIdaho Design <bdortch@hidaho.com>
//  The following functions are released to the public domain.
//

//
// "Internal" function to return the decoded value of a cookie
//
function getCookieVal (offset) {
  var endstr = document.cookie.indexOf (";", offset);
  if (endstr == -1)
    endstr = document.cookie.length;
  return unescape(document.cookie.substring(offset, endstr));
}
//
//  Function to correct for 2.x Mac date bug.  Call this function to
//  fix a date object prior to passing it to SetCookie.
//  IMPORTANT:  This function should only be called *once* for
//  any given date object!  See example at the end of this document.
//
function FixCookieDate (date) {
  var base = new Date(0);
  var skew = base.getTime(); // dawn of (Unix) time - should be 0
  if (skew > 0)  // Except on the Mac - ahead of its time
    date.setTime (date.getTime() - skew);
}
//
//  Function to return the value of the cookie specified by "name".
//    name - String object containing the cookie name.
//    returns - String object containing the cookie value, or null if
//      the cookie does not exist.
//
function GetCookie (name) {
	var arg = name + "=";
	var alen = arg.length;
	var clen = document.cookie.length;
	var i = 0;
	while (i < clen) {
		var j = i + alen;
		if (document.cookie.substring(i, j) == arg) {
			return getCookieVal(j);
		}
		i = document.cookie.indexOf(" ", i) + 1;
		if (i == 0) break; 
	}
	return null;
}
//
//  Function to create or update a cookie.
//    name - String object containing the cookie name.
//    value - String object containing the cookie value.  May contain
//      any valid string characters.
//    [expires] - Date object containing the expiration data of the cookie.  If
//      omitted or null, expires the cookie at the end of the current session.
//    [path] - String object indicating the path for which the cookie is valid.
//      If omitted or null, uses the path of the calling document.
//    [domain] - String object indicating the domain for which the cookie is
//      valid.  If omitted or null, uses the domain of the calling document.
//    [secure] - Boolean (true/false) value indicating whether cookie transmission
//      requires a secure channel (HTTPS).  
//
//  The first two parameters are required.  The others, if supplied, must
//  be passed in the order listed above.  To omit an unused optional field,
//  use null as a place holder.  For example, to call SetCookie using name,
//  value and path, you would code:
//
//      SetCookie ("myCookieName", "myCookieValue", null, "/");
//
//  Note that trailing omitted parameters do not require a placeholder.
//
//  To set a secure cookie for path "/myPath", that expires after the
//  current session, you might code:
//
//      SetCookie (myCookieVar, cookieValueVar, null, "/myPath", null, true);
//
function SetCookie (name,value,expires,path,domain,secure) {
  var cookieString = name + "=" + escape (value) +
    ((expires) ? "; expires=" + expires.toGMTString() : "") +
    ((path) ? "; path=" + path : "") +
    ((domain) ? "; domain=" + domain : "") +
    ((secure) ? "; secure" : "");
    document.cookie = cookieString;
}

//  Function to delete a cookie. (Sets expiration date to start of epoch)
//    name -   String object containing the cookie name
//    path -   String object containing the path of the cookie to delete. This MUST
//             be the same as the path used to create the cookie, or null/omitted if
//             no path was specified when creating the cookie.
//    domain - String object containing the domain of the cookie to delete.  This MUST
//             be the same as the domain used to create the cookie, or null/omitted if
//             no domain was specified when creating the cookie.
//
function DeleteCookie (name,path,domain) {
	if (GetCookie(name)) {
		document.cookie = name + "=" + ((path) ? "; path=" + path : "") + ((domain) ? "; domain=" + domain : "") + "; expires=Thu, 01-Jan-70 00:00:01 GMT";
	}
}
