/*
 * jQuery NatEdit: raw engine
 *
 * Copyright (c) 2008-2016 Michael Daum http://michaeldaumconsulting.com
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

RawEngine.prototype = new BaseEngine ();
RawEngine.prototype.constructor = RawEngine;
RawEngine.prototype.parent = BaseEngine.prototype;

function RawEngine(shell, opts) {
  var self = this;

  self.shell = shell;
  self.opts = $.extend({}, RawEngine.defaults, self.shell.opts.raw, opts);
}


/*************************************************************************
 * init this engine
 */
RawEngine.prototype.init = function() {
  var self = this,
      dfd = $.Deferred();

  if (typeof(self.shell.txtarea.selectionStart) === 'undefined') {
    self.oldIE = true; /* all IEs up to IE9; IE10 has got selectionStart/selectionEnd */
  }

  /* listen to keystrokes */
  $(self.shell.txtarea).on("keydown", function(ev) {
    if (ev.keyCode == 13) {
      self.handleLineFeed(ev);
    } else if (ev.keyCode == 9) {
      self.handleTab(ev);
    }
  }); 

  dfd.resolve(self);

  return dfd.promise();
};

/*************************************************************************
 * init gui
 */
RawEngine.prototype.initGui = function() {
  var self = this;
  self.undoManager = new UndoManager(self);
};

/*************************************************************************
 * insert stuff at the given cursor position
 */
RawEngine.prototype.insert = function(newText) {
  var self = this, startPos, endPos, text, prefix, postfix, 
      txtarea = self.shell.txtarea;

  self.getSelectionRange();
  startPos = txtarea.selectionStart;
  endPos = txtarea.selectionEnd;
  text = txtarea.value;
  prefix = text.substring(0, startPos);
  postfix = text.substring(endPos);

  txtarea.value = prefix + newText + postfix;
  self.setCaretPosition(startPos);
  self.undoManager.saveState("command");
};

/*************************************************************************
 * remove the selected substring
 */
RawEngine.prototype.remove = function() {
  var self = this, startPos, endPos, text, selection,
      txtarea = self.shell.txtarea;

  self.getSelectionRange();
  startPos = txtarea.selectionStart;
  endPos = txtarea.selectionEnd;
  text = txtarea.value;
  selection = text.substring(startPos, endPos);

  txtarea.value = text.substring(0, startPos) + text.substring(endPos);
  self.setSelectionRange(startPos, startPos);
  self.undoManager.saveState("command");

  return selection;
};

/*************************************************************************
 * compatibility method for IE: this sets txtarea.selectionStart and
 * txtarea.selectionEnd of the current selection in the given textarea 
 */
RawEngine.prototype.getSelectionRange = function() {
  var self = this, text, c, range, rangeCopy, pos, selection,
      txtarea = self.shell.txtarea;

  //self.log("NATEDIT: called getSelectionRange()");
  //$(txtarea).focus();

  if (self.oldIE) {

    text = txtarea.value;
    c = "\x01";
    range = document.selection.createRange();
    selection = range.text || "";
    rangeCopy = range.duplicate();
    rangeCopy.moveToElementText(txtarea);
    range.text = c;
    pos = (rangeCopy.text.indexOf(c));
   
    range.moveStart("character", -1);
    range.text = selection;

    if (pos < 0) {
      pos = text.length;
      selection = "";
    }

    txtarea.selectionStart = pos;
   
    if (selection == "") {
      txtarea.selectionEnd = pos;
    } else {
      txtarea.selectionEnd = pos + selection.length;
    }
  }
 
  return [txtarea.selectionStart, txtarea.selectionEnd];
};

/*************************************************************************
 * returns the current selection
 */
RawEngine.prototype.getSelection = function() {
  var self = this, startPos, endPos, 
      txtarea = self.shell.txtarea;

  self.getSelectionRange();
  startPos = txtarea.selectionStart;
  endPos = txtarea.selectionEnd;

  return txtarea.value.substring(startPos, endPos);
};

/*************************************************************************
  * returns the currently selected lines
  */
RawEngine.prototype.getSelectionLines = function() {
  var self = this, start, end, text,
      txtarea = self.shell.txtarea;

  self.getSelectionRange();
  start = txtarea.selectionStart;
  end = txtarea.selectionEnd;
  text = txtarea.value;

  while (start > 0 && text.charCodeAt(start-1) != 13 && text.charCodeAt(start-1) != 10) {
    start--;
  }

  while (end < text.length && text.charCodeAt(end) != 13 && text.charCodeAt(end) != 10) {
    end++;
  }

  //self.log("start=",start,"end=",end);

  self.setSelectionRange(start, end);

  return text.substring(start, end);
};

/*************************************************************************
 * set the selection
 */
RawEngine.prototype.setSelectionRange = function(start, end) {
  var self = this, lineFeeds, range,
      txtarea = self.shell.txtarea;

  //self.log("setSelectionRange("+txtarea+", "+start+", "+end+")");

  //$(txtarea).focus();
  if (typeof(txtarea.createTextRange) !== 'undefined' && !$.browser.opera) {
    lineFeeds = txtarea.value.substring(0, start).replace(/[^\r]/g, "").length;
    range = txtarea.createTextRange();
    range.collapse(true);
    range.moveStart('character', start-lineFeeds);
    range.moveEnd('character', end-start);
    range.select();
  } else { 
    txtarea.selectionStart = start;
    txtarea.selectionEnd = end;
  }
};

/*************************************************************************
 * set the caret position to a specific position. thats done by setting
 * the selection range to a single char at the given position
 */
RawEngine.prototype.setCaretPosition = function(caretPos) {
  var self = this;

  //self.log("NATEDIT: setCaretPosition("+caretPos+")");
  self.setSelectionRange(caretPos, caretPos);
};

/*************************************************************************
 * get the caret position 
 */
RawEngine.prototype.getCaretPosition = function() {
  var self = this;

  self.getSelectionRange();

  return self.shell.txtarea.selectionEnd;
};

/*************************************************************************
 * undo recent change
 */
RawEngine.prototype.undo = function() {
  var self = this;

  self.undoManager.undo();
};

/*************************************************************************
 * redo recent change
 */
RawEngine.prototype.redo = function() {
  var self = this;

  self.undoManager.redo();
};

/*************************************************************************
 * handles a tab event:
 * inserts spaces on tab, removes spaces on shift-tab
 */
RawEngine.prototype.handleTab = function(ev) {
  var self = this, text, startPos, endPos, len,
      txtarea = self.shell.txtarea;

  self.getSelectionRange();
  startPos = txtarea.selectionStart;
  endPos = txtarea.selectionEnd;

  if (ev.shiftKey) {

    text = txtarea.value;
    len = text.length;

    if (startPos > 2 &&
      text.substring(startPos-3, startPos) == '   ') {
      self.setSelectionRange(startPos-3, endPos);
      self.remove();
    }
  } else {
    self.insert("   ");
    self.setCaretPosition(startPos+3);
  }

  ev.preventDefault();
};

/*************************************************************************
 * handles a linefeed event:
 * - adds a bullets/enumeration hitting enter in a list,
 * - removes the list prefix hitting enter on an empty line of a list
 */
RawEngine.prototype.handleLineFeed = function(ev) {
  var self = this, startPos, endPos, text, prevLine, 
      list, prefix, postfix,
      txtarea = self.shell.txtarea;

  text = txtarea.value;

  self.getSelectionRange();
  startPos = txtarea.selectionStart;
  endPos = txtarea.selectionEnd;

  while (startPos > 0 && 
    text.charCodeAt(startPos-1) != 13 &&
    text.charCodeAt(startPos-1) != 10) {
    startPos--;
  }

  prevLine = text.substring(startPos, endPos);

  if (ev.shiftKey) {
    if (prevLine.match(/^((?: {3})+)([AaIi]\.?|\*|\d+| ) /)) {
      list = RegExp.$1+RegExp.$2.replace(/./g, " ")+" "; 
    }
  } else {

    if (prevLine.match(/^( {3})+([AaIi]\.?|\*|\d+) *$/)) {
      list = '';
    } else if (prevLine.match(/^((?: {3})+([AaIi]\.?|\*) )/)) {
      list = RegExp.$1;
    } else if (prevLine.match(/^(?:((?: {3})+)(\d+) )/)) {
      list = RegExp.$1 + (parseInt(RegExp.$2, 10)+1) + ' ';
    }
  }

  if (typeof(list) === 'undefined') {
    return;
  }

  if (list == '') {
    prefix = text.substr(0, startPos);
    postfix = text.substr(endPos);
    endPos = startPos;
  } else {
    prefix = text.substr(0, endPos);
    postfix = text.substr(endPos);

    if (self.oldIE) {
      list = "\r\n" + list;
    } else {
      list = "\n" + list;
    }
  }


  txtarea.value = prefix + list + postfix;
  self.setCaretPosition(prefix.length + list.length);
  self.undoManager.saveState("command");

  ev.preventDefault();
};

/*************************************************************************
 * used for line oriented tags - like bulleted lists
 * if you have a multiline selection, the tagOpen/tagClose is added to each line
 * if there is no selection, select the entire current line
 * if there is a selection, select the entire line for each line selected
 */
RawEngine.prototype.insertLineTag = function(markup) {
  var self = this, 
      tagOpen = markup[0],
      sampleText = markup[1],
      tagClose = markup[2],
      startPos, endPos, 
      text, scrollTop, theSelection, 
      pre, post, lines, modifiedSelection,
      i, line, subst, 
      listRegExp = new RegExp(/^(( {3})*)( {3})(\* |\d+ |\d+\. )/),
      nrSpaces = 0,
      txtarea = self.shell.txtarea;

  //self.log("called insertLineTag(..., ",markup,")");

  theSelection = self.getSelectionLines();
  startPos = txtarea.selectionStart;
  endPos = txtarea.selectionEnd;
  text = txtarea.value;

  scrollTop = txtarea.scrollTop;

  if (!theSelection) {
    theSelection = sampleText;
  }

  pre = text.substring(0, startPos);
  post = text.substring(endPos, text.length);

  // test if it is a multi-line selection, and if so, add tagOpen&tagClose to each line
  lines = theSelection.split(/\r?\n/);
  modifiedSelection = '';
  for (i = 0; i < lines.length; i++) {
    line = lines[i];

    if (line.match(/^\s*$/)) {
      // don't append tagOpen to empty lines
      subst = line;
    } else {
      // special case - undent (remove 3 spaces, and bullet or numbered list if outdenting away)
      if ((tagOpen == '' && sampleText == '' && tagClose == '')) {
        subst = line.replace(/^ {3}(\* |\d+ |\d+\. )?/, '');
      }

      // special case - list transform
      else if (listRegExp.test(line) && ( tagOpen == '   1 ' || tagOpen == '   * ')) {
        nrSpaces = RegExp.$1.length; 
        subst = line.replace(listRegExp, '$1' + tagOpen) + tagClose;
      } else {
        subst = tagOpen + line + tagClose;
      }
    }

    modifiedSelection += subst;
    if (i+1 < lines.length) {
      modifiedSelection += '\n';
    }
  }

  txtarea.value = pre + modifiedSelection + post;

  if (lines.length == 1) {
    startPos += nrSpaces + tagOpen.length;
    endPos = startPos + modifiedSelection.length - tagOpen.length - tagClose.length - nrSpaces;
  } else {
    endPos = nrSpaces + startPos + modifiedSelection.length + 1;
  }

  //self.log("finally, startPos="+startPos+" endPos="+endPos);

  self.setSelectionRange(startPos, endPos);
  txtarea.scrollTop = scrollTop;
  
  self.undoManager.saveState("command");
};

/*************************************************************************
 * insert a topic markup tag 
 */
RawEngine.prototype.insertTag = function(markup) {
  var self = this,
      tagOpen = markup[0],
      sampleText = markup[1],
      tagClose = markup[2],
      startPos, endPos, 
      text, scrollTop, theSelection,
      subst, txtarea = self.shell.txtarea;

  //self.log("called insertTag("+tagOpen+", "+sampleText+", "+tagClose+")");
    
  self.getSelectionRange();
  startPos = txtarea.selectionStart;
  endPos = txtarea.selectionEnd;
  text = txtarea.value;
  scrollTop = txtarea.scrollTop;
  theSelection = text.substring(startPos, endPos) || sampleText;

  //self.log("startPos="+startPos+" endPos="+endPos);

  subst = tagOpen + theSelection.replace(/(\s*)$/, tagClose + "$1");

  txtarea.value =  
    text.substring(0, startPos) + subst +
    text.substring(endPos, text.length);

  // set new selection
  startPos += tagOpen.length;
  endPos = startPos + theSelection.replace(/\s*$/, "").length;

  txtarea.scrollTop = scrollTop;
  self.setSelectionRange(startPos, endPos);

  self.undoManager.saveState("command");
};


/*****************************************************************************
 * search & replace a term in the textarea
 */
RawEngine.prototype.searchReplace = function(search, replace, ignoreCase) {
  var self = this,
    txtarea = self.shell.txtarea,
    scrollTop = txtarea.scrollTop,
    caretPos = self.getCaretPosition(),
    text = txtarea.value,
    copy,
    count = 0,
    pos;
   
  if (ignoreCase) {
    copy = text.toLowerCase();
    search = search.toLowerCase();
  } else {
    copy = text;
  }

  pos = copy.indexOf(search);
  while (pos != -1) {
    count++;
    text = text.substr(0, pos) + replace + text.substr(pos + search.length);
    copy = copy.substr(0, pos) + replace + copy.substr(pos + search.length);
    pos = copy.indexOf(search, pos + replace.length);
  }

  //self.log("NATEDIT: result=",text);
  if (count) {
    txtarea.value = text;
    //self.log("caretPos=",caretPos,"scrollTop=",scrollTop);
    self.setCaretPosition(caretPos);
    txtarea.scrollTop = scrollTop;

    if (self.shell.opts.autoMaxExpand) {
      $(window).trigger("resize");
    }
    self.undoManager.saveState("command");
  }
  
  return count;
};

/*************************************************************************
 * get the DOM element that holds the editor engine
 */
RawEngine.prototype.getWrapperElement = function() {
  var self = this;

  return $(self.shell.txtarea);
};

/*************************************************************************
 * register engine to NatEditor shell
 */
$.NatEditor.engines.raw = {
  createEngine: function(shell) {
    return (new RawEngine(shell)).init();
  }
};

})(jQuery);
