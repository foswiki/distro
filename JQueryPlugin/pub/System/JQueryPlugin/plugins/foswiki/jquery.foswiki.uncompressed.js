/**
 * foswiki setups wrt jQuery
 *
 * $Rev$
*/
var foswiki;
if (typeof(foswiki) == "undefined") {
  foswiki = {};
}

(function($) {

/* init */
$(function(){
  /********************************************************
   * populate foswiki obj with meta data
   */
  $("head meta[name^='foswiki.']").each(function() {
    foswiki[this.name.substr(8)]=this.content;
  });


  /********************************************************
   * shrink urls in WikiTables lists
   */
  if (false) {
    $(".foswikiAttachments .foswikiTable a").shrinkUrls({size:25, trunc:'middle'});
  }

  /********************************************************
   * media stuff
   */
  if (false) {
    $.fn.media.defaults.mp3Player = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';
    $.fn.media.defaults.flvPlayer = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';
    $.fn.media.defaults.players.flash.eAttrs.allowfullscreen = 'true';
    $(".media a[href*=.flv]").media();
    $(".media a[href*=.swf]").media();
    $(".media a[href*=.mp3]").media();
  }


  /********************************************************
   * chili book
   */
  if (typeof ChiliBook != "undefined") {
    ChiliBook.recipeFolder = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/chili/recipes/';
    ChiliBook.automaticSelector = 'pre';
  }
  
});

})(jQuery);
