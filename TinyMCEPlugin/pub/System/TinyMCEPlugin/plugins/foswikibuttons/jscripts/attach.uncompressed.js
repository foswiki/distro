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
var jQuery, $, // access to jQuery in the parent
    $dlg;      // access to jQuery elements in the dialog

var AttachDlg = {

    preInit: function() {
        tinyMCEPopup.requireLangPack();
    },

    // invoked on load from the body of the dialog
    // JQuery is *not* available, as we're in the DOM of the attach.htm
    init: function(ed) {
        if (typeof(jQuery) == "undefined") {
            var iframeBody = document.getElementsByTagName("body")[0];
            // Note this isn't the jQuery object, it's just a means of
            // accessing the DOM of this iframe
            jQuery = parent.window.jQuery;
            $ = jQuery;
            $dlg = function (selector) {
                return parent.jQuery(selector, iframeBody);
            };
        }

        // Insert a link to the selected attachment in the text
        $dlg('#insert').click(function() {
            AttachDlg.insert($dlg('#attachments_select').val());
        });

        FoswikiTiny.getListOfAttachments(
            function(atts) {
                var select = $dlg("#attachments_select");
                if (atts.length > 0) {
                    for (var i = 0; i < atts.length; i++) {
                        select.append('<option value="' + atts[i].name + '">'
                                      + atts[i].name + '</option>');
                    }
                } else {
                    // There are no attachments, so select upload tab.
                    $dlg('#general_tab').removeClass('current');
                    $dlg('#general_panel').removeClass('current');
                    $dlg('#upload_tab').addClass('current');
                    $dlg('#upload_panel').addClass('current');
                }
            });

        // Prepare the form for submission
        var $form = $dlg('#upload_form');
        var url = FoswikiTiny.getScriptURL('upload');
        $dlg('#upload_form_topic').val(FoswikiTiny.getTopicPath());
        $form.submit(function() {
            return AttachDlg.submit(url, $form);
        });

        tinyMCEPopup.resizeToInnerSize();
        
    },

    insert: function(filename) {
        var inst = tinyMCE.activeEditor;
        var url = FoswikiTiny.getFoswikiVar("ATTACHURL") + '/' + filename;
        var tmp = filename.lastIndexOf(".");
        if (tmp >= 0) tmp = 
            filename.substring(tmp + 1, filename.length).toLowerCase();

        var html;
        if (tmp == "jpg" || tmp == "gif" || tmp == "jpeg" ||
            tmp == "png" || tmp == "bmp") {
            html = "<img src='" + url + "' alt='" + filename + "'>";
        } else {
            html = "<a href='" + url + "'>" + filename + "</a>";
        }
        inst.execCommand('mceInsertContent', false, html);
        inst.nodeChanged();

        tinyMCEPopup.close();
    },

    submit: function(url, $form) {
        var key_carrier = parent.document.EditForm.validation_key;
        if (typeof(StrikeOne) !== 'undefined') {
             // Get the validation key from the textarea
            var nonce = key_carrier.value;
            if (nonce) {
                // Transfer to the upload form
                $dlg('#validation_key').val(StrikeOne.calculateNewKey(nonce));
            }
        }
        $dlg('#status_frame').text('Uploading...');

        if (false && typeof(FormData) !== 'undefined') {
            // HTML5 browser, so we can use FormData to do the upload
            var formData = new FormData($form[0]);

            jQuery.ajax({
                url: url,
                type: "POST",
                data: formData,
                mimeType:"multipart/form-data",
                contentType: false, // to protect multipart
                processData: false,
                cache: false,
                success: function(data, textStatus, jqXHR) {
                    AttachDlg.handle_message(jqXHR.responseText);
                },
                error: function(jqXHR, textStatus, error) {
                    AttachDlg.handle_message(jqXHR.responseText);
                },
                complete: function(jqXHR, textStatus) {
                    var nonce = jqXHR.getResponseHeader(
                        'X-Foswiki-Validation');
                    // patch in new nonce
                    if (nonce) {
                        key_carrier.value = "?" + nonce;
                    }
                }
            });
            return false;
        }

        // Browser too old, doesn't support FormData :-(
        // Use an iframe and tell the server not to expire the
        // validation code.
        $form.attr('action', url);
        if (!$form[0].preserve_vk) {
            $form.append('<input type="hidden" name="preserve_vk" value="1" />')
        }

	$dlg('iframe[name="upload_iframe"]').load(
            function(e)
	    {
		var doc = $(e.target.contentDocument);
		// data return from server. No access to the HTTP
                // headers, which is a PITA
		AttachDlg.handle_message($('body', doc).html());
	    });
        return true;
    },

    handle_message: function(text) {
        // Is it a recognised message? English only, sorry
        var m = /OopsException\(attention\/(\w+)/.exec(text);
        if (m) {
            var mel = $dlg('#' + m[1]);
            if (mel.length) {
                $dlg('#status_frame').html(mel.html());
                return;
            }
        };
        $dlg('#status_frame').text(text);
    }
};

AttachDlg.preInit();
tinyMCEPopup.onInit.add(AttachDlg.init, AttachDlg);
