(function($) {
  function switchSlide(incr) {
    var hash = window.location.hash,
        slideNumber, slide,
        lastSlide = $(".slideShowLastSlide"),
        maxSlideNumber = parseInt(lastSlide.attr("id").replace(/GoSlide/, ''), 10);

    if (!hash.match(/^#GoSlide\d+$/)) {
      return;
    }

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
        return;
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

    if (slide.length) {
      window.location.hash = hash;
    }
  }

  $(function() {
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
        case 39: // left
          switchSlide(1);
          return false;
        default:
          //console.log("key=",ev.keyCode);
          break;
      }
    });
  });

})(jQuery);
