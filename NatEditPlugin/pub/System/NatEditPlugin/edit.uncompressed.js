// to please pattern skin < 4.2
var beforeSubmitHandler, foswikiStrikeOne, tinyMCE, FoswikiTiny;

function initTextAreaHeight () { }
function handleKeyDown () { }

/* backwards compatibility */
function fixHeightOfPane () { }

(function($) {
  var editAction, $editForm;

  // add submit handler
  function submitHandler() {
    var topicParentField = $editForm.find("input[name=topicparent]");

    if (typeof(beforeSubmitHandler) == 'function') {
      if(beforeSubmitHandler("save", editAction) === false) {
        return false;
      }
    }


    if (topicParentField.val() === "") {
      topicParentField.val("none"); // trick in unsetting the topic parent
    }

    if (editAction === 'addform') {
      $editForm.find("input[name='submitChangeForm']").val(editAction);
    }
    $editForm.find("input[name='action_preview']").val('');
    $editForm.find("input[name='action_save']").val('');
    $editForm.find("input[name='action_checkpoint']").val('');
    $editForm.find("input[name='action_addform']").val('');
    $editForm.find("input[name='action_replaceform']").val('');
    $editForm.find("input[name='action_cancel']").val('');
    $editForm.find("input[name='action_"+editAction+"']").val('foobar');

    if (typeof(foswikiStrikeOne) != 'undefined') {
      foswikiStrikeOne($editForm[0]);
    }

    if ((typeof(tinyMCE) === 'object') && 
      (typeof(tinyMCE.activeEditor) === 'object') &&
      (tinyMCE.activeEditor !== null)) {
      tinyMCE.activeEditor.onSubmit.dispatch();
    }
  }

  $(function() {
    $editForm = $("#EditForm");

    /* remove the second TopicTitle */
    $("input[name='TopicTitle']:eq(1)").parents(".foswikiFormStep").remove();

    /* remove the second Summary */
    $("input[name='Summary']:eq(1)").parents(".foswikiFormStep").remove();
  
    /* add click handler */
    $("#save").click(function() {
      editAction = "save";
      $editForm.submit();
      return false;
    });
    $("#checkpoint").click(function() {
      editAction = "checkpoint";
      if ((typeof(tinyMCE) === 'object') && typeof(tinyMCE.activeEditor === 'object')) {
        // don't ajax using wysiwyg 
        $editForm.submit();
      } else {
        // only ajax using raw 
        submitHandler();
        $editForm.ajaxSubmit({
          beforeSubmit: function() {
            $.blockUI({message:'<h1> Saving ... </h1>'});
          },
          error: function(xhr, textStatus, errorThrown) {
            var message = $(xhr.response).find(".natErrorMessage").text().replace(/\s+/g, ' ').replace(/^\s+/, '') || textStatus;
            $.unblockUI();
            alert(message);
          },
          success: function(data, textStatus) {
            $.unblockUI();
          }
        });
      }
      return false;
    });
    $("#preview").click(function() {
      editAction = "preview";
      //$editForm.submit();
      submitHandler();
      $editForm.ajaxSubmit({
        beforeSubmit: function() {
          $.blockUI({message:'<h1> Loading preview ... </h1>'});
        },
        error: function(xhr, textStatus, errorThrown) {
          var message = $(xhr.response).find(".natErrorMessage").text().replace(/\s+/g, ' ').replace(/^\s+/, '') || textStatus;
          $.unblockUI();
          alert(message);
        },
        success: function(data, textStatus) {
          var $window = $(window),
              height,
              width = Math.round(parseInt($window.width() * 0.6, 10));

          $.unblockUI();
          foswiki.openDialog(data, {
            close: true,
            containerCss: {
              width: width
            },
            onShow: function(dialog) {
              $window.bind('resize', function() {
                height = Math.round(parseInt($window.height() * 0.6, 10));
                width = Math.round(parseInt($window.width() * 0.6, 10));
                if (width < 640) {
                  width = 640;
                }
                dialog.container.width(width);
                dialog.container.find(".foswikiPreviewArea").height(height);
              });
              $window.trigger('resize');
            }
          });
        }
      });
      return false;
    });
    $("#cancel").click(function() {
      editAction = "cancel";
      $editForm.submit();
      return false;
    });
    $("#replaceform").click(function() {
      editAction = "replaceform";
      $editForm.submit();
      return false;
    });
    $("#addform").click(function() {
      editAction = "addform";
      $editForm.submit();
      return false;
    });

    // fix browser back button quirks where checked radio buttons loose their state
    $("input[checked=checked]").each(function() {
      $(this).attr('checked', 'checked');
    });

    $editForm.submit(submitHandler);
  });

  // patch in tinymce
  $(window).load(function() {
    if ((typeof(tinyMCE) === 'object') && typeof(tinyMCE.activeEditor === 'object')) {
      $(".natEditToolBar").hide(); /* switch off natedit toolbar */
      $("#topic_fullscreen").parent().remove(); /* remove full-screen feature ... til fixed */
      /* Thanks to window.load event, TinyMCEPlugin has already done 
      ** switchToWYSIWYG(); our new switchToWYSIWYG() routine below wasn't 
      ** called. So force a TMCE resize. */
      $(window).trigger('resize.natedit');

      var oldSwitchToWYSIWYG = FoswikiTiny.switchToWYSIWYG;
      FoswikiTiny.switchToWYSIWYG = function(inst) {
        $(".natEditToolBar").hide();
        $("#wysiwyg").hide();
        oldSwitchToWYSIWYG(inst);
        $(window).trigger('resize.natedit');
      };

      var oldSwitchToRaw = FoswikiTiny.switchToRaw;
      var doneInit = false;
      FoswikiTiny.switchToRaw = function(inst) {
        oldSwitchToRaw(inst);
        $(window).trigger("resize"); /* to let natedit fix the textarea height */
        var oldWysiwygButton = $("#topic_2WYSIWYG");
        var newWysiwygButton = $("#wysiwyg");
        $(".natEditToolBar").show();
        if (!doneInit) {
          doneInit = true;
          var onClickHandler = oldWysiwygButton.attr('onclick');
          oldWysiwygButton.replaceWith(newWysiwygButton);
          newWysiwygButton.click(onClickHandler).show();
        } else {
          oldWysiwygButton.hide();
          newWysiwygButton.show();
        }
      };
    }
  });

})(jQuery);
