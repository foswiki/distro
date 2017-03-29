/*
 * jQuery NatEdit: codemirror engine
 *
 * Copyright (c) 2016-2017 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */

/*global BaseEngine:false CodeMirror:false ImageWidget:false */

"use strict";
(function($) {

/* hepler class for searching */
function SearchState() {
  var self = this;

  self.cursor = null;
  self.overlay = null;
  self.annotate = null;
  self.query = null;
  self.found = false;
}

/*****************************************************************************
 * constructor
 */

CodemirrorEngine.prototype = new BaseEngine();
CodemirrorEngine.prototype.constructor = CodemirrorEngine;
CodemirrorEngine.prototype.parent = BaseEngine.prototype;

function CodemirrorEngine(shell, opts) {
  var self = this;

  self.shell = shell;
  self.searchState = undefined;
  self.opts = $.extend({}, CodemirrorEngine.defaults, self.shell.opts.codemirror, opts);
}

/*************************************************************************
 * init this engine
 */
CodemirrorEngine.prototype.init = function() {
  var self = this,
      pubUrlPath = foswiki.getPreference("PUBURLPATH"),
      systemWeb = foswiki.getPreference('SYSTEMWEB'),
      editorPath = pubUrlPath+'/'+systemWeb+'/CodeMirrorContrib',
      dfd = $.Deferred();

  $('<link>')
    .appendTo('head')
    .attr({type : 'text/css', rel : 'stylesheet'})
    .attr('href', editorPath + '/lib/codemirror.css');

  $('<link>')
    .appendTo('head')
    .attr({type : 'text/css', rel : 'stylesheet'})
    .attr('href', editorPath + '/theme/foswiki.css?t='+(new Date()).getTime());

  $('<link>')
    .appendTo('head')
    .attr({type : 'text/css', rel : 'stylesheet'})
    .attr('href', editorPath + '/addon/search/matchesonscrollbar.css');

  self.shell.getScript(editorPath+"/lib/codemirror.js").done(function() {
    CodeMirror.modeURL = editorPath+'/'+'/mode/%N/%N.js';

    $.when(
      self.shell.getScript(editorPath+"/addon/mode/loadmode.js"),
      self.shell.getScript(editorPath+"/addon/fold/foldcode.js"),
      self.shell.getScript(editorPath+"/addon/fold/foldgutter.js"),
      self.shell.getScript(editorPath+"/addon/search/searchcursor.js"),
      self.shell.getScript(editorPath+"/addon/scroll/annotatescrollbar.js"),
      self.shell.getScript(editorPath+"/addon/search/matchesonscrollbar.js"),
      self.shell.getScript(editorPath+"/widgets/widgets.js"),
      self.shell.preloadDialog("searchdialog")
    ).done(function() {

        CodeMirror.requireMode(self.opts.mode || 'foswiki', function() {
          var $txtarea = $(self.shell.txtarea),
              cols = $txtarea.attr("cols"),
              rows = $txtarea.attr("rows"),
              lineHeight = parseInt($txtarea.css("line-height"), 10);

          self.cm = CodeMirror.fromTextArea(self.shell.txtarea, self.opts); 
          window.cm = self.cm; //playground

          if (typeof(cols) !== 'undefined' && cols > 0) {
            self.cm.setSize(cols+"ch");
          }
          if (typeof(rows) !== 'undefined' && rows > 0) {
            rows = (rows*lineHeight)+"px";
            self.cm.setSize(null, rows);
          }

          // forward events to shell
          self.cm.on("focus", function() {
            if (typeof(self.shell.onFocus) !== 'undefined') {
              self.shell.onFocus();
            }
          });

          // extend extra keys
          var extraKeys = $.extend(true, {}, 
            self.cm.getOption("extraKeys"), {
              "Ctrl-F": function() {
                self.openSearchDialog();
              },
              "Ctrl-G": function() {
                self.search();
              },
              "F3": function() {
                self.search();
              },
              "Esc": function() {
                self._searchDialogOpen = false;
                self.clearSearchState();
            }
          });
          self.cm.setOption("extraKeys", extraKeys);

          $(window).on("keydown", function(e) { // suppress global ctrl-f
            if (e.keyCode === 114 || (e.ctrlKey && e.keyCode === 70)) {
              // when we have only a single natedit on a page, then global ctrl-f opens the search dialog
              if ($(".ui-natedit").length === 1) { 
                self.cm.focus();
                self.openSearchDialog();
              }
              e.preventDefault();
              return false;
            }
          });

/*
          self.cm.on("change", function(cm, change) {
            self.updateWidgets(change);
          });

          self.insertWidgets();
*/

          dfd.resolve(self);
        });
    });
  });

  // listen to window resize and refresh codemirror.  a resize event is also triggered by a jquery.tabpane.
  // a codemirror element must be refreshed when becoming visible then.
  // (see also https://github.com/codemirror/CodeMirror/issues/3527)
  $(window).on("resize", function() {
    if (typeof(self.cm) !== 'undefined') {
      self.cm.refresh();
    }
  });

  return dfd.promise();
};

/*************************************************************************
 * intercept save process
 */
CodemirrorEngine.prototype.beforeSubmit = function(action) {
  var self = this;

  self.cm.save(); // copy to textarea

  return $.Deferred().resolve().promise();
};

/*************************************************************************
 * register events to editor engine
 */
CodemirrorEngine.prototype.on = function(eventName, func) {
  var self = this;

  self.cm.on(eventName, func);  
  return self.cm;
};

/*************************************************************************
 * replace specific elements with widgets to display them 
 */
CodemirrorEngine.prototype.insertWidgets = function(/*change*/) {
  var self = this,
      cursor = self.cm.getSearchCursor(/<img[^>]+\/>/, 0, 0);

  while (cursor.findNext()) {
    new ImageWidget(self.cm, cursor.pos.from, cursor.pos.to);
  }

};

/*************************************************************************
 * update all widgets in the range of the given change 
 */
CodemirrorEngine.prototype.updateWidgets = function(/*change*/) {
  var self = this,
      marks = self.cm.getAllMarks(),
      images = [],
      cursor = self.cm.getSearchCursor(/<img[^>]+\/>/, 0, 0),
      found;

  // get all image widgets
  $.each(marks, function(index, mark) {
    var widget = $(mark.replacedWith).data("ImageWidget");
    if (widget) {
      images.push(widget);
    }
  });

  while (cursor.findNext()) {
    found = false;
    $.each(images, function(index, widget) {
      if (cursor.pos.from.ch === widget.from.ch && 
          cursor.pos.from.line === widget.from.line &&
          cursor.pos.to.ch === widget.to.ch &&
          cursor.pos.to.line === widget.to.line) {
        found = true;
        return false;
      }
    });
    if (!found) {
      new ImageWidget(self.cm, cursor.pos.from, cursor.pos.to);
    }
  }
};

/*************************************************************************
 * remove the selected substring
 */
CodemirrorEngine.prototype.remove = function() {
  var self = this;

  return self.cm.replaceSelection("");
};

/*************************************************************************
 * returns the current selection
 */
CodemirrorEngine.prototype.getSelection = function() {
  var self = this;

  return self.cm.getSelection();
};

/*************************************************************************
  * returns the currently selected lines
  */
CodemirrorEngine.prototype.getSelectionLines = function() {
  var self = this,
      doc = self.cm.getDoc(),
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
};

/*************************************************************************
  * returns the current selection
  */
CodemirrorEngine.prototype.getSelectionRange = function() {
  var self = this;

  return self.cm.getDoc().getSelection();
};


/*************************************************************************
 * undo recent change
 */
CodemirrorEngine.prototype.undo = function() {
  var self = this;

  return self.cm.undo();
};

/*************************************************************************
 * redo recent change
 */
CodemirrorEngine.prototype.redo = function() {
  var self = this;

  return self.cm.redo();
};

/*************************************************************************
 * insert stuff at the given cursor position
 */
CodemirrorEngine.prototype.insert = function(text) {
  var self = this,
      doc = self.cm.getDoc(),
      start = doc.getCursor();

  doc.replaceRange(text, start);
};


/*************************************************************************
 * used for line oriented tags - like bulleted lists
 * if you have a multiline selection, the tagOpen/tagClose is added to each line
 * if there is no selection, select the entire current line
 * if there is a selection, select the entire line for each line selected
 */
CodemirrorEngine.prototype.insertLineTag = function(markup) {
  var self = this,
      tagOpen = markup[0],
      selection,
      tagClose = markup[2],
      doc = self.cm.getDoc(),
      start, end;

  selection = self.getSelectionLines() || markup[1];
  doc.replaceSelection(tagOpen+selection+tagClose, "start");

  start = doc.posFromIndex(doc.indexFromPos(doc.getCursor())+tagOpen.length);
  end = doc.posFromIndex(doc.indexFromPos(doc.getCursor())+tagOpen.length+selection.length);

  //console.log("start=",start,"end=",end);
  doc.setSelection(start, end);

  self.cm.focus();
  
};

/*************************************************************************
 * insert a topic markup tag 
 */
CodemirrorEngine.prototype.insertTag = function(markup) {
  var self = this,
      tagOpen = markup[0],
      selection,
      tagClose = markup[2],
      doc = self.cm.getDoc(),
      start, end;

  selection = self.getSelectionRange() || markup[1];
  doc.replaceSelection(tagOpen+selection+tagClose, "start");

  start = doc.posFromIndex(doc.indexFromPos(doc.getCursor())+tagOpen.length);
  end = doc.posFromIndex(doc.indexFromPos(doc.getCursor())+tagOpen.length+selection.length);

  //console.log("start=",start,"end=",end);
  doc.setSelection(start, end);
};

/******************************************************************************/
CodemirrorEngine.prototype.getSearchState = function() {
  var self = this;

  if (typeof(self.searchState) === 'undefined') {
    self.searchState = new SearchState();
  }

  return self.searchState;
};

/******************************************************************************/
CodemirrorEngine.prototype.clearSearchState = function() {
  var self = this,
      state = self.getSearchState();

  if (state.overlay) {
    self.cm.removeOverlay(state.overlay);
  }

  if (state.annotate) { 
    state.annotate.clear(); 
  }

  self.searchState = undefined;
};

/******************************************************************************/
CodemirrorEngine.prototype.searchOverlay = function(term, ignoreCase) {
  var query;

  if (typeof(term) === 'string') {
    query = new RegExp(term.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"), ignoreCase ? "gi" : "g");
  } else {
    query = term;
  }

  return {
    token: function(stream) {
      query.lastIndex = stream.pos;
      var match = query.exec(stream.string);
      if (match && match.index === stream.pos) {
        stream.pos += match[0].length || 1;
        return "searching";
      } else if (match) {
        stream.pos = match.index;
      } else {
        stream.skipToEnd();
      }
    }
  };
};

/*****************************************************************************
 * opens the search dialog
 */
CodemirrorEngine.prototype.openSearchDialog = function() {
  var self = this;

  if (self._searchDialogOpen) {
    return;
  }

  self._searchDialogOpen = true;

  self.shell.dialog({
    name: "searchdialog",
    data: {
        web: self.shell.opts.web,
        topic: self.shell.opts.topic,
        selection: self.getSelection() || self.getSearchState().query
    }
  }).then(function(dialog) {
      var $dialog = $(dialog),
          search = $dialog.find("input[name='search']").val(),
          ignoreCase = $dialog.find("input[name='ignorecase']:checked").length?true:false;
      self._searchDialogOpen = false;
      self.search(search, ignoreCase);
    }, function(/*dialog*/) {
      self._searchDialogOpen = false;
      self.clearSearchState();
    }
  );
};

/*****************************************************************************
 * search in editor
 */
CodemirrorEngine.prototype.search = function(term, ignoreCase) {
  var self = this, state, query;

  if (typeof(term) !== 'undefined') {
    if (/^\s*\/(.*)\/\s*$/.test(term)) {
      query = new RegExp(RegExp.$1, ignoreCase ? "gi" : "g");
    } else {
      query = term;
    }

    self.clearSearchState();
    state = self.getSearchState();
    state.cursor = self.cm.getSearchCursor(query, 0, ignoreCase);
    state.overlay = self.searchOverlay(query, ignoreCase);
    state.query = query;
    self.cm.addOverlay(state.overlay);
    if (self.cm.showMatchesOnScrollbar) {
      if (state.annotate) { 
        state.annotate.clear(); 
        state.annotate = null; 
      }
      state.annotate = self.cm.showMatchesOnScrollbar(query, ignoreCase);
    }
  } else {
    state = self.getSearchState();
  }

  if (state.cursor) {
    if(state.cursor.findNext()) {
      state.found = true;
      self.cm.setSelection(state.cursor.from(), state.cursor.to());
      self.cm.scrollIntoView({from: state.cursor.from(), to: state.cursor.to()}, 20);
    } else {
      self.shell.showMessage("info", state.found?$.i18n("no more matches"):$.i18n("nothing found"));
      self.clearSearchState();
    }
  }
};

/*****************************************************************************
 * search & replace a term in the editor
 */
CodemirrorEngine.prototype.searchReplace = function(term, text, ignoreCase) {
  var self = this, cursor, i, query;

  if (/^\s*\/(.*)\/\s*$/.test(term)) {
    query = new RegExp(RegExp.$1);
  } else {
    query = term;
  }

  cursor = self.cm.getSearchCursor(query, 0, ignoreCase);

  for(i = 0; cursor.findNext(); i++) {
    cursor.replace(text);
  }

  return i;
};

/*************************************************************************
 * get the DOM element that holds the editor engine
 */
CodemirrorEngine.prototype.getWrapperElement = function() {
  var self = this;

  return self.cm?$(self.cm.getWrapperElement()):null;
};

/*************************************************************************
 * set the size of editor
 */
CodemirrorEngine.prototype.setSize = function(width, height) {
  var self = this;

  width = width || 'auto';
  height = height || 'auto';

  self.cm.setSize(width, height);
  self.cm.refresh();
};

/*************************************************************************
 * set the value of the editor
 */
CodemirrorEngine.prototype.setValue = function(val) {
  var self = this;

  self.cm.setValue(val);
};

/***************************************************************************
 * editor defaults
 */
CodemirrorEngine.defaults = {
  //value
  debug: true,
  mode: 'foswiki',
  theme: 'foswiki',
  indentUnit: 3, 
  smartIndent: false,
  tabSize: 3,
  indentWithTabs: false, 
  //rtlMoveVisually
  electricChars: false,
  keyMap: "default",
  lineWrapping: true,
  lineNumbers: false, 
  firstLineNumber: 1,
  //lineNumberFormatter
  readOnly: false,
  showCursorWhenSelecting: false,
  undoDepth: 40,
  //tabindex
  autofocus: false,
  autoresize: false,
  singleCursorHeightPerLine: false,

  //gutters
  fixedGutter: true,
  foldGutter: true,
  gutters: [
    "CodeMirror-linenumbers", 
    "CodeMirror-foldgutter"
  ],

  // addon options
  extraKeys: {
    "Enter": "newlineAndIndentContinueFoswikiList",
    "Tab": "insertSoftTab",
    "Ctrl-Q": "toggleFold"
  }
  //matchBrackets: false, 
  //enterMode: "keep", 
  //tabMode: "shift" 
};

/*************************************************************************
 * register engine to NatEditor shell
 */
$.NatEditor.engines.codemirror = {
  createEngine: function(shell) {
    return (new CodemirrorEngine(shell)).init();
  }
};

})(jQuery);
