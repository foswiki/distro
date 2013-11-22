var main = function($) {

    // Update an element with a check result. The element and all sections leading
    // to the element get a report.
    function update_reports(results) {
        $('body').css('cursor','wait');
        for (var i = 0; i < results.length; i++) {
            var r = results[i];
            var id = _id_ify(r.keys);

            // Remove all existing reports related to these keys
            $('#' + id + '_report').remove();

            // First update the key block report
            var keyblock = $('#' + id);
            // An empty information message can be ignored
            if (!(r.level == 'information' && r.message == '')) {
                var report = keyblock.find('.report');
                if (report.length != 0) {
                    var whine = $('<div>' + r.message + '</div>');
                    whine.addClass(r.level);
                    whine.attr('id', id + '_report');
                    report.append(whine);
                }
            }

            if (r.sections) {
                // Bubble the existance of this report up through
                // the hierarchy, by following the chain of reports
                var path = r.sections.join(' > ');
                for (var j = 0; j < r.sections.length; j++) {
                    var sid = _id_ify(r.sections[j]);
                    var section = $('#' + sid).find('.report').first();
                    if (section.length > 0) {
                        var whine = $('<div>' + path + ' > ' + r.keys
                                      + ' has ' + r.level + '</div>');
                        whine.addClass(r.level);
                        whine.attr('id', id + '_report');
                        section.append(whine);
                    }
                }
            }
        }
        $('body').css('cursor','auto');
    }

    // Handler called on a 'change' event on a value
    function handle_new_value(spec, element, newval) {
        var params = {};
        params[spec.keys] = newval;
        $.jsonRpc(
            "../bin/jsonrpc",
            {
                namespace: "configure",
                method: "check",
                id: spec.keys,
                params: params,
                error: function(jsonResponse, textStatus, xhr) {
                    alert(jsonResponse.error.message);
                },
                success: function(jsonResponse, textStatus, xhr) {
                    update_reports(jsonResponse.result);
                }
            });
    }

    // Call to check all keys (slow)
    function checkAll() {
        $.jsonRpc(
            "../bin/jsonrpc",
            {
                namespace: "configure",
                method: "check",
                id: "checkAll",
                error: function(jsonResponse, textStatus, xhr) {
                    alert(jsonResponse.error.message);
                },
                success: function(jsonResponse, textStatus, xhr) {
                    update_reports(jsonResponse.result);
                }
            });
    }

    // Load a single value into the given node
    function load_value_ui(spec, element) {
        var handler_class = spec.type;
        if (!(typeof(window['Types'][handler_class]) === "function"))
            handler_class = "BaseType";
        var handler = new window['Types'][handler_class](spec);
        var ui = handler.createUI(function() {
            handle_new_value(spec, element, handler.changedValue());
        });
        element.find('.contents').before(ui);
        element.addClass("valued");
    }
    
    // Call to check the hierarchy under this node
    function check(node) {
        var to_do = {};
        var spec = node.find('.node.keys').each(function() {
            var spec = $(this).data('data_spec');
            to_do[spec.keys] = null;
        });
        $.jsonRpc(
            "../bin/jsonrpc",
            {
                namespace: "configure",
                method: "check",
                id: "check",
                params: to_do,
                error: function(jsonResponse, textStatus, xhr) {
                    alert(jsonResponse.error.message);
                },
                success: function(jsonResponse, textStatus, xhr) {
                    update_reports(jsonResponse.result);
                }
            });
     }

    // Populate values, if not already valued
    function load_value_uis(node) {
        node.find('.node.keys').each(function() {
            var spec = $(this).data('data_spec');
            load_value_ui(spec, $(this));
        });
        node.addClass("valued");
    }

    // Create the DOM for a list of specs
    function load_specs(entries, parent) {
        if (parent.hasClass('specced'))
            return;
        // Remove existing children
        var kids = parent.find('.children').first();
        kids.children().remove();
        for (var i = 0; i < entries.length; i++) {
            var node = load_spec(entries[i]);
            kids.append(node);
        }
        parent.addClass('specced');
    }

    // Create the DOM for a single spec
    function load_spec(entry) {
        var node = $('<div class="node closed"></div>');
        var head = null;
        var hasKids = false;
        node.data('data_spec', entry);
        if (entry.type == "SECTION") {
            var h = 'h' + entry.depth;
            head = $('<' + h + ' class="section">'
                     + entry.title + '</' + h + '>');
            hasKids = true;
            node.addClass('section');
            node.attr('id', _id_ify(entry.title));
        } else if (entry.title == undefined && entry.keys) {
            // Value node
            head = $('<div class="keys">' + entry.keys + '</div>');
            node.addClass('keys');
            node.attr('id', _id_ify(entry.keys));
        } else {
            // Something else e.g. ENVIRONMENT, PLUGGABLE
            head = $('<h1>' + entry.type + '</h1>');
            if (entry.keys)
                node.attr('id', _id_ify(entry.keys));
            hasKids = true; // maybe....
        }
        if (head != null) {
            node.append(head);
            head.click(function() {
                toggle_expanded(node, hasKids);
            });
        }
        node.append('<div class="report"></div>');

        var contents = $('<div class="contents"></div>');
        node.append(contents);

        if (entry.description) {
            contents.append('<div class="description">' + entry.description + '</div>');
        }

        if (hasKids) {
            var kids = $('<div class="children"><div class="loading">Loading ...</div></div>');
            contents.append(kids);

            if (entry.children != null) {
                load_specs(entry.children, node);
                check(node);
            }
        }

        return node;
    }

    // Handler to open a section
    function toggle_expanded(node) {
        if (node.hasClass("closed")) {
            node.removeClass("closed");
            node.addClass("open");
            if (!node.hasClass('specced')) {
                var spec = node.data('data_spec');
                $.jsonRpc(
                    "../bin/jsonrpc",
                    {
                        namespace: "configure",
                        method: "getspec",
                        id: spec.title,
                        params: {
                            "parent" : {
                                "depth": spec.depth,
                                "title" : spec.title
                            },
                            "children" : 0 },
                        error: function(jsonResponse, textStatus, xhr) {
                            if (jsonResponse.error.code == 1) {
                                alert(jsonResponse.error.message);
                            } else {
                                debugger;
                            }
                        },
                        success: function(jsonResponse, textStatus, xhr) {
                            load_specs(jsonResponse.result, node);
                            check(node);
                            load_value_uis(node);
                        }
                    }
                );
            }
        } else {
            node.removeClass("open");
            node.addClass("closed");
        }
    }

    $('#checkButton').button();

    // Get all root entries
    $.jsonRpc(
        "../bin/jsonrpc",
        {
            namespace: "configure",
            method: "getspec",
            id: "root",
            params: { "parent": { "type" : "ROOT" }, "children" : 0 },
            error: function(jsonResponse, textStatus, xhr) {
                if (jsonResponse.error.code == 1) {
                    alert(jsonResponse.error.message);
                } else {
                    debugger;
                }
            },
            success: function(jsonResponse, textStatus, xhr) {
                load_specs(jsonResponse.result, $('#root'));
                // Don't check, no point. We'll check when we start
                // opening sections, or when checkAll is selected.
                $('#checkButton').click(function() {
                    checkAll();
                }).removeAttr('disabled');
            }
        }
    );
}

main(jQuery);
