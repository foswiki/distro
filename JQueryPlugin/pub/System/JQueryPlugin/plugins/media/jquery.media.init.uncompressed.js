jQuery(function($) {
  var pubUrlPath = foswiki.getPreference("PUBURLPATH")+'/'+foswiki.getPreference("SYSTEMWEB")+'/JQueryPlugin';

  $.fn.media.defaults.mp3Player = pubUrlPath+'/plugins/media/mediaplayer/player.swf';
  $.fn.media.defaults.flvPlayer = pubUrlPath+'/plugins/media/mediaplayer/player.swf';
  $.fn.media.defaults.params = {
    bgColor: '#000',
    allowfullscreen: true
  }

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
    $this.find("a[href]").each(function() {
      $(this).media(options);
    });
  });
});
