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
var jQuery, $; // access to jQuery in the parent

var AttachDlg = {

    preInit: function() {
        tinyMCEPopup.requireLangPack();
    },

    // invoked on load from the body of the dialog
    // JQuery is *not* available, as we're in the DOM of the attach.htm
    init: function(ed) {
        if (typeof($) == "undefined") {
            var iframeBody = document.getElementsByTagName("body")[0];
            // Note this isn't the jQuery object, it's just a means of
            // accessing the DOM of this iframe
            jQuery = parent.window.jQuery;
            $ = function (selector) {
                return parent.jQuery(selector, iframeBody);
            };
        }

        // Insert a link to the selected attachment in the text
        $('#insert').click(function() {
            AttachDlg.insert($('#attachments_select').val());
        });

        FoswikiTiny.getListOfAttachments(
            function(atts) {
                var select = $("#attachments_select");
                if (atts.length > 0) {
                    for (var i = 0; i < atts.length; i++) {
                        select.append('<option value="' + atts[i].name + '">'
                                      + atts[i].name + '</option>');
                    }
                } else {
                    // There are no attachments, so select upload tab.
                    $('#general_tab').removeClass('current');
                    $('#general_panel').removeClass('current');
                    $('#upload_tab').addClass('current');
                    $('#upload_panel').addClass('current');
                }
            });

        // Prepare the form for submission
        var $form = $('#upload_form');
        var url = FoswikiTiny.getScriptURL('upload');
        $('#upload_form_topic').val(FoswikiTiny.getTopicPath());
        $form.submit(function() {
            AttachDlg.submit(url, $form);
            return false;
        });

        /*$('input[type=file]').on('change', function(e) {
            $form.data('files', e.target.files);
        });*/

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
                $('#validation_key').val(StrikeOne.calculateNewKey(nonce));
            }
        }
        /*jQuery.each($form.data('files'), function(k, v) {
            $form.append(k, v);
        });*/

        // Assumes an HTML5 browser
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
                $('#status_frame').text(jqXHR.responseText);
            },
            error: function(jqXHR, textStatus, error) {
                $('#status_frame').text(
                    '<div style="colour:red">' +
                        jqXHR.responseText + '</div>');
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
    }
};

AttachDlg.preInit();
tinyMCEPopup.onInit.add(AttachDlg.init, AttachDlg);
