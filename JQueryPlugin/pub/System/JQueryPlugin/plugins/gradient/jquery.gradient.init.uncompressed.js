;(function($) {
  $(function() {
    $(".jqGradient").each(function() {
      var $this = $(this);
      var opts = $this.metadata();
      $this.gradient(opts);
    });
  });
})(jQuery);
