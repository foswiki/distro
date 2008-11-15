/**
Requires twikiCSS.js
*/

if (twiki == undefined) var twiki = {};
twiki.Form = {
	
	/*
	Original js filename: formdata2querystring.js
	
	Copyright 2005 Matthew Eernisse (mde@fleegix.org)
	
	Licensed under the Apache License, Version 2.0 (the "License");
	http://www.apache.org/licenses/LICENSE-2.0

	Original code by Matthew Eernisse (mde@fleegix.org), March 2005
	Additional bugfixes by Mark Pruett (mark.pruett@comcast.net), 12th July 2005
	Multi-select added by Craig Anderson (craig@sitepoint.com), 24th August 2006

	Version 1.3
	
	Changes for TWiki:
	Added KEYVALUEPAIR_DELIMITER and documentation by Arthur Clemens, 2006
	*/
	
	KEYVALUEPAIR_DELIMITER : ";",

	/**
	Serializes the data from all the inputs in a Web form
	into a query-string style string.
	@param inForm : (HTMLElement) Reference to a DOM node of the form element
	@param inFormatOptions : (Object) value object of options for how to format the return string. Supported options:
		  collapseMulti: (Boolean) take values from elements that can return multiple values (multi-select, checkbox groups) and collapse into a single, comma-delimited value (e.g., thisVar=asdf,qwer,zxcv)
	@returns Query-string formatted String of variable-value pairs
	@example
	<code>
	var queryString = twiki.Form.formData2QueryString(
		document.getElementById('myForm'),
		{collapseMulti:true}
	);
	</code>
	*/
	formData2QueryString:function (inForm, inFormatOptions) {
		if (!inForm) return null;
		var opts = inFormatOptions || {};
		var str = '';
		var formElem;
		var lastElemName = '';
		
		for (i = 0; i < inForm.elements.length; i++) {
			formElem = inForm.elements[i];
			
			switch (formElem.type) {
				// Text fields, hidden form elements
				case 'text':
				case 'hidden':
				case 'password':
				case 'textarea':
				case 'select-one':
					str += formElem.name
						+ '='
						+ encodeURI(formElem.value)
						+ twiki.Form.KEYVALUEPAIR_DELIMITER;
					break;
				
				// Multi-option select
				case 'select-multiple':
					var isSet = false;
					for(var j = 0; j < formElem.options.length; j++) {
						var currOpt = formElem.options[j];
						if(currOpt.selected) {
							if (opts.collapseMulti) {
								if (isSet) {
									str += ','
										+ encodeURI(currOpt.text);
								} else {
									str += formElem.name
										+ '='
										+ encodeURI(currOpt.text);
									isSet = true;
								}
							} else {
								str += formElem.name
									+ '='
									+ encodeURI(currOpt.text)
									+ twiki.Form.KEYVALUEPAIR_DELIMITER;
							}
						}
					}
					if (opts.collapseMulti) {
						str += twiki.Form.KEYVALUEPAIR_DELIMITER;
					}
					break;
				
				// Radio buttons
				case 'radio':
					if (formElem.checked) {
						str += formElem.name
							+ '='
							+ encodeURI(formElem.value)
							+ twiki.Form.KEYVALUEPAIR_DELIMITER;
					}
					break;
				
				// Checkboxes
				case 'checkbox':
					if (formElem.checked) {
						// Collapse multi-select into comma-separated list
						if (opts.collapseMulti && (formElem.name == lastElemName)) {
						// Strip of end ampersand if there is one
						if (str.lastIndexOf('&') == str.length-1) {
							str = str.substr(0, str.length - 1);
						}
						// Append value as comma-delimited string
						str += ','
							+ encodeURI(formElem.value);
						}
						else {
						str += formElem.name
							+ '='
							+ encodeURI(formElem.value);
						}
						str += twiki.Form.KEYVALUEPAIR_DELIMITER;
						lastElemName = formElem.name;
					}
					break;
					
				} // switch
			} // for
		// Remove trailing separator
		str = str.substr(0, str.length - 1);
		return str;
	},
	
	/**
	Makes form field values safe to insert in a TWiki table. Any table-breaking characters are replaced.
	@param inForm: (String) the form to make safe
	*/
	makeSafeForTableEntry:function(inForm) {
		if (!inForm) return null;
		var formElem;
		
		for (i = 0; i < inForm.elements.length; i++) {
			formElem = inForm.elements[i];
			switch (formElem.type) {
				// Text fields, hidden form elements
				case 'text':
				case 'password':
				case 'textarea':
					formElem.value = twiki.Form._makeTextSafeForTableEntry(formElem.value);
					break;
			}
		}
	},
	
	/**
	Makes a text safe to insert in a TWiki table. Any table-breaking characters are replaced.
	@param inText: (String) the text to make safe
	@return table-safe text.
	*/
	_makeTextSafeForTableEntry:function(inText) {
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
	Finds the form element.
	@param inFormName : (String) name of the form
	@param inElementName : (String) name of the form element
	@return HTMLElement
	*/
	getFormElement:function(inFormName, inElementName) {
		return document[inFormName][inElementName];
	},
	
	/**
	Sets input focus to input element. Note: only one field on a page can have focus.
	@param inFormName : (String) name of the form
	@param inInputFieldName : (String) name of the input field that will get focus
	*/
	setFocus:function(inFormName, inInputFieldName) {
		try {
			var el = twiki.Form.getFormElement(inFormName, inInputFieldName);
			el.focus();
		} catch (er) {}
	},
	
	/**
	Sets the default text of an input field (for instance the text 'Enter keyword or product number' in a search box) that is cleared when the field gets focus. The field is styled with CSS class 'twikiInputFieldBeforeFocus'.
	@param el : (HTMLElement) the input field to receive default text
	@param inText : (String) the default text
	*/
	initBeforeFocusText:function(el, inText) {
		el.FP_defaultValue = inText;
		if (!el.value || el.value == inText) {
			twiki.Form._setDefaultStyle(el);
		}
	},
	
	/**
	Clears the default input field text. The CSS styling 'twikiInputFieldBeforeFocus' is removed. Call this function at 'onfocus'.
	@param el : (HTMLElement) the input field that has default text
	*/
	clearBeforeFocusText:function(el) {
		if (!el.FP_defaultValue) {
			el.FP_defaultValue = el.value;
		}
		if (el.FP_defaultValue == el.value) {
			el.value = "";
		}
		twiki.CSS.addClass(el, "twikiInputFieldFocus");
		twiki.CSS.removeClass(el, "twikiInputFieldBeforeFocus");
	},
	
	/**
	Restores the default text when the input field is empty. Call this function at 'onblur'.
	@param el : (HTMLElement) the input field to clear
	*/
	restoreBeforeFocusText:function(el) {
		if (!el.value && el.FP_defaultValue) {
			twiki.Form._setDefaultStyle(el);
		}
		twiki.CSS.removeClass(el, "twikiInputFieldFocus");
	},
	
	/**
	Sets the value and style of unfocussed or empty text field.
	@param el : (HTMLElement) the input field that has default text
	*/
	_setDefaultStyle:function(el) {
		el.value = el.FP_defaultValue;
		twiki.CSS.addClass(el, "twikiInputFieldBeforeFocus");
	}
	
};
