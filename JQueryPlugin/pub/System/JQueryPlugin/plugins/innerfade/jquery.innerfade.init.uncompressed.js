jQuery(function($) {
  var defaults = {
    speed: 1000,
    timeout: 5000,
    type: 'sequence',
    containerheight: 'auto'
  };
  $('.jqInnerfade:not(.jqInitedInnerfade)').livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedInnerfade");
    var opts = $.extend({}, defaults, $this.metadata());
    $this.innerfade(opts);
  });
});
