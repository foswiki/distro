"use strict";
jQuery(function($) {

  $.validator.addClassRules("foswikiMandatory", {
    required: true
  });

  $(".jqValidate:not(.jqInitedValidate)").livequery(function() {
    var $this = $(this), 
        options = $.extend({}, $this.data(), $this.metadata());

    $this.addClass("jqInitedValidate").validate(options);
  });
});
