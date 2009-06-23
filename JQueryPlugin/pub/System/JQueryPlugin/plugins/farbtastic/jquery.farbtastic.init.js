(function($){var defaults={fade:250,position:'bottom',callback:function(color){$.log("new color="+color);}};$(function(){var colorpicker=$("#colorpicker");if(colorpicker.length==0){colorpicker=$('<div class="ui-component-content ui-widget-content ui-hidden ui-helper-hidden" id="colorpicker"></div>').appendTo("body");}
$(".jqFarbtastic").each(function(){var $this=$(this);var fb=$.farbtastic(colorpicker).linkTo(this);var opts=$.extend({},defaults,$this.metadata());$this.click(function(){fb=$.farbtastic(colorpicker).linkTo(this);var pos=$this.offset();if(opts.position=='left')
pos.left+=$this.outerWidth();if(opts.position=='bottom')
pos.top+=$this.outerHeight();colorpicker.css({top:pos.top,left:pos.left});var fb=colorpicker.farbtastic();fb.debug();fb.fadeIn(opts.fade);}).
blur(function(){colorpicker.farbtastic().hide();if(typeof(opts.callback)=='function'){opts.callback.call(fb,fb.color);}});});});})(jQuery);;
