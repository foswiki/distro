/*
  Copyright (C) 2007-2009 Crawford Currie http://c-dot.co.uk
  Copyright (C) 2010 Foswiki Contributors http://foswiki.org
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
(function () {
    'use strict';
    tinymce.PluginManager.requireLangPack('foswikibuttons');

    tinymce.create('tinymce.plugins.FoswikiButtons', {
        /* Foswiki formats listbox */
        formats_listbox: null,
        /* Remembers which node was last calculated for button state */
        _lastButtonUpdateNode: null,
        /* Flag to indicate there's a setTimeout waiting to fire a
        ** _tryNodeChangeEvent() */
        _nodeChangeEventScheduled: null,
        /* Flag to indicate that the pending setTimeout waiting to fire a
        ** _tryNodeChangeEvent(), should be deferred */
        _deferNodeChangeEvent: null,
        /* setTimeout interval governing cursor idle time required to
        ** fire a button state update. Zero means always update. Set with
        ** foswikibuttons_cursoridletime param */
        nodeChangeEventFrequency: null,

        init: function (ed, url) {
            this.formats = ed.getParam('foswikibuttons_formats');
            this.nodeChangeEventFrequency =
                ed.getParam('foswikibuttons_cursoridletime');
            this.format_names = [];
            this.recipe_names = [];

            jQuery.each(this.formats, function (key, value) {
                ed.plugins.foswikibuttons.format_names.push(key);
            });
            /* Register Foswiki formats with TinyMCE's formatter, which isn't
               available during plugin init */
            ed.onInit.add(function (editor) {
                this.plugins.foswikibuttons._registerFormats(editor, this.plugins.foswikibuttons.formats);

                this.plugins.foswikibuttons._contextMenuVerbatimClasses(editor);
            });

            this._setupTTButton(ed, url);
            this._setupColourButton(ed, url);
            this._setupAttachButton(ed, url);
            this._setupIndentButton(ed, url);
            this._setupExdentButton(ed, url);
            this._setupHideButton(ed, url);
            this._setupFormatCommand(ed, this.formats);

            return;
        },

        getInfo: function () {
            return {
                longname: 'Foswiki Buttons Plugin',
                author: 'Crawford Currie',
                authorurl: 'http://c-dot.co.uk',
                infourl: 'http://c-dot.co.uk',
                version: 3
            };
        },

        createControl: function (name, controlManager) {
            if (name === 'foswikiformat') {
                return this._createFoswikiFormatControl(name,
                    controlManager, this);
            }

            return null;
        },

        _setupTTButton: function (ed, url) {
            // Register commands
            ed.addCommand('foswikibuttonsTT', function () {
                ed.formatter.toggle('WYSIWYG_TT');
            });

            // Register buttons
            ed.addButton('tt', {
                title: 'foswikibuttons.tt_desc',
                cmd: 'foswikibuttonsTT',
                image: url + '/img/tt.gif'
            });

            return;
        },

        _registerFormats: function (ed, formats) {
            ed.formatter.register('WYSIWYG_TT', {
                inline: 'span',
                classes: 'WYSIWYG_TT'
            });
            ed.formatter.register('WYSIWYG_COLOR', [{
                inline: 'span',
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
            }]);
            ed.formatter.register('IS_WYSIWYG_COLOR', {
                inline: 'span',
                classes: 'WYSIWYG_COLOR'
            });
            ed.formatter.register(formats);

            return;
        },

        _createFoswikiFormatControl: function (name, controlManager, plugin) {
            var ed = controlManager.editor;
            plugin.formats_listbox = controlManager.createListBox(name, {
                title: 'Format',
                onselect: function (format) {
                    ed.execCommand('foswikibuttonsFormat', false, format);
                }
            });
            // Build format select
            jQuery.each(plugin.formats, function (formatname, format) {
                plugin.formats_listbox.add(formatname, formatname);

                return;
            });
            plugin.formats_listbox.selectByIndex(0);

            return plugin.formats_listbox;
        },

        _setupFormatCommand: function (ed, formats) {
            ed.addCommand('foswikibuttonsFormat', function (ui, formatname) {
                // First, remove all existing formats.
                jQuery.each(formats, function (name, format) {
                    ed.formatter.remove(name);
                });
                // Now apply the format.
                ed.formatter.apply(formatname);
                //ed.nodeChanged(); - done in formatter.apply() already
            });

            ed.onNodeChange.add(this._nodeChange, this);

            return;
        },

        _setupColourButton: function (ed, url) {
            ed.addCommand('foswikibuttonsColour', function () {
                if (ed.selection.isCollapsed()) {
                    return;
                }
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

            return;
        },

        _setupAttachButton: function (ed, url) {
            ed.addCommand('foswikibuttonsAttach', function () {
                var htmpath = '/attach.htm',
                htmheight = 300;

                if (null !== FoswikiTiny.foswikiVars.TOPIC.match(
                    /(X{10}|AUTOINC[0-9]+)/)) {
                    htmpath = '/attach_error_autoinc.htm';
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

            return;
        },

       _setupIndentButton: function (ed, url) {
            ed.addCommand('fwindent', function () {
                if (this.queryCommandState('InsertUnorderedList') ||
                    this.queryCommandState('InsertOrderedList')) {
                    // list type node - use the default behaviour
                    this.execCommand("Indent");
                }
                else {
                    // drive up to the nearest block node
                    var dom = ed.dom, selection = ed.selection,
                        node = dom.getParent(selection.getStart(), dom.isBlock) ||
                               dom.getParent(selection.getEnd(), dom.isBlock),
                        div;
                    if (node) {
                        // SMELL: what about indentation inside tables? Needs to be disabled.
                        // insert div below the nearest block node
                        div = dom.create('div', { 'class' : 'foswikiIndent'});
                        while (node.firstChild) {
                            dom.add(div, dom.remove(node.firstChild));
                        }
                        div = dom.add(node, div);
                        ed.selection.select(div);
                        ed.selection.collapse(); // This eats the cursor!
                        ed.selection.setCursorLocation(div, 0);
                    }
                }
            });

            ed.addButton('fwindent', {
                title: 'foswikibuttons.indent_desc',
                cmd: 'fwindent',
                image: url + '/img/indent.gif'
            });

            return;
        },

        _setupExdentButton: function (ed, url) {
            ed.addCommand('fwexdent', function () {
                var dom = ed.dom, selection = ed.selection,
                    node = dom.getParent(selection.getStart(), dom.isBlock),
                    p;
                if (node && dom.hasClass(node, 'foswikiIndent')) {
                    p = node.parentNode;
                    while (node.firstChild) {
                        p.insertBefore(dom.remove(node.firstChild), node);
                    }
                    dom.remove(node);
                    ed.selection.select(p.firstChild);
                    ed.selection.collapse();
                } else {
                    this.execCommand("Outdent");
                }
            });

            ed.onNodeChange.add(function(ed, cm, n, co, ob) {
                var dom = ed.dom, selection = ed.selection,
                    node = dom.getParent(selection.getStart(), dom.isBlock),
                    state = (node && dom.hasClass(node, 'foswikiIndent')) ||
                            ed.queryCommandState('Outdent');

                cm.setDisabled('fwexdent', !state);
            });

            ed.addButton('fwexdent', {
                title: 'foswikibuttons.exdent_desc',
                cmd: 'fwexdent',
                image: url + '/img/exdent.gif'
            });

            return;
        },

        _setupHideButton: function (ed, url) {
            ed.addCommand('foswikibuttonsHide', function () {
                if (FoswikiTiny.saveEnabled) {
                    if (ed.getParam('fullscreen_is_enabled')) {
                        // The fullscreen plugin does its work asynchronously, 
                        // and it does not provide explicit hooks. However, it
                        // does a getContent prior to closing the editor which
                        // fires an onGetContent event. Hook into that, and
                        // fire off further asynchronous handling that will be
                        // processed after the fullscreen editor is destroyed.
                        ed.onGetContent.add(function () {
                            tinymce.DOM.win.setTimeout(function () {
                                // The fullscreen editor will have been
                                // destroyed by the time this function executes,
                                // so the active editor is the regular one.
                                var e = tinyMCE.activeEditor;
                                tinyMCE.execCommand('mceToggleEditor', 
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

            return;
        },

        /*
         * *IF YOU MAKE CHANGES HERE*, consider netbook/mobile users who need
         * every spare CPU cycle.
         * 
         * _nodeChange() is fired *very* frequently, on every cursor movement
         * for example. So expensive operations are deferred until the cursor
         * has settled for some time period this.nodeChangeEventFrequency (500ms)
         */
        _nodeChange: function (ed, cm, node, collapsed) {
            var selectedFormats, listbox;
            
            if (typeof(node) !== 'object') {
                return;
            }
            /* Set cursoridletime param to zero to do reliable performance
             * analysis of _updateButtonState(). See Item9427
             */
            if (this.nodeChangeEventFrequency) {
                this._scheduleNodeChangeEvent(ed, cm, node, collapsed);
            } else {
                this._doUpdateButtonState(ed, cm, node, collapsed);
            }

            return true;

        },

        /* Schedule a _tryNodeChangeEvent() call, unless one is already
         * scheduled. In that case, defer that next call, because this means
         * the cursor hasn't settled for long enough. _tryNodeChangeEvent()
         * will re-schedule itself instead of calling _doUpdateButtonState()
         * when it does eventually fire.
         */
        _scheduleNodeChangeEvent: function (ed, cm, node, collapsed) {
            var that = this;

            if (this._nodeChangeEventScheduled) {
                // defer the next update and keep blocking; cursor is still moving
                this._deferNodeChangeEvent = true;
            } else {
                this._deferNodeChangeEvent = false;
                this._nodeChangeEventScheduled = true;
                setTimeout(function () {
                    that._tryNodeChangeEvent(that, ed, cm, node, collapsed);

                    return;
                }, this.nodeChangeEventFrequency);
            }

            return;
        },

        /* If this event is to be deferred, "re-set the clock and wait
        ** another 500ms" - otherwise, finally, just do it
         */
        _tryNodeChangeEvent: function (that, ed, cm, node, collapsed) {
            if (that._deferNodeChangeEvent) {
                that._deferNodeChangeEvent = false;
                that._nodeChangeEventScheduled = false;
                that._scheduleNodeChangeEvent(ed, cm, node, collapsed);
            } else {
                /* Call expensive nodeChange stuff from here
                 * If we got to here, the cursor has been idle for > 500ms
                 *
                 * Additionally, the node and collapsed args are no longer
                 * relevant since the setTimeout was set. Use
                 * ed.selection.getNode() and ed.selection.isCollapsed() instead
                 */
                that._doUpdateButtonState(ed, cm);
                that._nodeChangeEventScheduled = false;
            }

            return;
        },

        /* This is a wrapper to _updateButtonState(). It tries to avoid
        ** updating the button state if the cursor has only moved within the
        ** textNode of a given node; ie. if the cursor is still inside the same
        ** node as the last time the button state was calculated, then there is
        ** no need to update it yet again.
         */
        _doUpdateButtonState: function (ed, cm) {
            var selectedFormats, listbox, node, collapsed;

            /* Sometimes, from fullscreen, hitting wikitext button results in
             * event firing when the editor has no valid selection. Without a
             * valid selection, we can't know what the button state should be.
             */
            if (ed.selection) {
                node = ed.selection.getNode();
                collapsed = ed.selection.isCollapsed();
                if (!collapsed) {
                    // !collapsed means a selection; always update button state if
                    // there is a selection. 
                    this._updateButtonState(ed, cm);
                } else if (node !== this._lastButtonUpdateNode) {
                    // Only update button state if it wasn't already calculated for
                    // this node already on a previous call.
                    this._updateButtonState(ed, cm, node, collapsed);

                    // Remember the node
                    this._lastButtonUpdateNode = node;
                }
            }
        },

        /* Item9427: Slow cursor movement in IEs on large, >250KiB documents
         *           Please read perf results and test method on that task
         *           if you make changes here, to compare before/after. A fast
         *           PC with a decent browser performs nothing like IE7 on a
         *           netbook
         *
         * _updateButtonState() is only called when the cursor has not moved
         * for 500ms or more.
         */
        _updateButtonState: function (ed, cm, node, collapsed) {
            var selectedFormats = ed.formatter.matchAll(
                    ed.plugins.foswikibuttons.format_names),
                listbox = cm.get(ed.id + '_foswikiformat');

            if (collapsed) { // Disable the buttons
                cm.setDisabled('colour', true);
                cm.setDisabled('tt', true);
            } else { // A selection means the buttons should be active.
                cm.setDisabled('colour', false);
                cm.setDisabled('tt', false);
            }

            if (ed.formatter.match('WYSIWYG_TT')) {
                cm.setActive('tt', true);
            } else {
                cm.setActive('tt', false);
            }
            if (ed.formatter.match('WYSIWYG_COLOR')) {
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
        },

        _contextMenuVerbatimClasses: function (ed) {
            var recipes = {},
                i,
                key,
                sm,
                se,
                el,
                selectedFormats,
                current = '';

            ed.plugins.foswikibuttons.recipe_names = ['bash','cplusplus','csharp','css','delphi','html','java','js','lotusscript','php','sql','tml'];
            for (i = 0; i < ed.plugins.foswikibuttons.recipe_names.length; i += 1) {
                key = ed.plugins.foswikibuttons.recipe_names[i];
                recipes[key] = { "block" : "pre", "remove" : "all", classes : 'TMLverbatim ' + key };
            }
            ed.formatter.register(recipes);
            jQuery.each(recipes, function (key, value) {
                ed.plugins.foswikibuttons.recipe_names.push(key);
            });
            if (ed && ed.plugins.contextmenu) {
                ed.plugins.contextmenu.onContextMenu.add(function(th, m, e) {
                    se = ed.selection;
                    el = se.getNode() || ed.getBody();

                    if (el.nodeName === 'PRE' && el.className.indexOf('TMLverbatim') !== -1) {
                        selectedFormats = ed.formatter.matchAll(ed.plugins.foswikibuttons.recipe_names);
                        if (selectedFormats.length > 0) {
                            current = '(' + selectedFormats[0] + ')';
                        }
                        sm = m.addMenu({title : 'Syntax highlighting' + current });
                        
                        jQuery.each(recipes, function (name, format) {
                            sm.add({title :  name , cmd : 'foswikiVerbatimClass', value : name });
                        });
                        sm.add({title : 'none', cmd : 'foswikiVerbatimClass', value : ' ' });
                    }
                });
            }

            ed.addCommand('foswikiVerbatimClass', function(ui, val) {
                // First, remove all existing formats.
                jQuery.each(recipes, function (name, format) {
                    ed.formatter.remove(name);
                });
                if (val) {
                    // Now apply the format.
                    ed.formatter.apply(val);
                }
            });
            return;
        }

    });

    // Register plugin
    tinymce.PluginManager.add('foswikibuttons', tinymce.plugins.FoswikiButtons);
})();
