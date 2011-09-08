// initializer for the ui-progressbar plugin
jQuery(function($) {
  
  // progressbar
  $(".jqUIProgressBar").livequery(function() {
    var $this = $(this), 
        value = parseInt($this.text(), 10),
        opts = $.extend({ value: value }, $this.metadata());

    $this.empty().removeClass("jqUIProgressbar").progressbar(opts);    
  });

});
