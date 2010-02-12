;(function($){var $serialScroll=$.serialScroll=function(settings){return $(window).serialScroll(settings);};$serialScroll.defaults={duration:1000,axis:'x',event:'click',start:0,step:1,lock:true,cycle:true,constant:true
};$.fn.serialScroll=function(options){return this.each(function(){var
settings=$.extend({},$serialScroll.defaults,options),event=settings.event,step=settings.step,lazy=settings.lazy,context=settings.target?this:document,$pane=$(settings.target||this,context),pane=$pane[0],items=settings.items,active=settings.start,auto=settings.interval,nav=settings.navigation,timer;if(!lazy)
items=getItems();if(settings.force)
jump({},active);$(settings.prev||[],context).bind(event,-step,move);$(settings.next||[],context).bind(event,step,move);if(!pane.ssbound)
$pane
.bind('prev.serialScroll',-step,move)
.bind('next.serialScroll',step,move)
.bind('goto.serialScroll',jump);if(auto)
$pane
.bind('start.serialScroll',function(e){if(!auto){clear();auto=true;next();}})
.bind('stop.serialScroll',function(){clear();auto=false;});$pane.bind('notify.serialScroll',function(e,elem){var i=index(elem);if(i>-1)
active=i;});pane.ssbound=true;if(settings.jump)
(lazy?$pane:getItems()).bind(event,function(e){jump(e,index(e.target));});if(nav)
nav=$(nav,context).bind(event,function(e){e.data=Math.round(getItems().length/nav.length)*nav.index(this);jump(e,this);});function move(e){e.data+=active;jump(e,this);};function jump(e,button){if(!isNaN(button)){e.data=button;button=pane;}
var
pos=e.data,n,real=e.type,$items=settings.exclude?getItems().slice(0,-settings.exclude):getItems(),limit=$items.length,elem=$items[pos],duration=settings.duration;if(real)
e.preventDefault();if(auto){clear();timer=setTimeout(next,settings.interval);}
if(!elem){n=pos<0?0:limit-1;if(active!=n)
pos=n;else if(!settings.cycle)
return;else
pos=limit-n-1;elem=$items[pos];}
if(!elem||settings.lock&&$pane.is(':animated')||real&&settings.onBefore&&settings.onBefore(e,elem,$pane,getItems(),pos)===false)return;if(settings.stop)
$pane.queue('fx',[]).stop();if(settings.constant)
duration=Math.abs(duration/step*(active-pos));$pane
.scrollTo(elem,duration,settings)
.trigger('notify.serialScroll',[pos]);};function next(){$pane.trigger('next.serialScroll');};function clear(){clearTimeout(timer);};function getItems(){return $(items,pane);};function index(elem){if(!isNaN(elem))return elem;var $items=getItems(),i;while((i=$items.index(elem))==-1&&elem!=pane)
elem=elem.parentNode;return i;};});};})(jQuery);