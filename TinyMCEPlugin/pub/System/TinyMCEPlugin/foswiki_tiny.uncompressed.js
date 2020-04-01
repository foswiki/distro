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

// This is a global singleton object, similar to 'tinymce'. It provides
// services that are specific to Foswiki, such as callbacks, initialisation,
// and provides services for conversion to/from TML.
var FoswikiTiny = {};

// Wrapper around tinymce.init. Sets up the extra init data that should
// not be changed in the Foswiki setup, and attaches handlers and callbacks.
FoswikiTiny.init = function(init) {
    init.extended_valid_elements = "li[type],a[rel|rev|charset|hreflang|tabindex|accesskey|type|name|href|target|title|class|onfocus|onblur|data*]";
    init.entity_encoding = "numeric";
    init.keep_styles = false;
    
    // Catch events to know when we are serialising
    init.init_instance_callback = function(editor) {
        editor.on('PreProcess', function(e) {
            editor.serialising = true;
        })
        editor.on('PostProcess', function(e) {
            editor.serialising = false;
        });
        editor.execCommand("fwSwitchToWYSIWYG");
    };

    init.formats = {
        WYSIWYG_TT: {
            inline: 'span',
            classes: 'WYSIWYG_TT'
        },
        WYSIWYG_COLOR: [
            {
                inline: 'span',
                classes: 'WYSIWYG_COLOR',
                styles: { color: '%value' }
            },
            {
                /* This entry allows WYSIWYG_COLOR to match without
                   a specific color attribute, used for button state */
                inline: 'span',
                classes: 'WYSIWYG_COLOR'
            }
        ],
        IS_WYSIWYG_COLOR: {
            inline: 'span',
            classes: 'WYSIWYG_COLOR'
        }
    };
    
    // URLs absolute
    init.relative_urls = false;
    // Don't fiddle with them
    init.remove_script_host = false;
    init.convert_urls = true;
    init.urlconverter_callback = function(url, node, onSave) {
        var editor = tinymce.activeEditor;
        return editor.plugins.foswiki.convertURI(
            url, editor.serialising);
    };

    // Supply an image_list for the image plugin that calls
    // back to the server for content - Item14323
    init.image_list = function(callback) {
        return tinymce.activeEditor.plugins.foswiki.getImageList(callback);
    };
    
    tinymce.init(init);
};
