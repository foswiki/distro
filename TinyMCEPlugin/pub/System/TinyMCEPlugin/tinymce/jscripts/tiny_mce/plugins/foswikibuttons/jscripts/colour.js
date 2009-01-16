function init(){tinyMCEPopup.resizeToInnerSize();}
function setColour(colour){var inst=tinyMCE.getInstanceById(tinyMCE.getWindowArg('editor_id'));var s=inst.selection.getSelectedHTML();if(s.length>0){tinyMCEPopup.execCommand('mceBeginUndoLevel');s='<font class="WYSIWYG_COLOR" color="'+
colour
+'">'+s+'</font>';tinyMCE.execCommand('mceInsertContent',false,s);tinyMCE.triggerNodeChange();tinyMCEPopup.execCommand('mceEndUndoLevel');}
tinyMCEPopup.close();}