jQuery(function($) {
  $(".jqShrinkUrls").livequery(function() {
    var $this = $(this);
    var opts = $.extend({},$this.metadata());
    $this.find("a:not(.jqInitedShrinkUrl)").addClass("jqInitedShrinkUrl").shrinkUrls(opts);
  });
});
