'use strict';
jQuery(function($) {
  var defaults = {
    waitForImages: false
  };

  $(".jqMasonry:not(.jqInitedMasonry)").livequery(function() {
    var $this = $(this),
        opts = $.extend({}, defaults, $this.data(), $this.metadata());

    if (opts.waitForImages) {
      $this.imagesLoaded(function() {
        $this.masonry(opts).addClass("jqInitedMasonry");
      });
    } else {
      $this.masonry(opts).addClass("jqInitedMasonry");
    }

  });
});
