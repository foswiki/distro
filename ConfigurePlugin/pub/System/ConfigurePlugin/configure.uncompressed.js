/*
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

User interface for Foswiki configuration. Uses the JsonRpc interface
to interact with Foswiki.
*/

/*jslint debug:true */
/*global TML:false*/

var json_rpc_url = "jsonrpc",
    jsonRpc_reqnum = 0,
    $FALSE = 0, // (May be) required for eval()ing values from FW
    $TRUE = 1;

// Convert key string to valid HTML id. Not guaranteed to generate a unique
// id, but close enough for our purposes.
function _id_ify(id) {
    if (typeof(id) === "undefined") {
      debugger;
    }
    id = id.replace(/[}{]/g, '-');
    id = id.replace(/['"]/g, '');
    id = id.replace(/[^A-Za-z0-9_]/g, '-');
    return 'i' + id;
}

(function($) {
"use strict";

    var auth_action = function() {},
        confirm_action = function() {};

    function inline_whirly($site) {
        var $whirly = $('<span class="whirly" />');
        $site.append($whirly);
        window.setTimeout(function() {
            $whirly.remove();
        }, 1000);
        return $whirly;
    }

    // Find all modified values, and return key-values
    function find_modified_values() {
        var set = {}, handler;

        $('.value_modified').each(function() {
            handler = $(this).data('value_handler');
            set[handler.spec.keys] = handler.currentValue();
        });
        return set;
    }

    function update_save_button(force) {
        var count = $('.value_modified').length,
            mess = (count == 1) ? "1 change"
            : (count > 0) ? count + " changes" : '';

        if ( force ) {
            count++;
            mess  = '(required)'
        }
        $('#saveButton').button('option', 'label', 'Save ' + mess);
        if ( $('#bootstrap_warning').length > 0 ) {
            count++;
        }
        $('#saveButton').button(count > 0 ? 'enable' : 'disable');
        
    }

    function update_modified_default($node) {
        var handler = $node.data('value_handler');
        if (handler.isModified()) {
            $node.addClass("value_modified");
            $node.find('.undo_button').show();
            update_save_button();
        } else {
            $node.removeClass("value_modified");
            update_save_button();
            $node.find('.undo_button').hide();
        }

        if (handler.isDefault()) {
            $node.find('.default_button').hide();
        } else {
            $node.find('.default_button').show();
        }
    }

    // Make an RPC call
    function RPC(method, message, params, report, $whirlyPlace) {
        var rpcid, $w;
        rpcid = _id_ify(message) + '_' + jsonRpc_reqnum++; // Get an id to uniquely identify the request
        console && console.debug("Sending " + rpcid);
        if ($whirlyPlace) {
          $w = inline_whirly($whirlyPlace);
        }
        $.jsonRpc(
            json_rpc_url,
            {
                namespace: 'configure',
                method: method,
                id: rpcid,
                params: params,
                error: function(jsonResponse, textStatus, xhr) {
                    console && console.debug(rpcid + " failed");
                    if ($w) {
                      $w.remove();
                    }
                    $.pnotify({
                      title: "Error",
                      text: jsonResponse.error.message,
                      type: "error",
                      hide: false,
                      sticker: false,
                      closer_hover: false,
                      icon: false
                    });
                },
                success: function(jsonResponse, textStatus, xhr) {
                    console && console.debug(rpcid + " OK");
                    report(jsonResponse.result);
                    if ($w) {
                      $w.remove();
                    }
                }
            });
    }

    /*
      CHECKERS

      Checker reports are attached to the key node they relate to using
      a generated div. Reports are also bubbled up though the section
      hierarchy. Each section (tab) node carries a .data('reports') that
      contains a record of the levels and the keys reported for that node.
      When an error report for {This}{Key} is bubbled up, the section
      (tab) node gets a class that indicates the level and id
      (errorsi-This-Key-), and data[errors]['i-This-Key-'] is incremented.
      The data is monitored to control addition/removal of the errors /
      warnings class that highlights when errors/warnings exits in a tab.
    */

    // Clear report recorded for the given level and id
    // on the given tab
    function forget_checker_reports($tab, level, id) {
        $tab.removeClass(level + id);

        // See if any other reports at the same level are extant,
        // otherwise remove the level class e.g. 'errors' or 'warnings'
        // This will remove th icon
        var i, cls = $tab.attr("class").split(/ +/);
        for (i = 0; i < cls.length; i++) {
            if (cls[i].startsWith(level + 'i-'))
                break;
        }
        if (i == cls.length)
            $tab.removeClass(level);

        var report_data = $tab.data('reports');
        report_data[level][id]--;
        if (report_data[level][id]) {
            delete report_data[level][id];
        }
        if (report_data[level].length === 0) {
            $tab.removeClass(level);
        }
    }

    // Record the existance of reports for the given level and
    // id in the given tab.
    function record_checker_reports($tab, level, id) {
        $tab.addClass(level + id);
        var report_data = $tab.data('reports');
        if (!report_data) {
            report_data = { errors: {}, warnings: {} };
            $tab.data('reports', report_data);
        }
        report_data[level][id] = true;
        $tab.addClass(level);
        // Make sure the tab is visible if it has an error or warning
        $tab.closest('li').addClass(level);
    }

    // Bubble reports up through the section hierarchy. Even if the
    // actual tab containing the erroneous item hasn't been opened
    // yet, this will annotate the tab that ultimately leads to it.
    function bubble_checker_reports(r, has) {
        var path = r.path.join(' > '),
            id = _id_ify(r.keys),
            sid, $whine;
           
        $.each(r.path, function(index, pel) {
            sid = _id_ify(pel);
            $.each(has, function (level, count) {
                if (count === 0 || level === 'notes' ) {
                    return;
                }

                // Annotate the tab with the existance of the report(s)
                // The count is irrelevant to the tab, as we don't show
                // it there.
                record_checker_reports( $('#TAB' + sid), level, id);

                // Annotate the tab report block with report details
                $('#REP' + sid)
                    .first()
                    .each(
                        function() {
                            var s = (count == 1) ?
                                level.substr(0, level.length - 1) : level;
                            $whine = $('<div>' + path + ' > ' + r.keys + ' has ' + count + ' ' + s + '</div>');
                            $whine.addClass(level);
                            $whine.addClass(id + '_report');
                            $(this).append($whine);
                        });
            });
        });
    }

    // Update the interface with check_current_value results.
    // Each result relates to a single configuration key, which is
    // annotated with the report detail. Tabs in the tab hierarchy
    // leading to the key are annotated as well, to indicate where
    // they include an error/warning.
   function checker_reports(results) {
        $('body').css('cursor','wait');

        $.each(results, function (index, r) {
            var $div, id, has, $reports, $whine;

            if (!r.keys) {
                // Report generic problems
                $div = $('<div id="report_dialog"></div>');
                $div.html(TML.render_reports(r.reports));
                $div.dialog({
                    modal: true,
                    width: 'auto',
                    minWidth: 390,
                    maxWidth: 700,
                    minHeight: 390,
                    maxHeight: 700,
                    buttons: {
                        Close: function() {
                            $div.dialog("close");
                            $div.remove();
                        }
                    },
                    close: function() {
                        $('body').css('cursor','auto');
                    }
                });
                return;
            }

            // Remove all existing reports related to this path
            id = _id_ify(r.keys);
            $('.' + id + '_report').remove();
            $('.errors' + id).each(function() {
                forget_checker_reports($(this), 'errors', id);
            });
            $('.warnings' + id).each(function() {
                forget_checker_reports($(this), 'warnings', id);
            });
            var $node = $('#' + id + '_block');

            // Remove the class that suppresses hidden_di and hidden_expert
            $node
                .removeClass('errors')
                .removeClass('warnings')
                .removeClass('notes');

            // Update the key block report (if it's there)
            has = { errors: 0, warnings: 0 };
            if (r.reports) {
                $reports = $('#REP' + id); // key block report is there
                $.each(r.reports, function(index, rep) {
                    has[rep.level]++;
                    // Add the message type to the key block
                    $('#' + id + '_block').addClass(rep.level);
                });
                if ($reports.length > 0) {
                    // Annotate the key block report
                    $whine = $("<div></div>");
                    $whine.html(TML.render_reports(r.reports));
                    $whine.addClass(id + '_report');
                    $whine.addClass('message_block');
                    $reports.append($whine);
                    if (r.hints && r.hints.reset_may_repair) {
                        // try resetting it, it might help
                        $node.data("value_handler").restoreDefaultValue();
                        // add modified flag
                        $node.addClass("value_modified");
                        update_save_button();
                    }
                }
                // If the key block isn't loaded yet,
                // bubble_checker_reports will annotate
                // the path leading to it
            }

            // Bubble the existance of reports up through
            // the section hierarchy
            if (has.errors + has.warnings > 0 && r.path) {
                bubble_checker_reports(r, has);
            }
        });

        $('body').css('cursor','auto');
    }

    // Perform a check on a single key node. If dep is true, then
    // check dependents as well
    function check_current_value($node, dep) {
        update_modified_default($node);

        var handler = $node.data('value_handler'),
            params = {
                keys: [ handler.spec.keys ],
                set: find_modified_values(),
                check_dependencies: dep
            };

        RPC('check_current_value',
            'Check: '+ handler.spec.keys,
            params,
            checker_reports,
            $node);
    }

    /*
      WIZARDS

      Wizard reports are handled by a modal dialog. A wizard
      may also repond with changes, which are applied to the
      elements they affect (and checked).
    */

    function wizard_started(params) {
        var id = params.wizard + '_' + params.method;
        var $dlg = $('#hogwarts');
        var $div = $('<div class="wiz"></div>');
        $div.addClass(id);
        $div.html( '<b>Waiting for the server, please be patient:</b><br/>');
        $div.append((params.wizard ? params.wizard + "/" : '')
                  + params.method + " is working");
        inline_whirly($div);
        $dlg.append($div);
        if (!$dlg.hasClass('ui-dialog-content')) {
            $dlg.dialog({
                title: "Active Wizards",
                width: 'auto'
            });
        } else if (!$dlg.dialog('isOpen'))
            $dlg.dialog('open');
    }

    function wizard_finished(params) {
        var id = params.wizard + '_' + params.method;
        var $dlg = $('#hogwarts');
        $dlg.find('.' + id).remove();
        if ($dlg.find('.wiz').length == 0) {
            $dlg.dialog('close');
        }
    }

    // Create a popup with reports, and apply changes
    function wizard_reports(params, $node, results) {
        var $div = $('<div class="message_block"></div>'),
            $dlg;

        $('body').css('cursor','wait');

        // Generate reports
        $div.html(TML.render_reports(results.messages));
        if (results.changes) {
            $.each(results.changes, function(key, value) {
                // Taken from render_tml.uncompressed.js - render verbatim blocks.
                var str = value;
                str = str.toString()
                         .replace(/&/g, "&amp;")
                         .replace(/</g, "&lt;")
                         .replace(/>/g, "&gt;");
                $div.append('<div class="changes">' + key + ' = ' + str + '</div>');
            });
        }

        // Enable any carry-on buttons we find
        $div.find('.wizard_button').each(function() {
            var data = $(this).data('wizard'), o, params;
            $(this).button().click(function() {
                var wiz;

                if (data.form) {
                    o = $.extend({}, data.args);
                    // Get wizard arguments from an optional form
                    $.each($(data.form).serializeArray(), function() {
                        if (o[this.name] !== undefined) {
                            if (!o[this.name].push) {
                                o[this.name] = [o[this.name]];
                            }
                            o[this.name].push(this.value || '');
                        } else {
                            o[this.name] = this.value || '';
                        }
                    });
                } else {
                    o = data.args;
                }
                params = {
                    wizard: data.wizard,
                    method: data.method,
                    args: o,
                    set: find_modified_values(),
                    cfgusername: $('#username').val(),
                    cfgpassword: $('#password').val()
                };
                wizard_started(params);
                RPC('wizard',
                    'Call ' + data.method,
                    params,
                    function(result) { wizard_reports(params, $node, result); },
                    $(this));
            });
        });

        // Reflect changed values back to the input elements and
        // run the checker on them
        $.each(results.changes, function(keys, value) {
            // Get the input for the keys, if it's there
            var spotted = false, pendid, $pending, handler;

            $('#' + _id_ify(keys))
                .closest('.node')
                .each(function() {
                    var $node = $(this),
                        handler = $node.data('value_handler');

                    handler.useVal(value);
                    spotted = true;
                    check_current_value($node, true);
                    $node.addClass("value_modified");
                });
            if (!spotted) {
                // It's not loaded yet, so record it for when it is
                pendid = 'pending' + _id_ify(keys);
                $pending = $('#' + pendid);

                if ($pending.length === 0) {
                    $pending = $('<div class="hidden_pending value_modified" id="' + pendid + '"></div>');
                    $('#root').append($pending);
                }
                handler = {
                    spec: { keys: keys },
                    currentValue: function() {
                        return value;
                    },
                    isDefault: function() { return true; },
                    isModified: function() { return true; },
                    commitVal: function() {
                        $pending.removeClass('value_modified');
                    }
                };
                $pending.data('value_handler', handler);
            }
        });

        update_save_button(results.hints.require_save);

        wizard_finished(params);

        $dlg = $('<div id="report_dialog"></div>');
        $dlg.append($div);
        $dlg.dialog({
            title: "Validation",
            width: 'auto',
            minWidth: 390,
            maxWidth: 700,
            minHeight: 390,
            maxHeight: 700,
            modal: true,
            buttons: {
                Close: function() {
                    $dlg.dialog("close");
                    $dlg.remove();
                }
            },
            close: function() {
                $('body').css('cursor','auto');
            }
        });
    }

    // Delegate for calling wizards once auth info is available
    function call_wizard($node, fb, $whirlyPlace) {
        var handler = $node.data('value_handler'),
            params = {
              wizard: fb.wizard,
              method: fb.method,
              keys: handler ? handler.spec.keys : '',
              set: find_modified_values(),
              cfgusername: $('#username').val(),
              cfgpassword: $('#password').val()
          };
        wizard_started(params);
        RPC('wizard',
            'Call ' + fb.method,
            params,
            function(result) { wizard_reports(params, $node, result); },
            $whirlyPlace);
    }

    /*
      UIs

      The UI for a key exists in two parts; first, there's the 'handler'.
      This is an abstract object created by the createUI method for the
      corresponding type in types.js. The handler has all the methods
      necessary for dealing with that generic type of value in an
      abstract way, and points to the $ui, which is the input, textarea,
      select or whatever is used to contain the value, and to the spec
      for the key.
      
      The second part of the UI is the 'node', which is the div
      that contains the ui element and other elements such as documentation,
      reports that are not specific to the handler type. This div is
      referred to as the node, and has css class 'node'.

      You access the handler from the node using the
      .data('value_handler'). This in turn points to the .$ui object.

      You can get to the node from the $ui by looking for
      .closest('.node')

      The UI for a tab is much simpler; jQuery tabs gives us a container
      for the contents, and an element for the tab itself. We can
      identify the tab using a unique key e.g. TABiGeneral-path-settings.
      We need this to be able to annotate report counts onto the tab.

      The actual tab page is contained in a div inside the jQuery
      container. This div has css class 'node' and carries .data('spec.entry')
      to refer to the corresponding spec node (unlike keys, indirection via
      a handler is not needed on sections). Within the div you can find
      a reports container e.g. REPiGeneral-path-settings and a container
      for the description. The rest of the div is filled with the key nodes
      and/or sub-tabs (sub-tabs always follow keys, if both are present).

      Where a wizard call has modified a value of an item that has not
      been loaded yet, a pending div is created to hold the value (search
      for 'pending')
    */

    // Create FEEDBACK controls for a key node
    function create_feedback(spec, fb, $node) {
        var $button;

        if (fb.method) {
            if (!fb.label) {
                fb.label = fb.method;
            }
            if (!fb.label) {
                fb.label = fb.wizard;
            }
            $button = $('<button class="feedback_button">' + fb.label + '</button>'); 
            if (fb.title) {
                $button.attr('title', fb.title);
            }
            var icon = fb.icon;
            if (!icon) {
                icon = "ui-icon-pencil";
            }
            $button.click(function() {
                if (fb.auth == 1) {
                    auth_action = function() {
                        call_wizard($node, fb, $node);
                    };
                    $('#auth_note').html(spec.title);
                    $('#auth_prompt').dialog(
                        'option', 'title',
                        fb.label + ' requires authentication');
                    $('#auth_prompt').dialog("open");
                } else {
                    call_wizard($node, fb, $node);
                }
            }).button({
              icon: icon
            });
            $node.find(".button_box").append($button);
        }
        else {
            console && console.debug("Useless FEEDBACK on " + spec.keys);
        }
    }

    // Load a key node UI
    function load_ui($node) {
        var spec = $node.data('spec.entry'),
            handler_class = spec.typename, // Create the handler
            handler, $ui, id, $butt, $button, pendid, $pending, $buttons;

        if (typeof(window.Types[handler_class]) !== "function") {
            handler_class = "BaseType";
        }
        handler = new window.Types[handler_class](spec);
        $node.data('value_handler', handler);

        $ui = handler.createUI(
            function() {
                update_modified_default($node);
                check_current_value($node, true);
            });
        $node.find(".ui-placeholder").replaceWith($ui);

        // Check for a pending value change from a wizard
        pendid = 'pending' + _id_ify(spec.keys);
        $pending = $('#' + pendid);
        if ($pending.length) {
            handler.useVal($pending.data('value_handler').currentValue());
            $pending.remove();
        }

        $buttons = $('<div class="button_box"></div>').insertAfter($ui);

        if (spec.CHECK.undefok === 1 && (spec.typename) != "BOOLEAN") {
            // If undefined is OK, then we add a checkbox that
            // needs to be clicked to see the value input.
            // if it isn't checked, the value is undefined; if it
            // is checked, then the value is at least ''. This
            // works for all types, but only really makes sense on
            // string types.
            $node.addClass('undefinedOK');
            id = 'UOK' + _id_ify(spec.keys);
            $butt = $('<input type="checkbox" id="' + id + '">').appendTo($buttons);
            $butt.click(function() {
                if ( $(this).attr("checked") ) {
                    $ui.removeAttr("disabled");
                    $node.removeClass("disabled");
                } else {
                    $ui.attr("disabled", "disabled");
                    $node.addClass("disabled");
                }
                update_modified_default( $node );
            });
            // Add a null_if handler to intercept the currentValue
            // of the keys (see types.js)
            handler.null_if = function () {
                return !$butt.attr("checked");
            };
            if (typeof(spec.current_value) == 'undefined' || spec.current_value === null) {
                $ui.attr("disabled", "disabled");
                $node.addClass("disabled");
            } else {
                $butt.attr("checked", "checked");
            }
            $butt.appendTo($buttons);
            $("<label for='"+id+"'> enable</label>")
              .attr("title", "If unchecked, " + spec.keys + " will be undefined. Check this box to give it a value.")
              .appendTo($buttons);
        }

        $button = $('<button class="undo_button control_button">undo</button>');
        $button.attr('title', 'Reset to configured value: ' + spec.current_value);
        $button.click(function() {
            handler.restoreCurrentValue();
            check_current_value($node, true);
        }).button({
            icon: "ui-icon-cancel"
        }).hide();
        $button.appendTo($buttons);

        $button = $('<button class="default_button control_button">reset</button>');
        $button.attr('title', 'Reset to default value: ' + spec['default']);
        $button.click(function() {
            handler.restoreDefaultValue();
            check_current_value($node, true);
        }).button({
            icon: "ui-icon-arrowrefresh-1-w"
        }).hide();
        $button.appendTo($buttons);

        if (spec.FEEDBACK) {
            $.each(spec.FEEDBACK, function(index, fb) {
                create_feedback(spec, fb, $node);
            });
        }

        // Attach handler to copy with the "visit site" button
        $('body').trigger("configurecreate", _id_ify(spec.keys));

        update_modified_default($node);
    }

    // Load the tab for a given section spec
    function load_tab(spec, $panel) {
        var $tab;

        if ($panel.hasClass('spec_loaded')) {
            return;
        }

        $tab = $('#TAB' + _id_ify(spec.headline));

        RPC('getspec',
            'Load: ' + spec.headline,
            {
                get : {
                    parent : {
                        depth: spec.depth,
                        headline : spec.headline
                    }
                },
                depth : 0
            },
            function(response) {
                var $node = $('<div class="node"></div>'),
                    $report;

                $panel.append($node);
                $panel.addClass('spec_loaded');
                if (spec.headline) {
                  $node.append("<h2>"+spec.headline+"</h2>");
                }

if (0) {
                // Clean off errors and warnings that were bubbled
                // up to here from higher level deep checks. We will
                // perform a deep check on this tab once it's open.
                $tab .removeClass('errors')
                    .removeClass('warnings');
                 // Duplicate the spec.entry here; it's the only way
                // to handle tab loading cleanly
                $node.data('spec.entry', spec);

                $report = $('<div class="reports"></div>');
                $report.attr('id', 'REP' + _id_ify(spec.headline));
                $node.append($report);
}

                if (spec.desc) {
                    add_desc(spec, $node);
                }

                load_section_specs(response, $node); /*SMELL load_section_specs is not defined yet */

                // Check all the keys under this node.
                RPC('check_current_value',
                    'Check: ' + spec.headline,
                    { keys : [ spec.headline ] },
                    checker_reports);
            },
            $panel
        );
    }

    // Get a canonical value for an input element identified by selector
    // Returns "1" if the selector doesn't identify an active element
    // Used to support DISPLAY_IF and ENABLE_IF
    function value_of(selector) {
        var $el = $(selector);
        if ($el.length === 0) {
            // Dependencies between elements in different panes are
            // generally a bad idea.
            throw selector + " has not been loaded yet";
        }
        if ($el.attr("type") == "checkbox") {
	    return $el.is(":checked");
        }
        return $el.val();
    }

    // Add a dependency to trigger a function when any of a set of
    // inputs associated with keys change. The keys are picked out of
    // a string e.r. "BLAH {This}{Key} and {That}{Key}" will bind handlers
    // to changes to {This}{Key} and {That}{Key}. Return the handler so
    // we can set up initial conditions when all specs have been loaded.
    // Used to support DISPLAY_IF and ENABLE_IF
    function add_dependency(test, $el, cb) {
        var name,
            keys = [],
            selector, handler;

        test = test.replace(/^(\w+)\s+/, function(str, p1, offset) {
            name = p1;
            return '';
        });
        // Replace each occurrence of a key string in the condition,
        test = test.replace(/((?:\{\w+\})+)/g, function(str, p1, offset) {
            // Identify the input for these keys
            selector = '#' + _id_ify(p1);
            keys.push(selector);
            // replace it with a JS call that will get the value of
            // the key. If the key has not bee loaded yet this will
            // throw an exception.
            return "value_of('" + selector + "')";
        });
        handler = function(event) {
            try {
                cb($el, eval('(' + test + ')') ? true : false); /* SMELL eval is evil */
            } catch (err) {
                console && console.debug(err);
            }
        };
        $.each(keys, function(index, k) {
            // Add a change handler so we know when the key value changes.
            // By using on() we will get the handler attached to elements
            // when they are loaded, even if they're not there yet.
            $(document).on("change", k, null, handler);
        });
        return handler;
    }

    // Add a description, splitting into summary and body if appropriate.
    function add_desc(entry, $node) {
        var m = /^((?:.|\n)*?\.)\s+((?:.|\n)+)$/.exec(entry.desc),
            $description, $more, $infob;

        if (m) {
            $description = $('<div class="description">' + TML.render(m[1]) + '&nbsp;</div>');
            $node.append($description);
            $more = $('<span class="closed">' + TML.render(m[2]) + '</span>');
            $infob = $('<a class="more">... more</a>');

            $infob.click(function() {
                if ($more.is(":visible")) {
                    $more.hide();
                    $infob.text("... more");
                } else {
                    $more.show();
                    $infob.text("... less");
                }
            });

            $description.append($more);
            $description.append($infob);

        } else {
            $node.append('<div class="description">' + TML.render(entry.desc) + '</div>');
        }
        $node.append();
    }

    // Create the DOM for a section from getspec entries
    function load_section_specs(entries, $section) {
        // Construct a value field for each key
        var on_ready = [],
            $children = null,
            $lis = null,
            created = {};

        $.each(entries, function(index, entry) {
            var label, $node, id, $report;

            if (entry.typename != "SECTION") {
                // It's a key

                // the load_ui class will trigger load_ui() later
                $node = $('<div class="node load_ui"></div>');
                $node.data('spec.entry', entry);
                if (entry.EXPERT && entry.EXPERT == 1) {
                    $node.addClass('expert');
                    if ($('#showExpert').attr('checked') !== 'checked') {
                        $node.addClass('hidden_expert');
                    }
                }
                if (typeof(entry.DISPLAY_IF) !== "undefined") {
                    on_ready.push(
                        add_dependency(
                            entry.DISPLAY_IF, $node, function ($n, tf) {
                                if (tf) {
                                    // Display if condition OK
                                    $n.removeClass('hidden_di');
                                } else {
                                    $n.addClass('hidden_di');
                                }
                            }));
                }
                if (typeof(entry.ENABLE_IF) !== "undefined") {
                    on_ready.push(
                        add_dependency(
                            entry.ENABLE_IF, $node, function($n, tf) {
                                if (tf) {
	                            $n.find("input,textarea").removeAttr('disabled');
                                } else {
	                            $n.find("input,textarea")
                                        .attr('disabled', 'disabled');
                                }
                            }));
                }

                if (typeof(entry.keys) !== "undefined") {
                    id = _id_ify(entry.keys);
                    $node.addClass("keyed");
                    if (entry.LABEL) {
                      label = '<b>'+entry.LABEL + ':</b><div class="keys">'+entry.keys+'</div>';
                    } else {
                      label = '<b>'+entry.keys + ':</b>';
                    }
                    $node.append('<div class="label">'+label+'</div><div class="ui-elem clearfix"><span class="ui-placeholder"></span></div>');

                } else if (entry.headline !== null) {
                    // unkeyed type e.g. BUTTON
                    id = _id_ify(entry.headline);
                }
                $node.attr('id', id + '_block');
                $report = $('<div class="reports"></div>');
                $report.attr('id', 'REP' + id);
                $node.append($report);
                if (entry.desc) {
                    add_desc(entry, $node);
                }
                if (entry.LABEL) {
                  //$node.append('<div class="keys">Key: <code>'+entry.keys+'</code></div>');
                }
                $section.append($node);
            }
        });

        // Construct tab entry for each (unique) child
        $.each(entries, function(index, entry) {
            if (entry.typename == "SECTION" && !created[entry.headline]) {
                created[entry.headline] = true;
                var $li = $('<li><a href="' +
                            // This URL could be anything; we're going to
                            // cancel it in the beforeLoad, below.
                            json_rpc_url +
                            '"><span class="tab" id="' +
                            'TAB' + _id_ify(entry.headline) + '">' +
                            entry.headline +
                            '</span></a></li>');
                if (entry.EXPERT && entry.EXPERT == 1) {
                    $li.addClass('expert');
                    if ($('#showExpert').attr('checked') !== 'checked') {
                        $li.addClass('hidden_expert');
                    }
                }
                $li.data('spec.entry', entry);
                if ($children === null) {
                    $children = $('<div></div>');
                    $section.append($children);
                    $lis = $('<ul></ul>');
                    $children.append($lis);
                }
                $lis.append($li);
            }
        });

        if ($children !== null) {
            // Construct the child tabs for the section
            $children.tabs({
                // Because we can't control the request sent by ui.tabs, we
                // have to intercept it before it's sent and substitute our
                // own load request.
                beforeLoad: function(event, ui) {
                    // Transfer the spec from the ul to the generated div
                    load_tab($(ui.tab).data('spec.entry'), $(ui.panel));
                    // Cancel the other request
                    return false;
                }
            });
            if ($section.is("#root")) {
              $children.addClass("ui-tabs-vertical ui-helper-clearfix");
            }
        }

        $section.find('.node.load_ui').each(function() {
            load_ui($(this).removeClass('load_ui'));
        });

        // Invoke any dependency handlers
        $.each(on_ready, function(index, handler) {
            handler.call();
        });
    }

    function search(term) {
      var $node = $('.searchResults'), $list, $title;

      $list = $node.find('ol').empty();
      $node.find(".errors").remove();
      $title = $node.find('.searchTitle').text("Searching for '" + term + "'");
      $node.slideDown();

      RPC('search',
        'Search: ' + term, {
          search: term
        },
        function(response) {
          var i, hit, l = response.length;
          if (l) {
            for (i = 0; i < l; i++) {
              hit = response[i].join(' > ');
              $list.append('<li>' + hit + '</li>');
            }
          } else {
            $("<div class='errors'>nothing found</div>").insertAfter($list);
            window.setTimeout(function() {
              $('.searchResults').slideUp();
            }, 1000);
          }
        },
        $title);
    }

    /*
      Main Program (I suppose you can call it that)
    */

    $(document).ready(function() {
        var $root = $('#root'), 
            bs = foswiki.getPreference('is_bootstrapped') === 'true';

        json_rpc_url = foswiki.getScriptUrlPath('jsonrpc');

        //init_whirly();

        if (!bs) {
            $('#bootstrap_warning').remove();
        }

        $('#auth_prompt').dialog({
            autoOpen: false,
            modal: true,
            buttons: {
                "Confirm": function () {
                    $('#auth_prompt').dialog( "close" );
                    auth_action();
                },
                Cancel: function() {
                    $('#auth_prompt').dialog( "close" );
                }
            }
        });

        $('#confirm_prompt').dialog({
            autoOpen: false,
            modal: true,
            buttons: {
                "Confirm": function () {
                    $('#confirm_prompt').dialog( "close" );
                    confirm_action();
                },
                Cancel: function() {
                    $('#confirm_prompt').dialog( "close" );
                }
            }
        });

/*
        $('#webCheckButton').button().click(function() {
             auth_action = function() {
                 var params = {
                     wizard: 'StudyWebserver',
                     method: 'report' };
                     wizard_started(params);
                 RPC('wizard',
                     'Study webserver',
                     params,
                     function(results) {
                         wizard_reports(params, $root, results);
                     },
                    $(this));
             };
            $('#auth_note').html($("#webCheckAuthMessage").html());
            $('#auth_prompt').dialog(
                'option', 'title', 'Webserver authentication');
            $('#auth_prompt').dialog("open");
        });
*/

        $('#closeSearchButton').button().click(function() {
            $('.searchResults').slideUp();
        });

        $('#searchButton').button({
          icon: "ui-icon-search",
          text: false
        }).click(function() {
          search($("#searchInput").val());
        });
        $("#searchInput").keypress(function(ev) {
          if (ev.which == 13) {
            search($(this).val());
          }
        });

        $('#showExpert').button({disabled: true});

        $('#visitSite').button();

        $('body').on("configurecreate", function(event, id) {
            if (id === 'i-DefaultUrlHost-'
                || id === 'i-ScriptUrlPath-'
                || id === 'i-ScriptSuffix-') {
                $('#' + id).change(function() {
                    var $vs = $('#visitSite');
                    var url = $('#i-DefaultUrlHost-').val()
                        + $('#i-ScriptUrlPath-').val()
                        + '/view'
                        + $('#i-ScriptSuffix-').val();
                    $('#visitSite')
                        .attr("href", url)
                        .text(url);
                });
            }
        });

        $('#saveButton').button({disabled: !bs}).click(function() {
            confirm_action = function() {
                var params = {
                    wizard: 'Save',
                    method: 'save',
                    set: find_modified_values()
                };
                wizard_started(params);
                RPC('wizard',
                    'Save',
                    params,
                    function(results) {
                        wizard_reports(params, $root, results);
                        var erc = 0;
                        $.each(results.messages, function(index, rep) {
                            if (rep.level == 'errors') {
                                erc += 1;
                            }
                        });
                        // No errors, commit the UI value to the spec
                        if (erc === 0) {
                            // Save was good, no longer in BS mode
                            $('#bootstrap_warning').remove();
                            // Commit the saved values to the UI
                            $('.value_modified').each(function() {
                                var handler = $(this).data('value_handler');
                                handler.commitVal();
                                update_modified_default($(this));
                                $(this).removeClass('value_modified');
                            });
                            $('#saveButton').button('disable');
                        }
                    },
                   $(this));
            };
            var changed = ':<ul>';
            if ($('#bootstrap_warning').length) {
                changed = " complete basic configuration" + changed;
            }
            $('.value_modified').each(function() {
                var handler = $(this).data('value_handler');
                changed += '<li>' + handler.spec.keys + '</li>';
            });
            changed += '</ul>';

            $('#confirm_note').html($('#saveMessage').html());
            $('#confirm_note').append(changed);
            $('#confirm_prompt').dialog(
                'option', 'title', 'Confirm save');
            $('#confirm_prompt').dialog("open");
        });

        $(document).tooltip({
          tooltipClass: 'info',
          show: {
            effect:'show',
            delay:500
          },
          hide: {
            effect:'hide',
            delay:200
          },
          track:true,
          position: {
            my: "left+15 top+15",
            at: "left bottom",
            collision: "flipfit"
          }
        });
        $('.help_button').each(function() {
            $(this).button({
                icon: $(this).attr("name"),
                text: false
            });
        });

        // Get all root entries
        RPC('getspec',
            'Load schema',
            { "get" : { "parent": { "depth" : 0 } }, "depth" : 0 },
            function(result) {
                $root.empty().removeClass("loading");
                load_section_specs(result, $root);

                $('#showExpert').change(function() {
                    if (this.checked) {
                        $('.expert').each(function() {
                            $(this).removeClass('hidden_expert');
                        });
                    } else {
                        $('.expert').each(function() {
                            $(this).addClass('hidden_expert');
                        });
                    }
                }).button('enable');

                // Check all keys under root
                RPC('check_current_value',
                    'Check all',
                    { keys : [] },
                    checker_reports
                );
            }
          );

       //$("#ui-tabs-9 .ui-tabs:first").livequery(function() {
       //   $(this).addClass("ui-tabs-vertical");
       // });
    });

    $(window).on('beforeunload', function() {
        if ($('.value_modified').length > 0) {
            var changed = '';
            if ($('#bootstrap_warning').length) {
                changed = " complete basic configuration\n";
            }
            $('.value_modified').each(function() {
                var handler = $(this).data('value_handler');
                changed += '   ' + handler.spec.keys + '\n';
            });
            return 'You have unsaved changes:\n' + changed +  'Are you really sure?\n';
        }
    });
})(jQuery);
