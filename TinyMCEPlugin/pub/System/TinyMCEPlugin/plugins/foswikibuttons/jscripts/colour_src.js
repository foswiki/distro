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

var ColoursDlg = {

    preInit: function() {
        tinyMCEPopup.requireLangPack();
    },

    // invoked on load from the body of the dialog
    init: function(ed) {
        tinyMCEPopup.resizeToInnerSize();
    },

    // Functions specific to the actions of the colour-setting dialog
    set: function(colour) {
        var ted = tinyMCE.activeEditor;
        ted.formatter.apply('WYSIWYG_COLOR', {value: colour});
        tinyMCEPopup.close();
    }
};

ColoursDlg.preInit();
tinyMCEPopup.onInit.add(ColoursDlg.init, ColoursDlg);
