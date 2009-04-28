var DEBUG=true;if(!("console"in window)||!("firebug"in console)){var names=["log","debug","info","warn","error","assert","dir","dirxml","group","groupEnd","time","timeEnd","count","trace","profile","profileEnd"];jQuery(document).ready(function(){$(document.body).append('<div id="DEBUG"><ol></ol></div>');});window.console={};for(var i=0;i<names.length;++i){window.console[names[i]]=function(msg){$('#DEBUG ol').append('<li>'+msg+'</li>');}}}
jQuery.fn.debug=function(){return this.each(function(){$.log(this);});};jQuery.log=function(message){if(window.DEBUG){var str=message;if(!('firebug'in console)){if(typeof(message)=='object'){if(message.nodeName)
{str='&lt;';str+=message.nodeName.toLowerCase();for(var i=0;i<message.attributes.length;i++){str+=' '+message.attributes[i].nodeName.toLowerCase()+'="'+message.attributes[i].nodeValue+'"';}
str+='&gt;';}
else
{for(var key in message){str+=key+" : "+(message[key])+", ";}}}}}
console.debug(str);};;
