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
              value = value.replace(/&/g, "&amp;");
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
              this.$ui = $('<input type="text" id="' + _id_ify(this.spec.keys) + 
                           '" size="' + size + '"/>');
              this.useVal(val);
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
              cv = (this.null_if === null) ? '' : null;
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

  Types.STRING = Types.BaseType.extend({
      restoreDefaultValue: function() {
          var val = this.spec['default'];
          if (val === 'undef')
              val = null;
          else
              val = val.replace(/^\s*(["'])(.*)\1\s*$/, "$2");
          this.useVal(val);
      },
      isDefault: function() {
          // trim ' from the default
          var val = this.spec['default'];
          if (typeof(val) === 'string') {
              if (/^\s*'.*'\s*$/.test(val)) {
                  // We can't use eval because JS eval behaves differently
                  // to perl eval of a single-quoted string. The currentValue
                  // comes from a perl eval.
                  val = val.replace(/^\s*'(.*)'\s*$/, "$1");
                  val = val.replace(/\'/g, "'");
              }
          }
          return this.currentValue() === val;
      }
  });

  Types.BOOLEAN = Types.BaseType.extend({
      createUI: function(change_handler) {
          this.$ui = $('<input type="checkbox" id="' + _id_ify(this.spec.keys) + '" />');
          if (typeof(change_handler) !== "undefined") {
              this.$ui.change(change_handler);
          }
          if (typeof(this.spec.current_value) == 'undefined') {
              this.spec.current_value = 0;
          } else if (this.spec.current_value == '0') {
              this.spec.current_value = 0;
          } else if (this.spec.current_value == '1') {
              this.spec.current_value = 1;
          }

          if (this.spec.current_value !== 0) {
              this.$ui.attr('checked', true);
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
          if (typeof(val) == 'undefined') {
              val = false;
          } else if (val  == '0' || val == '$FALSE') {
              val = false;
          } else if ( val == '1') {
              val = true;
          }
          this.$ui.attr('checked', val );
      }
  });

  Types.PASSWORD = Types.STRING.extend({
      createUI: function(change_handler) {
          this._super(change_handler);
          this.$ui.attr('type', 'password');
          this.$ui.attr('autocomplete', 'off');
          return this.$ui;
      }
  });

  Types.REGEX = Types.STRING.extend({
      restoreDefaultValue: function() {
          var val = this.spec['default'];
          if (val === 'undef')
              val = null;
          else
              val = val.replace(/^\s*(["'])(.*)\1\s*$/, "$2");
              val = val.replace(/\\\\\\/, "\\");
          this.useVal(val);
      },
      isDefault: function() {
          // trim ' from the default
          var val = this.spec['default'];
          if (typeof(val) === 'string') {
              if (/^\s*'.*'\s*$/.test(val)) {
                  // We can't use eval because JS eval behaves differently
                  // to perl eval of a single-quoted string. The currentValue
                  // comes from a perl eval.
                  val = val.replace(/^\s*'(.*)'\s*$/, "$1");
                  val = val.replace(/\'/g, "'");
                  val = val.replace(/\\\\\\/, "\\");
              }
          }
          return this.currentValue() === val;
      }
  });

  // Deep compare of simple object, used for perl simple structures.
  // Note: no support for built-in types other than the basic types, arrays
  // and hashes; but then parsing a perl value use eval will never succeed with
  // anything else.
  Types.deep_equals = function(x, y) {
      if (x === y)
          return true;

      if (x === null
          || x === undefined
          || y === null
          || y === undefined)
          return false; // x===y would have succeeded otherwise

      if (x.constructor !== y.constructor)
          return false;

      if (x.valueOf() === y.valueOf())
          return true;

      if (Array.isArray(x) && x.length !== y.length)
          return false;

      // if they are strictly equal, they both need to be object at least
      if (!(x instanceof Object && y instanceof Object))
          return false;

      // recursive equality check
      var p = Object.keys(x);
      return Object.keys(y).every(function (i) {
          return p.indexOf(i) !== -1;
      }) &&
          p.every(function (i) {
              return Types.deep_equals(x[i], y[i]);
          });
  };

  Types.PERL = Types.BaseType.extend({
      createUI: function(change_handler) {
          if (!(this.spec.SIZE && this.spec.SIZE.match(/\b(\d+)x(\d+)\b/))) {
              this.spec.SIZE = "80x20";
          }
          return this._super(change_handler);
      },
      isDefault: function() {
          // To do this comparison requires parsing and rewriting the perl to
          // javascript. Not impossible, but tricky.
          var a = this.currentValue().trim(),
              b = this.spec['default'].trim(), av, bv;
          try {
              // See if they parse as JS - they probably will! If they don't,
              // parse, fall back to a string comparison :-(
              av = eval(a);
              bv = eval(b);
          } catch (err) {
              av = null; bv = null;
          }
          if (av !== null && bv !== null) {
              return Types.deep_equals(av, bv);
          }
          // String comparison of the serialised perl value. This is unlikely
          // to work, but there's no other option if one or both of the values
          // fails to parse using JS eval.
          return a === b;
      }

  });

  Types.NUMBER = Types.BaseType.extend({
      // Local first-line validator
      createUI: function(change_handler) {
          return this._super(function(evt) {
              var val = $(this).val();
              if (/^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/.test(val)) {
                  $(this).css('background-color', '');
                  change_handler.call(this, evt);
              } else {
                  $(this).css('background-color', 'yellow');
                  alert('"' + val + '" is not a valid number');
              }
          });
      }
  });

  Types.OCTAL = Types.NUMBER.extend({
      // Local first-line validator
      createUI: function(change_handler) {
          return this._super(function(evt) {
              var val = $(this).val();
              if (/^[0-7]+$/.test(val)) {
                  $(this).css('background-color', '');
                  change_handler.call(this, evt);
              } else {
                  $(this).css('background-color', 'yellow');
                  alert('"' + val + '" is not a valid octal number');
              }
          });
      }
  });

  Types.PATHINFO = Types.STRING.extend({
      createUI: function(change_handler) {
          this._super(change_handler);
          this.$ui.attr('readonly', 'readonly');
          return this.$ui;
      }
  });

  Types.PATH = Types.STRING.extend({
  });

  Types.URL = Types.STRING.extend({
  });

  Types.URILIST = Types.STRING.extend({
  });

  Types.URLPATH = Types.STRING.extend({
  });

  Types.DATE = Types.STRING.extend({
  });

  Types.COMMAND = Types.STRING.extend({
  });

  Types.EMAILADDRESS = Types.STRING.extend({
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
          var size = 1, m, sel, i, opt, options, $option;

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
                  $option = $('<option>' + opt + '</option>');
                  if (sel[opt]) {
                      $option.attr('selected', 'selected');
                  }
                  this.$ui.append($option);
              }
          }
          return this.$ui;
      },

      useVal: function(val) {
          val = val.replace(/^\s*(["'])(.*?)\1\s*/, "$2");
          var sel = this._getSel(val),
              sf = this.spec.select_from,
              i;

          if (typeof(sf) !== "undefined") {
              i = 0;
              this.$ui.find('option').each(function() {
                  var opt = sf[i++];
                  if (sel[opt]) {
                      $(this).attr('selected', 'selected');
                  } else {
                      $(this).removeAttr('selected');
                  }
              });
          }
      },

      isDefault: function() {
          var a = this.currentValue().trim(),
              b = this.spec['default'].trim();
          b = b.replace(/^\s*(["'])(.*?)\1\s*/, "$2");
          return a === b;
      }
  });

  Types.SELECTCLASS = Types.SELECT.extend({});
})(jQuery);
