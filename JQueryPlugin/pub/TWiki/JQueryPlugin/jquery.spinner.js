(function($){function log(msg)
{if($.log)
{$.log(msg);}}
$.fn.spinner=function(options){var opts=$.extend({},$.fn.spinner.defaults,options);return this.each(function(){$this=$(this);if(typeof options=="string"){if(options=="stop")
{var o=$.data(this,"spinner");if(o.intervalId)
{log("stop "+this.id);clearInterval(o.intervalId);o.intervalId=undefined;$.data(this,"spinner",o);}
return;}
else if(options=="redraw")
{var o=$.data(this,"spinner");log("redraw "+this.id);log(o);if(o.frame>=o.frames){o.frame=1;}
pos="-"+(o.frame*o.width)+"px 0px";$this.css("background-position",pos);o.frame=o.frame+1;$.data(this,"spinner",o);return;}}
var o=$.extend({},opts,$.data(this,"spinner"));log("dump "+this.id);log(o);if(o.intervalId)
{$this.spinner('stop');}
if(o.height){$this.height(o.height);}
if(o.width){$this.width(o.width);}
$this.css("background-image","url("+o.image+")");$this.css("background-position","0px 0px");$this.css("background-repeat","no-repeat");img=new Image();img.src=o.image;img.onload=function(){log("image.onload "+this.id);o.frames=img.width/o.width;log(o);$.data(this,"spinner",o);};if(!o.speed){o.speed=25;}
log("start "+this.id);o.frame=0;o.intervalId=setInterval("$('#"+this.id+"').spinner('redraw')",o.speed);$.data(this,"spinner",o);});};$.fn.spinner.defaults={height:32,width:32,speed:50,frame:0,frames:31,intervalId:0};})(jQuery);;
