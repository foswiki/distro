/*
 * jQuery NatEdit plugin 
 *
 * Copyright (c) 2008-2012 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */
(function($) {

/*****************************************************************************
 * class definition
 */
$.NatEditor = function(txtarea, opts) {
  var self = this,
      $txtarea = $(txtarea),
      style;

  // build element specific options. 
  // note you may want to install the Metadata plugin
  self.opts = $.extend({}, opts, $txtarea.metadata());
  self.txtarea = txtarea;
  self.id = foswiki.getUniqueID();

  if (typeof(FoswikiTiny) !== 'undefined') {
    self.opts.showWysiwyg = true;
  }
    

  // dont do both: disable autoMaxExpand if we autoExpand
  if (self.opts.autoExpand) {
    self.opts.autoMaxExpand = false;
  }

  self.initGui();
 
  /* establish auto max expand */
  if (self.opts.autoMaxExpand) {
    $txtarea.addClass("natEditAutoMaxExpand");
    self.autoMaxExpand();
  }

  /* establish auto expand */
  if (self.opts.autoExpand) {

    self.helper = $('<div class="natEditHelper" style="position: absolute; top: 0; left: 0;"></div>');
    $('body').append(
      $('<div style="position: absolute; top: 0; left: 0; width: 100px; height: 100px; overflow: hidden; visibility: hidden;"></div>').
      append(self.helper));

    $txtarea.css('overflow', 'hidden');

    // get text styles and apply them to the helper
    style = {
      fontFamily: $txtarea.css('fontFamily')||'',
      fontSize: $txtarea.css('fontSize')||'',
      fontWeight: $txtarea.css('fontWeight')||'',
      fontStyle: $txtarea.css('fontStyle')||'',
      fontStretch: $txtarea.css('fontStretch')||'',
      fontVariant: $txtarea.css('fontVariant')||'',
      letterSpacing: $txtarea.css('letterSpacing')||'',
      wordSpacing: $txtarea.css('wordSpacing')||'',
      lineHeight: $txtarea.css('lineHeight')||'',
      textWrap: 'unrestricted'
    };
    self.helper.css(style);

    $txtarea.keydown(function() {
      self.autoExpand();
    }).keypress(function() {
      self.autoExpand();
    });
    self.autoExpand();
  }

  /* listen to keystrokes */
  $txtarea.keydown(function(ev) {
    if (ev.keyCode == 13) {
      self.handleLineFeed(ev);
    } else if (ev.keyCode == 9) {
      self.handleTab(ev);
    }
  });  
};

/*************************************************************************
 * handles a tab event:
 * inserts spaces on tab, removes spaces on shift-tab
 */
$.NatEditor.prototype.handleTab = function(ev) {
  var self = this, text, startPos, endPos, len;

  self.getSelectionRange();
  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;

  if (ev.shiftKey) {

    text = self.txtarea.value;
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
$.NatEditor.prototype.handleLineFeed = function(ev) {
  var self = this, startPos, endPos, text, prevLine, 
      list, prefix, postfix;

  text = self.txtarea.value;

  self.getSelectionRange();
  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;

  while (startPos > 0 && 
    text.charCodeAt(startPos-1) != 13 &&
    text.charCodeAt(startPos-1) != 10) {
    startPos--;
  }

  prevLine = text.substring(startPos, endPos);


  if (ev.shiftKey) {
    if (prevLine.match(/^((?:   )+)(\*|\d+| ) /)) {
      list = RegExp.$1+"  "; 
    }
  } else {

    if (prevLine.match(/^(   )+(\*|\d+) *$/)) {
      list = '';
    } else if (prevLine.match(/^((?:   )+\* )/)) {
      list = RegExp.$1;
    } else if (prevLine.match(/^(?:((?:   )+)(\d+) )/)) {
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

    if (document.selection && !$.browser.opera) { // IE
      list = "\r\n" + list;
    } else {
      list = "\n" + list;
    }
  }

  self.txtarea.value = prefix + list + postfix;
  self.setCaretPosition(prefix.length + list.length);

  ev.preventDefault();
};

/*************************************************************************
 * init the gui
 */
$.NatEditor.prototype.initGui = function() {
  var self = this, $txtarea, $headlineTools, $textTools, $paragraphTools,
    $listTools, $objectTools, $toggleTools, $toolbar, toolbarState, toggleToolbarState,
    $devTools,
    tmp;
  //$.log("called initGui this=",self);

  $txtarea = $(self.txtarea);
  self.container = $txtarea.wrap('<div class="natEdit"></div>').parent();
  self.container.attr("id", self.id);
  self.container.data("instance", self);

  if (!self.opts.showToolbar) {
    //$.log("no toolbar");
    return;
  }

  // toolbar
  $headlineTools = $('<ul class="natEditButtonBox natEditButtonBoxHeadline"></ul>').
    append(
      $(self.opts.h1Button).click(function() {
        self.insertLineTag(self.opts.h1Markup);
        return false;
      }).wrap("<li />").parent()
    ).
    append(
      $(self.opts.h2Button).click(function() {
        self.insertLineTag(self.opts.h2Markup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.h3Button).click(function() {
        self.insertLineTag(self.opts.h3Markup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.h4Button).click(function() {
        self.insertLineTag(self.opts.h4Markup);
        return false;
      }).wrap("<li />").parent());

  $textTools = $('<ul class="natEditButtonBox natEditButtonBoxText"></ul>').
    append(
      $(self.opts.boldButton).click(function() {
        self.insertTag(self.opts.boldMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.italicButton).click(function() {
        self.insertTag(self.opts.italicMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.monoButton).click(function() {
        self.insertTag(self.opts.monoMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.underlineButton).click(function() {
        self.insertTag(self.opts.underlineMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.strikeButton).click(function() {
        self.insertTag(self.opts.strikeMarkup);
        return false;
      }).wrap("<li />").parent());

  $paragraphTools = $('<ul class="natEditButtonBox natEditButtonBoxParagraph"></ul>').
    append(
      $(self.opts.leftButton).click(function() {
        self.insertTag(self.opts.leftMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.centerButton).click(function() {
        self.insertTag(self.opts.centerMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.rightButton).click(function() {
        self.insertTag(self.opts.rightMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.justifyButton).click(function() {
        self.insertTag(self.opts.justifyMarkup);
        return false;
      }).wrap("<li />").parent());

  $listTools = $('<ul class="natEditButtonBox natEditButtonBoxList"></ul>').
    append(
      $(self.opts.numberedButton).click(function() {
        self.insertLineTag(self.opts.numberedListMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.bulletButton).click(function() {
        self.insertLineTag(self.opts.bulletListMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.indentButton).click(function() {
        self.insertLineTag(self.opts.indentMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.outdentButton).click(function() {
        self.insertLineTag(self.opts.outdentMarkup);
        return false;
      }).wrap("<li />").parent());

  $objectTools = $('<ul class="natEditButtonBox natEditButtonBoxObject"></ul>').
    append(
      $(self.opts.tableButton).
        addClass("jqUIDialogLink").
        attr("href", self.opts.tableDialog+';editor='+self.id).
        wrap("<li />").parent()
    ).
    append(
      $(self.opts.linkButton).
        addClass("jqUIDialogLink").
        attr("href", self.opts.linkDialog+";editor="+self.id).
        wrap("<li />").parent()
    );

  if (foswiki.getPreference("MathModePluginEnabled")) {
    $objectTools.
      append(
        $(self.opts.mathButton).click(function() {
          self.insertTag(self.opts.mathMarkup);
          return false;
        }).wrap("<li />").parent());
  }

  $objectTools.
    append(
      $(self.opts.verbatimButton).click(function() {
        self.insertTag(self.opts.verbatimMarkup);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.signatureButton).click(function() {
        self.insertTag(self.opts.signatureMarkup);
        return false;
      }).wrap("<li />").parent());

  $devTools = $('<ul class="natEditButtonBox natEditButtonBoxDev"></ul>').
    append(
      $(self.opts.escapeTmlButton).click(function() {
        self.transformSelection(self.opts.escapeTmlTransform);
        return false;
      }).wrap("<li />").parent()).
    append(
      $(self.opts.unescapeTmlButton).click(function() {
        self.transformSelection(self.opts.unescapeTmlTransform);
        return false;
      }).wrap("<li />").parent());


  $toggleTools = $('<ul class="natEditButtonBox natEditButtonBoxToggles"></ul>');
  if (self.opts.showWysiwyg) {
    $toggleTools.append(
      $(self.opts.wysiwygButton).
        wrap("<li />").parent()
    );
  }

  $toolbar = $('<div class="natEditToolBar"></div>');
  if (self.opts.showHeadlineTools) {
    $toolbar.append($headlineTools);
  }
  if (self.opts.showTextTools) {
    $toolbar.append($textTools);
  }
  if (self.opts.showListTools) {
    $toolbar.append($listTools);
  }
  if (self.opts.showParagraphTools) {
    $toolbar.append($paragraphTools);
  }
  if (self.opts.showObjectTools) {
    $toolbar.append($objectTools);
  }
  if (self.opts.showDevTools) {
    $toolbar.append($devTools);
  }
  if (self.opts.showToggleTools) {
    $toolbar.append($toggleTools);
  }
  $toolbar.append('<span class="foswikiClear"></span>');

  if (self.opts.autoHideToolbar) {
    //$.log("toggling toolbar on hover event");
    $toolbar.hide();

    toolbarState = 0;
    toggleToolbarState = function() {
      if (toolbarState < 0) {
        return;
      }
      tmp = self.txtarea.value;
      if (toolbarState) {
        //$.log("slide down");
        $toolbar.slideDown("fast");
        //$toolbar.show();
        self.txtarea.value = tmp;
      } else {
        //$.log("slide up");
        $toolbar.slideUp("fast");
        //$toolbar.hide();
        self.txtarea.value = tmp;
      }
      if (self.opts.autoMaxExpand) {
        $(window).trigger("resize.natedit");
      }
      toolbarState = -1;
    };
    
    $txtarea.focus(
      function() {
        toolbarState = 1;
        window.setTimeout(toggleToolbarState, 100);
      }
    );
    $txtarea.blur(
      function() {
        toolbarState = 0;
        window.setTimeout(toggleToolbarState, 100);
      }
    );
  }

  self.container.prepend($toolbar);
};

/*************************************************************************
 * insert stuff at the given cursor position
 */
$.NatEditor.prototype.insert = function(newText) {
  var self = this, startPos, endPos, text, prefix, postfix;

  self.getSelectionRange();
  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;
  text = self.txtarea.value;
  prefix = text.substring(0, startPos);
  postfix = text.substring(endPos);
  self.txtarea.value = prefix + newText + postfix;
  
  self.setCaretPosition(startPos);
};

/*************************************************************************
 * remove the selected substring
 */
$.NatEditor.prototype.remove = function() {
  var self = this, startPos, endPos, text, selection;

  self.getSelectionRange();
  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;
  text = self.txtarea.value;
  selection = text.substring(startPos, endPos);
  self.txtarea.value = text.substring(0, startPos) + text.substring(endPos);
  self.setSelectionRange(startPos, startPos);
  return selection;
};

/*************************************************************************
 * insert a topic markup tag 
 */
$.NatEditor.prototype.insertTag = function(markup) {
  var self = this,
      tagOpen = markup[0],
      sampleText = markup[1],
      tagClose = markup[2],
      startPos, endPos, 
      text, scrollTop, theSelection,
      subst;

  //$.log("called insertTag("+tagOpen+", "+sampleText+", "+tagClose+")");
    
  self.getSelectionRange();
  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;
  text = self.txtarea.value;
  scrollTop = self.txtarea.scrollTop;
  theSelection = text.substring(startPos, endPos);

  //$.log("startPos="+startPos+" endPos="+endPos);

  if (!theSelection) {
    theSelection = sampleText;
  }

  if (theSelection.charAt(theSelection.length - 1) === " ") { 
    // exclude ending space char, if any
    subst = 
      tagOpen + 
      theSelection.substring(0, (theSelection.length - 1)) + 
      tagClose + " ";
  } else {
    subst = tagOpen + theSelection + tagClose;
  }

  self.txtarea.value =  
    text.substring(0, startPos) + subst +
    text.substring(endPos, text.length);

  // set new selection
  startPos += tagOpen.length;
  endPos = startPos + theSelection.length;
  self.txtarea.scrollTop = scrollTop;
  self.setSelectionRange(startPos, endPos);
  $(self.txtarea).trigger("keypress");
};

/*************************************************************************
 * Transform selected text with a provided function
 */
$.NatEditor.prototype.transformSelection = function(transformer) {
  var self = this,
      startPos, endPos, 
      text, scrollTop, theSelection,
      subst;

  //$.log("called insertTag("+tagOpen+", "+sampleText+", "+tagClose+")");
    
  self.getSelectionRange();
  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;
  text = self.txtarea.value;
  scrollTop = self.txtarea.scrollTop;
  theSelection = text.substring(startPos, endPos);

  //$.log("startPos="+startPos+" endPos="+endPos);

  subst = transformer.call(self, theSelection);

  self.txtarea.value =  
    text.substring(0, startPos) + subst +
    text.substring(endPos, text.length);

  // set new selection
  endPos = startPos + subst.length;
  self.txtarea.scrollTop = scrollTop;
  self.setSelectionRange(startPos, endPos);
  $(self.txtarea).trigger("keypress");
};



/*************************************************************************
 * compatibility method for IE: this sets txtarea.selectionStart and
 * txtarea.selectionEnd of the current selection in the given textarea 
 */
$.NatEditor.prototype.getSelectionRange = function() {
  var self = this, text, c, range, rangeCopy, pos, selection;

  //$.log("called getSelectionRange()");

  if (document.selection && !$.browser.opera) { // IE
    $(self.txtarea).focus();
   
    text = self.txtarea.value;
    c = "\01";
    range = document.selection.createRange();
    selection = range.text || "";
    rangeCopy = range.duplicate();
    rangeCopy.moveToElementText(self.txtarea);
    range.text = c;
    pos = (rangeCopy.text.indexOf(c));
   
    range.moveStart("character", -1);
    range.text = selection;

    if (pos < 0) {
      pos = text.length;
      selection = "";
    }
   
    self.txtarea.selectionStart = pos;
   
    if (selection == "") {
      self.txtarea.selectionEnd = pos;
    } else {
      self.txtarea.selectionEnd = pos + selection.length;
    }
  }
 
  return [self.txtarea.selectionStart, self.txtarea.selectionEnd];
};

/*************************************************************************
 * returns the current selection
 */
$.NatEditor.prototype.getSelection = function() {
  var self = this, startPos, endPos;

  self.getSelectionRange();
  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;

  return self.txtarea.value.substring(startPos, endPos);
};

/*************************************************************************
 * set the selection
 */
$.NatEditor.prototype.setSelectionRange = function(start, end) {
  var self = this, lineFeeds, range;

  //$.log("setSelectionRange("+self.txtarea+", "+start+", "+end+")");
  $(self.txtarea).focus();
  if (self.txtarea.createTextRange && !$.browser.opera) {
    lineFeeds = self.txtarea.value.substring(0, start).replace(/[^\r]/g, "").length;
    range = self.txtarea.createTextRange();
    range.collapse(true);
    range.moveStart('character', start-lineFeeds);
    range.moveEnd('character', end-start);
    range.select();
  } else { 
    self.txtarea.selectionStart = start;
    self.txtarea.selectionEnd = end;
  }
};

/*************************************************************************
 * set the caret position to a specific position. thats done by setting
 * the selection range to a single char at the given position
 */
$.NatEditor.prototype.setCaretPosition = function(caretPos) {
  //$.log("setCaretPosition("+this.txtarea+", "+caretPos+")");
  this.setSelectionRange(caretPos, caretPos);
};
 
/*************************************************************************
 * used for line oriented tags - like bulleted lists
 * if you have a multiline selection, the tagOpen/tagClose is added to each line
 * if there is no selection, select the entire current line
 * if there is a selection, select the entire line for each line selected
 */
$.NatEditor.prototype.insertLineTag = function(markup) {
  var self = this, tagOpen, sampleText, tagClose, startPos, endPos, text,
    scrollTop, theSelection, pre, post, lines, isMultiline, modifiedSelection,
    i, line, subst;

  //$.log("called inisertLineTag("+self.txtarea+", "+markup+")");
  tagOpen = markup[0];
  sampleText = markup[1];
  tagClose = markup[2];

  self.getSelectionRange();

  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;
  text = self.txtarea.value;

  //$.log("startPos="+startPos+" endPos="+endPos);

  // at this point we need to expand the selection to the \n before the startPos, and after the endPos
  while (startPos > 0 && 
    text.charCodeAt(startPos-1) != 13 &&
    text.charCodeAt(startPos-1) != 10) {
    startPos--;
  }

  while (endPos < text.length && 
    text.charCodeAt(endPos) != 13 && 
    text.charCodeAt(endPos) != 10) {
    endPos++;
  }

  //$.log("startPos="+startPos+" endPos="+endPos);

  scrollTop = self.txtarea.scrollTop;
  theSelection = text.substring(startPos, endPos);

  if (!theSelection) {
    theSelection = sampleText;
  }

  pre = text.substring(0, startPos);
  post = text.substring(endPos, text.length);

  // test if it is a multi-line selection, and if so, add tagOpen&tagClose to each line
  lines = theSelection.split(/\r?\n/);
  isMultiline = lines.length>1?true:false;
  modifiedSelection = '';
  for (i = 0; i < lines.length; i++) {
    line = lines[i];
    
    if (line.match(/^\s*$/)) {
      // don't append tagOpen to empty lines
      subst = line;
    } else {
      // special case - undent (remove 3 spaces, and bullet or numbered list if outdenting away)
      if ((tagOpen == '') && (sampleText == '') && (tagClose == '')) {
        subst = line.replace(/^ {3}(\* |\d+ |\d+\. )?/, '');
      } else {
        subst = tagOpen + line + tagClose;
      }
    }

    modifiedSelection += subst;
    if (i+1 < lines.length) {
      modifiedSelection += '\n';
    }
  }

  self.txtarea.value = pre + modifiedSelection + post;

  startPos += (isMultiline?0:tagOpen.length);
  endPos = startPos + modifiedSelection.length - (isMultiline?0:tagOpen.length-tagClose.length);

  self.setSelectionRange(startPos, endPos);
  self.txtarea.scrollTop = scrollTop;
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
$.NatEditor.prototype.insertTable = function(opts) {
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

/***************************************************************************
 * insert a square brackets link
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
$.NatEditor.prototype.insertLink = function(opts) {
  var self = this, markup;

  if (typeof(opts.url) !== 'undefined') {
    // external link
    if (typeof(opts.url) === 'undefined' || opts.url == '') {
      return; // nop
    }

    if (typeof(opts.text) !== 'undefined' && opts.text != '') {
      markup = "[["+opts.url+"]["+opts.text+"]]";
    } else {
      markup = "[["+opts.url+"]]";
    }
  } else if (typeof(opts.file) !== 'undefined') {
    // attachment link

    if (typeof(opts.web) === 'undefined' || opts.web == '' || 
        typeof(opts.topic) === 'undefined' || opts.topic == '') {
      return; // nop
    }

    if (opts.file.match(/\.(bmp|png|jpe?g|gif|svg)$/i) && foswiki.getPreference("ImagePluginEnabled")) {
      markup = '%IMAGE{"'+opts.file+'"';
      if (opts.web != self.opts.web || opts.topic != self.opts.topic) {
        markup += ' topic="';
        if (opts.web != self.opts.web) {
          markup += opts.web+'.';
        }
        markup += opts.topic+'"';
      }
      if (typeof(opts.text) !== 'undefined' && opts.text != '') {
        markup += ' caption="'+opts.text+'"';
      }
      markup += ' size="200"}%';
    } else {
      // linking to an ordinary attachment

      if (opts.web == self.opts.web && opts.topic == self.opts.topic) {
        markup = "[[%ATTACHURLPATH%/"+opts.file+"]";
      } else {
        markup = "[[%PUBURLPATH%/"+opts.web+"/"+opts.topic+"/"+opts.file+"]";
      }

      if (typeof(opts.text) !== 'undefined' && opts.text != '') {
        markup += "["+opts.text+"]";
      } 
      markup += "]";

    }

  } else {
    // wiki link
    
    if (typeof(opts.topic) === 'undefined' || opts.topic == '') {
      return; // nop
    }

    if (opts.web == self.opts.web) {
      markup = "[["+opts.topic+"]";
    } else {
      markup = "[["+opts.web+"."+opts.topic+"]";
    }

    if (typeof(opts.text) !== 'undefined' && opts.text != '') {
      markup += "["+opts.text+"]";
    } 
    markup += "]";
  }
  self.remove();
  self.insertTag(['', markup, '']);
};

/*************************************************************************
 * Replaces all foswiki TML special characters with their escaped counterparts.
 * See Foswiki:System.FormatTokens
 * @param inValue: (String) the text to escape
 * @return escaped text.
 */
$.NatEditor.prototype.escapeTML = function(inValue) {
  var text = inValue;

  text = text.replace(/\$/g, '$dollar');
  text = text.replace(/%/g, '$percnt');
  text = text.replace(/"/g, '\\"');
  text = text.replace(/&/g, '$amp');
  text = text.replace(/>/g, '$gt');
  text = text.replace(/</g, '$lt');
  text = text.replace(/,/g, '$comma');

  return text;
};

/*************************************************************************
 * The inverse of the escapeTML function.
 * See Foswiki:System.FormatTokens
 * @param inValue: (String) the text to unescape.
 * @return unescaped text.
 */
$.NatEditor.prototype.unescapeTML = function(inValue) {
  var text = inValue;

  text = text.replace(/\$nop/g, '');
  text = text.replace(/\\"/g, '"');
  text = text.replace(/\$perce?nt/g, '%');
  text = text.replace(/\$quot/g, '"');
  text = text.replace(/\$comma/g, ',');
  text = text.replace(/\$lt/g, '<');
  text = text.replace(/\$gt/g, '>');
  text = text.replace(/\$amp/g, '&');
  text = text.replace(/\$dollar/g, '$');

  return text;
};

/*************************************************************************
 * event handler for window.resize event 
 */
$.NatEditor.prototype.autoMaxExpand = function() {
  var self = this;

  window.setTimeout(function() {
    self.fixHeight();
    $(window).one("resize.natedit", function() {
      self.autoMaxExpand();
    });
  }, 100); 
};

/*************************************************************************
 * adjust height of textarea to window height
 */
$.NatEditor.prototype.fixHeight = function() {
  var self = this,
    $txtarea = $(self.txtarea),
    windowHeight = $(window).height() || window.innerHeight,
    bottomHeight = $('.natEditBottomBar').outerHeight(true),
    offset = $txtarea.offset(),
    tmceEdContainer, tmceIframe,
    minHeight, 
    newHeight = windowHeight-offset.top-bottomHeight*2-1,
    newHeightExtra = 0, 
    natEditTopicInfoHeight,
    $debug = $("#DEBUG");

  if ($debug.length) {
    newHeight -= $debug.height();
  }

  //$.log("natedit: windowHeight="+windowHeight+" bottomHeight="+bottomHeight+" top offset="+offset.top+" newHeight="+newHeight+" minHeight="+self.opts.minHeight);

  if (self.opts.minHeight && newHeight < self.opts.minHeight) {
    //$.log("natedit: minHeight reached");
    newHeight = self.opts.minHeight;
  }

  if (newHeight < 0) {
    return;
  }
		
  if ($txtarea.is(":visible")) {
    $txtarea.height(newHeight);
  }
	
  /* Resize tinyMCE. Both the iframe and containing table need to be adjusted. */
  if (typeof(tinyMCE) === 'object' && tinyMCE.activeEditor !== null &&
    !tinyMCE.activeEditor.getParam('fullscreen_is_enabled')) {
    
    /* TMCE container = <td>, in a <tr>, <tbody>, <table>, <span> next to original 
     * <textarea display: none> in a <div .natEdit> in a <div .jqTabContents> :-) 
     * SMELL: No "proper" way to get correct instance until Item2297 finished 
     */

    tmceEdContainer = tinyMCE.activeEditor.contentAreaContainer;
    if ($(tmceEdContainer).is(":visible")) {

      tmceIframe = $(tmceEdContainer).children('iframe')[0];
      tmceTable = tmceEdContainer.parentNode.parentNode.parentNode;

      /* The NatEdit Title: text sits in the jqTab above TMCE */
      natEditTopicInfoHeight = $(tmceTable.parentNode.parentNode).siblings(
        '.natEditTopicInfo:first').outerHeight(true); // SMELL: this looks strange
      offset = $(tmceTable).offset().top;

      $(tmceEdContainer.parentNode).siblings().each(	/* Iterate over TMCE layout */
        function (i, tr) {
          newHeightExtra = newHeightExtra + $(tr).outerHeight(true);
        }
      );

      /* SMELL: minHeight isn't working on IE7 but does on IE6 + IE8 */
      newHeight = windowHeight - offset - bottomHeight*2;
      if (self.opts.minHeight && newHeight - newHeightExtra + 
        natEditTopicInfoHeight < self.opts.minHeight) {
        newHeight = self.opts.minHeight + natEditTopicInfoHeight;
      }
      $(tmceTable).height(newHeight);
      $(tmceIframe).height(newHeight - newHeightExtra);
    }
  }
};

/*************************************************************************
 * adjust height of textarea according to content
 */
$.NatEditor.prototype.autoExpand = function() {
  var self = this, 
      $txtarea = $(self.txtarea),
      now, text, height;

  //$.log("called autoExpand()");
  now = new Date();
  
  // don't do it too often
  if (self._time && now.getTime() - self._time.getTime() < 100) {
    //$.log("suppressing events within 100ms");
    return;
  }
  self._time = now;

  window.setTimeout(function() {
    text = self.txtarea.value+'x';
    if (text == self._lastText) {
      $.log("suppressing events");
      return;
    }
    self._lastText = text;
    text = self.htmlEntities(text);

    //$.log("helper text="+text);
    self.helper.html(text);
    height = self.helper.height() + 12;
    height = Math.max($txtarea.height(), height);
    //$.log("helper height="+height);
    $txtarea.height(height);
  },100);
};

/*************************************************************************
 * replace entities with real html
 */
$.NatEditor.prototype.htmlEntities = function(text) { 
  var entities = {
    '&':'&amp;',
    '<':'&lt;',
    '>':'&gt;',
    '"':'&quot;',
    "\\n": "<br />"
  };
  for(var i in entities) {
    text = text.replace(new RegExp(i,'g'),entities[i]);
  }
  return text;
};

/***************************************************************************
 * plugin defaults
 */
$.NatEditor.prototype.defaults = {
  h1Button: '<a class="natEditH1Button" href="#" title="Level 1 headline" accesskey="1"><span>H1</span></a>',
  h2Button: '<a class="natEditH2Button" href="#" title="Level 2 headline" accesskey="2"><span>H2</span></a>',
  h3Button: '<a class="natEditH3Button" href="#" title="Level 3 headline" accesskey="3"><span>H3</span></a>',
  h4Button: '<a class="natEditH4Button" href="#" title="Level 4 headline" accesskey="4"><span>H4</span></a>',
  boldButton: '<a class="natEditBoldButton" href="#" title="Bold" accesskey="*"><span>Bold</span></a>',
  italicButton: '<a class="natEditItalicButton" href="#" title="Italic" accesskey="_"><span>Italic</span></a>',
  monoButton: '<a class="natEditMonoButton" href="#" title="Monospace" accesskey="="><span>Monospace</span></a>',
  underlineButton: '<a class="natEditUnderlineButton" href="#" title="Underline" accesskey="u"><span>Underline</span></a>',
  strikeButton: '<a class="natEditStrikeButton" href="#" title="Strike" accesskey="-"><span>Strike</span></a>',
  leftButton: '<a class="natEditLeftButton" href="#" title="Align left" accesskey="<"><span>Left</span></a>',
  centerButton: '<a class="natEditCenterButton" href="#" title="Center align" accesskey="."><span>Center</span></a>',
  rightButton: '<a class="natEditRightButton" href="#" title="Align right" accesskey=">"><span>Right</span></a>',
  justifyButton: '<a class="natEditJustifyButton" href="#" title="Justify text" accesskey="j"><span>Justify</span></a>',
  numberedButton: '<a class="natEditNumberedButton" href="#" title="Numbered list" accesskey="l"><span>Numbered List</span></a>',
  bulletButton: '<a class="natEditBulletButton" href="#" title="Bullet list" accesskey="*"><span>Bullet List</span></a>',
  indentButton: '<a class="natEditIndentButton" href="#" title="Indent" accesskey="-"><span>Indent</span></a>',
  outdentButton: '<a class="natEditOutdentButton" href="#" title="Outdent" accesskey="o"><span>Outdent</span></a>',
  tableButton: '<a class="natEditTableButton" href="#" title="Insert table" accesskey="t"><span>Table</span></a>',
  linkButton: '<a  class="natEditLinkButton"href="#" title="Insert link" accesskey="#"><span>Link</span></a>',
  mathButton: '<a class="natEditMathButton" href="#" title="Mathematical formula (LaTeX)" accesskey="m"><span>Math</span></a>',
  verbatimButton: '<a class="natEditVerbatimButton" href="#" title="Ignore wiki formatting" accesskey="v"><span>Verbatim</span></a>',
  signatureButton: '<a class="natEditSignatureButton" href="#" title="Your signature with timestamp" accesskey="z"><span>Sign</span></a>',
  wysiwygButton: '<a class="natEditWysiwygButton" href="#" id="topic_2WYSIWYG" title="Switch to WYSIWYG" accesskey="w"><span>Wysiwyg</span></a>',
  escapeTmlButton: '<a class="natEditEscapeTmlButton" href="#" title="Escape TML" accesskey="$"><span>Escape TML</span></a>',
  unescapeTmlButton: '<a class="natEditUnescapeTmlButton" href="#" title="Unescape TML" accesskey="%"><span>Unescape TML</span></a>',

  // Elements 0 and 2 are (respectively) prepended and appended.  Element 1 is the default text to use,
  // if no text is currently selected.

  h1Markup: ['---+!! ','%TOPIC%',''],
  h2Markup: ['---++ ','Headline text',''],
  h3Markup: ['---+++ ','Headline text',''],
  h4Markup: ['---++++ ','Headline text',''],
  boldMarkup: ['*', 'Bold text', '*'],
  italicMarkup: ['_', 'Italic text', '_'],
  monoMarkup: ['=', 'Monospace text', '='],
  underlineMarkup: ['<u>', 'Underlined text', '</u>'],
  strikeMarkup: ['<del>', 'Strike through text', '</del>'],
  leftMarkup: ['<p style="text-align:left">\n','Align left','\n</p>\n'],
  centerMarkup: ['<p style="text-align:center">\n','Center text','\n</p>\n'],
  rightMarkup: ['<p style="text-align:right">\n','Align right','\n</p>\n'],
  justifyMarkup: ['<p style="text-align:justify">\n','Justify text','\n</p>\n'],
  numberedListMarkup: ['   1 ','enumerated item',''],
  bulletListMarkup: ['   * ','bullet item',''],
  indentMarkup: ['   ','',''],
  outdentMarkup: ['','',''],
  mathMarkup: ['<latex title="Example">\n','\\sum_{x=1}^{n}\\frac{1}{x}','\n</latex>'],
  verbatimMarkup: ['<verbatim>\n','Insert non-formatted text here','\n</verbatim>\n'],
  signatureMarkup: ['-- ', '%WIKINAME%, ' - '%DATE%'],

  escapeTmlTransform: function (string) {
    return this.escapeTML(string);
  },
  unescapeTmlTransform: function(string) {
    return this.unescapeTML(string);
  },

  autoHideToolbar: false,
  autoMaxExpand:false,
  autoExpand:false,
  minHeight:230,

  showToolbar: true,
  showHeadlineTools: true,
  showTextTools: true,
  showListTools: true,
  showParagraphTools: true,
  showObjectTools: true,
  showDevTools: true,
  showToggleTools: true,
  showWysiwyg: false
};

/*****************************************************************************
 * global function to init and open a dialog
 */
$.NatEditor.openDialog = function() {
  var $dialog = $(this),
      editorId = $dialog.find("input[name='editor']").val(),
      editor = $("#"+editorId).data("instance");

  if ($dialog.is(".natEditInsertLink")) {
    if (!$dialog.data("initedEvents")) {
      $dialog.data("initedEvents", true);
      editor.initInsertLinkDialog($dialog);
    }
    return editor.openInsertLinkDialog($dialog);
  }

  if ($dialog.is(".natEditInsertTable")) {
    if (!$dialog.data("initedEvents")) {
      $dialog.data("initedEvents", true);
      editor.initInsertTableDialog($dialog);
    }
    return editor.openInsertTableDialog($dialog);
  }

};

/*****************************************************************************
 * init the insert table dialog
 */
$.NatEditor.prototype.initInsertTableDialog = function($dialog) {
  var self = this;

  //console.log("called initInsertTable()", $dialog);
  $dialog.find("form").bind("submit", function() {
    var rows = $dialog.find("input[name='rows']").val(),
        cols = $dialog.find("input[name='cols']").val(),
        heads = $dialog.find("input[name='heads']").val();
        editable = $dialog.find("input[name='editable']:checked").val() === 'true'?true:false;

    $dialog.dialog("close");

    self.insertTable({
      heads: heads, 
      rows: rows, 
      cols: cols,
      editable: editable
    });
    return false;
  });
};

/*****************************************************************************
  * called when the insert table dialog is opened
  */
$.NatEditor.prototype.openInsertTableDialog = function($dialog) {
  //console.log("called openInsertTable()", $dialog);
}

/*****************************************************************************
  * init the insert link dialog 
  */
$.NatEditor.prototype.initInsertLinkDialog = function($dialog) {
  var self = this,
      xhr, requestIndex = 0,
      $thumbnail = $dialog.find(".natEditAttachmentThumbnail"),
      systemWeb = foswiki.getPreference("SYSTEMWEB");

  //console.log("called initInsertLinkDialog");

  $dialog.find("input[name='web']").autocomplete({
    source: self.opts.scriptUrl+"/view/"+systemWeb+"/JQueryAjaxHelper?section=web&skin=text"
  });

  $dialog.find("input[name='topic']").autocomplete({
    source: function(request, response) {
      if (xhr) {
        xhr.abort();
      }
      xhr = $.ajax({
        url: self.opts.scriptUrl+"/view/"+systemWeb+"/JQueryAjaxHelper",
        data: $.extend(request, {
          section: 'topic',
          skin: 'text',
          baseweb: $dialog.find(".jqTab.current input[name='web']").val()
        }),
        dataType: "json",
        autocompleteRequest: ++requestIndex,
        success: function(data, status) {
          if (this.autocompleteRequest === requestIndex) {
            response(data);
          }
        },
        error: function(xhr, status) {
          if (this.autocompleteRequest === requestIndex) {
            response([]);
          }
        }
      });
    }
  });

  $dialog.find(".natEditAttachmentSelector").autocomplete({
    source: function(request, response) {
      var $currentTab = $dialog.find(".jqTab.current");
      if (xhr) {
        xhr.abort();
      }
      xhr = $.ajax({
        url: self.opts.scriptUrl+"/view",
        data: $.extend(request, {
          template: 'editdialog',
          dialog: 'insertlink::attachment::list',
          topic: $currentTab.find("input[name='web']").val()+'.'+$currentTab.find("input[name='topic']").val()
        }),
        dataType: "json",
        autocompleteRequest: ++requestIndex,
        success: function(data, status) {
          if (this.autocompleteRequest === requestIndex) {
            response(data);
          }
        },
        error: function(xhr, status) {
          if (this.autocompleteRequest === requestIndex) {
            response([]);
          }
        }
      });
    },
    select: function(ev, ui) {
      $thumbnail.attr("src", ui.item.img).show();
    },
    change: function(ev, ui) {
      if (ui.item) {
        $thumbnail.attr("src", ui.item.img).show();
      } else {
        $thumbnail.hide();
      }
    }
  }).data("autocomplete")._renderItem = function(ul, item) {
    if (typeof(item.label) !== "undefined") {
      return $("<li></li>")
        .data("item.autocomplete", item)
        .append("<a><table width='100%'><tr><td width='60px'><img width='50' src='"+item.img+"' /></td><td>"+item.label+"<br />"+item.comment+"</td></tr></table></a>")
        .appendTo(ul);
    }
  };

  $dialog.find("form").bind("submit", function() {
    var opts,
        $currentTab = $dialog.find(".jqTab.current");

    if ($currentTab.is(".topic")) {
      opts = {
        web: $currentTab.find("input[name='web']").val(),
        topic: $currentTab.find("input[name='topic']").val(),
        text: $dialog.find("input[name='linktext']").val()
      };
    } 

    if ($currentTab.is(".external")) {
      opts = {
        url: $currentTab.find("input[name='url']").val(),
        text: $dialog.find("input[name='linktext']").val()
      };
    }

    if ($currentTab.is(".attachment")) {
      opts = {
        web: $currentTab.find("input[name='web']").val(),
        topic: $currentTab.find("input[name='topic']").val(),
        file: $currentTab.find("input[name='file']").val(),
        text: $dialog.find("input[name='linktext']").val()
      };
    }

    $dialog.dialog("close");
    self.insertLink(opts);
    return false;
  });
}

/*****************************************************************************
  * called when the insert link dialog is opened
  */
$.NatEditor.prototype.openInsertLinkDialog = function($dialog) {
  //console.log("called openInsertLink()", $dialog);

  var self = this,
      selection = self.getSelection(),
      web = self.opts.web,
      topic = self.opts.topic,
      file = '',
      url = '',
      initialTab = 'topic',
      urlRegExp = "(?:file|ftp|gopher|https?|irc|mailto|news|nntp|telnet|webdav|sip|edit)://[^\\s]+?";

  //console.log("before selection=",selection);

  // initialize from selection
  if (selection.match(/\s*\[\[(.*?)\]\]\s*/)) {
    selection = RegExp.$1;
    //console.log("brackets link, selection=",selection);
    if (selection.match("^("+urlRegExp+")(?:\\]\\[(.*))?$")) {
      //console.log("external link");
      url = RegExp.$1;
      selection = RegExp.$2 || '';
      initialTab = 'external';
    } else if (selection.match(/^(?:%ATTACHURL(?:PATH)?%\/)(.*?)(?:\]\[(.*))?$/)) {
      //console.log("this attachment link");     
      file = RegExp.$1;
      selection = RegExp.$2;
      initialTab = "attachment";
    } else if (selection.match(/^(?:%PUBURL(?:PATH)?%\/)(.*)\/(.*?)\/(.*?)(?:\]\[(.*))?$/)) {
      //console.log("other topic attachment link");     
      web = RegExp.$1;
      topic = RegExp.$2;
      file = RegExp.$3;
      selection = RegExp.$4;
      initialTab = "attachment";
    } else if (selection.match(/^(?:(.*)\.)?(.*?)(?:\]\[(.*))?$/)) {
      //console.log("topic link");
      web = RegExp.$1 || web;
      topic = RegExp.$2;
      selection = RegExp.$3 || '';
    } else {
      //console.log("some link");
      topic = selection;
      selection = '';
    }
  } else if (selection.match("^\s*"+urlRegExp)) {
    //console.log("no brackets external link");
    url = selection;
    selection = "";
    initialTab = "external";
  } else if (selection.match(/^\s*%IMAGE{"(.*?)"(?:.*?topic="(?:([^\s\.]+)\.)?(.*?)")?.*?}%\s*$/)) {
    // SMELL: nukes custom params
    //console.log("image link");
    web = RegExp.$2 || web;
    topic = RegExp.$3 || topic;
    file = RegExp.$1;
    selection = "";
    initialTab = "attachment";
  } else {
    if (selection.match(/^\s*([A-Z][^\s\.]*)\.(A-Z.*?)\s*$/)) {
      //console.log("topic link");
      web = RegExp.$1 || web;
      topic = RegExp.$2;
      selection = '';
      initialTab = "topic";
    } else {
      //console.log("some selection, not a link");
    }
  }
  //console.log("after: selection=",selection, ", url=",url, ", web=",web,", topic=",topic,", file=",file,", initialTab=", initialTab);

  if (typeof(initialTab) !== 'undefined') {
    window.location.hash = "!" + $dialog.find(".jqTab."+initialTab).attr("id");
  }
      
  $dialog.find(".empty").val('');
  $dialog.find(".selection").val(selection);
  $dialog.find("input[name='web']").each(function() {
    $(this).val(web);
  });
  $dialog.find("input[name='topic']").each(function() {
    $(this).val(topic);
  });
  $dialog.find("input[name='url']").each(function() {
    $(this).val(url);
  });
  $dialog.find("input[name='file']").each(function() {
    $(this).val(file);
  });

};

/*****************************************************************************
 * register to jquery 
 */
$.fn.natedit = function(opts) {
  //$.log("called natedit()");

  // build main options before element iteration
  var thisOpts = $.extend({}, $.NatEditor.prototype.defaults, opts);

  return this.each(function() {
    new $.NatEditor(this, thisOpts);
  });
};


/*****************************************************************************
 * initializer called on dom ready
 */
$(function() {

  // listen for natedit
  $(".natedit:not(.natedit_inited)").livequery(function() {
    var web = foswiki.getPreference("WEB"),
        topic = foswiki.getPreference("TOPIC"),
        scriptUrl = foswiki.getPreference("SCRIPTURL");

    $(this).addClass("natedit_inited").natedit({
      web: web,
      topic: topic,
      scriptUrl: scriptUrl,
      tableDialog: scriptUrl+'/view/'+web+'/'+topic+"?template=editdialog;dialog=inserttable",
      linkDialog: scriptUrl+'/view/'+web+'/'+topic+"?template=editdialog;dialog=insertlink",
      autoMaxExpand:false,
      signatureMarkup: ['-- ', foswiki.getPreference("WIKIUSERNAME"), ' - '+foswiki.getPreference("SERVERTIME")]
    });
  });


});

})(jQuery);
