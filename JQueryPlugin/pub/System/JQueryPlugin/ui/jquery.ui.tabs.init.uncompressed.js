// initializer for the ui-tabs plugin
jQuery(function($) {

  $(".jqUITabs").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.data(), $this.metadata());
    $this.removeClass("jqUITabs").tabs(opts);
  });

});
