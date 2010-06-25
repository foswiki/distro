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
     * ... more as required (eg. fix autosave plugin integration)
*/

(function() {
    tinymce.create('tinymce.plugins.Foswiki', {

        init: function(ed, url) {
            ed.onInit.add(function(ed) {
                ed.plugins.foswiki._fixAdvancedTheme(ed);
            });
        },

        /* SMELL: Item1378 - we should create our own theme instead of
         * monkey-patching, but then we would have to maintain our own
         * theme - that can come later. Sadly there's no opportunity to
         * use any CSS to override the width param, because the link dialogue's
         * iframe is not consistently classed/id'd */
        _fixAdvancedTheme: function(ed) {
            ed.theme._mceLink = function(ui, val) {
                var ed = this.editor;

                ed.windowManager.open({
                    url: tinymce.baseURL + '/themes/advanced/link.htm',
                    width: 360 + parseInt(ed.getLang('advanced.link_delta_width', 0)),
                    height: 200 + parseInt(ed.getLang('advanced.link_delta_height', 0)),
                    inline: true
                },
                {
                    theme_url: this.url
                });
            }
        },

        getInfo: function() {
            return {
                longname: 'Foswiki plugin',
                author: 'Paul.W.Harvey@csiro.au',
                authorurl: 'http://trin.org.au',
                infourl: 'http://foswiki.org/Extensions/TinyMCEPlugin',
                version: '1.0'
            };
        }
    });

    tinymce.PluginManager.add('foswiki', tinymce.plugins.Foswiki);
})();
