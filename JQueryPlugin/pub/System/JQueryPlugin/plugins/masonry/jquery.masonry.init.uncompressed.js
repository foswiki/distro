jQuery(function($) {
  $(".jqMasonry:not(.jqInitedMasonry)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedMasonry");
    var opts = $.extend({}, $this.metadata());
    $this.masonry(opts);
  });
});
