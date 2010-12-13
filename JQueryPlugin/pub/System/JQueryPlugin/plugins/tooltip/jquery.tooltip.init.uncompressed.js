jQuery(function($) {
  var defaults = {
    delay:350,
    track:true,
    showURL:false,
    showBody:':',
    extraClass:'foswiki'
  };
  var globalOpts;

  function initTooltip(elem) {
    var $elem = $(elem);
    var opts = $.extend({}, globalOpts, $elem.metadata());
    $elem.tooltip(opts);
  }

  $(".jqTooltip:not(.jqInitedTooltip)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedTooltip");
    globalOpts = $.extend({}, defaults , $this.metadata());
    initTooltip(this);
    $this.find("[title]").each(function() {
      initTooltip(this);
    });
  });
});
