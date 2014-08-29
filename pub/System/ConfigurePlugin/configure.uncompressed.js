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
var json_rpc_url = "jsonrpc";
var reqnum = 0;
// Required for eval()ing values from FW
var $FALSE = 0;
var $TRUE = 1;

(function($) {
    var auth_action = function() {};
    var confirm_action = function() {};

    function requestID(s) {
        var rid = _id_ify(s) + '_' + reqnum++;
        console.debug("Sending " + rid);
        return rid;
    }

    // Load a whirling wait image
    function createWhirly($node, loadType, atStart) {
        var $image = $('<div class="whirly ' + loadType + 'Whirly" ></div>');
        if (atStart)
            $node.prepend($image);
        else
            $node.append($image);
        return $image;
    }

    // Find all modified values, and return key-values
    function modified_values() {
        var set = {};
        $('.value_modified').each(function() {
            var handler = $(this).data('value_handler');
            set[handler.spec.keys] = handler.currentValue();
        });
        return set;
    }

    // Make an RPC call
    function RPC(method, rid, params, report, $whirly) {
        $.jsonRpc(
            json_rpc_url,
            {
                namespace: 'configure',
                method: method,
                id: requestID(rid),
                params: params,
                error: function(jsonResponse, textStatus, xhr) {
                    if ($whirly)
                        $whirly.remove();
                    alert(jsonResponse.error.message);
                },
                success: function(jsonResponse, textStatus, xhr) {
                    if ($whirly)
                        $whirly.remove();
                    report(jsonResponse.result);
                }
            });
    }

    // Update the interface with check_current_value results.
    // Each result relates to a single configuration key, which is
    // annotated with the report detail. Tabs in the tab hierarchy
    // leading to the key are annotated as well, to indicate where
    // they include an error/warning.
    function update_reports(results) {
        $('body').css('cursor','wait');
        var refresh_tabs = {};

        $.each(results, function (index, r) {
            var id = _id_ify(r.keys);

            // Remove all existing reports related to these keys
            // This will remove all errors, notes etc.
            $('.' + id + '_report').remove();

            // Update the key block report
            var has = { errors: 0, warnings: 0 };
            if (r.reports) {
                var $reports = $('#REP' + id);
                $.each(r.reports, function(index, rep) {
                    // An empty information message can be ignored
                    if (!(rep.level == 'notes' && rep.message == '')) {
                        if (rep.level == 'errors' || rep.level == 'warnings')
                            has[rep.level]++;
                        var $whine = $('<div>' + rep.message + '</div>');
                        $whine.addClass(rep.level);
                        $whine.addClass(id + '_report');
                        $reports.append($whine);
                    }
                });
            }

            // Bubble the existance of reports up through
            // the section hierarchy
            if (has.errors + has.warnings > 0 && r.path) {
                var path = r.path.join(' > ');

                $.each(r.path, function(index, pel) {
                    var sid = _id_ify(pel);
                    if (!refresh_tabs[sid])
                        refresh_tabs[sid] = {};
                    $.each(has, function (level, count) {
                        if (count > 0) {
                            $('#REP' + sid)
                                .first()
                                .each(
                                    function() {
                                        var $whine = $('<div>' + path + ' > '
                                                       + r.keys
                                                       + ' has '
                                                       + count + ' '
                                                       + level
                                                       + '</div>');
                                        $whine.addClass(level);
                                        $whine.addClass(id + '_report');
                                        $(this).append($whine);
                                        if (!refresh_tabs[sid][level])
                                            refresh_tabs[sid][level] = count;
                                        else
                                            refresh_tabs[sid][level] += count;
                                    });
                        }
                    });
                });
            }
        });

        // Refresh the tab element
        $.each(refresh_tabs, function(id, has) {
            var $tab = $('#TAB' + id);
            if ($tab) {
                $tab.removeClass('warnings').removeClass('errors');
                if (has['warnings'] > 0)
                    $tab.addClass('warnings');
                if (has['errors'] > 0)
                    $tab.addClass('errors');
            }
        });
        $('body').css('cursor','auto');
    }

    // Create a popup with reports
    function wizard_reports(results) {
        $('body').css('cursor','wait');
        // Generate reports
        var $div = $('<div id="report_dialog"></div>');
        $.each(results.report, function(index, rep) {
            var $whine = $('<div>' + rep.message + '</div>');
            $whine.addClass(rep.level);
            $div.append($whine);
        });
        // Reflect changed values back to the input elements
        $.each(results.changes, function(keys, value) {
            // Get the input for the keys, if it's there
            var $input = $('#' + _id_ify(keys));
            $input.each(function() {
                $(this).attr('value', value);
                update_modified_default($(this).closest('div.node'));
            })
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

    function update_modified_default($node) {
        var handler = $node.data('value_handler');
        if (handler.isModified()) {
            $node.addClass("value_modified");
            $node.find('.undo_button').show();
            $('#saveButton').button("enable");
        } else {
            $node.removeClass("value_modified");
            $node.find('.undo_button').hide();
            if (!$('#saveButton').button("option", "disabled")) {
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

    // Performs a check on a key
    function check_current_value($node) {
        update_modified_default($node);

        var handler = $node.data('value_handler');
        var params = {
            keys: [ handler.spec.keys ],
            set: modified_values()
        };

        RPC('check_current_value',
            'ccv' + handler.spec.keys,
            params,
            update_reports,
            createWhirly($node, 'check') );
    }

    // Delegate for calling wizards once auth info is available
    function call_wizard($node, fb) {
        var handler = $node.data('value_handler');
        var params = {
            wizard: fb.wizard,
            keys: handler.spec.keys,
            method: fb.method,
            set: modified_values(),
            cfgusername: $('#username').val(),
            cfgpassword: $('#password').val()
        };

        RPC('wizard',
            'cw' + handler.spec.keys,
            params,
            wizard_reports,
            createWhirly($node, 'check'));
    }

    // Load all the value UIs for the key nodes under an element
    function load_value_uis($node) {
        $node.find('.node.valued').each(function() {
            var $key = $(this);
            $key.removeClass('valued');
            var spec = $key.data('spec.entry');
            var handler_class = spec.typename;
            if (!(typeof(window['Types'][handler_class]) === "function"))
                handler_class = "BaseType";
            var handler = new window['Types'][handler_class](spec);
            $key.data('value_handler', handler);

            var $ui = handler.createUI(
                function() {
                    update_modified_default($key);
                    check_current_value($key);
                });
            $key.append($ui);

            if (spec.UNDEFINEDOK == 1) {
                // If undefined is OK, then we add a checkbox that
                // needs to be clicked to see the value input.
                // if it isn't checked, the value is undefined; if it
                // is checked, then the value is at least ''. This
                // works for all types, but only really makes sense on
                // string types.
                $node.addClass('undefinedOK');
                var id = 'UOK' + _id_ify(spec.keys);
                $key.append("<label for='"+id+"'></label>");
                var $butt = $('<input type="checkbox" id="' + id
                              + '">');
                $butt.attr("title", "Enable this option to take a value");
                $butt.click(function() {
                    if ( $(this).attr("checked") )
                        $ui.show();
                    else
                        $ui.hide();
                    update_modified_default( $key );
                }).show();
                // Add a null_if handler to intercent the currentValue
                // of the keys (see types.js)
                handler.null_if = function () {
                    return !$butt.attr("checked");
                }
                if (typeof(spec.current_value) == 'undefined'
                    || spec.current_value == null) {
                    $ui.hide();
                } else {
                    $butt.attr("checked", "checked");
                }
                $ui.before($butt);
            }

            var $button = $('<button class="undo_button control_button"></button>');
            $button.attr('title', 'Reset to configured value: '
                         + spec.current_value);
            $button.click(function() {
                handler.restoreCurrentValue();
                check_current_value($key);
            }).button({
                icons: {
                    primary: "undo-icon"
                },
                text: false
            }).hide();
            $key.append($button);

            $button = $('<button class="default_button control_button"></button>');
            $button.attr('title', 'Reset to default value: ' + spec.default);
            $button.click(function() {
                handler.restoreDefaultValue();
                check_current_value($key);
            }).button({
                icons: {
                    primary: "default-icon"
                },
                text: false
            }).hide();
            $key.append($button);

            if (spec.FEEDBACK)
                $.each(spec.FEEDBACK, function(index, fb) {
                    var onClick;
                    if (fb.method) {
                        if (!fb.label)
                            fb.label = fb.method;
                        if (!fb.label)
                            fb.label = fb.wizard;
                        $button = $('<button class="feedback_button">'
                                    + fb.label + '</button>');
                        if (spec.title == null)
                            spec.title = fb.label;
                        $button.attr('title', spec.title);
                        $button.click(function() {
                            if (fb.auth == 1) {
                                auth_action = function() {
                                    call_wizard($key, fb);
                                };
                                $('#auth_note').html(spec.title);
                                $('#auth_prompt').dialog(
                                    'option', 'title',
                                    fb.label + ' requires authentication');
                                $('#auth_prompt').dialog("open");
                            } else
                                call_wizard($key, fb);
                        }).button();
                        $key.append($button);
                    }
                    else {
                        console.debug("Useless FEEDBACK on " + spec.keys);
                    }
                });

            update_modified_default($key);
        });
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

    // Load the tab for a given section spec
    function load_tab(spec, $node) {
        if ($node.data('spec.entry'))
            return;
        $node.data('spec.entry', spec);
        RPC('getspec',
            spec.headline,
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
                var $report = $('<div class="reports"></div>');
                $report.attr('id', 'REP' + _id_ify(spec.headline));
                $node.append($report);

                if (spec.desc) {
                    $node.append('<div class="description">'
                                 + spec.desc + '</div>');
                }
                load_section_specs(response, $node);
                // Call to check all the *known* keys under this node. Keys
                // that are currently missing from the UI (because they have
                // not been loaded yet) will not be checked.
                var to_do = [];
                $node.find('.node.keyed').each(function() {
                    var spec = $(this).data('spec.entry');
                    to_do.push(spec.keys);
                });
                RPC('check_current_value',
                    'checkLoadedKeys',
                    { keys : to_do },
                    update_reports,
                    createWhirly($node, 'check') );
            }
        );
    }

    // Get a canonical value for an input element identified by selector
    // Returns "1" if the selector doesn't identify an active element
    function value_of(selector) {
        var $el = $(selector);
        if ($el.length == 0) {
            // Dependencies between elements in different panes are
            // generally a bad idea.
            throw selector + " has not been loaded yet";
        }
        if ($el.attr("type") == "checkbox")
	    return $el.is(":checked");
        return $el.val();
    }

    // Add a dependency to trigger a function when any of a set of
    // inputs associated with keys change. The keys are picked out of
    // a string e.r. "BLAH {This}{Key} and {That}{Key}" will bind handlers
    // to changes to {This}{Key} and {That}{Key}. Return the handler so
    // we can set up initial conditions when all specs have been loaded.
    function add_dependency(test, $el, cb) {
        var name;
        test = test.replace(/^(\w+)\s+/, function(str, p1, offset) {
            name = p1;
            return '';
        });
        var keys = [];
        // Replace each occurrence of a key string in the condition,
 	test = test.replace(/((?:{\w+})+)/g, function(str, p1, offset) {
            // Identify the input for these keys
            var selector = '#' + _id_ify(p1);
            keys.push(selector);
            // replace it with a JS call that will get the value of
            // the key. If the key has not bee loaded yet this will
            // throw an exception.
            return "value_of('" + selector + "')";
        });
        var handler = function(event) {
            try {
                cb($el, eval('(' + test + ')') ? true : false);
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
    };

    // Create the DOM for a section from getspec entries
    function load_section_specs(entries, $section) {
        // Construct a value field for each key
        var on_ready = [];
        $.each(entries, function(index, entry) {
            var label;
            if (entry.typename != "SECTION") {
                var $node = $('<div class="node valued closed"></div>');
                $node.data('spec.entry', entry);
                if (entry.EXPERT && entry.EXPERT == 1) {
                    $node.addClass('expert');
                    $node.addClass('hidden_expert');
                }
                var label = entry.LABEL;
                if (entry.DISPLAY_IF != null)
                    on_ready.push(
                        add_dependency(
                            entry.DISPLAY_IF, $node, function ($n, tf) {
                                if (tf) {
                                    // Display if not expert
                                    $n.removeClass('hidden_di');
                                } else
                                    $n.addClass('hidden_di');
                            }));
                if (entry.ENABLE_IF != null)
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

                var id;

                if (entry.keys != null) {
                    id = _id_ify(entry.keys);
                    $node.addClass("keyed");
                    if (!label)
                        label = entry.keys;
                    var $head = $('<div class="keys">' + label + '</div>');
                    $node.append($head);
                    if (entry.desc) {
                        var $infob = $('<button class="control_button"></button>');
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
                } else if (entry.headline != null) {
                    // unkeyed type e.g. BUTTON
                    id = _id_ify(entry.headline);
                }
                $node.attr('id', id + '_block');
                var $report = $('<div class="reports"></div>');
                $report.attr('id', 'REP' + id);
                $node.append($report);
                if (entry.desc) {
                    $node.append('<div class="description">'
                                  + entry.desc + '</div>');
                }
                $section.append($node);
            }
        });

        // Construct tab entry for each (unique) child
        var $children = null;
        var $lis = null;
        var created = {};
        $.each(entries, function(index, entry) {
            if (entry.typename == "SECTION" && !created[entry.headline]) {
                created[entry.headline] = true;
                var $li = $('<li><a href="'
                           // This URL could be anything; we're going to
                           // cancel it in the beforeLoad, below.
                           + json_rpc_url
                           + '"><span class="tab" id="'
                           + 'TAB' + _id_ify(entry.headline) + '">'
                           + entry.headline + '</span></a></li>');
                $li.data('spec.entry', entry);
                if ($children == null) {
                    $children = $('<div></div>');
                    $section.append($children);
                    $lis = $('<ul></ul>');
                    $children.append($lis);
                }
                $lis.append($li);
            }
        });

        if ($children != null) {
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

        load_value_uis($section);

       // Invoke any dependency handlers
        $.each(on_ready, function(index, handler) {
            handler.call();
        });
    }

    $(document).ready(function() {
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
                     'wsreport',
                     params,
                     function(results) {
                         wizard_reports(results);
                     },
                     createWhirly($('#root'), 'load'));
             };
            $('#auth_note').html($("#webCheckAuthMessage").html());
            $('#auth_prompt').dialog(
                'option', 'title', 'Webserver authentication');
            $('#auth_prompt').dialog("open");
        });

        $('#showExpert').button();

        $('#saveButton').button({disabled: true}).click(function() {
            // SMELL: Save wizard v.s. changecfg in ConfigurePlugin
            confirm_action = function() {
                var params = {
                    wizard: 'Save',
                    method: 'save',
                    set: modified_values()
                };

                RPC('wizard',
                    'save',
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
                        if (erc == 0) {
                            $('.value_modified').each(function() {
                                var handler = $(this).data('value_handler');
                                handler.commitVal();
                                update_modified_default($(this));
                            });
                        }
                    },
                    createWhirly($('#root'), 'load'));
            };
            var changed = '';
            $('.value_modified').each(function() {
                var handler = $(this).data('value_handler');
                changed += handler.spec.keys + ' ';
            });
 
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
            'rootSpec',
            { "get" : { "parent": { "depth" : 0 } }, "depth" : 0 },
            function(result) {
                load_section_specs(result, $('#root'));

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
                    'deepCheck',
                    { keys : [] },
                    update_reports,
                    createWhirly($('#root'), 'check') );
            },
            createWhirly($('#root'), 'load'));
    });

    $(window).on('beforeunload', function() {
        if ($('.value_modified').length > 0)
            return "You have unsaved changes";
        return 'Are you really sure?';
    });

})(jQuery);

