"use strict";
jQuery(function($) {
  $("input.jqTextboxList:not(.jqInitedTextboxList)").livequery(function() {
    var $this = $(this),
        opts = $.extend({ autocomplete:$this.attr("autocomplete") }, $this.data(), $this.metadata());

    $this.addClass("jqInitedTextboxList").textboxlist(opts);
  });
});
