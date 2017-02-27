/*
 * jQuery NatEdit: base engine
 *
 * Copyright (c) 2015-2016 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
'use strict';

(function($) {

/*****************************************************************************
 * constructor
 */
window.BaseEngine = function BaseEngine() {
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
  //var self = this;

  //self.log("BaseEngine::init");
  // return dfd.promise();
};

/*************************************************************************
 * init gui
 */
BaseEngine.prototype.initGui = function() {
  // nop
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
    console.log.apply(console, arguments);
  }
};

/*************************************************************************
 * insert stuff at the given cursor position
 */
BaseEngine.prototype.insert = function(newText) {
  var self = this;

  throw("not implemented: insert()");
};

/*************************************************************************
 * remove the selected substring
 */
BaseEngine.prototype.remove = function() {
  var self = this;

  throw("not implemented: remove()");
};

/*************************************************************************
 * returns the current selection
 */
BaseEngine.prototype.getSelection = function() {
  var self = this;

  throw("not implemented: getSelection()");
};

/*************************************************************************
  * returns the currently selected lines
  */
BaseEngine.prototype.getSelectionLines = function() {
  var self = this;

  throw("not implemented: getSelectionLines()");
};

/*************************************************************************
 * set the selection
 */
BaseEngine.prototype.setSelectionRange = function(start, end) {
  var self = this;

  throw("not implemented: setSelectionRange()");
};

/*************************************************************************
 * set the caret position to a specific position. thats done by setting
 * the selection range to a single char at the given position
 */
BaseEngine.prototype.setCaretPosition = function(caretPos) {
  var self = this;

  throw("not implemented: setCaretPosition()");
};

/*************************************************************************
 * get the caret position 
 */
BaseEngine.prototype.getCaretPosition = function() {
  var self = this;

  throw("not implemented: getCaretPosition()");
};

/*************************************************************************
 * undo recent change
 */
BaseEngine.prototype.undo = function() {
  var self = this;

  throw("not implemented: undo()");
};

/*************************************************************************
 * redo recent change
 */
BaseEngine.prototype.redo = function() {
  var self = this;

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
BaseEngine.prototype.insertLineTag = function(markup) {
  var self = this;

  throw("not implemented: insertLineTag()");
};

/*************************************************************************
 * insert a topic markup tag 
 */
BaseEngine.prototype.insertTag = function(markup) {
  var self = this;

  throw("not implemented: insertTag()");
};

/*************************************************************************
 * insert a TML table with the given header rows, rows and cols
 * opts: 
 * {
 *   heads: integer, // number of header rows
 *   rows: integer, // number of rows
 *   cols: integer, // number of columns
 *   editable: boolean, // add %EDITTABLE markup
 * }
 */
BaseEngine.prototype.insertTable = function(opts) {
  var self = this, output = [], editTableLine, i, j, line;

  if (typeof(opts.heads) === 'undefined') {
    opts.heads = 0;
  }
  if (typeof(opts.rows) === 'undefined') {
    opts.rows = 0;
  }
  if (typeof(opts.cols) === 'undefined') {
    opts.cols = 0;
  }

  if (opts.editable) {
    editTableLine = '%EDITTABLE{format="';

    for (i = 0; i < opts.cols; i++) {
      editTableLine += '| text,20';
    }

    editTableLine += '|"}%';
    output.push(editTableLine);
  }

  for (i = 0; i < opts.heads; i++) {
    line = '|';
    for (j = 0; j < opts.cols; j++) {
      line += ' *head* |';
    }
    output.push(line);
  }
  for (i = 0; i < opts.rows; i++) {
    line = '|';
    for (j = 0; j < opts.cols; j++) {
      line += ' data |';
    }
    output.push(line);
  }
  self.remove();
  self.insertTag(['', output.join("\n")+"\n", '']);
};

/*****************************************************************************
 * search & replace a term in the textarea
 */
BaseEngine.prototype.searchReplace = function(term, text, ignoreCase) {
  var self = this;

  throw("not implemented: searchReplace()");
};

})(jQuery);
