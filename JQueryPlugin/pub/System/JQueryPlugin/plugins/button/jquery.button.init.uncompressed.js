(function($) {
  $(function() {
    $(".jqButton").each(function() {
      var $this = $(this);
      var options = $.extend({}, $this.metadata({type:'attr', name:'data'}));
      if (options.onclick) {
	$this.click(function() {
	  return options.onclick.call(this);
	});
      }
      // TODO hover
    });
 });
})(jQuery);


