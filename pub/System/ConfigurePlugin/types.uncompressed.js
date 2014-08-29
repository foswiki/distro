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
        var val = this.spec.current_value;
        if (val == undefined)
            val = '';//eval(this.spec.default);

        var m;
        // columns x rows
        if (this.spec.SIZE
            && (m = this.spec.SIZE.match(/^\s*(\d+)x(\d+)(\s|$)/))) {
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
            if (this.spec.SIZE
                && (m = this.spec.SIZE.match(/^\s*(\d+)(\s|$)/))) {
                size = m[1];
            }
            this.ui = $('<input id="' + _id_ify(this.spec.keys)
                        + '" size="' + size + '"/>');
            this.ui.attr('value', val);
        }
        if (this.spec.SPELLCHECK) {
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

    commitVal: function() {
        this.spec.current_value = this.currentValue();
    },

    restoreCurrentValue: function() {
        this.useVal(this.spec.current_value);
    },

    restoreDefaultValue: function() {
        this.useVal(this.spec.default);
    },

    isModified: function() {
        var cv = this.spec.current_value;
        if (typeof(cv) == 'undefined')
            cv = '';
        return this.currentValue() != cv;
    },

    isDefault: function() {
        // Implementation appropriate for number and string types
        // which can be compared as their base type in JS. More
        // complex types may need conversion to string first.
        return this.currentValue() == this.spec.default;
    }

});

Types.BOOLEAN = Types.BaseType.extend({
    createUI: function(change_handler) {
        this.ui = $('<input type="checkbox" id="' + _id_ify(this.spec.keys)
                    + '" />');
        if (change_handler != undefined)
            this.ui.change(change_handler);
        if (typeof(this.spec.current_value) == 'undefined')
            this.spec.current_value = 0;
        if (this.spec.current_value != 0) {
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

    isModified: function() {
        var a = this.currentValue();
        var b = this.spec.current_value;
        return a != b;
    },

    isDefault: function() {
        var a = this.currentValue();
        var b = eval(this.spec.default);
        return a == b;
    },

    useVal: function(val) {
        this.ui[0].attr(checked, val ? 'checked' : '');
    }
});

Types.BOOLGROUP = Types.BaseType.extend({
    createUI: function(change_handler) {
        var options = this.spec.select_from;
        var sets = [];
        var values = this.spec.current_value.split(/,\s*/);
        for (var i = 0; i < values.length; i++) {
            sets[values[i]] = true;
        }
        this.ui = $('<div class="checkbox_group"></div>');
        for (var i = 0; i < options.length; i++) {
            var cb = $('<input type="checkbox" name="' + options[i]
                       + ' id="' + _id_ify(this.spec.keys) + '"/>');
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

Types.REGEX = Types.BaseType.extend({
    isDefault: function() {
        // String comparison, no eval
        return this.currentValue() == this.spec.default;
    }
});

Types.PERL = Types.BaseType.extend({
    createUI: function(change_handler) {
        if (!(this.spec.SIZE && this.spec.SIZE.match(/\b(\d+)x(\d+)\b/))) {
            this.spec.SIZE = "80x20";
        }
        return this._super(change_handler);
    },

    isDefault: function() {
        // String comparison, no eval
        return this.currentValue() == this.spec.default;
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
    // Get an array of items that need to be selected given the value
    // 'val'
    _getSel: function(val, mult) {
        var sel = {};
        if (val != undefined) {
            if (mult) {
                var a = val.split(',');
                for (var i = 0; i < a.length; i++) {
                    sel[a[i]] = true;
                }
            } else {
                sel[val] = true;
            }
        }
        return sel;
    },

    createUI: function(change_handler) {
        var size = 1;
        var m;
        if (this.spec.SIZE && (m = this.spec.SIZE.match(/\b(\d+)\b/)))
            size = m[0];

        this.ui = $('<select id="' + _id_ify(this.spec.keys) + '" size="' + size
                    + '" class="foswikiSelect" />');
        if (change_handler != undefined)
            this.ui.change(change_handler);
        if (this.spec.MULTIPLE) {
            this.ui.attr('multiple', 'multiple');
        }

        if (this.spec.select_from != undefined) {
            var sel = this._getSel(this.spec.current_value, this.spec.MULTIPLE);
            for (var i = 0; i < this.spec.select_from.length; i++) {
                var opt = this.spec.select_from[i];
                var option = $('<option>' + opt + '</option>');
                if (sel[opt]) {
                    option.attr('selected', 'selected');
                }
                this.ui.append(option);
            }
        }
        return this.ui;
    },

    useVal: function(val) {
        var sel = this._getSel(val);
        var sf = this.spec.select_from;
        if (sf != undefined) {
            var i = 0;
            this.ui.find('option').each(function() {
                var opt = sf[i++];
                if (sel[opt])
                    $(this).attr('selected', 'selected');
                else
                    $(this).removeAttr('selected');
            });
        }
    }
});

Types.SELECTCLASS = Types.SELECT.extend({});
