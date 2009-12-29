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
        formats_lb: null, // formats listbox

        init : function(ed, url) {

            ed.fw_formats = ed.getParam("foswikibuttons_formats");
            ed.fw_lb = null;

            // Register commands
            ed.addCommand('foswikibuttonsTT', function() {
                if (!ed.selection.isCollapsed())
                    ed.execCommand('mceSetCSSClass', false, "WYSIWYG_TT");
            });

            // Register buttons
            ed.addButton('tt', {
                title : 'foswikibuttons.tt_desc',
                cmd : 'foswikibuttonsTT',
                image: url + '/img/tt.gif'
            });

            ed.addCommand('foswikibuttonsColour', function() {
                if (ed.selection.isCollapsed())
                    return;
                ed.windowManager.open({
                    location: false,
                    menubar: false,
                    toolbar: false,
                    status: false,
                    url : url + '/colours.htm',
                    width : 240,
                    height : 140,
                    movable : true,
                    popup_css: false, // not required
                    inline : true
                }, {
                    plugin_url: url
                });
            });

            ed.addButton('colour', {
                title : 'foswikibuttons.colour_desc',
                cmd : 'foswikibuttonsColour',
                image: url + '/img/colour.gif'
            });

            ed.addCommand('foswikibuttonsAttach', function() {
                var htmpath = '/attach.htm',
                    htmheight = 250;

                if (null !== FoswikiTiny.foswikiVars.TOPIC.match(/(X{10}|AUTOINC[0-9]+)/)) {
                    htmpath = '/attach_error_autoinc.htm',
                    htmheight = 125;
                }
                ed.windowManager.open({
                    location: false,
                    menubar: false,
                    toolbar: false,
                    status: false,
                    url : url + htmpath,
                    width : 350,
                    height : htmheight,
                    movable : true,
                    inline : true
                }, {
                    plugin_url: url
                });
            });

            ed.addButton('attach', {
                title : 'foswikibuttons.attach_desc',
                cmd : 'foswikibuttonsAttach',
                image: url + '/img/attach.gif'
            });

            ed.addCommand('foswikibuttonsHide', function() {
                if (FoswikiTiny.saveEnabled) {
                    if (ed.getParam('fullscreen_is_enabled')) {
                        // The fullscreen plugin does its work asynchronously, 
                        // and it does not provide explicit hooks.
                        // However, it does a getContent prior to closing the editor
                        // which fires an onGetContent event.
                        // Hook into that, and fire off further asynchronous handling
                        // tht will be processed after the fullscreen editor is destroyed.
                        ed.onGetContent.add(function(){
                            tinymce.DOM.win.setTimeout(function() {
                                // The fullscreen editor will have been destroyed
                                // by the time this function executes,
                                // so the active editor is the regular one.
                                var e = tinyMCE.activeEditor;
                                tinyMCE.execCommand("mceToggleEditor", true, e.id);
                                FoswikiTiny.switchToRaw(e);
                            }, 10);
                        });

                        // Call the full-screen toggle function to hide the fullscreen editor
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
                title : 'foswikibuttons.hide_desc',
                cmd : 'foswikibuttonsHide',
                image: url + '/img/hide.gif'
            });

            ed.addCommand('foswikibuttonsFormat', function(ui, fn) {
                var format = null;
                for (var i = 0; i < ed.fw_formats.length; i++) {
                    if (ed.fw_formats[i].name === fn) {
                        format = ed.fw_formats[i];
                        break;
                    }
                }
                if (format.el !== null) {
                    ed.execCommand('FormatBlock', false, format.el);
                    /* Item2447: We apply a <div> instead of null element
                    if (format.el === '') {
                        var elm = ed.selection.getNode();
                        // SMELL: MIDAS command
                        ed.execCommand('removeformat', false, elm);
                    }*/
                }
                if (format.style !== null) {
                    // element is additionally styled
                    ed.execCommand('mceSetCSSClass', false,
                                   format.style);
                }
                ed.nodeChanged();
            });

            ed.onNodeChange.add(this._nodeChange, this);
        },

        getInfo : function() {
            return {
                    longname : 'Foswiki Buttons Plugin',
                    author : 'Crawford Currie',
                    authorurl : 'http://c-dot.co.uk',
                    infourl : 'http://c-dot.co.uk',
                    version : 2
            };
        },

        createControl : function(n, cm) {
            if (n == 'foswikiformat') {
                var ed = tinyMCE.activeEditor;
                var m = cm.createListBox(ed.id + '_' + n, {
                   title : 'Format',
                   onselect : function(format) {
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

        _nodeChange : function(ed, cm, n, co) {
            if (n == null)
                return;

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
            if (elm != null)
                cm.setActive('tt', true);
            else
                cm.setActive('tt', false);
            elm = ed.dom.getParent(n, '.WYSIWYG_COLOR');
            if (elm != null)
                cm.setActive('colour', true);
            else
                cm.setActive('colour', false);

            if (ed.fw_lb) {
                var puck = -1;
                var nn = n.nodeName.toLowerCase();
                do {
                    for (var i = 0; i < ed.fw_formats.length; i++) {
                        if ((!ed.fw_formats[i].el
                             || ed.fw_formats[i].el == nn)
                            && (!ed.fw_formats[i].style ||
                                ed.dom.hasClass(ed.fw_formats[i].style))) {
                            // Matched el+style or just el
                            puck = i;
                            // Only break if the format is not Normal
                            // (which always matches, and is at pos 0)
                            if (puck > 0)
                                break;
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
    tinymce.PluginManager.add('foswikibuttons',
                              tinymce.plugins.FoswikiButtons);
})();

/* Tiny MCE 2 version

tinyMCE.importPluginLanguagePack('foswikibuttons');

var FoswikiButtonsPlugin = {
    getInfo : function() {
        return {
            longname : 'Foswiki Buttons Plugin',
            author : 'Crawford Currie',
            authorurl : 'http://c-dot.co.uk',
            infourl : 'http://c-dot.co.uk',
            version : 1
        };
    },

    initInstance : function(inst) {
        //tinyMCE.importCSS(inst.getDoc(),
        //tinyMCE.baseURL + "/plugins/foswikibuttons/css/foswikibuttons.css");
    },

    getControlHTML : function(cn) {
        var html, formats;
        switch (cn) {
        case "tt":
            return tinyMCE.getButtonHTML(cn, 'lang_foswikibuttons_tt_desc',
                                         '{$pluginurl}/images/tt.gif',
                                         'foswikiTT', true);
        case "colour":
            return tinyMCE.getButtonHTML(cn, 'lang_foswikibuttons_colour_desc',
                                         '{$pluginurl}/images/colour.gif',
                                         'foswikiCOLOUR', true);
        case "attach":
            return tinyMCE.getButtonHTML(cn, 'lang_foswikibuttons_attach_desc',
                                         '{$pluginurl}/images/attach.gif',
                                         'foswikiATTACH', true);
        case "hide":
            return tinyMCE.getButtonHTML(cn, 'lang_foswikibuttons_hide_desc',
                                         '{$pluginurl}/images/hide.gif',
                                         'foswikiHIDE', true);
        case "foswikiformat":
            html = '<select id="{$editor_id}_foswikiFormatSelect" name="{$editor
_id}_foswikiFormatSelect" onfocus="tinyMCE.addSelectAccessibility(event, this, w
indow);" onchange="tinyMCE.execInstanceCommand(\'{$editor_id}\',\'foswikiFORMAT\
',false,this.options[this.selectedIndex].value);" class="mceSelectList">';
            formats = tinyMCE.getParam("foswikibuttons_formats");
            // Build format select
            for (var i = 0; i < formats.length; i++) {
                html += '<option value="'+ formats[i].name + '">'
                    + formats[i].name + '</option>';
            }
            html += '</select>';
            
            return html;
        }

        return "";
    },

    execCommand : function(editor_id, element, command,
                           user_interface, value) {
        var em;
        var inst = tinyMCE.getInstanceById(editor_id);

        switch (command) {
        case "foswikiCOLOUR":
            var t = inst.selection.getSelectedText();
            if (!(t && t.length > 0 || pe))
                return true;

            template = new Array();
            template['file'] = '../../plugins/foswikibuttons/colours.htm';
            template['width'] = 240;
            template['height'] = 140;
            tinyMCE.openWindow(template, {editor_id : editor_id});
            return true;

        case "foswikiTT":
            inst = tinyMCE.getInstanceById(editor_id);
            elm = inst.getFocusElement();
            var t = inst.selection.getSelectedText();
            var pe = tinyMCE.getParentElement(elm, 'TT');

            if (!(t && t.length > 0 || pe))
                return true;
            var s = inst.selection.getSelectedHTML();
            if (s.length > 0) {
                tinyMCE.execCommand('mceBeginUndoLevel');
                tinyMCE.execInstanceCommand(
                    editor_id, 'mceSetCSSClass', user_interface,
                    "WYSIWYG_TT");
                tinyMCE.execCommand('mceEndUndoLevel');
            }

            return true;

        case "foswikiHIDE":
            tinyMCE.execCommand("mceToggleEditor", user_interface, editor_id);
            return true;

        case "foswikiATTACH":
            template = new Array();
            template['file'] = '../../plugins/foswikibuttons/attach.htm';
            template['width'] = 350;
            template['height'] = 250;
            tinyMCE.openWindow(template, {editor_id : editor_id});
            return true;

        case "foswikiFORMAT":
            var formats = tinyMCE.getParam("foswikibuttons_formats");
            var format = null;
            for (var i = 0; i < formats.length; i++) {
                if (formats[i].name == value) {
                    format = formats[i];
                    break;
                }
            }

            if (format != null) {
                // if None, then remove all the styles that are in the
                // formats
                tinyMCE.execCommand('mceBeginUndoLevel');
                if (format.el != null) {
                    var fmt = format.el;
                    if (fmt.length)
                        fmt = '<' + fmt + '>';
                    tinyMCE.execInstanceCommand(
                        editor_id, 'FormatBlock', user_interface, fmt);
                    if (format.el == '') {
                        elm = inst.getFocusElement();
                        tinyMCE.execCommand(
                            'removeformat', user_interface, elm);
                    }
                }
                if (format.style != null) {
                    // element is additionally styled
                    tinyMCE.execInstanceCommand(
                        editor_id, 'mceSetCSSClass', user_interface,
                        format.style);
                }
                tinyMCE.triggerNodeChange();
            }
            tinyMCE.execCommand('mceEndUndoLevel');
           return true;
        }

        return false;
    },

    handleNodeChange : function(editor_id, node, undo_index,
                                undo_levels, visual_aid, any_selection) {
        var elm = tinyMCE.getParentElement(node);

        if (node == null)
            return;

        if (!any_selection) {
            // Disable the buttons
            tinyMCE.switchClass(editor_id + '_tt', 'mceButtonDisable
d');
            tinyMCE.switchClass(editor_id + '_colour', 'mceButtonDis
abled');
        } else {
            // A selection means the buttons should be active.
            tinyMCE.switchClass(editor_id + '_tt', 'mceButtonNormal'
);
            tinyMCE.switchClass(editor_id + '_colour', 'mceButtonNor
mal');
        }

        switch (node.nodeName) {
            case "TT":
            tinyMCE.switchClass(editor_id + '_tt', 'mceButtonSelected');
            return true;
        }

        var selectElm = document.getElementById(
            editor_id + "_foswikiFormatSelect");
        if (selectElm) {
            var formats = tinyMCE.getParam("foswikibuttons_formats");
            var puck = -1;
            do {
                for (var i = 0; i < formats.length; i++) {
                    if (!formats[i].el ||
                        formats[i].el == node.nodeName.toLowerCase()) {
                        if (!formats[i].style ||
                            RegExp('\\b' + formats[i].style + '\\b').test(
                                tinyMCE.getAttrib(node, "class"))) {
                            // Matched el+style or just el
                            puck = i;
                            // Only break if the format is not Normal (which
                            // always matches, and is at pos 0)
                            if (puck > 0)
                                break;
                        }
                    }
                }
            } while (puck < 0 && (node = node.parentNode) != null);
            if (puck >= 0) {
                selectElm.selectedIndex = puck;
            }
        }
        return true;
    }
};

tinyMCE.addPlugin("foswikibuttons", FoswikiButtonsPlugin);
*/
