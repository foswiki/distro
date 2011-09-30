// initializer for the ui-draggable plugin
jQuery(function($) {

  $(".jqUIDraggable").livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, $this.metadata());

    $this.removeClass("jqUIDraggable").draggable(opts);
  });
});
