(function($){ChiliBook={version:"2.2"
,automatic:true,automaticSelector:"code",lineNumbers:!true,codeLanguage:function(el){var recipeName=$(el).attr("class");return recipeName?recipeName:'';},recipeLoading:true,recipeFolder:""
,replaceSpace:"&#160;",replaceTab:"&#160;&#160;&#160;&#160;",replaceNewLine:"&#160;<br/>",selectionStyle:["position:absolute; z-index:3000; overflow:scroll;","width:16em;","height:9em;","border:1px solid gray;","padding:15px;","background-color:yellow;"].join(' ')
,defaultReplacement:'<span class="$0">$$</span>',recipes:{},queue:{},unique:function(){return(new Date()).valueOf();}};$.fn.chili=function(options){var book=$.extend({},ChiliBook,options||{});function cook(ingredients,recipe,blockName){function prepareBlock(recipe,blockName){var steps=[];for(var stepName in recipe[blockName]){steps.push(prepareStep(recipe,blockName,stepName));}
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
.each(function(){var $this=$(this);$this.trigger('chili.before_coloring');askDish(this);$this.trigger('chili.after_coloring');});return this;};})(jQuery);