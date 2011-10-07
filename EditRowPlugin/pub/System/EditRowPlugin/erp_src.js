/**
 * Support for EditRowPlugin
 * 
 * Copyright (c) 2009-2011 Foswiki Contributors
 * Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
 * All Rights Reserved. Foswiki Contributors are listed in the
 * AUTHORS file in the root of this distribution.
 * NOTE: Please extend that file, not this notice.
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version. For
 * more details read LICENSE in the root of this distribution.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * Do not remove this copyright notice.
 */
(function($) {
    var instrument;

    // Date editable
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
            var inp = $(this).find('input');
            var cal = new Calendar(
                1, null,
                function (cal, date) { // onSelected
                    cal.hide();
                    inp.val(date);
                    $(form).trigger("submit");
                },
                function (cal) { // onClose
                    cal.hide();
                    original.reset.apply(original, [ form ]);
                    $(original).addClass(settings.cssdecoration);
                });
            cal.showsOtherMonths = true;
            cal.setRange(1900, 2070);
            cal.create();
            if (settings.format) {
                cal.showsTime = (settings.format.search(/%H|%I|%k|%l|%M|%p|%P/) != -1);
                cal.setDateFormat(settings.format);
            }
            cal.parseDate(original.revert.replace(/^\s+/, ''));
            cal.showAtElement(inp[0], "Br");
        }});

    // Radio button editable
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
                $(this).append('<label for="' + id + '">' +
                               settings.data[key] + '</label>');
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

    // The default JEditable select does not retain the sorting of the selection options,
    // so we need a sorted version. Assumes three keys in the json data: 'order', 'keys'
    // and 'selected'. 'order' is an array containing the sort order of the keys; 'keys'
    // contains the key mapped to the string title of the key; and 'selected' contains
    // the string value of the currently selected key.
    $.editable.addInputType('erpselect', {
        element : function(settings, original) {
            var select = $('<select />');
            $(this).append(select);
            return(select);
        },
        content: function(data, settings, original) {
            /* If it is string assume it is json. */
            if (String == data.constructor) {      
                eval ('var json = ' + data);
            } else {
                /* Otherwise assume it is a hash already. */
                var json = data;
            }

            for (var i in json.order) {
                var key = json.order[i];
                if (json.keys[key] == null)
                    continue;
                var option = $('<option />').val(key).append(json.keys[key]);
                $('select', this).append(option);    
            }
            /* Loop option again to set selected. IE needed this... */ 
            $('select', this).children().each(function() {
                if ($(this).val() == json.selected || 
                    $(this).text() == $.trim(original.revert)) {
                    $(this).attr('selected', 'selected');
                }
            });
        }
    });

    // Checkbox editable
    $.editable.addInputType('checkbox', {
        element : function(settings, original) {
            // 'this' is the form
            // data is CSV list
            var hinput = $('<input type="hidden" id="' + settings.name
                           + '" name="' + settings.name + '" value="" />');
            // *Must* be first
            $(this).append(hinput);
            var key, input, checked, id, cnt = 1;
            var picked = new RegExp(
                "\\b(" + settings.text.replace(/\s*,\s*/, "|") + ")\\b");
            for (key in settings.data) {
                id = settings.name + "_button" + cnt;
                checked = picked.test(key) ? ' checked="checked"' : '';
                input = $('<input type="checkbox" name="' + settings.name +
                          '_buttons" id="' + id + '"' + checked + ' value="'
                          + key + '" />');
                $(this).append(input);
                $(this).append('<label for="' + id + '">' +
                               settings.data[key] + '</label>');
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

    var onDrop = function(event, container, dragee, rows) {
        var target = $(event.target);
        var edge;
        // A drop outside the table
        // is triggered on the drag helper instead of the
        // droppable at the end of the table.
        if (target.hasClass("drag-helper")) {
            var top = rows.first().offset().top;
            var posY = event.pageY - top;
            edge = (posY < (rows.last().offset().top() +
                            rows.last().height() - top) / 2)
                ? 'top' :'bottom';
            if (edge == 'top')
                target = rows.first();
            else
                target = rows.last();
        } else {
            var posY = event.pageY - target.offset().top;
            edge = (posY < target.height() / 2)
                ? 'top' :'bottom';
        }
        // dragee and target are both TRs
        var target_data = target.data('row_data');
        var dragee_data = dragee.data('row_data');
        var old_pos = dragee_data.erp_active_row;
        var new_pos = target_data.erp_active_row;
        var move_data = $.extend({}, target_data);
        if (edge == 'bottom')
            new_pos++;
        
        if (new_pos == old_pos)
            return;
        
        // Send the good news to the server
        dragee.fadeTo("slow", 0.0); // to show it's being moved
        container.css("cursor", "wait");

        move_data.erp_action = 'moveRow';
        move_data.old_pos = old_pos;
        move_data.new_pos = new_pos;
        // Tell the server *not* to return us to edit mode
        move_data.erp_stop_edit = 1;

        // The request will update the entire container.
        $.ajax({
            url: move_data.url,
            type: "POST",
            data: move_data,
            success: function(response) {
                if (response.indexOf("RESPONSE") != 0) {
                    // We got something other than a REST response -
                    // probably an auth prompt. Need to edit the
                    // login form and clear noredirect so that the
                    // save knows to complete in an unRESTful way.
                    // Note that this should really prompt in a
                    // pop-up dialog.
                    container.replaceWith($(response).find(
                        "form[name='loginform']"));
                    $("form[name='loginform'] input[name='noredirect']")
                        .remove();
                } else {
                    var newtable = $(response.replace(/^RESPONSE/, ''));
                    newtable.addClass("erp_new_table");
                    var table = container.closest("table");
                    table.replaceWith(newtable);
                    $(document).find(".erp_new_table").each(
                        function(index, value) {
                            $(this).removeClass("erp_new_table");
                            instrument($(this));
                        });
                }
                if (edge == 'top')
                    dragee.insertBefore(target);
                else
                    dragee.insertAfter(target);
            },
            error: function(jqXHR, textStatus, errorThrown) {
                // Cancel the drag
                dragee.fadeTo("fast", 1.0);
                container.css("cursor", "auto");
		var mess = jqXHR.responseText;
		if (mess && mess.indexOf('RESPONSE') == 0)
                    mess = mess.replace(/^RESPONSE/, ': ');
		else
		    mess = '';
                alert("Error " + jqXHR.status + " - Failed to move row" + mess);
            }
        });
    };

    var dragHelper = function(tr) {
        var helper = tr.clone();
        var dv = $('<div><table></table></div>')
            .find('table')
            .append(helper.addClass("drag-helper"))
            .end();
        dv.css("margin-left", tr.offset().left + "px");
        return dv;
    };

    var makeRowDraggable = function(tr) {
        // Add a "drag handle" element to the first cell of the row
        tr.find("div.erpJS_container").first().find("a.erp_drag_button").each(
            function () {
                var container = tr.closest("thead,tbody,table");
                var handle = $(this);
                handle.addClass('ui-icon');
                handle.draggable({
                    // constrain to the containing table
                    containment: container,
                    axis: 'y',
                    appendTo: 'body',
                    helper: function(event) {
                        return dragHelper(tr);
                    },
                    start: function(event, ui) {
                        tr.fadeTo("fast", 0.3); // to show it's moving
                        var rows = container.find(".editRowPluginRow");
                        rows.not(tr).not('.drag-helper').droppable({
                            drop: function(event, ui) {
                                onDrop(event, container, tr, rows);
                            }
                        });
                    },
                    stop: function() {
                        tr.fadeTo("fast", 1.0);
                    }
                });
            });
    };

    var makeRowsDraggable = function(n, rows) {
	var to = n + Math.min(200, rows.length - n);
	while (n < to) {
	    makeRowDraggable($(rows[n++]));
	}
	if (n < rows.length)
	    window.setTimeout(makeRowsDraggable, 100, n, rows);
    };

    var editControls = {
        onedit: function(settings, self) {
            // Hide the edit button
             $(self).next().hide();
        },

        // use a function to get the submit data from the class
        // attribute, because
        // the row index may change if rows are moved/added/deleted
        submitdata: function(value, settings) {
            var sd = $(this).data('cell_data').erp_data;
            sd.erp_action = 'saveCell';
            return sd;
        },

        onsubmit: function(settings, self) {
            // For some reason we get a double-submit, that we have to defend
            if (self.isSubmitting)
                return false;
            self.isSubmitting = true;
            // Add a clock to feedback on the save
            $("<div class='erp_clock_button'></div>").insertAfter($(self).next());
            return true;
        },

        // submit and reset must restore the edit button
        onreset: function(settings, self) {
            $(self).next().show();
            return true;
        },

        onerror: function(settings, self, xhr) {
            var mess = xhr.responseText;
            self.isSubmitting = false;
            $(self).parent().find('.erp_clock_button').remove();
            $(self).next().show();
            if (mess.indexOf('RESPONSE') == 0)
                alert(mess.replace(/^RESPONSE/, ''));
        },

        onblur: 'cancel',
    };

    var editCallback = function(value, settings, val2data) {
        if (value.indexOf("RESPONSE") != 0) {
            // We got something other than a REST response -
            // probably an auth prompt. Need to edit the
            // login form and clear noredirect so that the
            // save knows to complete in an unRESTful way.
            // Note that this should really prompt in a pop-up dialog.
            $(this).replaceWith($(value).find(
                "form[name='loginform']"));
            $("form[name='loginform'] input[name='noredirect']")
                .remove();
        } else {
            value = value.replace(/^RESPONSE/, '');
            $(this).html(value);
            if (val2data) {
                // Add changed text (unexpanded) to settings
                settings.data = value;
            }
            this.isSubmitting = false;
            $(this).parent().find('.erp_clock_button').remove();
            $(this).next().show();
        }
    };

    // callback for text edit controls
    var textCallback = {
        callback: function(value, settings) {
            editCallback(value, settings, true);
        }
    };

    // callback for all other types of control
    var otherCallback = {
        callback: function(value, settings) {
            editCallback(value, settings, false);
        }
    };

    var erp_dataDirty = false;
    var erp_dirtyVeto = false;

    // For a given context (the whole document, or a single table during editing)
    // decorate the table with handlers for cell edit, row edit, and row move
    instrument = function(context) {

        context.find('.erpJS_input').change(function() {
            erp_dataDirty = true;
        });

        // Action on edit row
        context.find('div.erpJS_editButton').click(function() {
            // Send the event to the span
            $(this).prev().triggerHandler('erp_edit');
        });

        // Action on select row and + row. Check if the data is
        // dirty, and if it is, prompt for save
        context.find('a.erpJS_willDiscard').click(function(event) {
            if (erp_dataDirty) {
                if (!confirm("This action will discard your changes.")) {
                    erp_dirtyVeto = true;
                    return false;
                }
            }
            return true;
        });

        if (!$.browser.msie || parseInt($.browser.version) >= 8)
            // No button support in IE 7 and below
            context.find('a.erpJS_submit').button();

        context.find('a.erpJS_submit').click(function() {
            var cont = true;
            if (erp_dirtyVeto) {
                erp_dirtyVeto = false;
                cont = false;
            } else {
                var form = $(this).closest("form");
                if (form && form.length > 0) {
                    form[0].erp_action.value = $(this).attr('href');
                    form.submit();
                    cont = false;
                }
            }
            return cont;
        });

        context.find('span.erpJS_sort').click(function() {
            var m = /{(.*)}/.exec($(this).attr("class"));
            var md = {};
            if (m)
                md = eval('({' + m[1] + '})');
            return sortTable(this, false, md.headrows, md.footrows);
        });

        context.find('span.erpJS_cell').each(function(index, value) {

            // Make the containing row draggable
            var tr = $(this).closest("tr");
            tr.addClass('ui-draggable');

            // Move meta-data stored in the class attribute into $.data
            var p, m, c = $(this).attr("class");
            if (m = /({.*})/.exec(c)) {
                p = eval('(' + m[1] + ')');
                $(this).data('cell_data', p);
                $(this).attr("class", c.replace(/\s*{.*?}/, ''));
            } else {
                //alert("This should not fail");
            }

            if (!p || !p.type || p.type == 'label')
                return;

            // Import the edit control functions
            $.extend(p,
                     editControls,
                     (p.type == "text" || p.type == "textarea") ?
                     textCallback : otherCallback);

            // We can't add row meta-data when generating the table because
            // it's done by the FW core table rendering. So we have to get
            // the row-meta from the first cell-meta when we have it.
            if (p.erp_data && p.erp_data.erp_active_row
                && !tr.hasClass('editRowPluginRow')) {
                tr.addClass("editRowPluginRow");
                p.erp_data.url = p.url;
                tr.data('row_data', p.erp_data);
            }

            $(this).editable(p.url, p);
        });

	makeRowsDraggable(0, context.find('tr.ui-draggable'));
    };

    $(document).ready(function() {
        instrument($(document));
    });
})(jQuery);
