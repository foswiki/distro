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
 * Support for the "raw text" editor. Requires the 'foswiki' object
 * to exist, but does *not* require JQueryPlugin.
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

foswiki.Edit = {
    textareaInited: false,
    fontStyle: null,

    getFontStyle: function() {
        var pref = foswiki.Edit.fontStyle;
        if (!pref)
            pref = foswiki.Pref.getPref(EDITBOX_PREF_FONTSTYLE_ID);

        if (!pref || (pref != EDITBOX_FONTSTYLE_PROPORTIONAL
                      && pref != EDITBOX_FONTSTYLE_MONO))
            pref = EDITBOX_FONTSTYLE_PROPORTIONAL;

        foswiki.Edit.fontStyle = pref;
        return pref;
    },

    /**
     * Sets the font style of the edit box and the signature box. The change
     *  is written to a cookie.
     * @param inFontStyle: either EDITBOX_FONTSTYLE_MONO or
     *  EDITBOX_FONTSTYLE_PROPORTIONAL
     */
    setFontStyle: function(inFontStyle) {
        if (inFontStyle == EDITBOX_FONTSTYLE_MONO) {
            foswiki.CSS.replaceClass(
                document.getElementById(EDITBOX_ID),
                EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE,
                EDITBOX_FONTSTYLE_MONO_STYLE);
        }
        if (inFontStyle == EDITBOX_FONTSTYLE_PROPORTIONAL) {
            foswiki.CSS.replaceClass(
                document.getElementById(EDITBOX_ID),
                EDITBOX_FONTSTYLE_MONO_STYLE,
                EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
        }
        foswiki.Edit.fontStyle = inFontStyle;
        foswiki.Pref.setPref(EDITBOX_PREF_FONTSTYLE_ID, inFontStyle);
    },

    initForm: function() {
        try {
            document.main.text.focus();
        } catch (er) {
        };
        foswiki.Edit.initTextArea();
        foswiki.Edit.initTextAreaHeight();
        foswiki.Edit.initTextAreaStyles();
    },

    /**
     * Sets the height of the edit box to height read from cookie.
     */
    initTextAreaHeight: function() {
        var pref = foswiki.Pref.getPref(EDITBOX_PREF_ROWS_ID);
        if (pref)
            foswiki.Edit.setEditBoxHeight( parseInt(pref) );
    },

    /**
     */
    initTextArea: function () {
        if (!foswiki.Edit.textareaInited) {
            foswiki.Edit.initTextAreaHeight();
            foswiki.Edit.initTextAreaFontStyle();
            foswiki.Edit.textareaInited = true;
        }
    },

    /**
     * Hook for plugins.
     */
    initTextAreaStyles: function() {},

    /**
     * Sets the font style (monospace or proportional space) of the edit
     *  box to style read from cookie.
     */
    initTextAreaFontStyle: function() {
        var pref  = foswiki.Edit.getFontStyle();
        if (pref)
            foswiki.Edit.setFontStyle( pref );
    },

    /**
     * Disables the use of ESCAPE in the edit box, because some browsers
     *  will interpret this as cancel and will remove all changes.
     */
    handleKeyDown: function(e) {
        if (!e)
            e = window.event;
        var code;
        if (e.keyCode)
            code = e.keyCode;
        return (code != 27) // ESC
    },
    
    /**
     * Changes the height of the editbox textarea.
     * param inDirection : -1 (decrease) or 1 (increase).
     * If the new height is smaller than EDITBOX_MIN_ROWCOUNT the height
     *  will become EDITBOX_MIN_ROWCOUNT.
     * Each change is written to a cookie.
     */
    changeEditBox: function(inDirection) {
        var rowCount = document.getElementById(EDITBOX_ID).rows;
        rowCount += (inDirection * EDITBOX_CHANGE_STEP_SIZE);
        rowCount = (rowCount < EDITBOX_MIN_ROWCOUNT)
        ? EDITBOX_MIN_ROWCOUNT : rowCount;
        foswiki.Edit.setEditBoxHeight(rowCount);
        foswiki.Pref.setPref(EDITBOX_PREF_ROWS_ID, rowCount);
        return false;
    },
    
    /**
     * Sets the height of the exit box text area.
     * param inRowCount: the number of rows
     */
    setEditBoxHeight: function(inRowCount) {
        var el = document.getElementById(EDITBOX_ID);
        if (el) {
            el.rows = inRowCount;
        }
    },
   
    /**
     *  Provided for use by editors that need to validate form elements before
     *  navigating away
     */
    validateMandatoryFields: function(event) {
        if (foswiki.Pref.validateSuppressed) {
            return true;
        }
        var ok = true;
        var els = foswiki.getElementsByClassName(
            document, 'foswikiMandatory', 'select');
        for (var j = 0; j < els.length; j++) {
            var one = false;
            for (var k = 0; k < els[j].options.length; k++) {
                if (els[j].options[k].selected) {
                    one = true;
                    break;
                }
            }
            if (!one) {
                alert("The required form field '" + els[j].name +
                      "' has no value.");
                ok = false;
            }
        }
        var taglist = new Array('input', 'textarea');
        for (var i = 0; i < taglist.length; i++) {
            els = foswiki.getElementsByClassName(
                document, 'foswikiMandatory', taglist[i]);
            for (var j = 0; j < els.length; j++) {
                if (els[j].value == null || els[j].value.length == 0) {
                    alert("The required form field '" + els[j].name +
                          "' has no value.");
                    ok = false;
                }
            }
        }
        return ok;
    },
    
    /**
     * Used to dynamically set validation suppression, depending
     * on which submit button is pressed (i.e. call this on 'Cancel').
     */
    suppressSaveValidation: function() {
        foswiki.Pref.validateSuppressed = true;
    }
};
