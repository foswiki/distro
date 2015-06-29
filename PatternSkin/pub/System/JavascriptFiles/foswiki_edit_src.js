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
 * Support for the "raw text" editor.
 * Requires JQUERYPLUGIN::FOSWIKI
 */

var EDITBOX_ID = "topic";
// edit box rows
var EDITBOX_PREF_ROWS_ID     = "EditTextareaRows";
var EDITBOX_CHANGE_STEP_SIZE = 4;
var EDITBOX_MIN_ROWCOUNT     = 4;
// edit box font style
var EDITBOX_PREF_FONTSTYLE_ID            = "EditTextareaFontStyle";
var EDITBOX_FONTSTYLE_MONO               = "mono";
var EDITBOX_FONTSTYLE_PROPORTIONAL       = "proportional";
var EDITBOX_FONTSTYLE_MONO_STYLE         = "foswikiEditboxStyleMono";
var EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE = "foswikiEditboxStyleProportional";

(function($) {
    foswiki.Edit = {
        textareaInited: false,
        fontStyle: null,
        validateSuppressed: false
    };

    /**
     * Sets the font style of the edit box and the signature box. The change
     *  is written to a cookie.
     * @param inFontStyle: either EDITBOX_FONTSTYLE_MONO or
     *  EDITBOX_FONTSTYLE_PROPORTIONAL
     */
    foswiki.Edit.getFontStyle = function() {
        if (foswiki.Edit.fontStyle) {
            return foswiki.Edit.fontStyle;
        }
        
        var pref = foswiki.Pref.getPref(EDITBOX_PREF_FONTSTYLE_ID);
        
        if (!pref || (pref !== EDITBOX_FONTSTYLE_PROPORTIONAL
                      && pref !== EDITBOX_FONTSTYLE_MONO)) {
            pref = EDITBOX_FONTSTYLE_PROPORTIONAL;
        }
        
        return pref;
    };
    
    /**
     * Sets the font style of the edit box and the signature box. The change
     *  is written to a cookie.
     * @param inFontStyle: either EDITBOX_FONTSTYLE_MONO or
     *  EDITBOX_FONTSTYLE_PROPORTIONAL
     */
    foswiki.Edit.setFontStyle = function(inFontStyle) {
        if (inFontStyle === EDITBOX_FONTSTYLE_MONO) {
            $('#' + EDITBOX_ID).removeClass(
                EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE).addClass(
                EDITBOX_FONTSTYLE_MONO_STYLE);
        }
        if (inFontStyle === EDITBOX_FONTSTYLE_PROPORTIONAL) {
            $('#' + EDITBOX_ID).removeClass(
                EDITBOX_FONTSTYLE_MONO_STYLE).addClass(
                EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
        }
        foswiki.Edit.fontStyle = inFontStyle;
        foswiki.Pref.setPref(EDITBOX_PREF_FONTSTYLE_ID, inFontStyle);
    };
            
    /**
     * Changes the height of the editbox textarea.
     * param inDirection : -1 (decrease) or 1 (increase).
     * If the new height is smaller than EDITBOX_MIN_ROWCOUNT the height
     *  will become EDITBOX_MIN_ROWCOUNT.
     * Each change is written to a cookie.
     */
    foswiki.Edit.changeEditBox = function(inDirection) {
        var rowCount = $('#' +  EDITBOX_ID).attr('rows');
	rowCount = parseInt(rowCount);
        rowCount += (inDirection * EDITBOX_CHANGE_STEP_SIZE);
        rowCount = (rowCount < EDITBOX_MIN_ROWCOUNT)
        ? EDITBOX_MIN_ROWCOUNT : rowCount;
        $('#' + EDITBOX_ID).attr('rows', rowCount);
                foswiki.Pref.setPref(EDITBOX_PREF_ROWS_ID, rowCount);
        return false;
    };

    foswiki.Edit.validateMandatoryFields = function() {
        // Provided for use by editors that need to
        // validate form elements before navigating away
        if (foswiki.Edit.validateSuppressed) {
            return true;
        }
        
        var alerts = [];
        $('select.foswikiMandatory').each(function(index, el) {
			var one = false;
			var k;
			for (k = 0; k < el.options.length; k=k+1) {
				if (el.options[k].selected) {
					one = true;
					break;
				}
			}
			if (!one) {
				alerts.push("The required form field '"
							+ el.name +
							"' has no value.");
			}
		});

        $('textarea.foswikiMandatory, input.foswikiMandatory').each(function(index, el) {
			if (el.value === null || el.value.length === 0) {
				alerts.push("The required form field '"
							+ el.name +
							"' has no value.");
			}
		});

        if (alerts.length > 0) {
            alert(alerts.join("\n"));
            return false;
        } else {
            return true;
        }
    };

    $(function() {

		try {
			document.main.text.focus();
		} catch (er) {
			//
		}
		
		var prefRowsId = foswiki.Pref.getPref(EDITBOX_PREF_ROWS_ID);
		if (prefRowsId) {
			$('#' + EDITBOX_ID).attr('rows', parseInt(prefRowsId, 10) );
		}
		
		// Set the font style (monospace or proportional space) of the edit
		// box to the style read from cookie.
		var prefStyle  = foswiki.Edit.getFontStyle();
		foswiki.Edit.setFontStyle(prefStyle);

		$(document.forms[name='main']).submit(function(e) {
			return foswiki.Edit.validateMandatoryFields();
		});

		$('.foswikiTextarea').keydown(function(e) {
			// Disables the use of ESCAPE in the edit box, because some
			// browsers will interpret this as cancel and will remove
			// all changes.
			var code;
			if (e.keyCode) {
				code = e.keyCode;
			}
			return (code !== 27); // ESC
		});

		$('.foswikiButtonCancel').click(function(e) {
			// Used to dynamically set validation suppression
			foswiki.Edit.validateSuppressed = true;
		});
	});
}(jQuery));
