"use strict";
jQuery(function($) {

  $.validator.addClassRules("foswikiMandatory", {
    required: true,
    normalizer: function(val) {
      var elem = this,
          natedit = $(elem).data("natedit");

      if (typeof(natedit) !== 'undefined' && typeof(natedit.getValue) !== 'undefined') {
        //console.log("getting value from natedit");
        val = natedit.getValue();
      }
      return val;
    }
  });

  $(".jqValidate:not(.jqInitedValidate)").livequery(function() {
    var $this = $(this), 
        options = $.extend({}, $this.data(), $this.metadata());

    $this.addClass("jqInitedValidate").validate(options);
  });
});
