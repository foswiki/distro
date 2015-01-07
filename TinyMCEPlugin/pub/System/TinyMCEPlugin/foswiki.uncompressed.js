/*
  Copyright (C) 2007 Crawford Currie http://wikiring.com and Arthur Clemens
  All Rights Reserved.

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version. For
  more details read LICENSE in the root of the Foswiki distribution.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  As per the GPL, removal of this notice is prohibited.
*/

// Item10288:  Prevent save while in Full Screen
jQuery(document).ready(function($) {
    $("#save").closest('form').bind('submit', function(event) {
        if (( $('#cancel:focus') ).length) {
            return true;
        }
        if ( (typeof(tinyMCE) === 'object')
          && (typeof(tinyMCE.activeEditor) === 'object')
          && (tinyMCE.activeEditor !== null)
          &&  tinyMCE.activeEditor.getParam('fullscreen_is_enabled') ) {
            alert('Please toggle out of full screen mode before attempting to save');
            return false;
        }
    });
});

// Setup the standard edit screen for use with TMCE
var IFRAME_ID = 'mce_editor_0';

/**
   Overrides changeEditBox in foswiki_edit.js.
*/
function changeEditBox(inDirection) {
    return false;
}

/**
   Overrides setEditBoxHeight in foswiki_edit.js.
*/
function setEditBoxHeight(inRowCount) {}

/**
   Give the iframe table holder auto-height.
*/
function initTextAreaStyles() {
    var iframe = document.getElementById(IFRAME_ID);
    if (iframe == null) return;

    // walk up to the table
    var node = iframe.parentNode;
    var counter = 0;
    while (node != document) {
        if (node.nodeName == 'TABLE') {
            node.style.height = 'auto';

            // get select boxes
            var selectboxes = node.getElementsByTagName('SELECT');
            var i, ilen = selectboxes.length;
            for (i = 0; i < ilen; ++i) {
                selectboxes[i].style.marginLeft = selectboxes[i].style.marginRight = '2px';
                selectboxes[i].style.fontSize = '94%';
            }

            break;
        }
        node = node.parentNode;
    }
}

/**
Disables the use of ESCAPE in the edit box, because some browsers will
interpret this as cancel and will remove all changes. Copied from 
%SYSTEMWEB%.JavascriptFiles/foswiki_edit.js because it is used in pickaxe mode.
*/
function handleKeyDown(e) {
    if (!e) e = window.event;
    var code;
    if (e.keyCode) code = e.keyCode;
    if (code == 27) return false;
    return true;
}

/**
Provided for use by editors that need to validate form elements before
navigating away. Duplicated from JavascriptFiles/foswiki_edit.js to resolve
Item5514
*/
function validateMandatoryFields(event) {
    if (foswiki.Pref.validateSuppressed) {
        return true;
    }
    var ok = true;
    var els = foswiki.getElementsByClassName(document, 'foswikiMandatory', 'select');
    for (var j = 0; j < els.length; j++) {
        var one = false;
        for (var k = 0; k < els[j].options.length; k++) {
            if (els[j].options[k].selected) {
                one = true;
                break;
            }
        }
        if (!one) {
            alert("The required form field '" + els[j].name + "' has no value.");
            ok = false;
        }
    }
    var taglist = new Array('input', 'textarea');
    for (var i = 0; i < taglist.length; i++) {
        els = foswiki.getElementsByClassName(document, 'foswikiMandatory', taglist[i]);
        for (var j = 0; j < els.length; j++) {
            if (els[j].value == null || els[j].value.length == 0) {
                alert("The required form field '" + els[j].name + "' has no value.");
                ok = false;
            }
        }
    }
    return ok;
}

/**
Used to dynamically set validation suppression, depending on which submit
button is pressed (i.e. call this n 'Cancel').
Duplicated from JavascriptFiles/foswiki_edit.js to resolve Item5514
*/
function suppressSaveValidation() {
    foswiki.Pref.validateSuppressed = true;
}
