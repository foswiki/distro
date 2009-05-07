/********************************************************
 * media init for foswiki
 */
;(function($) {

  if (true) { // TODO: make this configurable
    $.fn.media.defaults.mp3Player = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';
    $.fn.media.defaults.flvPlayer = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';
    $.fn.media.defaults.players.flash.eAttrs.allowfullscreen = 'true';
    $(".media").find("a[href*=.flv], a[href*=.swf], a[href*=.mp3]").media();
  }

})(jQuery);
