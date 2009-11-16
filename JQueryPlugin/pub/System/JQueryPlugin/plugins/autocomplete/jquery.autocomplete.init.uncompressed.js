(function($) {

$(function() {
  $("[autocomplete][autocomplete!=off]").not('.jqInited').each(function() {
    var $this = $(this);
    $this.addClass("jqInited");
    var options = $.extend({
      selectFirst:false,
      autoFill:false,
      matchCase:false,
      matchSubset:false,
      matchContains:false
    }, $this.metadata());
    var urlOrData = $this.attr('autocomplete') || '';
    $this.attr('autocomplete', 'off');
    if (!urlOrData.match("^https?://")) {
      urlOrData = urlOrData.split(/\s*,\s*/);
    }
    $this.autocomplete(urlOrData, options);
  });
});

})(jQuery);
