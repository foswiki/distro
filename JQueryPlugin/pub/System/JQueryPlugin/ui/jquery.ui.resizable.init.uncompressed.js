// initializer for the ui-resizable plugin
jQuery(function($) {

  $(".jqUIResizable").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.data(), $this.metadata());

    $this.removeClass("jqUIResizable").resizable(opts);
  });
});
