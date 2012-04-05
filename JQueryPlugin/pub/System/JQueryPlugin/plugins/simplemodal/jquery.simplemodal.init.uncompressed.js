(function($) { 
  /**************************************************************************/
  foswiki.openDialog = function(data, opts) { 
    $.log("SM: called openDialog data");
    $("body").css("cursor", "process"); // reset in init()
    opts = $.extend({}, opts);
    if (typeof(opts._origOnShow) !== undefined) {
      opts._origOnShow = opts.onShow;
      opts.onShow = function(dialog) {
        if ($.isFunction(opts._origOnShow)) {
          opts._origOnShow(dialog);
        }
        init(dialog, opts);
      }
    }
    opts.onOpen = function(dialog) {
      $.log("SM: called onOpen");
      dialog.overlay.show();
      dialog.container.hide();
      dialog.data.show();
    };
    $(data).modal(opts); 
  } 

  /**************************************************************************/
  function loadDialog(url, opts) {
    $.log("SM: loading "+url);
    $.ajax({
      url: url,
      dataType: 'html',
      async: false,
      success: function(data) {
        $("body").append(data);
        foswiki.openDialog(data, opts);
      }
    });
  }

  /**************************************************************************/
  function init(dialog, opts) {
    $.log("SM: called init");

    // restore cursor
    $("body").css("cursor", "auto");

    //  fix position
    setTimeout(function() {
      $(window).trigger("resize.simplemodal"); 
      dialog.container.fadeIn();
    }, 100);
    
    // OK button
    dialog.container.find(".jqSimpleModalOK:not(.jqInitedSimpleModalOK)").each(function() {
      $(this).addClass("jqInitedSimpleModalOK").click(function(e) {
        $.log("SM: clicked ok");
        $.modal.close(); 
        if (typeof(opts.onSubmit) == 'function') { 
          opts.onSubmit(dialog); 
        } 
        e.preventDefault();
        return false; 
      });
    });

    // Cancel button
    dialog.container.find(".jqSimpleModalCancel:not(.jqInitedSimpleModalCancel)").each(function() {
      $(this).addClass("jqInitedSimpleModalCancel").click(function(e) {
        $.log("SM: clicked cancel");
        $.modal.close(); 
        if (typeof(opts.onCancel) == 'function') { 
          opts.onCancel(dialog); 
        } 
        e.preventDefault();
        return false; 
      }); 
    }); 

    // add onCancel to simplemoda-close elements
    if (typeof(opts.onCancel) == 'function') {
      dialog.container.find(".simplemodal-close").click(function() {
        opts.onCancel(dialog);
      });
    }

    // make it draggable if there's a handler
    dialog.container.find(".jqSimpleModalDraggable").each(function() {
      var opts = $.extend({
        handle: '.jqSimpleModalDraggable'
      }, $(this).metadata());
      dialog.container.draggable(opts);
    });

    // make it draggable if there's a handler
    dialog.container.find(".jqSimpleModalResizable:first").each(function() {
      var opts = $.extend({
        handles: 'se'
      }, $(this).metadata());
      dialog.container.resizable(opts);
    });
  }

  /**************************************************************************/
  var defaults = {
    persist:false,
    close:true, 
    opacity: 40
  };

  /**************************************************************************/
  $(function() { 
    // opener
    $(".jqSimpleModal:not(.jqInitedSimpleModal)").livequery(function() { 
      var $this = $(this);
      $this.addClass("jqInitedSimpleModal").click(function(e) {
        var opts = $.extend({}, defaults, $this.metadata());
        if (opts.url) { 
          // async
          $.get(opts.url, function(content) { 
            var $content = $(content),
                id = $content.attr('id');
            if (!id) {
              id = foswiki.getUniqueID();
            }
            $content.attr('id', id).hide();
            $("body").append($content);
            $.log("SM: id="+id);
            $this.attr('simple-modal-data', '#'+id);
            foswiki.openDialog("#"+id, opts); 
          }); 
        } else { 
          // inline
          foswiki.openDialog(opts.data, opts); 
        } 
        e.preventDefault();
        return false;
      });
    }); 
  }); 
})(jQuery); 
