// Handling for data value types in configure

var Types = {};

// Convert key string to valid HTML id. Not guaranteed to generate a unique
// id, but close enough for our purposes.
function _id_ify(id) {
    if (id == undefined) debugger;
    id = id.replace(/[}{]/g, '_');
    id = id.replace(/['"]/g, '');
    id = id.replace(/[^A-Za-z0-9_]/g, '_');
    return 'cfg' + id;
}

Types.BaseType = Class.extend({
    init: function(spec) {
	this.spec = spec;
    },

    createUI: function(change_handler) {
        var opts = ' ' + (this.spec.options ? this.spec.options : '') + ' ';
        // CCxRR
        // EXPERT
        // M (mandatory)
        // CHECK=
        // FEEDBACK=
        // AUDIT=
        // expand

	var m;
        if (m = opts.match(/\b(\d+)x(\d+)\b/)) {
            var cols = m[0];
            var rows = m[1];
            var value = this.spec.value == undefined ? '' : this.spec.value;
            this.ui = $('<textarea id="' + _id_ify(this.spec.keys)
			+ '" rows="' + rows
			+ '" cols="' + cols
			+ '" class="foswikiTextArea">' + value + '</textarea>');
        } else {
	    var size = 80;
            if (m = opts.match(/\b(\d+)\b/)) {
		size = m[0];
	    }
            this.ui = $('<input id="' + _id_ify(this.spec.keys)
                       + '" class="foswikiInputField" size="' + size + '"/>');
            if (this.spec.value != undefined)
                this.ui.attr('value', this.spec.value);
        }
        if (m = opts.match(/\b([sS])\b/) ) {
            this.ui.attr('spellcheck', "true");
        }
        if (m = opts.match(/\b(\d+)\b/)) {
            this.ui.attr('size', m[0]);
        }
	if (change_handler != undefined)
	    this.ui.change(change_handler);
        return this.ui;
    },

    changedValue: function() {
	return this.ui.val();
    }
});

Types.BOOLEAN = Types.BaseType.extend({
    createUI: function(change_handler) {
        this.ui = $('<input type="checkbox" id="' + _id_ify(this.spec.keys)
		    + '" />');
	if (change_handler != undefined)
	    this.ui.change(change_handler);
        if (this.spec.value) {
            this.ui.attr('checked', 'checked');
        }
        if (this.spec.extraClass) {
            this.ui.addClass(this.spec.extraClass);
        }
        return this.ui;
    },

    changedValue: function() {
	return this.ui[0].checked;
    }
});

Types.BOOLGROUP = Types.BaseType.extend({
    createUI: function(change_handler) {
	var options = split(/,\s*/, this.spec.options);
	var sets = [];
	var values = split(/,\s*/, this.spec.value);
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

    changedValue: function() {
	var newval = [];
	$('#' + _id_ify(this.spec.keys)).each(function() {
	    if (this.attr('checked'))
		newval.push(this.attr('name'));
	});
	return newval.join(',');
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

Types.OCTAL = Types.BaseType.extend({
    createUI: function(change_handler) {
	if (this.spec.value != undefined && typeof this.spec.value != 'string') {
	    this.spec.value = "" + this.spec.value.toString(8);
	}
	return this._super(change_handler);
    },

    changedValue: function() {
	var newval = this.ui.val();
	return newval.parseInt(8);
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
	this.ui.addClass('foswikiMakeHidden foswikiNULLField');
	return this.ui;
    }
});

Types.SELECT = Types.BaseType.extend({
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

	var sel = [];
	if (this.spec.value != undefined) {
	    if (Object.prototype.toString.call(this.spec.value) === '[object Array]') {
		for (var i = 0; i < this.spec.value.length; i++) {
		    sel[this.spec.value[i]] = true;
		}
	    } else {
		sel[this.spec.value] = true;
	    }
	}

	if (this.spec.choices != undefined) {
	    for (var i = 0; i < this.spec.choices.length; i++) {
		var opt = this.spec.choices[i];
		var option = $('<option>' + opt + '</option>');
		if (sel[opt])
		    option.attr('selected', 'selected');
		this.ui.append(option);
            }
	}
	return this.ui;
    }
});

Types.SELECTCLASS = Types.SELECT.extend({});
