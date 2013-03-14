jQuery(function($) {
  $(document).on("click", ".jqScrollToLink", function() {
    var opts = $.extend({}, $(this).metadata());
    $.scrollTo(opts.target, opts);
    return false;
  });
});
