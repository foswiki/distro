(function($) {
    $.editable.addInputType('datepicker', {
	element : function(settings, original) {
	    var input = $('<input>');
	    if (settings.width  != 'none')
		input.width(settings.width);
	    if (settings.height != 'none')
		input.height(settings.height);
	    input.attr('autocomplete', 'off');
	    $(this).append(input);
	    return(input);
	},
	plugin : function(settings, original) {
	    /* Workaround for missing parentNode in IE */
	    var form = this;
	    settings.onblur = 'ignore';
	    $(this).find('input').datepicker({
		firstDay: 1,
		dateFormat: $.datepicker.W3C,
		closeText: 'X',
		onSelect: function(dateText) {
		    $(this).hide();
		    $(form).trigger("submit");
		},
		onClose: function(dateText) {
		    original.reset.apply(form, [settings, original]);
		    $(original).addClass( settings.cssdecoration );
		},
	    });
	}});

    $.editable.addInputType('radio', {
        element : function(settings, original) {
	    // 'this' is the form
	    var hinput = $('<input type="hidden" id="' + settings.name
			   + '" name="' + settings.name + '" value="" />');
	    // *Must* be first
	    $(this).append(hinput);
	    var key, input, checked, id, cnt = 1;
	    for (key in settings.data) {
		id = settings.name + "_button" + cnt;
		$(this).append('<label for="' + id + '">' + settings.data[key] + '</label>');
		checked = (key === settings.text) ? ' checked="checked"' : "";
		input = $('<input type="radio" name="' + settings.name +
			  '_buttons" id="' + id + '"' + checked + ' value="'
			  + key + '" />');
		$(this).append(input);
		input.click(function() {
		    $('#' + settings.name).val($(this).val());
		});
		cnt++;
	    }
            return hinput;
        }
    });

    $.editable.addInputType('checkbox', {
        element : function(settings, original) {
	    // 'this' is the form
	    // data is CSV list
	    var hinput = $('<input type="hidden" id="' + settings.name
			   + '" name="' + settings.name + '" value="" />');
	    // *Must* be first
	    $(this).append(hinput);
	    var key, input, checked, id, cnt = 1;
	    var picked = new RegExp("\\b(" + settings.text.replace(/\s*,\s*/, "|") + ")\\b");
	    for (key in settings.data) {
		id = settings.name + "_button" + cnt;
		checked = picked.test(key) ? ' checked="checked"' : '';
		input = $('<input type="checkbox" name="' + settings.name +
			  '_buttons" id="' + id + '"' + checked + ' value="'
			  + key + '" />');
		$(this).append(input);
		$(this).append('<label for="' + id + '">' + settings.data[key] + '</label>');
		input.change(function() {
		    // The :checked selector doesn't work :-(
		    var vs = 'input[name="' + settings.name + '_buttons"]';
		    var vals = [];
		    $(vs).each(function(i, e) {
			if ($(e).attr("checked"))
			    vals.push($(e).val());
		    });
		    $('#' + settings.name).val(vals.join(','));
		});
		cnt++;
	    }
            return hinput;
	}
    });

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

	$(".editRowPluginCell").livequery(function() {
	    var m = /({.*})/.exec($(this).attr("class"));
	    var p = eval('(' + m[1] + ')');
	    if (!p.type || p.type == 'label')
		return;

	    if (!p.tooltip)
		p.tooltip = 'Click to edit...';
	    p.onblur = 'cancel';

	    if (m = /(.*)\?(.*)/.exec(p.url)) {
		p.url = m[1];
		p.submitdata = {
		    erp_action: 'erp_saveCell',
		};
		var params = m[2].split(/[;&]/), i;
		for (i in params) {
		    if (m = /^(.*?)=(.*)/.exec(params[i]))
			p.submitdata[m[1]] = unescape(m[2]);
		    else
			alert("Invalid param "+params[i]);
		}
	    }
	    #console.debug(p.type + " " + p.url);
	    $(this).editable(p.url, p);
 	});
    });
})(jQuery);
