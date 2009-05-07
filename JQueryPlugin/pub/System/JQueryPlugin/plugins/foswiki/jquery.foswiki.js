var foswiki;if(typeof(foswiki)=="undefined"){foswiki={};}
(function($){$("head meta[name^='foswiki.']").each(function(){foswiki[this.name.substr(8)]=this.content;});$.log=function(message){};$.fn.debug=function(){};})(jQuery);;
