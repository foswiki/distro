/*
 * jQuery AnimateCSS plugin 1.01
 *
 * Copyright (c) 2018-2020 Foswiki Contributors http://foswiki.org
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";

(function($) {

  // global vars
  $.animateCSS = $.extend({
    EFFECTS: {
      "attentionSeekers": [
        "bounce", "flash", "headShake", "jello", "pulse", "rubberBand", "shake",
        "swing", "tada", "wobble", "heartBeat"
      ],
      "bouncingEntrances":  [
        "bounceIn", "bounceInDown", "bounceInLeft", "bounceInRight", "bounceInUp"
      ],
      "bouncingExits": [
        "bounceOut", "bounceOutDown", "bounceOutLeft", "bounceOutRight", "bounceOutUp"
      ],
      "fadingEntrances": [
        "fadeIn", "fadeInDown", "fadeInDownBig", "fadeInLeft", "fadeInLeftBig",
        "fadeInRight", "fadeInRightBig", "fadeInUp", "fadeInUpBig"
      ],
      "fadingExits": [
        "fadeOut", "fadeOutDown", "fadeOutDownBig", "fadeOutLeft",
        "fadeOutLeftBig", "fadeOutRight", "fadeOutRightBig", "fadeOutUp",
        "fadeOutUpBig"
      ],
      "flipEntrances": [
        "flip", "flipInX", "flipInY"
      ],
      "flipExits": [
        "flipOutX", "flipOutY"
      ],
      "lightspeedEntrances": [
        "lightSpeedIn"
      ],
      "lightspeedExits": [
        "lightSpeedOut"
      ],
      "rotatingEntrances": [
        "rotateIn", "rotateInDownLeft", "rotateInDownRight", "rotateInUpLeft",
        "rotateInUpRight"
      ],
      "rotatingExits": [
        "rotateOut", "rotateOutDownLeft", "rotateOutDownRight",
        "rotateOutUpLeft", "rotateOutUpRight"
      ],
      "slidingEntrances": [
        "slideInDown", "slideInLeft", "slideInRight", "slideInUp"
      ],
      "slidingExits": [
        "slideOutDown", "slideOutLeft", "slideOutRight", "slideOutUp"
      ],
      "specials": [
        "hinge", "jackInTheBox", "rollIn", "rollOut"
      ],
      "zoomingEntrances": [
        "zoomIn", "zoomInDown", "zoomInLeft", "zoomInRight", "zoomInUp"
      ],
      "zoomingExits": [
        "zoomOut", "zoomOutDown", "zoomOutLeft", "zoomOutRight", "zoomOutUp"
      ],
    }
  });


  function AnimateCSS(elem, opts) {
    var self = this;

    self.elem = $(elem);
    self.opts = $.extend({}, self.elem.data(), opts);
    self.init();
  }

  AnimateCSS.prototype.init = function () {
    var self = this;

    self._groups = [];

    $.each($.animateCSS.EFFECTS, function(key) {
      self._groups.push(key);
    });

    self._groupRegex = new RegExp(self._groups.join("|"), "i");

    self.elem.on("refresh", function(ev, name) {
      self.animate(name);
    });

    self.opts.effect = self.opts.effect.split(/\s*,\s*/);
  };

  AnimateCSS.prototype.getEffects = function(grp) {
    var self = this;

    if (typeof(grp) === 'undefined') {
      return $.animateCSS.EFFECTS;
    }

    return $.animateCSS.EFFECTS[grp];
  };

  AnimateCSS.prototype.getEffect = function(name) {
    var self = this, eff = name || self.opts.effect;

    if (typeof(eff) === 'string') {
      if (self._groupRegex.test(eff)) {
        eff = self.randomEffect($.animateCSS.EFFECTS[eff]);
      } else if (eff === 'random') {
        eff = self.randomEffect();
      } 
    } else {
      if (eff.length == 1) {
        return self.getEffect(eff[0]);
      } else {
        eff = self.randomElem(eff);
      }
    }

    return eff;
  };

  AnimateCSS.prototype.randomEffect = function (arr) {
    var self = this;

    if (typeof(arr) === 'undefined') {
      arr = $.animateCSS.EFFECTS[self.randomElem(self._groups)];
    }

    return self.randomElem(arr);
  };

  AnimateCSS.prototype.randomElem = function(arr) {
    return arr[Math.floor(Math.random()*arr.length)]
  };

  AnimateCSS.prototype.animate = function(name) {
    var self = this,
        dfd = $.Deferred(),
        eff = self.getEffect(name);

    if (self.opts.infinite) {
      eff += " infinite";
    }

    self.elem.trigger("start.animate");
    this.elem.addClass("animated").addClass(eff).one("animationend webkitAnimationEnd MSAnimationEnd oAnimationEnd mozAnimationEnd oanimationend", function() {
      //console.log("animation ",eff,"ended");
      self.elem.removeClass(eff);
      self.elem.trigger("stop.animate");
      dfd.resolve();
    });

    return dfd.promise();
  };

  // register jQuery function
  $.fn.animateCSS = function (opts) {
    return this.each(function () {
      var ctrl = $.data(this, "animateCSS");
      if (typeof(opts) === 'string') {
        opts = { effect: opts };
      }
      if (!ctrl) {
        ctrl = new AnimateCSS(this, opts);
        $.data(this, "animateCSS", ctrl);
      } else {
        $.extend(ctrl.opts, opts);
      }
      return ctrl.animate();
    });
  };

  // enable declarative widget instanziation
  $(".jqAnimateCSS").livequery(function() {
    var $this = $(this);
    $this.animateCSS();
  });

})(jQuery);
