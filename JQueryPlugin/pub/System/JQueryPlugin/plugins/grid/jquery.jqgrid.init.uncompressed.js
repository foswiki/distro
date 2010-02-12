jQuery(function($) {
  // initinitializer for %GRID%
  $(".jqTable2Grid:not(.jqInitedGrid)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedGrid");
    var options = $.extend({}, $this.metadata());
    var $table = $this.nextAll('table:first');
    if (options.pager) {
      $table.after("<div id='"+options.pager+"'></div>");
    }
    tableToGrid($table, options);
    var $grid = $table.jqGrid();
    if(options.foswiki_filtertoolbar) {
      $grid.filterToolbar();
    }
    if(options.foswiki_navgrid) {
      $grid.navGrid();
    }
  });
});
