(function($) {
  function switchSlide(incr) {
    var hash = window.location.hash,
        slideNumber, slide,
        lastSlide = $(".slideShowLastSlide"),
        maxSlideNumber = parseInt(lastSlide.attr("id").replace(/GoSlide/, ''), 10);

    if (hash.match(/^#GoSlide\d+$/)) {

      if (incr === Number.MAX_VALUE) {
        // go to last
        slide = lastSlide;
        hash = "#GoSlide" + maxSlideNumber;

      } else if (incr === 0) {

        // go to first
        hash = "#GoSlide1";
        slide = $("div"+hash);

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
    window.location.hash = hash;
  }

  $(function() {
    switchSlide(0);
    $(document).on("keydown", function(ev) {
      switch (ev.keyCode) {
        case 27: // esc
          window.location.href = window.location.href.replace(/\?.*$/, '');
          return false;
        case 33: // page up
          switchSlide(-10);
          return false;
        case 34: // page down
          switchSlide(10);
          return false;
        case 35: // end
          switchSlide(Number.MAX_VALUE);
          return false;
        case 36: // pos1
          switchSlide(0);
          return false;
        case 37: // right
          switchSlide(-1);
          return false;
        case 32: // space
        case 39: // left
          switchSlide(1);
          return false;
        case 38: // up
          $(".slideShowCurrentSlide").scrollTo("-=21px", 0, {"axis":"y"});
          return false;
        case 40: // down
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
