jQuery(function($) {
  $(".jqGradient:not(.jqInitedGradient)").each(function() {
    var $this = $(this);
    $this.addClass("jqInitedGradient");
    var opts = $.extend({}, $this.metadata());
    $this.gradient(opts);
  });
});
