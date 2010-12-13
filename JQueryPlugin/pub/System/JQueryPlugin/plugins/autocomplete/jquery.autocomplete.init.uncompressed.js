jQuery(function($) {
  var defaults = {
    selectFirst:false,
    autoFill:false,
    matchCase:false,
    matchSubset:false,
    matchContains:false,
    scrollHeight: 200
  };

  $("[autocomplete][autocomplete!=off]:not(.jqInitedAutocomplete)").livequery(function() {
    var $this = $(this);
    var options = $.extend({}, defaults, $this.metadata());
    var urlOrData = $this.attr('autocomplete') || '';
    $this.attr('autocomplete', 'off');
    if (!urlOrData.match("^https?://")) {
      urlOrData = urlOrData.split(/\s*,\s*/);
    }
    $this.addClass("jqInitedAutocomplete").autocomplete(urlOrData, options);
  });
});
