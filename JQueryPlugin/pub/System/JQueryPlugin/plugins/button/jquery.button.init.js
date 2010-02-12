jQuery(function($){$(".jqButton:not(.jqInitedButton)").livequery(function(){var $this=$(this);$this.addClass("jqInitedButton");var options=$.extend({},$this.metadata({type:'attr',name:'data'}));if(options.onclick){$this.click(function(){return options.onclick.call(this);});}
});});;
