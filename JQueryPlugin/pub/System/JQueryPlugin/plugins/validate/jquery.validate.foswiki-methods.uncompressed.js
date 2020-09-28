"use strict";
(function($) {
  $.validator.addClassRules("foswikiMandatory", {
    required: true
  });

  $.validator.addMethod(
    "wikiword", 
    function(value, element) {
      return this.optional(element) || foswiki.RE.wikiword.test(value);
    }, 
    "WikiWord only please"
  ); 
})(jQuery);
