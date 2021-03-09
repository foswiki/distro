/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2021 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.


As per the GPL, removal of this notice is prohibited.
*/

"use strict";

(function($) {

  function switchSlide(incr) {
    var hash = window.location.hash,
        slideNumber, slide,
        lastSlide = $(".slideShowLastSlide"),
        maxSlideNumber = parseInt(lastSlide.attr("id").replace(/GoSlide/, ''), 10);

    if (hash.match(/^#GoSlide\d+$/)) {
      if (typeof(incr) === 'undefined') {
        // load slide as defined in the hash
        slide = $("div"+hash);

      } else if (incr === Number.MAX_VALUE) {
        // go to last
        slide = lastSlide;
        hash = "#GoSlide" + maxSlideNumber;

      } else {
        // got to other slide
        slideNumber  = parseInt(hash.replace(/^#GoSlide/, '', 'g'), 10);
        if (isNaN(slideNumber)) {
          slideNumber = 0;
        }

        slideNumber += incr;

        if (slideNumber < 1 ) {
          slideNumber = 1;
        }

        if (slideNumber > maxSlideNumber) {
          slideNumber = maxSlideNumber;
        }

        hash = "#GoSlide"+slideNumber;
        slide = $("div"+hash);
      }
    } else {
      slide = $(".slideShowFirstSlide");
    }

    $(".slideShowPane").removeClass("slideShowCurrentSlide");
    slide.addClass("slideShowCurrentSlide");

    // scroll into view
    if (window.location.hash === hash) {
      slide[0].scrollIntoView(1);
    } else {
      window.location.hash = hash;
    }
  }

  $(function() {
    switchSlide();

    $(document).on("keydown", function(ev) {
      switch (ev.key) {
        case "Escape":
          window.location.href = window.location.href.replace(/\?.*$/, '');
          return false;
        case "PageUp":
          switchSlide(-10);
          return false;
        case "PageDown":
          switchSlide(10);
          return false;
        case "End":
          switchSlide(Number.MAX_VALUE);
          return false;
        case "Home":
          switchSlide(0);
          return false;
        case "ArrowLeft":
          switchSlide(-1);
          return false;
        case " ":
        case "ArrowRight":
          switchSlide(1);
          return false;
        case "ArrowUp":
          $(".slideShowCurrentSlide").scrollTo("-=21px", 0, {"axis":"y"});
          return false;
        case "ArrowDown":
          $(".slideShowCurrentSlide").scrollTo("+=21px", 0, {"axis":"y"});
          return false;
        default:
          //console.log("key=",ev.keyCode);
          break;
      }
    });

    $(".slideShowFirst").on("click", function() {
      switchSlide(0);
      return false;
    });

    $(".slideShowLast").on("click", function() {
      switchSlide(Number.MAX_VALUE);
      return false;
    });

    $(".slideShowNext").on("click", function() {
      switchSlide(1);
      return false;
    });

    $(".slideShowPrev").on("click", function() {
      switchSlide(-1);
      return false;
    });
  });

})(jQuery);
