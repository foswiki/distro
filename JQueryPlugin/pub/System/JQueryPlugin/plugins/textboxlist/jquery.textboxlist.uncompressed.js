/*
 * jQuery textbox list plugin 2.23
 *
 * Copyright (c) 2009-2020 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 */

/***************************************************************************
 * plugin definition 
 */
"use strict";
(function($) {

  // extending jquery 
  $.fn.extend({
    textboxlist: function(options) {
       
      // build main options before element iteration
      var opts = $.extend({}, $.TextboxLister.defaults, options);

      // create textbox lister for each jquery hit
      return this.each(function() {
        if (!$.data(this, "textboxlist")) {
          $.data(this, "textboxlist", new $.TextboxLister(this, opts));
        }
      });
    }
  });

  // TextboxLister class **************************************************
  $.TextboxLister = function(elem, opts) {
    var self = this;
    self.input = $(elem);
    elem.textboxList = self;

    // build element specific options. 
    // note you may want to install the Metadata plugin
    self.opts = $.extend({}, self.input.data(), self.input.metadata(), opts);

    if(!self.opts.inputName) {
      self.opts.inputName = self.input.attr('name');
    }

    // wrap
    self.container = self.input.wrap("<div />")
      .parent()
      .addClass(self.opts.containerClass)
      .addClass("clearfix");

    if (self.opts.enableClose) {
      self.container.addClass("jqTextboxListEnableClose");
    }

    if (self.opts.sorting === "manual") {
      self.container.sortable({
        items: "> ."+self.opts.listValueClass,
        placeholder: "jqTextboxListPlaceholder",
        forcePlaceholderSize: true,
        update: function(ev, ui) {
          var vals = [];
          $.each(self.container.sortable("toArray", {attribute: "class"}), function(i, classes) {
            var selector = [];
            $.map(classes.split(/\s+/), function(cls) {
              selector.push("."+cls);
            });
            selector = selector.join("");
            $(selector).find("input").each(function() {
              vals.push($(this).val());
            });
          });
          self.currentValues = vals;
        }
      });
    }


    // clear button
    if (self.opts.clearControl) {
      $(self.opts.clearControl).on("click", function() {
        self.clear();
        this.blur();
        return false;
      });
    }

    // reset button
    if (self.opts.resetControl) {
      $(self.opts.resetControl).on("click", function() {
        self.reset();
        this.blur();
        return false;
      });
    }
   
    // autocompletion
    if (self.opts.autocomplete) {
      $.extend(self.opts, {
        source: self.opts.autocomplete,
        select: function(event, ui) {
          $.log("TEXTBOXLIST: selected value="+ui.item.value+" label="+ui.item.label);
          self.select([ui.item.value+"="+ui.item.label]);
          return false;
        }
      });
      self.input.attr('autocomplete', 'off').autocomplete(self.opts);
    } else {
      $.log("TEXTBOXLIST: no autocomplete");
    }

    // keypress event
    self.input.bind("keydown.textboxlist", function(event) {
      // track last key pressed
      if(event.keyCode === 13) {
        var val = self.input.val();
        if (val) {
          $.log("TEXTBOXLIST: closing suggestion list");
          if (self.opts.autocomplete) {
            self.input.autocomplete("close");
          }
          self.select(val);
          event.preventDefault();
          return false;
        }
      }
    });

    // add event
    self.input.bind("AddValue", function(e, val) {
      $.log("TEXTBOXLIST: got add event, val="+val);
      if (val) {
        self.select(val);
      }
    });

    // delete event
    self.input.bind("DeleteValue", function(e, val) {
      if (val) {
        self.deselect([val]);
      }
    });

    // reset event
    self.input.bind("Reset", function() {
      self.reset();
    });

    // clear event
    self.input.bind("Clear", function() {
      self.clear();
    });

    // init
    self.currentValues = [];
    self.titleOfValue = [];
    if (self.input.val()) {
      self.select(self.input.val().split(/\s*,\s*/), true);
    }
    self.initialValues = self.currentValues.slice();
    self.input.removeClass('foswikiHidden').show();

    return this;
  };
 
  // clear selection *****************************************************
  $.TextboxLister.prototype.clear = function() {
    $.log("TEXTBOXLIST: called clear");
    var self = this;
    self.container.find("."+self.opts.listValueClass).remove();
    self.currentValues = [];
    self.titleOfValue = [];

    // onClear callback
    if (typeof(self.opts.onClear) == 'function') {
      $.log("TEXTBOXLIST: calling onClear handler");
      self.opts.onClear(self);
    }
  };

  // reset selection *****************************************************
  $.TextboxLister.prototype.reset = function() {
    $.log("TEXTBOXLIST: called reset");
    var self = this;
    self.clear();
    self.select(self.initialValues);

    // onReset callback
    if (typeof(self.opts.onReset) == 'function') {
      $.log("TEXTBOXLIST: calling onReseet handler");
      self.opts.onReset(self);
    }
  };

  // add values to the selection ******************************************
  $.TextboxLister.prototype.select = function(values, suppressCallback) {
    $.log("TEXTBOXLIST: called select("+values+") "+typeof(values));
    var self = this, i, j, val, title, found, currentVal, input, close, className;

    if (typeof(values) === 'string') {
      values = values.split(/\s*,\s*/);
    } else if (typeof(values) === 'undefined') {
      values = [];
    }

    // parse values
    for (i = 0; i < values.length; i++) {
      val = values[i];
      found = false;
      if (!val) {
        continue;
      }
      title = val;
      if (val.match(/^(.*)=(.*)$/)) {
        values[i] = val = RegExp.$1;
        self.titleOfValue["_"+val] = RegExp.$2;
      }
    }

    // only set values not already there
    if (self.currentValues.length > 0) {
      for (i = 0; i < values.length; i++) {
        val = values[i];
        found = false;
        if (!val) {
          continue;
        }
        for (j = 0; j < self.currentValues.length; j++) {
          currentVal = self.currentValues[j];
          if (currentVal === val) {
            found = true;
            break;
          }
        }
        if (!found) {
          self.currentValues.push(val);
        }
      }
    } else {
      self.currentValues = [];
      for (i = 0; i < values.length; i++) {
        val = values[i];
        if (val) {
          self.currentValues.push(val);
        }
      }
    }

    if (self.opts.sorting === true) {
      self.currentValues = self.currentValues.sort();
    }

    $.log("TEXTBOXLIST: self.currentValues="+self.currentValues+" length="+self.currentValues.length);

    self.container.find("."+self.opts.listValueClass).remove();

    for (i = self.currentValues.length-1; i >= 0; i--) {
      val = self.currentValues[i];
      if (!val) {
        continue;
      }
      title = self.titleOfValue["_"+val] || val;
      $.log("TEXTBOXLIST: val="+val+" title="+title);
      className = "tag_"+title.replace(/["' ]/, "_");
      input = $("<input type='hidden' name='"+self.opts.inputName+"' title='"+title+"' />").val(val);
      if (self.input.is(".foswikiMandatory")) {
        input.addClass("foswikiMandatory");
      }
      if (self.opts.enableClose) {
        close = $("<a href='#' title='remove "+title+"'></a>").
          addClass(self.opts.closeClass).
          on("click", function(e) {
            e.preventDefault();
            self.input.trigger("DeleteValue", $(this).parent().find("input").val());
            return false;
          });
      }
      $("<span></span>").addClass(self.opts.listValueClass+" "+className).
        append(input).
        append(close).
        append(title).
        prependTo(self.container);

    }
    self.input.val('');

    // onSelect callback
    if (!suppressCallback && typeof(self.opts.onSelect) == 'function') {
      $.log("TEXTBOXLIST: calling onSelect handler");
      self.opts.onSelect(self);
    }
    self.input.trigger("SelectedValue", values);
  };

  // remove values from the selection *************************************
  $.TextboxLister.prototype.deselect = function(values) {
    $.log("TEXTBOXLIST: called deselect("+values+")");

    var self = this, newValues = [], i, j, currentVal, found, val;

    if (typeof(values) == 'string') {
      values = values.split(/\s*,\s*/);
    }
    if (!values.length) {
      return;
    }

    for (i = 0; i < self.currentValues.length; i++) {
      currentVal = self.currentValues[i];
      if (!currentVal) {
        continue;
      }
      found = false;
      for (j = 0; j < values.length; j++) {
        val = values[j];
        if (val && currentVal === val) {
          found = true;
          break;
        }
      }
      if (!found && currentVal) {
        newValues.push(currentVal);
      }
    }
    self.currentValues = newValues;

    // onDeselect callback
    if (typeof(self.opts.onDeselect) == 'function') {
      $.log("TEXTBOXLIST: calling onDeselect handler");
      self.opts.onDeselect(self);
    }

    self.select(newValues, true);
  };

  // default settings ****************************************************
  $.TextboxLister.defaults = {
    containerClass: 'jqTextboxListContainer',
    listValueClass: 'jqTextboxListValue',
    closeClass: 'jqTextboxListClose',
    enableClose: true,
    sorting: 'manual',
    inputName: undefined,
    resetControl: undefined,
    clearControl: undefined,
    autocomplete: undefined,
    onClear: undefined,
    onReset: undefined,
    onSelect: undefined,
    onDeselect: undefined
  };
 
})(jQuery);
