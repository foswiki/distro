(function($) {
    function expand(entry, addTo) {
	if (entry.type == "SECTION") {
	    var h = 'h' + entry.depth;
	    addTo.append('<' + h + ' class="section">' + entry.title + '</' + h + '>');
	} else if (entry.keys) {
	    addTo.append('<div class="keys">' + entry.type + ' ' + entry.keys + '</div>');
	}
	if (entry.description) {
	    addTo.append('<div class="description">' + entry.description + '</div>');
	}
	if (entry.children) {
	    var sub = $('<div class="children"></div>');
	    addTo.append(sub);
	    for (var i = 0; i < entry.children.length; i++) {
		expand(entry.children[i], sub);
	    }
	}
    }
    $.jsonRpc(
        "../bin/jsonrpc",
        {
            namespace: "configure",
            method: "getspec",
            id: "1",
            error: function(jsonResponse, textStatus, xhr) {
                if (jsonResponse.error.code == 1) {
                    alert(jsonResponse.error.message);
                } else {
                    debugger;
                }
            },
            success: function(jsonResponse, textStatus, xhr) {
                expand(jsonResponse.result, $('#root'))
            }
        }
    );
})(jQuery);
