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
'use strict';
(function () {
    tinymce.PluginManager.requireLangPack('foswikiimage');

    tinymce.create('tinymce.plugins.FoswikiImage', {

        init: function (ed, url) {

            // Register commands
            ed.addCommand('foswikiimage', function () {
                ed.windowManager.open({
                    location: false,
                    menubar: false,
                    toolbar: false,
                    status: false,
                    url: url + '/image.htm',
                    width: 550,
                    height: 400,
                    movable: true,
                    inline: true
                },
                {
                    plugin_url: url,
                    attach_url: FoswikiTiny.getFoswikiVar("PUBURL") + '/' +
                        FoswikiTiny.getFoswikiVar("WEB") + '/' +
                        FoswikiTiny.getFoswikiVar("TOPIC") + '/',
                    vars: ed.getParam("foswiki_vars", "")
                });
            });

            // Register buttons
            ed.addButton('image', {
                title: 'foswikiimage.image_desc',
                cmd: 'foswikiimage'
            });
        },

        getInfo: function () {
            return {
                longname: 'Foswiki image',
                author: 'Crawford Currie, from Moxiecode Systems AB original',
                authorurl: 'http://c-dot.co.uk.com',
                infourl: 'http://foswiki.org/Extensions/TinyMCEPlugin',
                version: tinyMCE.majorVersion + "." + tinyMCE.minorVersion
            };
        },

        _nodeChange: function (ed, cm, n, co) {
            if (!n) {
                return;
            }

            cm.setActive('foswikiimage', ed.dom.getParent(n, 'img'));
        }
    });

    // Register plugin
    tinymce.PluginManager.add('foswikiimage', tinymce.plugins.FoswikiImage);
})();
