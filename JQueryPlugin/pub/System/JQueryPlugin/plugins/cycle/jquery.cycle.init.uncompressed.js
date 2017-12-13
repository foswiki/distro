"use strict";
jQuery(function($) {
  $(".jqCycle:not(.jqInitedCycle)").livequery(function() {
    var $this = $(this);
    var opts = $.extend({}, $this.data(), $this.metadata());
    $this.addClass(".jqInitedCycle").cycle(opts);
  });
});
