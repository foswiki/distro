var foswiki;if(typeof(foswiki)=="undefined"){foswiki={};}
(function($){$(function(){$("head meta[name^='foswiki.']").each(function(){foswiki[this.name.substr(8)]=this.content;});var $jqTreeviews;if(true){$jqTreeviews=$(".jqTreeview");$jqTreeviews.children("> ul").each(function(){var args=Array();var parentClass=$(this).parent().attr('class');if(parentClass.match(/\bopen\b/)){args['collapsed']=false;}
if(parentClass.match(/\bclosed?\b/)){args['collapsed']=true;}
if(parentClass.match(/\bunique\b/)){args['unique']=true;}
if(parentClass.match(/\bprerendered\b/)){args['prerendered']=true;}
args['animated']='fast';if(parentClass.match(/\bspeed_(fast|slow|normal|none|[\d\.]+)\b/)){var speed=RegExp.$1;if(speed=="none"){delete args['animated'];}else{args['animated']=speed;}}
$(this).treeview(args);});}
if(false){$(".foswikiAttachments .foswikiTable a").shrinkUrls({size:25,trunc:'middle'});}
if(false){$.fn.media.defaults.mp3Player=foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';$.fn.media.defaults.flvPlayer=foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';$.fn.media.defaults.players.flash.eAttrs.allowfullscreen='true';$(".media a[href*=.flv]").media();$(".media a[href*=.swf]").media();$(".media a[href*=.mp3]").media();}
if(typeof ChiliBook!="undefined"){ChiliBook.recipeFolder=foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/chili/recipes/';ChiliBook.automaticSelector='pre';}
if($jqTreeviews){$jqTreeviews.css('display','block');}});})(jQuery);;
