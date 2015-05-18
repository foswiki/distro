jQuery.validator.addMethod(
  "wikiword", 
  function(value, element) {
    return this.optional(element) || foswiki.wikiword.test(value);
  }, 
  "WikiWord only please"
); 

