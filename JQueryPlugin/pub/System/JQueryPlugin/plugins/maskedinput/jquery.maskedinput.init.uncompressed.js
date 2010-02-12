jQuery(function($) {
  $("input[mask]:not(.jqInitedMaskedInput)").livequery(function() {
    var $this = $(this);
    $this.addClass(".jqInitedMaskedInput");
    var opts = $.extend({}, $this.metadata());
    $this.mask($this.attr('mask'), opts);
  });
});
