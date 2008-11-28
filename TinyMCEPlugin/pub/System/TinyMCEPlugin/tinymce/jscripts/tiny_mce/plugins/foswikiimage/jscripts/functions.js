var preloadImg=null;var orgImageWidth,orgImageHeight;function preinit(){tinyMCE.setWindowArg('mce_windowresize',false);var url=tinyMCE.getParam("external_image_list_url");if(url!=null){if(url.charAt(0)!='/'&&url.indexOf('://')==-1)
url=tinyMCE.documentBasePath+"/"+url;document.write('<sc'+'ript language="javascript" type="text/javascript" src="'
+url+'"></sc'+'ript>');}}
function pubURL(url,node,on_save){return eval("tinyMCEPopup.windowOpener."
+tinyMCE.settings['foswikipuburl_callback']
+"(url, node, on_save);");}
function getImageSrc(str){var pos=-1;if(!str)
return"";if((pos=str.indexOf('this.src='))!=-1){var src=str.substring(pos+10);src=src.substring(0,src.indexOf('\''));if(tinyMCE.getParam('convert_urls'))
src=pubURL(src,null,true);return src;}
return"";}
function init(){tinyMCEPopup.resizeToInnerSize();var formObj=document.forms[0];var inst=tinyMCE.getInstanceById(tinyMCE.getWindowArg('editor_id'));var elm=inst.getFocusElement();var action="insert";var html="";html=getImageListHTML('imagelistsrc','src','onSelectMainImage');if(html=="")
document.getElementById("imagelistsrcrow").style.display='none';else
document.getElementById("imagelistsrccontainer").innerHTML=html;html=getImageListHTML('imagelistover','onmouseoversrc');if(html=="")
document.getElementById("imagelistoverrow").style.display='none';else
document.getElementById("imagelistovercontainer").innerHTML=html;html=getImageListHTML('imagelistout','onmouseoutsrc');if(html=="")
document.getElementById("imagelistoutrow").style.display='none';else
document.getElementById("imagelistoutcontainer").innerHTML=html;html=getBrowserHTML('srcbrowser','src','image','foswikiimage');document.getElementById("srcbrowsercontainer").innerHTML=html;html=getBrowserHTML('oversrcbrowser','onmouseoversrc','image','foswikiimage');document.getElementById("onmouseoversrccontainer").innerHTML=html;html=getBrowserHTML('outsrcbrowser','onmouseoutsrc','image','foswikiimage');document.getElementById("onmouseoutsrccontainer").innerHTML=html;html=getBrowserHTML('longdescbrowser','longdesc','file','foswikiimage');document.getElementById("longdesccontainer").innerHTML=html;if(isVisible('srcbrowser'))
document.getElementById('src').style.width='260px';if(isVisible('oversrcbrowser'))
document.getElementById('onmouseoversrc').style.width='260px';if(isVisible('outsrcbrowser'))
document.getElementById('onmouseoutsrc').style.width='260px';if(isVisible('longdescbrowser'))
document.getElementById('longdesc').style.width='180px';if(elm!=null&&elm.nodeName=="IMG")
action="update";formObj.insert.value=tinyMCE.getLang('lang_'+action,'Insert',true);if(action=="update"){var src=tinyMCE.getAttrib(elm,'src');var onmouseoversrc=getImageSrc(tinyMCE.cleanupEventStr(tinyMCE.getAttrib(elm,'onmouseover')));var onmouseoutsrc=getImageSrc(tinyMCE.cleanupEventStr(tinyMCE.getAttrib(elm,'onmouseout')));src=pubURL(src,elm,true);var mceRealSrc=tinyMCE.getAttrib(elm,'mce_src');if(mceRealSrc!=""){src=mceRealSrc;if(tinyMCE.getParam('convert_urls'))
src=pubURL(src,elm,true);}
if(onmouseoversrc!=""&&tinyMCE.getParam('convert_urls'))
onmouseoversrc=pubURL(onmouseoversrc,elm,true);if(onmouseoutsrc!=""&&tinyMCE.getParam('convert_urls'))
onmouseoutsrc=pubURL(onmouseoutsrc,elm,true);var style=tinyMCE.parseStyle(tinyMCE.getAttrib(elm,"style"));orgImageWidth=trimSize(getStyle(elm,'width'))
orgImageHeight=trimSize(getStyle(elm,'height'));formObj.src.value=src;formObj.alt.value=tinyMCE.getAttrib(elm,'alt');formObj.title.value=tinyMCE.getAttrib(elm,'title');formObj.border.value=trimSize(getStyle(elm,'border','borderWidth'));formObj.vspace.value=tinyMCE.getAttrib(elm,'vspace');formObj.hspace.value=tinyMCE.getAttrib(elm,'hspace');formObj.width.value=orgImageWidth;formObj.height.value=orgImageHeight;formObj.onmouseoversrc.value=onmouseoversrc;formObj.onmouseoutsrc.value=onmouseoutsrc;formObj.id.value=tinyMCE.getAttrib(elm,'id');formObj.dir.value=tinyMCE.getAttrib(elm,'dir');formObj.lang.value=tinyMCE.getAttrib(elm,'lang');formObj.longdesc.value=tinyMCE.getAttrib(elm,'longdesc');formObj.usemap.value=tinyMCE.getAttrib(elm,'usemap');formObj.style.value=tinyMCE.serializeStyle(style);if(tinyMCE.isMSIE)
selectByValue(formObj,'align',getStyle(elm,'align','styleFloat'));else
selectByValue(formObj,'align',getStyle(elm,'align','cssFloat'));addClassesToList('classlist','foswikiimage_styles');selectByValue(formObj,'classlist',tinyMCE.getAttrib(elm,'class'));selectByValue(formObj,'imagelistsrc',src);selectByValue(formObj,'imagelistover',onmouseoversrc);selectByValue(formObj,'imagelistout',onmouseoutsrc);updateStyle();showPreviewImage(src,true);changeAppearance();window.focus();}else
addClassesToList('classlist','foswikiimage_styles');if(tinyMCE.getParam("foswikiimage_constrain_proportions",true))
formObj.constrain.checked=true;if(formObj.onmouseoversrc.value!=""||formObj.onmouseoutsrc.value!="")
setSwapImageDisabled(false);else
setSwapImageDisabled(true);}
function setSwapImageDisabled(state){var formObj=document.forms[0];formObj.onmousemovecheck.checked=!state;setBrowserDisabled('overbrowser',state);setBrowserDisabled('outbrowser',state);if(formObj.imagelistover)
formObj.imagelistover.disabled=state;if(formObj.imagelistout)
formObj.imagelistout.disabled=state;formObj.onmouseoversrc.disabled=state;formObj.onmouseoutsrc.disabled=state;}
function setAttrib(elm,attrib,value){var formObj=document.forms[0];var valueElm=formObj.elements[attrib];if(typeof(value)=="undefined"||value==null){value="";if(valueElm)
value=valueElm.value;}
if(value!=""){elm.setAttribute(attrib,value);if(attrib=="style")
attrib="style.cssText";if(attrib=="longdesc")
attrib="longDesc";if(attrib=="width"){attrib="style.width";value=value+"px";value=value.replace(/%px/g,'px');}
if(attrib=="height"){attrib="style.height";value=value+"px";value=value.replace(/%px/g,'px');}
if(attrib=="class")
attrib="className";eval('elm.'+attrib+"=value;");}else{if(attrib=='class')
elm.className='';elm.removeAttribute(attrib);}}
function makeAttrib(attrib,value){var formObj=document.forms[0];var valueElm=formObj.elements[attrib];if(typeof(value)=="undefined"||value==null){value="";if(valueElm)
value=valueElm.value;}
if(value=="")
return"";value=value.replace(/&/g,'&amp;');value=value.replace(/\"/g,'&quot;');value=value.replace(/</g,'&lt;');value=value.replace(/>/g,'&gt;');return' '+attrib+'="'+value+'"';}
function insertAction(){var inst=tinyMCE.getInstanceById(tinyMCE.getWindowArg('editor_id'));var elm=inst.getFocusElement();var formObj=document.forms[0];var src=pubURL(formObj.src.value,tinyMCE.imgElement);var onmouseoversrc=formObj.onmouseoversrc.value;var onmouseoutsrc=formObj.onmouseoutsrc.value;if(!AutoValidator.validate(formObj)){alert(tinyMCE.getLang('lang_invalid_data'));return false;}
if(tinyMCE.getParam("accessibility_warnings")){if(formObj.alt.value==""&&!confirm(tinyMCE.getLang('lang_foswikiimage_missing_alt','',true)))
return;}
if(onmouseoversrc&&onmouseoversrc!="")
onmouseoversrc="this.src='"+
pubURL(onmouseoversrc,tinyMCE.imgElement)+"';";if(onmouseoutsrc&&onmouseoutsrc!="")
onmouseoutsrc="this.src='"+
pubURL(onmouseoutsrc,tinyMCE.imgElement)+"';";if(elm!=null&&elm.nodeName=="IMG"){setAttrib(elm,'src',src);setAttrib(elm,'mce_src',src);setAttrib(elm,'alt');setAttrib(elm,'title');setAttrib(elm,'border');setAttrib(elm,'vspace');setAttrib(elm,'hspace');setAttrib(elm,'width');setAttrib(elm,'height');setAttrib(elm,'onmouseover',onmouseoversrc);setAttrib(elm,'onmouseout',onmouseoutsrc);setAttrib(elm,'id');setAttrib(elm,'dir');setAttrib(elm,'lang');setAttrib(elm,'longdesc');setAttrib(elm,'usemap');setAttrib(elm,'style');setAttrib(elm,'class',getSelectValue(formObj,'classlist'));setAttrib(elm,'align',getSelectValue(formObj,'align'));if(formObj.width.value!=orgImageWidth||formObj.height.value!=orgImageHeight)
inst.repaint();if(tinyMCE.isMSIE5)
elm.outerHTML=elm.outerHTML;}else{var html="<img";html+=makeAttrib('src',src);html+=makeAttrib('mce_src',src);html+=makeAttrib('alt');html+=makeAttrib('title');html+=makeAttrib('border');html+=makeAttrib('vspace');html+=makeAttrib('hspace');html+=makeAttrib('width');html+=makeAttrib('height');html+=makeAttrib('onmouseover',onmouseoversrc);html+=makeAttrib('onmouseout',onmouseoutsrc);html+=makeAttrib('id');html+=makeAttrib('dir');html+=makeAttrib('lang');html+=makeAttrib('longdesc');html+=makeAttrib('usemap');html+=makeAttrib('style');html+=makeAttrib('class',getSelectValue(formObj,'classlist'));html+=makeAttrib('align',getSelectValue(formObj,'align'));html+=" />";tinyMCEPopup.execCommand("mceInsertContent",false,html);}
tinyMCE._setEventsEnabled(inst.getBody(),false);tinyMCEPopup.close();}
function cancelAction(){tinyMCEPopup.close();}
function changeAppearance(){var formObj=document.forms[0];var img=document.getElementById('alignSampleImg');if(img){img.align=formObj.align.value;img.border=formObj.border.value;img.hspace=formObj.hspace.value;img.vspace=formObj.vspace.value;}}
function changeMouseMove(){var formObj=document.forms[0];setSwapImageDisabled(!formObj.onmousemovecheck.checked);}
function updateStyle(){var formObj=document.forms[0];var st=tinyMCE.parseStyle(formObj.style.value);if(tinyMCE.getParam('inline_styles',false)){st['width']=formObj.width.value==''?'':formObj.width.value+"px";st['height']=formObj.height.value==''?'':formObj.height.value+"px";st['border-width']=formObj.border.value==''?'':formObj.border.value+"px";st['margin-top']=formObj.vspace.value==''?'':formObj.vspace.value+"px";st['margin-bottom']=formObj.vspace.value==''?'':formObj.vspace.value+"px";st['margin-left']=formObj.hspace.value==''?'':formObj.hspace.value+"px";st['margin-right']=formObj.hspace.value==''?'':formObj.hspace.value+"px";}else{st['width']=st['height']=st['border-width']=null;if(st['margin-top']==st['margin-bottom'])
st['margin-top']=st['margin-bottom']=null;if(st['margin-left']==st['margin-right'])
st['margin-left']=st['margin-right']=null;}
formObj.style.value=tinyMCE.serializeStyle(st);}
function styleUpdated(){var formObj=document.forms[0];var st=tinyMCE.parseStyle(formObj.style.value);if(st['width'])
formObj.width.value=st['width'].replace('px','');if(st['height'])
formObj.height.value=st['height'].replace('px','');if(st['margin-top']&&st['margin-top']==st['margin-bottom'])
formObj.vspace.value=st['margin-top'].replace('px','');if(st['margin-left']&&st['margin-left']==st['margin-right'])
formObj.hspace.value=st['margin-left'].replace('px','');if(st['border-width'])
formObj.border.value=st['border-width'].replace('px','');}
function changeHeight(){var formObj=document.forms[0];if(!formObj.constrain.checked||!preloadImg){updateStyle();return;}
if(formObj.width.value==""||formObj.height.value=="")
return;var temp=(parseInt(formObj.width.value)/parseInt(preloadImg.width))*preloadImg.height;formObj.height.value=temp.toFixed(0);updateStyle();}
function changeWidth(){var formObj=document.forms[0];if(!formObj.constrain.checked||!preloadImg){updateStyle();return;}
if(formObj.width.value==""||formObj.height.value=="")
return;var temp=(parseInt(formObj.height.value)/parseInt(preloadImg.height))*preloadImg.width;formObj.width.value=temp.toFixed(0);updateStyle();}
function onSelectMainImage(target_form_element,name,value){var formObj=document.forms[0];formObj.alt.value=name;formObj.title.value=name;resetImageData();showPreviewImage(formObj.elements[target_form_element].value,false);}
function showPreviewImage(src,start){var formObj=document.forms[0];selectByValue(document.forms[0],'imagelistsrc',src);var elm=document.getElementById('prev');var src=pubURL(src,null,false);if(!start&&tinyMCE.getParam("foswikiimage_update_dimensions_onchange",true))
resetImageData();if(src=="")
elm.innerHTML="";else
elm.innerHTML='<img id="previewImg" src="'+src
+'" border="0" onload="updateImageData('
+start+');" onerror="resetImageData();" />'}
function updateImageData(start){var formObj=document.forms[0];preloadImg=document.getElementById('previewImg');if(!start&&formObj.width.value=="")
formObj.width.value=preloadImg.width;if(!start&&formObj.height.value=="")
formObj.height.value=preloadImg.height;updateStyle();}
function resetImageData(){var formObj=document.forms[0];formObj.width.value=formObj.height.value="";}
function getSelectValue(form_obj,field_name){var elm=form_obj.elements[field_name];if(elm==null||elm.options==null)
return"";return elm.options[elm.selectedIndex].value;}
function getImageListHTML(elm_id,target_form_element,onchange_func){if(typeof(tinyMCEImageList)=="undefined"||tinyMCEImageList.length==0)
return"";var html="";html+='<select id="'+elm_id+'" name="'+elm_id+'"';html+=' class="mceImageList" onfocus="tinyMCE.addSelectAccessibility(event, this, window);" onchange="this.form.'
+target_form_element+'.value=';html+='this.options[this.selectedIndex].value;';if(typeof(onchange_func)!="undefined")
html+=onchange_func+'(\''+target_form_element
+'\',this.options[this.selectedIndex].text,this.options[this.selectedIndex].value);';html+='"><option value="">---</option>';for(var i=0;i<tinyMCEImageList.length;i++)
html+='<option value="'+tinyMCEImageList[i][1]+'">'
+tinyMCEImageList[i][0]+'</option>';html+='</select>';return html;}
preinit();