/*Foswiki - The Free and Open Source Wiki, http://foswiki.org/

  Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
  are listed in the AUTHORS file in the root of this distribution.
  NOTE: Please extend that file, not this notice.

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version. For
  more details read LICENSE in the root of this distribution.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  As per the GPL, removal of this notice is prohibited.

  ------------------------------------------------------------------

  This plugin tries to encapsulate a few things which customise TinyMCE
  for Foswiki:
     * Fix Item1378, override (!) advanced theme link dialogue window size
     * Fix Item9198, tables at top of document: unable to position cursor above
     * Fix Item1952, autosave monkey-patching storage key hack, unless init
                     param foswiki_no_autosave_fixup true. autosave must appear
                     before foswiki in the plugins order!
*/
'use strict';

(function () {
    tinymce.create('tinymce.plugins.Foswiki', {

        init: function (ed, url) {
            /* In TinyMCE 3.3.x we used this hack to better support IEs with no
               native localStorage support. In TinyMCE 3.4.x this seems fixed,
               and our hack now causes a really obscure error in an apparently
               difficult-to-relate part of TinyMCE. We can delete this code. */
            // ed.plugins.foswiki._disableAutoSaveOnBadIEs(ed);
            ed.onInit.add(function (ed) {
                ed.plugins.foswiki._fixAdvancedTheme(ed);
                if (ed.plugins.autosave &&
                    !ed.settings.foswiki_no_autosave_fixup) {
                    ed.plugins.foswiki._fixAutoSave(ed);
                }
            });
        },

        /* SMELL: Item1378 - we should create our own theme instead of
         * monkey-patching, but then we would have to maintain our own
         * theme - that can come later. Sadly there's no opportunity to
         * use any CSS to override the width param, because the link dialogue's
         * iframe is not consistently classed/id'd */
        _fixAdvancedTheme: function (ed) {
            ed.theme._mceLink = function (ui, val) {
                var ed = this.editor;

                ed.windowManager.open({
                    url: tinymce.baseURL + '/themes/advanced/link.htm',
                    width: 360 + parseInt(ed.getLang('advanced.link_delta_width', 0), 10),
                    height: 200 + parseInt(ed.getLang('advanced.link_delta_height', 0), 10),
                    inline: true
                },
                {
                    theme_url: this.url
                });
            };
        },

        /* Item9263: IECollections' IE6 doesn't support userData. Disable on
        ** these browsers
         */
        _disableAutoSaveOnBadIEs: function (ed) {
            if (jQuery.browser.msie && ed.plugins.autosave) {
                ed.getElement().style.behavior = "url('#default#userData')";
                if (typeof(ed.getElement().load) === 'undefined') {
                    ed.plugins.autosave.setupStorage = function () {};
                    ed.plugins.autosave.removeDraft = function () {};
                    ed.plugins.autosave.restoreDraft = function () {};
                    ed.plugins.autosave.storeDraft = function () {};
                    ed.onInit.add(function (ed) {
                        ed.controlManager.controls[ed.id + '_restoredraft'].remove();
                        ed.controlManager.controls[ed.id + '_restoredraft'].destroy();
                    });
                }
            }
        },

        /* EXTRA SMELL: Item1952 - moxiecode ship a stripped-down autosave plugin
         * whose storage key cannot be arbitrarily set (stuck to some 
         * concatenation of ed.id). So... we temporarily... monkey-patch the
         * editor's id (!) and call autosave's setupStorage() a second time,
         * before sneakily restoring the ed.id as if nothing ever happened! */
        _fixAutoSave: function (ed) {
            var orig_id = ed.id;

            ed.id = FoswikiTiny.getFoswikiVar('WEB') + '.' + FoswikiTiny.getFoswikiVar('TOPIC')+'.'+orig_id;
            ed.id = ed.id.replace('/', '.');

            ed.plugins.autosave.setupStorage(ed);
            ed.id = orig_id;

            return;
        },

        getInfo: function () {
            return {
                longname: 'Foswiki plugin',
                author: 'Foswiki Contributor',
                authorurl: 'http://foswiki.org/System/ProjectContributor',
                infourl: 'http://foswiki.org/Extensions/TinyMCEPlugin',
                version: '1.0'
            };
        }
    });

    tinymce.PluginManager.add('foswiki', tinymce.plugins.Foswiki);
})();
