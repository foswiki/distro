// initializer for the ui-accordion plugin
jQuery(function($) {
  $(".jqUIAccordion").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.data(), $this.metadata());
    $this.removeClass("jqUIAccordion").accordion(opts);    
  });
});
