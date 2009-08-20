var bottomBarHeight=-1;(function($){$.tabpane={build:function(options){if(typeof(options)=='undefined'){options={};}
var opts=$.extend({},$.tabpane.defaults,options);return this.each(function(){var $thisPane=$(this);var thisOpts=$.extend({},opts,$thisPane.metadata());if($.browser.msie){thisOpts.animate=false;}
if(!$thisPane.is(".jqTabPaneInitialized")){$thisPane.addClass("jqTabPaneInitialized");$("<span class='foswikiClear'></span>").prependTo($thisPane);var $tabContainer=$thisPane;var $tabGroup=$('<ul class="jqTabGroup"></ul>').prependTo($thisPane);var index=1;$thisPane.find("> .jqTab").each(function(){var $this=$(this);var title=$this.find('h2:first').remove().text();$tabGroup.append('<li><a href="#" data="'+this.id+'">'+title+'</a></li>');if(index==thisOpts.select||$this.hasClass(thisOpts.select)){thisOpts.currentTabId=this.id;}
index++;});if(thisOpts.currentTabId){$.tabpane.switchTab($thisPane,thisOpts,thisOpts.currentTabId);}
if(thisOpts.autoMaxExpand){window.setTimeout(function(){$.tabpane.autoMaxExpand($thisPane,thisOpts);},100);}
$thisPane.find(".jqTabGroup > li > a").click(function(){$(this).blur();var newTabId=$(this).attr('data');if(newTabId!=thisOpts.currentTabId){$.tabpane.switchTab($thisPane,thisOpts,newTabId);}
return false;});}});},switchTab:function($thisPane,thisOpts,newTabId){var oldTabId=thisOpts.currentTabId;var $newTab=jQuery("#"+newTabId);var $oldTab=jQuery("#"+oldTabId);var $newContainer=$newTab.find('.jqTabContents');var $oldContainer=$oldTab.find('.jqTabContents');var oldHeight=$oldContainer.height();$oldTab.removeClass("current");$newTab.addClass("current");$thisPane.find("li a[data="+oldTabId+"]").parent().removeClass("current");$thisPane.find("li a[data="+newTabId+"]").parent().addClass("current");if(!thisOpts[newTabId]){thisOpts[newTabId]=$newTab.metadata();}
var data=thisOpts[newTabId];if(typeof(data.beforeHandler)=="function"){data.beforeHandler.call(this,oldTabId,newTabId);}
if((thisOpts.animate||thisOpts.autoMaxExpand)&&oldHeight>0){$newContainer.height(oldHeight);}
if(typeof(data.url)!="undefined"){$newContainer.load(data.url,undefined,function(){if(typeof(data.afterLoadHandler)=="function"){data.afterLoadHandler.call(this,oldTabId,newTabId);}
_finally();});delete thisOpts[newTabId].url;}else{_finally();}
function _finally(){var effect='none';if(oldHeight!=newHeight&&oldHeight>0){if(oldHeight>newHeight){effect='easeOutQuad';}else{effect='easeInQuad';}}
if(thisOpts.autoMaxExpand){if(thisOpts.animate&&effect!='none'){$newContainer.css({opacity:0.0}).animate({opacity:1.0},300);}
$(window).trigger("resize");}else{if(thisOpts.animate){$newContainer.height('auto');var newHeight=$newContainer.height();if(effect!='none'){$newContainer.height(oldHeight).css({opacity:0.0}).animate({opacity:1.0,height:newHeight},300,effect,function(){$newContainer.height('auto');});}else{$newContainer.height('auto');}}}
if(typeof(data.afterHandler)=="function"){data.afterHandler.call(this,oldTabId,newTabId);}
thisOpts.currentTabId=newTabId;}},autoMaxExpand:function($thisPane,opts){window.setTimeout(function(){jQuery.tabpane.fixHeight($thisPane,opts);jQuery(window).one("resize",function(){$.tabpane.autoMaxExpand($thisPane,opts)});},100);},fixHeight:function($thisPane,opts){var $container=$thisPane.find("> .jqTab.current .jqTabContents");var paneOffset=$container.offset();if(typeof(paneOffset)=='undefined'){return;}
var paneTop=paneOffset.top;if(bottomBarHeight<=0){bottomBarHeight=jQuery('.natEditBottomBar').outerHeight({margin:true,padding:true});}
var windowHeight=jQuery(window).height();if(!windowHeight){windowHeight=window.innerHeight;}
var height=windowHeight-paneTop-2*bottomBarHeight-12;var $debug=$("#DEBUG");if($debug){height-=$debug.outerHeight({margin:true,padding:true});}
if(opts&&opts.minHeight&&height<opts.minHeight){height=opts.minHeight;}
if(height<0){return;}
$container.height(height);},defaults:{select:1,animate:false,autoMaxExpand:false,minHeight:230}};$.fn.tabpane=$.tabpane.build;})(jQuery);;
