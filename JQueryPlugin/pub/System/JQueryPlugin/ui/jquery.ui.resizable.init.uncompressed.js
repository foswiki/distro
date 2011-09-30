// initializer for the ui-resizable plugin
jQuery(function($) {

  $(".jqUIResizable").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.metadata());

    $this.removeClass("jqUIResizable").resizable(opts);
  });
});
