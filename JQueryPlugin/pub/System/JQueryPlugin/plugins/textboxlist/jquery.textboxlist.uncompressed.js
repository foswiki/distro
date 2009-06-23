/*
 * jQuery textbox list plugin 1.0
 *
 * Copyright (c) 2009 Michael Daum http://michaeldaumconsulting.com
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
;(function($) {

  // extending jquery 
  $.fn.extend({
    textboxlist: function(options) {
       
      // build main options before element iteration
      var opts = $.extend({}, $.TextboxLister.defaults, options);
     
      // create textbox lister for each jquery hit
      return this.each(function() {
        new $.TextboxLister(this, opts);
      });
    }
  });

  // TextboxLister class **************************************************
  $.TextboxLister = function(elem, opts) {
    var self = this;
    self.input = $(elem);

    // build element specific options. 
    // note you may want to install the Metadata plugin
    self.opts = $.extend({}, self.input.metadata(), opts);

    if(!self.opts.inputName) {
      self.opts.inputName = self.input.attr('name');
    }

    // wrap
    self.container = self.input.wrap("<div class="+self.opts.containerClass+"></div>")
      .parent().append("<span class='foswikiClear'></span>");

    // clear button
    if (self.opts.clearControl) {
      $(self.opts.clearControl).click(function() {
        self.clear();
        this.blur();
        return false;
      });
    }

    // reset button
    if (self.opts.resetControl) {
      $(self.opts.resetControl).click(function() {
        self.reset();
        this.blur();
        return false;
      });
    }
   
    // autocompletion
    if (self.opts.autocomplete) {
      var autocompleteOpts = 
        $.extend({},{
            selectFirst:false,
            autoFill:false,
            matchCase:true,
            matchSubset:true
          }, self.opts.autocompleteOpts);
      self.input.attr('autocomplete', 'off').autocomplete(self.opts.autocomplete, autocompleteOpts).
      result(function(event, data, value) {
        //$.log("result data="+data+" formatted="+formatted);
        self.select(value);
      });
    } else {
      $.log("no autocomplete");
    }

    // autocomplete does not fire the result event on new items
    self.input.bind(($.browser.opera ? "keypress" : "keydown") + ".textboxlist", function(event) {
      // track last key pressed
      if(event.keyCode == 13) {
        var value = self.input.val();
        if (value) {
          self.select([value]);
          event.preventDefault();
          return false;
        }
      }
    });

    // init
    self.currentValues = [];
    if (self.input.val()) {
      self.select(self.input.val().split(/\s*,\s*/));
    }
    self.initialValues = self.currentValues.slice();
  }
 
  // clear selection *****************************************************
  $.TextboxLister.prototype.clear = function() {
    $.log("called clear");
    var self = this;
    self.container.find("."+self.opts.listValueClass).remove();
    self.currentValues = [];

    // onClear callback
    if (typeof(self.opts.onClear) == 'function') {
      $.log("calling onClear handler");
      self.opts.onClear(self);
    }
  };

  // reset selection *****************************************************
  $.TextboxLister.prototype.reset = function() {
    $.log("called reset");
    var self = this;
    self.clear();
    self.select(self.initialValues);

    // onReset callback
    if (typeof(self.opts.onReset) == 'function') {
      $.log("calling onReseet handler");
      self.opts.onReset(self);
    }
  };

  // add values to the selection ******************************************
  $.TextboxLister.prototype.select = function(values) {
    $.log("called select("+values+") "+typeof(values));
    var self = this;

    if (typeof(values) == 'object') {
      values = values.join(',');
    }
    values = values.split(/\s*,\s*/);

    // only set values not already there
    if (self.currentValues.length > 0) {
      for (i = 0; i < values.length; i++) {
        var val = values[i];
        var found = false;
        if (!val) {
          continue;
        }
        for (j = 0; j < self.currentValues.length; j++) {
          var currentVal = self.currentValues[j];
          if (currentVal == val) {
            found = true;
            break;
          }
        }
        if (!found) {
          self.currentValues.push(val);
        }
      }
    } else {
      self.currentValues = values.slice();
    }

    if (self.opts.doSort) {
      self.currentValues = self.currentValues.sort();
    }

    $.log("self.currentValues="+self.currentValues+"("+self.currentValues.length+")");

    self.container.find("."+self.opts.listValueClass).remove();
    for (var i = self.currentValues.length-1; i >= 0; i--) {
      var value = self.currentValues[i];
      if (!value) 
        continue;
      var input = "<input type='hidden' name='"+self.opts.inputName+"' value='"+value+"' />";
      var close = $("<a href='#' title='remove "+value+"'></a>").
        addClass(self.opts.closeClass).
        click(function() {
          self.deselect.call(self, $(this).parent().find("input").val());
          return false;
        });
      $("<span></span>").addClass(self.opts.listValueClass).
        append(input).
        append(close).
        append(value).
        prependTo(self.container);
    }
    self.input.val('');

    // onSelect callback
    if (typeof(self.opts.onSelect) == 'function') {
      $.log("calling onSelect handler");
      self.opts.onSelect(self);
    }
  };

  // remove values from the selection *************************************
  $.TextboxLister.prototype.deselect = function(values) {
    $.log("called deselect("+values+")");

    var self = this;
    var newValues = new Array();

    if (typeof(values) == 'object') {
      values = values.join(',');
    }
    values = values.split(/\s*,\s*/);
    if (!values.length) {
      return;
    }

    for (i = 0; i < self.currentValues.length; i++) {
      var currentVal = self.currentValues[i];
      if (!currentVal) 
        continue;
      var found = false;
      for (j = 0; j < values.length; j++) {
        var val = values[j];
        if (val && currentVal == val) {
          found = true;
          break;
        }
      }
      if (!found) {
        newValues.push(currentVal);
      }
    }
    self.currentValues = newValues;

    // onDeselect callback
    if (typeof(self.opts.onDeselect) == 'function') {
      $.log("calling onDeselect handler");
      self.opts.onDeselect(self);
    }

    self.select(newValues);
  };

  // default settings ****************************************************
  $.TextboxLister.defaults = {
    containerClass: 'jqTextboxListContainer',
    listValueClass: 'jqTextboxListValue',
    closeClass: 'jqTextboxListClose',
    doSort: false,
    inputName: undefined,
    resetControl: undefined,
    clearControl: undefined,
    autocomplete: undefined,
    onClear: undefined,
    onReset: undefined,
    onSelect: undefined,
    onDeselect: undefined,
  };
 
})(jQuery);
