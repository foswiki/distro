jQuery(function($) {
  var defaults = {
    delay:350,
    track:true,
    showURL:false,
    showBody:':',
    extraClass:'foswiki'
  };
  $(".jqTooltip [title]:not(.jqInitedTooltip)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedTooltip");
    var opts = $.extend({}, defaults , $this.metadata());
    $this.tooltip(opts);
  });
});
