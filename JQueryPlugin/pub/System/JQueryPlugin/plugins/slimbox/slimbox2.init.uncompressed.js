jQuery(function($) {
  var defaults = {
    resizeDuration:300,
    captionAnimationDuration:200,
    imageFadeDuration:300
  };
  $(".jqSlimbox:not(.jqInitedSlimbox2)").livequery(function() {
    var $this = $(this);
    $this.addClass("jqInitedSlimbox2");
    var opts = $.extend({}, defaults, $this.metadata());
    var groupRel = "lightbox-"+Math.floor(Math.random() * 100);
    $this.find("a[href]").attr('rel', groupRel).slimbox(opts,
      function(el) {
        var metadata = $(el).metadata();
        var href = metadata.origurl || el.href;
        return [el.href, '<a href="' + href + '">'+el.title+'</a>'];
      },
      function(el) {
        return (this == el) || ((this.rel.length > 8) && (this.rel == el.rel));
      }
    );
  });        
});
