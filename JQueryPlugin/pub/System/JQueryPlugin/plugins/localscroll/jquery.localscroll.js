;(function($){var URI=location.href.replace(/#.*/,'');var $localScroll=$.localScroll=function(settings){$('body').localScroll(settings);};$localScroll.defaults={duration:1000,axis:'y',event:'click',stop:true,target:window,reset:true
};$localScroll.hash=function(settings){if(location.hash){settings=$.extend({},$localScroll.defaults,settings);settings.hash=false;if(settings.reset){var d=settings.duration;delete settings.duration;$(settings.target).scrollTo(0,settings);settings.duration=d;}
scroll(0,location,settings);}};$.fn.localScroll=function(settings){settings=$.extend({},$localScroll.defaults,settings);return settings.lazy?this.bind(settings.event,function(e){var a=$([e.target,e.target.parentNode]).filter(filter)[0];if(a)
scroll(e,a,settings);}):this.find('a,area')
.filter(filter).bind(settings.event,function(e){scroll(e,this,settings);}).end()
.end();function filter(){return!!this.href&&!!this.hash&&this.href.replace(this.hash,'')==URI&&(!settings.filter||$(this).is(settings.filter));};};function scroll(e,link,settings){var id=link.hash.slice(1),elem=document.getElementById(id)||document.getElementsByName(id)[0];if(!elem)
return;if(e)
e.preventDefault();var $target=$(settings.target);if(settings.lock&&$target.is(':animated')||settings.onBefore&&settings.onBefore.call(settings,e,elem,$target)===false)
return;if(settings.stop)
$target.stop(true);if(settings.hash){var attr=elem.id==id?'id':'name',$a=$('<a> </a>').attr(attr,id).css({position:'absolute',top:$(window).scrollTop(),left:$(window).scrollLeft()});elem[attr]='';$('body').prepend($a);location=link.hash;$a.remove();elem[attr]=id;}
$target
.scrollTo(elem,settings)
.trigger('notify.serialScroll',[elem]);};})(jQuery);;
