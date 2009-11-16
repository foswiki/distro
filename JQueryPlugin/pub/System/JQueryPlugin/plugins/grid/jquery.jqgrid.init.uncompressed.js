(function($) {
  $(function() {
    // initinitializer for %GRID%
    $(".jqTable2Grid").each(function() {
      var $this = $(this);
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
})(jQuery);

