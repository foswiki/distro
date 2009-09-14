var ColoursDlg={preInit:function(){tinyMCEPopup.requireLangPack();},init:function(ed){tinyMCEPopup.resizeToInnerSize();},set:function(colour){var ted=tinyMCE.activeEditor;var s=ted.selection.getContent();if(s.length>0){s='<font class="WYSIWYG_COLOR" color="'+
colour
+'">'+s+'</font>';ted.selection.setContent(s);ted.nodeChanged();}
tinyMCEPopup.close();}};ColoursDlg.preInit();tinyMCEPopup.onInit.add(ColoursDlg.init,ColoursDlg);