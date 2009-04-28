/**
 * TWiki setups wrt jQuery
 *
 * $Rev$
*/
var twiki;
if (!twiki) {
  twiki = {};
}

twiki.JQueryPlugin = new function () {
  var self = this;
}

/**
 * make live easier with wrt rounded corners
 */
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
$(function(){

  /********************************************************
   * treeview stuff
   */
  var $jqTreeviews;
  if (true) {
    $jqTreeviews = $(".jqTreeview");
    $jqTreeviews.children("> ul").each(function(){
      /*$("a,span,input", this).tooltip({
        delay:250,
        track:false,
        showURL:false,
        extraClass:'twiki',
        showBody:": "
      });*/
      var args = Array();
      var parentClass = $(this).parent().attr('class');
      if (parentClass.match(/\bopen\b/)) {
        args['collapsed'] = false;
      }
      if (parentClass.match(/\bclosed?\b/)) {
        args['collapsed'] = true;
      }
      if (parentClass.match(/\bunique\b/)) {
        args['unique'] = true;
      }
      if (parentClass.match(/\bprerendered\b/)) {
        args['prerendered'] = true;
      }
      args['animated'] = 'fast';
      if (parentClass.match(/\bspeed_(fast|slow|normal|none|[\d\.]+)\b/)) {
        var speed = RegExp.$1;
        if (speed == "none") {
          delete args['animated'];
        } else {
          args['animated'] = speed;
        }
      }
      $(this).treeview(args);
    });
  }

  /********************************************************
   * shrink urls in TWikiTables lists
   */
  if (false) {
    $(".twikiAttachments .twikiTable a").shrinkUrls({size:25, trunc:'middle'});
  }

  /********************************************************
   * tooltips 
   */
  if (false) {
    $("a,span,input").tooltip({
      delay:250,
      track:false,
      showURL:false,
      extraClass:'twiki',
      showBody:": "
    });//.css('background','pink');
  }

  /********************************************************
   * rounded corners using nifty 
   */
  if (false) {
    $(".jqRounded").roundedCorners();
  }

  /********************************************************
   * twikiToc stuff
   */

  /* add a toggle switch */

  if (false) {
    $(".twikiToc").each(function() { 
      $(this).prepend("<a class='twikiTocToggle'>[hide]</a>")
    });

    /* behaviour of the twiki toggle switch */
    $(".twikiTocToggle").
      css("float","right").
      click(function() {
        $("> ul",$(this).parent()).slideToggle({easing:'easeInOutQuad', duration:300});
        if($(this).text() == "[hide]") {
          $(this).text("[show]");
        } else {
          $(this).text("[hide]");
        }
      });
  }

  /********************************************************
   * media stuff
   */
  if (false) {
    $.fn.media.defaults.mp3Player = twiki.pubUrlPath+'/TWiki/JQueryPlugin/mediaplayer/player.swf';
    $.fn.media.defaults.flvPlayer = twiki.pubUrlPath+'/TWiki/JQueryPlugin/mediaplayer/player.swf';
    $.fn.media.defaults.players.flash.eAttrs.allowfullscreen = 'true';
    $(".media a[href*=.flv]").media();
    $(".media a[href*=.swf]").media();
    $(".media a[href*=.mp3]").media();
  }
  
  /********************************************************
   * finally show treeviews 
   */
  if ($jqTreeviews) {
    $jqTreeviews.css('display', 'block');
  }

});
