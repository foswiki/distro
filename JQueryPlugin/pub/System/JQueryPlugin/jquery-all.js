(function(){var
window=this,undefined,_jQuery=window.jQuery,_$=window.$,jQuery=window.jQuery=window.$=function(selector,context){return new jQuery.fn.init(selector,context);},quickExpr=/^[^<]*(<(.|\s)+>)[^>]*$|^#([\w-]+)$/,isSimple=/^.[^:#\[\.,]*$/;jQuery.fn=jQuery.prototype={init:function(selector,context){selector=selector||document;if(selector.nodeType){this[0]=selector;this.length=1;this.context=selector;return this;}
if(typeof selector==="string"){var match=quickExpr.exec(selector);if(match&&(match[1]||!context)){if(match[1])
selector=jQuery.clean([match[1]],context);else{var elem=document.getElementById(match[3]);if(elem&&elem.id!=match[3])
return jQuery().find(selector);var ret=jQuery(elem||[]);ret.context=document;ret.selector=selector;return ret;}}else
return jQuery(context).find(selector);}else if(jQuery.isFunction(selector))
return jQuery(document).ready(selector);if(selector.selector&&selector.context){this.selector=selector.selector;this.context=selector.context;}
return this.setArray(jQuery.isArray(selector)?selector:jQuery.makeArray(selector));},selector:"",jquery:"1.3.2",size:function(){return this.length;},get:function(num){return num===undefined?Array.prototype.slice.call(this):this[num];},pushStack:function(elems,name,selector){var ret=jQuery(elems);ret.prevObject=this;ret.context=this.context;if(name==="find")
ret.selector=this.selector+(this.selector?" ":"")+selector;else if(name)
ret.selector=this.selector+"."+name+"("+selector+")";return ret;},setArray:function(elems){this.length=0;Array.prototype.push.apply(this,elems);return this;},each:function(callback,args){return jQuery.each(this,callback,args);},index:function(elem){return jQuery.inArray(elem&&elem.jquery?elem[0]:elem,this);},attr:function(name,value,type){var options=name;if(typeof name==="string")
if(value===undefined)
return this[0]&&jQuery[type||"attr"](this[0],name);else{options={};options[name]=value;}
return this.each(function(i){for(name in options)
jQuery.attr(type?this.style:this,name,jQuery.prop(this,options[name],type,i,name));});},css:function(key,value){if((key=='width'||key=='height')&&parseFloat(value)<0)
value=undefined;return this.attr(key,value,"curCSS");},text:function(text){if(typeof text!=="object"&&text!=null)
return this.empty().append((this[0]&&this[0].ownerDocument||document).createTextNode(text));var ret="";jQuery.each(text||this,function(){jQuery.each(this.childNodes,function(){if(this.nodeType!=8)
ret+=this.nodeType!=1?this.nodeValue:jQuery.fn.text([this]);});});return ret;},wrapAll:function(html){if(this[0]){var wrap=jQuery(html,this[0].ownerDocument).clone();if(this[0].parentNode)
wrap.insertBefore(this[0]);wrap.map(function(){var elem=this;while(elem.firstChild)
elem=elem.firstChild;return elem;}).append(this);}
return this;},wrapInner:function(html){return this.each(function(){jQuery(this).contents().wrapAll(html);});},wrap:function(html){return this.each(function(){jQuery(this).wrapAll(html);});},append:function(){return this.domManip(arguments,true,function(elem){if(this.nodeType==1)
this.appendChild(elem);});},prepend:function(){return this.domManip(arguments,true,function(elem){if(this.nodeType==1)
this.insertBefore(elem,this.firstChild);});},before:function(){return this.domManip(arguments,false,function(elem){this.parentNode.insertBefore(elem,this);});},after:function(){return this.domManip(arguments,false,function(elem){this.parentNode.insertBefore(elem,this.nextSibling);});},end:function(){return this.prevObject||jQuery([]);},push:[].push,sort:[].sort,splice:[].splice,find:function(selector){if(this.length===1){var ret=this.pushStack([],"find",selector);ret.length=0;jQuery.find(selector,this[0],ret);return ret;}else{return this.pushStack(jQuery.unique(jQuery.map(this,function(elem){return jQuery.find(selector,elem);})),"find",selector);}},clone:function(events){var ret=this.map(function(){if(!jQuery.support.noCloneEvent&&!jQuery.isXMLDoc(this)){var html=this.outerHTML;if(!html){var div=this.ownerDocument.createElement("div");div.appendChild(this.cloneNode(true));html=div.innerHTML;}
return jQuery.clean([html.replace(/ jQuery\d+="(?:\d+|null)"/g,"").replace(/^\s*/,"")])[0];}else
return this.cloneNode(true);});if(events===true){var orig=this.find("*").andSelf(),i=0;ret.find("*").andSelf().each(function(){if(this.nodeName!==orig[i].nodeName)
return;var events=jQuery.data(orig[i],"events");for(var type in events){for(var handler in events[type]){jQuery.event.add(this,type,events[type][handler],events[type][handler].data);}}
i++;});}
return ret;},filter:function(selector){return this.pushStack(jQuery.isFunction(selector)&&jQuery.grep(this,function(elem,i){return selector.call(elem,i);})||jQuery.multiFilter(selector,jQuery.grep(this,function(elem){return elem.nodeType===1;})),"filter",selector);},closest:function(selector){var pos=jQuery.expr.match.POS.test(selector)?jQuery(selector):null,closer=0;return this.map(function(){var cur=this;while(cur&&cur.ownerDocument){if(pos?pos.index(cur)>-1:jQuery(cur).is(selector)){jQuery.data(cur,"closest",closer);return cur;}
cur=cur.parentNode;closer++;}});},not:function(selector){if(typeof selector==="string")
if(isSimple.test(selector))
return this.pushStack(jQuery.multiFilter(selector,this,true),"not",selector);else
selector=jQuery.multiFilter(selector,this);var isArrayLike=selector.length&&selector[selector.length-1]!==undefined&&!selector.nodeType;return this.filter(function(){return isArrayLike?jQuery.inArray(this,selector)<0:this!=selector;});},add:function(selector){return this.pushStack(jQuery.unique(jQuery.merge(this.get(),typeof selector==="string"?jQuery(selector):jQuery.makeArray(selector))));},is:function(selector){return!!selector&&jQuery.multiFilter(selector,this).length>0;},hasClass:function(selector){return!!selector&&this.is("."+selector);},val:function(value){if(value===undefined){var elem=this[0];if(elem){if(jQuery.nodeName(elem,'option'))
return(elem.attributes.value||{}).specified?elem.value:elem.text;if(jQuery.nodeName(elem,"select")){var index=elem.selectedIndex,values=[],options=elem.options,one=elem.type=="select-one";if(index<0)
return null;for(var i=one?index:0,max=one?index+1:options.length;i<max;i++){var option=options[i];if(option.selected){value=jQuery(option).val();if(one)
return value;values.push(value);}}
return values;}
return(elem.value||"").replace(/\r/g,"");}
return undefined;}
if(typeof value==="number")
value+='';return this.each(function(){if(this.nodeType!=1)
return;if(jQuery.isArray(value)&&/radio|checkbox/.test(this.type))
this.checked=(jQuery.inArray(this.value,value)>=0||jQuery.inArray(this.name,value)>=0);else if(jQuery.nodeName(this,"select")){var values=jQuery.makeArray(value);jQuery("option",this).each(function(){this.selected=(jQuery.inArray(this.value,values)>=0||jQuery.inArray(this.text,values)>=0);});if(!values.length)
this.selectedIndex=-1;}else
this.value=value;});},html:function(value){return value===undefined?(this[0]?this[0].innerHTML.replace(/ jQuery\d+="(?:\d+|null)"/g,""):null):this.empty().append(value);},replaceWith:function(value){return this.after(value).remove();},eq:function(i){return this.slice(i,+i+1);},slice:function(){return this.pushStack(Array.prototype.slice.apply(this,arguments),"slice",Array.prototype.slice.call(arguments).join(","));},map:function(callback){return this.pushStack(jQuery.map(this,function(elem,i){return callback.call(elem,i,elem);}));},andSelf:function(){return this.add(this.prevObject);},domManip:function(args,table,callback){if(this[0]){var fragment=(this[0].ownerDocument||this[0]).createDocumentFragment(),scripts=jQuery.clean(args,(this[0].ownerDocument||this[0]),fragment),first=fragment.firstChild;if(first)
for(var i=0,l=this.length;i<l;i++)
callback.call(root(this[i],first),this.length>1||i>0?fragment.cloneNode(true):fragment);if(scripts)
jQuery.each(scripts,evalScript);}
return this;function root(elem,cur){return table&&jQuery.nodeName(elem,"table")&&jQuery.nodeName(cur,"tr")?(elem.getElementsByTagName("tbody")[0]||elem.appendChild(elem.ownerDocument.createElement("tbody"))):elem;}}};jQuery.fn.init.prototype=jQuery.fn;function evalScript(i,elem){if(elem.src)
jQuery.ajax({url:elem.src,async:false,dataType:"script"});else
jQuery.globalEval(elem.text||elem.textContent||elem.innerHTML||"");if(elem.parentNode)
elem.parentNode.removeChild(elem);}
function now(){return+new Date;}
jQuery.extend=jQuery.fn.extend=function(){var target=arguments[0]||{},i=1,length=arguments.length,deep=false,options;if(typeof target==="boolean"){deep=target;target=arguments[1]||{};i=2;}
if(typeof target!=="object"&&!jQuery.isFunction(target))
target={};if(length==i){target=this;--i;}
for(;i<length;i++)
if((options=arguments[i])!=null)
for(var name in options){var src=target[name],copy=options[name];if(target===copy)
continue;if(deep&&copy&&typeof copy==="object"&&!copy.nodeType)
target[name]=jQuery.extend(deep,src||(copy.length!=null?[]:{}),copy);else if(copy!==undefined)
target[name]=copy;}
return target;};var	exclude=/z-?index|font-?weight|opacity|zoom|line-?height/i,defaultView=document.defaultView||{},toString=Object.prototype.toString;jQuery.extend({noConflict:function(deep){window.$=_$;if(deep)
window.jQuery=_jQuery;return jQuery;},isFunction:function(obj){return toString.call(obj)==="[object Function]";},isArray:function(obj){return toString.call(obj)==="[object Array]";},isXMLDoc:function(elem){return elem.nodeType===9&&elem.documentElement.nodeName!=="HTML"||!!elem.ownerDocument&&jQuery.isXMLDoc(elem.ownerDocument);},globalEval:function(data){if(data&&/\S/.test(data)){var head=document.getElementsByTagName("head")[0]||document.documentElement,script=document.createElement("script");script.type="text/javascript";if(jQuery.support.scriptEval)
script.appendChild(document.createTextNode(data));else
script.text=data;head.insertBefore(script,head.firstChild);head.removeChild(script);}},nodeName:function(elem,name){return elem.nodeName&&elem.nodeName.toUpperCase()==name.toUpperCase();},each:function(object,callback,args){var name,i=0,length=object.length;if(args){if(length===undefined){for(name in object)
if(callback.apply(object[name],args)===false)
break;}else
for(;i<length;)
if(callback.apply(object[i++],args)===false)
break;}else{if(length===undefined){for(name in object)
if(callback.call(object[name],name,object[name])===false)
break;}else
for(var value=object[0];i<length&&callback.call(value,i,value)!==false;value=object[++i]){}}
return object;},prop:function(elem,value,type,i,name){if(jQuery.isFunction(value))
value=value.call(elem,i);return typeof value==="number"&&type=="curCSS"&&!exclude.test(name)?value+"px":value;},className:{add:function(elem,classNames){jQuery.each((classNames||"").split(/\s+/),function(i,className){if(elem.nodeType==1&&!jQuery.className.has(elem.className,className))
elem.className+=(elem.className?" ":"")+className;});},remove:function(elem,classNames){if(elem.nodeType==1)
elem.className=classNames!==undefined?jQuery.grep(elem.className.split(/\s+/),function(className){return!jQuery.className.has(classNames,className);}).join(" "):"";},has:function(elem,className){return elem&&jQuery.inArray(className,(elem.className||elem).toString().split(/\s+/))>-1;}},swap:function(elem,options,callback){var old={};for(var name in options){old[name]=elem.style[name];elem.style[name]=options[name];}
callback.call(elem);for(var name in options)
elem.style[name]=old[name];},css:function(elem,name,force,extra){if(name=="width"||name=="height"){var val,props={position:"absolute",visibility:"hidden",display:"block"},which=name=="width"?["Left","Right"]:["Top","Bottom"];function getWH(){val=name=="width"?elem.offsetWidth:elem.offsetHeight;if(extra==="border")
return;jQuery.each(which,function(){if(!extra)
val-=parseFloat(jQuery.curCSS(elem,"padding"+this,true))||0;if(extra==="margin")
val+=parseFloat(jQuery.curCSS(elem,"margin"+this,true))||0;else
val-=parseFloat(jQuery.curCSS(elem,"border"+this+"Width",true))||0;});}
if(elem.offsetWidth!==0)
getWH();else
jQuery.swap(elem,props,getWH);return Math.max(0,Math.round(val));}
return jQuery.curCSS(elem,name,force);},curCSS:function(elem,name,force){var ret,style=elem.style;if(name=="opacity"&&!jQuery.support.opacity){ret=jQuery.attr(style,"opacity");return ret==""?"1":ret;}
if(name.match(/float/i))
name=styleFloat;if(!force&&style&&style[name])
ret=style[name];else if(defaultView.getComputedStyle){if(name.match(/float/i))
name="float";name=name.replace(/([A-Z])/g,"-$1").toLowerCase();var computedStyle=defaultView.getComputedStyle(elem,null);if(computedStyle)
ret=computedStyle.getPropertyValue(name);if(name=="opacity"&&ret=="")
ret="1";}else if(elem.currentStyle){var camelCase=name.replace(/\-(\w)/g,function(all,letter){return letter.toUpperCase();});ret=elem.currentStyle[name]||elem.currentStyle[camelCase];if(!/^\d+(px)?$/i.test(ret)&&/^\d/.test(ret)){var left=style.left,rsLeft=elem.runtimeStyle.left;elem.runtimeStyle.left=elem.currentStyle.left;style.left=ret||0;ret=style.pixelLeft+"px";style.left=left;elem.runtimeStyle.left=rsLeft;}}
return ret;},clean:function(elems,context,fragment){context=context||document;if(typeof context.createElement==="undefined")
context=context.ownerDocument||context[0]&&context[0].ownerDocument||document;if(!fragment&&elems.length===1&&typeof elems[0]==="string"){var match=/^<(\w+)\s*\/?>$/.exec(elems[0]);if(match)
return[context.createElement(match[1])];}
var ret=[],scripts=[],div=context.createElement("div");jQuery.each(elems,function(i,elem){if(typeof elem==="number")
elem+='';if(!elem)
return;if(typeof elem==="string"){elem=elem.replace(/(<(\w+)[^>]*?)\/>/g,function(all,front,tag){return tag.match(/^(abbr|br|col|img|input|link|meta|param|hr|area|embed)$/i)?all:front+"></"+tag+">";});var tags=elem.replace(/^\s+/,"").substring(0,10).toLowerCase();var wrap=!tags.indexOf("<opt")&&[1,"<select multiple='multiple'>","</select>"]||!tags.indexOf("<leg")&&[1,"<fieldset>","</fieldset>"]||tags.match(/^<(thead|tbody|tfoot|colg|cap)/)&&[1,"<table>","</table>"]||!tags.indexOf("<tr")&&[2,"<table><tbody>","</tbody></table>"]||(!tags.indexOf("<td")||!tags.indexOf("<th"))&&[3,"<table><tbody><tr>","</tr></tbody></table>"]||!tags.indexOf("<col")&&[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"]||!jQuery.support.htmlSerialize&&[1,"div<div>","</div>"]||[0,"",""];div.innerHTML=wrap[1]+elem+wrap[2];while(wrap[0]--)
div=div.lastChild;if(!jQuery.support.tbody){var hasBody=/<tbody/i.test(elem),tbody=!tags.indexOf("<table")&&!hasBody?div.firstChild&&div.firstChild.childNodes:wrap[1]=="<table>"&&!hasBody?div.childNodes:[];for(var j=tbody.length-1;j>=0;--j)
if(jQuery.nodeName(tbody[j],"tbody")&&!tbody[j].childNodes.length)
tbody[j].parentNode.removeChild(tbody[j]);}
if(!jQuery.support.leadingWhitespace&&/^\s/.test(elem))
div.insertBefore(context.createTextNode(elem.match(/^\s*/)[0]),div.firstChild);elem=jQuery.makeArray(div.childNodes);}
if(elem.nodeType)
ret.push(elem);else
ret=jQuery.merge(ret,elem);});if(fragment){for(var i=0;ret[i];i++){if(jQuery.nodeName(ret[i],"script")&&(!ret[i].type||ret[i].type.toLowerCase()==="text/javascript")){scripts.push(ret[i].parentNode?ret[i].parentNode.removeChild(ret[i]):ret[i]);}else{if(ret[i].nodeType===1)
ret.splice.apply(ret,[i+1,0].concat(jQuery.makeArray(ret[i].getElementsByTagName("script"))));fragment.appendChild(ret[i]);}}
return scripts;}
return ret;},attr:function(elem,name,value){if(!elem||elem.nodeType==3||elem.nodeType==8)
return undefined;var notxml=!jQuery.isXMLDoc(elem),set=value!==undefined;name=notxml&&jQuery.props[name]||name;if(elem.tagName){var special=/href|src|style/.test(name);if(name=="selected"&&elem.parentNode)
elem.parentNode.selectedIndex;if(name in elem&&notxml&&!special){if(set){if(name=="type"&&jQuery.nodeName(elem,"input")&&elem.parentNode)
throw"type property can't be changed";elem[name]=value;}
if(jQuery.nodeName(elem,"form")&&elem.getAttributeNode(name))
return elem.getAttributeNode(name).nodeValue;if(name=="tabIndex"){var attributeNode=elem.getAttributeNode("tabIndex");return attributeNode&&attributeNode.specified?attributeNode.value:elem.nodeName.match(/(button|input|object|select|textarea)/i)?0:elem.nodeName.match(/^(a|area)$/i)&&elem.href?0:undefined;}
return elem[name];}
if(!jQuery.support.style&&notxml&&name=="style")
return jQuery.attr(elem.style,"cssText",value);if(set)
elem.setAttribute(name,""+value);var attr=!jQuery.support.hrefNormalized&&notxml&&special?elem.getAttribute(name,2):elem.getAttribute(name);return attr===null?undefined:attr;}
if(!jQuery.support.opacity&&name=="opacity"){if(set){elem.zoom=1;elem.filter=(elem.filter||"").replace(/alpha\([^)]*\)/,"")+
(parseInt(value)+''=="NaN"?"":"alpha(opacity="+value*100+")");}
return elem.filter&&elem.filter.indexOf("opacity=")>=0?(parseFloat(elem.filter.match(/opacity=([^)]*)/)[1])/100)+'':"";}
name=name.replace(/-([a-z])/ig,function(all,letter){return letter.toUpperCase();});if(set)
elem[name]=value;return elem[name];},trim:function(text){return(text||"").replace(/^\s+|\s+$/g,"");},makeArray:function(array){var ret=[];if(array!=null){var i=array.length;if(i==null||typeof array==="string"||jQuery.isFunction(array)||array.setInterval)
ret[0]=array;else
while(i)
ret[--i]=array[i];}
return ret;},inArray:function(elem,array){for(var i=0,length=array.length;i<length;i++)
if(array[i]===elem)
return i;return-1;},merge:function(first,second){var i=0,elem,pos=first.length;if(!jQuery.support.getAll){while((elem=second[i++])!=null)
if(elem.nodeType!=8)
first[pos++]=elem;}else
while((elem=second[i++])!=null)
first[pos++]=elem;return first;},unique:function(array){var ret=[],done={};try{for(var i=0,length=array.length;i<length;i++){var id=jQuery.data(array[i]);if(!done[id]){done[id]=true;ret.push(array[i]);}}}catch(e){ret=array;}
return ret;},grep:function(elems,callback,inv){var ret=[];for(var i=0,length=elems.length;i<length;i++)
if(!inv!=!callback(elems[i],i))
ret.push(elems[i]);return ret;},map:function(elems,callback){var ret=[];for(var i=0,length=elems.length;i<length;i++){var value=callback(elems[i],i);if(value!=null)
ret[ret.length]=value;}
return ret.concat.apply([],ret);}});var userAgent=navigator.userAgent.toLowerCase();jQuery.browser={version:(userAgent.match(/.+(?:rv|it|ra|ie)[\/: ]([\d.]+)/)||[0,'0'])[1],safari:/webkit/.test(userAgent),opera:/opera/.test(userAgent),msie:/msie/.test(userAgent)&&!/opera/.test(userAgent),mozilla:/mozilla/.test(userAgent)&&!/(compatible|webkit)/.test(userAgent)};jQuery.each({parent:function(elem){return elem.parentNode;},parents:function(elem){return jQuery.dir(elem,"parentNode");},next:function(elem){return jQuery.nth(elem,2,"nextSibling");},prev:function(elem){return jQuery.nth(elem,2,"previousSibling");},nextAll:function(elem){return jQuery.dir(elem,"nextSibling");},prevAll:function(elem){return jQuery.dir(elem,"previousSibling");},siblings:function(elem){return jQuery.sibling(elem.parentNode.firstChild,elem);},children:function(elem){return jQuery.sibling(elem.firstChild);},contents:function(elem){return jQuery.nodeName(elem,"iframe")?elem.contentDocument||elem.contentWindow.document:jQuery.makeArray(elem.childNodes);}},function(name,fn){jQuery.fn[name]=function(selector){var ret=jQuery.map(this,fn);if(selector&&typeof selector=="string")
ret=jQuery.multiFilter(selector,ret);return this.pushStack(jQuery.unique(ret),name,selector);};});jQuery.each({appendTo:"append",prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(name,original){jQuery.fn[name]=function(selector){var ret=[],insert=jQuery(selector);for(var i=0,l=insert.length;i<l;i++){var elems=(i>0?this.clone(true):this).get();jQuery.fn[original].apply(jQuery(insert[i]),elems);ret=ret.concat(elems);}
return this.pushStack(ret,name,selector);};});jQuery.each({removeAttr:function(name){jQuery.attr(this,name,"");if(this.nodeType==1)
this.removeAttribute(name);},addClass:function(classNames){jQuery.className.add(this,classNames);},removeClass:function(classNames){jQuery.className.remove(this,classNames);},toggleClass:function(classNames,state){if(typeof state!=="boolean")
state=!jQuery.className.has(this,classNames);jQuery.className[state?"add":"remove"](this,classNames);},remove:function(selector){if(!selector||jQuery.filter(selector,[this]).length){jQuery("*",this).add([this]).each(function(){jQuery.event.remove(this);jQuery.removeData(this);});if(this.parentNode)
this.parentNode.removeChild(this);}},empty:function(){jQuery(this).children().remove();while(this.firstChild)
this.removeChild(this.firstChild);}},function(name,fn){jQuery.fn[name]=function(){return this.each(fn,arguments);};});function num(elem,prop){return elem[0]&&parseInt(jQuery.curCSS(elem[0],prop,true),10)||0;}
var expando="jQuery"+now(),uuid=0,windowData={};jQuery.extend({cache:{},data:function(elem,name,data){elem=elem==window?windowData:elem;var id=elem[expando];if(!id)
id=elem[expando]=++uuid;if(name&&!jQuery.cache[id])
jQuery.cache[id]={};if(data!==undefined)
jQuery.cache[id][name]=data;return name?jQuery.cache[id][name]:id;},removeData:function(elem,name){elem=elem==window?windowData:elem;var id=elem[expando];if(name){if(jQuery.cache[id]){delete jQuery.cache[id][name];name="";for(name in jQuery.cache[id])
break;if(!name)
jQuery.removeData(elem);}}else{try{delete elem[expando];}catch(e){if(elem.removeAttribute)
elem.removeAttribute(expando);}
delete jQuery.cache[id];}},queue:function(elem,type,data){if(elem){type=(type||"fx")+"queue";var q=jQuery.data(elem,type);if(!q||jQuery.isArray(data))
q=jQuery.data(elem,type,jQuery.makeArray(data));else if(data)
q.push(data);}
return q;},dequeue:function(elem,type){var queue=jQuery.queue(elem,type),fn=queue.shift();if(!type||type==="fx")
fn=queue[0];if(fn!==undefined)
fn.call(elem);}});jQuery.fn.extend({data:function(key,value){var parts=key.split(".");parts[1]=parts[1]?"."+parts[1]:"";if(value===undefined){var data=this.triggerHandler("getData"+parts[1]+"!",[parts[0]]);if(data===undefined&&this.length)
data=jQuery.data(this[0],key);return data===undefined&&parts[1]?this.data(parts[0]):data;}else
return this.trigger("setData"+parts[1]+"!",[parts[0],value]).each(function(){jQuery.data(this,key,value);});},removeData:function(key){return this.each(function(){jQuery.removeData(this,key);});},queue:function(type,data){if(typeof type!=="string"){data=type;type="fx";}
if(data===undefined)
return jQuery.queue(this[0],type);return this.each(function(){var queue=jQuery.queue(this,type,data);if(type=="fx"&&queue.length==1)
queue[0].call(this);});},dequeue:function(type){return this.each(function(){jQuery.dequeue(this,type);});}});(function(){var chunker=/((?:\((?:\([^()]+\)|[^()]+)+\)|\[(?:\[[^[\]]*\]|['"][^'"]*['"]|[^[\]'"]+)+\]|\\.|[^ >+~,(\[\\]+)+|[>+~])(\s*,\s*)?/g,done=0,toString=Object.prototype.toString;var Sizzle=function(selector,context,results,seed){results=results||[];context=context||document;if(context.nodeType!==1&&context.nodeType!==9)
return[];if(!selector||typeof selector!=="string"){return results;}
var parts=[],m,set,checkSet,check,mode,extra,prune=true;chunker.lastIndex=0;while((m=chunker.exec(selector))!==null){parts.push(m[1]);if(m[2]){extra=RegExp.rightContext;break;}}
if(parts.length>1&&origPOS.exec(selector)){if(parts.length===2&&Expr.relative[parts[0]]){set=posProcess(parts[0]+parts[1],context);}else{set=Expr.relative[parts[0]]?[context]:Sizzle(parts.shift(),context);while(parts.length){selector=parts.shift();if(Expr.relative[selector])
selector+=parts.shift();set=posProcess(selector,set);}}}else{var ret=seed?{expr:parts.pop(),set:makeArray(seed)}:Sizzle.find(parts.pop(),parts.length===1&&context.parentNode?context.parentNode:context,isXML(context));set=Sizzle.filter(ret.expr,ret.set);if(parts.length>0){checkSet=makeArray(set);}else{prune=false;}
while(parts.length){var cur=parts.pop(),pop=cur;if(!Expr.relative[cur]){cur="";}else{pop=parts.pop();}
if(pop==null){pop=context;}
Expr.relative[cur](checkSet,pop,isXML(context));}}
if(!checkSet){checkSet=set;}
if(!checkSet){throw"Syntax error, unrecognized expression: "+(cur||selector);}
if(toString.call(checkSet)==="[object Array]"){if(!prune){results.push.apply(results,checkSet);}else if(context.nodeType===1){for(var i=0;checkSet[i]!=null;i++){if(checkSet[i]&&(checkSet[i]===true||checkSet[i].nodeType===1&&contains(context,checkSet[i]))){results.push(set[i]);}}}else{for(var i=0;checkSet[i]!=null;i++){if(checkSet[i]&&checkSet[i].nodeType===1){results.push(set[i]);}}}}else{makeArray(checkSet,results);}
if(extra){Sizzle(extra,context,results,seed);if(sortOrder){hasDuplicate=false;results.sort(sortOrder);if(hasDuplicate){for(var i=1;i<results.length;i++){if(results[i]===results[i-1]){results.splice(i--,1);}}}}}
return results;};Sizzle.matches=function(expr,set){return Sizzle(expr,null,null,set);};Sizzle.find=function(expr,context,isXML){var set,match;if(!expr){return[];}
for(var i=0,l=Expr.order.length;i<l;i++){var type=Expr.order[i],match;if((match=Expr.match[type].exec(expr))){var left=RegExp.leftContext;if(left.substr(left.length-1)!=="\\"){match[1]=(match[1]||"").replace(/\\/g,"");set=Expr.find[type](match,context,isXML);if(set!=null){expr=expr.replace(Expr.match[type],"");break;}}}}
if(!set){set=context.getElementsByTagName("*");}
return{set:set,expr:expr};};Sizzle.filter=function(expr,set,inplace,not){var old=expr,result=[],curLoop=set,match,anyFound,isXMLFilter=set&&set[0]&&isXML(set[0]);while(expr&&set.length){for(var type in Expr.filter){if((match=Expr.match[type].exec(expr))!=null){var filter=Expr.filter[type],found,item;anyFound=false;if(curLoop==result){result=[];}
if(Expr.preFilter[type]){match=Expr.preFilter[type](match,curLoop,inplace,result,not,isXMLFilter);if(!match){anyFound=found=true;}else if(match===true){continue;}}
if(match){for(var i=0;(item=curLoop[i])!=null;i++){if(item){found=filter(item,match,i,curLoop);var pass=not^!!found;if(inplace&&found!=null){if(pass){anyFound=true;}else{curLoop[i]=false;}}else if(pass){result.push(item);anyFound=true;}}}}
if(found!==undefined){if(!inplace){curLoop=result;}
expr=expr.replace(Expr.match[type],"");if(!anyFound){return[];}
break;}}}
if(expr==old){if(anyFound==null){throw"Syntax error, unrecognized expression: "+expr;}else{break;}}
old=expr;}
return curLoop;};var Expr=Sizzle.selectors={order:["ID","NAME","TAG"],match:{ID:/#((?:[\w\u00c0-\uFFFF_-]|\\.)+)/,CLASS:/\.((?:[\w\u00c0-\uFFFF_-]|\\.)+)/,NAME:/\[name=['"]*((?:[\w\u00c0-\uFFFF_-]|\\.)+)['"]*\]/,ATTR:/\[\s*((?:[\w\u00c0-\uFFFF_-]|\\.)+)\s*(?:(\S?=)\s*(['"]*)(.*?)\3|)\s*\]/,TAG:/^((?:[\w\u00c0-\uFFFF\*_-]|\\.)+)/,CHILD:/:(only|nth|last|first)-child(?:\((even|odd|[\dn+-]*)\))?/,POS:/:(nth|eq|gt|lt|first|last|even|odd)(?:\((\d*)\))?(?=[^-]|$)/,PSEUDO:/:((?:[\w\u00c0-\uFFFF_-]|\\.)+)(?:\((['"]*)((?:\([^\)]+\)|[^\2\(\)]*)+)\2\))?/},attrMap:{"class":"className","for":"htmlFor"},attrHandle:{href:function(elem){return elem.getAttribute("href");}},relative:{"+":function(checkSet,part,isXML){var isPartStr=typeof part==="string",isTag=isPartStr&&!/\W/.test(part),isPartStrNotTag=isPartStr&&!isTag;if(isTag&&!isXML){part=part.toUpperCase();}
for(var i=0,l=checkSet.length,elem;i<l;i++){if((elem=checkSet[i])){while((elem=elem.previousSibling)&&elem.nodeType!==1){}
checkSet[i]=isPartStrNotTag||elem&&elem.nodeName===part?elem||false:elem===part;}}
if(isPartStrNotTag){Sizzle.filter(part,checkSet,true);}},">":function(checkSet,part,isXML){var isPartStr=typeof part==="string";if(isPartStr&&!/\W/.test(part)){part=isXML?part:part.toUpperCase();for(var i=0,l=checkSet.length;i<l;i++){var elem=checkSet[i];if(elem){var parent=elem.parentNode;checkSet[i]=parent.nodeName===part?parent:false;}}}else{for(var i=0,l=checkSet.length;i<l;i++){var elem=checkSet[i];if(elem){checkSet[i]=isPartStr?elem.parentNode:elem.parentNode===part;}}
if(isPartStr){Sizzle.filter(part,checkSet,true);}}},"":function(checkSet,part,isXML){var doneName=done++,checkFn=dirCheck;if(!part.match(/\W/)){var nodeCheck=part=isXML?part:part.toUpperCase();checkFn=dirNodeCheck;}
checkFn("parentNode",part,doneName,checkSet,nodeCheck,isXML);},"~":function(checkSet,part,isXML){var doneName=done++,checkFn=dirCheck;if(typeof part==="string"&&!part.match(/\W/)){var nodeCheck=part=isXML?part:part.toUpperCase();checkFn=dirNodeCheck;}
checkFn("previousSibling",part,doneName,checkSet,nodeCheck,isXML);}},find:{ID:function(match,context,isXML){if(typeof context.getElementById!=="undefined"&&!isXML){var m=context.getElementById(match[1]);return m?[m]:[];}},NAME:function(match,context,isXML){if(typeof context.getElementsByName!=="undefined"){var ret=[],results=context.getElementsByName(match[1]);for(var i=0,l=results.length;i<l;i++){if(results[i].getAttribute("name")===match[1]){ret.push(results[i]);}}
return ret.length===0?null:ret;}},TAG:function(match,context){return context.getElementsByTagName(match[1]);}},preFilter:{CLASS:function(match,curLoop,inplace,result,not,isXML){match=" "+match[1].replace(/\\/g,"")+" ";if(isXML){return match;}
for(var i=0,elem;(elem=curLoop[i])!=null;i++){if(elem){if(not^(elem.className&&(" "+elem.className+" ").indexOf(match)>=0)){if(!inplace)
result.push(elem);}else if(inplace){curLoop[i]=false;}}}
return false;},ID:function(match){return match[1].replace(/\\/g,"");},TAG:function(match,curLoop){for(var i=0;curLoop[i]===false;i++){}
return curLoop[i]&&isXML(curLoop[i])?match[1]:match[1].toUpperCase();},CHILD:function(match){if(match[1]=="nth"){var test=/(-?)(\d*)n((?:\+|-)?\d*)/.exec(match[2]=="even"&&"2n"||match[2]=="odd"&&"2n+1"||!/\D/.test(match[2])&&"0n+"+match[2]||match[2]);match[2]=(test[1]+(test[2]||1))-0;match[3]=test[3]-0;}
match[0]=done++;return match;},ATTR:function(match,curLoop,inplace,result,not,isXML){var name=match[1].replace(/\\/g,"");if(!isXML&&Expr.attrMap[name]){match[1]=Expr.attrMap[name];}
if(match[2]==="~="){match[4]=" "+match[4]+" ";}
return match;},PSEUDO:function(match,curLoop,inplace,result,not){if(match[1]==="not"){if(match[3].match(chunker).length>1||/^\w/.test(match[3])){match[3]=Sizzle(match[3],null,null,curLoop);}else{var ret=Sizzle.filter(match[3],curLoop,inplace,true^not);if(!inplace){result.push.apply(result,ret);}
return false;}}else if(Expr.match.POS.test(match[0])||Expr.match.CHILD.test(match[0])){return true;}
return match;},POS:function(match){match.unshift(true);return match;}},filters:{enabled:function(elem){return elem.disabled===false&&elem.type!=="hidden";},disabled:function(elem){return elem.disabled===true;},checked:function(elem){return elem.checked===true;},selected:function(elem){elem.parentNode.selectedIndex;return elem.selected===true;},parent:function(elem){return!!elem.firstChild;},empty:function(elem){return!elem.firstChild;},has:function(elem,i,match){return!!Sizzle(match[3],elem).length;},header:function(elem){return/h\d/i.test(elem.nodeName);},text:function(elem){return"text"===elem.type;},radio:function(elem){return"radio"===elem.type;},checkbox:function(elem){return"checkbox"===elem.type;},file:function(elem){return"file"===elem.type;},password:function(elem){return"password"===elem.type;},submit:function(elem){return"submit"===elem.type;},image:function(elem){return"image"===elem.type;},reset:function(elem){return"reset"===elem.type;},button:function(elem){return"button"===elem.type||elem.nodeName.toUpperCase()==="BUTTON";},input:function(elem){return/input|select|textarea|button/i.test(elem.nodeName);}},setFilters:{first:function(elem,i){return i===0;},last:function(elem,i,match,array){return i===array.length-1;},even:function(elem,i){return i%2===0;},odd:function(elem,i){return i%2===1;},lt:function(elem,i,match){return i<match[3]-0;},gt:function(elem,i,match){return i>match[3]-0;},nth:function(elem,i,match){return match[3]-0==i;},eq:function(elem,i,match){return match[3]-0==i;}},filter:{PSEUDO:function(elem,match,i,array){var name=match[1],filter=Expr.filters[name];if(filter){return filter(elem,i,match,array);}else if(name==="contains"){return(elem.textContent||elem.innerText||"").indexOf(match[3])>=0;}else if(name==="not"){var not=match[3];for(var i=0,l=not.length;i<l;i++){if(not[i]===elem){return false;}}
return true;}},CHILD:function(elem,match){var type=match[1],node=elem;switch(type){case'only':case'first':while(node=node.previousSibling){if(node.nodeType===1)return false;}
if(type=='first')return true;node=elem;case'last':while(node=node.nextSibling){if(node.nodeType===1)return false;}
return true;case'nth':var first=match[2],last=match[3];if(first==1&&last==0){return true;}
var doneName=match[0],parent=elem.parentNode;if(parent&&(parent.sizcache!==doneName||!elem.nodeIndex)){var count=0;for(node=parent.firstChild;node;node=node.nextSibling){if(node.nodeType===1){node.nodeIndex=++count;}}
parent.sizcache=doneName;}
var diff=elem.nodeIndex-last;if(first==0){return diff==0;}else{return(diff%first==0&&diff/first>=0);}}},ID:function(elem,match){return elem.nodeType===1&&elem.getAttribute("id")===match;},TAG:function(elem,match){return(match==="*"&&elem.nodeType===1)||elem.nodeName===match;},CLASS:function(elem,match){return(" "+(elem.className||elem.getAttribute("class"))+" ")
.indexOf(match)>-1;},ATTR:function(elem,match){var name=match[1],result=Expr.attrHandle[name]?Expr.attrHandle[name](elem):elem[name]!=null?elem[name]:elem.getAttribute(name),value=result+"",type=match[2],check=match[4];return result==null?type==="!=":type==="="?value===check:type==="*="?value.indexOf(check)>=0:type==="~="?(" "+value+" ").indexOf(check)>=0:!check?value&&result!==false:type==="!="?value!=check:type==="^="?value.indexOf(check)===0:type==="$="?value.substr(value.length-check.length)===check:type==="|="?value===check||value.substr(0,check.length+1)===check+"-":false;},POS:function(elem,match,i,array){var name=match[2],filter=Expr.setFilters[name];if(filter){return filter(elem,i,match,array);}}}};var origPOS=Expr.match.POS;for(var type in Expr.match){Expr.match[type]=RegExp(Expr.match[type].source+/(?![^\[]*\])(?![^\(]*\))/.source);}
var makeArray=function(array,results){array=Array.prototype.slice.call(array);if(results){results.push.apply(results,array);return results;}
return array;};try{Array.prototype.slice.call(document.documentElement.childNodes);}catch(e){makeArray=function(array,results){var ret=results||[];if(toString.call(array)==="[object Array]"){Array.prototype.push.apply(ret,array);}else{if(typeof array.length==="number"){for(var i=0,l=array.length;i<l;i++){ret.push(array[i]);}}else{for(var i=0;array[i];i++){ret.push(array[i]);}}}
return ret;};}
var sortOrder;if(document.documentElement.compareDocumentPosition){sortOrder=function(a,b){var ret=a.compareDocumentPosition(b)&4?-1:a===b?0:1;if(ret===0){hasDuplicate=true;}
return ret;};}else if("sourceIndex"in document.documentElement){sortOrder=function(a,b){var ret=a.sourceIndex-b.sourceIndex;if(ret===0){hasDuplicate=true;}
return ret;};}else if(document.createRange){sortOrder=function(a,b){var aRange=a.ownerDocument.createRange(),bRange=b.ownerDocument.createRange();aRange.selectNode(a);aRange.collapse(true);bRange.selectNode(b);bRange.collapse(true);var ret=aRange.compareBoundaryPoints(Range.START_TO_END,bRange);if(ret===0){hasDuplicate=true;}
return ret;};}
(function(){var form=document.createElement("form"),id="script"+(new Date).getTime();form.innerHTML="<input name='"+id+"'/>";var root=document.documentElement;root.insertBefore(form,root.firstChild);if(!!document.getElementById(id)){Expr.find.ID=function(match,context,isXML){if(typeof context.getElementById!=="undefined"&&!isXML){var m=context.getElementById(match[1]);return m?m.id===match[1]||typeof m.getAttributeNode!=="undefined"&&m.getAttributeNode("id").nodeValue===match[1]?[m]:undefined:[];}};Expr.filter.ID=function(elem,match){var node=typeof elem.getAttributeNode!=="undefined"&&elem.getAttributeNode("id");return elem.nodeType===1&&node&&node.nodeValue===match;};}
root.removeChild(form);})();(function(){var div=document.createElement("div");div.appendChild(document.createComment(""));if(div.getElementsByTagName("*").length>0){Expr.find.TAG=function(match,context){var results=context.getElementsByTagName(match[1]);if(match[1]==="*"){var tmp=[];for(var i=0;results[i];i++){if(results[i].nodeType===1){tmp.push(results[i]);}}
results=tmp;}
return results;};}
div.innerHTML="<a href='#'></a>";if(div.firstChild&&typeof div.firstChild.getAttribute!=="undefined"&&div.firstChild.getAttribute("href")!=="#"){Expr.attrHandle.href=function(elem){return elem.getAttribute("href",2);};}})();if(document.querySelectorAll)(function(){var oldSizzle=Sizzle,div=document.createElement("div");div.innerHTML="<p class='TEST'></p>";if(div.querySelectorAll&&div.querySelectorAll(".TEST").length===0){return;}
Sizzle=function(query,context,extra,seed){context=context||document;if(!seed&&context.nodeType===9&&!isXML(context)){try{return makeArray(context.querySelectorAll(query),extra);}catch(e){}}
return oldSizzle(query,context,extra,seed);};Sizzle.find=oldSizzle.find;Sizzle.filter=oldSizzle.filter;Sizzle.selectors=oldSizzle.selectors;Sizzle.matches=oldSizzle.matches;})();if(document.getElementsByClassName&&document.documentElement.getElementsByClassName)(function(){var div=document.createElement("div");div.innerHTML="<div class='test e'></div><div class='test'></div>";if(div.getElementsByClassName("e").length===0)
return;div.lastChild.className="e";if(div.getElementsByClassName("e").length===1)
return;Expr.order.splice(1,0,"CLASS");Expr.find.CLASS=function(match,context,isXML){if(typeof context.getElementsByClassName!=="undefined"&&!isXML){return context.getElementsByClassName(match[1]);}};})();function dirNodeCheck(dir,cur,doneName,checkSet,nodeCheck,isXML){var sibDir=dir=="previousSibling"&&!isXML;for(var i=0,l=checkSet.length;i<l;i++){var elem=checkSet[i];if(elem){if(sibDir&&elem.nodeType===1){elem.sizcache=doneName;elem.sizset=i;}
elem=elem[dir];var match=false;while(elem){if(elem.sizcache===doneName){match=checkSet[elem.sizset];break;}
if(elem.nodeType===1&&!isXML){elem.sizcache=doneName;elem.sizset=i;}
if(elem.nodeName===cur){match=elem;break;}
elem=elem[dir];}
checkSet[i]=match;}}}
function dirCheck(dir,cur,doneName,checkSet,nodeCheck,isXML){var sibDir=dir=="previousSibling"&&!isXML;for(var i=0,l=checkSet.length;i<l;i++){var elem=checkSet[i];if(elem){if(sibDir&&elem.nodeType===1){elem.sizcache=doneName;elem.sizset=i;}
elem=elem[dir];var match=false;while(elem){if(elem.sizcache===doneName){match=checkSet[elem.sizset];break;}
if(elem.nodeType===1){if(!isXML){elem.sizcache=doneName;elem.sizset=i;}
if(typeof cur!=="string"){if(elem===cur){match=true;break;}}else if(Sizzle.filter(cur,[elem]).length>0){match=elem;break;}}
elem=elem[dir];}
checkSet[i]=match;}}}
var contains=document.compareDocumentPosition?function(a,b){return a.compareDocumentPosition(b)&16;}:function(a,b){return a!==b&&(a.contains?a.contains(b):true);};var isXML=function(elem){return elem.nodeType===9&&elem.documentElement.nodeName!=="HTML"||!!elem.ownerDocument&&isXML(elem.ownerDocument);};var posProcess=function(selector,context){var tmpSet=[],later="",match,root=context.nodeType?[context]:context;while((match=Expr.match.PSEUDO.exec(selector))){later+=match[0];selector=selector.replace(Expr.match.PSEUDO,"");}
selector=Expr.relative[selector]?selector+"*":selector;for(var i=0,l=root.length;i<l;i++){Sizzle(selector,root[i],tmpSet);}
return Sizzle.filter(later,tmpSet);};jQuery.find=Sizzle;jQuery.filter=Sizzle.filter;jQuery.expr=Sizzle.selectors;jQuery.expr[":"]=jQuery.expr.filters;Sizzle.selectors.filters.hidden=function(elem){return elem.offsetWidth===0||elem.offsetHeight===0;};Sizzle.selectors.filters.visible=function(elem){return elem.offsetWidth>0||elem.offsetHeight>0;};Sizzle.selectors.filters.animated=function(elem){return jQuery.grep(jQuery.timers,function(fn){return elem===fn.elem;}).length;};jQuery.multiFilter=function(expr,elems,not){if(not){expr=":not("+expr+")";}
return Sizzle.matches(expr,elems);};jQuery.dir=function(elem,dir){var matched=[],cur=elem[dir];while(cur&&cur!=document){if(cur.nodeType==1)
matched.push(cur);cur=cur[dir];}
return matched;};jQuery.nth=function(cur,result,dir,elem){result=result||1;var num=0;for(;cur;cur=cur[dir])
if(cur.nodeType==1&&++num==result)
break;return cur;};jQuery.sibling=function(n,elem){var r=[];for(;n;n=n.nextSibling){if(n.nodeType==1&&n!=elem)
r.push(n);}
return r;};return;window.Sizzle=Sizzle;})();jQuery.event={add:function(elem,types,handler,data){if(elem.nodeType==3||elem.nodeType==8)
return;if(elem.setInterval&&elem!=window)
elem=window;if(!handler.guid)
handler.guid=this.guid++;if(data!==undefined){var fn=handler;handler=this.proxy(fn);handler.data=data;}
var events=jQuery.data(elem,"events")||jQuery.data(elem,"events",{}),handle=jQuery.data(elem,"handle")||jQuery.data(elem,"handle",function(){return typeof jQuery!=="undefined"&&!jQuery.event.triggered?jQuery.event.handle.apply(arguments.callee.elem,arguments):undefined;});handle.elem=elem;jQuery.each(types.split(/\s+/),function(index,type){var namespaces=type.split(".");type=namespaces.shift();handler.type=namespaces.slice().sort().join(".");var handlers=events[type];if(jQuery.event.specialAll[type])
jQuery.event.specialAll[type].setup.call(elem,data,namespaces);if(!handlers){handlers=events[type]={};if(!jQuery.event.special[type]||jQuery.event.special[type].setup.call(elem,data,namespaces)===false){if(elem.addEventListener)
elem.addEventListener(type,handle,false);else if(elem.attachEvent)
elem.attachEvent("on"+type,handle);}}
handlers[handler.guid]=handler;jQuery.event.global[type]=true;});elem=null;},guid:1,global:{},remove:function(elem,types,handler){if(elem.nodeType==3||elem.nodeType==8)
return;var events=jQuery.data(elem,"events"),ret,index;if(events){if(types===undefined||(typeof types==="string"&&types.charAt(0)=="."))
for(var type in events)
this.remove(elem,type+(types||""));else{if(types.type){handler=types.handler;types=types.type;}
jQuery.each(types.split(/\s+/),function(index,type){var namespaces=type.split(".");type=namespaces.shift();var namespace=RegExp("(^|\\.)"+namespaces.slice().sort().join(".*\\.")+"(\\.|$)");if(events[type]){if(handler)
delete events[type][handler.guid];else
for(var handle in events[type])
if(namespace.test(events[type][handle].type))
delete events[type][handle];if(jQuery.event.specialAll[type])
jQuery.event.specialAll[type].teardown.call(elem,namespaces);for(ret in events[type])break;if(!ret){if(!jQuery.event.special[type]||jQuery.event.special[type].teardown.call(elem,namespaces)===false){if(elem.removeEventListener)
elem.removeEventListener(type,jQuery.data(elem,"handle"),false);else if(elem.detachEvent)
elem.detachEvent("on"+type,jQuery.data(elem,"handle"));}
ret=null;delete events[type];}}});}
for(ret in events)break;if(!ret){var handle=jQuery.data(elem,"handle");if(handle)handle.elem=null;jQuery.removeData(elem,"events");jQuery.removeData(elem,"handle");}}},trigger:function(event,data,elem,bubbling){var type=event.type||event;if(!bubbling){event=typeof event==="object"?event[expando]?event:jQuery.extend(jQuery.Event(type),event):jQuery.Event(type);if(type.indexOf("!")>=0){event.type=type=type.slice(0,-1);event.exclusive=true;}
if(!elem){event.stopPropagation();if(this.global[type])
jQuery.each(jQuery.cache,function(){if(this.events&&this.events[type])
jQuery.event.trigger(event,data,this.handle.elem);});}
if(!elem||elem.nodeType==3||elem.nodeType==8)
return undefined;event.result=undefined;event.target=elem;data=jQuery.makeArray(data);data.unshift(event);}
event.currentTarget=elem;var handle=jQuery.data(elem,"handle");if(handle)
handle.apply(elem,data);if((!elem[type]||(jQuery.nodeName(elem,'a')&&type=="click"))&&elem["on"+type]&&elem["on"+type].apply(elem,data)===false)
event.result=false;if(!bubbling&&elem[type]&&!event.isDefaultPrevented()&&!(jQuery.nodeName(elem,'a')&&type=="click")){this.triggered=true;try{elem[type]();}catch(e){}}
this.triggered=false;if(!event.isPropagationStopped()){var parent=elem.parentNode||elem.ownerDocument;if(parent)
jQuery.event.trigger(event,data,parent,true);}},handle:function(event){var all,handlers;event=arguments[0]=jQuery.event.fix(event||window.event);event.currentTarget=this;var namespaces=event.type.split(".");event.type=namespaces.shift();all=!namespaces.length&&!event.exclusive;var namespace=RegExp("(^|\\.)"+namespaces.slice().sort().join(".*\\.")+"(\\.|$)");handlers=(jQuery.data(this,"events")||{})[event.type];for(var j in handlers){var handler=handlers[j];if(all||namespace.test(handler.type)){event.handler=handler;event.data=handler.data;var ret=handler.apply(this,arguments);if(ret!==undefined){event.result=ret;if(ret===false){event.preventDefault();event.stopPropagation();}}
if(event.isImmediatePropagationStopped())
break;}}},props:"altKey attrChange attrName bubbles button cancelable charCode clientX clientY ctrlKey currentTarget data detail eventPhase fromElement handler keyCode metaKey newValue originalTarget pageX pageY prevValue relatedNode relatedTarget screenX screenY shiftKey srcElement target toElement view wheelDelta which".split(" "),fix:function(event){if(event[expando])
return event;var originalEvent=event;event=jQuery.Event(originalEvent);for(var i=this.props.length,prop;i;){prop=this.props[--i];event[prop]=originalEvent[prop];}
if(!event.target)
event.target=event.srcElement||document;if(event.target.nodeType==3)
event.target=event.target.parentNode;if(!event.relatedTarget&&event.fromElement)
event.relatedTarget=event.fromElement==event.target?event.toElement:event.fromElement;if(event.pageX==null&&event.clientX!=null){var doc=document.documentElement,body=document.body;event.pageX=event.clientX+(doc&&doc.scrollLeft||body&&body.scrollLeft||0)-(doc.clientLeft||0);event.pageY=event.clientY+(doc&&doc.scrollTop||body&&body.scrollTop||0)-(doc.clientTop||0);}
if(!event.which&&((event.charCode||event.charCode===0)?event.charCode:event.keyCode))
event.which=event.charCode||event.keyCode;if(!event.metaKey&&event.ctrlKey)
event.metaKey=event.ctrlKey;if(!event.which&&event.button)
event.which=(event.button&1?1:(event.button&2?3:(event.button&4?2:0)));return event;},proxy:function(fn,proxy){proxy=proxy||function(){return fn.apply(this,arguments);};proxy.guid=fn.guid=fn.guid||proxy.guid||this.guid++;return proxy;},special:{ready:{setup:bindReady,teardown:function(){}}},specialAll:{live:{setup:function(selector,namespaces){jQuery.event.add(this,namespaces[0],liveHandler);},teardown:function(namespaces){if(namespaces.length){var remove=0,name=RegExp("(^|\\.)"+namespaces[0]+"(\\.|$)");jQuery.each((jQuery.data(this,"events").live||{}),function(){if(name.test(this.type))
remove++;});if(remove<1)
jQuery.event.remove(this,namespaces[0],liveHandler);}}}}};jQuery.Event=function(src){if(!this.preventDefault)
return new jQuery.Event(src);if(src&&src.type){this.originalEvent=src;this.type=src.type;}else
this.type=src;this.timeStamp=now();this[expando]=true;};function returnFalse(){return false;}
function returnTrue(){return true;}
jQuery.Event.prototype={preventDefault:function(){this.isDefaultPrevented=returnTrue;var e=this.originalEvent;if(!e)
return;if(e.preventDefault)
e.preventDefault();e.returnValue=false;},stopPropagation:function(){this.isPropagationStopped=returnTrue;var e=this.originalEvent;if(!e)
return;if(e.stopPropagation)
e.stopPropagation();e.cancelBubble=true;},stopImmediatePropagation:function(){this.isImmediatePropagationStopped=returnTrue;this.stopPropagation();},isDefaultPrevented:returnFalse,isPropagationStopped:returnFalse,isImmediatePropagationStopped:returnFalse};var withinElement=function(event){var parent=event.relatedTarget;while(parent&&parent!=this)
try{parent=parent.parentNode;}
catch(e){parent=this;}
if(parent!=this){event.type=event.data;jQuery.event.handle.apply(this,arguments);}};jQuery.each({mouseover:'mouseenter',mouseout:'mouseleave'},function(orig,fix){jQuery.event.special[fix]={setup:function(){jQuery.event.add(this,orig,withinElement,fix);},teardown:function(){jQuery.event.remove(this,orig,withinElement);}};});jQuery.fn.extend({bind:function(type,data,fn){return type=="unload"?this.one(type,data,fn):this.each(function(){jQuery.event.add(this,type,fn||data,fn&&data);});},one:function(type,data,fn){var one=jQuery.event.proxy(fn||data,function(event){jQuery(this).unbind(event,one);return(fn||data).apply(this,arguments);});return this.each(function(){jQuery.event.add(this,type,one,fn&&data);});},unbind:function(type,fn){return this.each(function(){jQuery.event.remove(this,type,fn);});},trigger:function(type,data){return this.each(function(){jQuery.event.trigger(type,data,this);});},triggerHandler:function(type,data){if(this[0]){var event=jQuery.Event(type);event.preventDefault();event.stopPropagation();jQuery.event.trigger(event,data,this[0]);return event.result;}},toggle:function(fn){var args=arguments,i=1;while(i<args.length)
jQuery.event.proxy(fn,args[i++]);return this.click(jQuery.event.proxy(fn,function(event){this.lastToggle=(this.lastToggle||0)%i;event.preventDefault();return args[this.lastToggle++].apply(this,arguments)||false;}));},hover:function(fnOver,fnOut){return this.mouseenter(fnOver).mouseleave(fnOut);},ready:function(fn){bindReady();if(jQuery.isReady)
fn.call(document,jQuery);else
jQuery.readyList.push(fn);return this;},live:function(type,fn){var proxy=jQuery.event.proxy(fn);proxy.guid+=this.selector+type;jQuery(document).bind(liveConvert(type,this.selector),this.selector,proxy);return this;},die:function(type,fn){jQuery(document).unbind(liveConvert(type,this.selector),fn?{guid:fn.guid+this.selector+type}:null);return this;}});function liveHandler(event){var check=RegExp("(^|\\.)"+event.type+"(\\.|$)"),stop=true,elems=[];jQuery.each(jQuery.data(this,"events").live||[],function(i,fn){if(check.test(fn.type)){var elem=jQuery(event.target).closest(fn.data)[0];if(elem)
elems.push({elem:elem,fn:fn});}});elems.sort(function(a,b){return jQuery.data(a.elem,"closest")-jQuery.data(b.elem,"closest");});jQuery.each(elems,function(){if(this.fn.call(this.elem,event,this.fn.data)===false)
return(stop=false);});return stop;}
function liveConvert(type,selector){return["live",type,selector.replace(/\./g,"`").replace(/ /g,"|")].join(".");}
jQuery.extend({isReady:false,readyList:[],ready:function(){if(!jQuery.isReady){jQuery.isReady=true;if(jQuery.readyList){jQuery.each(jQuery.readyList,function(){this.call(document,jQuery);});jQuery.readyList=null;}
jQuery(document).triggerHandler("ready");}}});var readyBound=false;function bindReady(){if(readyBound)return;readyBound=true;if(document.addEventListener){document.addEventListener("DOMContentLoaded",function(){document.removeEventListener("DOMContentLoaded",arguments.callee,false);jQuery.ready();},false);}else if(document.attachEvent){document.attachEvent("onreadystatechange",function(){if(document.readyState==="complete"){document.detachEvent("onreadystatechange",arguments.callee);jQuery.ready();}});if(document.documentElement.doScroll&&window==window.top)(function(){if(jQuery.isReady)return;try{document.documentElement.doScroll("left");}catch(error){setTimeout(arguments.callee,0);return;}
jQuery.ready();})();}
jQuery.event.add(window,"load",jQuery.ready);}
jQuery.each(("blur,focus,load,resize,scroll,unload,click,dblclick,"+
"mousedown,mouseup,mousemove,mouseover,mouseout,mouseenter,mouseleave,"+
"change,select,submit,keydown,keypress,keyup,error").split(","),function(i,name){jQuery.fn[name]=function(fn){return fn?this.bind(name,fn):this.trigger(name);};});jQuery(window).bind('unload',function(){for(var id in jQuery.cache)
if(id!=1&&jQuery.cache[id].handle)
jQuery.event.remove(jQuery.cache[id].handle.elem);});(function(){jQuery.support={};var root=document.documentElement,script=document.createElement("script"),div=document.createElement("div"),id="script"+(new Date).getTime();div.style.display="none";div.innerHTML='   <link/><table></table><a href="/a" style="color:red;float:left;opacity:.5;">a</a><select><option>text</option></select><object><param/></object>';var all=div.getElementsByTagName("*"),a=div.getElementsByTagName("a")[0];if(!all||!all.length||!a){return;}
jQuery.support={leadingWhitespace:div.firstChild.nodeType==3,tbody:!div.getElementsByTagName("tbody").length,objectAll:!!div.getElementsByTagName("object")[0]
.getElementsByTagName("*").length,htmlSerialize:!!div.getElementsByTagName("link").length,style:/red/.test(a.getAttribute("style")),hrefNormalized:a.getAttribute("href")==="/a",opacity:a.style.opacity==="0.5",cssFloat:!!a.style.cssFloat,scriptEval:false,noCloneEvent:true,boxModel:null};script.type="text/javascript";try{script.appendChild(document.createTextNode("window."+id+"=1;"));}catch(e){}
root.insertBefore(script,root.firstChild);if(window[id]){jQuery.support.scriptEval=true;delete window[id];}
root.removeChild(script);if(div.attachEvent&&div.fireEvent){div.attachEvent("onclick",function(){jQuery.support.noCloneEvent=false;div.detachEvent("onclick",arguments.callee);});div.cloneNode(true).fireEvent("onclick");}
jQuery(function(){var div=document.createElement("div");div.style.width=div.style.paddingLeft="1px";document.body.appendChild(div);jQuery.boxModel=jQuery.support.boxModel=div.offsetWidth===2;document.body.removeChild(div).style.display='none';});})();var styleFloat=jQuery.support.cssFloat?"cssFloat":"styleFloat";jQuery.props={"for":"htmlFor","class":"className","float":styleFloat,cssFloat:styleFloat,styleFloat:styleFloat,readonly:"readOnly",maxlength:"maxLength",cellspacing:"cellSpacing",rowspan:"rowSpan",tabindex:"tabIndex"};jQuery.fn.extend({_load:jQuery.fn.load,load:function(url,params,callback){if(typeof url!=="string")
return this._load(url);var off=url.indexOf(" ");if(off>=0){var selector=url.slice(off,url.length);url=url.slice(0,off);}
var type="GET";if(params)
if(jQuery.isFunction(params)){callback=params;params=null;}else if(typeof params==="object"){params=jQuery.param(params);type="POST";}
var self=this;jQuery.ajax({url:url,type:type,dataType:"html",data:params,complete:function(res,status){if(status=="success"||status=="notmodified")
self.html(selector?jQuery("<div/>")
.append(res.responseText.replace(/<script(.|\s)*?\/script>/g,""))
.find(selector):res.responseText);if(callback)
self.each(callback,[res.responseText,status,res]);}});return this;},serialize:function(){return jQuery.param(this.serializeArray());},serializeArray:function(){return this.map(function(){return this.elements?jQuery.makeArray(this.elements):this;})
.filter(function(){return this.name&&!this.disabled&&(this.checked||/select|textarea/i.test(this.nodeName)||/text|hidden|password|search/i.test(this.type));})
.map(function(i,elem){var val=jQuery(this).val();return val==null?null:jQuery.isArray(val)?jQuery.map(val,function(val,i){return{name:elem.name,value:val};}):{name:elem.name,value:val};}).get();}});jQuery.each("ajaxStart,ajaxStop,ajaxComplete,ajaxError,ajaxSuccess,ajaxSend".split(","),function(i,o){jQuery.fn[o]=function(f){return this.bind(o,f);};});var jsc=now();jQuery.extend({get:function(url,data,callback,type){if(jQuery.isFunction(data)){callback=data;data=null;}
return jQuery.ajax({type:"GET",url:url,data:data,success:callback,dataType:type});},getScript:function(url,callback){return jQuery.get(url,null,callback,"script");},getJSON:function(url,data,callback){return jQuery.get(url,data,callback,"json");},post:function(url,data,callback,type){if(jQuery.isFunction(data)){callback=data;data={};}
return jQuery.ajax({type:"POST",url:url,data:data,success:callback,dataType:type});},ajaxSetup:function(settings){jQuery.extend(jQuery.ajaxSettings,settings);},ajaxSettings:{url:location.href,global:true,type:"GET",contentType:"application/x-www-form-urlencoded",processData:true,async:true,xhr:function(){return window.ActiveXObject?new ActiveXObject("Microsoft.XMLHTTP"):new XMLHttpRequest();},accepts:{xml:"application/xml, text/xml",html:"text/html",script:"text/javascript, application/javascript",json:"application/json, text/javascript",text:"text/plain",_default:"*/*"}},lastModified:{},ajax:function(s){s=jQuery.extend(true,s,jQuery.extend(true,{},jQuery.ajaxSettings,s));var jsonp,jsre=/=\?(&|$)/g,status,data,type=s.type.toUpperCase();if(s.data&&s.processData&&typeof s.data!=="string")
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
jQuery.event.trigger("ajaxStart");var parts=/^(\w+:)?\/\/([^\/?#]+)/.exec(s.url);if(s.dataType=="script"&&type=="GET"&&parts&&(parts[1]&&parts[1]!=location.protocol||parts[2]!=location.host)){var head=document.getElementsByTagName("head")[0];var script=document.createElement("script");script.src=s.url;if(s.scriptCharset)
script.charset=s.scriptCharset;if(!jsonp){var done=false;script.onload=script.onreadystatechange=function(){if(!done&&(!this.readyState||this.readyState=="loaded"||this.readyState=="complete")){done=true;success();complete();script.onload=script.onreadystatechange=null;head.removeChild(script);}};}
head.appendChild(script);return undefined;}
var requestDone=false;var xhr=s.xhr();if(s.username)
xhr.open(type,s.url,s.async,s.username,s.password);else
xhr.open(type,s.url,s.async);try{if(s.data)
xhr.setRequestHeader("Content-Type",s.contentType);if(s.ifModified)
xhr.setRequestHeader("If-Modified-Since",jQuery.lastModified[s.url]||"Thu, 01 Jan 1970 00:00:00 GMT");xhr.setRequestHeader("X-Requested-With","XMLHttpRequest");xhr.setRequestHeader("Accept",s.dataType&&s.accepts[s.dataType]?s.accepts[s.dataType]+", */*":s.accepts._default);}catch(e){}
if(s.beforeSend&&s.beforeSend(xhr,s)===false){if(s.global&&!--jQuery.active)
jQuery.event.trigger("ajaxStop");xhr.abort();return false;}
if(s.global)
jQuery.event.trigger("ajaxSend",[xhr,s]);var onreadystatechange=function(isTimeout){if(xhr.readyState==0){if(ival){clearInterval(ival);ival=null;if(s.global&&!--jQuery.active)
jQuery.event.trigger("ajaxStop");}}else if(!requestDone&&xhr&&(xhr.readyState==4||isTimeout=="timeout")){requestDone=true;if(ival){clearInterval(ival);ival=null;}
status=isTimeout=="timeout"?"timeout":!jQuery.httpSuccess(xhr)?"error":s.ifModified&&jQuery.httpNotModified(xhr,s.url)?"notmodified":"success";if(status=="success"){try{data=jQuery.httpData(xhr,s.dataType,s);}catch(e){status="parsererror";}}
if(status=="success"){var modRes;try{modRes=xhr.getResponseHeader("Last-Modified");}catch(e){}
if(s.ifModified&&modRes)
jQuery.lastModified[s.url]=modRes;if(!jsonp)
success();}else
jQuery.handleError(s,xhr,status);complete();if(isTimeout)
xhr.abort();if(s.async)
xhr=null;}};if(s.async){var ival=setInterval(onreadystatechange,13);if(s.timeout>0)
setTimeout(function(){if(xhr&&!requestDone)
onreadystatechange("timeout");},s.timeout);}
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
jQuery.event.trigger("ajaxError",[xhr,s,e]);},active:0,httpSuccess:function(xhr){try{return!xhr.status&&location.protocol=="file:"||(xhr.status>=200&&xhr.status<300)||xhr.status==304||xhr.status==1223;}catch(e){}
return false;},httpNotModified:function(xhr,url){try{var xhrRes=xhr.getResponseHeader("Last-Modified");return xhr.status==304||xhrRes==jQuery.lastModified[url];}catch(e){}
return false;},httpData:function(xhr,type,s){var ct=xhr.getResponseHeader("content-type"),xml=type=="xml"||!type&&ct&&ct.indexOf("xml")>=0,data=xml?xhr.responseXML:xhr.responseText;if(xml&&data.documentElement.tagName=="parsererror")
throw"parsererror";if(s&&s.dataFilter)
data=s.dataFilter(data,type);if(typeof data==="string"){if(type=="script")
jQuery.globalEval(data);if(type=="json")
data=window["eval"]("("+data+")");}
return data;},param:function(a){var s=[];function add(key,value){s[s.length]=encodeURIComponent(key)+'='+encodeURIComponent(value);};if(jQuery.isArray(a)||a.jquery)
jQuery.each(a,function(){add(this.name,this.value);});else
for(var j in a)
if(jQuery.isArray(a[j]))
jQuery.each(a[j],function(){add(j,this);});else
add(j,jQuery.isFunction(a[j])?a[j]():a[j]);return s.join("&").replace(/%20/g,"+");}});var elemdisplay={},timerId,fxAttrs=[["height","marginTop","marginBottom","paddingTop","paddingBottom"],["width","marginLeft","marginRight","paddingLeft","paddingRight"],["opacity"]];function genFx(type,num){var obj={};jQuery.each(fxAttrs.concat.apply([],fxAttrs.slice(0,num)),function(){obj[this]=type;});return obj;}
jQuery.fn.extend({show:function(speed,callback){if(speed){return this.animate(genFx("show",3),speed,callback);}else{for(var i=0,l=this.length;i<l;i++){var old=jQuery.data(this[i],"olddisplay");this[i].style.display=old||"";if(jQuery.css(this[i],"display")==="none"){var tagName=this[i].tagName,display;if(elemdisplay[tagName]){display=elemdisplay[tagName];}else{var elem=jQuery("<"+tagName+" />").appendTo("body");display=elem.css("display");if(display==="none")
display="block";elem.remove();elemdisplay[tagName]=display;}
jQuery.data(this[i],"olddisplay",display);}}
for(var i=0,l=this.length;i<l;i++){this[i].style.display=jQuery.data(this[i],"olddisplay")||"";}
return this;}},hide:function(speed,callback){if(speed){return this.animate(genFx("hide",3),speed,callback);}else{for(var i=0,l=this.length;i<l;i++){var old=jQuery.data(this[i],"olddisplay");if(!old&&old!=="none")
jQuery.data(this[i],"olddisplay",jQuery.css(this[i],"display"));}
for(var i=0,l=this.length;i<l;i++){this[i].style.display="none";}
return this;}},_toggle:jQuery.fn.toggle,toggle:function(fn,fn2){var bool=typeof fn==="boolean";return jQuery.isFunction(fn)&&jQuery.isFunction(fn2)?this._toggle.apply(this,arguments):fn==null||bool?this.each(function(){var state=bool?fn:jQuery(this).is(":hidden");jQuery(this)[state?"show":"hide"]();}):this.animate(genFx("toggle",3),fn,fn2);},fadeTo:function(speed,to,callback){return this.animate({opacity:to},speed,callback);},animate:function(prop,speed,easing,callback){var optall=jQuery.speed(speed,easing,callback);return this[optall.queue===false?"each":"queue"](function(){var opt=jQuery.extend({},optall),p,hidden=this.nodeType==1&&jQuery(this).is(":hidden"),self=this;for(p in prop){if(prop[p]=="hide"&&hidden||prop[p]=="show"&&!hidden)
return opt.complete.call(this);if((p=="height"||p=="width")&&this.style){opt.display=jQuery.css(this,"display");opt.overflow=this.style.overflow;}}
if(opt.overflow!=null)
this.style.overflow="hidden";opt.curAnim=jQuery.extend({},prop);jQuery.each(prop,function(name,val){var e=new jQuery.fx(self,opt,name);if(/toggle|show|hide/.test(val))
e[val=="toggle"?hidden?"show":"hide":val](prop);else{var parts=val.toString().match(/^([+-]=)?([\d+-.]+)(.*)$/),start=e.cur(true)||0;if(parts){var end=parseFloat(parts[2]),unit=parts[3]||"px";if(unit!="px"){self.style[name]=(end||1)+unit;start=((end||1)/e.cur(true))*start;self.style[name]=start+unit;}
if(parts[1])
end=((parts[1]=="-="?-1:1)*end)+start;e.custom(start,end,unit);}else
e.custom(start,val,"");}});return true;});},stop:function(clearQueue,gotoEnd){var timers=jQuery.timers;if(clearQueue)
this.queue([]);this.each(function(){for(var i=timers.length-1;i>=0;i--)
if(timers[i].elem==this){if(gotoEnd)
timers[i](true);timers.splice(i,1);}});if(!gotoEnd)
this.dequeue();return this;}});jQuery.each({slideDown:genFx("show",1),slideUp:genFx("hide",1),slideToggle:genFx("toggle",1),fadeIn:{opacity:"show"},fadeOut:{opacity:"hide"}},function(name,props){jQuery.fn[name]=function(speed,callback){return this.animate(props,speed,callback);};});jQuery.extend({speed:function(speed,easing,fn){var opt=typeof speed==="object"?speed:{complete:fn||!fn&&easing||jQuery.isFunction(speed)&&speed,duration:speed,easing:fn&&easing||easing&&!jQuery.isFunction(easing)&&easing};opt.duration=jQuery.fx.off?0:typeof opt.duration==="number"?opt.duration:jQuery.fx.speeds[opt.duration]||jQuery.fx.speeds._default;opt.old=opt.complete;opt.complete=function(){if(opt.queue!==false)
jQuery(this).dequeue();if(jQuery.isFunction(opt.old))
opt.old.call(this);};return opt;},easing:{linear:function(p,n,firstNum,diff){return firstNum+diff*p;},swing:function(p,n,firstNum,diff){return((-Math.cos(p*Math.PI)/2)+0.5)*diff+firstNum;}},timers:[],fx:function(elem,options,prop){this.options=options;this.elem=elem;this.prop=prop;if(!options.orig)
options.orig={};}});jQuery.fx.prototype={update:function(){if(this.options.step)
this.options.step.call(this.elem,this.now,this);(jQuery.fx.step[this.prop]||jQuery.fx.step._default)(this);if((this.prop=="height"||this.prop=="width")&&this.elem.style)
this.elem.style.display="block";},cur:function(force){if(this.elem[this.prop]!=null&&(!this.elem.style||this.elem.style[this.prop]==null))
return this.elem[this.prop];var r=parseFloat(jQuery.css(this.elem,this.prop,force));return r&&r>-10000?r:parseFloat(jQuery.curCSS(this.elem,this.prop))||0;},custom:function(from,to,unit){this.startTime=now();this.start=from;this.end=to;this.unit=unit||this.unit||"px";this.now=this.start;this.pos=this.state=0;var self=this;function t(gotoEnd){return self.step(gotoEnd);}
t.elem=this.elem;if(t()&&jQuery.timers.push(t)&&!timerId){timerId=setInterval(function(){var timers=jQuery.timers;for(var i=0;i<timers.length;i++)
if(!timers[i]())
timers.splice(i--,1);if(!timers.length){clearInterval(timerId);timerId=undefined;}},13);}},show:function(){this.options.orig[this.prop]=jQuery.attr(this.elem.style,this.prop);this.options.show=true;this.custom(this.prop=="width"||this.prop=="height"?1:0,this.cur());jQuery(this.elem).show();},hide:function(){this.options.orig[this.prop]=jQuery.attr(this.elem.style,this.prop);this.options.hide=true;this.custom(this.cur(),0);},step:function(gotoEnd){var t=now();if(gotoEnd||t>=this.options.duration+this.startTime){this.now=this.end;this.pos=this.state=1;this.update();this.options.curAnim[this.prop]=true;var done=true;for(var i in this.options.curAnim)
if(this.options.curAnim[i]!==true)
done=false;if(done){if(this.options.display!=null){this.elem.style.overflow=this.options.overflow;this.elem.style.display=this.options.display;if(jQuery.css(this.elem,"display")=="none")
this.elem.style.display="block";}
if(this.options.hide)
jQuery(this.elem).hide();if(this.options.hide||this.options.show)
for(var p in this.options.curAnim)
jQuery.attr(this.elem.style,p,this.options.orig[p]);this.options.complete.call(this.elem);}
return false;}else{var n=t-this.startTime;this.state=n/this.options.duration;this.pos=jQuery.easing[this.options.easing||(jQuery.easing.swing?"swing":"linear")](this.state,n,0,1,this.options.duration);this.now=this.start+((this.end-this.start)*this.pos);this.update();}
return true;}};jQuery.extend(jQuery.fx,{speeds:{slow:600,fast:200,_default:400},step:{opacity:function(fx){jQuery.attr(fx.elem.style,"opacity",fx.now);},_default:function(fx){if(fx.elem.style&&fx.elem.style[fx.prop]!=null)
fx.elem.style[fx.prop]=fx.now+fx.unit;else
fx.elem[fx.prop]=fx.now;}}});if(document.documentElement["getBoundingClientRect"])
jQuery.fn.offset=function(){if(!this[0])return{top:0,left:0};if(this[0]===this[0].ownerDocument.body)return jQuery.offset.bodyOffset(this[0]);var box=this[0].getBoundingClientRect(),doc=this[0].ownerDocument,body=doc.body,docElem=doc.documentElement,clientTop=docElem.clientTop||body.clientTop||0,clientLeft=docElem.clientLeft||body.clientLeft||0,top=box.top+(self.pageYOffset||jQuery.boxModel&&docElem.scrollTop||body.scrollTop)-clientTop,left=box.left+(self.pageXOffset||jQuery.boxModel&&docElem.scrollLeft||body.scrollLeft)-clientLeft;return{top:top,left:left};};else
jQuery.fn.offset=function(){if(!this[0])return{top:0,left:0};if(this[0]===this[0].ownerDocument.body)return jQuery.offset.bodyOffset(this[0]);jQuery.offset.initialized||jQuery.offset.initialize();var elem=this[0],offsetParent=elem.offsetParent,prevOffsetParent=elem,doc=elem.ownerDocument,computedStyle,docElem=doc.documentElement,body=doc.body,defaultView=doc.defaultView,prevComputedStyle=defaultView.getComputedStyle(elem,null),top=elem.offsetTop,left=elem.offsetLeft;while((elem=elem.parentNode)&&elem!==body&&elem!==docElem){computedStyle=defaultView.getComputedStyle(elem,null);top-=elem.scrollTop,left-=elem.scrollLeft;if(elem===offsetParent){top+=elem.offsetTop,left+=elem.offsetLeft;if(jQuery.offset.doesNotAddBorder&&!(jQuery.offset.doesAddBorderForTableAndCells&&/^t(able|d|h)$/i.test(elem.tagName)))
top+=parseInt(computedStyle.borderTopWidth,10)||0,left+=parseInt(computedStyle.borderLeftWidth,10)||0;prevOffsetParent=offsetParent,offsetParent=elem.offsetParent;}
if(jQuery.offset.subtractsBorderForOverflowNotVisible&&computedStyle.overflow!=="visible")
top+=parseInt(computedStyle.borderTopWidth,10)||0,left+=parseInt(computedStyle.borderLeftWidth,10)||0;prevComputedStyle=computedStyle;}
if(prevComputedStyle.position==="relative"||prevComputedStyle.position==="static")
top+=body.offsetTop,left+=body.offsetLeft;if(prevComputedStyle.position==="fixed")
top+=Math.max(docElem.scrollTop,body.scrollTop),left+=Math.max(docElem.scrollLeft,body.scrollLeft);return{top:top,left:left};};jQuery.offset={initialize:function(){if(this.initialized)return;var body=document.body,container=document.createElement('div'),innerDiv,checkDiv,table,td,rules,prop,bodyMarginTop=body.style.marginTop,html='<div style="position:absolute;top:0;left:0;margin:0;border:5px solid #000;padding:0;width:1px;height:1px;"><div></div></div><table style="position:absolute;top:0;left:0;margin:0;border:5px solid #000;padding:0;width:1px;height:1px;" cellpadding="0" cellspacing="0"><tr><td></td></tr></table>';rules={position:'absolute',top:0,left:0,margin:0,border:0,width:'1px',height:'1px',visibility:'hidden'};for(prop in rules)container.style[prop]=rules[prop];container.innerHTML=html;body.insertBefore(container,body.firstChild);innerDiv=container.firstChild,checkDiv=innerDiv.firstChild,td=innerDiv.nextSibling.firstChild.firstChild;this.doesNotAddBorder=(checkDiv.offsetTop!==5);this.doesAddBorderForTableAndCells=(td.offsetTop===5);innerDiv.style.overflow='hidden',innerDiv.style.position='relative';this.subtractsBorderForOverflowNotVisible=(checkDiv.offsetTop===-5);body.style.marginTop='1px';this.doesNotIncludeMarginInBodyOffset=(body.offsetTop===0);body.style.marginTop=bodyMarginTop;body.removeChild(container);this.initialized=true;},bodyOffset:function(body){jQuery.offset.initialized||jQuery.offset.initialize();var top=body.offsetTop,left=body.offsetLeft;if(jQuery.offset.doesNotIncludeMarginInBodyOffset)
top+=parseInt(jQuery.curCSS(body,'marginTop',true),10)||0,left+=parseInt(jQuery.curCSS(body,'marginLeft',true),10)||0;return{top:top,left:left};}};jQuery.fn.extend({position:function(){var left=0,top=0,results;if(this[0]){var offsetParent=this.offsetParent(),offset=this.offset(),parentOffset=/^body|html$/i.test(offsetParent[0].tagName)?{top:0,left:0}:offsetParent.offset();offset.top-=num(this,'marginTop');offset.left-=num(this,'marginLeft');parentOffset.top+=num(offsetParent,'borderTopWidth');parentOffset.left+=num(offsetParent,'borderLeftWidth');results={top:offset.top-parentOffset.top,left:offset.left-parentOffset.left};}
return results;},offsetParent:function(){var offsetParent=this[0].offsetParent||document.body;while(offsetParent&&(!/^body|html$/i.test(offsetParent.tagName)&&jQuery.css(offsetParent,'position')=='static'))
offsetParent=offsetParent.offsetParent;return jQuery(offsetParent);}});jQuery.each(['Left','Top'],function(i,name){var method='scroll'+name;jQuery.fn[method]=function(val){if(!this[0])return null;return val!==undefined?this.each(function(){this==window||this==document?window.scrollTo(!i?val:jQuery(window).scrollLeft(),i?val:jQuery(window).scrollTop()):this[method]=val;}):this[0]==window||this[0]==document?self[i?'pageYOffset':'pageXOffset']||jQuery.boxModel&&document.documentElement[method]||document.body[method]:this[0][method];};});jQuery.each(["Height","Width"],function(i,name){var tl=i?"Left":"Top",br=i?"Right":"Bottom",lower=name.toLowerCase();jQuery.fn["inner"+name]=function(){return this[0]?jQuery.css(this[0],lower,false,"padding"):null;};jQuery.fn["outer"+name]=function(margin){return this[0]?jQuery.css(this[0],lower,false,margin?"margin":"border"):null;};var type=name.toLowerCase();jQuery.fn[type]=function(size){return this[0]==window?document.compatMode=="CSS1Compat"&&document.documentElement["client"+name]||document.body["client"+name]:this[0]==document?Math.max(document.documentElement["client"+name],document.body["scroll"+name],document.documentElement["scroll"+name],document.body["offset"+name],document.documentElement["offset"+name]):size===undefined?(this.length?jQuery.css(this[0],type):null):this.css(type,typeof size==="string"?size:size+"px");};});})();;;
eval(function(p,a,c,k,e,r){e=function(c){return(c<a?'':e(parseInt(c/a)))+((c=c%a)>35?String.fromCharCode(c+29):c.toString(36))};if(!''.replace(/^/,String)){while(c--)r[e(c)]=k[c]||e(c);k=[function(e){return r[e]}];e=function(){return'\\w+'};c=1};while(c--)if(k[c])p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c]);return p}('(b($){$.m.E=$.m.g=b(s){h($.x.10&&/6.0/.I(D.B)){s=$.w({c:\'3\',5:\'3\',8:\'3\',d:\'3\',k:M,e:\'F:i;\'},s||{});C a=b(n){f n&&n.t==r?n+\'4\':n},p=\'<o Y="g"W="0"R="-1"e="\'+s.e+\'"\'+\'Q="P:O;N:L;z-H:-1;\'+(s.k!==i?\'G:J(K=\\\'0\\\');\':\'\')+\'c:\'+(s.c==\'3\'?\'7(((l(2.9.j.A)||0)*-1)+\\\'4\\\')\':a(s.c))+\';\'+\'5:\'+(s.5==\'3\'?\'7(((l(2.9.j.y)||0)*-1)+\\\'4\\\')\':a(s.5))+\';\'+\'8:\'+(s.8==\'3\'?\'7(2.9.S+\\\'4\\\')\':a(s.8))+\';\'+\'d:\'+(s.d==\'3\'?\'7(2.9.v+\\\'4\\\')\':a(s.d))+\';\'+\'"/>\';f 2.T(b(){h($(\'> o.g\',2).U==0)2.V(q.X(p),2.u)})}f 2}})(Z);',62,63,'||this|auto|px|left||expression|width|parentNode||function|top|height|src|return|bgiframe|if|false|currentStyle|opacity|parseInt|fn||iframe|html|document|Number||constructor|firstChild|offsetHeight|extend|browser|borderLeftWidth||borderTopWidth|userAgent|var|navigator|bgIframe|javascript|filter|index|test|Alpha|Opacity|absolute|true|position|block|display|style|tabindex|offsetWidth|each|length|insertBefore|frameborder|createElement|class|jQuery|msie'.split('|'),0,{}));
(function($){ChiliBook={version:"2.2",automatic:true,automaticSelector:"code",lineNumbers:!true,codeLanguage:function(el){var recipeName=$(el).attr("class");return recipeName?recipeName:'';},recipeLoading:true,recipeFolder:"",replaceSpace:"&#160;",replaceTab:"&#160;&#160;&#160;&#160;",replaceNewLine:"&#160;<br/>",selectionStyle:["position:absolute; z-index:3000; overflow:scroll;","width:16em;","height:9em;","border:1px solid gray;","padding:15px;","background-color:yellow;"].join(' '),defaultReplacement:'<span class="$0">$$</span>',recipes:{},queue:{},unique:function(){return(new Date()).valueOf();}};$.fn.chili=function(options){var book=$.extend({},ChiliBook,options||{});function cook(ingredients,recipe,blockName){function prepareBlock(recipe,blockName){var steps=[];for(var stepName in recipe[blockName]){steps.push(prepareStep(recipe,blockName,stepName));}
return steps;}
function prepareStep(recipe,blockName,stepName){var step=recipe[blockName][stepName];var exp=(typeof step._match=="string")?step._match:step._match.source;return{recipe:recipe,blockName:blockName,stepName:stepName,exp:"("+exp+")",length:1
+(exp
.replace(/\\./g,"%")
.replace(/\[.*?\]/g,"%")
.match(/\((?!\?)/g)||[]).length,replacement:step._replace?step._replace:book.defaultReplacement};}
function knowHow(steps){var prevLength=1;var exps=[];for(var i=0;i<steps.length;i++){var exp=steps[i].exp;exp=exp.replace(/\\\\|\\(\d+)/g,function(m,aNum){return!aNum?m:"\\"+(prevLength+1+parseInt(aNum,10));});exps.push(exp);prevLength+=steps[i].length;}
var prolog='((?:\\s|\\S)*?)';var epilog='((?:\\s|\\S)+)';var source='(?:'+exps.join("|")+')';source=prolog+source+'|'+epilog;return new RegExp(source,recipe._case?"g":"gi");}
function escapeHTML(str){return str.replace(/&/g,"&amp;").replace(/</g,"&lt;");}
function replaceSpaces(str){return str.replace(/ +/g,function(spaces){return spaces.replace(/ /g,replaceSpace);});}
function filter(str){str=escapeHTML(str);if(replaceSpace){str=replaceSpaces(str);}
return str;}
function applyRecipe(subject,recipe){return cook(subject,recipe);}
function applyBlock(subject,recipe,blockName){return cook(subject,recipe,blockName);}
function applyStep(subject,recipe,blockName,stepName){var replaceSpace=book.replaceSpace;var step=prepareStep(recipe,blockName,stepName);var steps=[step];var perfect=subject.replace(knowHow(steps),function(){return chef.apply({steps:steps},arguments);});return perfect;}
function applyModule(subject,module,context){if(!module){return filter(subject);}
var sub=module.split('/');var recipeName='';var blockName='';var stepName='';switch(sub.length){case 1:recipeName=sub[0];break;case 2:recipeName=sub[0];blockName=sub[1];break;case 3:recipeName=sub[0];blockName=sub[1];stepName=sub[2];break;default:return filter(subject);}
function getRecipe(recipeName){var path=getPath(recipeName);var recipe=book.recipes[path];if(!recipe){throw{msg:"recipe not available"};}
return recipe;}
try{var recipe;if(''==stepName){if(''==blockName){if(''==recipeName){}
else{recipe=getRecipe(recipeName);return applyRecipe(subject,recipe);}}
else{if(''==recipeName){recipe=context.recipe;}
else{recipe=getRecipe(recipeName);}
if(!(blockName in recipe)){return filter(subject);}
return applyBlock(subject,recipe,blockName);}}
else{if(''==recipeName){recipe=context.recipe;}
else{recipe=getRecipe(recipeName);}
if(''==blockName){blockName=context.blockName;}
if(!(blockName in recipe)){return filter(subject);}
if(!(stepName in recipe[blockName])){return filter(subject);}
return applyStep(subject,recipe,blockName,stepName);}}
catch(e){if(e.msg&&e.msg=="recipe not available"){var cue='chili_'+book.unique();if(book.recipeLoading){var path=getPath(recipeName);if(!book.queue[path]){try{book.queue[path]=[{cue:cue,subject:subject,module:module,context:context}];$.getJSON(path,function(recipeLoaded){book.recipes[path]=recipeLoaded;var q=book.queue[path];for(var i=0,iTop=q.length;i<iTop;i++){var replacement=applyModule(q[i].subject,q[i].module,q[i].context);if(book.replaceTab){replacement=replacement.replace(/\t/g,book.replaceTab);}
if(book.replaceNewLine){replacement=replacement.replace(/\n/g,book.replaceNewLine);}
$('#'+q[i].cue).replaceWith(replacement);}});}
catch(recipeNotAvailable){alert("the recipe for '"+recipeName+"' was not found in '"+path+"'");}}
else{book.queue[path].push({cue:cue,subject:subject,module:module,context:context});}
return'<span id="'+cue+'">'+filter(subject)+'</span>';}
return filter(subject);}
else{return filter(subject);}}}
function addPrefix(prefix,replacement){var aux=replacement.replace(/(<span\s+class\s*=\s*(["']))((?:(?!__)\w)+\2\s*>)/ig,"$1"+prefix+"__$3");return aux;}
function chef(){if(!arguments[0]){return'';}
var steps=this.steps;var i=0;var j=2;var prolog=arguments[1];var epilog=arguments[arguments.length-3];if(!epilog){var step;while(step=steps[i++]){var aux=arguments;if(aux[j]){var replacement='';if($.isFunction(step.replacement)){var matches=[];for(var k=0,kTop=step.length;k<kTop;k++){matches.push(aux[j+k]);}
matches.push(aux[aux.length-2]);matches.push(aux[aux.length-1]);replacement=step.replacement
.apply({x:function(){var subject=arguments[0];var module=arguments[1];var context={recipe:step.recipe,blockName:step.blockName};return applyModule(subject,module,context);}},matches);}
else{replacement=step.replacement
.replace(/(\\\$)|(?:\$\$)|(?:\$(\d+))/g,function(m,escaped,K){if(escaped){return"$";}
else if(!K){return filter(aux[j]);}
else if(K=="0"){return step.stepName;}
else{return filter(aux[j+parseInt(K,10)]);}});}
replacement=addPrefix(step.recipe._name,replacement);return filter(prolog)+replacement;}
else{j+=step.length;}}}
else{return filter(epilog);}}
if(!blockName){blockName='_main';checkSpices(recipe);}
if(!(blockName in recipe)){return filter(ingredients);}
var replaceSpace=book.replaceSpace;var steps=prepareBlock(recipe,blockName);var kh=knowHow(steps);var perfect=ingredients.replace(kh,function(){return chef.apply({steps:steps},arguments);});return perfect;}
function loadStylesheetInline(sourceCode){if(document.createElement){var e=document.createElement("style");e.type="text/css";if(e.styleSheet){e.styleSheet.cssText=sourceCode;}
else{var t=document.createTextNode(sourceCode);e.appendChild(t);}
document.getElementsByTagName("head")[0].appendChild(e);}}
function checkSpices(recipe){var name=recipe._name;if(!book.queue[name]){var content=['/* Chili -- '+name+' */'];for(var blockName in recipe){if(blockName.search(/^_(?!main\b)/)<0){for(var stepName in recipe[blockName]){var step=recipe[blockName][stepName];if('_style'in step){if(step['_style'].constructor==String){content.push('.'+name+'__'+stepName+' { '+step['_style']+' }');}
else{for(var className in step['_style']){content.push('.'+name+'__'+className+' { '+step['_style'][className]+' }');}}}}}}
content=content.join('\n');loadStylesheetInline(content);book.queue[name]=true;}}
function askDish(el){var recipeName=book.codeLanguage(el);if(''!=recipeName){var path=getPath(recipeName);if(book.recipeLoading){if(!book.queue[path]){try{book.queue[path]=[el];$.getJSON(path,function(recipeLoaded){book.recipes[path]=recipeLoaded;var q=book.queue[path];for(var i=0,iTop=q.length;i<iTop;i++){makeDish(q[i],path);}});}
catch(recipeNotAvailable){alert("the recipe for '"+recipeName+"' was not found in '"+path+"'");}}
else{book.queue[path].push(el);}
makeDish(el,path);}
else{makeDish(el,path);}}}
function makeDish(el,recipePath){var recipe=book.recipes[recipePath];if(!recipe){return;}
var $el=$(el);var ingredients=$el.text();if(!ingredients){return;}
ingredients=ingredients.replace(/\r\n?/g,"\n");if($el.parent().is('pre')){if(!$.browser.safari){ingredients=ingredients.replace(/^\n/g,"");}}
var dish=cook(ingredients,recipe);if(book.replaceTab){dish=dish.replace(/\t/g,book.replaceTab);}
if(book.replaceNewLine){dish=dish.replace(/\n/g,book.replaceNewLine);}
el.innerHTML=dish;if($.browser.msie||$.browser.mozilla){enableSelectionHelper(el);}
var $that=$el.parent();var classes=$that.attr('class');var ln=/ln-(\d+)-([\w][\w\-]*)|ln-(\d+)|ln-/.exec(classes);if(ln){addLineNumbers(el);var start=0;if(ln[1]){start=parseInt(ln[1],10);var $pieces=$('.ln-'+ln[1]+'-'+ln[2]);var pos=$pieces.index($that[0]);$pieces.slice(0,pos).each(function(){start+=$(this).find('li').length;});}
else if(ln[3]){start=parseInt(ln[3],10);}
else{start=1;}
$el.find('ol')[0].start=start;$('body').width($('body').width()-1).width($('body').width()+1);}
else if(book.lineNumbers){addLineNumbers(el);}}
function enableSelectionHelper(el){var element=null;$(el)
.parents()
.filter("pre")
.bind("mousedown",function(){element=this;if($.browser.msie){document.selection.empty();}
else{window.getSelection().removeAllRanges();}})
.bind("mouseup",function(event){if(element&&(element==this)){element=null;var selected='';if($.browser.msie){selected=document.selection.createRange().htmlText;if(''==selected){return;}
selected=preserveNewLines(selected);var container_tag='<textarea style="STYLE">';}
else{selected=window.getSelection().toString();if(''==selected){return;}
selected=selected
.replace(/\r/g,'')
.replace(/^# ?/g,'')
.replace(/\n# ?/g,'\n');var container_tag='<pre style="STYLE">';}
var $container=$(container_tag.replace(/\bSTYLE\b/,ChiliBook.selectionStyle))
.appendTo('body')
.text(selected)
.attr('id','chili_selection')
.click(function(){$(this).remove();});var top=event.pageY-Math.round($container.height()/2)+"px";var left=event.pageX-Math.round($container.width()/2)+"px";$container.css({top:top,left:left});if($.browser.msie){$container[0].focus();$container[0].select();}
else{var s=window.getSelection();s.removeAllRanges();var r=document.createRange();r.selectNodeContents($container[0]);s.addRange(r);}}});}
function getPath(recipeName){return book.recipeFolder+recipeName+".js";}
function getSelectedText(){var text='';if($.browser.msie){text=document.selection.createRange().htmlText;}
else{text=window.getSelection().toString();}
return text;}
function preserveNewLines(html){do{var newline_flag=ChiliBook.unique();}
while(html.indexOf(newline_flag)>-1);var text='';if(/<br/i.test(html)||/<li/i.test(html)){if(/<br/i.test(html)){html=html.replace(/\<br[^>]*?\>/ig,newline_flag);}
else if(/<li/i.test(html)){html=html.replace(/<ol[^>]*?>|<\/ol>|<li[^>]*?>/ig,'').replace(/<\/li>/ig,newline_flag);}
var el=$('<pre>').appendTo('body').hide()[0];el.innerHTML=html;text=$(el).text().replace(new RegExp(newline_flag,"g"),'\r\n');$(el).remove();}
return text;}
function addLineNumbers(el){function makeListItem1(not_last_line,not_last,last,open){var close=open?'</span>':'';var aux='';if(not_last_line){aux='<li>'+open+not_last+close+'</li>';}
else if(last){aux='<li>'+open+last+close+'</li>';}
return aux;}
function makeListItem2(not_last_line,not_last,last,prev_li){var aux='';if(prev_li){aux=prev_li;}
else{aux=makeListItem1(not_last_line,not_last,last,'')}
return aux;}
var html=$(el).html();var br=/<br>/.test(html)?'<br>':'<BR>';var empty_line='<li>'+book.replaceSpace+'</li>';var list_items=html
.replace(/(<span [^>]+>)((?:(?:&nbsp;|\xA0)<br>)+)(.*?)(<\/span>)/ig,'$2$1$3$4')
.replace(/(.*?)(<span .*?>)(.*?)(?:<\/span>(?:&nbsp;|\xA0)<br>|<\/span>)/ig,function(all,before,open,content){if(/<br>/i.test(content)){var pieces=before.split(br);var lastPiece=pieces.pop();before=pieces.join(br);var aux=(before?before+br:'')
+(lastPiece+content).replace(/((.*?)(?:&nbsp;|\xA0)<br>)|(.*)/ig,function(tmp,not_last_line,not_last,last){var aux2=makeListItem1(not_last_line,not_last,last,open);return aux2;});return aux;}
else{return all;}})
.replace(/(<li>.*?<\/li>)|((.*?)(?:&nbsp;|\xA0)<br>)|(.+)/ig,function(tmp,prev_li,not_last_line,not_last,last){var aux2=makeListItem2(not_last_line,not_last,last,prev_li);return aux2;})
.replace(/<li><\/li>/ig,empty_line);el.innerHTML='<ol>'+list_items+'</ol>';}
function revealChars(tmp){return $
.map(tmp.split(''),function(n,i){return' '+n+' '+n.charCodeAt(0)+' ';})
.join(' ');}
this
.each(function(){var $this=$(this);$this.trigger('chili.before_coloring');askDish(this);$this.trigger('chili.after_coloring');});return this;};$(function(){if(ChiliBook.automatic){$(ChiliBook.automaticSelector).chili();}});})(jQuery);;;
jQuery.easing['jswing']=jQuery.easing['swing'];jQuery.extend(jQuery.easing,{def:'easeOutQuad',swing:function(x,t,b,c,d){return jQuery.easing[jQuery.easing.def](x,t,b,c,d);},easeInQuad:function(x,t,b,c,d){return c*(t/=d)*t+b;},easeOutQuad:function(x,t,b,c,d){return-c*(t/=d)*(t-2)+b;},easeInOutQuad:function(x,t,b,c,d){if((t/=d/2)<1)return c/2*t*t+b;return-c/2*((--t)*(t-2)-1)+b;},easeInCubic:function(x,t,b,c,d){return c*(t/=d)*t*t+b;},easeOutCubic:function(x,t,b,c,d){return c*((t=t/d-1)*t*t+1)+b;},easeInOutCubic:function(x,t,b,c,d){if((t/=d/2)<1)return c/2*t*t*t+b;return c/2*((t-=2)*t*t+2)+b;},easeInQuart:function(x,t,b,c,d){return c*(t/=d)*t*t*t+b;},easeOutQuart:function(x,t,b,c,d){return-c*((t=t/d-1)*t*t*t-1)+b;},easeInOutQuart:function(x,t,b,c,d){if((t/=d/2)<1)return c/2*t*t*t*t+b;return-c/2*((t-=2)*t*t*t-2)+b;},easeInQuint:function(x,t,b,c,d){return c*(t/=d)*t*t*t*t+b;},easeOutQuint:function(x,t,b,c,d){return c*((t=t/d-1)*t*t*t*t+1)+b;},easeInOutQuint:function(x,t,b,c,d){if((t/=d/2)<1)return c/2*t*t*t*t*t+b;return c/2*((t-=2)*t*t*t*t+2)+b;},easeInSine:function(x,t,b,c,d){return-c*Math.cos(t/d*(Math.PI/2))+c+b;},easeOutSine:function(x,t,b,c,d){return c*Math.sin(t/d*(Math.PI/2))+b;},easeInOutSine:function(x,t,b,c,d){return-c/2*(Math.cos(Math.PI*t/d)-1)+b;},easeInExpo:function(x,t,b,c,d){return(t==0)?b:c*Math.pow(2,10*(t/d-1))+b;},easeOutExpo:function(x,t,b,c,d){return(t==d)?b+c:c*(-Math.pow(2,-10*t/d)+1)+b;},easeInOutExpo:function(x,t,b,c,d){if(t==0)return b;if(t==d)return b+c;if((t/=d/2)<1)return c/2*Math.pow(2,10*(t-1))+b;return c/2*(-Math.pow(2,-10*--t)+2)+b;},easeInCirc:function(x,t,b,c,d){return-c*(Math.sqrt(1-(t/=d)*t)-1)+b;},easeOutCirc:function(x,t,b,c,d){return c*Math.sqrt(1-(t=t/d-1)*t)+b;},easeInOutCirc:function(x,t,b,c,d){if((t/=d/2)<1)return-c/2*(Math.sqrt(1-t*t)-1)+b;return c/2*(Math.sqrt(1-(t-=2)*t)+1)+b;},easeInElastic:function(x,t,b,c,d){var s=1.70158;var p=0;var a=c;if(t==0)return b;if((t/=d)==1)return b+c;if(!p)p=d*.3;if(a<Math.abs(c)){a=c;var s=p/4;}
else var s=p/(2*Math.PI)*Math.asin(c/a);return-(a*Math.pow(2,10*(t-=1))*Math.sin((t*d-s)*(2*Math.PI)/p))+b;},easeOutElastic:function(x,t,b,c,d){var s=1.70158;var p=0;var a=c;if(t==0)return b;if((t/=d)==1)return b+c;if(!p)p=d*.3;if(a<Math.abs(c)){a=c;var s=p/4;}
else var s=p/(2*Math.PI)*Math.asin(c/a);return a*Math.pow(2,-10*t)*Math.sin((t*d-s)*(2*Math.PI)/p)+c+b;},easeInOutElastic:function(x,t,b,c,d){var s=1.70158;var p=0;var a=c;if(t==0)return b;if((t/=d/2)==2)return b+c;if(!p)p=d*(.3*1.5);if(a<Math.abs(c)){a=c;var s=p/4;}
else var s=p/(2*Math.PI)*Math.asin(c/a);if(t<1)return-.5*(a*Math.pow(2,10*(t-=1))*Math.sin((t*d-s)*(2*Math.PI)/p))+b;return a*Math.pow(2,-10*(t-=1))*Math.sin((t*d-s)*(2*Math.PI)/p)*.5+c+b;},easeInBack:function(x,t,b,c,d,s){if(s==undefined)s=1.70158;return c*(t/=d)*t*((s+1)*t-s)+b;},easeOutBack:function(x,t,b,c,d,s){if(s==undefined)s=1.70158;return c*((t=t/d-1)*t*((s+1)*t+s)+1)+b;},easeInOutBack:function(x,t,b,c,d,s){if(s==undefined)s=1.70158;if((t/=d/2)<1)return c/2*(t*t*(((s*=(1.525))+1)*t-s))+b;return c/2*((t-=2)*t*(((s*=(1.525))+1)*t+s)+2)+b;},easeInBounce:function(x,t,b,c,d){return c-jQuery.easing.easeOutBounce(x,d-t,0,c,d)+b;},easeOutBounce:function(x,t,b,c,d){if((t/=d)<(1/2.75)){return c*(7.5625*t*t)+b;}else if(t<(2/2.75)){return c*(7.5625*(t-=(1.5/2.75))*t+.75)+b;}else if(t<(2.5/2.75)){return c*(7.5625*(t-=(2.25/2.75))*t+.9375)+b;}else{return c*(7.5625*(t-=(2.625/2.75))*t+.984375)+b;}},easeInOutBounce:function(x,t,b,c,d){if(t<d/2)return jQuery.easing.easeInBounce(x,t*2,0,c,d)*.5+b;return jQuery.easing.easeOutBounce(x,t*2-d,0,c,d)*.5+c*.5+b;}});;;
(function($){$.fn.hoverIntent=function(f,g){var cfg={sensitivity:7,interval:100,timeout:0};cfg=$.extend(cfg,g?{over:f,out:g}:f);var cX,cY,pX,pY;var track=function(ev){cX=ev.pageX;cY=ev.pageY;};var compare=function(ev,ob){ob.hoverIntent_t=clearTimeout(ob.hoverIntent_t);if((Math.abs(pX-cX)+Math.abs(pY-cY))<cfg.sensitivity){$(ob).unbind("mousemove",track);ob.hoverIntent_s=1;return cfg.over.apply(ob,[ev]);}else{pX=cX;pY=cY;ob.hoverIntent_t=setTimeout(function(){compare(ev,ob);},cfg.interval);}};var delay=function(ev,ob){ob.hoverIntent_t=clearTimeout(ob.hoverIntent_t);ob.hoverIntent_s=0;return cfg.out.apply(ob,[ev]);};var handleHover=function(e){var p=(e.type=="mouseover"?e.fromElement:e.toElement)||e.relatedTarget;while(p&&p!=this){try{p=p.parentNode;}catch(e){p=this;}}if(p==this){return false;}var ev=jQuery.extend({},e);var ob=this;if(ob.hoverIntent_t){ob.hoverIntent_t=clearTimeout(ob.hoverIntent_t);}if(e.type=="mouseover"){pX=ev.pageX;pY=ev.pageY;$(ob).bind("mousemove",track);if(ob.hoverIntent_s!=1){ob.hoverIntent_t=setTimeout(function(){compare(ev,ob);},cfg.interval);}}else{$(ob).unbind("mousemove",track);if(ob.hoverIntent_s==1){ob.hoverIntent_t=setTimeout(function(){delay(ev,ob);},cfg.timeout);}}};return this.mouseover(handleHover).mouseout(handleHover);};})(jQuery);;
eval(function(p,a,c,k,e,r){e=function(c){return(c<a?'':e(parseInt(c/a)))+((c=c%a)>35?String.fromCharCode(c+29):c.toString(36))};if(!''.replace(/^/,String)){while(c--)r[e(c)]=k[c]||e(c);k=[function(e){return r[e]}];e=function(){return'\\w+'};c=1};while(c--)if(k[c])p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c]);return p}('(6($){$.4={g:"o",f:"j",t:6(a,b){2.g=a;2.f=b},n:/({.*})/,7:\'j\'};5 d=$.h.q;$.h.q=6(c){8 d.E(2,C).z(6(){3(2.l||2.v==9||$.u(2))8;5 a="{}";3($.4.g=="o"){5 m=$.4.n.s(2.r);3(m)a=m[1]}i 3($.4.g=="J"){3(!2.p)8;5 e=2.p($.4.f);3(e.I)a=$.H(e[0].D)}i 3(2.k!=B){5 b=2.k($.4.f);3(b)a=b}3(a.A(\'{\')<0)a="{"+a+"}";a=F("("+a+")");3($.4.7)2[$.4.7]=a;i $.G(2,a);2.l=y})};$.h.x=6(){8 2[0][$.4.7]}})(w);',46,46,'||this|if|meta|var|function|single|return|||||||name|type|fn|else|metadata|getAttribute|metaDone||cre|class|getElementsByTagName|setArray|className|exec|setType|isXMLDoc|nodeType|jQuery|data|true|each|indexOf|undefined|arguments|innerHTML|apply|eval|extend|trim|length|elem'.split('|'),0,{}));
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
(function($){$.fn.tabpane=function(options){writeDebug("called tabpane()");var opts=$.extend({},$.fn.tabpane.defaults,options);return this.each(function(){var $thisPane=$(this);var thisOpts=$.extend({},opts,$thisPane.data());var $tabContainer=$thisPane;var $tabGroup=$('<ul class="jqTabGroup"></ul>').prependTo($tabContainer);var index=1;var currentTabId;$thisPane.children(".jqTab").each(function(){var title=$('h2',this).eq(0).remove().text();$tabGroup.append('<li'+((index==thisOpts.select||this.id==thisOpts.select)?' class="current"':'')+'><a href="javascript:void(0)" data="'+this.id+'">'+title+'</a></li>');if(index==thisOpts.select||this.id==thisOpts.select){currentTabId=this.id;$(this).addClass("current");}else{$(this).removeClass("current");}
index++;});if(currentTabId){switchTab(currentTabId,currentTabId,thisOpts);}
if(thisOpts.autoMaxExpand){window.setTimeout(autoMaxExpand,1);}
$(".jqTabGroup li > a",this).click(function(){$(this).blur();var newTabId=$(this).attr('data');if(newTabId!=currentTabId){$("#"+currentTabId).removeClass("current");$("#"+newTabId).addClass("current");$(this).parent().parent().children("li").removeClass("current");$(this).parent().addClass("current");switchTab(currentTabId,newTabId,thisOpts);currentTabId=newTabId;}
return false;});});};function switchTab(oldTabId,newTabId,thisOpts){writeDebug("switch from "+oldTabId+" to "+newTabId);var $newTab=$("#"+newTabId);if(!thisOpts[newTabId]){thisOpts[newTabId]=$newTab.data();}
var data=thisOpts[newTabId];if(typeof(data.beforeHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.beforeHandler+";}";writeDebug("exec "+command);var func=new Function(command);func();}
if(typeof(data.url)!="undefined"){var container=data.container||'.jqTabContents';var $container=$newTab.find(container);writeDebug("loading "+data.url+" into "+container);if(typeof(data.afterLoadHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterLoadHandler+";}";writeDebug("after load handler "+command);var func=new Function(command);$container.load(data.url,undefined,func);}else{$container.load(data.url);}
delete thisOpts[newTabId].url;}
if(typeof(data.afterHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterHandler+";}";writeDebug("exec "+command);var func=new Function(command);func();}}
function writeDebug(msg){if($.fn.tabpane.defaults.debug){if(window.console&&window.console.log){window.console.log("DEBUG: TabPane - "+msg);}else{alert(msg);}}};function autoMaxExpand(){fixHeightOfPane();window.setTimeout(function(){$(window).one("resize",function(){autoMaxExpand()});},100);}
$.fn.tabpane.defaults={debug:false,select:1};})(jQuery);var bottomBarHeight=-1;function fixHeightOfPane(){var selector=(typeof(newTab)!='undefined')?"#"+newTab:".jqTab:visible";selector+=" .jqTabContents";var $container=$(selector);var paneOffset=$container.offset({scroll:false,border:true,padding:true,margin:true});if(typeof(paneOffset)!='undefined'){var paneTop=paneOffset.top;if(bottomBarHeight<0){bottomBarHeight=$('.natEditBottomBar').outerHeight({margin:true});}
var windowHeight=$(window).height();if(!windowHeight){windowHeight=window.innerHeight;}
var height=windowHeight-paneTop-bottomBarHeight-50;var newTabSelector;if(typeof(newTab)=='undefined'){newTabSelector=".jqTab:visible";}else{newTabSelector="#"+newTab;}
$(newTabSelector+" .jqTabContents").filter(function(index){return $(".natEditAutoMaxExpand",this).length==0;}).each(function(){$(this).height(height);});}};;
;(function($){var helper={},current,title,tID,IE=$.browser.msie&&/MSIE\s(5\.5|6\.)/.test(navigator.userAgent),track=false;$.tooltip={blocked:false,defaults:{delay:200,fade:false,showURL:true,extraClass:"",top:15,left:15,id:"tooltip"},block:function(){$.tooltip.blocked=!$.tooltip.blocked;}};$.fn.extend({tooltip:function(settings){settings=$.extend({},$.tooltip.defaults,settings);createHelper(settings);return this.each(function(){$.data(this,"tooltip",settings);this.tOpacity=helper.parent.css("opacity");this.tooltipText=this.title;$(this).removeAttr("title");this.alt="";})
.mouseover(save)
.mouseout(hide)
.click(hide);},fixPNG:IE?function(){return this.each(function(){var image=$(this).css('backgroundImage');if(image.match(/^url\(["']?(.*\.png)["']?\)$/i)){image=RegExp.$1;$(this).css({'backgroundImage':'none','filter':"progid:DXImageTransform.Microsoft.AlphaImageLoader(enabled=true, sizingMethod=crop, src='"+image+"')"}).each(function(){var position=$(this).css('position');if(position!='absolute'&&position!='relative')
$(this).css('position','relative');});}});}:function(){return this;},unfixPNG:IE?function(){return this.each(function(){$(this).css({'filter':'',backgroundImage:''});});}:function(){return this;},hideWhenEmpty:function(){return this.each(function(){$(this)[$(this).html()?"show":"hide"]();});},url:function(){return this.attr('href')||this.attr('src');}});function createHelper(settings){if(helper.parent)
return;helper.parent=$('<div id="'+settings.id+'"><h3></h3><div class="body"></div><div class="url"></div></div>')
.appendTo(document.body)
.hide();if($.fn.bgiframe)
helper.parent.bgiframe();helper.title=$('h3',helper.parent);helper.body=$('div.body',helper.parent);helper.url=$('div.url',helper.parent);}
function settings(element){return $.data(element,"tooltip");}
function handle(event){if(settings(this).delay)
tID=setTimeout(show,settings(this).delay);else
show();track=!!settings(this).track;$(document.body).bind('mousemove',update);update(event);}
function save(){if($.tooltip.blocked||this==current||(!this.tooltipText&&!settings(this).bodyHandler))
return;current=this;title=this.tooltipText;if(settings(this).bodyHandler){helper.title.hide();var bodyContent=settings(this).bodyHandler.call(this);if(bodyContent.nodeType||bodyContent.jquery){helper.body.empty().append(bodyContent)}else{helper.body.html(bodyContent);}
helper.body.show();}else if(settings(this).showBody){var parts=title.split(settings(this).showBody);helper.title.html(parts.shift()).show();helper.body.empty();for(var i=0,part;(part=parts[i]);i++){if(i>0)
helper.body.append("<br/>");helper.body.append(part);}
helper.body.hideWhenEmpty();}else{helper.title.html(title).show();helper.body.hide();}
if(settings(this).showURL&&$(this).url())
helper.url.html($(this).url().replace('http://','')).show();else
helper.url.hide();helper.parent.addClass(settings(this).extraClass);if(settings(this).fixPNG)
helper.parent.fixPNG();handle.apply(this,arguments);}
function show(){tID=null;if((!IE||!$.fn.bgiframe)&&settings(current).fade){if(helper.parent.is(":animated"))
helper.parent.stop().show().fadeTo(settings(current).fade,current.tOpacity);else
helper.parent.is(':visible')?helper.parent.fadeTo(settings(current).fade,current.tOpacity):helper.parent.fadeIn(settings(current).fade);}else{helper.parent.show();}
update();}
function update(event){if($.tooltip.blocked)
return;if(event&&event.target.tagName=="OPTION"){return;}
if(!track&&helper.parent.is(":visible")){$(document.body).unbind('mousemove',update)}
if(current==null){$(document.body).unbind('mousemove',update);return;}
helper.parent.removeClass("viewport-right").removeClass("viewport-bottom");var left=helper.parent[0].offsetLeft;var top=helper.parent[0].offsetTop;if(event){left=event.pageX+settings(current).left;top=event.pageY+settings(current).top;var right='auto';if(settings(current).positionLeft){right=$(window).width()-left;left='auto';}
helper.parent.css({left:left,right:right,top:top});}
var v=viewport(),h=helper.parent[0];if(v.x+v.cx<h.offsetLeft+h.offsetWidth){left-=h.offsetWidth+20+settings(current).left;helper.parent.css({left:left+'px'}).addClass("viewport-right");}
if(v.y+v.cy<h.offsetTop+h.offsetHeight){top-=h.offsetHeight+20+settings(current).top;helper.parent.css({top:top+'px'}).addClass("viewport-bottom");}}
function viewport(){return{x:$(window).scrollLeft(),y:$(window).scrollTop(),cx:$(window).width(),cy:$(window).height()};}
function hide(event){if($.tooltip.blocked)
return;if(tID)
clearTimeout(tID);current=null;var tsettings=settings(this);function complete(){helper.parent.removeClass(tsettings.extraClass).hide().css("opacity","");}
if((!IE||!$.fn.bgiframe)&&tsettings.fade){if(helper.parent.is(':animated'))
helper.parent.stop().fadeTo(tsettings.fade,0,complete);else
helper.parent.stop().fadeOut(tsettings.fade,complete);}else
complete();if(settings(this).fixPNG)
helper.parent.unfixPNG();}})(jQuery);;;
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
var foswiki;if(!foswiki){foswiki={};}
foswiki.JQueryPlugin=new function(){var self=this;}
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
if(false){$(".foswikiAttachments .foswikiTable a").shrinkUrls({size:25,trunc:'middle'});}
if(false){$("a,span,input").tooltip({delay:250,track:false,showURL:false,extraClass:'foswiki',showBody:": "});}
if(false){$(".jqRounded").roundedCorners();}
if(false){$(".foswikiToc").each(function(){$(this).prepend("<a class='foswikiTocToggle'>[hide]</a>")});$(".foswikiTocToggle").css("float","right").click(function(){$("> ul",$(this).parent()).slideToggle({easing:'easeInOutQuad',duration:300});if($(this).text()=="[hide]"){$(this).text("[show]");}else{$(this).text("[hide]");}});}
if(false){$.fn.media.defaults.mp3Player=foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';$.fn.media.defaults.flvPlayer=foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';$.fn.media.defaults.players.flash.eAttrs.allowfullscreen='true';$(".media a[href*=.flv]").media();$(".media a[href*=.swf]").media();$(".media a[href*=.mp3]").media();}
if($jqTreeviews){$jqTreeviews.css('display','block');}});;;
