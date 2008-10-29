tinyMCE.importPluginLanguagePack('twikiimage');var TinyMCE_TWikiImagePlugin={getInfo:function(){return{longname:'TWiki image',author:'WikiRing, from Moxiecode Systems AB original',authorurl:'http://wikiring.com',infourl:'http://twiki.org/cgi-bin/view/Plugins/TinyMCEPlugin',version:tinyMCE.majorVersion+"."+tinyMCE.minorVersion};},getControlHTML:function(cn){switch(cn){case"image":return tinyMCE.getButtonHTML(cn,'lang_image_desc','{$themeurl}/images/image.gif','mceAdvImage');}
return"";},execCommand:function(editor_id,element,command,user_interface,value){switch(command){case"mceAdvImage":var template=new Array();template['file']='../../plugins/twikiimage/image.htm';template['width']=480;template['height']=380;template['width']+=tinyMCE.getLang('lang_twikiimage_delta_width',0);template['height']+=tinyMCE.getLang('lang_twikiimage_delta_height',0);var inst=tinyMCE.getInstanceById(editor_id);var elm=inst.getFocusElement();if(elm!=null&&tinyMCE.getAttrib(elm,'class').indexOf('mceItem')!=-1)
return true;tinyMCE.openWindow(template,{editor_id:editor_id,inline:"yes"});return true;}
return false;},cleanup:function(type,content){switch(type){case"insert_to_editor_dom":var imgs=content.getElementsByTagName("img"),src,i;for(i=0;i<imgs.length;i++){var onmouseover=tinyMCE.cleanupEventStr(tinyMCE.getAttrib(imgs[i],'onmouseover'));var onmouseout=tinyMCE.cleanupEventStr(tinyMCE.getAttrib(imgs[i],'onmouseout'));if((src=this._getImageSrc(onmouseover))!=""){src=eval(tinyMCE.settings['twikipuburl_callback']
+"(src);");imgs[i].setAttribute('onmouseover',"this.src='"
+src+"';");}
if((src=this._getImageSrc(onmouseout))!=""){src=eval(tinyMCE.settings['twikipuburl_callback']
+"(src);");imgs[i].setAttribute('onmouseout',"this.src='"
+src+"';");}}
break;case"get_from_editor_dom":var imgs=content.getElementsByTagName("img");for(var i=0;i<imgs.length;i++){var onmouseover=tinyMCE.cleanupEventStr(tinyMCE.getAttrib(imgs[i],'onmouseover'));var onmouseout=tinyMCE.cleanupEventStr(tinyMCE.getAttrib(imgs[i],'onmouseout'));if((src=this._getImageSrc(onmouseover))!=""){src=eval(tinyMCE.settings['twikipuburl_callback']
+"(src);");imgs[i].setAttribute('onmouseover',"this.src='"
+src+"';");}
if((src=this._getImageSrc(onmouseout))!=""){src=eval(tinyMCE.settings['twikipuburl_callback']
+"(src, null, true);");imgs[i].setAttribute('onmouseout',"this.src='"
+src+"';");}}
break;}
return content;},handleNodeChange:function(editor_id,node,undo_index,undo_levels,visual_aid,any_selection){if(node==null)
return;do{if(node.nodeName=="IMG"&&tinyMCE.getAttrib(node,'class').indexOf('mceItem')==-1){tinyMCE.switchClass(editor_id+'_twikiimage','mceButtonSelected');return true;}}while((node=node.parentNode));tinyMCE.switchClass(editor_id+'_twikiimage','mceButtonNormal');return true;},_getImageSrc:function(s){var sr,p=-1;if(!s)
return"";if((p=s.indexOf('this.src='))!=-1){sr=s.substring(p+10);sr=sr.substring(0,sr.indexOf('\''));return sr;}
return"";}};tinyMCE.addPlugin("twikiimage",TinyMCE_TWikiImagePlugin);