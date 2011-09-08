jQuery(function($) {
  $(".jqValidate:not(.jqInitedValidate)").livequery(function() {
    var $this = $(this), 
        options = $.extend({}, $this.metadata());

    $this.addClass("jqInitedValidate").validate(options);
  });
});
