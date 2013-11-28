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
var AttachDlg = {

    preInit: function() {
        tinyMCEPopup.requireLangPack();
    },

    // invoked on load from the body of the dialog
    init: function(ed) {
        FoswikiTiny.getListOfAttachments(
        function(atts) {
            var select = document.getElementById("attachments_select");
            if (atts.length > 0) {
                for (var i = 0; i < atts.length; i++) {
                    select.options[i] = new Option(atts[i].name, atts[i].name);
                }
            } else {
                /* There are no attachments, so select upload tab. NB: JQuery
                ** not available in popup iframes, and TinyMCE's dom utils
                ** won't be able to select an element by id string by itself
                ** because the activeEditor seems to only scan its own
                ** document, so we pass the iframe's dom element explicitly */
                ed.dom.removeClass(document.getElementById('general_tab'), 'current');
                ed.dom.removeClass(document.getElementById('general_panel'), 'current');
                ed.dom.addClass(document.getElementById('upload_tab'), 'current');
                ed.dom.addClass(document.getElementById('upload_panel'), 'current');
            }
        });

        // Write the correct action into the form in attach.htm
        var el = document.getElementById('upload_form');
        el.action = FoswikiTiny.getRESTURL('upload');
        el = document.getElementById('upload_form_topic');
        el.value = FoswikiTiny.getTopicPath();
        tinyMCEPopup.resizeToInnerSize();
    },

    // Insert a link to the selected attachment in the text
    insertLink: function() {
        var inst = tinyMCE.activeEditor;
        var select = document.getElementById("attachments_select");
        var filename = select.value;
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
    }
};

AttachDlg.preInit();
tinyMCEPopup.onInit.add(AttachDlg.init, AttachDlg);
