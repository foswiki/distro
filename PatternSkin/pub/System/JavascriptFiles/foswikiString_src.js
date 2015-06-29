/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
 * Support for string manipulation
 * Requires: JQUERYPLUGIN::FOSWIKI
 */

/**
 * Unicode conversion tools:
 * Convert text to hexadecimal Unicode escape sequence (\uXXXX)
 * http://www.hot-tips.co.uk/useful/unicode_converter.HTML
 * Convert hexadecimal Unicode escape sequence (\uXXXX) to text
 * http://www.hot-tips.co.uk/useful/unicode_convert_back.HTML
 * 	
 * More international characters in foswikiStringUnicodeChars.js
 * Import file when international support is needed:
 * <script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JavascriptFiles/foswikiStringUnicodeChars.js"></script>
 * foswikiStringUnicodeChars.js will overwrite the regexes below:
 * 
 * Info on unicode: http://www.fileformat.info/info/unicode/
 */

var foswiki = foswiki || {
  preferences: {}
};

foswiki.String = {
    
    /**
     * Checks if a string is a WikiWord.
     * @param inValue : string to test
     * @return True if a WikiWord, false if not.
     */
    isWikiWord:function(inValue) {
	if (!inValue) return false;
	return (inValue.match(foswiki.RE.wikiword)) ? true : false;
    },
    
    /**
     * Capitalizes words in the string. For example: "A handy dictionary"
     * becomes "A Handy Dictionary".
     * @param inValue : (String) text to convert
     * @return The capitalized text.
     */
    capitalize:function(inValue) {
	if (!inValue) return null;
	var re = new RegExp(
            "[" + foswiki.RE.lower + foswiki.RE.upper + "]+", "g");
	return inValue.replace(re, function(a) {
	    return a.charAt(0).toLocaleUpperCase() + a.substr(1);
	});
    },
    
    /**
     * Checks if a string is a 'boolean string'.
     * @param inValue : (String) text to check
     * Returns True if the string is either "on", "true" or "1";
     *  otherwise: false.
     */
    isBoolean:function(inValue) {
	return (inValue == "on") || (inValue == "true") || (inValue == "1");
    },
    
    /**
     * Removes spaces from a string. For example: "A Handy Dictionary"
     *  becomes "AHandyDictionary".
     * @param inValue : the string to remove spaces from
     * @return A new string free from spaces.
     */
    removeSpaces:function(inValue) {
	return inValue.replace(/\s/g, '');
    },
    
    trimSpaces:function(inValue) {
    	if (inValue) {
    	    inValue = inValue.replace(/^\s\s*/, '');
	}
	if (inValue) {
	    inValue = inValue.replace(/\s\s*$/, '');
	}
	return inValue;
    },
    
    /**
     * Removes filtered punctuation characters from a string by stripping all characters
     * identified in the Foswiki::cfg{NameFilter} passed as NAMEFILTER+.
     * @param inValue : the string to remove chars from
     * @return A new string free from punctuation characters.
     */
    filterPunctuation:function(inValue) {
	if (!inValue) return null;
        var nameFilterRegex = foswiki.getPreference('NAMEFILTER')
	var re = new RegExp(nameFilterRegex, "g");
	return inValue.replace(re, " ");
    },
    
    /**
     * Removes punctuation characters from a string by stripping all characters
     * except for [:alnum:] . For example: "A / Z" becomes "AZ".
     * @param inValue : the string to remove chars from
     * @return A new string free from punctuation characters.
     */
    removePunctuation:function(inValue) {
	if (!inValue) return null;
	var allowedRegex = "[^" + foswiki.RE.alnum + "]+";
	var re = new RegExp(allowedRegex, "g");
	return inValue.replace(re, "");
    },
    
    /**
     * Creates a WikiWord from a string. For example: "A handy dictionary"
     * becomes "AHandyDictionary".
     * @param inValue : (String) the text to convert to a WikiWord
     * @return A new WikiWord string.
     */
    makeWikiWord:function(inValue) {
	if (!inValue) return null;
	return foswiki.String.removePunctuation(foswiki.String.capitalize(inValue));
    },
    
    /**
     * Creates a CamelCase string from separate words.
     * @param inValue : (String) the text to convert to a WikiWord
     * @return A new WikiWord string.
     */
    makeCamelCase: function() {
	var i, v = '';
	for (i = 0; i < arguments.length; i++) {
	    if (arguments[i])
		v += foswiki.String.capitalize(arguments[i]);
	}
	return foswiki.String.removePunctuation(v);
    },
    
    /**
     * Makes a text safe to insert in a Foswiki table. Any table-breaking
     * characters are replaced.
     * @param inText: (String) the text to make safe
     * @return table-safe text.
     */
    makeSafeForTableEntry:function(inText) {
	if (inText.length == 0) return "";
	var safeString = inText;
	var re;
	// replace \n by \r
	re = new RegExp(/\r/g);
	safeString = safeString.replace(re, "\n");	
	// replace pipes by forward slashes
	re = new RegExp(/\|/g);
	safeString = safeString.replace(re, "/");
	// replace double newlines
	re = new RegExp(/\n\s*\n/g);
	safeString = safeString.replace(re, "%<nop>BR%%<nop>BR%");
	// replace single newlines
	re = new RegExp(/\n/g);
	safeString = safeString.replace(re, "%<nop>BR%");
	// make left-aligned by appending a space
	safeString += " ";
	return safeString;
    },
    
    /**
     * Replaces all foswiki TML special characters with their escaped counterparts.
     * See Foswiki:System.FormatTokens
     * @param inValue: (String) the text to escape
     * @return escaped text.
     */
    escapeTML:function(inValue) {
      var text = inValue;
      text = text.replace(/\$/g, '$dollar');
      text = text.replace(/&/g, '$amp');
      text = text.replace(/>/g, '$gt');
      text = text.replace(/</g, '$lt');
      text = text.replace(/%/g, '$percent');
      text = text.replace(/,/g, '$comma');
      text = text.replace(/"/g, '\\"');
      return text;
    },

    /**
     * The inverse of the escapeTML function.
     * See Foswiki:System.FormatTokens
     * @param inValue: (String) the text to unescape.
     * @return unescaped text.
     */
    unescapeTML:function(inValue) {
      var text = inValue;
      text = text.replace(/\$nop/g, '');
      text = text.replace(/\\"/g, '"');
      text = text.replace(/\$quot/g, '"');
      text = text.replace(/\$comma/g, ',');
      text = text.replace(/\$perce?nt/g, '%');
      text = text.replace(/\$lt/g, '<');
      text = text.replace(/\$gt/g, '>');
      text = text.replace(/\$amp/g, '&');
      text = text.replace(/\$dollar/g, '$');
      return text;
    }
}
