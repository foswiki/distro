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

// The FoswikiTiny class object
var FoswikiTiny = {

    foswikiVars : null,
    request : null, // Container for HTTP request object
    metaTags : null,

    tml2html : new Array(), // callbacks, attached in plugins
    html2tml : new Array(), // callbacks, attached in plugins

    // Get a Foswiki variable from the set passed
    getFoswikiVar : function (name) {
        if (FoswikiTiny.foswikiVars == null) {
            var sets = tinyMCE.getParam("foswiki_vars", "");
            FoswikiTiny.foswikiVars = eval(sets);
        }
        return FoswikiTiny.foswikiVars[name];
    },

    expandVariables : function(url) {
        for (var i in FoswikiTiny.foswikiVars) {
            url = url.replace('%' + i + '%', FoswikiTiny.foswikiVars[i], 'g');
        }
        return url;
    },

    enableSave: function(enabled) {
        var status = enabled ? null : "disabled";
        var elm = document.getElementById("save");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("preview");
        if (elm) {
            elm.style.display = 'none'; // Item5263: broken preview
            elm.disabled = status;
        }
    },

    transform : function(editor, handler, text, onReadyToSend, onReply, onFail) {
        // Work out the rest URL from the location
        var url = FoswikiTiny.getFoswikiVar("SCRIPTURL");
        var suffix = FoswikiTiny.getFoswikiVar("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        url += "/rest" + suffix + "/WysiwygPlugin/" + handler;
        var path = FoswikiTiny.getFoswikiVar("WEB") + '.'
        + FoswikiTiny.getFoswikiVar("TOPIC");
        FoswikiTiny.request = new Object();
        if (tinyMCE.isIE) {
            // branch for IE/Windows ActiveX version
            FoswikiTiny.request.req = new ActiveXObject("Microsoft.XMLHTTP");
        } else {
            // branch for native XMLHttpRequest object
            FoswikiTiny.request.req = new XMLHttpRequest();
        }
        FoswikiTiny.request.editor = editor;
        FoswikiTiny.request.req.open("POST", url, true);
        FoswikiTiny.request.req.setRequestHeader(
            "Content-type", "application/x-www-form-urlencoded");
        var params = "nocache=" + encodeURIComponent((new Date()).getTime())
        + "&topic=" + encodeURIComponent(path)
        + "&text=" + encodeURIComponent(text);
    
        FoswikiTiny.request.req.setRequestHeader(
            "Content-length", params.length);
        FoswikiTiny.request.req.setRequestHeader("Connection", "close");
        FoswikiTiny.request.req.onreadystatechange = function() {
            // Callback for XMLHttpRequest
            // only if FoswikiTiny.request.req shows "complete"
            if (FoswikiTiny.request.req.readyState == 4) {
                // only if "OK"
                if (FoswikiTiny.request.req.status == 200) {
                    onReply();
                } else {
                    onFail();
                }
            }
        };
        onReadyToSend();
        FoswikiTiny.request.req.send(params);
    },

    initialisedFromServer : false,

    // Set up content for the initial edit
    setUpContent : function(editor_id, body, doc) {
        // If we haven't done it before, then transform from TML
        // to HTML. We need this test so that pressing the 'back'
        // button from a failed save doesn't banjax the old content.
        if (FoswikiTiny.initialisedFromServer) return;
        var editor = tinyMCE.getInstanceById(editor_id);
        FoswikiTiny.switchToWYSIWYG(editor);
        FoswikiTiny.initialisedFromServer = true;
    },

    // Convert HTML content to textarea. Called from the WYSIWYG->raw switch
    switchToRaw : function (inst) {
        // As shown by OliverKrueger in Item5138, trivial text may include
        // UTF-8 chars. These need to be encoded to entities before we can
        // pass the string back to the server. This is done in triggerSave,
        // but note that it requires cleanup:true to work.
        inst.triggerSave(false, true);
        var text = inst.oldTargetElement.value;

        // Evaluate post-processors
        for (var i = 0; i < FoswikiTiny.html2tml.length; i++) {
            var cb = FoswikiTiny.html2tml[i];
            text = cb.apply(inst, [ inst, text ]);
        }
        FoswikiTiny.transform(
            inst, "html2tml", text,
            function () {
                FoswikiTiny.enableSave(false);
                var te = FoswikiTiny.request.editor.oldTargetElement;
                te.value = "Please wait... retrieving page from server";
            },
            function () {
                var te = FoswikiTiny.request.editor.oldTargetElement;
                var text = FoswikiTiny.request.req.responseText;
                te.value = text;
                FoswikiTiny.enableSave(true);
            },
            function () {
                var te = FoswikiTiny.request.editor.oldTargetElement;
                te.value = "There was a problem retrieving the page: "
                    + FoswikiTiny.request.req.statusText;
                //FoswikiTiny.enableSave(true); leave it disabled
            });
        // Add the button for the switch back to WYSIWYG mode
        var eid = inst.editorId;
        var id = eid + "_2WYSIWYG";
        var el = document.getElementById(id);
        if (el) {
            // exists, unhide it
            el.style.display = "block";
        } else {
            // does not exist, create it
            el = document.createElement('INPUT');
            el.id = id;
            el.type = "button";
            el.value = "WYSIWYG";
            el.className = "foswikiButton";
            el.onclick = function () {
                tinyMCE.execCommand("mceToggleEditor", null, inst.editorId);
                return false;
            }
            // Need to insert after to avoid knackering 'back'
            var pel = inst.oldTargetElement.parentNode;
            pel.insertBefore(el, inst.oldTargetElement);
        }
        // SMELL: what if there is already an onchange handler?
        inst.oldTargetElement.onchange = function() {
            var inst = tinyMCE.getInstanceById(eid);
            inst.isNotDirty = false;
            return true;
        }
    },

    // Convert textarea content to HTML. This is invoked from the content
    // setup handler, and also from the raw->WYSIWYG switch
    switchToWYSIWYG : function (editor) {
        // Kill the change handler to avoid excess fires
        editor.oldTargetElement.onchange = null;
        // Need to tinyMCE.execCommand("mceToggleEditor", null, editor_id);
        FoswikiTiny.transform(
            editor, "tml2html", editor.oldTargetElement.value,
            function () {
                // Before send
                FoswikiTiny.enableSave(false);
                var editor = FoswikiTiny.request.editor;
                tinyMCE.setInnerHTML(
                    FoswikiTiny.request.editor.getBody(),
                    "<span class='foswikiAlert'>Please wait... retrieving page from server.</span>");
            },
            function () {
                // Handle the reply
                var text = FoswikiTiny.request.req.responseText;
                // Evaluate any registered pre-processors
                for (var i = 0; i < FoswikiTiny.tml2html.length; i++) {
                    var cb = FoswikiTiny.tml2html[i];
                    text = cb.apply(editor, [ editor, text ]);
                }
                tinyMCE.setInnerHTML(FoswikiTiny.request.editor.getBody(), text);
                FoswikiTiny.request.editor.isNotDirty = true;
                FoswikiTiny.enableSave(true);
            },
            function () {
                // Handle a failure
                tinyMCE.setInnerHTML(
                    FoswikiTiny.request.editor.getBody(),
                    "<div class='foswikiAlert'>"
                    + "There was a problem retrieving the page: "
                    + FoswikiTiny.request.req.statusText + "</div>");
                //FoswikiTiny.enableSave(true); leave save disabled
            });

        // Hide the conversion button, if it exists
        var id = editor.editorId + "_2WYSIWYG";
        var el = document.getElementById(id);
        if (el) {
            // exists, hide it
            el.style.display = "none";
        }
    },

    // Callback on save. Make sure the WYSIWYG flag ID is there.
    saveCallback : function(editor_id, html, body) {
        // Evaluate any registered post-processors
        var editor = tinyMCE.getInstanceById(editor_id);
        for (var i = 0; i < FoswikiTiny.html2tml.length; i++) {
            var cb = FoswikiTiny.html2tml[i];
            html = cb.apply(editor, [ editor, html ]);
        }
        var secret_id = tinyMCE.getParam('foswiki_secret_id');
        if (secret_id != null && html.indexOf(
                '<!--' + secret_id + '-->') == -1) {
            // Something ate the ID. Probably IE. Add it back.
            html = '<!--' + secret_id + '-->' + html;
        }
        return html;
    },

    // Called 
    // Called on URL insertion, but not on image sources. Expand Foswiki
    // variables in the url.
    convertLink : function(url, node, onSave){
        if(onSave == null)
            onSave = false;
        var orig = url;
        var pubUrl = FoswikiTiny.getFoswikiVar("PUBURL");
        var vsu = FoswikiTiny.getFoswikiVar("VIEWSCRIPTURL");
        url = FoswikiTiny.expandVariables(url);
        if (onSave) {
            if ((url.indexOf(pubUrl + '/') != 0) &&
                (url.indexOf(vsu + '/') == 0)) {
                url = url.substr(vsu.length + 1);
                url = url.replace(/\/+/g, '.');
                if (url.indexOf(FoswikiTiny.getFoswikiVar('WEB') + '.') == 0) {
                    url = url.substr(FoswikiTiny.getFoswikiVar('WEB').length + 1);
                }
            }
        } else {
            if (url.indexOf('/') == -1) {
                // if it's a wikiword, make a suitable link
                var match = /^((?:\w+\.)*)(\w+)$/.exec(url);
                if (match != null) {
                    var web = match[1];
                    var topic = match[2];
                    if (web == null || web.length == 0) {
                        web = FoswikiTiny.getFoswikiVar("WEB");
                    }
                    web = web.replace(/\.+/g, '/');
                    web = web.replace(/\/+$/, '');
                    url = vsu + '/' + web + '/' + topic;
                }
            }
        }
        return url;
    },

    // Called from Insert Image, when the image is inserted. The resultant
    // URL is only used when displaying the image in the picture dialog. It
    // is thrown away (reverts to the typed address) when the image is
    // actually inserted, at which time convertLink is called.
    convertPubURL : function(url){
        var orig = url;
        var base = FoswikiTiny.getFoswikiVar("PUBURL") + '/'
        + FoswikiTiny.getFoswikiVar("WEB") + '/'
        + FoswikiTiny.getFoswikiVar("TOPIC") + '/';
        url = FoswikiTiny.expandVariables(url);
        if (url.indexOf('/') == -1) {
            url = base + url;
        }
        return url;
    },

    getMetaTag : function(inKey) {
        if (FoswikiTiny.metaTags == null || FoswikiTiny.metaTags.length == 0) {
            // Do this the brute-force way because of the Firefox problem
            // seen sporadically on Bugs where the DOM appears complete, but
            // the META tags are not all found by getElementsByTagName
            var head = document.getElementsByTagName("META");
            head = head[0].parentNode.childNodes;
            FoswikiTiny.metaTags = new Array();
            for (var i = 0; i < head.length; i++) {
                if (head[i].tagName != null &&
                    head[i].tagName.toUpperCase() == 'META') {
                    FoswikiTiny.metaTags[head[i].name] = head[i].content;
                }
            }
        }
        return FoswikiTiny.metaTags[inKey]; 
    },
    
    install : function() {
        // find the TINYMCEPLUGIN_INIT META
        var tmce_init = FoswikiTiny.getMetaTag('TINYMCEPLUGIN_INIT');
        if (tmce_init != null) {
            eval("tinyMCE.init({" + unescape(tmce_init) + "});");
            return;
        }
        alert("Unable to install TinyMCE; <META name='TINYMCEPLUGIN_INIT' is missing"); 
    }
};
