/*
 * class UndoManager
 *
 * Copyright (c) 2008-2016 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
'use strict';

/* export */
var UndoManager;

(function($) {
/*****************************************************************************
 * constructor
 */
UndoManager = function(engine) {
  var self = this;

  self.engine = engine;
  self.shell = engine.shell;
  self.undoBuf = [];
  self.undoPtr = -1;
  self.mode = "none";

  $(self.shell.txtarea).on("keydown keyup", function(ev) {
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
    undoButton = self.shell.container.find(".ui-natedit-undo"),
    redoButton = self.shell.container.find(".ui-natedit-redo");

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

    if (currentState.value == self.shell.txtarea.value 
        || (mode != "none" && mode == self.mode)
        || (mode === "whitespace" && self.mode === "typing")) {
      // reuse the current state if it is just a move operation
      $.log("UNDOMANAGER: reuse current state in mode=",mode);
      self.mode = mode;
      currentState.init();
      return;
    }
  }

  $.log("UNDOMANAGER: mode=",mode);
  self.mode = mode;

  self.undoPtr++;
  $.log("UNDOMANAGER: save state at undoPtr=",self.undoPtr);

  currentState = new TextareaState(self.engine);
  self.undoBuf[self.undoPtr] = currentState;
  self.undoBuf[self.undoPtr+1] = undefined;

  self.updateGui();
};

UndoManager.prototype.undo = function() {
  var self = this;

  $.log("UNDOMANAGER: called undo");

  if (!self.canUndo()) {
    $.log("... can't undo");
    return;
  }

  self.undoPtr--;
  $.log("UNDOMANAGER: ... undoing undoPtr=",self.undoPtr);
  self.undoBuf[self.undoPtr].restore();

  self.mode = "none";
  self.updateGui();
};

UndoManager.prototype.redo = function() {
  var self = this;

  if (!self.canRedo()) {
    $.log("UNDOMANAGER: ... can't redo");
    return;
  }

  self.undoPtr++;
  $.log("UNDOMANAGER: ... redoing undoPtr=",self.undoPtr);
  self.undoBuf[self.undoPtr].restore();

  self.mode = "none";
  self.updateGui();
};


})(jQuery);
