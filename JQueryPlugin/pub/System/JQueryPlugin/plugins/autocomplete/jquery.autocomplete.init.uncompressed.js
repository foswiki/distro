jQuery(function($) {
  var defaults = {
    selectFirst:false,
    autoFill:false,
    matchCase:false,
    matchSubset:false,
    matchContains:false,
    scrollHeight: 200
  };

  $("input[autocomplete]:not([autocomplete=off]):not(.jqInitedAutocomplete)").livequery(function() {
    var $this = $(this), 
        urlOrData = 
          $this.attr("autocomplete") 
          || $this[0].getAttribute("autocomplete") /* fix for firefox-4 */
          || '',
        options = $.extend({}, defaults, $this.metadata());

    if (!urlOrData.match("^https?://")) {
      urlOrData = urlOrData.split(/\s*,\s*/);
    }
    $this.addClass("jqInitedAutocomplete").autocomplete(urlOrData, options);
  });
});
