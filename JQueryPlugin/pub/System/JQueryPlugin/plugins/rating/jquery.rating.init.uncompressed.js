jQuery(function($) {
  $(".jqRating:not(.jqInitedRating)").livequery(function() {
    var $this = $(this);
    var $tip = $("<span class='jqRatingTip'>&nbsp;</span>").appendTo($this);
    function getVal () {
      var current = $this.find(":checked");
      return (current.length)?current.attr('title')||current.val():"&nbsp;";
    }
    $tip.html(getVal());
    var opts = $.extend({
      focus: function(val, elem) {
        $tip.html(elem.title || elem.value);
      },
      blur: function(val, elem) {
        $tip.html(getVal());
      },
      callback: function (val) {
        if (typeof(val) === 'undefined' || val == '') {
          val = "&nbsp;"
        } 
        $tip.html(val);
      }
    }, $this.metadata());
    $this.addClass("jqInitedRating").find("input:[type=radio]").rating(opts);
  });
});
