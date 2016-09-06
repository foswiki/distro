// initializer for the ui-tabs plugin
"use strict";
jQuery(function($) {

  $(".jqUITabs:not(.jqUITabsInited)").livequery(function() {
    var $this = $(this), opts = $.extend({}, $this.data(), $this.metadata());
    $this.addClass("jqUITabsInited").tabs(opts);
  });

});
