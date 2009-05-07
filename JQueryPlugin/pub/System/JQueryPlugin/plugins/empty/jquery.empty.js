;(function($){$.empty={build:function(options){$.log("called empty()");var opts=$.extend({},$.fn.empty.defaults,options);return this.each(function(){$this=$(this);var thisOpts=$.meta?$.extend({},opts,$this.data()):opts;});},helper:function(){},defaults:{};}
$.fn.empty=$.empty.build;})(jQuery);;
