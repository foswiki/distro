/*
  Copyright (C) 2007 Crawford Currie http://wikiring.com and Arthur Clemens
  All Rights Reserved.

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version. For
  more details read LICENSE in the root of the TWiki distribution.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  As per the GPL, removal of this notice is prohibited.
*/

// invoked on load from the body of the dialog
function init() {
	tinyMCEPopup.resizeToInnerSize();
}

// Functions specific to the actions of the colour-setting dialog
function setColour(colour) {
	var inst = tinyMCE.getInstanceById(tinyMCE.getWindowArg('editor_id'));
    var s = inst.selection.getSelectedHTML();
    if (s.length > 0) {
        tinyMCEPopup.execCommand('mceBeginUndoLevel');
        // Styled spans don't work inside the editor for some reason
        s = '<font class="WYSIWYG_COLOR" color="' +
            colour
            + '">' + s + '</font>';
        tinyMCE.execCommand('mceInsertContent', false, s);
        tinyMCE.triggerNodeChange();
        tinyMCEPopup.execCommand('mceEndUndoLevel');
    }
    tinyMCEPopup.close();
}
