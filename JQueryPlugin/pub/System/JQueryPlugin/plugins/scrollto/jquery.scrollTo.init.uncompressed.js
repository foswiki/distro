jQuery(function($) {
  $(".jqScrollToLink").live("click", function() {
    var opts = $.extend({}, $(this).metadata());
    $.scrollTo(opts.target, opts);
    return false;
  });
});
