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

Based on code written by Bill Dortch, hIdaho Design <bdortch@hidaho.com>

*/

/**
 * Store preferences in cookies.
 * Based on "Night of the Living Cookie" Version (25-Jul-96)
 * The preferred way for reading and writing cookies is using getPref
 * and setPref, otherwise the limit of 20 cookies per domain is reached
 * soon. See http://foswiki.org/Support/DataStorageInUserCookie
 *
 * Requires: JQUERYPLUGIN::FOSWIKI
 */

foswiki.Pref = {
	
	FOSWIKI_PREF_COOKIE_NAME:"FOSWIKIPREF",
	/**
	Separates key-value pairs
	*/
	COOKIE_PREF_SEPARATOR:"|",
	/**
	Separates key from value
	*/
	COOKIE_PREF_VALUE_SEPARATOR:"=",
	/**
	By default expire one year from now.
	*/
	COOKIE_EXPIRY_TIME:365 * 24 * 60 * 60 * 1000,

	/**
     * Writes data to a user cookie, using key-value notation. If the key
     * already exists, the value is overwritten. If the key is new, a new
     * key/value pair is created.
     * Characters '|' and '=' are reserved as separators.
     * @param inPrefName : (String) name of the preference to write, for
     *  instance 'SHOWATTACHMENTS'
     * @param inPrefValue : (String) stringified value to write, for
     *  instance '1'
     */
	setPref:function(inPrefName, inPrefValue) {
		var cookieString = foswiki.Pref._getPrefCookie();
		var prefs = cookieString.split(foswiki.Pref.COOKIE_PREF_SEPARATOR);
		var prefName = foswiki.Pref._getSafeString(inPrefName);
		var index = foswiki.Pref._getKeyValueLoc(prefs, prefName);
		if (index != -1) {
			// updating this entry is done by removing the existing entry
            // from the array and then pushing the new key-value onto it
			prefs.splice(index, 1);
		}
		// else not found, so don't remove an existing entry
		var prefValue = (isNaN(inPrefValue))
        ? foswiki.Pref._getSafeString(inPrefValue) : inPrefValue;
		var keyvalueString = prefName
        + foswiki.Pref.COOKIE_PREF_VALUE_SEPARATOR + prefValue;
		prefs.push(keyvalueString);
		foswiki.Pref._writePrefValues(prefs);
	},
	
	/**
	* Clears the preference.
	*/
	clearPref:function(inPrefName) {
		var cookieString = foswiki.Pref._getPrefCookie();
		var prefs = cookieString.split(foswiki.Pref.COOKIE_PREF_SEPARATOR);
		var prefName = foswiki.Pref._getSafeString(inPrefName);
		var index = foswiki.Pref._getKeyValueLoc(prefs, prefName);
		if (index != -1) {
			// updating this entry is done by removing the existing entry
            // from the array and then pushing the new key-value onto it
			prefs.splice(index, 1);
		}
		foswiki.Pref._writePrefValues(prefs);
	},
	
	/**
     * Reads the value of a preference.
     * Characters '|' and '=' are reserved as separators.
     * @param inPrefName (String): name of the preference to read, for
     *  instance 'SHOWATTACHMENTS'
     * @return The value of the preference; an empty string when no value
     *  is found.
     */
	getPref:function(inPrefName) {
		var prefName = foswiki.Pref._getSafeString(inPrefName);
		return foswiki.Pref.getPrefValueFromPrefList(
            prefName, foswiki.Pref.getPrefList());
	},
	
	/**
     * Reads the value of a preference from an array of key-value pairs.
     * Use in conjunction with getPrefList() when you want to store the
     * key-value pairs for successive look-ups.
     * @param inPrefName (String): name of the preference to read, for
     * instance 'SHOWATTACHMENTS'
     * @param inPrefList (Array): list of key-value pairs, retrieved with
     * getPrefList()
     * @return The value of the preference; an empty string when no value
     * is found.
     */
	getPrefValueFromPrefList:function(inPrefName, inPrefList) {
		var keyvalue = foswiki.Pref._getKeyValue(inPrefList, inPrefName);
		if (keyvalue != null) return keyvalue[1];
		return '';
	},
	
	/**
     * Gets the list of all values set with setPref.
     * @return An Array of key-value pair pref values; null if no value
     * has been set before.
     */
	getPrefList:function() {
		var cookieString = foswiki.Pref._getPrefCookie();
		if (!cookieString) return null;
		return cookieString.split(foswiki.Pref.COOKIE_PREF_SEPARATOR);
	},
	
	/**	
     * Retrieves the value of the cookie specified by "name".
     * @param inName : (String) identifier name of the cookie
     * @return (String) the cookie value; null if no cookie with name inName
     * has been set.
     */
	getCookie:function(inName) {
		var arg = inName + "=";
		var alen = arg.length;
		var clen = document.cookie.length;
		var i = 0;
		while (i < clen) {
			var j = i + alen;
			if (document.cookie.substring(i, j) == arg) {
				return foswiki.Pref._getCookieVal(j);
			}
			i = document.cookie.indexOf(" ", i) + 1;
			if (i == 0) break; 
		}
		return null;
	},
	
	/**
     * Creates a new cookie or updates an existing cookie.
     * @param inName : (String) identifier name of the cookie
     * @param inValue : (String) stringified cookie value, for instance '1'
     * @param inExpires : (Date) (optional) the expiration data of the
     *  cookie; if omitted or null, expires the cookie at the end of the
     *  current session
     * @param inPath : (String) (optional) the path for which the cookie
     *  is valid; if omitted or null, uses the path of the current document
     * @param inDomain : (String) (optional) the domain for which the
     *  cookie is valid; if omitted or null, uses the domain of the
     *  current document
     * @param inUsesSecure : (Boolean) (optional) whether cookie transmission
     *  requires a secure channel (https)
     * @use
     * To call setCookie using name, value and path, write:
     * <pre>
     * foswiki.Pref.setCookie ("myCookieName", "myCookieValue", null, "/");
     * </pre>	
     * To set a secure cookie for path "/myPath", that expires after the
     *  current session, write:
     * <pre>
     * foswiki.Pref.setCookie ("myCookieName", "myCookieValue", null,
     *  "/myPath", null, true);
     * </pre>
     */
	setCookie:function(inName, inValue, inExpires, inPath,
                       inDomain, inUsesSecure) {
		var cookieString = inName + "=" + escape (inValue) +
			((inExpires) ? "; expires=" + inExpires.toGMTString() : "") +
			((inPath) ? "; path=" + inPath : "") +
			((inDomain) ? "; domain=" + inDomain : "") +
			((inUsesSecure) ? "; secure" : "");
		document.cookie = cookieString;
	},
	
	/**
     * Function to delete a cookie. (Sets expiration date to start of epoch)
     * @param inName : (String) identifier name of the cookie
     * @param inPath : (String) The path for which the cookie is valid.
     * This MUST be the same as the path used to create the cookie, or
     * null/omitted if no path was specified when creating the cookie.
     * @param inDomain : (String) The domain for which the cookie is valid.
     * This MUST be the same as the domain used to create the cookie, or
     * null/omitted if no domain was specified when creating the cookie.
	*/
	deleteCookie:function(inName, inPath, inDomain) {
		if (foswiki.Pref.getCookie(inName)) {
			document.cookie =
            inName + "="
            + ((inPath) ? ";path=" + inPath : "")
            + ((inDomain) ? "; domain=" + inDomain : "")
            + "; expires=Thu, 01-Jan-70 00:00:01 GMT";
		}
	},
	
	/**
     * PRIVATE
     * Finds a key-value pair in an array.
     * @param inKeyValues: (Array) the array to iterate
     * @param inKey: (String) the key to find in the array
     * @return The first occurrence of a key-value pair, where
     *  key == inKey; null if none is found.
     */
	_getKeyValue:function(inKeyValues, inKey) {
		if (!inKeyValues) return null;
		var i = inKeyValues.length;
		while (i--) {
			var keyvalue = inKeyValues[i].split(
                foswiki.Pref.COOKIE_PREF_VALUE_SEPARATOR);
			if (keyvalue[0] == inKey) return keyvalue;	
		}
		return null;
	},
	
	/**
     * PRIVATE
     * Finds the location of a key-value pair in an array.
     * @param inKeyValues: (Array) the array to iterate
     * @param inKey: (String) the key to find in the array
     * @return The location of the first occurrence of a key-value
     *  tuple, where key == inKey; -1 if none is found.
     */
	_getKeyValueLoc:function(inKeyValues, inKey) {
		if (!inKeyValues) return null;
		var i = inKeyValues.length;
		while (i--) {
			var keyvalue = inKeyValues[i].split(
                foswiki.Pref.COOKIE_PREF_VALUE_SEPARATOR);
			if (keyvalue[0] == inKey) return i;	
		}
		return -1;
	},
	
	/**
     * 	PRIVATE
     * Writes a cookie with the stringified array values of inValues.
     * @param inValues: (Array) an array with key-value tuples
     */
	_writePrefValues:function(inValues) {
		var cookieString = (inValues != null)
        ? inValues.join(foswiki.Pref.COOKIE_PREF_SEPARATOR) : '';
		var expiryDate = new Date ();
        var cookieDomain = foswiki.getPreference('COOKIEREALM');
        var cookieSecure = foswiki.getPreference('URLHOST').startsWith("https://");
        // Correct for Mac date bug - call only once for given Date object!
		foswiki.Pref._fixCookieDate (expiryDate);
		expiryDate.setTime (expiryDate.getTime()
                            + foswiki.Pref.COOKIE_EXPIRY_TIME);
		foswiki.Pref.setCookie(foswiki.Pref.FOSWIKI_PREF_COOKIE_NAME,
                               cookieString, expiryDate, '/', cookieDomain, cookieSecure);
	},
	
	/**
     * PRIVATE
     * Gets the FOSWIKI_PREF_COOKIE_NAME cookie; creates a new cookie
     *  if it does not exist.
     * @return The pref cookie.
     */
	_getPrefCookie:function() {
		var cookieString = foswiki.Pref.getCookie(
            foswiki.Pref.FOSWIKI_PREF_COOKIE_NAME);
		if (cookieString == undefined) {
			cookieString = "";
		}
		return cookieString;
	},
	
	/**
     * PRIVATE
     * Strips reserved characters '|' and '=' from the input string.
     * @return The stripped string.
     */
	_getSafeString:function(inString) {
		var regex = new RegExp(/[|=]/);
		return inString.replace(regex, "");
	},
	
	/**
     * PRIVATE
     * 	Retrieves the decoded value of a cookie.
     * @param inOffset : (Number) location of value in full cookie string.
     */
	_getCookieVal:function(inOffset) {
		var endstr = document.cookie.indexOf (";", inOffset);
		if (endstr == -1) {
			endstr = document.cookie.length;
		}
		return unescape(document.cookie.substring(inOffset, endstr));
	},
	
	/**
     * PRIVATE
     * 	Function to correct for 2.x Mac date bug.  Call this function to
     * fix a date object prior to passing it to setCookie.
     * IMPORTANT:  This function should only be called *once* for
     * any given date object!  See example at the end of this document.
     */
	_fixCookieDate:function(inDate) {
		var base = new Date(0);
		var skew = base.getTime(); // dawn of (Unix) time - should be 0
		if (skew > 0) {	// Except on the Mac - ahead of its time
			inDate.setTime(inDate.getTime() - skew);
		}
	}
};
