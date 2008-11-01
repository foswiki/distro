(function(){var _jQuery=window.jQuery,_$=window.$;var jQuery=window.jQuery=window.$=function(selector,context){return new jQuery.fn.init(selector,context);};var quickExpr=/^[^<]*(<(.|\s)+>)[^>]*$|^#(\w+)$/,isSimple=/^.[^:#\[\.]*$/,undefined;jQuery.fn=jQuery.prototype={init:function(selector,context){selector=selector||document;if(selector.nodeType){this[0]=selector;this.length=1;return this;}
if(typeof selector=="string"){var match=quickExpr.exec(selector);if(match&&(match[1]||!context)){if(match[1])
selector=jQuery.clean([match[1]],context);else{var elem=document.getElementById(match[3]);if(elem){if(elem.id!=match[3])
return jQuery().find(selector);return jQuery(elem);}
selector=[];}}else
return jQuery(context).find(selector);}else if(jQuery.isFunction(selector))
return jQuery(document)[jQuery.fn.ready?"ready":"load"](selector);return this.setArray(jQuery.makeArray(selector));},jquery:"1.2.6",size:function(){return this.length;},length:0,get:function(num){return num==undefined?jQuery.makeArray(this):this[num];},pushStack:function(elems){var ret=jQuery(elems);ret.prevObject=this;return ret;},setArray:function(elems){this.length=0;Array.prototype.push.apply(this,elems);return this;},each:function(callback,args){return jQuery.each(this,callback,args);},index:function(elem){var ret=-1;return jQuery.inArray(elem&&elem.jquery?elem[0]:elem,this);},attr:function(name,value,type){var options=name;if(name.constructor==String)
if(value===undefined)
return this[0]&&jQuery[type||"attr"](this[0],name);else{options={};options[name]=value;}
return this.each(function(i){for(name in options)
jQuery.attr(type?this.style:this,name,jQuery.prop(this,options[name],type,i,name));});},css:function(key,value){if((key=='width'||key=='height')&&parseFloat(value)<0)
value=undefined;return this.attr(key,value,"curCSS");},text:function(text){if(typeof text!="object"&&text!=null)
return this.empty().append((this[0]&&this[0].ownerDocument||document).createTextNode(text));var ret="";jQuery.each(text||this,function(){jQuery.each(this.childNodes,function(){if(this.nodeType!=8)
ret+=this.nodeType!=1?this.nodeValue:jQuery.fn.text([this]);});});return ret;},wrapAll:function(html){if(this[0])
jQuery(html,this[0].ownerDocument)
.clone()
.insertBefore(this[0])
.map(function(){var elem=this;while(elem.firstChild)
elem=elem.firstChild;return elem;})
.append(this);return this;},wrapInner:function(html){return this.each(function(){jQuery(this).contents().wrapAll(html);});},wrap:function(html){return this.each(function(){jQuery(this).wrapAll(html);});},append:function(){return this.domManip(arguments,true,false,function(elem){if(this.nodeType==1)
this.appendChild(elem);});},prepend:function(){return this.domManip(arguments,true,true,function(elem){if(this.nodeType==1)
this.insertBefore(elem,this.firstChild);});},before:function(){return this.domManip(arguments,false,false,function(elem){this.parentNode.insertBefore(elem,this);});},after:function(){return this.domManip(arguments,false,true,function(elem){this.parentNode.insertBefore(elem,this.nextSibling);});},end:function(){return this.prevObject||jQuery([]);},find:function(selector){var elems=jQuery.map(this,function(elem){return jQuery.find(selector,elem);});return this.pushStack(/[^+>] [^+>]/.test(selector)||selector.indexOf("..")>-1?jQuery.unique(elems):elems);},clone:function(events){var ret=this.map(function(){if(jQuery.browser.msie&&!jQuery.isXMLDoc(this)){var clone=this.cloneNode(true),container=document.createElement("div");container.appendChild(clone);return jQuery.clean([container.innerHTML])[0];}else
return this.cloneNode(true);});var clone=ret.find("*").andSelf().each(function(){if(this[expando]!=undefined)
this[expando]=null;});if(events===true)
this.find("*").andSelf().each(function(i){if(this.nodeType==3)
return;var events=jQuery.data(this,"events");for(var type in events)
for(var handler in events[type])
jQuery.event.add(clone[i],type,events[type][handler],events[type][handler].data);});return ret;},filter:function(selector){return this.pushStack(jQuery.isFunction(selector)&&jQuery.grep(this,function(elem,i){return selector.call(elem,i);})||jQuery.multiFilter(selector,this));},not:function(selector){if(selector.constructor==String)
if(isSimple.test(selector))
return this.pushStack(jQuery.multiFilter(selector,this,true));else
selector=jQuery.multiFilter(selector,this);var isArrayLike=selector.length&&selector[selector.length-1]!==undefined&&!selector.nodeType;return this.filter(function(){return isArrayLike?jQuery.inArray(this,selector)<0:this!=selector;});},add:function(selector){return this.pushStack(jQuery.unique(jQuery.merge(this.get(),typeof selector=='string'?jQuery(selector):jQuery.makeArray(selector))));},is:function(selector){return!!selector&&jQuery.multiFilter(selector,this).length>0;},hasClass:function(selector){return this.is("."+selector);},val:function(value){if(value==undefined){if(this.length){var elem=this[0];if(jQuery.nodeName(elem,"select")){var index=elem.selectedIndex,values=[],options=elem.options,one=elem.type=="select-one";if(index<0)
return null;for(var i=one?index:0,max=one?index+1:options.length;i<max;i++){var option=options[i];if(option.selected){value=jQuery.browser.msie&&!option.attributes.value.specified?option.text:option.value;if(one)
return value;values.push(value);}}
return values;}else
return(this[0].value||"").replace(/\r/g,"");}
return undefined;}
if(value.constructor==Number)
value+='';return this.each(function(){if(this.nodeType!=1)
return;if(value.constructor==Array&&/radio|checkbox/.test(this.type))
this.checked=(jQuery.inArray(this.value,value)>=0||jQuery.inArray(this.name,value)>=0);else if(jQuery.nodeName(this,"select")){var values=jQuery.makeArray(value);jQuery("option",this).each(function(){this.selected=(jQuery.inArray(this.value,values)>=0||jQuery.inArray(this.text,values)>=0);});if(!values.length)
this.selectedIndex=-1;}else
this.value=value;});},html:function(value){return value==undefined?(this[0]?this[0].innerHTML:null):this.empty().append(value);},replaceWith:function(value){return this.after(value).remove();},eq:function(i){return this.slice(i,i+1);},slice:function(){return this.pushStack(Array.prototype.slice.apply(this,arguments));},map:function(callback){return this.pushStack(jQuery.map(this,function(elem,i){return callback.call(elem,i,elem);}));},andSelf:function(){return this.add(this.prevObject);},data:function(key,value){var parts=key.split(".");parts[1]=parts[1]?"."+parts[1]:"";if(value===undefined){var data=this.triggerHandler("getData"+parts[1]+"!",[parts[0]]);if(data===undefined&&this.length)
data=jQuery.data(this[0],key);return data===undefined&&parts[1]?this.data(parts[0]):data;}else
return this.trigger("setData"+parts[1]+"!",[parts[0],value]).each(function(){jQuery.data(this,key,value);});},removeData:function(key){return this.each(function(){jQuery.removeData(this,key);});},domManip:function(args,table,reverse,callback){var clone=this.length>1,elems;return this.each(function(){if(!elems){elems=jQuery.clean(args,this.ownerDocument);if(reverse)
elems.reverse();}
var obj=this;if(table&&jQuery.nodeName(this,"table")&&jQuery.nodeName(elems[0],"tr"))
obj=this.getElementsByTagName("tbody")[0]||this.appendChild(this.ownerDocument.createElement("tbody"));var scripts=jQuery([]);jQuery.each(elems,function(){var elem=clone?jQuery(this).clone(true)[0]:this;if(jQuery.nodeName(elem,"script"))
scripts=scripts.add(elem);else{if(elem.nodeType==1)
scripts=scripts.add(jQuery("script",elem).remove());callback.call(obj,elem);}});scripts.each(evalScript);});}};jQuery.fn.init.prototype=jQuery.fn;function evalScript(i,elem){if(elem.src)
jQuery.ajax({url:elem.src,async:false,dataType:"script"});else
jQuery.globalEval(elem.text||elem.textContent||elem.innerHTML||"");if(elem.parentNode)
elem.parentNode.removeChild(elem);}
function now(){return+new Date;}
jQuery.extend=jQuery.fn.extend=function(){var target=arguments[0]||{},i=1,length=arguments.length,deep=false,options;if(target.constructor==Boolean){deep=target;target=arguments[1]||{};i=2;}
if(typeof target!="object"&&typeof target!="function")
target={};if(length==i){target=this;--i;}
for(;i<length;i++)
if((options=arguments[i])!=null)
for(var name in options){var src=target[name],copy=options[name];if(target===copy)
continue;if(deep&&copy&&typeof copy=="object"&&!copy.nodeType)
target[name]=jQuery.extend(deep,src||(copy.length!=null?[]:{}),copy);else if(copy!==undefined)
target[name]=copy;}
return target;};var expando="jQuery"+now(),uuid=0,windowData={},exclude=/z-?index|font-?weight|opacity|zoom|line-?height/i,defaultView=document.defaultView||{};jQuery.extend({noConflict:function(deep){window.$=_$;if(deep)
window.jQuery=_jQuery;return jQuery;},isFunction:function(fn){return!!fn&&typeof fn!="string"&&!fn.nodeName&&fn.constructor!=Array&&/^[\s[]?function/.test(fn+"");},isXMLDoc:function(elem){return elem.documentElement&&!elem.body||elem.tagName&&elem.ownerDocument&&!elem.ownerDocument.body;},globalEval:function(data){data=jQuery.trim(data);if(data){var head=document.getElementsByTagName("head")[0]||document.documentElement,script=document.createElement("script");script.type="text/javascript";if(jQuery.browser.msie)
script.text=data;else
script.appendChild(document.createTextNode(data));head.insertBefore(script,head.firstChild);head.removeChild(script);}},nodeName:function(elem,name){return elem.nodeName&&elem.nodeName.toUpperCase()==name.toUpperCase();},cache:{},data:function(elem,name,data){elem=elem==window?windowData:elem;var id=elem[expando];if(!id)
id=elem[expando]=++uuid;if(name&&!jQuery.cache[id])
jQuery.cache[id]={};if(data!==undefined)
jQuery.cache[id][name]=data;return name?jQuery.cache[id][name]:id;},removeData:function(elem,name){elem=elem==window?windowData:elem;var id=elem[expando];if(name){if(jQuery.cache[id]){delete jQuery.cache[id][name];name="";for(name in jQuery.cache[id])
break;if(!name)
jQuery.removeData(elem);}}else{try{delete elem[expando];}catch(e){if(elem.removeAttribute)
elem.removeAttribute(expando);}
delete jQuery.cache[id];}},each:function(object,callback,args){var name,i=0,length=object.length;if(args){if(length==undefined){for(name in object)
if(callback.apply(object[name],args)===false)
break;}else
for(;i<length;)
if(callback.apply(object[i++],args)===false)
break;}else{if(length==undefined){for(name in object)
if(callback.call(object[name],name,object[name])===false)
break;}else
for(var value=object[0];i<length&&callback.call(value,i,value)!==false;value=object[++i]){}}
return object;},prop:function(elem,value,type,i,name){if(jQuery.isFunction(value))
value=value.call(elem,i);return value&&value.constructor==Number&&type=="curCSS"&&!exclude.test(name)?value+"px":value;},className:{add:function(elem,classNames){jQuery.each((classNames||"").split(/\s+/),function(i,className){if(elem.nodeType==1&&!jQuery.className.has(elem.className,className))
elem.className+=(elem.className?" ":"")+className;});},remove:function(elem,classNames){if(elem.nodeType==1)
elem.className=classNames!=undefined?jQuery.grep(elem.className.split(/\s+/),function(className){return!jQuery.className.has(classNames,className);}).join(" "):"";},has:function(elem,className){return jQuery.inArray(className,(elem.className||elem).toString().split(/\s+/))>-1;}},swap:function(elem,options,callback){var old={};for(var name in options){old[name]=elem.style[name];elem.style[name]=options[name];}
callback.call(elem);for(var name in options)
elem.style[name]=old[name];},css:function(elem,name,force){if(name=="width"||name=="height"){var val,props={position:"absolute",visibility:"hidden",display:"block"},which=name=="width"?["Left","Right"]:["Top","Bottom"];function getWH(){val=name=="width"?elem.offsetWidth:elem.offsetHeight;var padding=0,border=0;jQuery.each(which,function(){padding+=parseFloat(jQuery.curCSS(elem,"padding"+this,true))||0;border+=parseFloat(jQuery.curCSS(elem,"border"+this+"Width",true))||0;});val-=Math.round(padding+border);}
if(jQuery(elem).is(":visible"))
getWH();else
jQuery.swap(elem,props,getWH);return Math.max(0,val);}
return jQuery.curCSS(elem,name,force);},curCSS:function(elem,name,force){var ret,style=elem.style;function color(elem){if(!jQuery.browser.safari)
return false;var ret=defaultView.getComputedStyle(elem,null);return!ret||ret.getPropertyValue("color")=="";}
if(name=="opacity"&&jQuery.browser.msie){ret=jQuery.attr(style,"opacity");return ret==""?"1":ret;}
if(jQuery.browser.opera&&name=="display"){var save=style.outline;style.outline="0 solid black";style.outline=save;}
if(name.match(/float/i))
name=styleFloat;if(!force&&style&&style[name])
ret=style[name];else if(defaultView.getComputedStyle){if(name.match(/float/i))
name="float";name=name.replace(/([A-Z])/g,"-$1").toLowerCase();var computedStyle=defaultView.getComputedStyle(elem,null);if(computedStyle&&!color(elem))
ret=computedStyle.getPropertyValue(name);else{var swap=[],stack=[],a=elem,i=0;for(;a&&color(a);a=a.parentNode)
stack.unshift(a);for(;i<stack.length;i++)
if(color(stack[i])){swap[i]=stack[i].style.display;stack[i].style.display="block";}
ret=name=="display"&&swap[stack.length-1]!=null?"none":(computedStyle&&computedStyle.getPropertyValue(name))||"";for(i=0;i<swap.length;i++)
if(swap[i]!=null)
stack[i].style.display=swap[i];}
if(name=="opacity"&&ret=="")
ret="1";}else if(elem.currentStyle){var camelCase=name.replace(/\-(\w)/g,function(all,letter){return letter.toUpperCase();});ret=elem.currentStyle[name]||elem.currentStyle[camelCase];if(!/^\d+(px)?$/i.test(ret)&&/^\d/.test(ret)){var left=style.left,rsLeft=elem.runtimeStyle.left;elem.runtimeStyle.left=elem.currentStyle.left;style.left=ret||0;ret=style.pixelLeft+"px";style.left=left;elem.runtimeStyle.left=rsLeft;}}
return ret;},clean:function(elems,context){var ret=[];context=context||document;if(typeof context.createElement=='undefined')
context=context.ownerDocument||context[0]&&context[0].ownerDocument||document;jQuery.each(elems,function(i,elem){if(!elem)
return;if(elem.constructor==Number)
elem+='';if(typeof elem=="string"){elem=elem.replace(/(<(\w+)[^>]*?)\/>/g,function(all,front,tag){return tag.match(/^(abbr|br|col|img|input|link|meta|param|hr|area|embed)$/i)?all:front+"></"+tag+">";});var tags=jQuery.trim(elem).toLowerCase(),div=context.createElement("div");var wrap=!tags.indexOf("<opt")&&[1,"<select multiple='multiple'>","</select>"]||!tags.indexOf("<leg")&&[1,"<fieldset>","</fieldset>"]||tags.match(/^<(thead|tbody|tfoot|colg|cap)/)&&[1,"<table>","</table>"]||!tags.indexOf("<tr")&&[2,"<table><tbody>","</tbody></table>"]||(!tags.indexOf("<td")||!tags.indexOf("<th"))&&[3,"<table><tbody><tr>","</tr></tbody></table>"]||!tags.indexOf("<col")&&[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"]||jQuery.browser.msie&&[1,"div<div>","</div>"]||[0,"",""];div.innerHTML=wrap[1]+elem+wrap[2];while(wrap[0]--)
div=div.lastChild;if(jQuery.browser.msie){var tbody=!tags.indexOf("<table")&&tags.indexOf("<tbody")<0?div.firstChild&&div.firstChild.childNodes:wrap[1]=="<table>"&&tags.indexOf("<tbody")<0?div.childNodes:[];for(var j=tbody.length-1;j>=0;--j)
if(jQuery.nodeName(tbody[j],"tbody")&&!tbody[j].childNodes.length)
tbody[j].parentNode.removeChild(tbody[j]);if(/^\s/.test(elem))
div.insertBefore(context.createTextNode(elem.match(/^\s*/)[0]),div.firstChild);}
elem=jQuery.makeArray(div.childNodes);}
if(elem.length===0&&(!jQuery.nodeName(elem,"form")&&!jQuery.nodeName(elem,"select")))
return;if(elem[0]==undefined||jQuery.nodeName(elem,"form")||elem.options)
ret.push(elem);else
ret=jQuery.merge(ret,elem);});return ret;},attr:function(elem,name,value){if(!elem||elem.nodeType==3||elem.nodeType==8)
return undefined;var notxml=!jQuery.isXMLDoc(elem),set=value!==undefined,msie=jQuery.browser.msie;name=notxml&&jQuery.props[name]||name;if(elem.tagName){var special=/href|src|style/.test(name);if(name=="selected"&&jQuery.browser.safari)
elem.parentNode.selectedIndex;if(name in elem&&notxml&&!special){if(set){if(name=="type"&&jQuery.nodeName(elem,"input")&&elem.parentNode)
throw"type property can't be changed";elem[name]=value;}
if(jQuery.nodeName(elem,"form")&&elem.getAttributeNode(name))
return elem.getAttributeNode(name).nodeValue;return elem[name];}
if(msie&&notxml&&name=="style")
return jQuery.attr(elem.style,"cssText",value);if(set)
elem.setAttribute(name,""+value);var attr=msie&&notxml&&special?elem.getAttribute(name,2):elem.getAttribute(name);return attr===null?undefined:attr;}
if(msie&&name=="opacity"){if(set){elem.zoom=1;elem.filter=(elem.filter||"").replace(/alpha\([^)]*\)/,"")+
(parseInt(value)+''=="NaN"?"":"alpha(opacity="+value*100+")");}
return elem.filter&&elem.filter.indexOf("opacity=")>=0?(parseFloat(elem.filter.match(/opacity=([^)]*)/)[1])/100)+'':"";}
name=name.replace(/-([a-z])/ig,function(all,letter){return letter.toUpperCase();});if(set)
elem[name]=value;return elem[name];},trim:function(text){return(text||"").replace(/^\s+|\s+$/g,"");},makeArray:function(array){var ret=[];if(array!=null){var i=array.length;if(i==null||array.split||array.setInterval||array.call)
ret[0]=array;else
while(i)
ret[--i]=array[i];}
return ret;},inArray:function(elem,array){for(var i=0,length=array.length;i<length;i++)
if(array[i]===elem)
return i;return-1;},merge:function(first,second){var i=0,elem,pos=first.length;if(jQuery.browser.msie){while(elem=second[i++])
if(elem.nodeType!=8)
first[pos++]=elem;}else
while(elem=second[i++])
first[pos++]=elem;return first;},unique:function(array){var ret=[],done={};try{for(var i=0,length=array.length;i<length;i++){var id=jQuery.data(array[i]);if(!done[id]){done[id]=true;ret.push(array[i]);}}}catch(e){ret=array;}
return ret;},grep:function(elems,callback,inv){var ret=[];for(var i=0,length=elems.length;i<length;i++)
if(!inv!=!callback(elems[i],i))
ret.push(elems[i]);return ret;},map:function(elems,callback){var ret=[];for(var i=0,length=elems.length;i<length;i++){var value=callback(elems[i],i);if(value!=null)
ret[ret.length]=value;}
return ret.concat.apply([],ret);}});var userAgent=navigator.userAgent.toLowerCase();jQuery.browser={version:(userAgent.match(/.+(?:rv|it|ra|ie)[\/: ]([\d.]+)/)||[])[1],safari:/webkit/.test(userAgent),opera:/opera/.test(userAgent),msie:/msie/.test(userAgent)&&!/opera/.test(userAgent),mozilla:/mozilla/.test(userAgent)&&!/(compatible|webkit)/.test(userAgent)};var styleFloat=jQuery.browser.msie?"styleFloat":"cssFloat";jQuery.extend({boxModel:!jQuery.browser.msie||document.compatMode=="CSS1Compat",props:{"for":"htmlFor","class":"className","float":styleFloat,cssFloat:styleFloat,styleFloat:styleFloat,readonly:"readOnly",maxlength:"maxLength",cellspacing:"cellSpacing"}});jQuery.each({parent:function(elem){return elem.parentNode;},parents:function(elem){return jQuery.dir(elem,"parentNode");},next:function(elem){return jQuery.nth(elem,2,"nextSibling");},prev:function(elem){return jQuery.nth(elem,2,"previousSibling");},nextAll:function(elem){return jQuery.dir(elem,"nextSibling");},prevAll:function(elem){return jQuery.dir(elem,"previousSibling");},siblings:function(elem){return jQuery.sibling(elem.parentNode.firstChild,elem);},children:function(elem){return jQuery.sibling(elem.firstChild);},contents:function(elem){return jQuery.nodeName(elem,"iframe")?elem.contentDocument||elem.contentWindow.document:jQuery.makeArray(elem.childNodes);}},function(name,fn){jQuery.fn[name]=function(selector){var ret=jQuery.map(this,fn);if(selector&&typeof selector=="string")
ret=jQuery.multiFilter(selector,ret);return this.pushStack(jQuery.unique(ret));};});jQuery.each({appendTo:"append",prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(name,original){jQuery.fn[name]=function(){var args=arguments;return this.each(function(){for(var i=0,length=args.length;i<length;i++)
jQuery(args[i])[original](this);});};});jQuery.each({removeAttr:function(name){jQuery.attr(this,name,"");if(this.nodeType==1)
this.removeAttribute(name);},addClass:function(classNames){jQuery.className.add(this,classNames);},removeClass:function(classNames){jQuery.className.remove(this,classNames);},toggleClass:function(classNames){jQuery.className[jQuery.className.has(this,classNames)?"remove":"add"](this,classNames);},remove:function(selector){if(!selector||jQuery.filter(selector,[this]).r.length){jQuery("*",this).add(this).each(function(){jQuery.event.remove(this);jQuery.removeData(this);});if(this.parentNode)
this.parentNode.removeChild(this);}},empty:function(){jQuery(">*",this).remove();while(this.firstChild)
this.removeChild(this.firstChild);}},function(name,fn){jQuery.fn[name]=function(){return this.each(fn,arguments);};});jQuery.each(["Height","Width"],function(i,name){var type=name.toLowerCase();jQuery.fn[type]=function(size){return this[0]==window?jQuery.browser.opera&&document.body["client"+name]||jQuery.browser.safari&&window["inner"+name]||document.compatMode=="CSS1Compat"&&document.documentElement["client"+name]||document.body["client"+name]:this[0]==document?Math.max(Math.max(document.body["scroll"+name],document.documentElement["scroll"+name]),Math.max(document.body["offset"+name],document.documentElement["offset"+name])):size==undefined?(this.length?jQuery.css(this[0],type):null):this.css(type,size.constructor==String?size:size+"px");};});function num(elem,prop){return elem[0]&&parseInt(jQuery.curCSS(elem[0],prop,true),10)||0;}var chars=jQuery.browser.safari&&parseInt(jQuery.browser.version)<417?"(?:[\\w*_-]|\\\\.)":"(?:[\\w\u0128-\uFFFF*_-]|\\\\.)",quickChild=new RegExp("^>\\s*("+chars+"+)"),quickID=new RegExp("^("+chars+"+)(#)("+chars+"+)"),quickClass=new RegExp("^([#.]?)("+chars+"*)");jQuery.extend({expr:{"":function(a,i,m){return m[2]=="*"||jQuery.nodeName(a,m[2]);},"#":function(a,i,m){return a.getAttribute("id")==m[2];},":":{lt:function(a,i,m){return i<m[3]-0;},gt:function(a,i,m){return i>m[3]-0;},nth:function(a,i,m){return m[3]-0==i;},eq:function(a,i,m){return m[3]-0==i;},first:function(a,i){return i==0;},last:function(a,i,m,r){return i==r.length-1;},even:function(a,i){return i%2==0;},odd:function(a,i){return i%2;},"first-child":function(a){return a.parentNode.getElementsByTagName("*")[0]==a;},"last-child":function(a){return jQuery.nth(a.parentNode.lastChild,1,"previousSibling")==a;},"only-child":function(a){return!jQuery.nth(a.parentNode.lastChild,2,"previousSibling");},parent:function(a){return a.firstChild;},empty:function(a){return!a.firstChild;},contains:function(a,i,m){return(a.textContent||a.innerText||jQuery(a).text()||"").indexOf(m[3])>=0;},visible:function(a){return"hidden"!=a.type&&jQuery.css(a,"display")!="none"&&jQuery.css(a,"visibility")!="hidden";},hidden:function(a){return"hidden"==a.type||jQuery.css(a,"display")=="none"||jQuery.css(a,"visibility")=="hidden";},enabled:function(a){return!a.disabled;},disabled:function(a){return a.disabled;},checked:function(a){return a.checked;},selected:function(a){return a.selected||jQuery.attr(a,"selected");},text:function(a){return"text"==a.type;},radio:function(a){return"radio"==a.type;},checkbox:function(a){return"checkbox"==a.type;},file:function(a){return"file"==a.type;},password:function(a){return"password"==a.type;},submit:function(a){return"submit"==a.type;},image:function(a){return"image"==a.type;},reset:function(a){return"reset"==a.type;},button:function(a){return"button"==a.type||jQuery.nodeName(a,"button");},input:function(a){return/input|select|textarea|button/i.test(a.nodeName);},has:function(a,i,m){return jQuery.find(m[3],a).length;},header:function(a){return/h\d/i.test(a.nodeName);},animated:function(a){return jQuery.grep(jQuery.timers,function(fn){return a==fn.elem;}).length;}}},parse:[/^(\[) *@?([\w-]+) *([!*$^~=]*) *('?"?)(.*?)\4 *\]/,/^(:)([\w-]+)\("?'?(.*?(\(.*?\))?[^(]*?)"?'?\)/,new RegExp("^([:.#]*)("+chars+"+)")],multiFilter:function(expr,elems,not){var old,cur=[];while(expr&&expr!=old){old=expr;var f=jQuery.filter(expr,elems,not);expr=f.t.replace(/^\s*,\s*/,"");cur=not?elems=f.r:jQuery.merge(cur,f.r);}
return cur;},find:function(t,context){if(typeof t!="string")
return[t];if(context&&context.nodeType!=1&&context.nodeType!=9)
return[];context=context||document;var ret=[context],done=[],last,nodeName;while(t&&last!=t){var r=[];last=t;t=jQuery.trim(t);var foundToken=false,re=quickChild,m=re.exec(t);if(m){nodeName=m[1].toUpperCase();for(var i=0;ret[i];i++)
for(var c=ret[i].firstChild;c;c=c.nextSibling)
if(c.nodeType==1&&(nodeName=="*"||c.nodeName.toUpperCase()==nodeName))
r.push(c);ret=r;t=t.replace(re,"");if(t.indexOf(" ")==0)continue;foundToken=true;}else{re=/^([>+~])\s*(\w*)/i;if((m=re.exec(t))!=null){r=[];var merge={};nodeName=m[2].toUpperCase();m=m[1];for(var j=0,rl=ret.length;j<rl;j++){var n=m=="~"||m=="+"?ret[j].nextSibling:ret[j].firstChild;for(;n;n=n.nextSibling)
if(n.nodeType==1){var id=jQuery.data(n);if(m=="~"&&merge[id])break;if(!nodeName||n.nodeName.toUpperCase()==nodeName){if(m=="~")merge[id]=true;r.push(n);}
if(m=="+")break;}}
ret=r;t=jQuery.trim(t.replace(re,""));foundToken=true;}}
if(t&&!foundToken){if(!t.indexOf(",")){if(context==ret[0])ret.shift();done=jQuery.merge(done,ret);r=ret=[context];t=" "+t.substr(1,t.length);}else{var re2=quickID;var m=re2.exec(t);if(m){m=[0,m[2],m[3],m[1]];}else{re2=quickClass;m=re2.exec(t);}
m[2]=m[2].replace(/\\/g,"");var elem=ret[ret.length-1];if(m[1]=="#"&&elem&&elem.getElementById&&!jQuery.isXMLDoc(elem)){var oid=elem.getElementById(m[2]);if((jQuery.browser.msie||jQuery.browser.opera)&&oid&&typeof oid.id=="string"&&oid.id!=m[2])
oid=jQuery('[@id="'+m[2]+'"]',elem)[0];ret=r=oid&&(!m[3]||jQuery.nodeName(oid,m[3]))?[oid]:[];}else{for(var i=0;ret[i];i++){var tag=m[1]=="#"&&m[3]?m[3]:m[1]!=""||m[0]==""?"*":m[2];if(tag=="*"&&ret[i].nodeName.toLowerCase()=="object")
tag="param";r=jQuery.merge(r,ret[i].getElementsByTagName(tag));}
if(m[1]==".")
r=jQuery.classFilter(r,m[2]);if(m[1]=="#"){var tmp=[];for(var i=0;r[i];i++)
if(r[i].getAttribute("id")==m[2]){tmp=[r[i]];break;}
r=tmp;}
ret=r;}
t=t.replace(re2,"");}}
if(t){var val=jQuery.filter(t,r);ret=r=val.r;t=jQuery.trim(val.t);}}
if(t)
ret=[];if(ret&&context==ret[0])
ret.shift();done=jQuery.merge(done,ret);return done;},classFilter:function(r,m,not){m=" "+m+" ";var tmp=[];for(var i=0;r[i];i++){var pass=(" "+r[i].className+" ").indexOf(m)>=0;if(!not&&pass||not&&!pass)
tmp.push(r[i]);}
return tmp;},filter:function(t,r,not){var last;while(t&&t!=last){last=t;var p=jQuery.parse,m;for(var i=0;p[i];i++){m=p[i].exec(t);if(m){t=t.substring(m[0].length);m[2]=m[2].replace(/\\/g,"");break;}}
if(!m)
break;if(m[1]==":"&&m[2]=="not")
r=isSimple.test(m[3])?jQuery.filter(m[3],r,true).r:jQuery(r).not(m[3]);else if(m[1]==".")
r=jQuery.classFilter(r,m[2],not);else if(m[1]=="["){var tmp=[],type=m[3];for(var i=0,rl=r.length;i<rl;i++){var a=r[i],z=a[jQuery.props[m[2]]||m[2]];if(z==null||/href|src|selected/.test(m[2]))
z=jQuery.attr(a,m[2])||'';if((type==""&&!!z||type=="="&&z==m[5]||type=="!="&&z!=m[5]||type=="^="&&z&&!z.indexOf(m[5])||type=="$="&&z.substr(z.length-m[5].length)==m[5]||(type=="*="||type=="~=")&&z.indexOf(m[5])>=0)^not)
tmp.push(a);}
r=tmp;}else if(m[1]==":"&&m[2]=="nth-child"){var merge={},tmp=[],test=/(-?)(\d*)n((?:\+|-)?\d*)/.exec(m[3]=="even"&&"2n"||m[3]=="odd"&&"2n+1"||!/\D/.test(m[3])&&"0n+"+m[3]||m[3]),first=(test[1]+(test[2]||1))-0,last=test[3]-0;for(var i=0,rl=r.length;i<rl;i++){var node=r[i],parentNode=node.parentNode,id=jQuery.data(parentNode);if(!merge[id]){var c=1;for(var n=parentNode.firstChild;n;n=n.nextSibling)
if(n.nodeType==1)
n.nodeIndex=c++;merge[id]=true;}
var add=false;if(first==0){if(node.nodeIndex==last)
add=true;}else if((node.nodeIndex-last)%first==0&&(node.nodeIndex-last)/first>=0)
add=true;if(add^not)
tmp.push(node);}
r=tmp;}else{var fn=jQuery.expr[m[1]];if(typeof fn=="object")
fn=fn[m[2]];if(typeof fn=="string")
fn=eval("false||function(a,i){return "+fn+";}");r=jQuery.grep(r,function(elem,i){return fn(elem,i,m,r);},not);}}
return{r:r,t:t};},dir:function(elem,dir){var matched=[],cur=elem[dir];while(cur&&cur!=document){if(cur.nodeType==1)
matched.push(cur);cur=cur[dir];}
return matched;},nth:function(cur,result,dir,elem){result=result||1;var num=0;for(;cur;cur=cur[dir])
if(cur.nodeType==1&&++num==result)
break;return cur;},sibling:function(n,elem){var r=[];for(;n;n=n.nextSibling){if(n.nodeType==1&&n!=elem)
r.push(n);}
return r;}});jQuery.event={add:function(elem,types,handler,data){if(elem.nodeType==3||elem.nodeType==8)
return;if(jQuery.browser.msie&&elem.setInterval)
elem=window;if(!handler.guid)
handler.guid=this.guid++;if(data!=undefined){var fn=handler;handler=this.proxy(fn,function(){return fn.apply(this,arguments);});handler.data=data;}
var events=jQuery.data(elem,"events")||jQuery.data(elem,"events",{}),handle=jQuery.data(elem,"handle")||jQuery.data(elem,"handle",function(){if(typeof jQuery!="undefined"&&!jQuery.event.triggered)
return jQuery.event.handle.apply(arguments.callee.elem,arguments);});handle.elem=elem;jQuery.each(types.split(/\s+/),function(index,type){var parts=type.split(".");type=parts[0];handler.type=parts[1];var handlers=events[type];if(!handlers){handlers=events[type]={};if(!jQuery.event.special[type]||jQuery.event.special[type].setup.call(elem)===false){if(elem.addEventListener)
elem.addEventListener(type,handle,false);else if(elem.attachEvent)
elem.attachEvent("on"+type,handle);}}
handlers[handler.guid]=handler;jQuery.event.global[type]=true;});elem=null;},guid:1,global:{},remove:function(elem,types,handler){if(elem.nodeType==3||elem.nodeType==8)
return;var events=jQuery.data(elem,"events"),ret,index;if(events){if(types==undefined||(typeof types=="string"&&types.charAt(0)=="."))
for(var type in events)
this.remove(elem,type+(types||""));else{if(types.type){handler=types.handler;types=types.type;}
jQuery.each(types.split(/\s+/),function(index,type){var parts=type.split(".");type=parts[0];if(events[type]){if(handler)
delete events[type][handler.guid];else
for(handler in events[type])
if(!parts[1]||events[type][handler].type==parts[1])
delete events[type][handler];for(ret in events[type])break;if(!ret){if(!jQuery.event.special[type]||jQuery.event.special[type].teardown.call(elem)===false){if(elem.removeEventListener)
elem.removeEventListener(type,jQuery.data(elem,"handle"),false);else if(elem.detachEvent)
elem.detachEvent("on"+type,jQuery.data(elem,"handle"));}
ret=null;delete events[type];}}});}
for(ret in events)break;if(!ret){var handle=jQuery.data(elem,"handle");if(handle)handle.elem=null;jQuery.removeData(elem,"events");jQuery.removeData(elem,"handle");}}},trigger:function(type,data,elem,donative,extra){data=jQuery.makeArray(data);if(type.indexOf("!")>=0){type=type.slice(0,-1);var exclusive=true;}
if(!elem){if(this.global[type])
jQuery("*").add([window,document]).trigger(type,data);}else{if(elem.nodeType==3||elem.nodeType==8)
return undefined;var val,ret,fn=jQuery.isFunction(elem[type]||null),event=!data[0]||!data[0].preventDefault;if(event){data.unshift({type:type,target:elem,preventDefault:function(){},stopPropagation:function(){},timeStamp:now()});data[0][expando]=true;}
data[0].type=type;if(exclusive)
data[0].exclusive=true;var handle=jQuery.data(elem,"handle");if(handle)
val=handle.apply(elem,data);if((!fn||(jQuery.nodeName(elem,'a')&&type=="click"))&&elem["on"+type]&&elem["on"+type].apply(elem,data)===false)
val=false;if(event)
data.shift();if(extra&&jQuery.isFunction(extra)){ret=extra.apply(elem,val==null?data:data.concat(val));if(ret!==undefined)
val=ret;}
if(fn&&donative!==false&&val!==false&&!(jQuery.nodeName(elem,'a')&&type=="click")){this.triggered=true;try{elem[type]();}catch(e){}}
this.triggered=false;}
return val;},handle:function(event){var val,ret,namespace,all,handlers;event=arguments[0]=jQuery.event.fix(event||window.event);namespace=event.type.split(".");event.type=namespace[0];namespace=namespace[1];all=!namespace&&!event.exclusive;handlers=(jQuery.data(this,"events")||{})[event.type];for(var j in handlers){var handler=handlers[j];if(all||handler.type==namespace){event.handler=handler;event.data=handler.data;ret=handler.apply(this,arguments);if(val!==false)
val=ret;if(ret===false){event.preventDefault();event.stopPropagation();}}}
return val;},fix:function(event){if(event[expando]==true)
return event;var originalEvent=event;event={originalEvent:originalEvent};var props="altKey attrChange attrName bubbles button cancelable charCode clientX clientY ctrlKey currentTarget data detail eventPhase fromElement handler keyCode metaKey newValue originalTarget pageX pageY prevValue relatedNode relatedTarget screenX screenY shiftKey srcElement target timeStamp toElement type view wheelDelta which".split(" ");for(var i=props.length;i;i--)
event[props[i]]=originalEvent[props[i]];event[expando]=true;event.preventDefault=function(){if(originalEvent.preventDefault)
originalEvent.preventDefault();originalEvent.returnValue=false;};event.stopPropagation=function(){if(originalEvent.stopPropagation)
originalEvent.stopPropagation();originalEvent.cancelBubble=true;};event.timeStamp=event.timeStamp||now();if(!event.target)
event.target=event.srcElement||document;if(event.target.nodeType==3)
event.target=event.target.parentNode;if(!event.relatedTarget&&event.fromElement)
event.relatedTarget=event.fromElement==event.target?event.toElement:event.fromElement;if(event.pageX==null&&event.clientX!=null){var doc=document.documentElement,body=document.body;event.pageX=event.clientX+(doc&&doc.scrollLeft||body&&body.scrollLeft||0)-(doc.clientLeft||0);event.pageY=event.clientY+(doc&&doc.scrollTop||body&&body.scrollTop||0)-(doc.clientTop||0);}
if(!event.which&&((event.charCode||event.charCode===0)?event.charCode:event.keyCode))
event.which=event.charCode||event.keyCode;if(!event.metaKey&&event.ctrlKey)
event.metaKey=event.ctrlKey;if(!event.which&&event.button)
event.which=(event.button&1?1:(event.button&2?3:(event.button&4?2:0)));return event;},proxy:function(fn,proxy){proxy.guid=fn.guid=fn.guid||proxy.guid||this.guid++;return proxy;},special:{ready:{setup:function(){bindReady();return;},teardown:function(){return;}},mouseenter:{setup:function(){if(jQuery.browser.msie)return false;jQuery(this).bind("mouseover",jQuery.event.special.mouseenter.handler);return true;},teardown:function(){if(jQuery.browser.msie)return false;jQuery(this).unbind("mouseover",jQuery.event.special.mouseenter.handler);return true;},handler:function(event){if(withinElement(event,this))return true;event.type="mouseenter";return jQuery.event.handle.apply(this,arguments);}},mouseleave:{setup:function(){if(jQuery.browser.msie)return false;jQuery(this).bind("mouseout",jQuery.event.special.mouseleave.handler);return true;},teardown:function(){if(jQuery.browser.msie)return false;jQuery(this).unbind("mouseout",jQuery.event.special.mouseleave.handler);return true;},handler:function(event){if(withinElement(event,this))return true;event.type="mouseleave";return jQuery.event.handle.apply(this,arguments);}}}};jQuery.fn.extend({bind:function(type,data,fn){return type=="unload"?this.one(type,data,fn):this.each(function(){jQuery.event.add(this,type,fn||data,fn&&data);});},one:function(type,data,fn){var one=jQuery.event.proxy(fn||data,function(event){jQuery(this).unbind(event,one);return(fn||data).apply(this,arguments);});return this.each(function(){jQuery.event.add(this,type,one,fn&&data);});},unbind:function(type,fn){return this.each(function(){jQuery.event.remove(this,type,fn);});},trigger:function(type,data,fn){return this.each(function(){jQuery.event.trigger(type,data,this,true,fn);});},triggerHandler:function(type,data,fn){return this[0]&&jQuery.event.trigger(type,data,this[0],false,fn);},toggle:function(fn){var args=arguments,i=1;while(i<args.length)
jQuery.event.proxy(fn,args[i++]);return this.click(jQuery.event.proxy(fn,function(event){this.lastToggle=(this.lastToggle||0)%i;event.preventDefault();return args[this.lastToggle++].apply(this,arguments)||false;}));},hover:function(fnOver,fnOut){return this.bind('mouseenter',fnOver).bind('mouseleave',fnOut);},ready:function(fn){bindReady();if(jQuery.isReady)
fn.call(document,jQuery);else
jQuery.readyList.push(function(){return fn.call(this,jQuery);});return this;}});jQuery.extend({isReady:false,readyList:[],ready:function(){if(!jQuery.isReady){jQuery.isReady=true;if(jQuery.readyList){jQuery.each(jQuery.readyList,function(){this.call(document);});jQuery.readyList=null;}
jQuery(document).triggerHandler("ready");}}});var readyBound=false;function bindReady(){if(readyBound)return;readyBound=true;if(document.addEventListener&&!jQuery.browser.opera)
document.addEventListener("DOMContentLoaded",jQuery.ready,false);if(jQuery.browser.msie&&window==top)(function(){if(jQuery.isReady)return;try{document.documentElement.doScroll("left");}catch(error){setTimeout(arguments.callee,0);return;}
jQuery.ready();})();if(jQuery.browser.opera)
document.addEventListener("DOMContentLoaded",function(){if(jQuery.isReady)return;for(var i=0;i<document.styleSheets.length;i++)
if(document.styleSheets[i].disabled){setTimeout(arguments.callee,0);return;}
jQuery.ready();},false);if(jQuery.browser.safari){var numStyles;(function(){if(jQuery.isReady)return;if(document.readyState!="loaded"&&document.readyState!="complete"){setTimeout(arguments.callee,0);return;}
if(numStyles===undefined)
numStyles=jQuery("style, link[rel=stylesheet]").length;if(document.styleSheets.length!=numStyles){setTimeout(arguments.callee,0);return;}
jQuery.ready();})();}
jQuery.event.add(window,"load",jQuery.ready);}
jQuery.each(("blur,focus,load,resize,scroll,unload,click,dblclick,"+
"mousedown,mouseup,mousemove,mouseover,mouseout,change,select,"+
"submit,keydown,keypress,keyup,error").split(","),function(i,name){jQuery.fn[name]=function(fn){return fn?this.bind(name,fn):this.trigger(name);};});var withinElement=function(event,elem){var parent=event.relatedTarget;while(parent&&parent!=elem)try{parent=parent.parentNode;}catch(error){parent=elem;}
return parent==elem;};jQuery(window).bind("unload",function(){jQuery("*").add(document).unbind();});jQuery.fn.extend({_load:jQuery.fn.load,load:function(url,params,callback){if(typeof url!='string')
return this._load(url);var off=url.indexOf(" ");if(off>=0){var selector=url.slice(off,url.length);url=url.slice(0,off);}
callback=callback||function(){};var type="GET";if(params)
if(jQuery.isFunction(params)){callback=params;params=null;}else{params=jQuery.param(params);type="POST";}
var self=this;jQuery.ajax({url:url,type:type,dataType:"html",data:params,complete:function(res,status){if(status=="success"||status=="notmodified")
self.html(selector?jQuery("<div/>")
.append(res.responseText.replace(/<script(.|\s)*?\/script>/g,""))
.find(selector):res.responseText);self.each(callback,[res.responseText,status,res]);}});return this;},serialize:function(){return jQuery.param(this.serializeArray());},serializeArray:function(){return this.map(function(){return jQuery.nodeName(this,"form")?jQuery.makeArray(this.elements):this;})
.filter(function(){return this.name&&!this.disabled&&(this.checked||/select|textarea/i.test(this.nodeName)||/text|hidden|password/i.test(this.type));})
.map(function(i,elem){var val=jQuery(this).val();return val==null?null:val.constructor==Array?jQuery.map(val,function(val,i){return{name:elem.name,value:val};}):{name:elem.name,value:val};}).get();}});jQuery.each("ajaxStart,ajaxStop,ajaxComplete,ajaxError,ajaxSuccess,ajaxSend".split(","),function(i,o){jQuery.fn[o]=function(f){return this.bind(o,f);};});var jsc=now();jQuery.extend({get:function(url,data,callback,type){if(jQuery.isFunction(data)){callback=data;data=null;}
return jQuery.ajax({type:"GET",url:url,data:data,success:callback,dataType:type});},getScript:function(url,callback){return jQuery.get(url,null,callback,"script");},getJSON:function(url,data,callback){return jQuery.get(url,data,callback,"json");},post:function(url,data,callback,type){if(jQuery.isFunction(data)){callback=data;data={};}
return jQuery.ajax({type:"POST",url:url,data:data,success:callback,dataType:type});},ajaxSetup:function(settings){jQuery.extend(jQuery.ajaxSettings,settings);},ajaxSettings:{url:location.href,global:true,type:"GET",timeout:0,contentType:"application/x-www-form-urlencoded",processData:true,async:true,data:null,username:null,password:null,accepts:{xml:"application/xml, text/xml",html:"text/html",script:"text/javascript, application/javascript",json:"application/json, text/javascript",text:"text/plain",_default:"*/*"}},lastModified:{},ajax:function(s){s=jQuery.extend(true,s,jQuery.extend(true,{},jQuery.ajaxSettings,s));var jsonp,jsre=/=\?(&|$)/g,status,data,type=s.type.toUpperCase();if(s.data&&s.processData&&typeof s.data!="string")
s.data=jQuery.param(s.data);if(s.dataType=="jsonp"){if(type=="GET"){if(!s.url.match(jsre))
s.url+=(s.url.match(/\?/)?"&":"?")+(s.jsonp||"callback")+"=?";}else if(!s.data||!s.data.match(jsre))
s.data=(s.data?s.data+"&":"")+(s.jsonp||"callback")+"=?";s.dataType="json";}
if(s.dataType=="json"&&(s.data&&s.data.match(jsre)||s.url.match(jsre))){jsonp="jsonp"+jsc++;if(s.data)
s.data=(s.data+"").replace(jsre,"="+jsonp+"$1");s.url=s.url.replace(jsre,"="+jsonp+"$1");s.dataType="script";window[jsonp]=function(tmp){data=tmp;success();complete();window[jsonp]=undefined;try{delete window[jsonp];}catch(e){}
if(head)
head.removeChild(script);};}
if(s.dataType=="script"&&s.cache==null)
s.cache=false;if(s.cache===false&&type=="GET"){var ts=now();var ret=s.url.replace(/(\?|&)_=.*?(&|$)/,"$1_="+ts+"$2");s.url=ret+((ret==s.url)?(s.url.match(/\?/)?"&":"?")+"_="+ts:"");}
if(s.data&&type=="GET"){s.url+=(s.url.match(/\?/)?"&":"?")+s.data;s.data=null;}
if(s.global&&!jQuery.active++)
jQuery.event.trigger("ajaxStart");var remote=/^(?:\w+:)?\/\/([^\/?#]+)/;if(s.dataType=="script"&&type=="GET"&&remote.test(s.url)&&remote.exec(s.url)[1]!=location.host){var head=document.getElementsByTagName("head")[0];var script=document.createElement("script");script.src=s.url;if(s.scriptCharset)
script.charset=s.scriptCharset;if(!jsonp){var done=false;script.onload=script.onreadystatechange=function(){if(!done&&(!this.readyState||this.readyState=="loaded"||this.readyState=="complete")){done=true;success();complete();head.removeChild(script);}};}
head.appendChild(script);return undefined;}
var requestDone=false;var xhr=window.ActiveXObject?new ActiveXObject("Microsoft.XMLHTTP"):new XMLHttpRequest();if(s.username)
xhr.open(type,s.url,s.async,s.username,s.password);else
xhr.open(type,s.url,s.async);try{if(s.data)
xhr.setRequestHeader("Content-Type",s.contentType);if(s.ifModified)
xhr.setRequestHeader("If-Modified-Since",jQuery.lastModified[s.url]||"Thu, 01 Jan 1970 00:00:00 GMT");xhr.setRequestHeader("X-Requested-With","XMLHttpRequest");xhr.setRequestHeader("Accept",s.dataType&&s.accepts[s.dataType]?s.accepts[s.dataType]+", */*":s.accepts._default);}catch(e){}
if(s.beforeSend&&s.beforeSend(xhr,s)===false){s.global&&jQuery.active--;xhr.abort();return false;}
if(s.global)
jQuery.event.trigger("ajaxSend",[xhr,s]);var onreadystatechange=function(isTimeout){if(!requestDone&&xhr&&(xhr.readyState==4||isTimeout=="timeout")){requestDone=true;if(ival){clearInterval(ival);ival=null;}
status=isTimeout=="timeout"&&"timeout"||!jQuery.httpSuccess(xhr)&&"error"||s.ifModified&&jQuery.httpNotModified(xhr,s.url)&&"notmodified"||"success";if(status=="success"){try{data=jQuery.httpData(xhr,s.dataType,s.dataFilter);}catch(e){status="parsererror";}}
if(status=="success"){var modRes;try{modRes=xhr.getResponseHeader("Last-Modified");}catch(e){}
if(s.ifModified&&modRes)
jQuery.lastModified[s.url]=modRes;if(!jsonp)
success();}else
jQuery.handleError(s,xhr,status);complete();if(s.async)
xhr=null;}};if(s.async){var ival=setInterval(onreadystatechange,13);if(s.timeout>0)
setTimeout(function(){if(xhr){xhr.abort();if(!requestDone)
onreadystatechange("timeout");}},s.timeout);}
try{xhr.send(s.data);}catch(e){jQuery.handleError(s,xhr,null,e);}
if(!s.async)
onreadystatechange();function success(){if(s.success)
s.success(data,status);if(s.global)
jQuery.event.trigger("ajaxSuccess",[xhr,s]);}
function complete(){if(s.complete)
s.complete(xhr,status);if(s.global)
jQuery.event.trigger("ajaxComplete",[xhr,s]);if(s.global&&!--jQuery.active)
jQuery.event.trigger("ajaxStop");}
return xhr;},handleError:function(s,xhr,status,e){if(s.error)s.error(xhr,status,e);if(s.global)
jQuery.event.trigger("ajaxError",[xhr,s,e]);},active:0,httpSuccess:function(xhr){try{return!xhr.status&&location.protocol=="file:"||(xhr.status>=200&&xhr.status<300)||xhr.status==304||xhr.status==1223||jQuery.browser.safari&&xhr.status==undefined;}catch(e){}
return false;},httpNotModified:function(xhr,url){try{var xhrRes=xhr.getResponseHeader("Last-Modified");return xhr.status==304||xhrRes==jQuery.lastModified[url]||jQuery.browser.safari&&xhr.status==undefined;}catch(e){}
return false;},httpData:function(xhr,type,filter){var ct=xhr.getResponseHeader("content-type"),xml=type=="xml"||!type&&ct&&ct.indexOf("xml")>=0,data=xml?xhr.responseXML:xhr.responseText;if(xml&&data.documentElement.tagName=="parsererror")
throw"parsererror";if(filter)
data=filter(data,type);if(type=="script")
jQuery.globalEval(data);if(type=="json")
data=eval("("+data+")");return data;},param:function(a){var s=[];if(a.constructor==Array||a.jquery)
jQuery.each(a,function(){s.push(encodeURIComponent(this.name)+"="+encodeURIComponent(this.value));});else
for(var j in a)
if(a[j]&&a[j].constructor==Array)
jQuery.each(a[j],function(){s.push(encodeURIComponent(j)+"="+encodeURIComponent(this));});else
s.push(encodeURIComponent(j)+"="+encodeURIComponent(jQuery.isFunction(a[j])?a[j]():a[j]));return s.join("&").replace(/%20/g,"+");}});jQuery.fn.extend({show:function(speed,callback){return speed?this.animate({height:"show",width:"show",opacity:"show"},speed,callback):this.filter(":hidden").each(function(){this.style.display=this.oldblock||"";if(jQuery.css(this,"display")=="none"){var elem=jQuery("<"+this.tagName+" />").appendTo("body");this.style.display=elem.css("display");if(this.style.display=="none")
this.style.display="block";elem.remove();}}).end();},hide:function(speed,callback){return speed?this.animate({height:"hide",width:"hide",opacity:"hide"},speed,callback):this.filter(":visible").each(function(){this.oldblock=this.oldblock||jQuery.css(this,"display");this.style.display="none";}).end();},_toggle:jQuery.fn.toggle,toggle:function(fn,fn2){return jQuery.isFunction(fn)&&jQuery.isFunction(fn2)?this._toggle.apply(this,arguments):fn?this.animate({height:"toggle",width:"toggle",opacity:"toggle"},fn,fn2):this.each(function(){jQuery(this)[jQuery(this).is(":hidden")?"show":"hide"]();});},slideDown:function(speed,callback){return this.animate({height:"show"},speed,callback);},slideUp:function(speed,callback){return this.animate({height:"hide"},speed,callback);},slideToggle:function(speed,callback){return this.animate({height:"toggle"},speed,callback);},fadeIn:function(speed,callback){return this.animate({opacity:"show"},speed,callback);},fadeOut:function(speed,callback){return this.animate({opacity:"hide"},speed,callback);},fadeTo:function(speed,to,callback){return this.animate({opacity:to},speed,callback);},animate:function(prop,speed,easing,callback){var optall=jQuery.speed(speed,easing,callback);return this[optall.queue===false?"each":"queue"](function(){if(this.nodeType!=1)
return false;var opt=jQuery.extend({},optall),p,hidden=jQuery(this).is(":hidden"),self=this;for(p in prop){if(prop[p]=="hide"&&hidden||prop[p]=="show"&&!hidden)
return opt.complete.call(this);if(p=="height"||p=="width"){opt.display=jQuery.css(this,"display");opt.overflow=this.style.overflow;}}
if(opt.overflow!=null)
this.style.overflow="hidden";opt.curAnim=jQuery.extend({},prop);jQuery.each(prop,function(name,val){var e=new jQuery.fx(self,opt,name);if(/toggle|show|hide/.test(val))
e[val=="toggle"?hidden?"show":"hide":val](prop);else{var parts=val.toString().match(/^([+-]=)?([\d+-.]+)(.*)$/),start=e.cur(true)||0;if(parts){var end=parseFloat(parts[2]),unit=parts[3]||"px";if(unit!="px"){self.style[name]=(end||1)+unit;start=((end||1)/e.cur(true))*start;self.style[name]=start+unit;}
if(parts[1])
end=((parts[1]=="-="?-1:1)*end)+start;e.custom(start,end,unit);}else
e.custom(start,val,"");}});return true;});},queue:function(type,fn){if(jQuery.isFunction(type)||(type&&type.constructor==Array)){fn=type;type="fx";}
if(!type||(typeof type=="string"&&!fn))
return queue(this[0],type);return this.each(function(){if(fn.constructor==Array)
queue(this,type,fn);else{queue(this,type).push(fn);if(queue(this,type).length==1)
fn.call(this);}});},stop:function(clearQueue,gotoEnd){var timers=jQuery.timers;if(clearQueue)
this.queue([]);this.each(function(){for(var i=timers.length-1;i>=0;i--)
if(timers[i].elem==this){if(gotoEnd)
timers[i](true);timers.splice(i,1);}});if(!gotoEnd)
this.dequeue();return this;}});var queue=function(elem,type,array){if(elem){type=type||"fx";var q=jQuery.data(elem,type+"queue");if(!q||array)
q=jQuery.data(elem,type+"queue",jQuery.makeArray(array));}
return q;};jQuery.fn.dequeue=function(type){type=type||"fx";return this.each(function(){var q=queue(this,type);q.shift();if(q.length)
q[0].call(this);});};jQuery.extend({speed:function(speed,easing,fn){var opt=speed&&speed.constructor==Object?speed:{complete:fn||!fn&&easing||jQuery.isFunction(speed)&&speed,duration:speed,easing:fn&&easing||easing&&easing.constructor!=Function&&easing};opt.duration=(opt.duration&&opt.duration.constructor==Number?opt.duration:jQuery.fx.speeds[opt.duration])||jQuery.fx.speeds.def;opt.old=opt.complete;opt.complete=function(){if(opt.queue!==false)
jQuery(this).dequeue();if(jQuery.isFunction(opt.old))
opt.old.call(this);};return opt;},easing:{linear:function(p,n,firstNum,diff){return firstNum+diff*p;},swing:function(p,n,firstNum,diff){return((-Math.cos(p*Math.PI)/2)+0.5)*diff+firstNum;}},timers:[],timerId:null,fx:function(elem,options,prop){this.options=options;this.elem=elem;this.prop=prop;if(!options.orig)
options.orig={};}});jQuery.fx.prototype={update:function(){if(this.options.step)
this.options.step.call(this.elem,this.now,this);(jQuery.fx.step[this.prop]||jQuery.fx.step._default)(this);if(this.prop=="height"||this.prop=="width")
this.elem.style.display="block";},cur:function(force){if(this.elem[this.prop]!=null&&this.elem.style[this.prop]==null)
return this.elem[this.prop];var r=parseFloat(jQuery.css(this.elem,this.prop,force));return r&&r>-10000?r:parseFloat(jQuery.curCSS(this.elem,this.prop))||0;},custom:function(from,to,unit){this.startTime=now();this.start=from;this.end=to;this.unit=unit||this.unit||"px";this.now=this.start;this.pos=this.state=0;this.update();var self=this;function t(gotoEnd){return self.step(gotoEnd);}
t.elem=this.elem;jQuery.timers.push(t);if(jQuery.timerId==null){jQuery.timerId=setInterval(function(){var timers=jQuery.timers;for(var i=0;i<timers.length;i++)
if(!timers[i]())
timers.splice(i--,1);if(!timers.length){clearInterval(jQuery.timerId);jQuery.timerId=null;}},13);}},show:function(){this.options.orig[this.prop]=jQuery.attr(this.elem.style,this.prop);this.options.show=true;this.custom(0,this.cur());if(this.prop=="width"||this.prop=="height")
this.elem.style[this.prop]="1px";jQuery(this.elem).show();},hide:function(){this.options.orig[this.prop]=jQuery.attr(this.elem.style,this.prop);this.options.hide=true;this.custom(this.cur(),0);},step:function(gotoEnd){var t=now();if(gotoEnd||t>this.options.duration+this.startTime){this.now=this.end;this.pos=this.state=1;this.update();this.options.curAnim[this.prop]=true;var done=true;for(var i in this.options.curAnim)
if(this.options.curAnim[i]!==true)
done=false;if(done){if(this.options.display!=null){this.elem.style.overflow=this.options.overflow;this.elem.style.display=this.options.display;if(jQuery.css(this.elem,"display")=="none")
this.elem.style.display="block";}
if(this.options.hide)
this.elem.style.display="none";if(this.options.hide||this.options.show)
for(var p in this.options.curAnim)
jQuery.attr(this.elem.style,p,this.options.orig[p]);}
if(done)
this.options.complete.call(this.elem);return false;}else{var n=t-this.startTime;this.state=n/this.options.duration;this.pos=jQuery.easing[this.options.easing||(jQuery.easing.swing?"swing":"linear")](this.state,n,0,1,this.options.duration);this.now=this.start+((this.end-this.start)*this.pos);this.update();}
return true;}};jQuery.extend(jQuery.fx,{speeds:{slow:600,fast:200,def:400},step:{scrollLeft:function(fx){fx.elem.scrollLeft=fx.now;},scrollTop:function(fx){fx.elem.scrollTop=fx.now;},opacity:function(fx){jQuery.attr(fx.elem.style,"opacity",fx.now);},_default:function(fx){fx.elem.style[fx.prop]=fx.now+fx.unit;}}});jQuery.fn.offset=function(){var left=0,top=0,elem=this[0],results;if(elem)with(jQuery.browser){var parent=elem.parentNode,offsetChild=elem,offsetParent=elem.offsetParent,doc=elem.ownerDocument,safari2=safari&&parseInt(version)<522&&!/adobeair/i.test(userAgent),css=jQuery.curCSS,fixed=css(elem,"position")=="fixed";if(elem.getBoundingClientRect){var box=elem.getBoundingClientRect();add(box.left+Math.max(doc.documentElement.scrollLeft,doc.body.scrollLeft),box.top+Math.max(doc.documentElement.scrollTop,doc.body.scrollTop));add(-doc.documentElement.clientLeft,-doc.documentElement.clientTop);}else{add(elem.offsetLeft,elem.offsetTop);while(offsetParent){add(offsetParent.offsetLeft,offsetParent.offsetTop);if(mozilla&&!/^t(able|d|h)$/i.test(offsetParent.tagName)||safari&&!safari2)
border(offsetParent);if(!fixed&&css(offsetParent,"position")=="fixed")
fixed=true;offsetChild=/^body$/i.test(offsetParent.tagName)?offsetChild:offsetParent;offsetParent=offsetParent.offsetParent;}
while(parent&&parent.tagName&&!/^body|html$/i.test(parent.tagName)){if(!/^inline|table.*$/i.test(css(parent,"display")))
add(-parent.scrollLeft,-parent.scrollTop);if(mozilla&&css(parent,"overflow")!="visible")
border(parent);parent=parent.parentNode;}
if((safari2&&(fixed||css(offsetChild,"position")=="absolute"))||(mozilla&&css(offsetChild,"position")!="absolute"))
add(-doc.body.offsetLeft,-doc.body.offsetTop);if(fixed)
add(Math.max(doc.documentElement.scrollLeft,doc.body.scrollLeft),Math.max(doc.documentElement.scrollTop,doc.body.scrollTop));}
results={top:top,left:left};}
function border(elem){add(jQuery.curCSS(elem,"borderLeftWidth",true),jQuery.curCSS(elem,"borderTopWidth",true));}
function add(l,t){left+=parseInt(l,10)||0;top+=parseInt(t,10)||0;}
return results;};jQuery.fn.extend({position:function(){var left=0,top=0,results;if(this[0]){var offsetParent=this.offsetParent(),offset=this.offset(),parentOffset=/^body|html$/i.test(offsetParent[0].tagName)?{top:0,left:0}:offsetParent.offset();offset.top-=num(this,'marginTop');offset.left-=num(this,'marginLeft');parentOffset.top+=num(offsetParent,'borderTopWidth');parentOffset.left+=num(offsetParent,'borderLeftWidth');results={top:offset.top-parentOffset.top,left:offset.left-parentOffset.left};}
return results;},offsetParent:function(){var offsetParent=this[0].offsetParent;while(offsetParent&&(!/^body|html$/i.test(offsetParent.tagName)&&jQuery.css(offsetParent,'position')=='static'))
offsetParent=offsetParent.offsetParent;return jQuery(offsetParent);}});jQuery.each(['Left','Top'],function(i,name){var method='scroll'+name;jQuery.fn[method]=function(val){if(!this[0])return;return val!=undefined?this.each(function(){this==window||this==document?window.scrollTo(!i?val:jQuery(window).scrollLeft(),i?val:jQuery(window).scrollTop()):this[method]=val;}):this[0]==window||this[0]==document?self[i?'pageYOffset':'pageXOffset']||jQuery.boxModel&&document.documentElement[method]||document.body[method]:this[0][method];};});jQuery.each(["Height","Width"],function(i,name){var tl=i?"Left":"Top",br=i?"Right":"Bottom";jQuery.fn["inner"+name]=function(){return this[name.toLowerCase()]()+
num(this,"padding"+tl)+
num(this,"padding"+br);};jQuery.fn["outer"+name]=function(margin){return this["inner"+name]()+
num(this,"border"+tl+"Width")+
num(this,"border"+br+"Width")+
(margin?num(this,"margin"+tl)+num(this,"margin"+br):0);};});})();;;
eval(function(p,a,c,k,e,r){e=function(c){return(c<a?'':e(parseInt(c/a)))+((c=c%a)>35?String.fromCharCode(c+29):c.toString(36))};if(!''.replace(/^/,String)){while(c--)r[e(c)]=k[c]||e(c);k=[function(e){return r[e]}];e=function(){return'\\w+'};c=1};while(c--)if(k[c])p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c]);return p}('(6($){$.4={g:"o",f:"j",t:6(a,b){2.g=a;2.f=b},n:/({.*})/,7:\'j\'};5 d=$.h.q;$.h.q=6(c){8 d.E(2,C).z(6(){3(2.l||2.v==9||$.u(2))8;5 a="{}";3($.4.g=="o"){5 m=$.4.n.s(2.r);3(m)a=m[1]}i 3($.4.g=="J"){3(!2.p)8;5 e=2.p($.4.f);3(e.I)a=$.H(e[0].D)}i 3(2.k!=B){5 b=2.k($.4.f);3(b)a=b}3(a.A(\'{\')<0)a="{"+a+"}";a=F("("+a+")");3($.4.7)2[$.4.7]=a;i $.G(2,a);2.l=y})};$.h.x=6(){8 2[0][$.4.7]}})(w);',46,46,'||this|if|meta|var|function|single|return|||||||name|type|fn|else|metadata|getAttribute|metaDone||cre|class|getElementsByTagName|setArray|className|exec|setType|isXMLDoc|nodeType|jQuery|data|true|each|indexOf|undefined|arguments|innerHTML|apply|eval|extend|trim|length|elem'.split('|'),0,{}));
jQuery.easing['jswing']=jQuery.easing['swing'];jQuery.extend(jQuery.easing,{def:'easeOutQuad',swing:function(x,t,b,c,d){return jQuery.easing[jQuery.easing.def](x,t,b,c,d);},easeInQuad:function(x,t,b,c,d){return c*(t/=d)*t+b;},easeOutQuad:function(x,t,b,c,d){return-c*(t/=d)*(t-2)+b;},easeInOutQuad:function(x,t,b,c,d){if((t/=d/2)<1)return c/2*t*t+b;return-c/2*((--t)*(t-2)-1)+b;},easeInCubic:function(x,t,b,c,d){return c*(t/=d)*t*t+b;},easeOutCubic:function(x,t,b,c,d){return c*((t=t/d-1)*t*t+1)+b;},easeInOutCubic:function(x,t,b,c,d){if((t/=d/2)<1)return c/2*t*t*t+b;return c/2*((t-=2)*t*t+2)+b;},easeInQuart:function(x,t,b,c,d){return c*(t/=d)*t*t*t+b;},easeOutQuart:function(x,t,b,c,d){return-c*((t=t/d-1)*t*t*t-1)+b;},easeInOutQuart:function(x,t,b,c,d){if((t/=d/2)<1)return c/2*t*t*t*t+b;return-c/2*((t-=2)*t*t*t-2)+b;},easeInQuint:function(x,t,b,c,d){return c*(t/=d)*t*t*t*t+b;},easeOutQuint:function(x,t,b,c,d){return c*((t=t/d-1)*t*t*t*t+1)+b;},easeInOutQuint:function(x,t,b,c,d){if((t/=d/2)<1)return c/2*t*t*t*t*t+b;return c/2*((t-=2)*t*t*t*t+2)+b;},easeInSine:function(x,t,b,c,d){return-c*Math.cos(t/d*(Math.PI/2))+c+b;},easeOutSine:function(x,t,b,c,d){return c*Math.sin(t/d*(Math.PI/2))+b;},easeInOutSine:function(x,t,b,c,d){return-c/2*(Math.cos(Math.PI*t/d)-1)+b;},easeInExpo:function(x,t,b,c,d){return(t==0)?b:c*Math.pow(2,10*(t/d-1))+b;},easeOutExpo:function(x,t,b,c,d){return(t==d)?b+c:c*(-Math.pow(2,-10*t/d)+1)+b;},easeInOutExpo:function(x,t,b,c,d){if(t==0)return b;if(t==d)return b+c;if((t/=d/2)<1)return c/2*Math.pow(2,10*(t-1))+b;return c/2*(-Math.pow(2,-10*--t)+2)+b;},easeInCirc:function(x,t,b,c,d){return-c*(Math.sqrt(1-(t/=d)*t)-1)+b;},easeOutCirc:function(x,t,b,c,d){return c*Math.sqrt(1-(t=t/d-1)*t)+b;},easeInOutCirc:function(x,t,b,c,d){if((t/=d/2)<1)return-c/2*(Math.sqrt(1-t*t)-1)+b;return c/2*(Math.sqrt(1-(t-=2)*t)+1)+b;},easeInElastic:function(x,t,b,c,d){var s=1.70158;var p=0;var a=c;if(t==0)return b;if((t/=d)==1)return b+c;if(!p)p=d*.3;if(a<Math.abs(c)){a=c;var s=p/4;}
else var s=p/(2*Math.PI)*Math.asin(c/a);return-(a*Math.pow(2,10*(t-=1))*Math.sin((t*d-s)*(2*Math.PI)/p))+b;},easeOutElastic:function(x,t,b,c,d){var s=1.70158;var p=0;var a=c;if(t==0)return b;if((t/=d)==1)return b+c;if(!p)p=d*.3;if(a<Math.abs(c)){a=c;var s=p/4;}
else var s=p/(2*Math.PI)*Math.asin(c/a);return a*Math.pow(2,-10*t)*Math.sin((t*d-s)*(2*Math.PI)/p)+c+b;},easeInOutElastic:function(x,t,b,c,d){var s=1.70158;var p=0;var a=c;if(t==0)return b;if((t/=d/2)==2)return b+c;if(!p)p=d*(.3*1.5);if(a<Math.abs(c)){a=c;var s=p/4;}
else var s=p/(2*Math.PI)*Math.asin(c/a);if(t<1)return-.5*(a*Math.pow(2,10*(t-=1))*Math.sin((t*d-s)*(2*Math.PI)/p))+b;return a*Math.pow(2,-10*(t-=1))*Math.sin((t*d-s)*(2*Math.PI)/p)*.5+c+b;},easeInBack:function(x,t,b,c,d,s){if(s==undefined)s=1.70158;return c*(t/=d)*t*((s+1)*t-s)+b;},easeOutBack:function(x,t,b,c,d,s){if(s==undefined)s=1.70158;return c*((t=t/d-1)*t*((s+1)*t+s)+1)+b;},easeInOutBack:function(x,t,b,c,d,s){if(s==undefined)s=1.70158;if((t/=d/2)<1)return c/2*(t*t*(((s*=(1.525))+1)*t-s))+b;return c/2*((t-=2)*t*(((s*=(1.525))+1)*t+s)+2)+b;},easeInBounce:function(x,t,b,c,d){return c-jQuery.easing.easeOutBounce(x,d-t,0,c,d)+b;},easeOutBounce:function(x,t,b,c,d){if((t/=d)<(1/2.75)){return c*(7.5625*t*t)+b;}else if(t<(2/2.75)){return c*(7.5625*(t-=(1.5/2.75))*t+.75)+b;}else if(t<(2.5/2.75)){return c*(7.5625*(t-=(2.25/2.75))*t+.9375)+b;}else{return c*(7.5625*(t-=(2.625/2.75))*t+.984375)+b;}},easeInOutBounce:function(x,t,b,c,d){if(t<d/2)return jQuery.easing.easeInBounce(x,t*2,0,c,d)*.5+b;return jQuery.easing.easeOutBounce(x,t*2-d,0,c,d)*.5+c*.5+b;}});;;
(function($){$.fn.hoverIntent=function(f,g){var cfg={sensitivity:7,interval:100,timeout:0};cfg=$.extend(cfg,g?{over:f,out:g}:f);var cX,cY,pX,pY;var track=function(ev){cX=ev.pageX;cY=ev.pageY;};var compare=function(ev,ob){ob.hoverIntent_t=clearTimeout(ob.hoverIntent_t);if((Math.abs(pX-cX)+Math.abs(pY-cY))<cfg.sensitivity){$(ob).unbind("mousemove",track);ob.hoverIntent_s=1;return cfg.over.apply(ob,[ev]);}else{pX=cX;pY=cY;ob.hoverIntent_t=setTimeout(function(){compare(ev,ob);},cfg.interval);}};var delay=function(ev,ob){ob.hoverIntent_t=clearTimeout(ob.hoverIntent_t);ob.hoverIntent_s=0;return cfg.out.apply(ob,[ev]);};var handleHover=function(e){var p=(e.type=="mouseover"?e.fromElement:e.toElement)||e.relatedTarget;while(p&&p!=this){try{p=p.parentNode;}catch(e){p=this;}}if(p==this){return false;}var ev=jQuery.extend({},e);var ob=this;if(ob.hoverIntent_t){ob.hoverIntent_t=clearTimeout(ob.hoverIntent_t);}if(e.type=="mouseover"){pX=ev.pageX;pY=ev.pageY;$(ob).bind("mousemove",track);if(ob.hoverIntent_s!=1){ob.hoverIntent_t=setTimeout(function(){compare(ev,ob);},cfg.interval);}}else{$(ob).unbind("mousemove",track);if(ob.hoverIntent_s==1){ob.hoverIntent_t=setTimeout(function(){delay(ev,ob);},cfg.timeout);}}};return this.mouseover(handleHover).mouseout(handleHover);};})(jQuery);;
eval(function(p,a,c,k,e,r){e=function(c){return(c<a?'':e(parseInt(c/a)))+((c=c%a)>35?String.fromCharCode(c+29):c.toString(36))};if(!''.replace(/^/,String)){while(c--)r[e(c)]=k[c]||e(c);k=[function(e){return r[e]}];e=function(){return'\\w+'};c=1};while(c--)if(k[c])p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c]);return p}('(b($){$.m.E=$.m.g=b(s){h($.x.10&&/6.0/.I(D.B)){s=$.w({c:\'3\',5:\'3\',8:\'3\',d:\'3\',k:M,e:\'F:i;\'},s||{});C a=b(n){f n&&n.t==r?n+\'4\':n},p=\'<o Y="g"W="0"R="-1"e="\'+s.e+\'"\'+\'Q="P:O;N:L;z-H:-1;\'+(s.k!==i?\'G:J(K=\\\'0\\\');\':\'\')+\'c:\'+(s.c==\'3\'?\'7(((l(2.9.j.A)||0)*-1)+\\\'4\\\')\':a(s.c))+\';\'+\'5:\'+(s.5==\'3\'?\'7(((l(2.9.j.y)||0)*-1)+\\\'4\\\')\':a(s.5))+\';\'+\'8:\'+(s.8==\'3\'?\'7(2.9.S+\\\'4\\\')\':a(s.8))+\';\'+\'d:\'+(s.d==\'3\'?\'7(2.9.v+\\\'4\\\')\':a(s.d))+\';\'+\'"/>\';f 2.T(b(){h($(\'> o.g\',2).U==0)2.V(q.X(p),2.u)})}f 2}})(Z);',62,63,'||this|auto|px|left||expression|width|parentNode||function|top|height|src|return|bgiframe|if|false|currentStyle|opacity|parseInt|fn||iframe|html|document|Number||constructor|firstChild|offsetHeight|extend|browser|borderLeftWidth||borderTopWidth|userAgent|var|navigator|bgIframe|javascript|filter|index|test|Alpha|Opacity|absolute|true|position|block|display|style|tabindex|offsetWidth|each|length|insertBefore|frameborder|createElement|class|jQuery|msie'.split('|'),0,{}));
$.fn.extend({shrinkUrls:function(settings){settings=$.extend({whitespace:false,trunc:'tail'},settings||{});return this.each(function(){var text=$(this).text();if((text.length>settings.size)&&(!settings.include||text.match(settings.include))&&(!settings.exclude||!text.match(settings.exclude))&&(settings.whitespace||!text.match(/\s/))){var txtlength=text.length;var firstPart="";var lastPart="";var middlePart="";switch(settings.trunc){default:case'tail':firstPart=text.substring(0,settings.size-1);break;case'head':lastPart=text.substring(txtlength-settings.size+1,txtlength);break;case'middle':firstPart=text.substring(0,settings.size/2);lastPart=text.substring(txtlength-settings.size/2+1,txtlength);break;}
var origText=text;text=firstPart+"&hellip;"+lastPart;var title=$(this).attr('title');if(title){title+=' ('+origText+')';}else{title=origText;}
$(this).html(text).attr('title',title);}});}});;;
(function($){$.blockUI=function(msg,css,opts){$.blockUI.impl.install(window,msg,css,opts);};$.blockUI.version=1.33;$.unblockUI=function(opts){$.blockUI.impl.remove(window,opts);};$.fn.block=function(msg,css,opts){return this.each(function(){if(!this.$pos_checked){if($.css(this,"position")=='static')
this.style.position='relative';if($.browser.msie)this.style.zoom=1;this.$pos_checked=1;}
$.blockUI.impl.install(this,msg,css,opts);});};$.fn.unblock=function(opts){return this.each(function(){$.blockUI.impl.remove(this,opts);});};$.fn.displayBox=function(css,fn,isFlash){var msg=this[0];if(!msg)return;var $msg=$(msg);css=css||{};var w=$msg.width()||$msg.attr('width')||css.width||$.blockUI.defaults.displayBoxCSS.width;var h=$msg.height()||$msg.attr('height')||css.height||$.blockUI.defaults.displayBoxCSS.height;if(w[w.length-1]=='%'){var ww=document.documentElement.clientWidth||document.body.clientWidth;w=parseInt(w)||100;w=(w*ww)/100;}
if(h[h.length-1]=='%'){var hh=document.documentElement.clientHeight||document.body.clientHeight;h=parseInt(h)||100;h=(h*hh)/100;}
var ml='-'+parseInt(w)/2+'px';var mt='-'+parseInt(h)/2+'px';var ua=navigator.userAgent.toLowerCase();var opts={displayMode:fn||1,noalpha:isFlash&&/mac/.test(ua)&&/firefox/.test(ua)};$.blockUI.impl.install(window,msg,{width:w,height:h,marginTop:mt,marginLeft:ml},opts);};$.blockUI.defaults={pageMessage:'<h1>Please wait...</h1>',elementMessage:'',overlayCSS:{backgroundColor:'#fff',opacity:'0.5'},pageMessageCSS:{width:'250px',margin:'-50px 0 0 -125px',top:'50%',left:'50%',textAlign:'center',color:'#000',backgroundColor:'#fff',border:'3px solid #aaa'},elementMessageCSS:{width:'250px',padding:'10px',textAlign:'center',backgroundColor:'#fff'},displayBoxCSS:{width:'400px',height:'400px',top:'50%',left:'50%'},ie6Stretch:1,allowTabToLeave:0,closeMessage:'Click to close',fadeOut:1,fadeTime:400};$.blockUI.impl={box:null,boxCallback:null,pageBlock:null,pageBlockEls:[],op8:window.opera&&window.opera.version()<9,ie6:$.browser.msie&&/MSIE 6.0/.test(navigator.userAgent),install:function(el,msg,css,opts){opts=opts||{};this.boxCallback=typeof opts.displayMode=='function'?opts.displayMode:null;this.box=opts.displayMode?msg:null;var full=(el==window);var noalpha=this.op8||$.browser.mozilla&&/Linux/.test(navigator.platform);if(typeof opts.alphaOverride!='undefined')
noalpha=opts.alphaOverride==0?1:0;if(full&&this.pageBlock)this.remove(window,{fadeOut:0});if(msg&&typeof msg=='object'&&!msg.jquery&&!msg.nodeType){css=msg;msg=null;}
msg=msg?(msg.nodeType?$(msg):msg):full?$.blockUI.defaults.pageMessage:$.blockUI.defaults.elementMessage;if(opts.displayMode)
var basecss=jQuery.extend({},$.blockUI.defaults.displayBoxCSS);else
var basecss=jQuery.extend({},full?$.blockUI.defaults.pageMessageCSS:$.blockUI.defaults.elementMessageCSS);css=jQuery.extend(basecss,css||{});var f=($.browser.msie)?$('<iframe class="blockUI" style="z-index:1000;border:none;margin:0;padding:0;position:absolute;width:100%;height:100%;top:0;left:0" src="javascript:false;"></iframe>'):$('<div class="blockUI" style="display:none"></div>');var w=$('<div class="blockUI" style="z-index:1001;cursor:wait;border:none;margin:0;padding:0;width:100%;height:100%;top:0;left:0"></div>');var m=full?$('<div class="blockUI blockMsg" style="z-index:1002;cursor:wait;padding:0;position:fixed"></div>'):$('<div class="blockUI" style="display:none;z-index:1002;cursor:wait;position:absolute"></div>');w.css('position',full?'fixed':'absolute');if(msg)m.css(css);if(!noalpha)w.css($.blockUI.defaults.overlayCSS);if(this.op8)w.css({width:''+el.clientWidth,height:''+el.clientHeight});if($.browser.msie)f.css('opacity','0.0');$([f[0],w[0],m[0]]).appendTo(full?'body':el);var expr=$.browser.msie&&(!$.boxModel||$('object,embed',full?null:el).length>0);if(this.ie6||expr){if(full&&$.blockUI.defaults.ie6Stretch&&$.boxModel)
$('html,body').css('height','100%');if((this.ie6||!$.boxModel)&&!full){var t=this.sz(el,'borderTopWidth'),l=this.sz(el,'borderLeftWidth');var fixT=t?'(0 - '+t+')':0;var fixL=l?'(0 - '+l+')':0;}
$.each([f,w,m],function(i,o){var s=o[0].style;s.position='absolute';if(i<2){full?s.setExpression('height','document.body.scrollHeight > document.body.offsetHeight ? document.body.scrollHeight : document.body.offsetHeight + "px"'):s.setExpression('height','this.parentNode.offsetHeight + "px"');full?s.setExpression('width','jQuery.boxModel && document.documentElement.clientWidth || document.body.clientWidth + "px"'):s.setExpression('width','this.parentNode.offsetWidth + "px"');if(fixL)s.setExpression('left',fixL);if(fixT)s.setExpression('top',fixT);}
else{if(full)s.setExpression('top','(document.documentElement.clientHeight || document.body.clientHeight) / 2 - (this.offsetHeight / 2) + (blah = document.documentElement.scrollTop ? document.documentElement.scrollTop : document.body.scrollTop) + "px"');s.marginTop=0;}});}
if(opts.displayMode){w.css('cursor','default').attr('title',$.blockUI.defaults.closeMessage);m.css('cursor','default');$([f[0],w[0],m[0]]).removeClass('blockUI').addClass('displayBox');$().click($.blockUI.impl.boxHandler).bind('keypress',$.blockUI.impl.boxHandler);}
else
this.bind(1,el);m.append(msg).show();if(msg.jquery)msg.show();if(opts.displayMode)return;if(full){this.pageBlock=m[0];this.pageBlockEls=$(':input:enabled:visible',this.pageBlock);setTimeout(this.focus,20);}
else this.center(m[0]);},remove:function(el,opts){var o=$.extend({},$.blockUI.defaults,opts);this.bind(0,el);var full=el==window;var els=full?$('body').children().filter('.blockUI'):$('.blockUI',el);if(full)this.pageBlock=this.pageBlockEls=null;if(o.fadeOut){els.fadeOut(o.fadeTime,function(){if(this.parentNode)this.parentNode.removeChild(this);});}
else els.remove();},boxRemove:function(el){$().unbind('click',$.blockUI.impl.boxHandler).unbind('keypress',$.blockUI.impl.boxHandler);if(this.boxCallback)
this.boxCallback(this.box);$('body .displayBox').hide().remove();},handler:function(e){if(e.keyCode&&e.keyCode==9){if($.blockUI.impl.pageBlock&&!$.blockUI.defaults.allowTabToLeave){var els=$.blockUI.impl.pageBlockEls;var fwd=!e.shiftKey&&e.target==els[els.length-1];var back=e.shiftKey&&e.target==els[0];if(fwd||back){setTimeout(function(){$.blockUI.impl.focus(back)},10);return false;}}}
if($(e.target).parents('div.blockMsg').length>0)
return true;return $(e.target).parents().children().filter('div.blockUI').length==0;},boxHandler:function(e){if((e.keyCode&&e.keyCode==27)||(e.type=='click'&&$(e.target).parents('div.blockMsg').length==0))
$.blockUI.impl.boxRemove();return true;},bind:function(b,el){var full=el==window;if(!b&&(full&&!this.pageBlock||!full&&!el.$blocked))return;if(!full)el.$blocked=b;var $e=$(el).find('a,:input');$.each(['mousedown','mouseup','keydown','keypress','click'],function(i,o){$e[b?'bind':'unbind'](o,$.blockUI.impl.handler);});},focus:function(back){if(!$.blockUI.impl.pageBlockEls)return;var e=$.blockUI.impl.pageBlockEls[back===true?$.blockUI.impl.pageBlockEls.length-1:0];if(e)e.focus();},center:function(el){var p=el.parentNode,s=el.style;var l=((p.offsetWidth-el.offsetWidth)/2)-this.sz(p,'borderLeftWidth');var t=((p.offsetHeight-el.offsetHeight)/2)-this.sz(p,'borderTopWidth');s.left=l>0?(l+'px'):'0';s.top=t>0?(t+'px'):'0';},sz:function(el,p){return parseInt($.css(el,p))||0;}};})(jQuery);;;
(function($){$.fn.innerfade=function(options){this.each(function(){var settings={animationtype:'fade',speed:'normal',timeout:2000,type:'sequence',containerheight:'auto',runningclass:'innerfade'};if(options)
$.extend(settings,options);var elements=$(this).children();if(elements.length>1){$(this).css('position','relative');$(this).css('height',settings.containerheight);$(this).addClass(settings.runningclass);for(var i=0;i<elements.length;i++){$(elements[i]).css('z-index',String(elements.length-i)).css('position','absolute');$(elements[i]).hide();};if(settings.type=='sequence'){setTimeout(function(){$.innerfade.next(elements,settings,1,0);},settings.timeout);$(elements[0]).show();}else if(settings.type=='random'){setTimeout(function(){do{current=Math.floor(Math.random()*(elements.length));}while(current==0)
$.innerfade.next(elements,settings,current,0);},settings.timeout);$(elements[0]).show();}else{alert('type must either be \'sequence\' or \'random\'');}}});};$.innerfade=function(){}
$.innerfade.next=function(elements,settings,current,last){if(settings.animationtype=='slide'){$(elements[last]).slideUp(settings.speed,$(elements[current]).slideDown(settings.speed));}else if(settings.animationtype=='fade'){$(elements[last]).fadeOut(settings.speed);$(elements[current]).fadeIn(settings.speed);}else{alert('animationtype must either be \'slide\' or \'fade\'');};if(settings.type=='sequence'){if((current+1)<elements.length){current=current+1;last=current-1;}else{current=0;last=elements.length-1;};}else if(settings.type=='random'){last=current;while(current==last){current=Math.floor(Math.random()*(elements.length));};}else{alert('type must either be \'sequence\' or \'random\'');};setTimeout((function(){$.innerfade.next(elements,settings,current,last);}),settings.timeout);};})(jQuery);;;
$.create=function(){if(arguments.length==0){return[];}
var first_arg=arguments[0];if(first_arg==null){first_arg="";}
if(first_arg.constructor==String){if(arguments.length>1){var second_arg=arguments[1];if(second_arg.constructor==String){var elt=document.createTextNode(first_arg);var elts=[];elts.push(elt);var siblings=$.create.apply(null,Array.prototype.slice.call(arguments,1));elts=elts.concat(siblings);return elts;}else{var elt=document.createElement(first_arg);var attributes=arguments[1];for(var attr in attributes){$(elt).attr(attr,attributes[attr]);}
var children=arguments[2];children=$.create.apply(null,children);$(elt).append(children);if(arguments.length>3){var siblings=$.create.apply(null,Array.prototype.slice.call(arguments,3));return[elt].concat(siblings);}
return elt;}}else{return document.createTextNode(first_arg);}}else{var elts=[];elts.push(first_arg);var siblings=$.create.apply(null,(Array.prototype.slice.call(arguments,1)));elts=elts.concat(siblings);return elts;}};;
eval(function(p,a,c,k,e,r){e=function(c){return(c<a?'':e(parseInt(c/a)))+((c=c%a)>35?String.fromCharCode(c+29):c.toString(36))};if(!''.replace(/^/,String)){while(c--)r[e(c)]=k[c]||e(c);k=[function(e){return r[e]}];e=function(){return'\\w+'};c=1};while(c--)if(k[c])p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c]);return p}(';(3($){m d={},k,g,w,S=$.2f.21&&/1Y\\s(5\\.5|6\\.)/.1B(1w.2e),H=1h;$.f={r:1h,1b:{O:1Q,11:Z,U:"",u:15,z:15,R:"f"},1t:3(){$.f.r=!$.f.r}};$.F.1o({f:3(a){a=$.1o({},$.f.1b,a);1j(a);e 2.B(3(){$.1d(2,"f-7",a);2.T=2.g;$(2).1W("g");2.1U=""}).1S(16,l).1O(l)},D:S?3(){e 2.B(3(){m b=$(2).o(\'N\');4(b.1G(/^j\\(["\']?(.*\\.1C)["\']?\\)$/i)){b=1y.$1;$(2).o({\'N\':\'1x\',\'17\':"1u:1s.1r.2c(2b=Z, 2a=29, 1k=\'"+b+"\')"}).B(3(){m a=$(2).o(\'1m\');4(a!=\'23\'&&a!=\'1i\')$(2).o(\'1m\',\'1i\')})}})}:3(){e 2},1g:S?3(){e 2.B(3(){$(2).o({\'17\':\'\',N:\'\'})})}:3(){e 2},1f:3(){e 2.B(3(){$(2)[$(2).C()?"n":"l"]()})},j:3(){e 2.1e(\'1Z\')||2.1e(\'1k\')}});3 1j(a){4(d.8)e;d.8=$(\'<p R="\'+a.R+\'"><W></W><p 1c="9"></p><p 1c="j"></p></p>\').1X(I.9).l();4($.F.1a)d.8.1a();d.g=$(\'W\',d.8);d.9=$(\'p.9\',d.8);d.j=$(\'p.j\',d.8)}3 7(a){e $.1d(a,"f-7")}3 19(a){4(7(2).O)w=1T(n,7(2).O);A n();H=!!7(2).H;$(I.9).1R(\'K\',q);q(a)}3 16(){4($.f.r||2==k||(!2.T&&!7(2).J))e;k=2;g=2.T;4(7(2).J){d.g.l();m a=7(2).J.1P(2);4(a.1N||a.1M){d.9.12().P(a)}A{d.9.C(a)}d.9.n()}A 4(7(2).10){m b=g.1L(7(2).10);d.g.C(b.1K()).n();d.9.12();1J(m i=0,M;M=b[i];i++){4(i>0)d.9.P("<1I/>");d.9.P(M)}d.9.1f()}A{d.g.C(g).n();d.9.l()}4(7(2).11&&$(2).j())d.j.C($(2).j().1H(\'1F://\',\'\')).n();A d.j.l();d.8.V(7(2).U);4(7(2).D)d.8.D();19.1E(2,1D)}3 n(){w=L;d.8.n();q()}3 q(c){4($.f.r)e;4(!H&&d.8.1A(":1z")){$(I.9).18(\'K\',q)}4(k==L){$(I.9).18(\'K\',q);e}d.8.Q("t-Y").Q("t-13");m b=d.8[0].14;m a=d.8[0].X;4(c){b=c.1v+7(k).z;a=c.1V+7(k).u;d.8.o({z:b+\'E\',u:a+\'E\'})}m v=t(),h=d.8[0];4(v.x+v.1q<h.14+h.1p){b-=h.1p+20+7(k).z;d.8.o({z:b+\'E\'}).V("t-Y")}4(v.y+v.1l<h.X+h.1n){a-=h.1n+20+7(k).u;d.8.o({u:a+\'E\'}).V("t-13")}}3 t(){e{x:$(G).28(),y:$(G).27(),1q:$(G).26(),1l:$(G).25()}}3 l(a){4($.f.r)e;4(w)24(w);k=L;d.8.l().Q(7(2).U);4(7(2).D)d.8.1g()}$.F.2d=$.F.f})(22);',62,140,'||this|function|if|||settings|parent|body|||||return|tooltip|title|||url|current|hide|var|show|css|div|update|blocked||viewport|top||tID|||left|else|each|html|fixPNG|px|fn|window|track|document|bodyHandler|mousemove|null|part|backgroundImage|delay|append|removeClass|id|IE|tooltipText|extraClass|addClass|h3|offsetTop|right|true|showBody|showURL|empty|bottom|offsetLeft||save|filter|unbind|handle|bgiframe|defaults|class|data|attr|hideWhenEmpty|unfixPNG|false|relative|createHelper|src|cy|position|offsetHeight|extend|offsetWidth|cx|Microsoft|DXImageTransform|block|progid|pageX|navigator|none|RegExp|visible|is|test|png|arguments|apply|http|match|replace|br|for|shift|split|jquery|nodeType|click|call|200|bind|hover|setTimeout|alt|pageY|removeAttr|appendTo|MSIE|href||msie|jQuery|absolute|clearTimeout|height|width|scrollTop|scrollLeft|crop|sizingMethod|enabled|AlphaImageLoader|Tooltip|userAgent|browser'.split('|'),0,{}));
jQuery.fn.nifty=function(options){if((document.getElementById&&document.createElement&&Array.prototype.push)==false)return;options=options||"";h=(options.indexOf("fixed-height")>=0)?this.offsetHeight:0;this.each(function(){var i,top="",bottom="";if(options!=""){options=options.replace("left","tl bl");options=options.replace("right","tr br");options=options.replace("top","tr tl");options=options.replace("bottom","br bl");options=options.replace("transparent","alias");if(options.indexOf("tl")>=0){top="both";if(options.indexOf("tr")==-1)top="left";}else if(options.indexOf("tr")>=0)top="right";if(options.indexOf("bl")>=0){bottom="both";if(options.indexOf("br")==-1)bottom="left";}else if(options.indexOf("br")>=0)bottom="right";}
if(top==""&&bottom==""&&options.indexOf("none")==-1){top="both";bottom="both";}
if(this.currentStyle!=null&&this.currentStyle.hasLayout!=null&&this.currentStyle.hasLayout==false)
jQuery(this).css("display","inline-block");if(top!=""){var d=document.createElement("b"),lim=4,border="",p,i,btype="r",bk,color;jQuery(d).css("marginLeft","-"+_niftyGP(this,"Left")+"px");jQuery(d).css("marginRight","-"+_niftyGP(this,"Right")+"px");if(options.indexOf("alias")>=0||(color=_niftyBC(this))=="transparent"){color="transparent";bk="transparent";border=_niftyPBC(this);btype="t";}
else{bk=_niftyPBC(this);border=_niftyMix(color,bk);}
jQuery(d).css("background",bk);d.className="niftycorners";p=_niftyGP(this,"Top");if(options.indexOf("small")>=0){jQuery(d).css("marginBottom",(p-2)+"px");btype+="s";lim=2;}
else if(options.indexOf("big")>=0){jQuery(d).css("marginBottom",(p-10)+"px");btype+="b";lim=8;}
else jQuery(d).css("marginBottom",(p-5)+"px");for(i=1;i<=lim;i++)
jQuery(d).append(CreateStrip(i,top,color,border,btype));jQuery(this).css("paddingTop","0px");jQuery(this).prepend(d);}
if(bottom!=""){var d=document.createElement("b"),lim=4,border="",p,i,btype="r",bk,color;jQuery(d).css("marginLeft","-"+_niftyGP(this,"Left")+"px");jQuery(d).css("marginRight","-"+_niftyGP(this,"Right")+"px");if(options.indexOf("alias")>=0||(color=_niftyBC(this))=="transparent"){color="transparent";bk="transparent";border=_niftyPBC(this);btype="t";}else{bk=_niftyPBC(this);border=_niftyMix(color,bk);}
jQuery(d).css("background",bk);d.className="niftycorners";p=_niftyGP(this,"Bottom");if(options.indexOf("small")>=0){jQuery(d).css("marginTop",(p-2)+"px");btype+="s";lim=2;}
else if(options.indexOf("big")>=0){jQuery(d).css("marginTop",(p-10)+"px");btype+="b";lim=8;}
else jQuery(d).css("marginTop",(p-5)+"px");for(i=lim;i>0;i--)
jQuery(d).append(CreateStrip(i,bottom,color,border,btype));jQuery(this).css("paddingBottom","0");jQuery(this).append(d);};});if(options.indexOf("height")>=0)
{this.each(function(){if(this.offsetHeight>h)h=this.offsetHeight;jQuery(this).css("height","auto");var gap=h-this.offsetHeight;if(gap>0)
{var t=document.createElement("b");t.className="niftyfill";jQuery(t).css("height",gap+"px");nc=this.lastChild;nc.className=="niftycorners"?this.insertBefore(t,nc):jQuery(this).append(t);}});}
return this;}
function CreateStrip(index,side,color,border,btype){var x=document.createElement("b");x.className=btype+index;jQuery(x).css("backgroundColor",color).css("borderColor",border);if(side=="left")jQuery(x).css("borderRightWidth","0").css("marginRight","0");else if(side=="right")jQuery(x).css("borderLeftWidth","0").css("marginLeft","0");return(x);}
function _niftyPBC(x){var el=x.parentNode,c;while(el.tagName.toUpperCase()!="HTML"&&(c=_niftyBC(el))=="transparent")
el=el.parentNode;if(c=="transparent")c="#FFFFFF";return(c);}
function _niftyBC(x){var c=jQuery(x).css("backgroundColor");if(c==null||c=="transparent"||c.indexOf("rgba(0, 0, 0, 0)")>=0)return("transparent");if(c.indexOf("rgb")>=0){var hex="";var regexp=/([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)/;var h=regexp.exec(c);for(var i=1;i<4;i++){var v=parseInt(h[i]).toString(16);if(v.length==1)hex+="0"+v;else hex+=v;}
c="#"+hex;}
return(c);}
function _niftyGP(x,side){var p=jQuery(x).css("padding"+side);if(p==null||p.indexOf("px")==-1)return(0);return(parseInt(p));}
function _niftyMix(c1,c2){var i,step1,step2,x,y,r=new Array(3);c1.length==4?step1=1:step1=2;c2.length==4?step2=1:step2=2;if(c1=='white')c1='#ffffff';if(c2=='white')c2='#ffffff';if(c1=='black')c1='#000000';if(c2=='black')c2='#000000';for(i=0;i<3;i++){x=parseInt(c1.substr(1+step1*i,step1),16);if(step1==1)x=16*x+x;y=parseInt(c2.substr(1+step2*i,step2),16);if(step2==1)y=16*y+y;r[i]=Math.floor((x*50+y*50)/100);r[i]=r[i].toString(16);if(r[i].length==1)r[i]="0"+r[i];}
return("#"+r[0]+r[1]+r[2]);};;
;(function($){$.extend($.fn,{swapClass:function(c1,c2){var c1Elements=this.filter('.'+c1);this.filter('.'+c2).removeClass(c2).addClass(c1);c1Elements.removeClass(c1).addClass(c2);return this;},replaceClass:function(c1,c2){return this.filter('.'+c1).removeClass(c1).addClass(c2).end();},hoverClass:function(className){className=className||"hover";return this.hover(function(){$(this).addClass(className);},function(){$(this).removeClass(className);});},heightToggle:function(animated,callback){animated?this.animate({height:"toggle"},animated,callback):this.each(function(){jQuery(this)[jQuery(this).is(":hidden")?"show":"hide"]();if(callback)
callback.apply(this,arguments);});},heightHide:function(animated,callback){if(animated){this.animate({height:"hide"},animated,callback);}else{this.hide();if(callback)
this.each(callback);}},prepareBranches:function(settings){if(!settings.prerendered){this.filter(":last-child:not(ul)").addClass(CLASSES.last);this.filter((settings.collapsed?"":"."+CLASSES.closed)+":not(."+CLASSES.open+")").find(">ul").hide();}
return this.filter(":has(>ul)");},applyClasses:function(settings,toggler){this.filter(":has(>ul):not(:has(>a))").find(">span").unbind("click.treeview").bind("click.treeview",function(event){if(this==event.target)
toggler.apply($(this).next());}).add($("a",this)).hoverClass();if(!settings.prerendered){this.filter(":has(>ul:hidden)")
.addClass(CLASSES.expandable)
.replaceClass(CLASSES.last,CLASSES.lastExpandable);this.not(":has(>ul:hidden)")
.addClass(CLASSES.collapsable)
.replaceClass(CLASSES.last,CLASSES.lastCollapsable);this.prepend("<div class=\""+CLASSES.hitarea+"\"/>").find("div."+CLASSES.hitarea).each(function(){var classes="";$.each($(this).parent().attr("class").split(" "),function(){classes+=this+"-hitarea ";});$(this).addClass(classes);});}
this.find("div."+CLASSES.hitarea).click(toggler);},treeview:function(settings){settings=$.extend({cookieId:"treeview"},settings);if(settings.add){return this.trigger("add",[settings.add]);}
if(settings.toggle){var callback=settings.toggle;settings.toggle=function(){return callback.apply($(this).parent()[0],arguments);};}
function treeController(tree,control){function handler(filter){return function(){toggler.apply($("div."+CLASSES.hitarea,tree).filter(function(){return filter?$(this).parent("."+filter).length:true;}));return false;};}
$("a:eq(0)",control).click(handler(CLASSES.collapsable));$("a:eq(1)",control).click(handler(CLASSES.expandable));$("a:eq(2)",control).click(handler());}
function toggler(){$(this)
.parent()
.find(">.hitarea")
.swapClass(CLASSES.collapsableHitarea,CLASSES.expandableHitarea)
.swapClass(CLASSES.lastCollapsableHitarea,CLASSES.lastExpandableHitarea)
.end()
.swapClass(CLASSES.collapsable,CLASSES.expandable)
.swapClass(CLASSES.lastCollapsable,CLASSES.lastExpandable)
.find(">ul")
.heightToggle(settings.animated,settings.toggle);if(settings.unique){$(this).parent()
.siblings()
.find(">.hitarea")
.replaceClass(CLASSES.collapsableHitarea,CLASSES.expandableHitarea)
.replaceClass(CLASSES.lastCollapsableHitarea,CLASSES.lastExpandableHitarea)
.end()
.replaceClass(CLASSES.collapsable,CLASSES.expandable)
.replaceClass(CLASSES.lastCollapsable,CLASSES.lastExpandable)
.find(">ul")
.heightHide(settings.animated,settings.toggle);}}
function serialize(){function binary(arg){return arg?1:0;}
var data=[];branches.each(function(i,e){data[i]=$(e).is(":has(>ul:visible)")?1:0;});$.cookie(settings.cookieId,data.join(""));}
function deserialize(){var stored=$.cookie(settings.cookieId);if(stored){var data=stored.split("");branches.each(function(i,e){$(e).find(">ul")[parseInt(data[i])?"show":"hide"]();});}}
this.addClass("treeview");var branches=this.find("li").prepareBranches(settings);switch(settings.persist){case"cookie":var toggleCallback=settings.toggle;settings.toggle=function(){serialize();if(toggleCallback){toggleCallback.apply(this,arguments);}};deserialize();break;case"location":var current=this.find("a").filter(function(){return this.href.toLowerCase()==location.href.toLowerCase();});if(current.length){current.addClass("selected").parents("ul, li").add(current.next()).show();}
break;}
branches.applyClasses(settings,toggler);if(settings.control){treeController(this,settings.control);$(settings.control).show();}
return this.bind("add",function(event,branches){$(branches).prev()
.removeClass(CLASSES.last)
.removeClass(CLASSES.lastCollapsable)
.removeClass(CLASSES.lastExpandable)
.find(">.hitarea")
.removeClass(CLASSES.lastCollapsableHitarea)
.removeClass(CLASSES.lastExpandableHitarea);$(branches).find("li").andSelf().prepareBranches(settings).applyClasses(settings,toggler);});}});var CLASSES=$.fn.treeview.classes={open:"open",closed:"closed",expandable:"expandable",expandableHitarea:"expandable-hitarea",lastExpandableHitarea:"lastExpandable-hitarea",collapsable:"collapsable",collapsableHitarea:"collapsable-hitarea",lastCollapsableHitarea:"lastCollapsable-hitarea",lastCollapsable:"lastCollapsable",lastExpandable:"lastExpandable",last:"last",hitarea:"hitarea"};$.fn.Treeview=$.fn.treeview;})(jQuery);;;
;(function($){function load(settings,root,child,container){$.getJSON(settings.url,{root:root},function(response){function createNode(parent){var current=$("<li/>").attr("id",this.id||"").html("<span>"+this.text+"</span>").appendTo(parent);if(this.classes){current.children("span").addClass(this.classes);}
if(this.expanded){current.addClass("open");}else{current.addClass("closed");}
if(this.hasChildren||this.children&&this.children.length){var branch=$("<ul/>").appendTo(current);if(this.hasChildren){current.addClass("hasChildren");createNode.call({classes:"placeholder",text:"&nbsp;",children:[]},branch);}
if(this.children&&this.children.length){$.each(this.children,createNode,[branch])}}}
child.empty();$.each(response,createNode,[child]);$(container).treeview({add:child});});}
var proxied=$.fn.treeview;$.fn.treeview=function(settings){if(!settings.url){return proxied.apply(this,arguments);}
var container=this;if(!container.children().size())
load(settings,settings.root||"source",this,container);var userToggle=settings.toggle;return proxied.call(this,$.extend({},settings,{collapsed:true,toggle:function(){var $this=$(this);if($this.hasClass("hasChildren")){var childList=$this.removeClass("hasChildren").find("ul");load(settings,this.id,childList,container);}
if(userToggle){userToggle.apply(this,arguments);}}}));};})(jQuery);;;
var twiki;if(!twiki){twiki={};}
twiki.JQueryPlugin=new function(){var self=this;}
twiki.JQueryPlugin.toggle=function(target,effect){switch(effect){case"fade":$(target).animate({height:'toggle',opacity:'toggle'},"fast");break;case"slide":$(target).slideToggle("fast");break;case"ease":$(target).slideToggle({duration:200,easing:'easeInOutQuad'});break;case"bounce":if($(target).is(":visible")){$(target).slideUp({duration:200,easing:'easeInOutQuad'});}else{$(target).slideDown({duration:500,easing:'easeOutBounce'});}
break;case"toggle":default:return $(target).toggle();break;}
return $(target);}
$.fn.extend({roundedCorners:function(){this.each(function(){var cls=$(this).attr('class');var h2args='';var divargs='';var foundsize=false;var foundh2=false;var foundcorner=false;if($(this).children().is("h2"))foundh2=true;if(cls.match(/\bsame-height\b/))
divargs+=" same-height";if(cls.match(/\bfixed-height\b/))
divargs+=" fixed-height";if(cls.match(/\btransparent\b/)){h2args+=" transparent";divargs+=" transparent";}
if(cls.match(/\btl\b/)){foundcorner=true;if(foundh2){h2args+=" tl";divargs+=" none";}else
divargs+=" tl";}
if(cls.match(/\btr\b/)){foundcorner=true;if(foundh2){h2args+=" tr";divargs+=" none";}else
divargs+=" tr";}
if(cls.match(/\bbl\b/)){foundcorner=true;h2args+=" none";divargs+=" bl";}
if(cls.match(/\bbr\b/)){foundcorner=true;h2args+=" none";divargs+=" br";}
if(cls.match(/\bbottom\b/)){foundcorner=true;if(foundh2)
h2args+=" none";divargs+=" bottom";}
if(cls.match(/\bleft\b/)){foundcorner=true;if(foundh2){h2args+=" tl";divargs+=" bl";}else{divargs+=" left";}}
if(cls.match(/\btop\b/)){foundcorner=true;if(foundh2){h2args+=" top";divargs+=" none";}else{divargs+=" top";}}
if(cls.match(/\bright\b/)){foundcorner=true;if(foundh2){h2args+=" tr";divargs+=" br";}else{divargs+=" right";}}
if(cls.match(/\bnone\b/)){foundcorner=true;h2args+=" none";divargs+=" none";}
if(cls.match(/\bsmall\b/)){h2args+=" small";divargs+=" small";foundsize=true;}
if(cls.match(/\bnormal\b/)){h2args+=" normal";divargs+=" normal";foundsize=true;}
if(cls.match(/\bbig\b/)){h2args+=" big";divargs+=" big";foundsize=true;}
if(!foundsize){h2args+=" big";divargs+=" big";}
if(!foundcorner){if(foundh2){h2args+=" top";divargs+=" bottom";}}
if(foundh2){$("h2",this).nifty(h2args);}
$(this).nifty(divargs);});return this;}});$(function(){var $jqTreeviews;if(true){$jqTreeviews=$(".jqTreeview");$jqTreeviews.children("> ul").each(function(){var args=Array();var parentClass=$(this).parent().attr('class');if(parentClass.match(/\bopen\b/)){args['collapsed']=false;}
if(parentClass.match(/\bclosed?\b/)){args['collapsed']=true;}
if(parentClass.match(/\bunique\b/)){args['unique']=true;}
if(parentClass.match(/\bprerendered\b/)){args['prerendered']=true;}
args['animated']='fast';if(parentClass.match(/\bspeed_(fast|slow|normal|none|[\d\.]+)\b/)){var speed=RegExp.$1;if(speed=="none"){delete args['animated'];}else{args['animated']=speed;}}
$(this).treeview(args);});}
if(false){$(".twikiAttachments .twikiTable a").shrinkUrls({size:25,trunc:'middle'});}
if(false){$('.jqButton').each(function(){var b=$(this);var tt=b.text();b.text('').prepend('<i></i>').append($('<span>').text(tt).append('<i></i><span></span>'));});}
if(false){$("a,span,input").tooltip({delay:250,track:false,showURL:false,extraClass:'twiki',showBody:": "});}
if(false){$(".jqRounded").roundedCorners();}
if(false){$(".twikiToc").each(function(){$(this).prepend("<a class='twikiTocToggle'>[hide]</a>")});$(".twikiTocToggle").css("float","right").click(function(){$("> ul",$(this).parent()).slideToggle({easing:'easeInOutQuad',duration:300});if($(this).text()=="[hide]"){$(this).text("[show]");}else{$(this).text("[hide]");}});}
if($jqTreeviews){$jqTreeviews.css('display','block');}});;;
(function($){$.fn.tabpane=function(options){writeDebug("called tabpane()");var opts=$.extend({},$.fn.tabpane.defaults,options);return this.each(function(){var $thisPane=$(this);var thisOpts=$.extend({},opts,$thisPane.data());var $tabContainer=$thisPane;var $tabGroup=$('<ul class="jqTabGroup"></ul>').prependTo($tabContainer);var index=1;var currentTabId;$thisPane.children(".jqTab").each(function(){var title=$('h2',this).eq(0).remove().text();$tabGroup.append('<li'+(index==thisOpts.select?' class="current"':'')+'><a href="javascript:void(0)" data="'+this.id+'">'+title+'</a></li>');if(index==thisOpts.select){currentTabId=this.id;$(this).addClass("current");}else{$(this).removeClass("current");}
index++;});switchTab(currentTabId,currentTabId,thisOpts);$(".jqTabGroup li > a",this).click(function(){$(this).blur();var newTabId=$(this).attr('data');if(newTabId!=currentTabId){$("#"+currentTabId).removeClass("current");$("#"+newTabId).addClass("current");$(this).parent().parent().children("li").removeClass("current");$(this).parent().addClass("current");switchTab(currentTabId,newTabId,thisOpts);currentTabId=newTabId;}
return false;});$thisPane.css("display","block");});};function switchTab(oldTabId,newTabId,thisOpts){writeDebug("switch from "+oldTabId+" to "+newTabId);var $newTab=$("#"+newTabId);if(!thisOpts[newTabId]){thisOpts[newTabId]=$newTab.data();}
var data=thisOpts[newTabId];if(typeof(data.beforeHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.beforeHandler+";}";writeDebug("exec "+command);eval(command);}
if(typeof(data.url)!="undefined"){var container=data.container||'.jqTabContents';var $container=$newTab.find(container);writeDebug("loading "+data.url+" into "+container);if(typeof(data.afterLoadHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterLoadHandler+";}";writeDebug("after load handler "+command);var func=new Function(command);$container.load(data.url,{},func);}else{$container.load(data.url);}
delete thisOpts[newTabId].url;}
if(typeof(data.afterHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterHandler+";}";writeDebug("exec "+command);eval(command);}}
function writeDebug(msg){if($.fn.tabpane.defaults.debug){if(window.console&&window.console.log){window.console.log("DEBUG: TabPane - "+msg);}else{}}};$.fn.tabpane.defaults={debug:false,select:1};})(jQuery);;;
