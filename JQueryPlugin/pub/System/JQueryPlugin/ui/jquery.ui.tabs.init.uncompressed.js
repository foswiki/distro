// initializer for the ui-tabs plugin
jQuery(function($) {

  $(".jqUITabs").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.metadata());
    $this.removeClass("jqUITabs").tabs(opts);
  });

});
