jQuery(function($) {
  $(".jqTabPane:not(.jqInitedTabpane)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedTabpane");
    $this.tabpane();
  });
});

