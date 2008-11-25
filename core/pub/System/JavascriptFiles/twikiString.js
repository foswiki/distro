
if (twiki == undefined) var twiki = {};
twiki.String = {
		
	/**
	Checks if a string is a WikiWord.
	@param inValue : string to test
	@return True if a WikiWord, false if not.
	*/
	isWikiWord:function(inValue) {
		if (!inValue) return false;
		var re = new RegExp(twiki.StringConstants.getInstance().WIKIWORD_REGEX);
		return (inValue.match(re)) ? true : false;
	},

	/**
	Capitalizes words in the string. For example: "A handy dictionary" becomes "A Handy Dictionary".
	@param inValue : (String) text to convert
	@return The capitalized text.
	*/
	capitalize:function(inValue) {
		if (!inValue) return null;
		var re = new RegExp("[" + twiki.StringConstants.getInstance().MIXED_ALPHANUM_CHARS + "]+", "g");
		return inValue.replace(re, function(a) {
			return a.charAt(0).toLocaleUpperCase() + a.substr(1);
		});
	},
	
	/**
	Checks if a string is a 'boolean string'.
	@param inValue : (String) text to check
	Returns True if the string is either "on", "true" or "1"; otherwise: false.
	*/
	isBoolean:function(inValue) {
		return (inValue == "on") || (inValue == "true") || (inValue == "1");
	},

	/**
	Removes spaces from a string. For example: "A Handy Dictionary" becomes "AHandyDictionary".
	@param inValue : the string to remove spaces from
	@return A new string free from spaces.
	*/
	removeSpaces:function(inValue) {
		if (!inValue) return null;
		var sIn = inValue;
		var sOut = '';
		for ( var i = 0; i < sIn.length; i++ ) {
			ch = sIn.charAt( i );
			if( ch==' ' ) {
				chgUpper = true;
				continue;
			}
			sOut += ch;
		}
		return sOut;
	},
	
	/**
	Removes punctuation characters from a string by stripping all characters except for MIXED_ALPHANUM_CHARS. For example: "A / Z" becomes "AZ".
	@param inValue : the string to remove chars from
	@return A new string free from punctuation characters.
	*/
	removePunctuation:function(inValue) {
		if (!inValue) return null;
		var allowedRegex = "[^" + twiki.StringConstants.getInstance().MIXED_ALPHANUM_CHARS + "]";
		var re = new RegExp(allowedRegex, "g");
		return inValue.replace(re, "");
	},
	
	/**
	Creates a WikiWord from a string. For example: "A handy dictionary" becomes "AHandyDictionary".
	@param inValue : (String) the text to convert to a WikiWord
	@return A new WikiWord string.
	*/
	makeWikiWord:function(inValue) {
		if (!inValue) return null;
		return twiki.String.removePunctuation(twiki.String.capitalize(inValue));
	},
	
	/**
	Makes a text safe to insert in a Foswiki table. Any table-breaking characters are replaced.
	@param inText: (String) the text to make safe
	@return table-safe text.
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
	}
}


/*
Unicode conversion tools:
Convert text to hexadecimal Unicode escape sequence (\uXXXX)
http://www.hot-tips.co.uk/useful/unicode_converter.HTML
Convert hexadecimal Unicode escape sequence (\uXXXX) to text
http://www.hot-tips.co.uk/useful/unicode_convert_back.HTML
	
More international characters in unicode_chars.js
Import file when international support is needed:
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JavascriptFiles/unicode_chars.js"></script>
unicode_chars.js will overwrite the regexes below
	
Info on unicode: http://www.fileformat.info/info/unicode/
*/
	
twiki.StringConstants = function () {
	this.init();
}
twiki.StringConstants.__instance__ = null; // define the static property
twiki.StringConstants.getInstance = function () {
	if (this.__instance__ == null) {
		this.__instance__ = new twiki.StringConstants();
	}
	return this.__instance__;
}
twiki.StringConstants.prototype.UPPER_ALPHA_CHARS = "A-Z";

twiki.StringConstants.prototype.LOWER_ALPHA_CHARS = "a-z";
twiki.StringConstants.prototype.NUMERIC_CHARS = "\\d";

twiki.StringConstants.prototype.MIXED_ALPHA_CHARS;
twiki.StringConstants.prototype.MIXED_ALPHANUM_CHARS;
twiki.StringConstants.prototype.LOWER_ALPHANUM_CHARS;
twiki.StringConstants.prototype.WIKIWORD_REGEX;
twiki.StringConstants.prototype.ALLOWED_URL_CHARS;

twiki.StringConstants.prototype.init = function () {
	twiki.StringConstants.prototype.MIXED_ALPHA_CHARS = twiki.StringConstants.prototype.LOWER_ALPHA_CHARS + twiki.StringConstants.prototype.UPPER_ALPHA_CHARS;
	
	twiki.StringConstants.prototype.MIXED_ALPHANUM_CHARS = twiki.StringConstants.prototype.MIXED_ALPHA_CHARS + twiki.StringConstants.prototype.NUMERIC_CHARS;
	
	twiki.StringConstants.prototype.LOWER_ALPHANUM_CHARS = twiki.StringConstants.prototype.LOWER_ALPHA_CHARS + twiki.StringConstants.prototype.NUMERIC_CHARS;
	
	twiki.StringConstants.prototype.WIKIWORD_REGEX = "^" + "[" + twiki.StringConstants.prototype.UPPER_ALPHA_CHARS + "]" + "+" + "[" + twiki.StringConstants.prototype.LOWER_ALPHANUM_CHARS + "]" + "+" + "[" + twiki.StringConstants.prototype.UPPER_ALPHA_CHARS + "]" + "+" + "[" + twiki.StringConstants.prototype.MIXED_ALPHANUM_CHARS + "]" + "*";
	
	twiki.StringConstants.prototype.ALLOWED_URL_CHARS = twiki.StringConstants.prototype.MIXED_ALPHANUM_CHARS + "-_^";
}

