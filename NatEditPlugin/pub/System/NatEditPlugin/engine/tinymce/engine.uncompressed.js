/*
 * jQuery NatEdit: tinymce engine
 *
 * Copyright (c) 2015-2016 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */

/*global BaseEngine:false tinymce:false*/

"use strict";
(function($) {

/*****************************************************************************
 * constructor
 */

TinyMCEEngine.prototype = new BaseEngine();
TinyMCEEngine.prototype.constructor = TinyMCEEngine;
TinyMCEEngine.prototype.parent = BaseEngine.prototype;

function TinyMCEEngine(shell, opts) {
  var self = this,
      wikiUserNameUrl = foswiki.getScriptUrlPath("view", foswiki.getPreference("USERSWEB"), foswiki.getPreference("WIKINAME")),
      pubUrlPath = foswiki.getPreference("PUBURLPATH");

  self.shell = shell;
  self.opts = $.extend({}, TinyMCEEngine.defaults, self.shell.opts.tinymce, opts);
  self.opts.tinymce.selector = "#"+self.shell.id+" textarea";
  self.opts.natedit.signatureMarkup = ['-- ', '<a href="'+wikiUserNameUrl+'">'+foswiki.getPreference("WIKINAME")+'</a>', ' - '+foswiki.getPreference("SERVERTIME")];

  $.extend(self.shell.opts, self.opts.natedit);
}

/*************************************************************************
 * init tinymce instance 
 */
TinyMCEEngine.prototype.init = function() {
  var self = this,
      pubUrlPath = foswiki.getPreference("PUBURLPATH"),
      systemWeb = foswiki.getPreference('SYSTEMWEB'),
      editorPath = pubUrlPath+'/'+systemWeb+'/TinyMCEPlugin',
      dfd = $.Deferred();

  $('<link>')
    .appendTo('head')
    .attr({type : 'text/css', rel : 'stylesheet'})
    .attr('href', editorPath + '/wysiwyg.css');

  self.shell.getScript(editorPath+'/tinymce/js/tinymce/tinymce.min.js').done(function() {

    self.opts.tinymce.init_instance_callback = function(editor) {

      //self.log("tinymce instance", editor);

      self.editor = editor;
      //window.editor = editor; // playground

      self.tml2html($(self.shell.txtarea).val())
        .done(function(data) {
          self.editor.setContent(data);
          self.editor.undoManager.clear(); // don't go beyond this level
          $(window).trigger("resize");
          dfd.resolve(self);
        })
        .fail(function() {
          dfd.reject();
          alert("Error calling tml2html"); // SMELL: better error handling
        });

      self.shell.form.on("beforeSubmit.natedit", function(e, params) {
      });

    };

    tinymce.init(self.opts.tinymce);

  }).fail(function() {
    dfd.reject();
    alert("failed to load tinymce.js");
  });

  return dfd.promise();
};

/*************************************************************************
 * intercept save process
 */
TinyMCEEngine.prototype.beforeSubmit = function(action) {
  var self = this, dfd;

  if (action === 'cancel') {
    return;
  }

  return self.html2tml(self.editor.getContent())
    .done(function(data) {
      $(self.shell.txtarea).val(data);
    })
    .fail(function() {
      alert("Error calling html2tml"); // SMELL: better error handling
    });
};


/*************************************************************************
 * init gui
 */
TinyMCEEngine.prototype.initGui = function() {
  var self = this;

  // flag to container ... smell: is this really needed?
  self.shell.container.addClass("ui-natedit-wysiwyg-enabled");

  // highlight buttons on toolbar when the cursor moves into a format
  $.each(self.opts.tinymce.formats, function(formatName) {
    self.editor.formatter.formatChanged(formatName, function(state, args) {
      $.each(self.editor.formatter.get(formatName), function(i, format) {
        if (state) {
          self.shell.toolbar.find(format.toolbar).addClass("ui-natedit-active");
        } else {
          self.shell.toolbar.find(format.toolbar).removeClass("ui-natedit-active");
        }
      });
    });
  });

  // listen to change events and update stuff
  self.editor.on("change", function() {
    self.updateUndoButtons();
  });

  self.updateUndoButtons();
};

/*************************************************************************
 * register events to editor engine
 */
TinyMCEEngine.prototype.updateUndoButtons = function() {
  var self = this,
    undoButton = self.shell.container.find(".ui-natedit-undo"),
    redoButton = self.shell.container.find(".ui-natedit-redo"),
    undoManager = self.editor.undoManager;

  if (undoManager.hasUndo()) {
    undoButton.button("enable");
  } else {
    undoButton.button("disable");
  }

  if (undoManager.hasRedo()) {
    redoButton.button("enable");
  } else {
    redoButton.button("disable");
  }
};

/*************************************************************************
 * register events to editor engine
 */
TinyMCEEngine.prototype.on = function(eventName, func) {
  var self = this;

  self.editor.on(eventName, func);  
  return self.editor;
};

/*************************************************************************
 * handle toolbar actions
 */
TinyMCEEngine.prototype.handleToolbarAction = function(ui) {
  var self = this,
      data = $.extend({}, ui.data()),
      format = data.markup;

  // TODO: for now only handle markup buttons
  if (typeof(format) !== 'undefined') {
    if (self.editor.formatter.get(format)) {
      delete data.markup;
      self.editor.formatter.toggle(format);
    }
  }

  return data;
};


/*************************************************************************
 * convert tml to html using WysiwygPlugin, returns a Deferred
 */
TinyMCEEngine.prototype.tml2html = function(tml) {
  var /*self = this,*/
      url = foswiki.getScriptUrl("rest", "WysiwygPlugin", "tml2html");

  //console.log("called tml2html", tml);

  return $.post(url, {
    topic: foswiki.getPreference("WEB")+"."+foswiki.getPreference("TOPIC"),
    t: (new Date()).getTime(),
    text: tml
  });
};

/*************************************************************************
 * convert html back to tml using WysiwygPlugin, returns a Deferred
 */
TinyMCEEngine.prototype.html2tml = function(html) {
  var /*self = this,*/
      url = foswiki.getScriptUrl("rest", "WysiwygPlugin", "html2tml");

  //self.log("called html2tml", tml);

  return $.post(url, {
    topic: foswiki.getPreference("WEB")+"."+foswiki.getPreference("TOPIC"),
    t: (new Date()).getTime(),
    text: html
  });
};

/*************************************************************************
 * insert stuff at the given cursor position
 */
TinyMCEEngine.prototype.insert = function(text) {
  var self = this;

  self.editor.insertContent(text);
};

/*************************************************************************
 * remove the selected substring
 */
TinyMCEEngine.prototype.remove = function() {
  var self = this;

  return self.editor.selection.setContent("");
};

/*************************************************************************
 * returns the current selection
 */
TinyMCEEngine.prototype.getSelection = function() {
  var self = this;

  return self.editor.selection.getContent();
};

/*************************************************************************
  * returns the currently selected lines
  */
TinyMCEEngine.prototype.getSelectionLines = function() {
  var self = this, 
      range = self.editor.selection.getRng(),
      start = range.startOffset,
      end = range.endOffset,
      node = self.editor.selection.getNode(),
      text = $(node).text();


  while (start > 0 && text.charCodeAt(start-1) !== 13 && text.charCodeAt(start-1) !== 10) {
    start--;
  }

  while (end < text.length && text.charCodeAt(end) !== 13 && text.charCodeAt(end) !== 10) {
    end++;
  }

  if (end >= text.length) {
    end = text.length - 1;
  }

//console.log("start=",start,"end=",end,"range=",range,"text=",text,"len=",text.length);

  range.setStart(node, start);
  //range.setEnd(node, end);

  self.editor.selection.setRng(range);

  return text;
};

/*************************************************************************
 * set the caret position to a specific position. thats done by setting
 * the selection range to a single char at the given position
 */
TinyMCEEngine.prototype.setCaretPosition = function(caretPos) {
  var self = this;

  return self.editor.selection.setCursorLocation(undefined, caretPos);
};

/*************************************************************************
 * get the caret position 
 */
TinyMCEEngine.prototype.getCaretPosition = function() {
  var self = this;

  return self.editor.selection.getEnd();
};

/*************************************************************************
 * undo recent change
 */
TinyMCEEngine.prototype.undo = function() {
  var self = this;

  self.editor.undoManager.undo();
  self.updateUndoButtons();
};

/*************************************************************************
 * redo recent change
 */
TinyMCEEngine.prototype.redo = function() {
  var self = this;

  self.editor.undoManager.redo();
  self.updateUndoButtons();
};

/*************************************************************************
 * used for line oriented tags - like bulleted lists
 * if you have a multiline selection, the tagOpen/tagClose is added to each line
 * if there is no selection, select the entire current line
 * if there is a selection, select the entire line for each line selected
 */
TinyMCEEngine.prototype.insertLineTag = function(markup) {
  var self = this,
      tagOpen = markup[0],
      selection = self.getSelectionLines() || markup[1],
      tagClose = markup[2];

  self.log("selection=",selection);

  self.editor.selection.setContent(tagOpen+selection+tagClose);
};

/*************************************************************************
 * insert a topic markup tag 
 */
TinyMCEEngine.prototype.insertTag = function(markup) {
  var self = this,
      tagOpen = markup[0],
      selection = self.getSelection() || markup[1],
      tagClose = markup[2];

  self.editor.selection.setContent(tagOpen+selection+tagClose);
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
TinyMCEEngine.prototype.insertTable = function(opts) {
  /*var self = this;*/

  throw("not implemented: insertTable opts=",opts);
};

/*************************************************************************
 * set the value of the editor
 */
TinyMCEEngine.prototype.setValue = function(val) {
  var self = this;

  self.editor.setContent(val);
};


/*****************************************************************************
 * search & replace a term in the textarea
 */
TinyMCEEngine.prototype.searchReplace = function(search, replace, ignoreCase) {
  /*var self = this;*/

  throw("not implemented: searchReplace(",search,replace,ignoreCase,")");
};

/*************************************************************************
 * get the DOM element that holds the editor engine
 */
TinyMCEEngine.prototype.getWrapperElement = function() {
  var self = this;

  return self.editor?$(self.editor.contentAreaContainer).children("iframe"):null;
};

/*************************************************************************
 * set the size of editor
 */
TinyMCEEngine.prototype.setSize = function(width, height) {
  var self = this,
      elem = self.getWrapperElement();

  width = width || 'auto';
  height = height || 'auto';

  if (elem) {
    elem.height(height);
  }
};


/***************************************************************************
 * editor defaults
 */
TinyMCEEngine.defaults = {
  debug: false,
  natedit: {
  },
  tinymce: {
    selector: 'textarea#topic',
    menubar: false,
    toolbar: false,
    statusbar: false,
    plugins: 'contextmenu table searchreplace paste lists link anchor hr legacyoutput image', // save autosave fullscreen anchor charmap code textcolor colorpicker
    paste_data_images: true,
    content_css: ["/pub/System/TinyMCEPlugin/wysiwyg.css", "/pub/System/SkinTemplates/base.css"],
    formats: {
      h1Markup: { block: "h1", toolbar: ".ui-natedit-h1" },
      h2Markup: { block: "h2", toolbar: ".ui-natedit-h2" },
      h3Markup: { block: "h3", toolbar: ".ui-natedit-h3" },
      h4Markup: { block: "h4", toolbar: ".ui-natedit-h4" },
      h5Markup: { block: "h5", toolbar: ".ui-natedit-h5" },
      h6Markup: { block: "h6", toolbar: ".ui-natedit-h6" },
      normalMarkup: { block: "p", toolbar: ".ui-natedit-normal"},
      quoteMarkup: { block: "blockquote", toolbar: ".ui-natedit-quoted"},
      boldMarkup: { inline: "b", toolbar: ".ui-natedit-bold" },
      italicMarkup: { inline: "em", toolbar: ".ui-natedit-italic" },
      monoMarkup: { inline: "code", toolbar: ".ui-natedit-mono" },
      underlineMarkup: { inline: "span", styles: { "text-decoration": "underline" }, toolbar: ".ui-natedit-underline"  },
      strikeMarkup: { inline: "span", styles: { "text-decoration": "line-through" }, toolbar: ".ui-natedit-strike"  },
      superscriptMarkup: { inline: "sup", toolbar: ".ui-natedit-super" },
      subscriptMarkup: { inline: "sub", toolbar: ".ui-natedit-sub" },
      leftMarkup: { block: "p", styles: { "text-align": "left" }, toolbar: ".ui-natedit-left" },
      rightMarkup: { block: "p", styles: { "text-align": "right" }, toolbar: ".ui-natedit-right" },
      centerMarkup: { block: "p", styles: { "text-align": "center" }, toolbar: ".ui-natedit-center" },
      justifyMarkup: { block: "p", styles: { "text-align": "justify" }, toolbar: ".ui-natedit-justify" },
      verbatimMarkup: { block: "pre", classes: "TMLverbatim", toolbar: ".ui-natedit-verbatim" }
    }
  }
};

/*************************************************************************
 * register engine to NatEditor shell
 */
$.NatEditor.engines.tinymce = {
  createEngine: function(shell) {
    return (new TinyMCEEngine(shell)).init();
  }
};

})(jQuery);
