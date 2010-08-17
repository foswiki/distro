(function($) { 
  function openDialog(data, opts) { 
    $.log("SM: called openDialog data="+data);
    var $dialog = $(data);
    $dialog.modal(opts); 

    // OK button
    $(".jqSimpleModalOK:not(.jqInitedSimpleModalOK)", $dialog).each(function() {
      $(this).addClass("jqInitedSimpleModalOK").click(function(e) {
        $.log("SM: clicked ok");
        $.modal.close(); 
        if (typeof(opts.onSubmit) == 'function') { 
          opts.onSubmit($dialog); 
        } 
        e.preventDefault();
        return false; 
      });
    });

    // Cancel button
    $(".jqSimpleModalCancel:not(.jqInitedSimpleModalCancel)", $dialog).each(function() {
      $(this).addClass("jqInitedSimpleModalCancel").click(function(e) {
        $.log("SM: clicked cancel");
        $.modal.close(); 
        if (typeof(opts.onCancel) == 'function') { 
          opts.onCancel($dialog); 
        } 
        e.preventDefault();
        return false; 
      }); 
    }); 
  } 

  var defaults = {
    persist:false,
    close:false, 
    onShow: function() { 
      $(window).trigger("resize.simplemodal"); 
    } 
  };

  $(function() { 
    // opener
    $(".jqSimpleModal:not(.jqInitedSimpleModal)").livequery(function() { 
      var $this = $(this);
      $this.addClass("jqInitedSimpleModal").click(function(e) {
        var opts = $.extend({}, defaults, $this.metadata());
        var id = $this.attr('simple-modal-data') || opts.data;
        if (opts.url && !id) { 
          // async
          $.get(opts.url, function(content) { 
            var $content = $(content);
            id = $content.attr('id');
            if (!id) {
              id = foswiki.getUniqueID();
              $content.attr('id', id).hide();
              $("body").append($content);
            }
            $this.attr('simple-modal-data', '#'+id);
            openDialog("#"+id, opts); 
          }); 
        } else { 
          // inline
          openDialog(id, opts); 
        } 
        e.preventDefault();
        return false;
      });
    }); 
  }); 
})(jQuery); 
