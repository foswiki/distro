// initializer for the ui-progressbar plugin
jQuery(function($) {
  
  // progressbar
  $(".jqUIProgressBar:not(.jqUIProgressBarInited)").livequery(function() {
    var $this = $(this), 
        value = parseInt($this.text(), 10),
        opts = $.extend({ value: value }, $this.data(), $this.metadata());

    $this.addClass("jqUIProgressBarInited").progressbar(opts);    
  });

});
