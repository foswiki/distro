// Handling for data value types in configure

var Types = {};

// Convert key string to valid HTML id. Not guaranteed to generate a unique
// id, but close enough for our purposes.
function _id_ify(id) {
    if (id == undefined) debugger;
    id = id.replace(/[}{]/g, '-');
    id = id.replace(/['"]/g, '');
    id = id.replace(/[^A-Za-z0-9_]/g, '-');
    return 'cfg' + id;
}

Types.BaseType = Class.extend({
    init: function(spec) {
	this.spec = spec;
    },

    createUI: function(change_handler) {
        var opts = ' ' + (this.spec.options ? this.spec.options : '') + ' ';
        // M (mandatory) - ignored by this tool
        // CHECK=? - ignored by this tool
        // FEEDBACK=? - ignored by this tool
        // AUDIT=? - ignored by this tool
        var val = this.spec.current_value;
        if (val == undefined)
            val = this.spec.spec_value;

 	var m;
        // columns x rows
        if (m = opts.match(/^\s*(\d+)x(\d+)(\s|$)/)) {
            var cols = m[1];
            var rows = m[2];
            var value = val == undefined ? '' : val;
            this.ui = $('<textarea id="' + _id_ify(this.spec.keys)
 			+ '" rows="' + rows
 			+ '" cols="' + cols
 			+ '" class="foswikiTextArea">' + value + '</textarea>');
        } else {
            // simple size
 	    var size = 80;
            if (m = opts.match(/^\s*(\d+)(\s|$)/)) {
 		size = m[1];
 	    }
            this.ui = $('<input id="' + _id_ify(this.spec.keys)
                        + '" size="' + size + '"/>');
            if (val != undefined)
                this.ui.attr('value', val);
        }
        if (m = opts.match(/\b([sS])\b/) ) {
            this.ui.attr('spellcheck', "true");
        }
 	if (change_handler != undefined)
 	    this.ui.change(change_handler);
        return this.ui;
    },

    useVal: function(val) {
        this.ui.val(val);
    },

    currentValue: function() {
 	return this.ui.val();
    },

    restoreCurrentValue: function() {
        this.useVal(this.spec.current_value);
    },

    restoreSpecValue: function() {
        this.useVal(this.spec.spec_value);
    },

    isModified: function() {
        return this.currentValue() != this.spec.current_value;
    },

    isDefault: function() {
        return this.currentValue() == this.spec.spec_value;
    }

});

Types.BOOLEAN = Types.BaseType.extend({
    createUI: function(change_handler) {
        this.ui = $('<input type="checkbox" id="' + _id_ify(this.spec.keys)
 		    + '" />');
 	if (change_handler != undefined)
 	    this.ui.change(change_handler);
        if (this.spec.current_value) {
            this.ui.attr('checked', 'checked');
        }
        if (this.spec.extraClass) {
            this.ui.addClass(this.spec.extraClass);
        }
        return this.ui;
    },

    currentValue: function() {
 	return this.ui[0].checked ? 1 : 0;
    },

    useVal: function(val) {
        this.ui[0].attr(checked, val ? 'checked' : '');
    }
});

Types.BOOLGROUP = Types.BaseType.extend({
    createUI: function(change_handler) {
 	var options = split(/,\s*/, this.spec.options);
 	var sets = [];
 	var values = split(/,\s*/, this.spec.current_value);
 	for (var i = 0; i < values.length; i++) {
 	    sets[values[i]] = true;
 	}
 	this.ui = $('<div class="checkbox_group"></div>');
 	for (var i = 0; i < options.length; i++) {
 	    var cb = $('<input type="checkbox" name="' + options[i]
 		       + ' id="' + _if_ify(this.spec.keys) + '"/>');
 	    if (sets[options[i]])
 		cb.attr('checked', 'checked');
 	    cb.change(change_handler);
 	    this.ui.append(cb);
 	}
 	return this.ui;
    },

    currentValue: function() {
 	var newval = [];
 	$('#' + _id_ify(this.spec.keys)).each(function() {
 	    if (this.attr('checked'))
 		newval.push(this.attr('name'));
 	});
 	return newval.join(',');
    },

    useVal: function(val) {
 	var sets = [];
 	var values = split(/,\s*/, val);
 	for (var i = 0; i < values.length; i++) {
 	    sets[values[i]] = true;
 	}
        var i = 0;
        this.ui.find('input[type="checkbox"]').each(function() {
 	    if (sets[options[i++]])
 		cb.attr('checked', 'checked');
        });
    }
});

Types.PASSWORD = Types.BaseType.extend({
    createUI: function(change_handler) {
 	this._super(change_handler);
 	this.ui.attr('type', 'password');
 	this.ui.attr('autocomplete', 'off');
 	return this.ui;
    }
});

Types.PERL = Types.BaseType.extend({
    createUI: function(change_handler) {
        if (!this.spec.options)
            this.spec.options = '';
        if (!this.spec.options.match(/\b(\d+)x(\d+)\b/)) {
            this.spec.options = " 80x20 " + this.spec.options;
        }
 	return this._super(change_handler);
    }
});

Types.OCTAL = Types.BaseType.extend({
    createUI: function(change_handler) {
 	if (this.spec.current_value != undefined && typeof this.spec.current_value != 'string') {
 	    this.spec.current_value = "" + this.spec.current_value.toString(8);
 	}
 	return this._super(change_handler);
    },

    currentValue: function() {
 	var newval = this.ui.val();
 	return newval.toString(8);
    }
});

Types.PATHINFO = Types.BaseType.extend({
    createUI: function(change_handler) {
 	this._super(change_handler);
 	this.ui.attr('readonly', 'readonly');
 	return this.ui;
    }
});

// This field is invisible, as it only exists to provide a hook
// for a provideFeedback button. It is disabled as there is no
// point in POSTing it.
Types.NULL = Types.BaseType.extend({
    createUI: function(change_handler) {
 	this._super(change_handler);
 	this.ui.attr('readonly', 'readonly');
 	this.ui.attr('disabled', 'disabled');
 	this.ui.attr('size', '1');
 	return this.ui;
    }
});

Types.BUTTON = Types.BaseType.extend({
    createUI: function() {
        this.ui = $('<a href="' + this.spec.uri + '">'
                    + this.spec.title + '</a>');
        this.ui.button();
 	return this.ui;
    },

    useVal: function() {
        // NOP
    }
});

Types.SELECT = Types.BaseType.extend({
    _getSel: function(val) {
 	var sel = [];
 	if (val != undefined) {
 	    if (Object.prototype.toString.call(val) === '[object Array]') {
 		for (var i = 0; i < val.length; i++) {
 		    sel[val[i]] = true;
 		}
 	    } else {
 		sel[val] = true;
 	    }
 	}
        return sel;
    },

    createUI: function(change_handler) {
 	var opts = this.spec.options;
 	var size = 1;
 	var m;
 	if (m = opts.match(/\b(\d+)\b/))
 	    size = m[0];
 	var mult = false;
 	this.ui = $('<select id="' + _id_ify(this.spec.keys) + '" size="' + size
 		    + '" class="foswikiSelect" />');
 	if (change_handler != undefined)
 	    this.ui.change(change_handler);
 	if (opts.match(/\bmultiple\b/)) {
 	    this.ui.attr('multiple', 'multiple');
 	}

 	if (this.spec.choices != undefined) {
 	    var sel = this._getSel(this.spec.current_value);
 	    for (var i = 0; i < this.spec.choices.length; i++) {
 		var opt = this.spec.choices[i];
 		var option = $('<option>' + opt + '</option>');
 		if (sel[opt])
 		    $(this).attr('selected', 'selected');
 		this.ui.append(option);
            }
 	}
 	return this.ui;
    },

    useVal: function(val) {
        var sel = this._getSel(val);
 	if (this.spec.choices != undefined) {
            var i = 0;
 	    this.ui.find('option').each(function() {
 		var opt = this.spec.choices[i++];
 		if (sel[opt])
 		    $(this).attr('selected', 'selected');
                else
                    $(this).removeAttr('selected');
            });
 	}
    }
});

Types.SELECTCLASS = Types.SELECT.extend({});
