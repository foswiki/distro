jQuery(function($) {
  $(".jqCorner:not(.jqInitedCorner)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedCorner").corner();
  });
});
