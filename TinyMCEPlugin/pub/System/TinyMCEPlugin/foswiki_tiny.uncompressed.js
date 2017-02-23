/*
  Copyright (C) 2007 Crawford Currie http://wikiring.com and Arthur Clemens
  Copyright (C) 2010-2017 Foswiki Contributors http://foswiki.org
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

    tml2html: new Array(),
    // callbacks, attached in plugins
    html2tml: new Array(),
    // callbacks, attached in plugins
    transformCbs: new Array(),

    //  This URL expansion is reversed by
    // WysiwygPlugin::Handlers::postConvertURL()
    expandVariables: function(url) {
        return url.replace(/%[A-Za-z0-9_]+%/g, function(i) {
            // Don't expand macros that are not reversed during save
            // Part of fix to Item13178
            if ( i === 'WEB' || i === 'TOPIC' || i === 'SYSTEMWEB' )
                return i;
            var p = foswiki.getPreference(i);
            if ( p === '' )
                return i;   // Empty variables are not reversible
            //console.log( 'expandVariables ' + i + ' expanded to ' + p );
            return p;
        });
    },

    saveEnabled: 0,
    enableSaveButton: function(enabled) {
        var status = enabled ? null : "disabled";
        FoswikiTiny.saveEnabled = enabled ? 1 : 0;
        var elm = document.getElementById("save");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("quietsave");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("checkpoint");
        if (elm) {
            elm.disabled = status;
        }
        elm = document.getElementById("preview");
        if (elm) {
            elm.style.display = 'none'; // Item5263: broken preview
            elm.disabled = status;
        }
    },

    transform: function(editor, handler, text, onSuccess, onFail) {
        // Work out the rest URL from the location
        var url = foswiki.getPreference("SCRIPTURL");
        var suffix = foswiki.getPreference("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        url += "/rest" + suffix + "/WysiwygPlugin/" + handler;
        var path = foswiki.getPreference("WEB") + '.' + 
            foswiki.getPreference("TOPIC");

        tinymce.util.XHR.send({
            url: url,
            content_type: "application/x-www-form-urlencoded",
            type: "POST",
            data: "nocache=" + encodeURIComponent((new Date()).getTime()) +
                  "&topic=" + encodeURIComponent(path) + "&text=" +
                  encodeURIComponent(text),
            async: true,
            scope: editor,
            success: onSuccess,
            error: onFail
        })
    },

    cleanBeforeSave: function(eid, buttonId) {
        var el = document.getElementById(buttonId);
        if (el == null) return;
        // SMELL: what if there is already an onclick handler?
        el.onclick = function() {
            var editor = tinymce.getInstanceById(eid);
            editor.isNotDirty = true;
            return true;
        }
    },

    onSubmitHandler: false,

    // Convert HTML content to textarea. Called from the WYSIWYG->raw switch
    switchToRaw: function(editor) {
        var text = editor.getContent();

        // Make the raw-edit help visible (still subject to toggle)
        var el = document.getElementById("foswikiTinyMcePluginWysiwygEditHelp");
        if (el) {
            el.style.display = 'none';
        }
        el = document.getElementById("foswikiTinyMcePluginRawEditHelp");
        if (el) {
            el.style.display = 'block';
        }

        // Evaluate post-processors attached from plugins
        for (var i = 0; i < FoswikiTiny.html2tml.length; i++) {
            var cb = FoswikiTiny.html2tml[i];
            text = cb.apply(editor, [editor, text]);
        }
        FoswikiTiny.enableSaveButton(false);

        editor.getElement().value = "Please wait... retrieving page from server.";
        FoswikiTiny.transform(
        editor, "html2tml", text, function(text, req, o) {
            editor.getElement().value = text;
            FoswikiTiny.enableSaveButton(true);
            // Call post-transform callbacks attached from plugins
	    for (var i = 0; i < FoswikiTiny.transformCbs.length; i++) {
		var cb = FoswikiTiny.transformCbs[i];
		cb.apply(editor, [editor, text]);
	    }
        },
        function(type, req, o) {
            editor.setContent("<div class='foswikiAlert'>" + 
                "There was a problem retrieving " + o.url + ": " + type + " " +
                req.status + "</div>");
            //FoswikiTiny.enableSaveButton(true); leave save disabled
        });
        // Add the button for the switch back to WYSIWYG mode
        var eid = editor.id;
        var id = eid + "_2WYSIWYG";
        var el = document.getElementById(id);
        if (el) {
            // exists, unhide it
            el.style.display = "inline";
        } else {
            // does not exist, create it
            el = document.createElement('INPUT');
            el.id = id;
            el.type = "button";
            el.value = "WYSIWYG";
            el.className = "foswikiButton";
            
	    // Need to insert after to avoid knackering 'back'
	    var pel = editor.getElement().parentNode;
	    pel.insertBefore(el, editor.getElement());
        }
	el.onclick = function() {
	    // Make the wysiwyg help visible (still subject to toggle)
	    var el_help = document.getElementById(
		"foswikiTinyMcePluginWysiwygEditHelp");
	    if (el_help) {
		el_help.style.display = 'block';
	    }
	    el_help = document.getElementById("foswikiTinyMcePluginRawEditHelp");
	    if (el_help) {
		el_help.style.display = 'none';
	    }
	    tinymce.execCommand("mceToggleEditor", null, eid);
	    FoswikiTiny.switchToWYSIWYG(editor);
	    return false;
	}

	// remove class 'foswikiHasWysiwyg' to make non-wysiwyg controls visible 
	var body = document.getElementsByTagName('body')[0];
	tinymce.DOM.removeClass(body, 'foswikiHasWysiwyg');

        // SMELL: what if there is already an onchange handler?
        editor.getElement().onchange = function() {
            var editor = tinymce.getInstanceById(eid);
            editor.isNotDirty = false;
            return true;
        },
        // Ooo-err. Stomp on the default submit handler and
        // forcibly disable the editor to prevent a call to
        // the TMCE save. This in turn blocks the getContent
        // that would otherwise wipe out the content of the
        // textarea with the DOM. We'd better make damn sure we
        // remove this handler when we switch back!
        editor.onSubmitHandler = function(ed, e) {
            // SMELL: Editor.initialized is undocumented and liable
            // to break when we upgrade TMCE
            editor.initialized = false;
        };
        /* Item14323
        // SMELL: Event.addToTop() is undocumented and liable
        // to break when we upgrade TMCE
        editor.onSubmit.addToTop(editor.onSubmitHandler);
        */
        // Make the save buttons mark the text as not-dirty 
        // to avoid the popup that says "Are you sure? The changes you have
        // made will be lost"
        FoswikiTiny.cleanBeforeSave(eid, "save");
        FoswikiTiny.cleanBeforeSave(eid, "quietsave");
        FoswikiTiny.cleanBeforeSave(eid, "checkpoint");
        // preview shouldn't get the popup either, when preview is enabled one
        // day
        FoswikiTiny.cleanBeforeSave(eid, "preview");
        // cancel shouldn't get the popup because the user just *said* they
        // want to cancel
        FoswikiTiny.cleanBeforeSave(eid, "cancel");
    },
    
    // Convert textarea content to HTML. This is invoked from the content
    // setup handler, and also from the raw->WYSIWYG switch
    switchToWYSIWYG: function(editor) {
        // Kill the change handler to avoid excess fires
        editor.getElement().onchange = null;

        // Get the textarea content
        var text = editor.getElement().value;

        if (editor.onSubmitHandler) {
            editor.onSubmit.remove(editor.onSubmitHandler);
            editor.onSubmitHandler = null;
        }
        FoswikiTiny.enableSaveButton(false);

	var throbberPath = foswiki.getPreference('PUBURLPATH') + '/' + foswiki.getPreference('SYSTEMWEB') + '/' + 'DocumentGraphics/processing.gif';
        editor.setContent("<img src='" + throbberPath + "' />");
        
        FoswikiTiny.transform(
        editor, "tml2html", text, function(text, req, o) { // Success
            // Evaluate any registered pre-processors
            for (var i = 0; i < FoswikiTiny.tml2html.length; i++) {
                var cb = FoswikiTiny.tml2html[i];
                text = cb.apply(this, [this, text]);
            }
            /* SMELL: Work-around for Item2270. In future this plugin may
                   be updated so that this needs to be changed. TMCE's wordcount
                   plugin limits itself to a max. of one count per
                   2 seconds, so users always see a wordcount of 6 (Please
                   wait... retrieving page from server) when they first edit a
                   document. So remove lock before setContent() */
            if (editor.plugins.wordcount !== undefined && 
                editor.plugins.wordcount.block !== undefined) {
                editor.plugins.wordcount.block = 0;
            }
            editor.setContent(text);
            editor.isNotDirty = true;
            FoswikiTiny.enableSaveButton(true);
            
            // Hide the conversion button, if it exists
	    var id = editor.id + "_2WYSIWYG";
	    var el = document.getElementById(id);
	    if (el) {
		// exists, hide it
		el.style.display = "none";
				
		// and show controls
		var body = document.getElementsByTagName('body')[0];
		tinymce.DOM.addClass(body, 'foswikiHasWysiwyg');
	    }
			
            // Call post-transform callbacks attached from plugins
	    for (var i = 0; i < FoswikiTiny.transformCbs.length; i++) {
		var cb = FoswikiTiny.transformCbs[i];
		cb.apply(editor, [editor, text]);
	    }
        },
        function(type, req, o) {
            // Handle a failure
            editor.setContent(
                "<div class='foswikiAlert'>" + 
                    "There was a problem retrieving " + o.url + ": " + type + 
                    " " + req.status + "</div>");
            //FoswikiTiny.enableSaveButton(true); leave save disabled
        }); 
    },

    // urlconverter_callback - was convertLink, completely rewritten
    // for Item14323
    urlconverter_callback: function(url, node, onSave) {
        if (tinymce.activeEditor.serialising) {
            // Prepping HTML for save. Want to convert URLs back
            // into %PREFERENCES%
            var PUBURL = new RegExp("^" + foswiki.getPreference("PUBURL") + "/");
            var WEB = new RegExp("/" + foswiki.getPreference('WEB') + "/");
            var TOPIC = new RegExp("/" + foswiki.getPreference('TOPIC') + "/");
            url = url.replace(PUBURL, "%PUBURL%/");
            url = url.replace(WEB, "/%WEB%/");
            url = url.replace(TOPIC, "/%TOPIC%/");
            var VSURL = foswiki.getPreference("VIEWSCRIPTURL");
            if (url.indexOf('/') == -1) {
                // if it's a wikiword, make a suitable view link
                var match = /^((?:\w+\.)*)(\w+)$/.exec(url);
                if (match != null) {
                    var web = match[1];
                    var topic = match[2];
                    if (web == null || web.length == 0)
                        web = WEB;
                    web = web.replace(/\.+/g, '/');
                    web = web.replace(/\/+$/, '');
                    url = VSURL + '/' + web + '/' + topic;
                }
            } else {
                var SURL = foswiki.getPreference("SCRIPTURL");
                url = url.replace(new RegExp("^" + VSURL + "/", "g"),
                                  "%VIEWSCRIPTURL%/");
                url = url.replace(new RegExp("^" + SURL + "/", "g"),
                                  "%SCRIPTURL%/");
            }
        } else {
            // Not serialising, want to convert %PREFERENCES% to URLs
            url = url.replace(/%[A-Za-z0-9_]+%/g, function(m) {
                var r = foswiki.getPreference(m);
                return (r && r !== '') ? r : m;
            });
        }
        return url;
    },

    // Convert a simple attachment name into a URL - Item14323
    _makeAttachmentURL: function(url) {
        url = FoswikiTiny.expandVariables(url);
        if (url.indexOf('/') == -1) {
            var base = foswiki.getPreference("PUBURL") + '/' + 
                foswiki.getPreference("WEB") + '/' + 
                foswiki.getPreference("TOPIC") + '/';
            url = base + url;
        }
        return url;
    },

    install: function(init) {
        // find the TINYMCEPLUGIN_INIT preference
        if (! init) {
            init = FoswikiTiny.init;
        }

        // Catch events to know when we are serialising - Item14323
        init.init_instance_callback = function(editor) {
            FoswikiTiny.switchToWYSIWYG(editor);

            editor.on('PreProcess', function(e) {
                editor.serialising = true;
            })
            editor.on('PostProcess', function(e) {
                editor.serialising = false;
            })
        };

        // Moved from init - Item14323
        init.urlconverter_callback = FoswikiTiny.urlconverter_callback;

        // Supply an image_list for the image plugin that calls
        // back to the server for content - Item14323
        init.image_list = function(callback) {
            FoswikiTiny.getListOfAttachments(function(list) {
                // The REST call gives us a list of Foswiki meta-data
                // Convert to TMCE-speak
                var ml = [];
                for (var i in list)
                    // Expand simple attachment name into a pub
                    // reference
                    var url = FoswikiTiny._makeAttachmentURL(
                        list[i].attachment);
                    ml.push({
                        url: url,
                        value: url,
                        text: list[i].attachment
                    });               
                callback(ml);
            });
        };
        
        if (init) {
            tinymce.init(init);
        }
    },

    getTopicPath: function() {
        return foswiki.getPreference("WEB") + '.' + foswiki.getPreference("TOPIC");
    },

    getScriptURL: function(script) {
        var scripturl = foswiki.getPreference("SCRIPTURL");
        var suffix = foswiki.getPreference("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        return scripturl + "/" + script + suffix;
    },

    getRESTURL: function(fn) {
        return this.getScriptURL('rest') + "/WysiwygPlugin/" + fn;
    },

    getListOfAttachments: function(onSuccess) {
        var url = FoswikiTiny.getRESTURL('attachments');
        var path = FoswikiTiny.getTopicPath();
        var params = "nocache=" + 
            encodeURIComponent((new Date()).getTime()) + "&topic=" +
            encodeURIComponent(path);

        tinymce.util.XHR.send({
            url: url + "?" + params,
            type: "POST",
            content_type: "application/x-www-form-urlencoded",
            data: params,
            success: function(atts) {
                if (atts != null) {
                    onSuccess(eval(atts));
                }
            }
        });
    }
};
