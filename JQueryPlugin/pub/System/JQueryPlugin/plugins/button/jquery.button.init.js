(function($){$(function(){$(".jqButton").not(".jqInited").each(function(){var $this=$(this);$this.addClass("jqInited");var options=$.extend({},$this.metadata({type:'attr',name:'data'}));if(options.onclick){$this.click(function(){return options.onclick.call(this);});}
});});})(jQuery);;
