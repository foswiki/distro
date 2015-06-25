jQuery.validator.addMethod(
  "wikiword", 
  function(value, element) {
    return this.optional(element) || foswiki.RE.wikiword.test(value);
  }, 
  "WikiWord only please"
); 

