/*
 * jQuery NatEdit: base engine
 *
 * Copyright (c) 2015-2017 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";

/* export */
var BaseEngine;

(function($) {

/*****************************************************************************
 * constructor
 */
BaseEngine = function() {
  var self = this;

  if (typeof(self.opts) === 'undefined') {
    self.opts = {};
  }
  self.log("BaseEngine::constructor");
};


/*************************************************************************
 * init this engine
 */
BaseEngine.prototype.init = function() {
  var self = this;

  //self.log("BaseEngine::init");

  return $.Deferred().resolve(self).promise();
};

/*************************************************************************
 * init gui
 */
BaseEngine.prototype.initGui = function() {
  // nop
};

/*************************************************************************
 * get the DOM element that holds the editor engine
 */
BaseEngine.prototype.getWrapperElement = function() {
  var self = this;

  return $(self.shell.txtarea);
};

/*************************************************************************
 * register events to editor engine
 */
BaseEngine.prototype.on = function(eventName, func) {
  var self = this;

  // by default forward it to wrapper element
  return self.getWrapperElement().on(eventName, func);  
};

/*************************************************************************
 * set the size of the editor
 */
BaseEngine.prototype.setSize = function(width, height) {
  var self = this,
      elem = self.getWrapperElement();

  if (width) {
    elem.width(width);
  }

  if (height) {
    elem.height(height);
  }
};

/*************************************************************************
 * called during save process
 */
BaseEngine.prototype.beforeSubmit = function() {
  return $.Deferred().resolve().promise();
};

/*************************************************************************
 * set the value of the editor
 */
BaseEngine.prototype.setValue = function(val) {
  var self = this,
      elem = self.getWrapperElement();

  elem.val(val);
};

/*************************************************************************
 * debug logging 
 */
BaseEngine.prototype.log = function() {
  var self = this;

  if (console && self.opts.debug) {
    console && console.log.apply(console, arguments); // eslint-disable-line no-console
  }
};

/*************************************************************************
 * insert stuff at the given cursor position
 */
BaseEngine.prototype.insert = function(/* text */) {
  /*var self = this;*/

  throw("not implemented: insert()");
};

/*************************************************************************
 * remove the selected substring
 */
BaseEngine.prototype.remove = function() {
  /*var self = this;*/

  throw("not implemented: remove()");
};

/*************************************************************************
 * returns the current selection
 */
BaseEngine.prototype.getSelection = function() {
  /*var self = this;*/

  throw("not implemented: getSelection()");
};

/*************************************************************************
  * returns the currently selected lines
  */
BaseEngine.prototype.getSelectionLines = function() {
  /*var self = this;*/

  throw("not implemented: getSelectionLines()");
};

/*************************************************************************
 * set the selection
 */
BaseEngine.prototype.setSelectionRange = function(/*start, end*/) {
  /*var self = this;*/

  throw("not implemented: setSelectionRange()");
};

/*************************************************************************
 * set the caret position to a specific position. thats done by setting
 * the selection range to a single char at the given position
 */
BaseEngine.prototype.setCaretPosition = function(/*caretPos*/) {
  /*var self = this;*/

  throw("not implemented: setCaretPosition()");
};

/*************************************************************************
 * get the caret position 
 */
BaseEngine.prototype.getCaretPosition = function() {
  /*var self = this;*/

  throw("not implemented: getCaretPosition()");
};

/*************************************************************************
 * undo recent change
 */
BaseEngine.prototype.undo = function() {
  /*var self = this;*/

  throw("not implemented: undo()");
};

/*************************************************************************
 * redo recent change
 */
BaseEngine.prototype.redo = function() {
  /*var self = this;*/

  throw("not implemented: redo()");
};

/*****************************************************************************
 * handle toolbar action. returns the data to be used by the toolbar action.
 * return undef to intercept the shell's actions
 */
BaseEngine.prototype.handleToolbarAction = function(ui) {
  return ui.data();
};

/*************************************************************************
 * used for line oriented tags - like bulleted lists
 * if you have a multiline selection, the tagOpen/tagClose is added to each line
 * if there is no selection, select the entire current line
 * if there is a selection, select the entire line for each line selected
 */
BaseEngine.prototype.insertLineTag = function(/*markup*/) {
  /*var self = this;*/

  throw("not implemented: insertLineTag()");
};

/*************************************************************************
 * insert a topic markup tag 
 */
BaseEngine.prototype.insertTag = function(/*markup*/) {
  /*var self = this;*/

  throw("not implemented: insertTag()");
};

/*************************************************************************
 * insert a TML table with the given header rows, rows and cols
 * opts: 
 * {
 *   heads: integer, // number of header rows
 *   rows: integer, // number of rows
 *   cols: integer, // number of columns
 * }
 */
BaseEngine.prototype.insertTable = function(opts) {
  var self = this, table;

  if (typeof(opts.heads) === 'undefined') {
    opts.heads = 0;
  }
  if (typeof(opts.rows) === 'undefined') {
    opts.rows = 0;
  }
  if (typeof(opts.cols) === 'undefined') {
    opts.cols = 0;
  }

  opts.init = self.getTableSelection();
  table = self.generateTMLTable(opts);

  self.remove();
  self.insert(table);
};

/***************************************************************************
 * insert a link
 * opts is a hash of params that can have either of two forms:
 *
 * insert a link to a topic:
 * {
 *   web: "TheWeb",
 *   topic: "TheTopic",
 *   text: "the link text" (optional)
 * }
 *
 * insert an external link:
 * {
 *   url: "http://...",
 *   text: "the link text" (optional)
 * }
 *
 * insert an attachment link:
 * {
 *   web: "TheWeb",
 *   topic: "TheTopic",
 *   file: "TheAttachment.jpg",
 *   text: "the link text" (optional)
 * }
 */
BaseEngine.prototype.insertLink = function(opts) {
  var self = this, markup;

console.log("insertLink opts=",opts);

  if (typeof(opts.url) !== 'undefined') {
    // external link
    if (typeof(opts.url) === 'undefined' || opts.url === '') {
      return; // nop
    }

    if (typeof(opts.text) !== 'undefined' && opts.text !== '') {
      markup = "[["+opts.url+"]["+opts.text+"]]";
    } else {
      markup = "[["+opts.url+"]]";
    }
  } else if (typeof(opts.file) !== 'undefined') {
    // attachment link

    if (typeof(opts.web) === 'undefined' || opts.web === '' || 
        typeof(opts.topic) === 'undefined' || opts.topic === '') {
      return; // nop
    }

    if (opts.file.match(/\.(bmp|png|jpe?g|gif|svg)$/i) && foswiki.getPreference("NatEditPlugin").ImagePluginEnabled) {
      markup = '%IMAGE{"'+opts.file+'"';
      if (opts.web !== self.shell.opts.web || opts.topic !== self.shell.opts.topic) {
        markup += ' topic="';
        if (opts.web !== self.shell.opts.web) {
          markup += opts.web+'.';
        }
        markup += opts.topic+'"';
      }
      if (typeof(opts.text) !== 'undefined' && opts.text !== '') {
        markup += ' caption="'+opts.text+'"';
      }
      markup += ' size="320"}%';
    } else {
      // linking to an ordinary attachment

      if (opts.web === self.shell.opts.web && opts.topic === self.shell.opts.topic) {
        markup = "[[%ATTACHURLPATH%/"+opts.file+"]";
      } else {
        markup = "[[%PUBURLPATH%/"+opts.web+"/"+opts.topic+"/"+opts.file+"]";
      }

      if (typeof(opts.text) !== 'undefined' && opts.text !== '') {
        markup += "["+opts.text+"]";
      } else {
        markup += "["+opts.file+"]";
      }
      markup += "]";
    }

  } else {
    // wiki link
    
    if (typeof(opts.topic) === 'undefined' || opts.topic === '') {
      return; // nop
    }

    if (opts.web === self.shell.opts.web) {
      markup = "[["+opts.topic+"]";
    } else {
      markup = "[["+opts.web+"."+opts.topic+"]";
    }

    if (typeof(opts.text) !== 'undefined' && opts.text !== '') {
      markup += "["+opts.text+"]";
    } 
    markup += "]";
  }

  self.remove();
  self.insert(markup);
};

/*****************************************************************************
 * parse the current selection into a two-dimensional array
 * to be used initializing a table. rows are separated by \n, columns by whitespace
 */
BaseEngine.prototype.getTableSelection = function() {
  var self = this,
      selection = self.getSelection().replace(/^\s+|\s+$/g, ""),
      result = [],
      rows = selection.split(/\n/),
      i;

  for (i = 0; i < rows.length; i++) {
    result.push(rows[i].split(/\s+/));
  }

  return result;
};

/*****************************************************************************
 * generate a tml table
 * opts: 
 * {
 *   heads: integer, // number of header rows
 *   rows: integer, // number of rows
 *   cols: integer, // number of columns
 *   init: two-dim array of initial content 
 * }
 */
BaseEngine.prototype.generateTMLTable = function(opts) {
  var result = "", i, j, cell;

  for (i = 0; i < opts.heads; i++) {
    result += '|';
    for (j = 0; j < opts.cols; j++) {
      result += ' *head* |';
    }
    result += "\n";
  }
  for (i = 0; i < opts.rows; i++) {
    result += '|';
    for (j = 0; j < opts.cols; j++) {
      if (typeof(opts.init) !== 'undefined' && typeof(opts.init[i]) !== 'undefined') {
        cell = opts.init[i][j];
      }
      cell = cell || 'data';
      result += ' '+cell+' |';
    }
    result += "\n";
  }

  return result;
};

/*****************************************************************************
 * generate an html table, see generateTMLTable 
 */
BaseEngine.prototype.generateHTMLTable = function(opts) {
  var result = "", i, j, cell;

  result += "<table>";

  if (opts.heads) {
    result += "<thead>";
    for (i = 0; i < opts.heads; i++) {
      result += "<tr>";
      for (j = 0; j < opts.cols; j++) {
        result += "<th>head</th>";
      }
      result += "</tr>";
    }
    result += "</thead>";
  }

  result += "<tbody>";
  for (i = 0; i < opts.rows; i++) {
    result += "<tr>";
    for (j = 0; j < opts.cols; j++) {
      if (typeof(opts.init) !== 'undefined' && typeof(opts.init[i]) !== 'undefined') {
        cell = opts.init[i][j];
      }
      cell = cell || 'data';
      result += '<td>'+cell+'</td>';
    }
    result += "</tr>";
  }

  result += "</table>";

  return result;
};

/*****************************************************************************
 * search & replace a term in the textarea
 */
BaseEngine.prototype.searchReplace = function(/*term, text, ignoreCase*/) {
  /*var self = this;*/

  throw("not implemented: searchReplace()");
};

})(jQuery);
