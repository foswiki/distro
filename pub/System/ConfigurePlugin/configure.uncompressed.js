/*
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
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
var json_rpc_url = "../../../bin/jsonrpc";
var reqnum = 0;

var main = function($) {

    function requestID(s) {
        var rid = _id_ify(s) + '_' + reqnum++;
        console.debug("Sending " + rid);
        return rid;
    }

    // Load a whirling wait image
    function createWhirly($node, loadType, atStart) {
        var $image = $('<img src="' + loadType + 'Whirly.gif" alt="'
                      + loadType + '"/>');
        if (atStart)
            $node.prepend($image);
        else
            $node.append($image);
        return $image;
    }

    // Update the interface with check results.
    // Each result relates to a single configuration key, which is
    // annotated with the report detail. Tabs in the tab hierarchy
    // leading to the key are annotated as well, to indicate where
    // they include an error/warning.
    function update_reports(results) {
        $('body').css('cursor','wait');
        var refresh_tabs = {};
        for (var i = 0; i < results.length; i++) {
            var r = results[i];
            var id = _id_ify(r.keys);
            var has = [];

            // Remove all existing reports related to these keys
            $('.' + id + '_report').remove();

            // First update the key block report
            // An empty information message can be ignored
            if (!(r.level == 'information' && r.message == '')) {
                has[r.level] = true;
                var $reports = $('#' + id + '_reports');
                var $whine = $('<div>' + r.message + '</div>');
                $whine.addClass(r.level);
                $whine.addClass(id + '_report');
                $reports.append($whine);
            }

            if (r.sections) {
                // Bubble the existance of this report up through
                // the hierarchy, by following the chain of reports
                var path = r.sections.join(' > ');
                for (var j = 0; j < r.sections.length; j++) {
                    var sid = _id_ify(r.sections[j]);
                    var $section = $('#' + sid + '_reports').first(
                        function() {
                            var $whine = $('<div>' + path + ' > ' + r.keys
                                           + ' has ' + r.level + '</div>');
                            $whine.addClass(r.level);
                            $whine.addClass(id + '_report');
                            $(this).append(whine);
                        });
                    refresh_tabs[sid] = has;
                }
            }
        }
        // Refresh the tab element
        $.each(refresh_tabs, function(id, has) {
            var $tab = $('#' + id + '_tab');
            if ($tab) {
                $tab.removeClass('warnings').removeClass('errors');
                if (has['warnings'])
                    $tab.addClass('warnings');
                if (has['errors'])
                    $tab.addClass('errors');
            }
        });
        $('body').css('cursor','auto');
    }

    // Performs a check on a key to decide whether to display
    // reset/default controls
    function checkModified($node, noCheck) {
        var handler = $node.data('value_handler');
        if (handler.isModified())
            $node.addClass("value_modified");
        else
            $node.removeClass("value_modified");

        if (handler.isDefault())
            $node.addClass("value_default");
        else
            $node.removeClass("value_default");

        if (noCheck)
            return;

        var val = handler.currentValue();
        var params = {};
        params[handler.spec.keys] = val;

        var whirly = createWhirly($node, 'check', false);
        var rid = requestID("modify" + _id_ify(handler.spec.keys));
        $.jsonRpc(
            json_rpc_url,
            {
                namespace: "configure",
                method: "check",
                id: rid,
                params: params,
                error: function(jsonResponse, textStatus, xhr) {
                    whirly.remove();
                    alert(jsonResponse.error.message);
                },
                success: function(jsonResponse, textStatus, xhr) {
                    update_reports(jsonResponse.result);
                    whirly.remove();
                }
            });
    }

    function checkKeys(keys, $node, noWhirly) {
        var $whirly;
        if (!noWhirly)
            $whirly = createWhirly($node, 'check', true);
        var rid = requestID("checkKeys");
        $.jsonRpc(
            json_rpc_url,
            {
                namespace: "configure",
                method: "check",
                id: rid,
                params: keys,
                error: function(jsonResponse, textStatus, xhr) {
                    if ($whirly)
                        $whirly.remove();
                    alert(jsonResponse.error.message);
                },
                success: function(jsonResponse, textStatus, xhr) {
                    if ($whirly)
                        $whirly.remove();
                    update_reports(jsonResponse.result);
                }
            });
    }

    // Call to check all the *known* keys under this node. Keys
    // that are currently missing from the UI (because they have
    // not been loaded yet) will not be checked.
    function checkLoadedKeys($node) {
        var to_do = {};
        $node.find('.node.keyed').each(function() {
            var spec = $(this).data('spec.entry');
            to_do[spec.keys] = null;
        });
        checkKeys(to_do, $node);
    }

    // Load all the value UIs for the key nodes under an element
    function load_value_uis($node) {
        $node.find('.node.valued').each(function() {
            var $key = $(this);
            $key.removeClass('valued');
            var spec = $key.data('spec.entry');
            var handler_class = spec.type;
            if (!(typeof(window['Types'][handler_class]) === "function"))
                handler_class = "BaseType";
            var handler = new window['Types'][handler_class](spec);
            $key.data('value_handler', handler);

            $key.append(handler.createUI(
                function() {
                    checkModified($key);
                }));

            var $button = $('<button class="undo_button"></button>');
            $button.attr('title', 'Reset to configured value: ' + spec.current_value);
            $button.click(function() {
                handler.restoreCurrentValue();
                checkModified($key);
            }).button({
                icons: {
                    primary: "undo-icon"
                },
                text: false
            });
            $key.append($button);

            $button = $('<button class="default_button"></button>');
            $button.attr('title', 'Reset to default value: ' + spec.spec_value);
            $button.click(function() {
                handler.restoreSpecValue();
                checkModified($key);
            }).button({
                icons: {
                    primary: "default-icon"
                },
                text: false
            });
            $key.append($button);

            checkModified($key, true);
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
        var $whirly = createWhirly($node, 'load', true);
        var rid = requestID(spec.title);
        $.jsonRpc(
            json_rpc_url,
            {
                namespace: "configure",
                method: "getspec",
                id: rid,
                params: {
                    "parent" : {
                        "depth": spec.depth,
                        "title" : spec.title
                    },
                    "children" : 0 },
                error: function(jsonResponse, textStatus, xhr) {
                    $whirly.remove();
                    if (jsonResponse.error.code == 1) {
                        alert(jsonResponse.error.message);
                    } else {
                        debugger;
                    }
                },
                success: function(jsonResponse, textStatus, xhr) {
                    var $report = $('<div class="reports"></div>');
                    $report.attr('id', _id_ify(spec.title) + '_reports');
                    $node.append($report);

                    if (spec.description) {
                        $node.append('<div class="description">'
                                      + spec.description + '</div>');
                    }
                    load_section_specs(jsonResponse.result, $node);
                    $whirly.remove();
                    checkLoadedKeys($node);
                }
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
        for (var i = 0; i < keys.length; i++) {
            // Add a change handler so we know when the key value changes.
            // By using on() we will get the handler attached to elements
            // when they are loaded, even if they're not there yet.
            $(document).on("change", keys[i], null, handler);
        }
        return handler;
    };

    // Create the DOM for a section
    function load_section_specs(entries, $section) {
        // Construct a value field for each key
        var on_ready = [];
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            var label;
            if (entry.type != "SECTION") {
                var $node = $('<div class="node valued closed"></div>');
                var label = null;
                $node.data('spec.entry', entry);
                if (entry.options) {
                    // Decode options
                    var m;
                    if (m = entry.options.match(/\bEXPERT\b/))
                        $node.addClass('inexpert');
                    if (m = entry.options.match(/\bLABEL="(.*?)"/))
                        label = m[1];
                    if (m = entry.options.match(/\b(DISPLAY_IF\s*.*)$/))
                        on_ready.push(
                            add_dependency(m[1], $node, function ($el, tf) {
                                $el.toggle(tf);
                            }));
                    else if (entry.options.match(/\b(ENABLE_IF\s*.*)$/))
                        on_ready.push(
                            add_dependency(m[1], $node, function($el, tf) {
                                if (tf) {
	                            $el.find("input,textarea").removeAttr('disabled');
                                } else {
	                            $el.find("input,textarea")
                                        .attr('disabled', 'disabled');
                                }
                            }));
                }
                var id = "NO_ID";
                if (entry.keys != null) {
                    id = _id_ify(entry.keys);
                    $node.addClass("keyed");
                    if (!label)
                        label = entry.keys;
                    var $head = $('<div class="keys">' + label + '</div>');
                    $node.append($head);
                    if (entry.description) {
                        var $infob = $('<button class="info_button"></button>');
                        $head.append($infob);
                        $infob.click(function() {
                            toggle_description($(this).closest('.keyed'));
                        }).button({
                            icons: {
                                primary: "info-icon"
                            },
                            text: false
                        });
                    }
                } else if (entry.title != null) {
                    // unkeyed type e.g. BUTTON
                    id = _id_ify(entry.title);
                }
                $node.attr('id', id + '_block');
                var $report = $('<div class="reports"></div>');
                $report.attr('id', id + '_reports');
                $node.append($report);
                if (entry.description) {
                    $node.append('<div class="description">'
                                  + entry.description + '</div>');
                }
                $section.append($node);
            }
        }

        // Construct tab entry for each child
        var $children = null;
        var $lis = null;
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (entry.type == "SECTION") {
                var $li = $('<li><a href="'
                           // This URL could be anything; we're going to
                           // cancel it in the beforeLoad, below.
                           + json_rpc_url
                           + '"><span class="tab" id="'
                           + _id_ify(entry.title) + '_tab">'
                           + entry.title + '</span></a></li>');
                $li.data('spec.entry', entry);
                if ($children == null) {
                    $children = $('<div></div>');
                    $section.append($children);
                    $lis = $('<ul></ul>');
                    $children.append($lis);
                }
                $lis.append($li);
            }
        }

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
        for (i = 0; i < on_ready.length; i++) {
            var handler = on_ready[i];
            handler.call();
        }
    }

    // Get all root entries
    var $whirly = createWhirly($('#root'), 'load', false);
    var rid = requestID("root");
    $.jsonRpc(
        json_rpc_url,
        {
            namespace: "configure",
            method: "getspec",
            id: rid,
            params: { "parent": { "type" : "ROOT" }, "children" : 0 },
            error: function(jsonResponse, textStatus, xhr) {
                $whirly.remove();
                if (jsonResponse.error.code == 1) {
                    alert(jsonResponse.error.message);
                } else {
                    debugger;
                }
            },
            success: function(jsonResponse, textStatus, xhr) {
                load_section_specs(jsonResponse.result, $('#root'));
                $whirly.remove();
                checkKeys({}, $('#root'), true);
                $('#showExpert').change(function() {
                    if (this.checked) {
                        $('.inexpert').each(function() {
                            $(this).removeClass('inexpert').addClass('expert');
                        });
                    } else {
                        $('.expert').each(function() {
                            $(this).removeClass('expert').addClass('inexpert');
                        });
                    }
                }).removeAttr('disabled');
            }
        }
    );

    $(window).on('beforeunload', function() {
        if ($('.value_modified').length > 0)
            return "You have unsaved changes";
        return null;
    });

    $(document).tooltip();
}

main(jQuery);
