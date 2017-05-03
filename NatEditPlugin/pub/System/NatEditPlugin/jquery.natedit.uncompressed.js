/*
 * jQuery NatEdit plugin 
 *
 * Copyright (c) 2008-2017 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */

/*global FoswikiTiny:false, tinyMCE:false, StrikeOne:false, plupload:false */
(function($) {
"use strict";

/*****************************************************************************
 * class TextareaState
 */
function TextareaState(editor) {
  var self = this;

  self.editor = editor;
  self.init();
}

TextareaState.prototype.init = function() {
  var self = this;

  self.editor.getSelectionRange();
  self.selectionStart = self.editor.txtarea.selectionStart;
  self.selectionEnd = self.editor.txtarea.selectionEnd;
  self.scrollTop = self.editor.txtarea.scrollTop;
  self.value = self.editor.txtarea.value;
};

TextareaState.prototype.restore = function() {
  var self = this;

  self.editor.txtarea.value = self.value;
  self.editor.txtarea.scrollTop = self.scrollTop;
  self.editor.setSelectionRange(self.selectionStart, self.selectionEnd);

  $(window).trigger("resize");
};

TextareaState.prototype.isUnchanged = function() {
  var self = this, txtarea = self.editor.txtarea;

  self.editor.getSelectionRange();

  return txtarea.selectionStart == self.selectionStart &&
      txtarea.selectionEnd == self.selectionEnd &&
      txtarea.scrollTop == self.scrollTop &&
      txtarea.value == self.value;
};

/*****************************************************************************
 * class UndoManager
 */
function UndoManager(editor) {
  var self = this;

  self.editor = editor;
  self.undoBuf = [];
  self.undoPtr = -1;
  self.mode = "none";

  $(self.editor.txtarea).on("keydown keyup", function(ev) {
    var code = ev.keyCode,
      mode;

    if (ev.ctrlKey || ev.metaKey) {
      switch (code) {
        case 17:
          return false;
        case 89: // ctbrl+y 
          if (ev.type == "keydown") {
            self.redo();
          }
          ev.preventDefault();
          return false;
        case 90: // ctrl+z 
          if (ev.type == "keydown") {
            self.undo();
          }
          ev.preventDefault();
          return false;
      }
    } else {
      if (ev.type == "keyup") {
        if ((code >= 33 && code <= 40) || (code >= 63232 && code <= 63235)) {
          mode = "moving";
        } else if (code == 8 || code == 46 || code == 127) {
          mode = "deleting";
        } else if (code == 13 || code == 32) {
          mode = "whitespace";
        } else if (code == 27) {
          mode = "escape";
        } else if ((code < 16 || code > 20) && code != 91 && code != 32) {
          mode = "typing";
        }
      }
    }

    if (ev.type == "keyup") {
      self.saveState(mode);
    }
  }).on("click drop paste", function(ev) {
    var mode = "paste";

    if (ev.type == "click") {
      mode = "moving";
    }

    self.saveState(mode);
  });

  // initial state
  self.saveState("none");
}

UndoManager.prototype.updateGui = function() {
  var self = this,
    undoButton = self.editor.container.find(".ui-natedit-undo"),
    redoButton = self.editor.container.find(".ui-natedit-redo");

  if (self.canUndo()) {
    undoButton.button("enable");
  } else {
    undoButton.button("disable");
  }

  if (self.canRedo()) {
    redoButton.button("enable");
  } else {
    redoButton.button("disable");
  }
};

UndoManager.prototype.canUndo = function() {
  var self = this;

  return self.undoPtr > 0;
};

UndoManager.prototype.canRedo = function() {
  var self = this;

  return typeof(self.undoBuf[self.undoPtr+1]) !== 'undefined';
};

UndoManager.prototype.getCurrentState = function() {
  var self = this;

  return self.undoBuf[self.undoPtr];
};

UndoManager.prototype.saveState = function(mode) {
  var self = this,
    currentState = self.getCurrentState();

  if (typeof(currentState) !== 'undefined') {

    if (currentState.isUnchanged()) {
      return;
    }

    if (currentState.value == self.editor.txtarea.value 
        || (mode != "none" && mode == self.mode)
        || (mode === "whitespace" && self.mode === "typing")) {
      // reuse the current state if it is just a move operation
      $.log("NATEDIT: reuse current state in mode=",mode);
      self.mode = mode;
      currentState.init();
      return;
    }
  }

  $.log("NATEDIT: mode=",mode);
  self.mode = mode;

  self.undoPtr++;
  $.log("NATEDIT: save state at undoPtr=",self.undoPtr);

  currentState = new TextareaState(self.editor);
  self.undoBuf[self.undoPtr] = currentState;
  self.undoBuf[self.undoPtr+1] = undefined;

  self.updateGui();
};

UndoManager.prototype.undo = function() {
  var self = this;

  $.log("NATEDIT: called undo");

  if (!self.canUndo()) {
    $.log("... can't undo");
    return;
  }

  self.undoPtr--;
  $.log("NATEDIT: ... undoing undoPtr=",self.undoPtr);
  self.undoBuf[self.undoPtr].restore();

  self.mode = "none";
  self.updateGui();
};

UndoManager.prototype.redo = function() {
  var self = this;

  if (!self.canRedo()) {
    $.log("NATEDIT: ... can't redo");
    return;
  }

  self.undoPtr++;
  $.log("NATEDIT: ... redoing undoPtr=",self.undoPtr);
  self.undoBuf[self.undoPtr].restore();

  self.mode = "none";
  self.updateGui();
};

/*****************************************************************************
 * class NatEditor
 */
$.NatEditor = function(txtarea, opts) {
  var self = this,
      $txtarea = $(txtarea);

  // build element specific options. 
  self.opts = $.extend({}, opts, $txtarea.data());
  self.txtarea = txtarea;
  self.id = foswiki.getUniqueID();
  self.form = $(txtarea.form);
 
  if (typeof(self.txtarea.selectionStart) === 'undefined') {
    self.oldIE = true; /* all IEs up to IE9; IE10 has got selectionStart/selectionEnd */
  }

  $.log("NATEDIT: opts=",self.opts);
  // disable autoMaxExpand and resizable if we are auto-resizing
  if (self.opts.autoResize) {
    self.opts.autoMaxExpand = false;
    self.opts.resizable = false;
  }

  $txtarea.addClass("ui-natedit ui-widget");

  self.initGui();
  self.undoManager = new UndoManager(self);

  if (self.opts.showToolbar) {
    self.initToolbar();
  }

  self.initForm();

  /* establish auto max expand */
  if (self.opts.autoMaxExpand) {
    $txtarea.addClass("ui-natedit-autoexpand");
    self.autoMaxExpand();

    // disabled height property in parent container
    self.container.parent().css("cssText", "height: auto !important");
  }

  /* establish auto expand */
  if (self.opts.autoResize) {
    self.initAutoExpand();
    self.autoResize();
  }

  /* listen to keystrokes */
  $txtarea.on("keydown", function(ev) {
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


  self.txtarea.value = prefix + list + postfix;
  self.setCaretPosition(prefix.length + list.length);
  self.undoManager.saveState("command");

  ev.preventDefault();
};

/*************************************************************************
 * init the helper to auto-expand the textarea on content change
 */
$.NatEditor.prototype.initAutoExpand = function() {
  var self = this,
      $txtarea = $(self.txtarea),
      style;

  self.helper = $('<textarea tabindex="-1" class="ui-natedit-auto-expand-helper" />').appendTo('body');

  // get text styles and apply them to the helper
  style = {
    fontFamily: $txtarea.css('fontFamily') || '',
    fontSize: $txtarea.css('fontSize') || '',
    fontWeight: $txtarea.css('fontWeight') || '',
    fontStyle: $txtarea.css('fontStyle') || '',
    fontStretch: $txtarea.css('fontStretch') || '',
    fontVariant: $txtarea.css('fontVariant') || '',
    letterSpacing: $txtarea.css('letterSpacing') || '',
    textTransform: $txtarea.css('textTransform') || '',
    textIndent: $txtarea.css('textIndent') || '',
    wordSpacing: $txtarea.css('wordSpacing') || '',
    lineHeight: $txtarea.css('lineHeight') || '',
    padding: $txtarea.css('padding') || '',
    textWrap: 'unrestricted'
  };
  self.helper.css(style);

  // add event handler
  if ('onpropertychange' in self.txtarea) {
    if ('oninput' in self.txtarea) {
      // IE9
      $txtarea.on('input.natedit keyup.natedit', function() {
        self.autoResize();
      });
    } else {
      // IE7 / IE8
      $txtarea.on('propertychange.natedit', function(ev) {
        if (ev.propertyName === 'value') {
          self.autoResize();
        }
      });
    }
  } else {
    // Modern Browsers
    $txtarea.on('input.natedit', function() {
      self.autoResize();
    });
  }

  // listen to window resize
  $(window).on("resize.natedit", function() {
    self.autoResize();
  });

};

/*************************************************************************
 * init the gui
 */
$.NatEditor.prototype.initGui = function() {
  var self = this, $txtarea = $(self.txtarea);

  self.container = $txtarea.wrap('<div class="ui-natedit"></div>').parent();
  self.container.attr("id", self.id);
  self.container.data("natedit", self);

  /* flag enabled plugins */
  if (typeof(tinyMCE) !== 'undefined') {
    self.container.addClass("ui-natedit-wysiwyg-enabled");
  }
  if (foswiki.getPreference("NatEditPlugin").FarbtasticEnabled) {
    self.container.addClass("ui-natedit-colorpicker-enabled");
  }

  if (self.opts.resizable) {
    // test for native resize
    if (typeof(self.txtarea.style.resize) === 'undefined') {
      //$.log("NATEDIT: falling back to jquery-ui resizable");
      $txtarea.resizable();
    } else {
      //$.log("NATEDIT: using native resize css");
      $txtarea.css("resize", "both");
    }
  }

  /* init the perms tab */
  function updateDetails(txtboxlst) {
    var currentValues = txtboxlst.currentValues,
      type = $(txtboxlst.input).data("permType");

    $.log("NATEDIT: currentValues="+currentValues.join(", "));
    self.setPermission(type, {
      allow: currentValues.join(", ")
    });
  }

  self.form.find(".ui-natedit-details-container input").on("blur", function() {
    var $this = $(this);
    $this.trigger("AddValue", $this.val());
  }).textboxlist({
    onSelect: updateDetails,
    onDeselect: updateDetails,
    onClear: updateDetails,
    onReset: updateDetails,
    autocomplete: foswiki.getScriptUrl('view', self.opts.systemWeb, 'JQueryAjaxHelper', {
        section: 'user',
        skin:    'text',
        contenttype: 'application/json'
    })
  });

  function setPermissionSet(data) {
    if (data.perms === 'details') {
      self.showPermDetails(data.permType);
    } else {
      self.hidePermDetails(data.permType);
      self.setPermission(data.permType, data.perms);
    }
  }

  // behavior
  self.form.find(".ui-natedit-permissions-form input[type=radio]").on("click", function() {
    setPermissionSet($(this).data());
  });

  // init
  self.form.find(".ui-natedit-permissions-form input[type=radio]:checked").not(":disabled").each(function() {
    setPermissionSet($(this).data());
  });

  // SMELL:monkey patch FoswikiTiny
  if (typeof(FoswikiTiny) !== 'undefined') {
    self.origSwitchToRaw = FoswikiTiny.switchToRaw;

    FoswikiTiny.switchToRaw = function(inst) {
      self.tinyMCEInstance = inst;
      self.origSwitchToRaw(inst);
      self.showToolbar();
      $("#"+inst.id+"_2WYSIWYG").remove(); // SMELL: not required ... shouldn't create it in the first place
    };
  } else {
    $txtarea.removeClass("foswikiWysiwygEdit");
  }
};

/*************************************************************************
  */
$.NatEditor.prototype.switchToWYSIWYG = function(ev) {
  var self = this;

  if (typeof(self.tinyMCEInstance) !== 'undefined') {
    self.hideToolbar();
    tinyMCE.execCommand("mceToggleEditor", null, self.tinyMCEInstance.id);
    FoswikiTiny.switchToWYSIWYG(self.tinyMCEInstance);
  }
};

/*************************************************************************
 * init the toolbar
 */
$.NatEditor.prototype.initToolbar = function() {
  var self = this, 
      $txtarea = $(self.txtarea),
      url = foswiki.getScriptUrl('rest', "JQueryPlugin", "tmpl", {
       topic: self.opts.web+"."+self.opts.topic,
       load:  self.opts.toolbar
       });

  // load toolbar
  $.loadTemplate({
    url:url
  }).done(function(tmpl) {

    // init it
    self.toolbar = $(tmpl.render({
      web: self.opts.web,
      topic: self.opts.topic
    }));

    self.container.prepend(self.toolbar);

    // buttonsets
    self.toolbar.find(".ui-natedit-buttons").buttonset({}).on("click", function(ev) {
      self.handleToolbarAction(ev, $(ev.target).closest("a:not(.ui-natedit-menu-button)"));
      return false;
    });

    // a simple button
    self.toolbar.find(".ui-natedit-button").button().on("click", function(ev) {
      self.handleToolbarAction(ev, $(this));
      return false;
    });

    // a button with a menu next to it
    self.toolbar.find(".ui-natedit-menu-button").not(".ui-button").button().end()
      .button("option", {
        icons: {
          secondary: 'ui-icon-triangle-1-s'
        }
      })
      .on("mousedown", function(ev) {
        var $this = $(this),
          $menu = (typeof($this.data("menu")) === 'undefined') ? $this.next() : $(self.container.find($this.data("menu"))),
          state = $menu.data("state") || false;

        $menu.data("menu-button", this);
        self.hideMenus();

        if (!state) {
          $this.addClass("ui-state-highlight");
          $menu.show().position({
            my: "left top",
            at: "left bottom+10",
            of: $this
          });
          $menu.data("state", true);
        } else {
          $this.removeClass("ui-state-highlight");
        }

        return false;
      }).on("click", function() {
        return false;
      });

    // markup menus
    self.toolbar.find(".ui-natedit-menu").each(function() {
      var $menu =
        $(this),
        timer,
        enableSelect = false;

      $menu.menu().on("mouseleave", function() {
        timer = window.setTimeout(function() {
          //$menu.hide().data("state", false);
        }, 1000);

      }).on("mouseenter", function() {
        if (typeof(timer) !== 'undefined') {
          window.clearTimeout(timer);
          timer = undefined;
        }
      }).on("menuselect", function(ev, ui) {
        ev.target = $menu.data("menu-button"); // SMELL: patch in menu button that triggered this event
        if (enableSelect) {
          self.hideMenus();
          self.handleToolbarAction(ev, ui.item.children("a:first"));
        }
      }).children().on("mouseup", function(ev) {
        enableSelect = true;
        $menu.menu("select", ev);
        enableSelect = false;
      }).on("click", function() {
        return false;
      });
    });


    // close menus clicking the container 
    $(self.container).on("click", function() {
      self.hideMenus();
    });

    if (self.opts.autoHideToolbar) {
      //$.log("NATEDIT: toggling toolbar on hover event");
      self.toolbar.hide();

      $txtarea.focus(
        function() {
          window.setTimeout(function() {
            self.showToolbar();
          });
        }
      );
      $txtarea.blur(
        function() {
          window.setTimeout(function() {
            self.hideToolbar();
          });
        }
      );
    }

    // ask undo manager for gui changes
    self.undoManager.updateGui();

    // set trigger resize again as the toolbar changed its height
    $(window).trigger("resize");
  });
};

/*************************************************************************
  * show the toolbar, constructs it if it hasn't been initialized yet
  */
$.NatEditor.prototype.showToolbar = function() {
  var self = this, tmp;

  if (typeof(self.toolbar) === 'undefined') {
    self.initToolbar();
  }

  if (typeof(self.toolbar) === 'undefined') {
    return;
  }

  tmp = self.txtarea.value; 
  self.toolbar.show();
  self.txtarea.value = tmp;

  if (self.opts.autoMaxExpand) {
    $(window).trigger("resize");
  }
};

/*************************************************************************
  * hide the toolbar
  */
$.NatEditor.prototype.hideToolbar = function() {
  var self = this, tmp;

  if (!self.toolbar) {
    return;
  }

  tmp = self.txtarea.value;
  self.toolbar.hide();
  self.txtarea.value = tmp;

  if (self.opts.autoMaxExpand) {
    $(window).trigger("resize");
  }
};

/*************************************************************************
  * assert a specific permission rule
  */
$.NatEditor.prototype.setPermission = function(type, rules) {
  var self = this,
    key, val;

  self.form.find(".permset_" + type).each(function() {
    $(this).val("undefined");
  });

  for (key in rules) {
    if (rules.hasOwnProperty(key)) {
      val = rules[key];
      $.log("NATEDIT: setting ."+key+"_"+type+"="+val); 
      self.form.find("." + key + "_" + type).val(val);
    }
  }
};

/*************************************************************************
  * show the details ui on the permissions tab
  */
$.NatEditor.prototype.showPermDetails = function(type) {
  var self = this,
    names = [],
    val;

  self.form.find(".ui-natedit-"+type+"-perms .ui-natedit-details-container").slideDown(300);
  self.form.find("input[name='Local+PERMSET_" + type.toUpperCase() + "_DETAILS']").each(function() {
    val = $(this).val();
    if (val && val != '') {
      names.push(val);
    }
  });

  names = names.join(', ');
  $.log("NATEDIT: showPermDetails - names="+names);

  self.setPermission(type, {
    allow: names
  });
};

/*************************************************************************
  * hide the details ui on the permissions tab
  */
$.NatEditor.prototype.hidePermDetails = function(type) {
  var self = this;

  self.form.find(".ui-natedit-"+type+"-perms .ui-natedit-details-container").slideUp(300);
  self.setPermission(type);
};


/*************************************************************************
  * calls a notification systems, defaults to pnotify
  */
$.NatEditor.prototype.showMessage = function(type, msg, title) {
  var self =

  $.pnotify({
    title: title,
    text:msg,
    hide:(type === "error"?false:true),
    type:type,
    sticker:false,
    closer_hover:false,
    delay: (type === "error"?8000:1000)
  });
};

/*************************************************************************
  * hide all open error messages in the notification system
  */
$.NatEditor.prototype.hideMessages = function() {
  var self = this;

  $.pnotify_remove_all();
};

/*************************************************************************
  * hack to extract an error message from a foswiki non-json aware response :(
  */
$.NatEditor.prototype.extractErrorMessage = function(text) {
  var self = this;

  if (text && text.match(/^<!DOCTYPE/)) {
    text = $(text).find(".natErrorMessage").text().replace(/\s+/g, ' ').replace(/^\s+/, '') || '';
  }

  if (text === "error") {
    text = "Error: save failed. Please save your content locally and reload this page.";
  }

  return text;
};

/*************************************************************************
  * things to be done before the submit goes out
  */
$.NatEditor.prototype.beforeSubmit = function(editAction) {
  var self = this, topicParentField, actionValue;

  if (typeof(self.form) === 'undefined' || self.form.length === 0) {
    return;
  }

  topicParentField = self.form.find("input[name=topicparent]");
  actionValue = 'foobar';

  if (topicParentField.val() === "") {
    topicParentField.val("none"); // trick in unsetting the topic parent
  }

  if (editAction === 'addform') {
    self.form.find("input[name='submitChangeForm']").val(editAction);
  }

  // the action_... field must be set to a specific value in newer foswikis
  if (editAction === 'save') {
    actionValue = 'Save';
  } else if (editAction === 'cancel') {
    actionValue = 'Cancel';
  }

  self.form.find("input[name='action_preview']").val('');
  self.form.find("input[name='action_save']").val('');
  self.form.find("input[name='action_checkpoint']").val('');
  self.form.find("input[name='action_addform']").val('');
  self.form.find("input[name='action_replaceform']").val('');
  self.form.find("input[name='action_cancel']").val('');
  self.form.find("input[name='action_" + editAction + "']").val(actionValue);

  if (typeof(StrikeOne) !== 'undefined') {
    StrikeOne.submit(self.form[0]);
  }

  if (typeof(tinyMCE) !== 'undefined') {
    $.each(tinyMCE.editors, function(index, editor) { 
        editor.onSubmit.dispatch(); 
    }); 
  }

  self.form.trigger("beforeSubmit.natedit", self, editAction);
};

/*************************************************************************
 * init the form surrounding natedit 
 */
$.NatEditor.prototype.initForm = function() {
  var self = this, formRules;

  if (typeof(self.form) === 'undefined' || self.form.length === 0 || self.form.data("isInitialized")) {
    return;
  }

  self.form.data("isInitialized", true);

  /* remove the second TopicTitle */
  self.form.find("input[name='TopicTitle']:eq(1)").parents(".foswikiFormStep").remove();

  /* remove the second Summary */
  self.form.find("input[name='Summary']:eq(1)").parents(".foswikiFormStep").remove();

  /* save handler */
  self.form.find(".ui-natedit-save").on("click", function() {
    var $editCaptcha = $("#editcaptcha"),
      buttons,
      doIt = function() {
        self.beforeSubmit("save");
        document.title = "Saving ...";
        $.blockUI({
          message: '<h1> Saving ... </h1>'
        });
        self.form.submit();
      };

    if ($editCaptcha.length) {
      buttons = $editCaptcha.dialog("option", "buttons");
      buttons[0].click = function() {
        if ($editCaptcha.find(".jqCaptcha").data("captcha").validate()) {
          $editCaptcha.dialog("close");
          doIt();
        }
      };
      $editCaptcha.dialog("option", "buttons", buttons).dialog("open");
    } else {
      doIt();
    }
    return false;
  });

  /* save & continue handler */
  self.form.find(".ui-natedit-checkpoint").on("click", function(ev) {
    var topicName = self.opts.topic,
      origTitle = document.title,
      $editCaptcha = $("#editcaptcha"),
      buttons,
      doIt = function() {
        var editAction = $(ev.currentTarget).attr("href").replace(/^#/, "");

        if (self.form.validate().form()) {
          self.beforeSubmit(editAction);

          if (topicName.match(/AUTOINC|XXXXXXXXXX/)) { 
            // don't ajax when we don't know the resultant URL (can change this if the server tells it to us..)
            self.form.submit();
          } else {
            self.form.ajaxSubmit({
              url: foswiki.getScriptUrl( 'rest', 'NatEditPlugin', 'save'),  // SMELL: use this one for REST as long as the normal save can't cope with REST
              beforeSubmit: function() {
                self.hideMessages();
                document.title = "Saving ...";
                $.blockUI({
                  message: '<h1> Saving ... </h1>'
                });
              },
              error: function(xhr, textStatus, errorThrown) {
                var message = self.extractErrorMessage(xhr.responseText || textStatus);
                self.showMessage("error", message);
              },
              complete: function(xhr, textStatus) {
                var nonce = xhr.getResponseHeader('X-Foswiki-Validation');
                if (nonce) {
                  // patch in new nonce
                  $("input[name='validation_key']").each(function() {
                    $(this).val("?" + nonce);
                  });
                }
                document.title = origTitle;
                $.unblockUI();
              }
            });
          }
        }
      };

    if ($editCaptcha.length) {
      buttons = $editCaptcha.dialog("option", "buttons");
      buttons[0].click = function() {
        if ($editCaptcha.find(".jqCaptcha").data("captcha").validate()) {
          $editCaptcha.dialog("close");
          doIt();
        }
      };
      $editCaptcha.dialog("option", "buttons", buttons).dialog("open");
    } else {
      doIt();
    }

    return false;
  });

  /* preview handler */
  self.form.find(".ui-natedit-preview").on("click", function() {

    if (self.form.validate().form()) {
      self.beforeSubmit("preview");

      self.form.ajaxSubmit({
        url: foswiki.getScriptUrl( 'rest', 'NatEditPlugin', 'save'),  // SMELL: use this one for REST as long as the normal save can't cope with REST
        beforeSubmit: function() {
          self.hideMessages();
          $.blockUI({
            message: '<h1> Loading preview ... </h1>'
          });
        },
        error: function(xhr, textStatus, errorThrown) {
          var message = self.extractErrorMessage(xhr.responseText || textStatus);
          $.unblockUI();
          self.showMessage("error", message);
        },
        success: function(data, textStatus) {
          var $window = $(window),
            height = Math.round(parseInt($window.height() * 0.6, 10)),
            width = Math.round(parseInt($window.width() * 0.6, 10));

          $.unblockUI();

          if (width < 640) {
            width = 640;
          }

          data = data.replace(/%width%/g, width).replace(/%height%/g, height);
          $("body").append(data);
        }
      });
    }
    return false;
  });


  // TODO: only use this for foswiki engines < 1.20
  self.form.find(".ui-natedit-cancel").on("click", function() {
    self.hideMessages();
    $("label.error").hide();
    $("input.error").removeClass("error");
    $(".jqTabGroup a.error").removeClass("error");
    self.beforeSubmit("cancel");
    self.form.submit();
    return false;
  });

  self.form.find(".ui-natedit-replaceform").on("click", function() {
    self.beforeSubmit("replaceform");
    self.form.submit();
    return false;
  });

  self.form.find(".ui-natedit-addform").on("click", function() {
    self.beforeSubmit("addform");
    self.form.submit();
    return false;
  });

  /* add clientside form validation */
  formRules = $.extend({}, self.form.metadata({
    type: 'attr',
    name: 'validate'
  }));

  self.form.validate({
    meta: "validate",
    invalidHandler: function(e, validator) {
      var errors = validator.numberOfInvalids(),
        $form = $(validator.currentForm), message;

      /* ignore a cancel action */
      if ($form.find("input[name*='action_'][value='Cancel']").attr("name") == "action_cancel") {
        validator.currentForm.submit();
        validator.errorList = [];
        return;
      }

      if (errors) {
        message = errors == 1 ? 'There\'s an error. It has been highlighted below.' : 'There are ' + errors + ' errors. They have been highlighted below.';
        $.unblockUI();
        self.showMessage("error", message);
        $.each(validator.errorList, function() {
          var $errorElem = $(this.element);
          $errorElem.parents(".jqTab").each(function() {
            var id = $(this).attr("id");
            $("[data=" + id + "]").addClass("error");
          });
        });
      } else {
        self.hideMessages();
        $form.find(".jqTabGroup a.error").removeClass("error");
      }
    },
    rules: formRules,
    ignoreTitle: true,
    errorPlacement: function(error, element) {
      if (element.is("[type=checkbox],[type=radio]")) {
        // special placement if we are inside a table
        $("<td>").appendTo(element.parents("tr:first")).append(error);
      } else {
        // default
        error.insertAfter(element);
      }
    }
  });

  $.validator.addClassRules("foswikiMandatory", {
    required: true
  });

};

/*************************************************************************
 * handles selection of menu item or click of a button in the toolbar
 */
$.NatEditor.prototype.handleToolbarAction = function(ev, ui) {
  var self = this, 
      itemData, 
      dialogData,
      okayHandler = function() {},
      cancelHandler = function() {},
      openHandler = function() {},
      optsHandler = function() {
        return {
          web: self.opts.web,
          topic: self.opts.topic,
          selection: self.getSelection()
        };
      };

  if (typeof(ui) ==='undefined' || ui.length === 0) {
    return;
  }

  // get inline opts
  itemData = ui.data();

  //$.log("handleToolbarAction data=",itemData)

  // insert markup mode
  if (typeof(itemData.markup) !== 'undefined') {
    itemData.value = self.opts[itemData.markup];
  }

  // insert markup by value 
  if (typeof(itemData.value) !== 'undefined') {
    if (itemData.type === 'line') {
      self.insertLineTag(itemData.value);
    } else {
      self.insertTag(itemData.value);
    }
  }

  // dialog mode
  if (typeof(itemData.dialog) !== 'undefined') {

    if (typeof(itemData.okayHandler) !== 'undefined' && typeof(self[itemData.okayHandler]) === 'function') {
      okayHandler = self[itemData.okayHandler];
    }

    if (typeof(itemData.cancelHandler) !== 'undefined' && typeof(self[itemData.cancelHandler]) === 'function') {
      cancelHandler = self[itemData.cancelHandler];
    }

    if (typeof(itemData.openHandler) !== 'undefined' && typeof(self[itemData.openHandler]) === 'function') {
      openHandler = self[itemData.openHandler];
    }

    if (typeof(itemData.optsHandler) !== 'undefined' && typeof(self[itemData.optsHandler]) === 'function') {
      optsHandler = self[itemData.optsHandler];
    }

    dialogData = optsHandler.call(self);

    self.dialog({
      name: itemData.dialog,
      open: function(elem) {
        openHandler.call(self, elem, dialogData);
      },
      data: dialogData,
      event: ev,
      modal: itemData.modal,
      okayText: itemData.okayText,
      cancelText: itemData.cancelText
    }).then(function(dialog) {
        okayHandler.call(self, dialog);
      }, function(dialog) {
        cancelHandler.call(self, dialog);
      }
    );
  }

  // method mode 
  if (typeof(itemData.handler) !== 'undefined' && typeof(self[itemData.handler]) === 'function') {
    //$.log("found handler in toolbar action",itemData.handler);
    self[itemData.handler].call(self, ev, ui);
    return;
  }

  //$.log("NATEDIT: no action for ",ui);
};

/*************************************************************************
 * close all open menus
*/
$.NatEditor.prototype.hideMenus = function() {
  var self = this;

  self.container.find(".ui-natedit-menu").each(function() {
    var $this = $(this),
        $button = $($this.data("menu-button"));

    $button.removeClass("ui-state-highlight");
    $this.hide().data("state", false);
  });
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
  self.undoManager.saveState("command");
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
  self.undoManager.saveState("command");

  return selection;
};

/*************************************************************************
 * compatibility method for IE: this sets txtarea.selectionStart and
 * txtarea.selectionEnd of the current selection in the given textarea 
 */
$.NatEditor.prototype.getSelectionRange = function() {
  var self = this, text, c, range, rangeCopy, pos, selection;

  //$.log("NATEDIT: called getSelectionRange()");
  //$(self.txtarea).focus();

  if (self.oldIE) {

    text = self.txtarea.value;
    c = "\x01";
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
  * returns the currently selected lines
  */
$.NatEditor.prototype.getSelectionLines = function() {
  var self = this, start, end, text;

  self.getSelectionRange();
  start = self.txtarea.selectionStart;
  end = self.txtarea.selectionEnd;
  text = self.txtarea.value;

  while (start > 0 && text.charCodeAt(start-1) != 13 && text.charCodeAt(start-1) != 10) {
    start--;
  }

  while (end < text.length && text.charCodeAt(end) != 13 && text.charCodeAt(end) != 10) {
    end++;
  }

  //$.log("start=",start,"end=",end);

  self.setSelectionRange(start, end);

  return text.substring(start, end);
};

/*************************************************************************
 * set the selection
 */
$.NatEditor.prototype.setSelectionRange = function(start, end) {
  var self = this, lineFeeds, range;

  //$.log("setSelectionRange("+self.txtarea+", "+start+", "+end+")");

  //$(self.txtarea).focus();
  if (typeof(self.txtarea.createTextRange) !== 'undefined' && !$.browser.opera) {
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
  var self = this;

  $.log("NATEDIT: setCaretPosition("+caretPos+")");
  self.setSelectionRange(caretPos, caretPos);
};

/*************************************************************************
 * get the caret position 
 */
$.NatEditor.prototype.getCaretPosition = function() {
  var self = this;

  this.getSelectionRange();

  return self.txtarea.selectionEnd;
};
 
 
/*************************************************************************
 * used for line oriented tags - like bulleted lists
 * if you have a multiline selection, the tagOpen/tagClose is added to each line
 * if there is no selection, select the entire current line
 * if there is a selection, select the entire line for each line selected
 */
$.NatEditor.prototype.insertLineTag = function(markup) {
  var self = this, 
      tagOpen = markup[0],
      sampleText = markup[1],
      tagClose = markup[2],
      startPos, endPos, 
      text, scrollTop, theSelection, 
      pre, post, lines, modifiedSelection,
      i, line, subst, 
      listRegExp = new RegExp(/^(( {3})*)( {3})(\* |\d+ |\d+\. )/),
      nrSpaces = 0;

  //$.log("called insertLineTag(..., ",markup,")");

  theSelection = self.getSelectionLines();
  startPos = self.txtarea.selectionStart;
  endPos = self.txtarea.selectionEnd;
  text = self.txtarea.value;

  scrollTop = self.txtarea.scrollTop;

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

  self.txtarea.value = pre + modifiedSelection + post;

  if (lines.length == 1) {
    startPos += nrSpaces + tagOpen.length;
    endPos = startPos + modifiedSelection.length - tagOpen.length - tagClose.length - nrSpaces;
  } else {
    endPos = nrSpaces + startPos + modifiedSelection.length + 1;
  }

  //$.log("finally, startPos="+startPos+" endPos="+endPos);

  self.setSelectionRange(startPos, endPos);
  self.txtarea.scrollTop = scrollTop;
  
  self.undoManager.saveState("command");
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
  theSelection = text.substring(startPos, endPos) || sampleText;

  //$.log("startPos="+startPos+" endPos="+endPos);

  subst = tagOpen + theSelection.replace(/(\s*)$/, tagClose + "$1");

  self.txtarea.value =  
    text.substring(0, startPos) + subst +
    text.substring(endPos, text.length);

  // set new selection
  startPos += tagOpen.length;
  endPos = startPos + theSelection.replace(/\s*$/, "").length;

  self.txtarea.scrollTop = scrollTop;
  self.setSelectionRange(startPos, endPos);

  self.undoManager.saveState("command");
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

    if (opts.file.match(/\.(bmp|png|jpe?g|gif|svg)$/i) && foswiki.getPreference("NatEditPlugin").ImagePluginEnabled) {
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
      } else {
        markup += "["+opts.file+"]";
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

/*****************************************************************************
 * handler for escape tml 
 */
$.NatEditor.prototype.handleEscapeTML = function(ev, elem) {
  var self = this, 
      selection = self.getSelection() || '';

  selection = self.escapeTML(selection);

  self.remove();
  self.insertTag(['', selection, '']);
};

/*****************************************************************************
 * handler for unescape tml 
 */
$.NatEditor.prototype.handleUnescapeTML = function(ev, elem) {
  var self = this, 
      selection = self.getSelection() || '';

  selection = self.unescapeTML(selection);

  self.remove();
  self.insertTag(['', selection, '']);
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

// SMELL: below aren't supported by all plugins; they don't play a role in TML parsing anyway

//  text = text.replace(/&/g, '$amp');
//  text = text.replace(/>/g, '$gt');
//  text = text.replace(/</g, '$lt');
//  text = text.replace(/,/g, '$comma');

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
  }); 
};

/*************************************************************************
 * adjust height of textarea to window height
 */
$.NatEditor.prototype.fixHeight = function() {
  var self = this,
    elem,
    windowHeight = $(window).height() || window.innerHeight,
    tmceEdContainer = (typeof(tinyMCE) !== 'undefined' && tinyMCE.activeEditor)?$(tinyMCE.activeEditor.contentAreaContainer):null,
    newHeight,
    $debug = $("#DEBUG");

  if (typeof(self.bottomHeight) === 'undefined') {
    self.bottomHeight = $('.natEditBottomBar').outerHeight(true) + parseInt($('.jqTabContents').css('padding-bottom'), 10) * 2 + 2; 
  }

  if (tmceEdContainer && !tinyMCE.activeEditor.getParam('fullscreen_is_enabled') && tmceEdContainer.is(":visible")) {
    /* resize tinyMCE. */
    tmceEdContainer.closest(".mceLayout").height('auto'); // remove local height properties
    elem = tmceEdContainer.children('iframe');

  } else {
    /* resize textarea. */
    elem = $(self.txtarea);
  }

  newHeight = windowHeight - elem.offset().top - self.bottomHeight - parseInt(elem.css('padding-bottom'), 10) *2 - 2;

  if ($debug.length) {
    newHeight -= $debug.height();
  }

  if (self.opts.minHeight && newHeight < self.opts.minHeight) {
    newHeight = self.opts.minHeight;
  }

  if (newHeight < 0) {
    return;
  }

  if (elem.is(":visible")) {
    $.log("NATEDIT: fixHeight height=",newHeight);
    elem.height(newHeight);
  } else {
    $.log("NATEDIT: not fixHeight elem not yet visible");
  }
};

/*************************************************************************
 * adjust height of textarea according to content
 */
$.NatEditor.prototype.autoResize = function() {
  var self = this, 
      $txtarea = $(self.txtarea),
      now, text, height;

  //$.log("NATEDIT: called autoResize()");
  now = new Date();
  
  // don't do it too often
  if (self._time && now.getTime() - self._time.getTime() < 100) {
    //$.log("NATEDIT: suppressing events within 100ms");
    return;
  }
  self._time = now;

  window.setTimeout(function() {
    text = $txtarea.val()+"\n";

    if (text == self._lastText) {
      //$.log("NATEDIT: suppressing events");
      return;
    }

    self._lastText = text;
    text = self.htmlEntities(text);

    //$.log("NATEDIT: helper text="+text);
    self.helper.width($txtarea.width()).val(text);

    //height = self.helper.height() + 12;
    self.helper.scrollTop(9e4);
    height = self.helper.scrollTop();

    if (self.opts.minHeight && height < self.opts.minHeight) {
      height = self.opts.minHeight;
    } 

    if (self.opts.maxHeight && height > self.opts.maxHeight) {
      height = self.opts.maxHeight;
      $txtarea.css('overflow-y', 'scroll');
    } else {
      $txtarea.css('overflow-y', 'hidden');
    }

    //$.log("NATEDIT: setting height=",height);

    $txtarea.height(height);
  });
};

/*************************************************************************
 * replace entities with real html
 */
$.NatEditor.prototype.htmlEntities = function(text) { 
  var entities = {
    '&':'&amp;',
    '<':'&lt;',
    '>':'&gt;',
    '"':'&quot;'
  }, i;

  for(i in entities) {
    if (entities.hasOwnProperty(i)) {
      text = text.replace(new RegExp(i,'g'),entities[i]);
    }
  }
  return text;
};

/*****************************************************************************
 * opens a dialog based on a jquery template
 */
$.NatEditor.prototype.dialog = function(opts) {
  var self = this,
    defaults = {
      url: undefined,
      title: "Confirmation required",
      okayText: "Ok",
      okayIcon: "ui-icon-check",
      cancelText: "Cancel",
      cancelIcon: "ui-icon-cancel",
      width: 'auto',
      modal: true,
      position: {
        my:'center', 
        at:'center',
        of: window
      },
      open: function() {},
      data: {
        web: self.opts.web,
        topic: self.opts.topic,
        selection: self.getSelection()
      }
    };

  if (typeof(opts) === 'string') {
    opts = {
      data: {
        text: opts
      }
    };
  }

  if (typeof(opts.url) === 'undefined' && typeof(opts.name) !== 'undefined') {
    opts.url = foswiki.getScriptUrl( 'rest', 'JQueryPlugin', 'tmpl', {
        topic: self.opts.web+"."+self.opts.topic,
        load:  'editdialog',
        name:  opts.name
    });

  }

  opts = $.extend({}, defaults, opts);

  if (typeof(opts.event) !== 'undefined') {
    opts.position = {
      my: 'center top',
      at: 'left bottom+30',
      of: opts.event.target
    };
  }

  self.hideMessages();
  return $.Deferred(function(dfd) {
    $.loadTemplate({
      url:opts.url,
      name:opts.name
    }).then(function(tmpl) {
      $(tmpl.render(opts.data)).dialog({
        buttons: [{
          text: opts.okayText,
          icons: {
            primary: opts.okayIcon
          },
          click: function() {
            $(this).dialog("close");
            dfd.resolve(this);
            return true;
          }
        }, {
          text: opts.cancelText,
          icons: {
            primary: opts.cancelIcon
          },
          click: function() {
            $(this).dialog("close");
            dfd.reject();
            return false;
          }
        }],
        open: function(ev) {
          var $this = $(this), 
              title = $this.data("title");

          if (typeof(title) !== 'undefined') {
            $this.dialog("option", "title", title);
          }

          $this.find("input").on("keydown", function(ev) {
            var $input = $(this);
            if (!$input.is(".ui-autocomplete-input") || !$input.data("ui-autocomplete").menu.element.is(":visible")) {
              if (ev.keyCode == 13) {
                ev.preventDefault();
                $this.dialog("close");
                dfd.resolve($this[0]);
              }
            }
          });

          opts.open.call(self, this, opts.data);
        },
        close: function(event, ui) {
          $(this).remove();
        },
        show: 'fade',
        modal: opts.modal,
        draggable: true,
        resizable: false,
        title: opts.title,
        width: opts.width,
        position: opts.position
      });
    }, function(xhr) {
      self.showMessage("error", xhr.responseText);
    });
  }).promise();
};

/*****************************************************************************
 * handler for the search&replace dialog
 */
$.NatEditor.prototype.handleSearchReplace = function(elem) {
  var self = this,
      $dialog = $(elem),
      search = $dialog.find("input[name='search']").val(),
      replace = $dialog.find("input[name='replace']").val(),
      ignoreCase = $dialog.find("input[name='ignorecase']:checked").length?true:false,
      count;

  $.log("NATEDIT: handleSearchReplace, search='"+search+" 'replace='"+replace+"' ignoreCase=",ignoreCase);

  if (search.length) {
    count = self.searchReplace(search, replace, ignoreCase);
    if (count) {
      self.showMessage("info", "replaced '"+search+"' "+count+" times");
    } else {
      self.showMessage("warning", "search string '"+search+"' not found");
    }
  }
};

/*****************************************************************************
 * search & replace a term in the textarea
 */
$.NatEditor.prototype.searchReplace = function(search, replace, ignoreCase) {
  var self = this,
    scrollTop = self.txtarea.scrollTop,
    caretPos = self.getCaretPosition(),
    text = self.txtarea.value,
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

  //$.log("NATEDIT: result=",text);
  $.log("NATEDIT: count=", count);
  if (count) {
    self.txtarea.value = text;
    //$.log("caretPos=",caretPos,"scrollTop=",scrollTop);
    self.setCaretPosition(caretPos);
    self.txtarea.scrollTop = scrollTop;

    if (self.opts.autoMaxExpand) {
      $(window).trigger("resize");
    }
    self.undoManager.saveState("command");
  }
  
  return count;
};


/*****************************************************************************
 * handler for the insert table dialog
 */
$.NatEditor.prototype.handleInsertTable = function(elem) {
  var self = this,
    $dialog = $(elem),
    rows = $dialog.find("input[name='rows']").val(),
    cols = $dialog.find("input[name='cols']").val(),
    heads = $dialog.find("input[name='heads']").val(),
    editable = $dialog.find("input[name='editable']:checked").val() === 'true' ? true : false;

  return self.insertTable({
    heads: heads,
    rows: rows,
    cols: cols,
    editable: editable
  });
};

/*****************************************************************************
  * handler for the insert link dialog
  */
$.NatEditor.prototype.handleInsertLink = function(elem) {
  var self = this,
    $dialog = $(elem),
    opts = {},
    $currentTab = $dialog.find(".jqTab.current");
 
  //$.log("called openInsertTable()", $dialog);

  if ($currentTab.is(".topic")) {
    opts = {
      web: $currentTab.find("input[name='web']").val(),
      topic: $currentTab.find("input[name='topic']").val(),
      text: $dialog.find("input[name='linktext_topic']").val()
    };
  } else if ($currentTab.is(".external")) {
    opts = {
      url: $currentTab.find("input[name='url']").val(),
      text: $dialog.find("input[name='linktext_external']").val()
    };
  } else {
    return;
  }

  //$.log("opts=",opts);
  return self.insertLink(opts);
};

/*****************************************************************************
  * handler for the insert attachment dialog
  */
$.NatEditor.prototype.handleInsertAttachment = function(elem) {
  var self = this, $dialog = $(elem);
 
  return self.insertLink({
    web: $dialog.find("input[name='web']").val(),
    topic: $dialog.find("input[name='topic']").val(),
    file: $dialog.find("input[name='file']").val(),
    text: $dialog.find("input[name='linktext_attachment']").val()
  });
};

/*****************************************************************************
 * init the color dialog
 */
$.NatEditor.prototype.initColorDialog = function(elem, data) {
  var self = this,
      $dialog = $(elem),
      color = self.getSelection(),
      inputField = $dialog.find("input[name='color']")[0];

  self.fb = $.farbtastic($dialog.find(".ui-natedit-colorpicker")).setColor("#fafafa").linkTo(inputField);

  return false;
};

/*****************************************************************************
 * parse selection for color code
 */
$.NatEditor.prototype.parseColorSelection = function() {
  var self = this,
      selection = self.getSelection() || '#ff0000';

  return {
    web: self.opts.web,
    topic: self.opts.topic,
    selection: selection
  };
};

/*****************************************************************************
 * init the date dialog
 */
$.NatEditor.prototype.openDatePicker = function(ev, ui) {
  var self = this,
      elem,
      date,
      selection = self.getSelection();

  if (selection === '') {
    date = new Date();
  } else {
    try {
      date = new Date(selection)
    } catch (e) {
      self.showMessage("error", "invalid date '"+selection+"'");
    };
  }

  if (typeof(self.datePicker) === 'undefined') {
      elem = $('<div class="ui-natedit-datepicker"/>').css("position", "absolute").appendTo("body").hide();

    self.overlay = $("<div>")
      .addClass("ui-widget-overlay ui-front")
      .hide()
      .appendTo("body")
      .on("click", function() {
        self.datePicker.hide();
        self.overlay.hide();
      });

    self.datePicker = elem.datepicker({
        onSelect: function() {
         var date = self.datePicker.datepicker("getDate");
          self.datePicker.hide();
          self.overlay.hide();
          self.remove();
          self.insertTag(['', self.formatDate(date), '']);
        }
    }).draggable({handle:'.ui-widget-header'}).zIndex(self.overlay.zIndex()+1);

  }

  self.overlay.show();
  self.datePicker.datepicker("setDate", date);
    
  self.datePicker.show().focus().position({my:'center', at:'center', of:window});

  return false;
};

/*****************************************************************************
 * format a date the foswiki way
 */
$.NatEditor.prototype.formatDate = function(date) {
  var self = this,

  // TODO: make it smarter
  date = date.toDateString().split(/ /);
  return date[2]+' '+date[1]+' '+date[3];
};

/*****************************************************************************
 * inserts the color code
 */
$.NatEditor.prototype.handleInsertColor = function(elem) {
  var self = this, 
      color = self.fb.color;

  self.remove();
  self.insertTag(['', color, '']);
};

/*************************************************************************/
$.NatEditor.prototype.handleUndo = function(elem) {
  var self = this;

  self.undoManager.undo();
};

/*************************************************************************/
$.NatEditor.prototype.handleRedo = function(elem) {
  var self = this;

  self.undoManager.redo();
};

/*****************************************************************************
 * sort selection 
 */
$.NatEditor.prototype.handleSortAscending = function(ev, elem) {
  var self = this;
  self.sortSelection("asc");
};

$.NatEditor.prototype.handleSortDescending = function(ev, elem) {
  var self = this;
  self.sortSelection("desc");
};

$.NatEditor.prototype.sortSelection = function(dir) {
  var self = this,
    selection, lines, ignored, isNumeric = true, value,
    line, prefix, i, beforeSelection = "", afterSelection = "";

  //$.log("NATEDIT: sortSelection ", dir);

  selection = self.getSelectionLines().split(/\r?\n/);

  lines = [];
  ignored = [];
  for (i = 0; i < selection.length; i++) {
    line = selection[i];
    // SMELL: sorting lists needs a real list parser
    if (line.match(/^((?: {3})+(?:[AaIi]\.|\d\.?|\*) | *\|)(.*)$/)) {
      prefix = RegExp.$1;
      line = RegExp.$2;
    } else {
      prefix = "";
    }

    value = parseFloat(line);
    if (isNaN(value)) {
      isNumeric = false;
      value = line;
    }

    if (line.match(/^\s*$/)) {
      ignored.push({
        pos: i,
        prefix: prefix,
        value: value,
        line: line
      });
    } else {
      lines.push({
        pos: i,
        prefix: prefix,
        line: line,
        value: value
      });
    }
  }

  $.log("NATEDIT: isNumeric=",isNumeric);
  $.log("NATEDIT: sorting lines",lines);

  lines = lines.sort(function(a, b) {
    var valA = a.value, valB = b.value;

    if (isNumeric) {
      return valA - valB;
    } else {
      return valA < valB ? -1 : valA > valB ? 1: 0;
    }
  });

  if (dir == "desc") {
    lines = lines.reverse();
  }

  $.map(ignored, function(item) {
    lines.splice(item.pos, 0, item);
  });

  selection = [];
  $.map(lines, function(item) {
    selection.push(item.prefix+item.line);
  });
  selection = selection.join("\n");

  $.log("NATEDIT: result=\n'"+selection+"'");

  self.remove();
  self.insertTag(['', selection, '']);
};

/*****************************************************************************
  * init the link dialog 
  */
$.NatEditor.prototype.initLinkDialog = function(elem, data) {
  var self = this,
      $dialog = $(elem), tabId,
      xhr, requestIndex = 0,
      $thumbnail = $dialog.find(".ui-natedit-attachment-thumbnail"),
      $container = $dialog.find(".jqTab.current");

  if ($container.length === 0) {
    $container = $dialog;
  }

  $dialog.find("input[name='web']").each(function() {
    $(this).autocomplete({
      source: foswiki.getScriptUrl('view', self.opts.systemWeb, 'JQueryAjaxHelper', {
         section:     'web',
         skin:        'text',
         contenttype: 'application/json'
      })
    });
  });

  $dialog.find("input[name='topic']").each(function() {
      $(this).autocomplete({
      source: function(request, response) {
        if (xhr) {
          xhr.abort();
        }
        xhr = $.ajax({
          url: foswiki.getScriptUrl('view', self.opts.systemWeb, 'JQueryAjaxHelper'),
          data: $.extend(request, {
            section: 'topic',
            skin: 'text',
            contenttype: 'application/json',
            baseweb: $container.find("input[name='web']").val()
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
  });

  // attachments autocomplete ... TODO: rename css class
  $dialog.find(".natEditAttachmentSelector").each(function() {
    $(this).autocomplete({
      source: function(request, response) {

        if (xhr) {
          xhr.abort();
        }
        xhr = $.ajax({
          url: foswiki.getScriptUrl('rest', 'NatEditPlugin', 'attachments'),
          data: $.extend(request, {
            // The topic autocomplete actually returns the Web.Topic
            topic: $container.find("input[name='topic']").val()
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
        if ($thumbnail.length) {
          $thumbnail.attr("src", ui.item.img).show();
        }
      },
      change: function(ev, ui) {
        if ($thumbnail.length) {
          if (ui.item) {
            $thumbnail.attr("src", ui.item.img).show();
          } else {
            $thumbnail.hide();
          }
        }
      }
    }).data("ui-autocomplete")._renderItem = function(ul, item) {
      if (typeof(item.label) !== "undefined") {
        return $("<li></li>")
          .data("item.autocomplete", item)
          .append("<a><table width='100%'><tr>"+(typeof(item.img) !== 'undefined' ? "<td width='60px'><img width='50' src='"+item.img+"' /></td>":"")+"<td>"+item.label+"<br />"+item.comment+"</td></tr></table></a>")
          .appendTo(ul);
      }
    };
  });

  if (typeof(data.type) !== 'undefined') {
    tabId = $dialog.find(".jqTab."+data.type).attr("id");
    if (typeof(tabId) !== 'undefined') {
      window.setTimeout(function() {
        window.location.hash = "!" + tabId;
      });
    }
  }
};

/*****************************************************************************
  * init the attachments dialog 
  */
$.NatEditor.prototype.initAttachmentsDialog = function(elem, data) {
  var self = this,
      $dialog = $(elem);

  $.log("NATEDIT: initAttachmentsDialog on elem=",elem);

  self.initLinkDialog(elem, data);

  $dialog.on("dialogclose", function() {
    self.hideMessages();
  });

  $dialog.find(".ui-natedit-uploader").each(function() {
    var $input = $dialog.find("input[name='file']"),
        $browseButton = $dialog.find(".ui-natedit-uploader-button"),
        $cancelButton = $dialog.find(".ui-natedit-uploader-cancel"),
        gotError = false;

    self.uploader = $(this).uploader({
      dragdrop: false,
      multi_selection: false,
      autoStart: true,
      browseButton: ".ui-natedit-uploader-button",
      stopButton: ".ui-natedit-uploader-cancel"
    }).data("uploader");

    self.uploader.bind("StateChanged", function() {
      var file = self.uploader.files[0];

      if (self.uploader.state == plupload.STARTED) {
        $.log("started upload");
        $input.attr("disabled", "disabled").val("uploading ...");
        $browseButton.hide();
        $cancelButton.show();
        self.hideMessages();
      } 

      if (self.uploader.state == plupload.STOPPED) {
        $.log("upload stopped");
        if (gotError || typeof(file) === 'undefined' || file.percent != 100) {
          $input.val("abording transfer ...");
          window.setTimeout(function() {
            $input.removeAttr("disabled").val("").focus();
          }, 1000);
        } else {
          $input.removeAttr("disabled").val(file.name).focus();
        }
        $browseButton.show();
        $cancelButton.hide();
      }
    });

    self.uploader.bind("Error", function(up, err) {
      var msg, 
          response = $.parseJSON(err.response);

      gotError = true;

      if (typeof(response.error) !== 'undefined') {
        msg = response.error.message;
      } else {
        msg = err;
      }

      self.showMessage("error", msg, "Error during upload");
    });

    self.uploader.bind("UploadProgress", function(up, file) {
      //$.log("upload progress percent=",file.percent);
      if (gotError || typeof(file) === 'undefined') {
        $input.val("error ...");
      } else if (file.percent == 100) {
        $input.val("finishing upload ...");
      } else {
        $input.val("uploading ... "+file.percent+"%");
      }
    });
  });
};

/*****************************************************************************
  * cancel the attachments dialog; abords any upload in progress
  */
$.NatEditor.prototype.cancelAttachmentsDialog = function(elem, data) {
  var self = this,
      $dialog = $(elem);

  $.log("NATEDIT: cancelAttachmentsDialog on elem=",elem);

  if (typeof(self.uploader) !== 'undefined') {
    $.log("stopping uploader");
    self.uploader.trigger("Stop");
  } else {
    $.log("no uploader found");
  }
};

/*****************************************************************************
 * parse the current selection and return the data to be used generating the tmpl
 */
$.NatEditor.prototype.parseLinkSelection = function() {
  var self = this,
      selection = self.getSelection(),
      web = self.opts.web,
      topic = self.opts.topic,
      file = '',
      url = '',
      type = 'topic',
      urlRegExp = "(?:file|ftp|gopher|https?|irc|mailto|news|nntp|telnet|webdav|sip|edit)://[^\\s]+?";

  // initialize from selection
  if (selection.match(/\s*\[\[(.*?)\]\]\s*/)) {
    selection = RegExp.$1;
    //$.log("brackets link, selection=",selection);
    if (selection.match("^("+urlRegExp+")(?:\\]\\[(.*))?$")) {
      //$.log("external link");
      url = RegExp.$1;
      selection = RegExp.$2 || '';
      type = 'external';
    } else if (selection.match(/^(?:%ATTACHURL(?:PATH)?%\/)(.*?)(?:\]\[(.*))?$/)) {
      //$.log("this attachment link");     
      file = RegExp.$1;
      selection = RegExp.$2;
      type = "attachment";
    } else if (selection.match(/^(?:%PUBURL(?:PATH)?%\/)(.*)\/(.*?)\/(.*?)(?:\]\[(.*))?$/)) {
      //$.log("other topic attachment link");     
      web = RegExp.$1;
      topic = RegExp.$2;
      file = RegExp.$3;
      selection = RegExp.$4;
      type = "attachment";
    } else if (selection.match(/^(?:(.*)\.)?(.*?)(?:\]\[(.*))?$/)) {
      //$.log("topic link");
      web = RegExp.$1 || web;
      topic = RegExp.$2;
      selection = RegExp.$3 || '';
    } else {
      //$.log("some link");
      topic = selection;
      selection = '';
    }
  } else if (selection.match("^ *"+urlRegExp)) {
    //$.log("no brackets external link");
    url = selection;
    selection = "";
    type = "external";
  } else if (selection.match(/^\s*%IMAGE\{"(.*?)"(?:.*?topic="(?:([^\s\.]+)\.)?(.*?)")?.*?\}%\s*$/)) {
    // SMELL: nukes custom params
    //$.log("image link");
    web = RegExp.$2 || web;
    topic = RegExp.$3 || topic;
    file = RegExp.$1;
    selection = "";
    type = "attachment";
  } else {
    if (selection.match(/^\s*([A-Z][^\s\.]*)\.(A-Z.*?)\s*$/)) {
      //$.log("topic link");
      web = RegExp.$1 || web;
      topic = RegExp.$2;
      selection = '';
      type = "topic";
    } else {
      //$.log("some selection, not a link");
    }
  }
  //$.log("after: selection=",selection, ", url=",url, ", web=",web,", topic=",topic,", file=",file,", initialTab=", initialTab);
  //
  return {
    selection: selection,
    web: web,
    topic: topic,
    file: file,
    url: url,
    type: type
  };
};

/***************************************************************************
 * plugin defaults
 */
$.NatEditor.defaults = {

  // toolbar template
  toolbar: "edittoolbar",

  // Elements 0 and 2 are (respectively) prepended and appended.  Element 1 is the default text to use,
  // if no text is currently selected.

  h1Markup: ['---+!! ','%TOPIC%',''],
  h2Markup: ['---++ ','Headline text',''],
  h3Markup: ['---+++ ','Headline text',''],
  h4Markup: ['---++++ ','Headline text',''],
  h5Markup: ['---+++++ ','Headline text',''],
  h6Markup: ['---++++++ ','Headline text',''],
  verbatimMarkup: ['<verbatim>\n','Insert non-formatted text here','\n</verbatim>'],
  quoteMarkup: ['<blockquote>\n','Insert quote here','\n</blockquote>'],
  boldMarkup: ['*', 'Bold text', '*'],
  italicMarkup: ['_', 'Italic text', '_'],
  monoMarkup: ['=', 'Monospace text', '='],
  underlineMarkup: ['<u>', 'Underlined text', '</u>'],
  strikeMarkup: ['<del>', 'Strike through text', '</del>'],
  superscriptMarkup: ['<sup>', 'superscript text', '</sup>'],
  subscriptMarkup: ['<sub>', 'subscript text', '</sub>'],
  leftMarkup: ['<p align="left">\n','Align left','\n</p>'],
  centerMarkup: ['<p align="center">\n','Center text','\n</p>'],
  rightMarkup: ['<p align="right">\n','Align right','\n</p>'],
  justifyMarkup: ['<p align="justify">\n','Justify text','\n</p>'],
  numberedListMarkup: ['   1 ','enumerated item',''],
  bulletListMarkup: ['   * ','bullet item',''],
  indentMarkup: ['   ','',''],
  outdentMarkup: ['','',''],
  mathMarkup: ['<latex title="Example">\n','\\sum_{x=1}^{n}\\frac{1}{x}','\n</latex>'],
  signatureMarkup: ['-- ', '[[%WIKINAME%]], ' - '%DATE%'],
  dataFormMarkup: ['', '| *Name*  | *Type* | *Size* | *Values* | *Description* | *Attributes* | *Default* |', '\n'],
  horizRulerMarkup: ['', '---', '\n'],
  autoHideToolbar: false,
  autoMaxExpand:false,
  minHeight:0,
  maxHeight:0,
  autoResize:false,
  resizable:false,

  showToolbar: true
};

/*****************************************************************************
 * register to jquery 
 */
$.fn.natedit = function(opts) {
  //$.log("NATEDIT: called natedit()");

  // build main options before element iteration
  var thisOpts = $.extend({}, $.NatEditor.defaults, opts);

  if (this.is(".foswikiWysiwygEdit") && typeof(tinyMCE) !== 'undefined') {
    thisOpts.showToolbar = false;
  }

  return this.each(function() {
    if (!$.data(this, "natedit")) {
      $.data(this, "natedit", new $.NatEditor(this, thisOpts));
    }
  });
};

/*****************************************************************************
 * initializer called on dom ready
 */
$(function() {

  $.NatEditor.defaults.web = foswiki.getPreference("WEB");
  $.NatEditor.defaults.topic = foswiki.getPreference("TOPIC");
  $.NatEditor.defaults.systemWeb = foswiki.getPreference("SYSTEMWEB");
  $.NatEditor.defaults.scriptUrl = foswiki.getPreference("SCRIPTURL");
  $.NatEditor.defaults.pubUrl = foswiki.getPreference("PUBURL");
  $.NatEditor.defaults.signatureMarkup = ['-- ', '[['+foswiki.getPreference("WIKIUSERNAME")+']]', ' - '+foswiki.getPreference("SERVERTIME")];

  // listen for natedit
  $(".natedit").livequery(function() {
    $(this).natedit();
  });

});

})(jQuery);
