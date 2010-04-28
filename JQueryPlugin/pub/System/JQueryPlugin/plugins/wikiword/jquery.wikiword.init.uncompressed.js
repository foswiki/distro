jQuery(function($) {
  $(".jqWikiWord:not(.jqInitedWikiWord)").livequery(function() {
    var $this = $(this), options;
    $this.addClass("jqInitedWikiWord");
    options = $.extend({}, $this.metadata());
    $this.wikiword(options.source, options);
  });
});



