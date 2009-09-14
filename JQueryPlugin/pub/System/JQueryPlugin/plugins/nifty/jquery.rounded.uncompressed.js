/**
 * make live easier with wrt rounded corners
 */
(function($) {
$.fn.extend({
  roundedCorners: function() {

    this.each(function() {
      var cls = $(this).attr('class');

      var h2args = '';
      var divargs = '';
      var foundsize = false;
      var foundh2 = false;
      var foundcorner = false;

      if ($(this).children().is("h2")) foundh2 = true;

      if (cls.match(/\bsame-height\b/)) 
        divargs += " same-height";
      if (cls.match(/\bfixed-height\b/)) 
        divargs += " fixed-height";
      if (cls.match(/\btransparent\b/)) {
        h2args += " transparent";
        divargs += " transparent";
      }

      if (cls.match(/\btl\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " tl";
          divargs += " none";
        } else
          divargs += " tl";
      }
      if (cls.match(/\btr\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " tr";
          divargs += " none";
        } else
          divargs += " tr";
      }
      if (cls.match(/\bbl\b/)) {
        foundcorner = true;
        h2args += " none";
        divargs += " bl";
      }
      if (cls.match(/\bbr\b/))  {
        foundcorner = true;
        h2args += " none";
        divargs += " br";
      }
      if (cls.match(/\bbottom\b/)) {
        foundcorner = true;
        if (foundh2) 
          h2args += " none";
        divargs += " bottom";
      }

      if (cls.match(/\bleft\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " tl";
          divargs += " bl";
        } else {
          divargs += " left";
        }
      }
      if (cls.match(/\btop\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " top";
          divargs += " none";
        } else {
          divargs += " top";
        }
      }
      if (cls.match(/\bright\b/)) {
        foundcorner = true;
        if (foundh2) {
          h2args += " tr";
          divargs += " br";
        } else {
          divargs += " right";
        }
      }
      if (cls.match(/\bnone\b/)) {
        foundcorner = true;
        h2args += " none";
        divargs += " none";
      }
      if (cls.match(/\bsmall\b/)) { 
        h2args += " small"; 
        divargs += " small"; 
        foundsize = true; 
      }
      if (cls.match(/\bnormal\b/)) { 
        h2args += " normal"; 
        divargs += " normal"; 
        foundsize = true; 
      }
      if (cls.match(/\bbig\b/)) { 
        h2args += " big"; 
        divargs += " big"; 
        foundsize = true; 
      }
      if (!foundsize) { 
        h2args += " big"; 
        divargs += " big"; 
      }
      if (!foundcorner) {
        if (foundh2) {
          h2args += " top";
          divargs += " bottom";
        }
      }

      if (foundh2) {
        $("h2",this).nifty(h2args);
      }
      $(this).nifty(divargs);
    });

    return this;
  }
});

/* init */
$(function()  {
  $(".jqRounded").roundedCorners();
});

})(jQuery);
