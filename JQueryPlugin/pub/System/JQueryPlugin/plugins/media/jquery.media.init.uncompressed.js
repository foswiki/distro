jQuery(function($) {

  $.fn.media.defaults.mp3Player = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';
  $.fn.media.defaults.flvPlayer = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/media/mediaplayer/player.swf';
  $.fn.media.defaults.players.flash.eAttrs.allowfullscreen = 'true';

  var types = new Array();
  for (var group in $.fn.media.defaults.players) {
    var val = $.fn.media.defaults.players[group].types;
    if (val) {
      val = val.split(/\s*,\s*/);
      for (var i = 0; i < val.length; i++) {
        types.push(val[i]);
      }
    }
  }

  var selector = "a[href*=."+types.join("], a[href*=.")+"]";
  $(".jqMedia:not(.jqInitedMedia)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedMedia");
    var options = $.extend({caption: ''}, $this.metadata());
    $this.find(selector).each(function() {
      $(this).media(options);
    });
  });
});
