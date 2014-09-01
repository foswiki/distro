/*global Class _id_ify */
// Handling for data value types in configure

var Types = {};

(function($) {
  "use strict";

  Types.BaseType = Class.extend({
      // Set to a function that returns true if the current value
      // is to be null
      null_if: null,

      init: function(spec) {
          this.spec = spec;
      },

      createUI: function(change_handler) {
          var val = this.spec.current_value, m, cols, rows, value, size;

          if (typeof(val) === "undefined") {
              val = '';//eval(this.spec['default']);
          }

          // columns x rows
          if (this.spec.SIZE && 
              (m = this.spec.SIZE.match(/^\s*(\d+)x(\d+)(\s|$)/))) {
              cols = m[1];
              rows = m[2];
              value = typeof(val) === "undefined" ? '' : val;
              this.$ui = $('<textarea id="' + _id_ify(this.spec.keys) + 
                          '" rows="' + rows + 
                          '" cols="' + cols + 
                          '" class="foswikiTextArea">' + value + '</textarea>');
          } else {
              // simple size
              size = 80;
              if (this.spec.SIZE && 
                  (m = this.spec.SIZE.match(/^\s*(\d+)(\s|$)/))) {
                  size = m[1];
              }
              this.$ui = $('<input id="' + _id_ify(this.spec.keys) + 
                           '" size="' + size + '"/>');
              this.$ui.val(val);
          }
          if (this.spec.SPELLCHECK) {
              this.$ui.attr('spellcheck', 'true');
          }
          if (typeof(change_handler) !== "undefined") {
              this.$ui.change(change_handler);
          }
          return this.$ui;
      },

      useVal: function(val) {
          this.$ui.val(val);
      },

      currentValue: function() {
          if (this.null_if !== null && this.null_if()) {
              return null;
          }
          return this.$ui.val();
      },

      commitVal: function() {
          this.spec.current_value = this.currentValue();
      },

      restoreCurrentValue: function() {
          this.useVal(this.spec.current_value);
      },

      restoreDefaultValue: function() {
          this.useVal(this.spec['default']);
      },

      isModified: function() {
          var cv = this.spec.current_value;
          if (typeof(cv) === 'undefined') {
              cv = null;
          }
          return this.currentValue() != cv;
      },

      isDefault: function() {
          // Implementation appropriate for number and string types
          // which can be compared as their base type in JS. More
          // complex types may need conversion to string first.
          return this.currentValue() == this.spec['default'];
      }

  });

  Types.BOOLEAN = Types.BaseType.extend({
      createUI: function(change_handler) {
          this.$ui = $('<input type="checkbox" id="' + _id_ify(this.spec.keys) + '" />');
          if (typeof(change_handler) !== "undefined") {
              this.$ui.change(change_handler);
          }
          if (typeof(this.spec.current_value) === 'undefined')
              this.spec.current_value = 0;
          else if (this.spec.current_value === '0')
              this.spec.current_value = 0;
          else if (this.spec.current_value === '1')
              this.spec.current_value = 1;

          if (this.spec.current_value !== 0) {
              this.$ui.attr('checked', 'checked');
          }
          if (this.spec.extraClass) {
              this.$ui.addClass(this.spec.extraClass);
          }
          return this.$ui;
      },

      currentValue: function() {
          return this.$ui[0].checked ? 1 : 0;
      },

      isModified: function() {
          var a = this.currentValue(),
              b = this.spec.current_value;
          return a != b;
      },

      isDefault: function() {
          var a = this.currentValue(),
              b = eval(this.spec['default']);
          return a == b;
      },

      useVal: function(val) {
          this.$ui.attr('checked', val ? 'checked' : '');
      }
  });

  Types.PASSWORD = Types.BaseType.extend({
      createUI: function(change_handler) {
          this._super(change_handler);
          this.$ui.attr('type', 'password');
          this.$ui.attr('autocomplete', 'off');
          return this.$ui;
      }
  });

  Types.REGEX = Types.BaseType.extend({
      isDefault: function() {
          // String comparison, no eval
          return this.currentValue() == this.spec['default'];
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
          return this.currentValue() == this.spec['default'];
      }
  });

  Types.OCTAL = Types.BaseType.extend({
      createUI: function(change_handler) {
          if (typeof(this.spec.current_value) !== "undefined" && typeof this.spec.current_value != 'string') {
              this.spec.current_value = "" + this.spec.current_value.toString(8);
          }
          return this._super(change_handler);
      },

      currentValue: function() {
          var newval = this.$ui.val();
          return newval.toString(8);
      }
  });

  Types.PATHINFO = Types.BaseType.extend({
      createUI: function(change_handler) {
          this._super(change_handler);
          this.$ui.attr('readonly', 'readonly');
          return this.$ui;
      }
  });

  // This field is invisible, as it only exists to provide a hook
  // for a provideFeedback button. It is disabled as there is no
  // point in POSTing it.
  Types.NULL = Types.BaseType.extend({
      createUI: function(change_handler) {
          this._super(change_handler);
          this.$ui.attr('readonly', 'readonly');
          this.$ui.attr('disabled', 'disabled');
          this.$ui.attr('size', '1');
          return this.$ui;
      }
  });

  Types.BUTTON = Types.BaseType.extend({
      createUI: function() {
          this.$ui = $('<a href="' + this.spec.uri + '">' + this.spec.title + '</a>');
          this.$ui.button();
          return this.$ui;
      },

      useVal: function() {
          // NOP
      }
  });

  Types.SELECT = Types.BaseType.extend({
      // Get an array of items that need to be selected given the value
      // 'val'
      _getSel: function(val, mult) {
          var sel = {}, a, i;

          if (typeof(val) !== "undefined") {
              if (mult) {
                  a = val.split(',');
                  for (i = 0; i < a.length; i++) {
                      sel[a[i]] = true;
                  }
              } else {
                  sel[val] = true;
              }
          }
          return sel;
      },

      createUI: function(change_handler) {
          var size = 1, m, sel, i, opt, options;

          if (this.spec.SIZE && (m = this.spec.SIZE.match(/\b(\d+)\b/))) {
              size = m[0];
          }

          this.$ui = $('<select id="' + _id_ify(this.spec.keys) + '" size="' + size + 
                       '" class="foswikiSelect" />');

          if (typeof(change_handler) !== "undefined") {
              this.$ui.change(change_handler);
          }
          if (this.spec.MULTIPLE) {
              this.$ui.attr('multiple', 'multiple');
          }

          if (typeof(this.spec.select_from) !== "undefined") {
              sel = this._getSel(this.spec.current_value, this.spec.MULTIPLE);
              for (i = 0; i < this.spec.select_from.length; i++) {
                  opt = this.spec.select_from[i];
                  var $option = $('<option>' + opt + '</option>');
                  if (sel[opt]) {
                      $option.attr('selected', 'selected');
                  }
                  this.$ui.append($option);
              }
          }
          return this.$ui;
      },

      useVal: function(val) {
          var sel = this._getSel(val),
              sf = this.spec.select_from,
              i, opt;

          if (typeof(sf) !== "undefined") {
              i = 0;
              this.$ui.find('option').each(function() {
                  opt = sf[i++];
                  if (sel[opt]) {
                      $(this).attr('selected', 'selected');
                  } else {
                      $(this).removeAttr('selected');
                  }
              });
          }
      }
  });

  Types.SELECTCLASS = Types.SELECT.extend({});
})(jQuery);
