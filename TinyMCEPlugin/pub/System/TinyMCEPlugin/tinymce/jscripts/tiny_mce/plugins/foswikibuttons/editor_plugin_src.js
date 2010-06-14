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
        formats_lb: null,
        // formats listbox

        init: function(ed, url) {

            ed.fw_formats = ed.getParam("foswikibuttons_formats");
            ed.fw_lb = null;
            ed.onInit.add(function () {
                ed.formatter.register('WYSIWYG_TT', {
                    inline: 'span',
                    classes: 'WYSIWYG_TT'
                });
                for (var i = 0; i < ed.fw_formats.length; i++) {
                    var format = ed.fw_formats[i];
                    ed.formatter.register(format.name, format);
                }
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
                    width: 240,
                    height: 140,
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
                htmheight = 250;

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
                    width: 350,
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
                if (fn === 'Normal') {
                    for (var i = 0; i < ed.fw_formats.length; i++) {
                        var format = ed.fw_formats[i];
                        if ('Normal' !== format.name) {
                            ed.formatter.remove(format.name);
                        }
                    }
                } else {
                    ed.formatter.apply(fn);
                }
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
                var formats = ed.getParam("foswikibuttons_formats");
                // Build format select
                for (var i = 0; i < formats.length; i++) {
                    m.add(formats[i].name, formats[i].name);
                }
                m.selectByIndex(0);
                ed.fw_lb = m;
                return m;
            }
            return null;
        },

        _nodeChange: function(ed, cm, n, co) {
            if (n == null) return;

            if (co) {
                // Disable the buttons
                cm.setDisabled('tt', true);
                cm.setDisabled('colour', true);
            } else {
                // A selection means the buttons should be active.
                cm.setDisabled('tt', false);
                cm.setDisabled('colour', false);
            }
            var elm = ed.dom.getParent(n, '.WYSIWYG_TT');
            if (elm != null) cm.setActive('tt', true);
            else cm.setActive('tt', false);
            elm = ed.dom.getParent(n, '.WYSIWYG_COLOR');
            if (elm != null) cm.setActive('colour', true);
            else cm.setActive('colour', false);

            if (ed.fw_lb) {
                var puck = -1;
                var nn = n.nodeName.toLowerCase();
                do {
                    for (var i = 0; i < ed.fw_formats.length; i++) {
                        if ((!ed.fw_formats[i].el || 
                                ed.fw_formats[i].el == nn) && 
                            (!ed.fw_formats[i].style ||
                             ed.dom.hasClass(ed.fw_formats[i].style))) {
                            // Matched el+style or just el
                            puck = i;
                            // Only break if the format is not Normal
                            // (which always matches, and is at pos 0)
                            if (puck > 0) break;
                        }
                    }
                } while (puck < 0 && (n = n.parentNode) != null);
                if (puck >= 0) {
                    ed.fw_lb.selectByIndex(puck);
                } else {
                    // A region has been selected that doesn't match any known
                    // foswiki formats, so select the first format in our list 
                    // ('Normal').
                    ed.fw_lb.selectByIndex(0);
                }
            }
            return true;

        }
    });

    // Register plugin
    tinymce.PluginManager.add('foswikibuttons', tinymce.plugins.FoswikiButtons);
})();
