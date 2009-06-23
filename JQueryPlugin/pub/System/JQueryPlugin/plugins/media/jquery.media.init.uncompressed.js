/********************************************************
 * media init for foswiki
 */
;(function($) {

$(function() {

  $.fn.media.defaults.mp3Player = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';
  $.fn.media.defaults.flvPlayer = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';
  $.fn.media.defaults.players.flash.eAttrs.allowfullscreen = 'true';
  $(".jqMedia").find("a[href*=.flv], a[href*=.swf], a[href*=.mp4], a[href*=.mp3]").each(function() {
    var $this = $(this);
    var options = $.extend({caption: ''}, $this.metadata());
    $this.media(options);
  });
});

})(jQuery);
