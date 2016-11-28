"use strict";
jQuery(function($) {
  $(".jqMaskedInput:not(.jqInitedMaskedInput)").livequery(function() {
    var $this = $(this), 
        mask = $this.attr("mask"),
        opts = $.extend({mask: mask}, $this.data(), $this.metadata());

    $this.addClass("jqInitedMaskedInput").mask(opts.mask, opts);
  });
});
