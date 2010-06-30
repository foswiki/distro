/*
  Copyright (C) 2007-2009 Crawford Currie http://c-dot.co.uk
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
(function() {
    tinymce.PluginManager.requireLangPack('foswikibuttons');

    tinymce.create('tinymce.plugins.FoswikiButtons', {
        // formats listbox
        formats_lb: null,

        init: function(ed, url) {

            ed.fw_formats = ed.getParam("foswikibuttons_formats");
            ed.fw_format_names = [];
            jQuery.each(ed.fw_formats, function (key, value) {
                ed.fw_format_names.push(key);
            });
            ed.fw_listbox = null;
            ed.onInit.add(function () {
                ed.formatter.register('WYSIWYG_TT', {
                    inline: 'span',
                    classes: 'WYSIWYG_TT'
                });
                ed.formatter.register('WYSIWYG_COLOR', [
                    {
                        inline:  'span',
                        classes: 'WYSIWYG_COLOR',
                        styles: {
                            color: '%value'
                        }
                    },
                    /* This entry allows WYSIWYG_COLOR to match without
                       a specific color attribute, used for button state */
                    {
                        inline: 'span',
                        classes: 'WYSIWYG_COLOR'
                    }
                ]);
                ed.formatter.register('IS_WYSIWYG_COLOR', {
                    inline:  'span',
                    classes: 'WYSIWYG_COLOR',
                });
                ed.formatter.register(ed.fw_formats);
            });

            // Register commands
            ed.addCommand('foswikibuttonsTT', function() {
                ed.formatter.toggle('WYSIWYG_TT');
            });

            // Register buttons
            ed.addButton('tt', {
                title: 'foswikibuttons.tt_desc',
                cmd: 'foswikibuttonsTT',
                image: url + '/img/tt.gif'
            });

            ed.addCommand('foswikibuttonsColour', function() {
                if (ed.selection.isCollapsed()) return;
                ed.windowManager.open({
                    location: false,
                    menubar: false,
                    toolbar: false,
                    status: false,
                    url: url + '/colours.htm',
                    width: 220,
                    height: 280,
                    movable: true,
                    popup_css: false,
                    // not required
                    inline: true
                },
                {
                    plugin_url: url
                });
            });

            ed.addButton('colour', {
                title: 'foswikibuttons.colour_desc',
                cmd: 'foswikibuttonsColour',
                image: url + '/img/colour.gif'
            });

            ed.addCommand('foswikibuttonsAttach', function() {
                var htmpath = '/attach.htm',
                htmheight = 300;

                if (null !== FoswikiTiny.foswikiVars.TOPIC.match(
                        /(X{10}|AUTOINC[0-9]+)/)) {
                    htmpath = '/attach_error_autoinc.htm',
                    htmheight = 125;
                }
                ed.windowManager.open({
                    location: false,
                    menubar: false,
                    toolbar: false,
                    status: false,
                    url: url + htmpath,
                    width: 450,
                    height: htmheight,
                    movable: true,
                    inline: true
                },
                {
                    plugin_url: url
                });
            });

            ed.addButton('attach', {
                title: 'foswikibuttons.attach_desc',
                cmd: 'foswikibuttonsAttach',
                image: url + '/img/attach.gif'
            });

            ed.addCommand('foswikibuttonsHide', function() {
                if (FoswikiTiny.saveEnabled) {
                    if (ed.getParam('fullscreen_is_enabled')) {
                        // The fullscreen plugin does its work asynchronously, 
                        // and it does not provide explicit hooks. However, it
                        // does a getContent prior to closing the editor which
                        // fires an onGetContent event. Hook into that, and
                        // fire off further asynchronous handling that will be
                        // processed after the fullscreen editor is destroyed.
                        ed.onGetContent.add(function() {
                            tinymce.DOM.win.setTimeout(function() {
                                // The fullscreen editor will have been
                                // destroyed by the time this function executes,
                                // so the active editor is the regular one.
                                var e = tinyMCE.activeEditor;
                                tinyMCE.execCommand("mceToggleEditor", 
                                    true, e.id);
                                FoswikiTiny.switchToRaw(e);
                            },
                            10);
                        });

                        // Call full-screen toggle to hide fullscreen editor
                        ed.execCommand('mceFullScreen');
                    }
                    else {
                        // regular editor, not fullscreen
                        tinyMCE.execCommand("mceToggleEditor", true, ed.id);
                        FoswikiTiny.switchToRaw(ed);
                    }
                }
            });

            ed.addButton('hide', {
                title: 'foswikibuttons.hide_desc',
                cmd: 'foswikibuttonsHide',
                image: url + '/img/hide.gif'
            });

            ed.addCommand('foswikibuttonsFormat', function(ui, fn) {
                // First, remove all existing formats.
                jQuery.each(ed.fw_formats, function (name, format) {
                    ed.formatter.remove(name);
                });
                // Now apply the format.
                ed.formatter.apply(fn);
                //ed.nodeChanged(); - done in formatter.apply() already
            });

            ed.onNodeChange.add(this._nodeChange, this);
        },

        getInfo: function() {
            return {
                longname: 'Foswiki Buttons Plugin',
                author: 'Crawford Currie',
                authorurl: 'http://c-dot.co.uk',
                infourl: 'http://c-dot.co.uk',
                version: 3
            };
        },

        createControl: function(n, cm) {
            if (n == 'foswikiformat') {
                var ed = tinyMCE.activeEditor;
                var m = cm.createListBox(ed.id + '_' + n, {
                    title: 'Format',
                    onselect: function(format) {
                        ed.execCommand('foswikibuttonsFormat', false, format);
                    }
                });
                // Build format select
                jQuery.each(ed.fw_formats, function (name, format) {
                    m.add(name, name);
                });
                m.selectByIndex(0);
                ed.fw_listbox = m;
                return m;
            }
            return null;
        },

        _nodeChange: function(ed, cm, node, collapsed) {
            var selectedFormats = ed.formatter.matchAll(ed.fw_format_names),
                // SMELL: ed.id gets concatenated twice - why?
                listbox = cm.get(ed.id + '_' + ed.id + '_foswikiformat');

            if (node == null) return;

            if (collapsed) { // Disable the buttons
                cm.setDisabled('colour', true);
                cm.setDisabled('tt', true);
            } else {         // A selection means the buttons should be active.
                cm.setDisabled('colour', false);
                cm.setDisabled('tt', false);
            }

            if (ed.formatter.match('WYSIWYG_TT')) {
                cm.setActive('tt', true);
            } else {
                cm.setActive('tt', false);
            }
            if ( ed.formatter.match('WYSIWYG_COLOR') ) {
                cm.setActive('colour', true);
            } else {
                cm.setActive('colour', false);
            }
            if (selectedFormats.length > 0) {
                listbox.select(selectedFormats[0]);
            } else {
                listbox.select('Normal');
            }

            return true;

        }
    });

    // Register plugin
    tinymce.PluginManager.add('foswikibuttons', tinymce.plugins.FoswikiButtons);
})();
