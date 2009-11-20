/*
 * jQuery NatEdit plugin 2.0
 *
 * Copyright (c) 2008-2009 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */

;(function($) {

/*****************************************************************************
 * class definition
 */
$.NatEditor = function(txtarea, opts) {
  var self = this;

  var $txtarea = $(txtarea);

  // build element specific options. 
  // note you may want to install the Metadata plugin
  self.opts = $.extend({}, opts, $txtarea.metadata());
  self.txtarea = txtarea;

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
    var style = {
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
      self.autoExpand()
    }).keypress(function() {;
      self.autoExpand()
    });
    self.autoExpand();
  }

  window.setTimeout(function() {
    try {
      self.setCaretPosition(0);
    } catch (e ){
      // ignore
    }
  }, 100);
};

/*************************************************************************
 * init the gui
 */
$.NatEditor.prototype.initGui = function() {
  var self = this;
  //$.log("called initGui this="+self);

  var $txtarea = $(self.txtarea);
  self.container = $txtarea.wrap('<div class="natEdit"></div>').parent();

  if (self.opts.hideToolbar) {
    //$.log("no toolbar");
    return;
  }

  var width = $txtarea.width();

  // toolbar
  var $headlineTools = $('<ul class="natEditButtonBox"></ul>').
    append(
      $(self.opts.h1Button).click(function() {
        self.insertLineTag(self.opts.h1Markup);
        return false;
      })).
    append(
      $(self.opts.h2Button).click(function() {
        self.insertLineTag(self.opts.h2Markup);
        return false;
      })).
    append(
      $(self.opts.h3Button).click(function() {
        self.insertLineTag(self.opts.h3Markup);
        return false;
      })).
    append(
      $(self.opts.h4Button).click(function() {
        self.insertLineTag(self.opts.h4Markup);
        return false;
      }));

  var $textTools = $('<ul class="natEditButtonBox"></ul>').
    append(
      $(self.opts.boldButton).click(function() {
        self.insertTag(self.opts.boldMarkup);
        return false;
      })).
    append(
      $(self.opts.italicButton).click(function() {
        self.insertTag(self.opts.italicMarkup);
        return false;
      })).
    append(
      $(self.opts.monoButton).click(function() {
        self.insertTag(self.opts.monoMarkup);
        return false;
      })).
    append(
      $(self.opts.underlineButton).click(function() {
        self.insertTag(self.opts.underlineMarkup);
        return false;
      })).
    append(
      $(self.opts.strikeButton).click(function() {
        self.insertTag(self.opts.strikeMarkup);
        return false;
      }));

  var $paragraphTools = $('<ul class="natEditButtonBox"></ul>').
    append(
      $(self.opts.leftButton).click(function() {
        self.insertTag(self.opts.leftMarkup);
        return false;
      })).
    append(
      $(self.opts.centerButton).click(function() {
        self.insertTag(self.opts.centerMarkup);
        return false;
      })).
    append(
      $(self.opts.rightButton).click(function() {
        self.insertTag(self.opts.rightMarkup);
        return false;
      })).
    append(
      $(self.opts.justifyButton).click(function() {
        self.insertTag(self.opts.justifyMarkup);
        return false;
      }));

  var $listTools = $('<ul class="natEditButtonBox"></ul>').
    append(
      $(self.opts.numberedButton).click(function() {
        self.insertLineTag(self.opts.numberedListMarkup);
        return false;
      })).
    append(
      $(self.opts.bulletButton).click(function() {
        self.insertLineTag(self.opts.bulletListMarkup);
        return false;
      })).
    append(
      $(self.opts.indentButton).click(function() {
        self.insertLineTag(self.opts.indentMarkup);
        return false;
      })).
    append(
      $(self.opts.outdentButton).click(function() {
        self.insertLineTag(self.opts.outdentMarkup);
        return false;
      }));


  var $objectTools = $('<ul class="natEditButtonBox"></ul>').
    append(
      $(self.opts.tableButton).click(function() {
        self.openDialog(self.opts.tableDialog);
        return false;
      })).
    append(
      $(self.opts.linkButton).click(function() {
        self.openDialog(self.opts.linkDialog);
        return false;
      })).
    append(
      $(self.opts.attachmentButton).click(function() {
        self.openDialog(self.opts.attachmentDialog);
        return false;
      }));

  if (foswiki.MathModePluginEnabled) {
    $objectTools.
      append(
        $(self.opts.mathButton).click(function() {
          self.insertTag(self.opts.mathMarkup);
          return false;
        }));
  }

  $objectTools.
    append(
      $(self.opts.verbatimButton).click(function() {
        self.insertTag(self.opts.verbatimMarkup);
        return false;
      })).
    append(
      $(self.opts.signatureButton).click(function() {
        self.insertTag(self.opts.signatureMarkup);
        return false;
      }));
    
  var $toolbar = 
    $('<div class="natEditToolBar"></div>').
    append($headlineTools).
    append($textTools).
    append($listTools).
    append($paragraphTools).
    append($objectTools).
    append('<span class="foswikiClear"></span>');

  if (width) {
    $toolbar.width(width);
  }

  if (self.opts.autoHideToolbar) {
    //$.log("toggling toolbar on hover event");
    $toolbar.hide();

    var toolbarState = 0;
    function toggleToolbarState () {
      if (toolbarState < 0) 
        return;
      var tmp = self.txtarea.value;
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
    }
    
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
  //$.log("called insert("+newText+")");
  var self = this;

  self.getSelectionRange();
  var startPos = self.txtarea.selectionStart;
  var text = self.txtarea.value;
  var prefix = text.substring(0, startPos);
  var postfix = text.substring(startPos+1);
  self.txtarea.value = prefix + newText + postfix;
  
  //$.log("startPos="+startPos);
  //$.log("prefix='+"+prefix+"'");
  //$.log("postfix='"+postfix+"'");
  self.setCaretPosition(startPos);
  $(self.txtarea).trigger("keypress");
};

/*************************************************************************
 * remove the selected substring
 */
$.NatEditor.prototype.remove = function() {
  var self = this;

  self.getSelectionRange();
  var startPos = self.txtarea.selectionStart;
  var endPos = self.txtarea.selectionEnd;
  var text = self.txtarea.value;
  var selection = text.substring(startPos, endPos);
  self.txtarea.value = text.substring(0, startPos) + text.substring(endPos);
  self.setSelectionRange(startPos, startPos);
  return selection;
};

/*************************************************************************
 * insert a topic markup tag 
 */
$.NatEditor.prototype.insertTag = function(markup) {
  var self = this;

  var tagOpen = markup[0];
  var sampleText = markup[1];
  var tagClose = markup[2];
  //$.log("called insertTag("+tagOpen+", "+sampleText+", "+tagClose+")");
    
  self.getSelectionRange();
  var startPos = self.txtarea.selectionStart;
  var endPos = self.txtarea.selectionEnd;
  var text = self.txtarea.value;
  var scrollTop = self.txtarea.scrollTop;
  var theSelection = text.substring(startPos, endPos);

  //$.log("startPos="+startPos+" endPos="+endPos);

  if (!theSelection) {
    theSelection = sampleText;
  }

  if (theSelection.charAt(theSelection.length - 1) == " ") { 
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
 * compatibility method for IE: this sets txtarea.selectionStart and
 * txtarea.selectionEnd of the current selection in the given textarea 
 */
$.NatEditor.prototype.getSelectionRange = function() {
  var self = this;

  //$.log("called getSelectionRange()");

  if (document.selection && !$.browser.opera) { // IE
    //$.log("IE");
    $(self.txtarea).focus();
   
    var text = self.txtarea.value;
    var c = "\001";
    var range = document.selection.createRange();
    var selection = range.text || "";
    var rangeCopy = range.duplicate();
    rangeCopy.moveToElementText(self.txtarea);
    range.text = c;
    var pos = (rangeCopy.text.indexOf(c));
   
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
  var self = this;
  self.getSelectionRange();
  var startPos = self.txtarea.selectionStart
  var endPos = self.txtarea.selectionEnd;
  return self.txtarea.value.substring(startPos, endPos);
};

/*************************************************************************
 * set the selection
 */
$.NatEditor.prototype.setSelectionRange = function(start, end) {
  var self = this;
  //$.log("setSelectionRange("+self.txtarea+", "+start+", "+end+")");
  $(self.txtarea).focus();
  if (self.txtarea.createTextRange && !$.browser.opera) {
    var lineFeeds = self.txtarea.value.substring(0, start).replace(/[^\r]/g, "").length;
    var range = self.txtarea.createTextRange();
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
},
 
/*************************************************************************
 * used for line oriented tags - like bulleted lists
 * if you have a multiline selection, the tagOpen/tagClose is added to each line
 * if there is no selection, select the entire current line
 * if there is a selection, select the entire line for each line selected
 */
$.NatEditor.prototype.insertLineTag = function(markup) {
  var self = this;

  //$.log("called inisertLineTag("+self.txtarea+", "+markup+")");
  var tagOpen = markup[0];
  var sampleText = markup[1];
  var tagClose = markup[2];

  self.getSelectionRange();

  var startPos = self.txtarea.selectionStart
  var endPos = self.txtarea.selectionEnd;
  var text = self.txtarea.value;

  //$.log("startPos="+startPos+" endPos="+endPos);

  // at this point we need to expand the selection to the \n before the startPos, and after the endPos
  while (startPos > 0 && 
    text.charCodeAt(startPos-1) != 13 &&
    text.charCodeAt(startPos-1) != 10) 
  {
    startPos--;
  }

  while (endPos < text.length && 
    text.charCodeAt(endPos) != 13 && 
    text.charCodeAt(endPos) != 10) 
  {
    endPos++;
  }

  //$.log("startPos="+startPos+" endPos="+endPos);

  var scrollTop = self.txtarea.scrollTop;
  var theSelection = text.substring(startPos, endPos);

  if (!theSelection) {
    theSelection = sampleText;
  }

  var pre = text.substring(0, startPos);
  var post = text.substring(endPos, text.length);

  // test if it is a multi-line selection, and if so, add tagOpen&tagClose to each line
  var lines = theSelection.split(/\r?\n/);
  var isMultiline = lines.length>1?true:false;
  var modifiedSelection = '';
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    var subst;
    
    if (line.match(/^\s*$/)) {
      // don't append tagOpen to empty lines
      subst = line;
    } else {
      // special case - undent (remove 3 spaces, and bullet or numbered list if outdenting away)
      if ((tagOpen == '') && (sampleText == '') && (tagClose == '')) {
        subst = line.replace(/^   (\* |\d+ |\d+\. )?/, '');
      } else {
        subst = tagOpen + line + tagClose;
      }
    }

    modifiedSelection += subst;
    if (i+1 < lines.length) 
      modifiedSelection += '\n';
  }

  self.txtarea.value = pre + modifiedSelection + post;

  startPos += (isMultiline?0:tagOpen.length);
  endPos = startPos + modifiedSelection.length - (isMultiline?0:tagOpen.length-tagClose.length);

  self.setSelectionRange(startPos, endPos);
  self.txtarea.scrollTop = scrollTop;
};

/*************************************************************************
 * opens a modal dialog
 */
$.NatEditor.prototype.openDialog = function(opts) {
  var self = this;
  if (opts.dialog && $(opts.dialog).length) {
    self._openDialog(opts);
  } else {
    if (opts.url) {
      $.get(opts.url, function(data) {
        opts.dialog = "#"+$(data).attr('id');
        $("body").append(data);
        self._openDialog(opts);
      });
    }
  }
};

$.NatEditor.prototype._openDialog = function(opts) {
  var self = this;

  var selection = self.getSelection() || '';
  opts._startPos = self.txtarea.selectionStart;
  opts._endPos = self.txtarea.selectionEnd;
  var $dialog = $(opts.dialog);

  $dialog.modal({
    persist: true,
    close:false,
    onShow: function(dialog) {
      $(window).trigger("resize.simplemodal");
      dialog.data.find("input:visible:first").focus();
      dialog.data.find("input.selection").val(selection);
      if (opts.onShow) {
        opts.onShow.call(this, self);
      }
    }
  });
  if (!opts._doneInit) {
    $dialog.find(".submit").click(function() {
      $.modal.close();
      if ($.browser.msie) { // restore lost position
        self.setSelectionRange(opts._startPos, opts._endPos);
      }
      if (typeof(opts.onSubmit) != 'undefined') {
        opts.onSubmit.call(this, self);
      }
      return false;
    });
    $dialog.find(".cancel").click(function() {
      $.modal.close();
      return false;
    });
    opts._doneInit = true;
  }
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
    windowHeight = $(window).height(),
    windowWidth = $(window).width(),
    bottomHeight = $('.natEditBottomBar').outerHeight({margin:true}),
    offset = $txtarea.offset(),
    tmceEdContainer, tmceIframe,
    minWidth, minHeight, newHeight, newHeightExtra = 0, natEditTopicInfoHeight,
    $debug = $("#DEBUG");
		
  if ($txtarea.parents(":not(:visible)").length) { // fix for  jquery < 1.3.x
    //$.log("natedit textarea not visible ... skipping fixHeight");
    return;
  }
  //$.log("called natedit::fixHeight("+self.txtarea+")");

  // get new window height (and width)
  if (!windowHeight) {
    windowHeight = window.innerHeight;
  }
  if (!windowWidth) {
    windowWidth = window.innerWidth;
  }
  newHeight = windowHeight-offset.top-bottomHeight*2-12;
  if ($debug) {
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

  $txtarea.height(newHeight);
	
	
  /* Resize tinyMCE. Both the iframe and containing table need to be adjusted. 
   * SMELL: Hard-coded magic numbers : 12px */
  if (typeof(tinyMCE) === 'object' && typeof(tinyMCE.activeEditor) === 'object' &&
    !tinyMCE.activeEditor.getParam('fullscreen_is_enabled')) {
    /* TMCE container = <td>, in a <tr>, <tbody>, <table>, <span> next to original 
     * <textarea display: none> in a <div .natEdit> in a <div .jqTabContents> :-) */
    /* SMELL: No "proper" way to get correct instance until Item2297 finished */
    tmceEdContainer = tinyMCE.activeEditor.contentAreaContainer;
    tmceIframe = $(tmceEdContainer).children('iframe')[0];
    tmceTable = tmceEdContainer.parentNode.parentNode.parentNode;
    /* The NatEdit Title: text sits in the jqTab above TMCE */
    natEditTopicInfoHeight = $($(tmceTable.parentNode.parentNode).siblings(
      '.natEditTopicInfo')[0]).outerHeight({margin: true});
    offset = $(tmceTable).offset().top;

    $(tmceEdContainer.parentNode).siblings().each(	/* Iterate over TMCE layout */
      function (i, tr) {
        newHeightExtra = newHeightExtra + $(tr).outerHeight({margin: true});
      }
    );
    /* SMELL: minHeight isn't working on IE7 (but does on IE6 + IE8 */
    newHeight = windowHeight - offset - bottomHeight*2 - 12;
    if (self.opts.minHeight && newHeight - newHeightExtra + 
      natEditTopicInfoHeight < self.opts.minHeight) {
      newHeight = self.opts.minHeight + natEditTopicInfoHeight - 12;
    }
    $(tmceTable).height(newHeight);
    $(tmceIframe).height(newHeight - newHeightExtra);
    /* SMELL: We set a width first, then check to see if it's too small
     * by checking if document is able to accomodate a larger size..
     * ... and this doesn't work in IE6 or IE8, so minWidth not enforced there. */
    offset = ($(tmceTable).offset().left * 2) + 4;	/* Assume centred layout */
    newWidth = windowWidth - offset;
    $(tmceTable).width(newWidth);
    $(tmceIframe).width(newWidth);
    minWidth = $(document).width() - offset;
    if (newWidth < minWidth) {
      $(tmceTable).width(minWidth);
      $(tmceIframe).width(minWidth);
    }
  }
};

/*************************************************************************
 * adjust height of textarea according to content
 */
$.NatEditor.prototype.autoExpand = function() {
  var self = this;
  var $txtarea = $(self.txtarea);

  //$.log("called autoExpand()");

  var now = new Date();
  //
  // don't do it too often
  if (self._time && now.getTime() - self._time.getTime() < 100) {
    //$.log("suppressing events within 100ms");
    return;
  }
  self._time = now;

  window.setTimeout(function() {
    var text = self.txtarea.value+'x';
    if (text == self._lastText) {
      //$.log("suppressing events for same text");
      return
    };
    self._lastText = text;
    text = $.natedit.htmlEntities(text);
   
    self.helper.width($txtarea.width());

    //$.log("helper text="+text);
    self.helper.html(text);
    var height = self.helper.height() + 12;
    height = Math.max($txtarea.height(), height);
    //$.log("helper height="+height);
    $txtarea.height(height).width($txtarea.width());
  },10);
};

/*****************************************************************************
 * plugin definition
 */
$.natedit = {

  /***************************************************************************
   * widget constructor
   */
  build: function(opts) {
    //$.log("called natedit()");

    // build main options before element iteration
    var opts = $.extend({}, $.natedit.defaults, opts);

    return this.each(function() {
      new $.NatEditor(this, opts);
    });

    // We use a helper div to measure text. We wrap it an overflow: hidden
    // container to avoid lengthening the page scrollbar.

    // iterate and reformat each matched element
    return this.each(function() {
    });
  },

  /*************************************************************************
   * replace entities with real html
   */
  htmlEntities: function(text) { 
    var entities = {
      '&':'&amp;',
      '<':'&lt;',
      '>':'&gt;',
      '"':'&quot;',
      "\\n": "<br />"
    };
    for(i in entities) {
      text = text.replace(new RegExp(i,'g'),entities[i]);
    }
    return text;
  },

  /*************************************************************************
   * add a handler to the submit process
   */
  addSubmitHandler: function(handler) {
    var oldSubmitHandler = beforeSubmitHandler || function() {};
    beforeSubmitHandler = function(script, action) {
      if (oldSubmitHandler(script, action) === false ||
          handler(script, action) === false) {
        return false;
      } else {
        return true;
      }
    }
  },

  /***************************************************************************
   * plugin defaults
   */
  defaults: {
    h1Button: '<li class="natEditH1Button"><a href="#" title="Level 1 headline" accesskey="1"><span>H1</span></a></li>',
    h2Button: '<li class="natEditH2Button"><a href="#" title="Level 2 headline" accesskey="2"><span>H2</span></a></li>',
    h3Button: '<li class="natEditH3Button"><a href="#" title="Level 3 headline" accesskey="3"><span>H3</span></a></li>',
    h4Button: '<li class="natEditH4Button"><a href="#" title="Level 4 headline" accesskey="4"><span>H4</span></a></li>',
    boldButton: '<li class="natEditBoldButton"><a href="#" title="Bold" accesskey="*"><span>Bold</span></a></li>',
    italicButton: '<li class="natEditItalicButton"><a href="#" title="Italic" accesskey="_"><span>Italic</span></a></li>',
    monoButton: '<li class="natEditMonoButton"><a href="#" title="Monospace" accesskey="="><span>Monospace</span></a></li>',
    underlineButton: '<li class="natEditUnderlineButton"><a href="#" title="Underline" accesskey="u"><span>Underline</span></a></li>',
    strikeButton: '<li class="natEditStrikeButton"><a href="#" title="Strike" accesskey="-"><span>Strike</span></a></li>',
    leftButton: '<li class="natEditLeftButton"><a href="#" title="Align left" accesskey="<"><span>Left</span></a></li>',
    centerButton: '<li class="natEditCenterButton"><a href="#" title="Center align" accesskey="."><span>Center</span></a></li>',
    rightButton: '<li class="natEditRightButton"><a href="#" title="Align right" accesskey=">"><span>Right</span></a></li>',
    justifyButton: '<li class="natEditJustifyButton"><a href="#" title="Justify text" accesskey="j"><span>Justify</span></a></li>',
    numberedButton: '<li class="natEditNumberedButton"><a href="#" title="Numbered list" accesskey="l"><span>Numbered List</span></a></li>',
    bulletButton: '<li class="natEditBulletButton"><a href="#" title="Bullet list" accesskey="*"><span>Bullet List</span></a></li>',
    indentButton: '<li class="natEditIndentButton"><a href="#" title="Indent" accesskey="-"><span>Indent</span></a></li>',
    outdentButton: '<li class="natEditOutdentButton"><a href="#" title="Outdent" accesskey="o"><span>Outdent</span></a></li>',
    tableButton: '<li class="natEditTableButton"><a href="#" title="Insert table" accesskey="t"><span>Table</span></a></li>',
    linkButton: '<li class="natEditIntButton"><a href="#" title="Insert link" accesskey="#"><span>Link</span></a></li>',
    mathButton: '<li class="natEditMathButton"><a href="#" title="Mathematical formula (LaTeX)" accesskey="m"><span>Math</span></a></li>',
    attachmentButton: '<li class="natEditAttachmentButton"><a href="#" title="Insert attachment" accesskey="a"><span>Attachment</span></a></li>',
    verbatimButton: '<li class="natEditVerbatimButton"><a href="#" title="Ignore wiki formatting" accesskey="v"><span>Verbatim</span></a></li>',
    signatureButton: '<li class="natEditSignatureButton"><a href="#" title="Your signature with timestamp" accesskey="z"><span>Sign</span></a></li>',

    h1Markup: ['---+!! ','%TOPIC%',''],
    h2Markup: ['---++ ','Headline text',''],
    h3Markup: ['---+++ ','Headline text',''],
    h4Markup: ['---++++ ','Headline text',''],
    boldMarkup: ['*', 'Bold text', '*'],
    italicMarkup: ['_', 'Italic text', '_'],
    monoMarkup: ['=', 'Monospace text', '='],
    underlineMarkup: ['<u>', 'Underlined text', '</u>'],
    strikeMarkup: ['<strike>', 'Strike through text', '</strike>'],
    leftMarkup: ['<p style="text-align:left">\n','Align left','\n</p>\n'],
    centerMarkup: ['<p style="text-align:center">\n','Center text','\n</p>\n'],
    rightMarkup: ['<p style="text-align:right">\n','Align right','\n</p>\n'],
    justifyMarkup: ['<p style="text-align:justify">\n','Justify text','\n</p>\n'],
    numberedListMarkup: ['   1 ','enumerated item',''],
    bulletListMarkup: ['   * ','bullet item',''],
    indentMarkup: ['   ','',''],
    outdentMarkup: ['','',''],
    tableDialog: {
      url: foswiki.scriptUrlPath+'/rest/RenderPlugin/template?name=editdialog;expand=inserttable;topic='+foswiki.web+"."+foswiki.topic,
      dialog: "#natEditInsertTable",
      onSubmit: function(nateditor) {
	$.natedit.handleInsertTable(nateditor);
      }
    },
    linkDialog: {
      url: foswiki.scriptUrlPath+'/rest/RenderPlugin/template?name=editdialog;expand=insertlink;topic='+foswiki.web+'.'+foswiki.topic,
      dialog: '#natEditInsertLink',
      onSubmit: function(nateditor) {
	$.natedit.handleInsertLink(nateditor);
      },
      onShow: function(nateditor) {
        $.natedit.initInsertLink(nateditor);
      }
    },
    attachmentDialog: {
      url: foswiki.scriptUrlPath+'/rest/RenderPlugin/template?name=editdialog;expand=insertattachment;topic='+foswiki.web+'.'+foswiki.topic,
      dialog: '#natEditInsertAttachment',
      onSubmit: function(nateditor) {
	$.natedit.handleInsertAttachment(nateditor);
      },
      onShow: function(nateditor) {
        $.natedit.initInsertAttachment(nateditor);
      }
    },
    imagePluginMarkup: ['%IMAGE{"','Example.jpg','|400px|Caption text|frame|center"}%'],
    imageMarkup: ['<img src="%<nop>ATTACHURLPATH%/','Example.jpg','" title="Example" />'],
    mathMarkup: ['<latex title="Example">\n','\\sum_{x=1}^{n}\\frac{1}{x}','\n</latex>'],
    verbatimMarkup: ['<verbatim>\n','Insert non-formatted text here','\n</verbatim>\n'],
    signatureMarkup: ['-- ', '%WIKINAME%, ' - '%DATE%'],

    autoHideToolbar: false,
    hideToolbar: false,
    autoMaxExpand:false,
    autoExpand:false,
    minHeight:230
  }
};

/* register to jquery */
$.fn.natedit = $.natedit.build;

/* initializer */
$(function() {

  var foundNatEdit = false;
  $(".natedit").each(function() {
    $(this).natedit({
      autoMaxExpand:false,
      signatureMarkup: ['-- ', foswiki.wikiUserName, ' - '+foswiki.serverTime]
    });
    foundNatEdit = true;
  });
  if (foundNatEdit) {
    var savetext = $("#savearea").val();
    if (savetext && savetext.length) {
      $("#topic").val(savetext);
    }
  }
});

})(jQuery);
