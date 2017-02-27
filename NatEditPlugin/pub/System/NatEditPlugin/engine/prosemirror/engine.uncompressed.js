/*
 * jQuery NatEdit: prosemirror engine
 *
 * Copyright (c) 2016 Michael Daum http://michaeldaumconsulting.com
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

ProsemirrorEngine.prototype = new BaseEngine();
ProsemirrorEngine.prototype.constructor = ProsemirrorEngine;
ProsemirrorEngine.prototype.parent = BaseEngine.prototype;

function ProsemirrorEngine(shell, opts) {
  var self = this;

  self.shell = shell;
  self.opts = $.extend({}, ProsemirrorEngine.defaults, self.shell.opts.prosemirror, opts);
};


/*************************************************************************
 * init this engine
 */
ProsemirrorEngine.prototype.init = function() {
  var self = this,
      pubUrlPath = foswiki.getPreference("PUBURLPATH"),
      systemWeb = foswiki.getPreference('SYSTEMWEB'),
      proseMirrorPath = pubUrlPath+'/'+systemWeb+'/ProseMirrorContrib',
      dfd = $.Deferred();

  self.shell.getScript(proseMirrorPath+"/prosemirror.js").done(function() {
    var $elem = $(self.shell.txtarea), opts,
        $place = $("<div />").insertAfter($elem);

    opts = $.extend({}, {
      place: $place[0],
      doc: $elem.is("textarea")?$elem.val():$elem[0],
      docFormat: $elem.is("textarea")?'text':"dom"
    }, self.opts);

    $elem.hide();
    self.pm = new prosemirror.ProseMirror(opts); 

    // forward events to shell
    self.pm.on("focus", function() {
      if (typeof(self.shell.onFocus) !== 'undefined') {
        self.shell.onFocus();
      }
    });

    dfd.resolve(self);
  });

  return dfd.promise();
};

/*************************************************************************
 * register events to editor engine
 */
ProsemirrorEngine.prototype.on = function(eventName, func) {
  var self = this;

  self.pm.on(eventName, func);  
  return self.pm;
};

/*************************************************************************
 * insert stuff at the given cursor position
 */
ProsemirrorEngine.prototype.insert = function(newText) {
  var self = this;

  throw("not implemented: insert()");
};

/*************************************************************************
 * remove the selected substring
 */
ProsemirrorEngine.prototype.remove = function() {
  var self = this;

  return self.pm.deleteSelection();
};

/*************************************************************************
 * returns the current selection
 */
ProsemirrorEngine.prototype.getSelection = function() {
  var self = this;

  return self.pm.selection();
};

/*************************************************************************
  * returns the currently selected lines
  */
ProsemirrorEngine.prototype.getSelectionLines = function() {
/*
  var self = this,
      doc = self.pm.getDoc(),
      start = doc.getCursor("from"),
      end = doc.getCursor("to");

  start.ch = 0;
  start = doc.posFromIndex(doc.indexFromPos(start));

  end.line++;
  end.ch = 0;
  end = doc.posFromIndex(doc.indexFromPos(end)-1);

  //console.log("start=",start,"end=",end);

  doc.setSelection(start, end);

  return doc.getSelection();
*/
};

/*************************************************************************
  * returns the current selection
  */
ProsemirrorEngine.prototype.getSelectionRange = function() {
  var self = this;

  return self.getSelection();
};


/*************************************************************************
 * undo recent change
 */
ProsemirrorEngine.prototype.undo = function() {
  var self = this;

  return self.pm.undo();
};

/*************************************************************************
 * redo recent change
 */
ProsemirrorEngine.prototype.redo = function() {
  var self = this;

  return self.pm.redo();
};

/*************************************************************************
 * used for line oriented tags - like bulleted lists
 * if you have a multiline selection, the tagOpen/tagClose is added to each line
 * if there is no selection, select the entire current line
 * if there is a selection, select the entire line for each line selected
 */
ProsemirrorEngine.prototype.insertLineTag = function(markup) {
/*
  var self = this,
      tagOpen = markup[0],
      selection,
      tagClose = markup[2],
      doc = self.pm.getDoc(),
      start, end;

  selection = self.getSelectionLines() || markup[1];
  doc.replaceSelection(tagOpen+selection+tagClose, "start");

  start = doc.posFromIndex(doc.indexFromPos(doc.getCursor())+tagOpen.length);
  end = doc.posFromIndex(doc.indexFromPos(doc.getCursor())+tagOpen.length+selection.length);

  console.log("start=",start,"end=",end);
  self.setSelection(start, end);
*/
  
};

/*************************************************************************
 * insert a topic markup tag 
 */
ProsemirrorEngine.prototype.insertTag = function(markup) {
/*
  var self = this,
      tagOpen = markup[0],
      selection,
      tagClose = markup[2],
      doc = self.pm.getDoc(),
      start, end;

  selection = self.getSelectionRange() || markup[1];
  doc.replaceSelection(tagOpen+selection+tagClose, "start");

  start = doc.posFromIndex(doc.indexFromPos(doc.getCursor())+tagOpen.length);
  end = doc.posFromIndex(doc.indexFromPos(doc.getCursor())+tagOpen.length+selection.length);

  console.log("start=",start,"end=",end);
  doc.setSelection(start, end);
*/
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
ProsemirrorEngine.prototype.insertTable = function(opts) {
  var self = this;

  throw("not implemented: insertTable()");
};

/*****************************************************************************
 * search & replace a term in the textarea
 */
ProsemirrorEngine.prototype.searchReplace = function(search, replace, ignoreCase) {
  var self = this;

  throw("not implemented: searchReplace()");
};

/*************************************************************************
 * get the DOM element that holds the editor engine
 */
ProsemirrorEngine.prototype.getWrapperElement = function() {
  var self = this;

  return self.pm?$(self.pm.wrapper):null;
};

/***************************************************************************
 * editor defaults
 */
ProsemirrorEngine.defaults = {
  debug: false
};

/*************************************************************************
 * register engine to NatEditor shell
 */
$.NatEditor.engines.prosemirror = {
  createEngine: function(shell) {
    return (new ProsemirrorEngine(shell)).init();
  }
};

})(jQuery);
