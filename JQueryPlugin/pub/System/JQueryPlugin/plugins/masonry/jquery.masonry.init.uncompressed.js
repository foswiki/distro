jQuery(function($) {
  var defaults = {
    waitForImages: false
  };

  $(".jqMasonry:not(.jqInitedMasonry)").livequery(function() {
    var $this = $(this),
        opts = $.extend({}, defaults, $this.metadata());

    $this.addClass("jqInitedMasonry");

    if (opts.waitForImages) {
      $this.imagesLoaded(function() {
        $this.masonry(opts);
      });
    } else {
      $this.masonry(opts);
    }

  });
});
