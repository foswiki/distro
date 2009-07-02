(function($) {

  /***************************************************************************
   * handles the submit action for the insert table dialog
   */
  $.natedit.handleInsertTable = function(nateditor) {
    var rows = parseInt($("#natEditInsertTableRows").val());
    var cols = parseInt($("#natEditInsertTableCols").val());
    var heads = $("#natEditInsertTableHeads").val();
    if (heads == 'NaN') {
      heads = 0;
    }
    if (rows == 'NaN') {
      rows = 0;
    }
    if (cols == 'NaN') {
      cols = 0;
    }
    var output = [];
    for (var i = 0; i < heads; i++) {
      var line = '|';
      for (var j = 0; j < cols; j++) {
	line += ' *head* |';
      }
      output.push(line);
    }
    for (var i = 0; i < rows; i++) {
      var line = '|';
      for (var j = 0; j < cols; j++) {
	line += ' data |';
      }
      output.push(line);
    }
    $.modal.close();
    nateditor.insert(output.join("\n")+"\n");
  };

})(jQuery);
