// initializer for the ui-accordion plugin
jQuery(function($) {
  $(".jqUIAccordion").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.metadata());
    $this.removeClass("jqUIAccordion").accordion(opts);    
  });
});
