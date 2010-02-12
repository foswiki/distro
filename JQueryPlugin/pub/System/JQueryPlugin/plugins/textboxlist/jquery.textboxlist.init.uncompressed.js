jQuery(function($) {
  $("input.jqTextboxList:not(.jqInitedTextboxList)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedTextboxList");
    var opts = $.extend({}, $this.metadata());
    $this.textboxlist(opts);
  });
});
