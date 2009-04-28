$.wikiword={build:function(source,options){$.wikiword.writeDebug("called wikiword()");var opts=$.extend({},$.fn.wikiword.defaults,options);var $source=$(source);return this.each(function(){var $this=$(this);var thisOpts=$.meta?$.extend({},opts,$this.data()):opts;$source.change(function(){$.wikiword.handleChange($source,$this,thisOpts);}).keyup(function(){$.wikiword.handleChange($source,$this,thisOpts);}).change();});},handleChange:function(source,target,thisOpts){var result='';source.each(function(){result+=$(this).is(':input')?$(this).val():$(this).text();});if(result||!thisOpts.initial){result=$.wikiword.wikify(result);if(thisOpts.suffix){result+=thisOpts.suffix;}
if(thisOpts.prefix){result=thisOpts.prefix+result;}}else{result=thisOpts.initial;}
$.wikiword.writeDebug("result="+result);target.each(function(){$(this).is(':input')?$(this).val(result):$(this).text(result);});},wikify:function(source){var result='';var chVal=0;for(var i=0;i<source.length;i++){chVal=source.charCodeAt(i);if(chVal==192||chVal==193||chVal==194||chVal==195){ch='A';}
else if(chVal==196){result+='Ae';}
else if(chVal==197){result+='Aa';}
else if(chVal==198){result+='Ae';}
else if(chVal==199){result+='C';}
else if(chVal==200||chVal==201||chVal==202||chVal==203){result+='E';}
else if(chVal==204||chVal==205||chVal==206||chVal==207){result+='I';}
else if(chVal==208){result+='d';}
else if(chVal==209){result+='N';}
else if(chVal==210||chVal==211||chVal==212||chVal==213){result+='O';}
else if(chVal==214){result+='Oe';}
else if(chVal==216){result+='Oe';}
else if(chVal==217||chVal==218||chVal==219){result+='U';}
else if(chVal==220){result+='Ue';}
else if(chVal==221){result+='Y';}
else if(chVal==222){result+='P';}
else if(chVal==223){result+='ss';}
else if(chVal==224||chVal==225||chVal==226||chVal==227){result+='a';}
else if(chVal==228){result+='ae';}
else if(chVal==229){result+='aa';}
else if(chVal==230){result+='ae';}
else if(chVal==231){result+='c';}
else if(chVal==232||chVal==233||chVal==234||chVal==235){result+='e';}
else if(chVal==236||chVal==237||chVal==238||chVal==239){result+='i';}
else if(chVal==240){result+='d';}
else if(chVal==241){result+='n';}
else if(chVal==242||chVal==243||chVal==244||chVal==245){result+='o';}
else if(chVal==246){result+='oe';}
else if(chVal==248){result+='oe';}
else if(chVal==249||chVal==250||chVal==251){result+='u';}
else if(chVal==252){result+='ue';}
else if(chVal==253){result+='y';}
else if(chVal==254){result+='p';}
else if(chVal==255){result+='y';}
else{result+=String.fromCharCode(chVal);}}
result=result.replace(/[a-zA-Z\d]+/g,function(a){return a.charAt(0).toLocaleUpperCase()+a.substr(1);});result=result.replace(/[^a-zA-Z\d]/g,"");result=result.replace(/\s/g,"");return result;},writeDebug:function(msg){if($.wikiword.defaults.debug){if(window.console&&window.console.log){window.console.log("DEBUG: wikiword - "+msg);}else{}}},defaults:{debug:false,suffix:'',prefix:'',initial:''}};$(function(){$.fn.wikiword=$.wikiword.build;});;
