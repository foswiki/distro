jQuery(function($) {

  $(".jqRating:not(.jqInitedRating)").livequery(function() {
    var $this = $(this),
        opts = $.extend(
        // defaults 
        {
          focus: function(value, link) {
            var $link = $(link), 
                title = $link.attr("title") || $link.attr("value");
            $this.find(".jqRatingValue").text(title);
          }, 
          blur: function(value, link) {
            var $link = $this.find(":checked"),
                title = $link.attr("title") || $link.attr("value") || '';
            $this.find(".jqRatingValue").text(title);
          }, 
          callback: function(value, link) {
            var $link = $(link), 
                title = $link.attr("title") || $link.attr("value");
            $this.find(".jqRatingValue").text(title);
          } 
        }, $this.metadata()),
        $link = $this.find(":checked"),
        val = $link.attr("title") || $link.attr("value") || '';

    // display value
    $("<span>"+val+"</span>").addClass('jqRatingValue').appendTo($this);

    // init
    $this.addClass("jqInitedRating").find('[type=radio]').rating(opts);
    
    // add hover to cancel button 
    $this.find(".rating-cancel").hover(
      function() {
        if (typeof(opts.focus) == 'function') {
          opts.focus(0, this);
        }
      },
      function() {
        if (typeof(opts.blur) == 'function') {
          opts.blur(0, this);
        }
      }
    );
  });

});
