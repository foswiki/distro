/*
 * class TextareaState
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
var TextareaState;

(function($) {

/*****************************************************************************
 * constructor
 */
TextareaState = function(engine) {
  var self = this;

  self.engine = engine;
  self.init();
}

TextareaState.prototype.init = function() {
  var self = this,
      txtarea = self.engine.shell.txtarea;

  self.engine.getSelectionRange();
  self.selectionStart = txtarea.selectionStart;
  self.selectionEnd = txtarea.selectionEnd;
  self.scrollTop = txtarea.scrollTop;
  self.value = txtarea.value;
};

TextareaState.prototype.restore = function() {
  var self = this,
      txtarea = self.engine.shell.txtarea;

  txtarea.value = self.value;
  txtarea.scrollTop = self.scrollTop;
  self.engine.setSelectionRange(self.selectionStart, self.selectionEnd);

  $(window).trigger("resize");
};

TextareaState.prototype.isUnchanged = function() {
  var self = this, 
      txtarea = self.engine.shell.txtarea;

  self.engine.getSelectionRange();

  return txtarea.selectionStart == self.selectionStart &&
      txtarea.selectionEnd == self.selectionEnd &&
      txtarea.scrollTop == self.scrollTop &&
      txtarea.value == self.value;
};

})(jQuery);
