/*
  Copyright (C) 2007 Crawford Currie http://wikiring.com and Arthur Clemens
  All Rights Reserved.

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version. For
  more details read LICENSE in the root of the TWiki distribution.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  As per the GPL, removal of this notice is prohibited.
*/
function initAttachDialog() {
	tinyMCEPopup.resizeToInnerSize();
}

// Done separately from initAttachDialog because it gets called in the
// wrong place in Safari otherwise
function getAttachInfo() {
    // Work out the rest URL from the location
    var scripturl = TWikiTiny.getTWikiVar("SCRIPTURL");
    var suffix = TWikiTiny.getTWikiVar("SCRIPTSUFFIX");
    if (suffix == null) suffix = '';
    var url = scripturl + "/rest" + suffix + "/WysiwygPlugin/attachments";

    var request = (tinyMCE.isIE) ?
        new ActiveXObject("Microsoft.XMLHTTP") :
        new XMLHttpRequest();
    request.open("POST", url, true);
    request.setRequestHeader(
        "Content-type", "application/x-www-form-urlencoded");

    var path = TWikiTiny.getTWikiVar("WEB") + '.' 
        + TWikiTiny.getTWikiVar("TOPIC");
    var params = "nocache=" + encodeURIComponent((new Date()).getTime())
        + "&topic=" + encodeURIComponent(path);
    
    request.setRequestHeader("Content-length", params.length);
    request.setRequestHeader("Connection", "close");
    request.onreadystatechange = function() {
        attachmentListCallback(request);
    };
    request.send(params);
    // Write the correct action into the form in attach.htm
    var el = document.getElementById('upload_form');
    el.action = scripturl + "/rest" + suffix +
        "/WysiwygPlugin/upload";
    el = document.getElementById('upload_form_topic');
    el.value = path;
}

// Callback to handle an attachment list
function attachmentListCallback(request) {
    if (request.readyState == 4) {
        // only if "OK"
        if (request.status == 200) {
            var atts = request.responseText;
            if (atts != null) {
                atts = eval(atts);
                var select = document.getElementById("attachments_select");
                for (var i = 0; i < atts.length; i++) {
                    select.options[i] = new Option(atts[i].name, atts[i].name);
                }
            }
        } else {
            alert("There was a problem retrieving the attachments list: "
                  + request.statusText);
        }
    }
}

// Insert a link to the selected attachment in the text
function insertLink() {
	var inst = tinyMCE.getInstanceById(tinyMCE.getWindowArg('editor_id'));
    var select = document.getElementById("attachments_select");
    var filename = select.value;
    var url = TWikiTiny.getTWikiVar("ATTACHURL") + '/' + filename;
    var tmp = filename.lastIndexOf(".");
    if (tmp >= 0)
        tmp = filename.substring(tmp + 1, filename.length).toLowerCase();

    var html;
    if (tmp == "jpg" || tmp == "gif" || tmp == "jpeg" ||
        tmp == "png" || tmp == "bmp") {
        html = "<img src='" + url + "' alt='" + filename + "'>";
    } else {
        html = "<a href='" + url + "'>" + filename + "</a>";
    }
    tinyMCEPopup.execCommand('mceBeginUndoLevel');
    tinyMCE.execCommand('mceInsertContent', false, html);
    tinyMCE.triggerNodeChange();
    tinyMCEPopup.execCommand('mceEndUndoLevel');

	tinyMCEPopup.close();
}

