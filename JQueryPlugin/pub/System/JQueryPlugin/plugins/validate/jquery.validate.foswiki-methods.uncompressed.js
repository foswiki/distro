jQuery.validator.addMethod(
  "wikiword", 
  function(value, element) {
    return this.optional(element) || /^[A-Z]+[a-z]+[A-Z]+/.test(value);
  }, 
  "WikiWord only please"
); 

