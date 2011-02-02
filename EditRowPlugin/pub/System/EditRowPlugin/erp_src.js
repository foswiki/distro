(function($) {
    $(document).ready(function() {
	var erp_rowDirty = false;

	$('.editRowPluginInput').livequery("change", function() {
	    erp_rowDirty = true;
	});

	// Action on select row and + row. Check if the current row is dirty, and
	// if it is, prompt for save
	$('.editRowPlugin_willDiscard').livequery("click", function() {
	    if (erp_rowDirty) {
		if (!confirm("This action will discard your changes.")) {
		    return false;
		}
	    }
	    return true;
	});

	$('.erp_submit').livequery("click", function() {
	    var form = $(this).closest("form");
	    if (form && form.length > 0) {
		form[0].erp_action.value = $(this).attr('href');
		form.submit();
		return false;
	    }
	    return true;
	}).button();

	$('.editRowPluginSort').livequery("click", function() {
	    var m = /{(.*)}/.exec(this.attr("class"));
	    var md = {};
	    if (m)
		md = eval('({' + m[1] + '})');
	    return sortTable(this, false, md.headrows, md.footrows);
	});
    });
})(jQuery);
/*
Whole table edit
Single row edit
*/