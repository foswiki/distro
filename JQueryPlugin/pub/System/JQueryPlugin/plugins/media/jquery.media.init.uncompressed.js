jQuery(function($) {
  var pubUrlPath = foswiki.getPreference("PUBURLPATH")+'/'+foswiki.getPreference("SYSTEMWEB")+'/JQueryPlugin';

  $.fn.media.defaults.mp3Player = pubUrlPath+'/plugins/media/mediaplayer/player.swf';
  $.fn.media.defaults.flvPlayer = pubUrlPath+'/plugins/media/mediaplayer/player.swf';
  $.fn.media.defaults.params = {
    bgColor: '#000',
    allowfullscreen: true
  }

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
    var $this = $(this),
        options = $.extend({
          caption: '',
          skin: 'stormtrooper'
        }, $this.metadata());

    if (options.autoplay) {
      options.flashvars = $.extend({}, options.flashvars, {
        autostart:true
      });
    }
    if (options.skin) {
      options.flashvars = $.extend({}, options.flashvars, {skin:pubUrlPath+"/plugins/media/skins/"+options.skin+".zip"});
    }

    $this.addClass("jqInitedMedia");
    $this.find(selector).each(function() {
      $(this).media(options);
    });
  });
});
