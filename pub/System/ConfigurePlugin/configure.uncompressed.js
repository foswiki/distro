/*
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2014 Foswiki Contributors. Foswiki Contributors
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
var json_rpc_url = "jsonrpc",
    jsonRpc_reqnum = 0,
    $FALSE = 0, // Required for eval()ing values from FW
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

    // Load a whirling wait image
    function create_whirly($node, loadType, message) {
        return $image; /* SMELL: $image not defined */
    }

    // Handler to open the documentation on a configuration item
    function toggle_description($node) {
        if ($node.hasClass("closed")) {
            $node.removeClass("closed");
            $node.addClass("open");
        } else {
            $node.removeClass("open");
            $node.addClass("closed");
        }
    }

    // Find all modified values, and return key-values
    function modified_values() {
        var set = {}, handler;

        $('.value_modified').each(function() {
            handler = $(this).data('value_handler');
            set[handler.spec.keys] = handler.currentValue();
        });
        return set;
    }

    function update_modified_default($node) {
        var handler = $node.data('value_handler');
        if (handler.isModified()) {
            $node.addClass("value_modified");
            $node.find('.undo_button').show();
            $('#saveButton').button("enable");
        } else {
            $node.removeClass("value_modified");
            $node.find('.undo_button').hide();
            if (!$('#saveButton').button("option", "disabled")
                && $('#bootstrap_warning').length == 0) {
                $('#saveButton').button('disable');
                $('.value_modified').first().each(function() {
                    $('#saveButton').button('enable');
                });
            }
        }

        if (handler.isDefault()) {
            $node.find('.default_button').hide();
        } else {
            $node.find('.default_button').show();
        }
    }

    // Make an RPC call
    function RPC(method, message, params, report, $node, whirly_type) {
        var rpcid = _id_ify(message) + '_' + jsonRpc_reqnum++, // Get an id to uniquely identify the request
            $whirly = $('<div class="whirly">' + message + '</div>'); // Add an activity whirly

        $whirly.attr('id', rpcid);
        $whirly.addClass(whirly_type);
        $node.append($whirly);

        console.debug("Sending " + rpcid);
        $.jsonRpc(
            json_rpc_url,
            {
                namespace: 'configure',
                method: method,
                id: rpcid,
                params: params,
                error: function(jsonResponse, textStatus, xhr) {
                    console.debug(rpcid + " failed");
                    $whirly.remove();
                    alert(jsonResponse.error.message);
                },
                success: function(jsonResponse, textStatus, xhr) {
                    console.debug(rpcid + " OK");
                    $whirly.remove();
                    report(jsonResponse.result);
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
                if (count === 0) {
                    return;
                }

                if (level != 'errors' && level != 'warnings') {
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
                            $whine = $('<div>' + path + ' > ' + r.keys + ' has ' + count + ' ' + level + '</div>');
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

            var id = _id_ify(r.keys),
                has, $reports, $whine;

            // Remove all existing reports related to these keys
            $('.' + id + '_report').remove();
            $('.errors' + id).each(function() {
                forget_checker_reports($(this), 'errors', id);
            });
            $('.warnings' + id).each(function() {
                forget_checker_reports($(this), 'warnings', id);
            });

            // Update the key block report (if it's there)
            has = { errors: 0, warnings: 0 };
            if (r.reports) {
                $reports = $('#REP' + id); // if it's there
                $.each(r.reports, function(index, rep) {
                    // An empty information message can be ignored
                    if (!(rep.level == 'notes' && rep.message == '')) {
                        if (rep.level == 'errors' || rep.level == 'warnings') {
                            has[rep.level]++;
                        }
                        if ($reports.length > 0) {
                            // If the key block isn't loaded,
                            // bubble_checker_reports will annotate
                            // the path leading to it
                            $whine = $('<div>' + rep.message + '</div>');
                            $whine.addClass(rep.level);
                            $whine.addClass(id + '_report');
                            $reports.append($whine);
                        }
                    }
                });
            }

            // Bubble the existance of reports up through
            // the section hierarchy
            if (has.errors + has.warnings > 0 && r.path) {
                bubble_checker_reports(r, has);
            }
        });

        $('body').css('cursor','auto');
    }

    // Perform a check on a single key node
    function check_current_value($node) {
        update_modified_default($node);

        var handler = $node.data('value_handler'),
            params = {
              keys: [ handler.spec.keys ],
              set: modified_values()
            };

        RPC('check_current_value',
            'Check: '+ handler.spec.keys,
            params,
            checker_reports,
            $node, 'check' );
    }

    /*
      WIZARDS

      Wizard reports are handled by a modal dialog. A wizard
      may also repond with changes, which are applied to the
      elements they affect (and checked).
    */

    // Create a popup with reports, and apply changes
    function wizard_reports(results) {
        $('body').css('cursor','wait');
        // Generate reports
        var $div = $('<div id="report_dialog"></div>');
        $.each(results.report, function(index, rep) {
            var $whine = $('<div>' + rep.message + '</div>');
            $whine.addClass(rep.level);
            $div.append($whine);
        });
        // Reflect changed values back to the input elements and
        // run the checker on them
        $.each(results.changes, function(keys, value) {
            // Get the input for the keys, if it's there
            $('#' + _id_ify(keys))
                .closest('.node')
                .each(function() {
                    var $node = $(this),
                        handler = $node.data('value_handler');

                    handler.useVal(value);
                    // Fire off checker
                    check_current_value($node);
                });
        });
        $div.dialog({
            width: '60%',
            modal: true,
            buttons: {
                Ok: function() {
                    $div.dialog("close");
                    $div.remove();
                    $('body').css('cursor','auto');
                }
            }
        });
    }

    // Delegate for calling wizards once auth info is available
    function call_wizard($node, fb) {
        var handler = $node.data('value_handler'), 
            params = {
              wizard: fb.wizard,
              keys: handler.spec.keys,
              method: fb.method,
              set: modified_values(),
              cfgusername: $('#username').val(),
              cfgpassword: $('#password').val()
          };

        RPC('wizard',
            'Call ' + fb.method,
            params,
            wizard_reports,
            $node, 'check');
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
            if (spec.title === null) {
                spec.title = fb.label;
            }
            $button.attr('title', spec.title);
            $button.click(function() {
                if (fb.auth == 1) {
                    auth_action = function() {
                        call_wizard($node, fb);
                    };
                    $('#auth_note').html(spec.title);
                    $('#auth_prompt').dialog(
                        'option', 'title',
                        fb.label + ' requires authentication');
                    $('#auth_prompt').dialog("open");
                } else {
                    call_wizard($node, fb);
                }
            }).button();
            $node.append($button);
        }
        else {
            console.debug("Useless FEEDBACK on " + spec.keys);
        }
    }

    // Load a key node UI
    function load_ui($node) {
        var spec = $node.data('spec.entry'),
            handler_class = spec.typename, // Create the handler
            handler, $ui, id, $butt, $button;

        if (typeof(window.Types[handler_class]) !== "function") {
            handler_class = "BaseType";
        }
        handler = new window.Types[handler_class](spec);
        $node.data('value_handler', handler);

        $ui = handler.createUI(
            function() {
                update_modified_default($node);
                check_current_value($node);
            });
        $node.append($ui);

        if (spec.UNDEFINEDOK == 1) {
            // If undefined is OK, then we add a checkbox that
            // needs to be clicked to see the value input.
            // if it isn't checked, the value is undefined; if it
            // is checked, then the value is at least ''. This
            // works for all types, but only really makes sense on
            // string types.
            $node.addClass('undefinedOK');
            id = 'UOK' + _id_ify(spec.keys);
            $node.append("<label for='"+id+"'></label>");
            $butt = $('<input type="checkbox" id="' + id + '">');
            $butt.attr("title", "Enable this option to take a value");
            $butt.click(function() {
                if ( $(this).attr("checked") ) {
                    $ui.show();
                } else {
                    $ui.hide();
                }
                update_modified_default( $node );
            }).show();
            // Add a null_if handler to intercent the currentValue
            // of the keys (see types.js)
            handler.null_if = function () {
                return !$butt.attr("checked");
            };
            if (typeof(spec.current_value) == 'undefined' || spec.current_value === null) {
                $ui.hide();
            } else {
                $butt.attr("checked", "checked");
            }
            $ui.before($butt);
        }

        $button = $('<button class="undo_button control_button"></button>');
        $button.attr('title', 'Reset to configured value: ' + spec.current_value);
        $button.click(function() {
            handler.restoreCurrentValue();
            check_current_value($node);
        }).button({
            icons: {
                primary: "undo-icon"
            },
            text: false
        }).hide();
        $node.append($button);

        $button = $('<button class="default_button control_button"></button>');
        $button.attr('title', 'Reset to default value: ' + spec['default']);
        $button.click(function() {
            handler.restoreDefaultValue();
            check_current_value($node);
        }).button({
            icons: {
                primary: "default-icon"
            },
            text: false
        }).hide();
        $node.append($button);

        if (spec.FEEDBACK) {
            $.each(spec.FEEDBACK, function(index, fb) {
                create_feedback(spec, fb, $node);
            });
        }

        update_modified_default($node);
    }

    // Load the tab for a given section spec
    function load_tab(spec, $panel) {
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
                    $tab, $report;

                $panel.append($node);

                // Clean off errors and warnings that were bubbled
                // up to here from higher level deep checks. We will
                // perform a deep check on this tab once it's open.
                $tab = $('#TAB' + _id_ify(spec.headline));
                $tab .removeClass('errors')
                    .removeClass('warnings');
                 // Duplicate the spec.entry here; it's the only way
                // to handle tab loading cleanly
                $node.data('spec.entry', spec);

                $report = $('<div class="reports"></div>');
                $report.attr('id', 'REP' + _id_ify(spec.headline));
                $node.append($report);

                if (spec.desc) {
                    $node.append('<div class="description">' + spec.desc + '</div>');
                }
                load_section_specs(response, $node); /*SMELL load_section_specs is not defined */
                // Call to check all the *known* keys under this node. Keys
                // that are currently missing from the UI (because they have
                // not been loaded yet) will not be checked.
                //var to_do = [];
                //$node.find('.node.keyed').each(function() {
                //    var spec = $(this).data('spec.entry');
                //    to_do.push(spec.keys);
                //});
                RPC('check_current_value',
                    'Check: ' + spec.headline,
                    { keys : [ spec.headline ] },
                    checker_reports,
                    $panel, 'check');
            },
            $panel, 'load'
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
                console.debug(err);
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

    // Create the DOM for a section from getspec entries
    function load_section_specs(entries, $section) {
        // Construct a value field for each key
        var on_ready = [],
            $children = null,
            $lis = null,
            created = {};

        $.each(entries, function(index, entry) {
            var label, $node, id, $head, $infob, $report;

            if (entry.typename != "SECTION") {
                // It's a key

                // the load_ui class will trigger load_ui() later
                $node = $('<div class="node load_ui closed"></div>');
                $node.data('spec.entry', entry);
                if (entry.EXPERT && entry.EXPERT == 1) {
                    $node.addClass('expert');
                    $node.addClass('hidden_expert');
                }
                label = entry.LABEL;
                if (typeof(entry.DISPLAY_IF) !== "undefined") {
                    on_ready.push(
                        add_dependency(
                            entry.DISPLAY_IF, $node, function ($n, tf) {
                                if (tf) {
                                    // Display if not expert
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
                    if (!label) {
                        label = entry.keys;
                    }
                    $head = $('<div class="keys">' + label + '</div>');
                    $node.append($head);
                    if (entry.desc) {
                        $infob = $('<button class="control_button"></button>');
                        $head.prepend($infob);
                        $infob.click(function() {
                            toggle_description($(this).closest('.keyed'));
                        }).button({
                            icons: {
                                primary: "info-icon"
                            },
                            text: false
                        });
                    }
                } else if (entry.headline !== null) {
                    // unkeyed type e.g. BUTTON
                    id = _id_ify(entry.headline);
                }
                $node.attr('id', id + '_block');
                $report = $('<div class="reports"></div>');
                $report.attr('id', 'REP' + id);
                $node.append($report);
                if (entry.desc) {
                    $node.append('<div class="description">' + entry.desc + '</div>');
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
                           entry.headline + '</span></a></li>');
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
        }

        $section.find('.node.load_ui').each(function() {
            load_ui($(this).removeClass('load_ui'));
        });

       // Invoke any dependency handlers
        $.each(on_ready, function(index, handler) {
            handler.call();
        });
    }

    /*
      Main Program (I suppose you can call it that)
    */

    $(document).ready(function() {
        var $root = $('#root');

        var bs = foswiki.getPreference('is_bootstrapped') === 'true';

        if (!bs)
            $('#bootstrap_warning').remove();

        $('#auth_prompt').dialog({
            autoOpen: false,
            height: 300,
            width: 400,
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
            height: 300,
            width: 400,
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

        $('#webCheckButton').button().click(function() {
             auth_action = function() {
                 var params = {
                     wizard: 'StudyWebserver',
                     method: 'report' };
                 RPC('wizard',
                     'Study webserver',
                     params,
                     function(results) {
                         wizard_reports(results);
                     },
                     $root, 'check');
             };
            $('#auth_note').html($("#webCheckAuthMessage").html());
            $('#auth_prompt').dialog(
                'option', 'title', 'Webserver authentication');
            $('#auth_prompt').dialog("open");
        });

        $('#showExpert').button();

        $('#saveButton').button({disabled: !bs}).click(function() {
            // SMELL: Save wizard v.s. changecfg in ConfigurePlugin
            confirm_action = function() {
                var params = {
                    wizard: 'Save',
                    method: 'save',
                    set: modified_values()
                };

                RPC('wizard',
                    'Save',
                    params,
                    function(results) {
                        wizard_reports(results);
                        var erc = 0;
                        $.each(results.report, function(index, rep) {
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
                            });
                            $('#saveButton').button('disable');
                        }
                    },
                    $root, 'load');
            };
            var changed = ':<ul>';
            if ($('#bootstrap_warning').length)
                changed = " complete basic configuration" + changed;
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

        $(document).tooltip();
        $('.help_button').each(function() {
            $(this).button({
                icons: {
                    primary: $(this).attr("name")
                },
                text: false
            });
        });

        // Get all root entries
        RPC('getspec',
            'Load schema',
            { "get" : { "parent": { "depth" : 0 } }, "depth" : 0 },
            function(result) {
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
                }).removeAttr('disabled');

                // Check all keys under root
                RPC('check_current_value',
                    'Check all',
                    { keys : [] },
                    checker_reports,
                    $root, 'check' );
            },
            $root, 'load');
    });

    $(window).on('beforeunload', function() {
        if ($('.value_modified').length > 0) {
            return "You have unsaved changes";
        }
        return 'Are you really sure?';
    });

})(jQuery);
