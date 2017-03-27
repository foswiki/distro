/*
 * jQuery NatEdit: tinymce native engine
 *
 * Copyright (c) 2017 Michael Daum http://michaeldaumconsulting.com
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

TinyMCENativeEngine.prototype = new BaseEngine();
TinyMCENativeEngine.prototype.constructor = TinyMCENativeEngine;
TinyMCENativeEngine.prototype.parent = BaseEngine.prototype;

function TinyMCENativeEngine(shell, opts) {
  var self = this;

  self.shell = shell;
  self.opts = $.extend({}, TinyMCENativeEngine.defaults, opts);
  self.opts.natedit.showToolbar = false;
  self.editor = tinymce.editors[0];
  
  $.extend(self.shell.opts, self.opts.natedit);
}

/*************************************************************************
 * init gui
 */
TinyMCENativeEngine.prototype.initGui = function() {
  var self = this, $txtarea = $(self.shell.txtarea);

  $txtarea.on("fwSwitchToRaw", function(/*ev, editor*/) {
    self.shell.showToolbar().then(function() {
      self.shell.toolbar.find(".ui-natedit-switch-to-wysiwyg").show();
    });
  }).on("fwSwitchToWYSIWYG", function() {
    self.shell.hideToolbar();
    $(document).trigger("resize");
  });
};

/*************************************************************************
  */
TinyMCENativeEngine.prototype.switchToWYSIWYG = function(ev) {
  var self = this;

  self.editor.execCommand("fwSwitchToWYSIWYG");
};

/*************************************************************************
 * get the DOM element that holds the editor engine
 */
TinyMCENativeEngine.prototype.getWrapperElement = function() {
  var self = this;

  return self.editor?$(self.editor.contentAreaContainer).children("iframe"):null;
};

/*************************************************************************
 * set the size of editor
 */
TinyMCENativeEngine.prototype.setSize = function(width, height) {
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
TinyMCENativeEngine.defaults = {
  debug: true,
  natedit: {
  }
};

/*************************************************************************
 * register engine to NatEditor shell
 */
$.NatEditor.engines.tinymce_native = {
  createEngine: function(shell) {
    return (new TinyMCENativeEngine(shell)).init();
  }
};

})(jQuery);
