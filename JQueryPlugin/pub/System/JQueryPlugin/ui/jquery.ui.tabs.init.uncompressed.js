// initializer for the ui-tabs plugin
jQuery(function($) {

  $(".jqUITabs").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.metadata(), $this.data());
    $this.removeClass("jqUITabs").tabs(opts);
  });

});
