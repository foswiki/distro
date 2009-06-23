var foswiki;if(typeof(foswiki)=="undefined"){foswiki={};}
(function($){$("head meta[name^='foswiki.']").each(function(){var val=this.content;if(val=="false"){val=false;}else if(val=="true"){val=true;}
foswiki[this.name.substr(8)]=val;});$.log=function(message){};$.fn.debug=function(){};})(jQuery);;
