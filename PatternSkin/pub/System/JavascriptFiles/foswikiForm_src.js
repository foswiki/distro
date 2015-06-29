/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this file
as follows:

Copyright 2005 Matthew Eernisse (mde@fleegix.org)

This program is free software; you can redistribute it and/or
modify it under the terms of the Apache License, Version 2.0 (the "License");
http://www.apache.org/licenses/LICENSE-2.0

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

/**
 * Support for JS control of fields in an HTML form.
 *
 * Based on code written by:
 *   Matthew Eernisse (mde@fleegix.org),
 *   Mark Pruett (mark.pruett@comcast.net),
 *   Craig Anderson (craig@sitepoint.com)
 * Original js filename: formdata2querystring.js (Version 1.3)
 *
 * Requires JQUERYPLUGIN::FOSWIKI, JavascriptFiles/foswikiString
 */
(function($) {
    foswiki.Form = {
        
        KEYVALUEPAIR_DELIMITER : ";",
        
        /**
         * Serializes the data from all the inputs in a Web form
         * in to a query-string style string.
         * @param inForm : (HTMLElement) Reference to a DOM node of the
         * form element
         * @param inFormatOptions : (Object) value object of options for how
         * to format the return string. Supported options:
         *  collapseMulti: (Boolean) take values from elements that can return
         *  multiple values (multi-select, checkbox groups) and collapse into
         *  a single, comma-delimited value (e.g., thisVar=asdf,qwer,zxcv)
         * @returns Query-string formatted String of variable-value pairs
         * @example
         * <code>
         * var queryString = foswiki.Form.formData2QueryString(
         *     document.getElementById('myForm'),
         *     {collapseMulti:true}
         * );
         * </code>
         */
        formData2QueryString:function (inForm, inFormatOptions) {
            if (!inForm) {
                return null;
            }
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
                    str += (formElem.name + '=' + encodeURI(formElem.value) + foswiki.Form.KEYVALUEPAIR_DELIMITER);
                    break;
                    
                    // Multi-option select
                case 'select-multiple':
                    var isSet = false;
                    for(var j = 0; j < formElem.options.length; j++) {
                        var currOpt = formElem.options[j];
                        if(currOpt.selected) {
                            if (opts.collapseMulti) {
                                if (isSet) {
                                    str += (',' + encodeURI(currOpt.text));
                                } else {
                                    str += (formElem.name + '=' + encodeURI(currOpt.text));
                                    isSet = true;
                                }
                            } else {
                                str += (formElem.name + '=' + encodeURI(currOpt.text) + foswiki.Form.KEYVALUEPAIR_DELIMITER);
                            }
                        }
                    }
                    if (opts.collapseMulti) {
                        str += foswiki.Form.KEYVALUEPAIR_DELIMITER;
                    }
                    break;
                    
                    // Radio buttons
                case 'radio':
                    if (formElem.checked) {
                        str += (formElem.name + '=' + encodeURI(formElem.value) + foswiki.Form.KEYVALUEPAIR_DELIMITER);
                    }
                    break;
                    
                    // Checkboxes
                case 'checkbox':
                    if (formElem.checked) {
                        // Collapse multi-select into comma-separated list
                        if (opts.collapseMulti && (formElem.name === lastElemName)) {
                            // Strip of end ampersand if there is one
                            if (str.lastIndexOf('&') == str.length-1) {
                                str = str.substr(0, str.length - 1);
                            }
                            // Append value as comma-delimited string
                            str += (',' + encodeURI(formElem.value));
                        }
                        else {
                            str += (formElem.name + '=' + encodeURI(formElem.value));
                        }
                        str += foswiki.Form.KEYVALUEPAIR_DELIMITER;
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
         * Makes form field values safe to insert in a Foswiki table.
         * Any table-breaking characters are replaced.
         * @param inForm: (String) the form to make safe
         */
        makeSafeForTableEntry:function(inForm) {
            if (!inForm) {
                return null;
            }
            var formElem;
            
            for (i = 0; i < inForm.elements.length; i++) {
                formElem = inForm.elements[i];
                switch (formElem.type) {
                    // Text fields, hidden form elements
                case 'text':
                case 'password':
                case 'textarea':
                    formElem.value = foswiki.String.makeTextSafeForTableEntry(
                        formElem.value);
                    break;
                }
            }
        },
        
        /**
         * Finds the form element.
         * @param inFormName : (String) name of the form
         * @param inElementName : (String) name of the form element
         * @return HTMLElement
         */
        getFormElement:function(inFormName, inElementName) {
            return document[inFormName][inElementName];
        },
        
        /**
         * Sets input focus to input element. Note: only one field on a page
         * can have focus.
         * @param inFormName : (String) name of the form
         * @param inInputFieldName : (String) name of the input field that 
         * will get focus
         */
        setFocus:function(inFormName, inInputFieldName) {
            try {
                var el = foswiki.Form.getFormElement(inFormName, inInputFieldName);
                el.focus();
            } catch (er) {}
        },
        
        /**
         * Sets the default text of an input field (for instance the text
         * 'Enter keyword or product number' in a search box) that is cleared
         * when the field gets focus. The field is styled with CSS class
         * 'foswikiInputFieldBeforeFocus'.
         * @param el : (HTMLElement) the input field to receive default text
         * @param inText : (String) the default text
         */
        initBeforeFocusText:function(el, inText) {
            el.FP_defaultValue = inText;
            if (!el.value || el.value == inText) {
                foswiki.Form._setDefaultStyle(el);
            }
        },
        
        /**
         * Clears the default input field text. The CSS styling
         * 'foswikiInputFieldBeforeFocus' is removed. Call this function
         * at 'onfocus'.
         * @param el : (HTMLElement) the input field that has default text
         */
        clearBeforeFocusText:function(el) {
            if (!el.FP_defaultValue) {
                el.FP_defaultValue = el.value;
            }
            if (el.FP_defaultValue == el.value) {
                el.value = "";
            }
            $(el).addClass("foswikiInputFieldFocus").removeClass("foswikiInputFieldBeforeFocus");
        },
        
        /**
         * Restores the default text when the input field is empty. Call
         * this function at 'onblur'.
         * @param el : (HTMLElement) the input field to clear
         */
        restoreBeforeFocusText:function(el) {
            if (!el.value && el.FP_defaultValue) {
                foswiki.Form._setDefaultStyle(el);
            }
            $(el).removeClass("foswikiInputFieldFocus");
        },
        
        /**
         * PRIVATE
         * Sets the value and style of unfocussed or empty text field.
         * @param el : (HTMLElement) the input field that has default text
         */
        _setDefaultStyle:function(el) {
            el.value = el.FP_defaultValue;
            $(el).addClass("foswikiInputFieldBeforeFocus");
        }
    };
    
})(jQuery);

jQuery(document).ready(
    function ($) {
        $('input[type="text"].foswikiDefaultText')
            .each(
                function(index, el) {
                    foswiki.Form.initBeforeFocusText(this, this.title);
                })
            .focus(
                function() {
                    foswiki.Form.clearBeforeFocusText(this);
                })
            .blur(
                function() {
                    foswiki.Form.restoreBeforeFocusText(this);
                });
        $('.foswikiCheckAllOn').click(
            function(e) {
                var form = $(this).parents('form:first');
                $('.foswikiCheckBox', form).attr('checked', true);
            }
        );
        $('.foswikiCheckAllOff').click(
            function(e) {
                var form = $(this).parents('form:first');
                $('.foswikiCheckBox', form).attr('checked', false);
            }
        );
    }
);
