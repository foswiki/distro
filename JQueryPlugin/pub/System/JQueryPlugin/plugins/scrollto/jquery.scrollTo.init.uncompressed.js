"use strict";
jQuery(function($) {
  $(document).on("click", ".jqScrollToLink", function() {
    var $this = $(this), 
        opts = $.extend({}, $this.data());

    $.scrollTo(opts.target, opts);
    return false;
  });
});
