var foswiki;if(typeof(foswiki)=="undefined"){foswiki={};}
(function($){$.log=function(message){};$.fn.debug=function(){};function createMember(obj,keys,val){var key=keys.shift();if(keys.length>0){if(typeof(obj[key])=='undefined'){obj[key]={};}
createMember(obj[key],keys,val);}else{obj[key]=val;}}
$(function(){$("head meta[name^='foswiki.']").each(function(){var val=this.content;if(val=="false"){val=false;}else if(val=="true"){val=true;}else if(val.match(/^function/)){val=eval("("+val+")");}
var keys=this.name.split(/\./);keys.shift();createMember(foswiki,keys,val);});});})(jQuery);;
