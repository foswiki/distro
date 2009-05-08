(function($) {
  $(function() {
    $('.jqInnerfade').each(function() {
      var options = {
        speed: 1000,
        timeout: 5000,
        type: 'sequence',
        containerheight: 'auto'
      };
      $.extend(options, $(this).metadata());
      $(this).innerfade(options);
    });
  });
})(jQuery);

