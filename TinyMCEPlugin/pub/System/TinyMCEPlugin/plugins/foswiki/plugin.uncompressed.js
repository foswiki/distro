/*
  Copyright (C) 2007-2017 Crawford Currie http://c-dot.co.uk
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

/**
 * TinyMCE plugin that implements most Foswiki features
 */
"use strict";
(function ($) {

    // Convert a simple attachment name into a URL
    function makeAttachmentURL(url) {
        // Expand %PREFERENCES% in a URL.
        // This expansion is reversed by
        // WysiwygPlugin::Handlers::postConvertURL()
        url = url.replace(/%[A-Za-z0-9_]+%/g, function(i) {
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

        if (url.indexOf('/') == -1) {
            var base = foswiki.getPreference("PUBURL") + '/' + 
                foswiki.getPreference("WEB") + '/' + 
                foswiki.getPreference("TOPIC") + '/';
            url = base + url;
        }
        return url;
    };

    // Get a list of attachments, in an array of META:FILEATTACHMENT fields
    function getListOfAttachments(onSuccess) {
        var url = foswiki.getScriptUrl('rest', "WysiwygPlugin", "attachments");
        var path = foswiki.getPreference("WEB")
            + '.' + foswiki.getPreference("TOPIC");
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
    };
    
    /**
     * Used to convert URLs from linkable format back
     * to Foswiki macros (as far as possible)
     */
    function convertURIForSave(url) {
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
        return url;
    }

    /**
     * Convert URI from Foswiki %MACRO% format
     * to a linkable format
     */
    function convertURIForLoad(url) {
        return url.replace(/%[A-Za-z0-9_]+%/g, function(m) {
            var r = foswiki.getPreference(m);
            return (r && r !== '') ? r : m;
        });
    };
   
    /**
     * Transform text to/from TML
     */
    function transform(editor, handler, text, onSuccess, onFail) {
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
    };


    // Convert HTML content to textarea. Called from the WYSIWYG->raw switch
    function switchToRaw(self, editor) {
        var text = editor.getContent();

        editor.getElement().value = "Please wait... retrieving page from server.";
        transform(
            editor, "html2tml", text, function(text, req, o) {
                var el = editor.getElement();
                el.value = text;
                $(el).trigger("fwSwitchToRaw", editor);
                // Muddy-boots the initialized status of the editor to
                // block the save event that would otherwise blow away
                // the textarea content when a submit event is raised
                // for a form that wraps around the editor.
                editor.initialized = false;
                editor.hide();
            },
            function(type, req, o) {
                editor.notificationManager.open({
                    text: "There was a problem retrieving " + o.url + ": "
                        + type + " " +
                        req.status,
                    type: 'error'
                });
            });
    }
    
    // Convert textarea content to HTML. This is invoked from the content
    // setup handler, and also from the raw->WYSIWYG switch
    function switchToWYSIWYG(self, editor) {
        // Get the textarea content
        var el = editor.getElement(),
            text = el.value;

        // When switching back from a raw edit, a show side-effects
        // and will re-load the content from the textarea, which contains
        // the raw TML. So we hide the editable area until the transform
        // is finished. Not pretty, but it works.
        $(editor.getBody()).hide();
        // This is supposed to start a throbber, but I've yet to see one.
        editor.setProgressState(true);
        // Now do the show. This will load the (hidden) editable area from
        // the textarea.
        editor.show();
        
        transform(
            editor, "tml2html", text, function(text, req, o) { // Success
                // Set the HTML content in the editable area (doesn't affect
                // the textarea, which still has the raw TML)
                editor.setContent(text);
                // Undo the hide above
                $(editor.getBody()).show();
                // Kill the progress state
                editor.setProgressState(false);
                // We can do this safely because the only way this code can
                // be reached is through an execCommand, and that's only
                // available when the editor is initialised. Reverse the
                // muddy-bootsing of the initialized status done in switchToRaw
                // (see above for details of why)
                editor.initialized = true;
                editor.isNotDirty = true;
                $(el).trigger("fwSwitchToWYSIWYG", editor);
            },
            function(type, req, o) {
                // Kill the progress state
                editor.setProgressState(false);
                editor.hide();
                // Handle a failure by firing an event back at the
                // textarea we are sitting on
                $(editor.getElement()).trigger(
                    "fwTxError",
                    "There was a problem retrieving " + o.url
                        + ": " + type + " " + req.status);
            }); 
    };
    
    // Dialog for the "fwupload" button
    function showUploadDialog() {
        function handle_message(text) {
            // Is it a recognised message? English only, sorry
            var m = /OopsException\(attention\/(\w+)/.exec(text);
            if (m && m[1].length) {
                editor.notificationManager.open({
                    text: m[1],
                    type: 'error'
                });
            }
        };
        
        function onSubmit() {
            var attname = this.find('#attname');
            // Dig out the DOM element to get the file
            var file = attname[0].$el[0].files[0];
            if (!file)
                return;

            var formData = new FormData();
            formData.append("noredirect", 1);
            formData.append("filepath", file, attname.value());

            var comment = this.find('#comment').value();
            if (comment)
                formData.append("filecomment", comment);
            if (this.find('#hide').value())
                formData.append("hidefile", 1);
            
            var key_carrier = parent.document.EditForm.validation_key;
            if (typeof(StrikeOne) !== 'undefined') {
                // Get the validation key from the textarea
                var nonce = key_carrier.value;
                if (nonce)
                    // Transfer to the upload form
                    formData.append('validation_key',
                                    StrikeOne.calculateNewKey(nonce));
            }

            var url = foswiki.getScriptUrl(
                'upload',
                foswiki.getPreference("WEB"),
                foswiki.getPreference("TOPIC"));
            
            jQuery.ajax({
                url: url,
                type: "POST",
                data: formData,
                mimeType:"multipart/form-data",
                contentType: false, // to protect multipart
                processData: false,
                cache: false,
                success: function(data, textStatus, jqXHR) {
                    tinymce.activeEditor.notificationManager.open({
                        text: jqXHR.responseText,
                        type: 'info' });
                },
                error: function(jqXHR, textStatus, error) {
                    tinymce.activeEditor.notificationManager.open({
                        text: jqXHR.responseText,
                        type: 'error' } );
                },
                complete: function(jqXHR, textStatus) {
                    var nonce = jqXHR.getResponseHeader('X-Foswiki-Validation');
                    // patch in new nonce
                    if (nonce)
                        key_carrier.value = "?" + nonce;
                }
            });
        }
        
        tinymce.activeEditor.windowManager.open(
            {
		title: 'Upload attachment',
                onSubmit: onSubmit,
                bodyType: 'form',
		body: [
                    {
			label: 'Upload new attachment',
			name: 'attname',
			type: 'textbox',
                        subtype: 'file'
		    },
		    {
			label: 'Comment',
			name: 'comment',
			type: 'textbox'
		    },
                    {
			label: 'Hide attachment',
			name: 'hide',
			type: 'checkbox'
                    }
                ]
            });
    }

    // Dialog for the "fwinsertlink" button
    function showInsertLinkDialog(list) {
        var itemList = [];
        tinymce.each(list, function(item) {
            itemList.push({ text: item.attachment, value: item.attachment });
        });
        
        function onSubmit() {
            var filename = this.find('#insert').value();
            var inst = top.tinymce.activeEditor;
            var url = foswiki.getPreference("PUBURL") + "/"
                + foswiki.getPreference("WEB") + "/"
                + foswiki.getPreference("TOPIC");
            url += '/' + filename;
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
            inst.execCommand('mceInsertContent', false, html);
        }
        
        tinymce.activeEditor.windowManager.open(
 	    {
		title: 'Insert link to attachment',
                onSubmit: onSubmit,
		bodyType: 'form',
		body: [
                    {
			label: 'Insert link',
			name: 'insert',
			type: 'listbox',
                        values: itemList
		    },
                ]
	    });
    }

    var next_style = {
        "foswikiListStyle1": "foswikiListStyleA",
        "foswikiListStyleA": "foswikiListStylea",
        "foswikiListStylea": "foswikiListStyleI",
        "foswikiListStyleI": "foswikiListStylei",
        "foswikiListStylei": "foswikiListStyle1"
    };

    
    // onclick for "fwchangelisttype"
    function handleChangeListType(ed) {
        var node = ed.dom.getParent(
            ed.selection.getStart(), function(f) {
                return ed.dom.is(f, 'ol, ul');
            });

        if (node.tagName === "OL") {
            for (var i in next_style) {
                if (ed.dom.hasClass(node, i)) {
                    ed.dom.removeClass(node, i);
                    ed.dom.addClass(node, next_style[i]);
                    return;
                }
            }
            ed.dom.addClass(node, 'foswikiListStylea');
        } else {
            if (ed.dom.hasClass(node, 'foswikiListStyleNone'))
                ed.dom.removeClass(node, 'foswikiListStyleNone')
            else
                ed.dom.addClass(node, 'foswikiListStyleNone');
        }
    }
    
    // onclick for "fwhide"
    function handleHide(ed) {
        if (ed.plugins.fullscreen && ed.plugins.fullscreen.isFullscreen())
            ed.execCommand('mceFullScreen');
        ed.execCommand("fwSwitchToRaw");
    }

    // Create the plugin it'll be added later
    tinymce.create('tinymce.plugins.Foswiki', {
        format_names: [],
        
        init: function (ed, url) {
            var self = this;
            
            ed.addCommand('fwSwitchToWYSIWYG', function(ui, v) {
                switchToWYSIWYG(self, this);
            });
            
            ed.addCommand('fwSwitchToRaw', function(ui, v) {
                switchToRaw(self, this);
            });
            
            ed.addCommand('fwsave', function(ui, v) {
                // If the editor is hidden, don't
                // mceSave, let the caller handle it. Otherwise we'll
                // do an extra conversion which was already done when
                // switching the editor to raw.
                if (!ed.isHidden())
                    this.execCommand("mceSave");
            });
            
            ed.addButton('fwtt', {
                title: 'Typewriter text',
                onclick: function(evt) { ed.formatter.toggle('WYSIWYG_TT'); },
                image: url + '/img/tt.gif',
                onpostrender: function() {
                    var btn = this;
                    ed.on("NodeChange", function(e) {
                        btn.disabled($(e.element).hasClass('WYSIWYG_TT'));
                    });
                }
            });
            
            if (typeof(FormData) !== 'undefined'
                && !foswiki.getPreference("TOPIC").match(
                        /(X{10}|AUTOINC[0-9]+)/))
            {
                ed.addButton('fwupload', {
                    title: 'Upload attachment',
                    image: url + '/img/upload.gif',
                    onclick: function () {
                        getListOfAttachments(showUploadDialog);
                    }
                });
            };
            // else browser too old (need HTML5 FormData), or the topic is
            // AUTOINC
            
            ed.addButton('fwinsertlink', {
                title: 'Insert link to attachment',
                image: url + '/img/insertlink.gif',
                onclick: function () {
                    getListOfAttachments(showInsertLinkDialog);
                }
            });
            
            ed.addButton('fwchangelisttype', {
                title: 'Change bullet/number style',
                image: url + '/img/changeliststyle.gif',
                onClick: function() { handleChangeListType(ed); },
                onpostrender: function() {
                    var btn = this;
                    ed.on("NodeChange", function(e) {
                        btn.disabled(
                            !ed.queryCommandState("InsertUnorderedList")
                                && !ed.queryCommandState("InsertOrderedList"));
                    });
                }

            });
            
            ed.addButton('fwhide', {
                title: 'Edit Foswiki markup',
                image: url + '/img/hide.gif',
                onClick: function () { handleHide(ed); }
            });
        },

        convertURI: function(url, onSave) {
            return (onSave) ? convertURIForSave(url)
                : convertURIForLoad(url);
        },
        
        // Callback used by image plugin to get a list of images
        getImageList: function(callback) {
            getListOfAttachments(function(list) {
                // The REST call gives us a list of Foswiki meta-data
                // Convert to TMCE-speak
                var ml = [];
                for (var i in list) {
                    // Expand simple attachment name into a pub
                    // reference
                    var url = makeAttachmentURL(list[i].attachment);
                    ml.push({
                        url: url,
                        value: url,
                        text: list[i].attachment
                    });
                }
                callback(ml);
            });
        },

        getInfo: function () {
            return {
                longname: 'Foswiki Plugin',
                author: 'Crawford Currie',
                authorurl: 'http://c-dot.co.uk',
                infourl: 'http://c-dot.co.uk',
                version: 3
            };
        }
    });

    // Register plugin
    tinymce.PluginManager.add('foswiki', tinymce.plugins.Foswiki);
})(jQuery);
