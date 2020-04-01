"use strict";
jQuery(function($) {
  $(".jqValidate:not(.jqInitedValidate)").livequery(function() {
    var $this = $(this), 
        options = $.extend({}, $this.data(), $this.metadata());

    $this.addClass("jqInitedValidate").validate(options);
  });
});
