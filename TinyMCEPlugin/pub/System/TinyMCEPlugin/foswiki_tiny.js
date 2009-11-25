var FoswikiTiny={foswikiVars:null,metaTags:null,tml2html:new Array(),html2tml:new Array(),getFoswikiVar:function(name){if(FoswikiTiny.foswikiVars==null){var sets=tinyMCE.activeEditor.getParam("foswiki_vars","");FoswikiTiny.foswikiVars=eval(sets);}
return FoswikiTiny.foswikiVars[name];},expandVariables:function(url){for(var i in FoswikiTiny.foswikiVars){url=url.replace('%'+i+'%',FoswikiTiny.foswikiVars[i],'g');}
return url;},saveEnabled:0,enableSaveButton:function(enabled){var status=enabled?null:"disabled";FoswikiTiny.saveEnabled=enabled?1:0;var elm=document.getElementById("save");if(elm){elm.disabled=status;}
elm=document.getElementById("quietsave");if(elm){elm.disabled=status;}
elm=document.getElementById("checkpoint");if(elm){elm.disabled=status;}
elm=document.getElementById("preview");if(elm){elm.style.display='none';elm.disabled=status;}},transform:function(editor,handler,text,onSuccess,onFail){var url=FoswikiTiny.getFoswikiVar("SCRIPTURL");var suffix=FoswikiTiny.getFoswikiVar("SCRIPTSUFFIX");if(suffix==null)suffix='';url+="/rest"+suffix+"/WysiwygPlugin/"+handler;var path=FoswikiTiny.getFoswikiVar("WEB")+'.'
+FoswikiTiny.getFoswikiVar("TOPIC");tinymce.util.XHR.send({url:url,content_type:"application/x-www-form-urlencoded",type:"POST",data:"nocache="+encodeURIComponent((new Date()).getTime())
+"&topic="+encodeURIComponent(path)
+"&text="+encodeURIComponent(text),async:true,scope:editor,success:onSuccess,error:onFail})},initialisedFromServer:false,setUpContent:function(editor_id,body,doc){if(FoswikiTiny.initialisedFromServer)return;var editor=tinyMCE.getInstanceById(editor_id);FoswikiTiny.switchToWYSIWYG(editor);FoswikiTiny.initialisedFromServer=true;},cleanBeforeSave:function(eid,buttonId){var el=document.getElementById(buttonId);if(el==null)
return;el.onclick=function(){var editor=tinyMCE.getInstanceById(eid);editor.isNotDirty=true;return true;}},onSubmitHandler:false,switchToRaw:function(editor){var text=editor.getContent();var el=document.getElementById("foswikiTinyMcePluginWysiwygEditHelp");if(el){el.style.display='none';}
el=document.getElementById("foswikiTinyMcePluginRawEditHelp");if(el){el.style.display='block';}
for(var i=0;i<FoswikiTiny.html2tml.length;i++){var cb=FoswikiTiny.html2tml[i];text=cb.apply(editor,[editor,text]);}
FoswikiTiny.enableSaveButton(false);editor.getElement().value="Please wait... retrieving page from server.";FoswikiTiny.transform(editor,"html2tml",text,function(text,req,o){this.getElement().value=text;FoswikiTiny.enableSaveButton(true);},function(type,req,o){this.setContent("<div class='foswikiAlert'>"
+"There was a problem retrieving "
+o.url+": "
+type+" "+req.status+"</div>");});var eid=editor.id;var id=eid+"_2WYSIWYG";var el=document.getElementById(id);if(el){el.style.display="block";}else{el=document.createElement('INPUT');el.id=id;el.type="button";el.value="WYSIWYG";el.className="foswikiButton";el.onclick=function(){var el=document.getElementById("foswikiTinyMcePluginWysiwygEditHelp");if(el){el.style.display='block';}
el=document.getElementById("foswikiTinyMcePluginRawEditHelp");if(el){el.style.display='none';}
tinyMCE.execCommand("mceToggleEditor",null,eid);FoswikiTiny.switchToWYSIWYG(editor);return false;}
var pel=editor.getElement().parentNode;pel.insertBefore(el,editor.getElement());}
editor.getElement().onchange=function(){var editor=tinyMCE.getInstanceById(eid);editor.isNotDirty=false;return true;},this.onSubmitHandler=function(ed,e){editor.initialized=false;};editor.onSubmit.addToTop(this.onSubmitHandler);FoswikiTiny.cleanBeforeSave(eid,"save");FoswikiTiny.cleanBeforeSave(eid,"quietsave");FoswikiTiny.cleanBeforeSave(eid,"checkpoint");FoswikiTiny.cleanBeforeSave(eid,"preview");FoswikiTiny.cleanBeforeSave(eid,"cancel");},switchToWYSIWYG:function(editor){editor.getElement().onchange=null;var text=editor.getElement().value;if(this.onSubmitHandler){editor.onSubmit.remove(this.onSubmitHandler);this.onSubmitHandler=null;}
FoswikiTiny.enableSaveButton(false);editor.setContent("<span class='foswikiAlert'>"
+"Please wait... retrieving page from server."
+"</span>");FoswikiTiny.transform(editor,"tml2html",text,function(text,req,o){for(var i=0;i<FoswikiTiny.tml2html.length;i++){var cb=FoswikiTiny.tml2html[i];text=cb.apply(this,[this,text]);}
if(this.plugins.wordcount!==undefined&&this.plugins.wordcount.block!==undefined){this.plugins.wordcount.block=0;}
this.setContent(text);this.isNotDirty=true;FoswikiTiny.enableSaveButton(true);},function(type,req,o){this.setContent("<div class='foswikiAlert'>"
+"There was a problem retrieving "
+o.url+": "
+type+" "+req.status+"</div>");});var id=editor.id+"_2WYSIWYG";var el=document.getElementById(id);if(el){el.style.display="none";}},saveCallback:function(editor_id,html,body){var editor=tinyMCE.getInstanceById(editor_id);for(var i=0;i<FoswikiTiny.html2tml.length;i++){var cb=FoswikiTiny.html2tml[i];html=cb.apply(editor,[editor,html]);}
var secret_id=tinyMCE.activeEditor.getParam('foswiki_secret_id');if(secret_id!=null&&html.indexOf('<!--'+secret_id+'-->')==-1){html='<!--'+secret_id+'-->'+html;}
return html;},convertLink:function(url,node,onSave){if(onSave==null)
onSave=false;var orig=url;var pubUrl=FoswikiTiny.getFoswikiVar("PUBURL");var vsu=FoswikiTiny.getFoswikiVar("VIEWSCRIPTURL");url=FoswikiTiny.expandVariables(url);if(onSave){if((url.indexOf(pubUrl+'/')!=0)&&(url.indexOf(vsu+'/')==0)){url=url.substr(vsu.length+1);url=url.replace(/\/+/g,'.');if(url.indexOf(FoswikiTiny.getFoswikiVar('WEB')+'.')==0){url=url.substr(FoswikiTiny.getFoswikiVar('WEB').length+1);}}}else{if(url.indexOf('/')==-1){var match=/^((?:\w+\.)*)(\w+)$/.exec(url);if(match!=null){var web=match[1];var topic=match[2];if(web==null||web.length==0){web=FoswikiTiny.getFoswikiVar("WEB");}
web=web.replace(/\.+/g,'/');web=web.replace(/\/+$/,'');url=vsu+'/'+web+'/'+topic;}}}
return url;},convertPubURL:function(url){url=FoswikiTiny.expandVariables(url);if(url.indexOf('/')==-1){var base=FoswikiTiny.getFoswikiVar("PUBURL")+'/'
+FoswikiTiny.getFoswikiVar("WEB")+'/'
+FoswikiTiny.getFoswikiVar("TOPIC")+'/';url=base+url;}
return url;},getMetaTag:function(inKey){if(FoswikiTiny.metaTags==null||FoswikiTiny.metaTags.length==0){var head=document.getElementsByTagName("META");head=head[0].parentNode.childNodes;FoswikiTiny.metaTags=new Array();for(var i=0;i<head.length;i++){if(head[i].tagName!=null&&head[i].tagName.toUpperCase()=='META'){FoswikiTiny.metaTags[head[i].name]=head[i].content;}}}
return FoswikiTiny.metaTags[inKey];},install:function(){var tmce_init=this.getMetaTag('TINYMCEPLUGIN_INIT');if(tmce_init!=null){eval("tinyMCE.init({"+unescape(tmce_init)+"});");return;}
alert("Unable to install TinyMCE; <META name='TINYMCEPLUGIN_INIT' is missing");},getTopicPath:function(){return this.getFoswikiVar("WEB")+'.'+this.getFoswikiVar("TOPIC");},getScriptURL:function(script){var scripturl=this.getFoswikiVar("SCRIPTURL");var suffix=this.getFoswikiVar("SCRIPTSUFFIX");if(suffix==null)suffix='';return scripturl+"/"+script+suffix;},getRESTURL:function(fn){return this.getScriptURL('rest')+"/WysiwygPlugin/"+fn;},getListOfAttachments:function(onSuccess){var url=this.getRESTURL('attachments');var path=this.getTopicPath();var params="nocache="+encodeURIComponent((new Date()).getTime())
+"&topic="+encodeURIComponent(path);tinymce.util.XHR.send({url:url+"?"+params,type:"POST",content_type:"application/x-www-form-urlencoded",data:params,success:function(atts){if(atts!=null){onSuccess(eval(atts));}}});}};